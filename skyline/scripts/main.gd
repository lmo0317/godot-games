extends Control
## Game screen (landscape): title, map with camera, status windows, build shop and placement.
## The rules live in City; this script turns input into City edits and City signals into feedback.
## Building works like base-builder games (Clash of Clans): open the shop, pick something, and a
## ghost appears on the map on green/red ground with cancel/confirm buttons above it. Drag the ghost
## to move it, drag anywhere else to move the map, press the green check to build.

const BASE := Vector2(1280, 720)     # design size; the screen is at least this big
const SAVE_PATH := "user://save.json"
const META_PATH := "user://meta.json"
const MIN_ZOOM := 1.0
const MAX_ZOOM := 3.0
const START_ZOOM := 2.0        # one tile 128 px wide (sprites 1:1), like Kairosoft town games
const MAX_RECT := 16
const MAX_PATH := 64
const EDGE := 70.0             # dragging a ghost this close to the screen edge moves the map
const EDGE_SPEED := 700.0
const TOP_SAFE := 86.0          # floating buttons stay below the top status windows
const MSG_TEXT := Color(0.16, 0.22, 0.1)
const SPEED_NAMES := ["멈춤", "보통", "빠름", "최고속"]
const ZONE_ICONS := ["", "ui_res", "ui_com", "ui_ind"]

enum Build { NONE, FAC, ROAD, ZONE, CLEAR }
# shop tabs: [name, items]; an item is [kind, id] with kind road, zone (id = Defs.Z), clear or fac
const SHOP_TABS := [
	["도로·구역", [["road", 0], ["zone", 1], ["zone", 2], ["zone", 3], ["clear", 0]]],
	["시설", [["fac", 2], ["fac", 3], ["fac", 4], ["fac", 5], ["fac", 6], ["fac", 7], ["fac", 8], ["fac", 9], ["fac", 10]]],
	["명소", [["fac", 11], ["fac", 12], ["fac", 13]]],
]

# screen size: the window is filled (stretch aspect "expand"), so a wide phone gets a wider screen
var W := BASE.x
var H := BASE.y
var VIEW := Rect2(Vector2.ZERO, BASE)

var city: City
var world: Node2D
var map: MapView
var walkers: Walkers
var fx: FxLayer

var zoom := 3.0
var cam := Vector2.ZERO
var speed_idx := 1
var week_timer := 0.0
var meta := {"best": 0, "best_daily": {}, "muted": false}
var year_start := {}
var year_net := 0
var warned := {}

# placement (the ghost)
var build := Build.NONE
var build_zone := 0
var fac_id := 2
var fac_cell := -1
var road_path: Array = []       # cells from the start; the last one carries the drag arrows
var road_base: Array = []       # the path when the current drag began
var road_axis := -1             # 0: the drag goes along x first, 1: along y first
var rect_a := -1                # fixed corner of a zone / demolish box
var rect_b := -1                # corner with the drag arrows
var build_ok := false
var drew_new := false           # this press started a new road / box where the finger landed
var before_press := {}          # the preview before this press (to undo it when two fingers land)
var shop_tab := 0

# pointer
var pressing := false
var moved := false
var drag := ""                  # pan, move, extend (road), resize (box)
var drag_cell := -1
var drag_offset := Vector2.ZERO
var press_pos := Vector2.ZERO
var finger := Vector2.ZERO
var panning := false
var pan_last := Vector2.ZERO
var touches := {}
var multi_touch := false
var pinch_dist := 1.0
var pinch_zoom := 3.0
var pinch_anchor := Vector2.ZERO

# one edit (for undo)
var stroke_changes := {}
var stroke_spent := 0
var stroke_failed := false
var undo_op := {}

# UI
var money_label: Label
var delta_label: Label
var date_label: Label
var pop_label: Label
var rank_label: Label
var goals_label: Label
var demand_bars: Array = []
var speed_button: Button
var undo_button: Button
var shop_button: Button
var done_button: Button         # ends road / zone / demolish drawing
var build_ui: Control           # cost + cancel/confirm, floats over the ghost
var cost_label: Label
var ok_button: Button
var select_ui: Control          # demolish button over a tapped cell
var demolish_button: Button
var hint_label: Label
var toast_panel: PanelContainer      # the advisor message bar
var toast_label: Label
var toast_queue: Array = []
var toast_time := 0.0
var current_hint := ""
var modal_layer: Control
var title_screen: Control
var continue_button: Button
var best_label: Label
var title_box: Control          # title screen content, kept in the middle
var date_box: Panel
var res_box: Panel


class Glyph:
	## White check or cross with a dark rim, drawn as lines (the font has no such signs).
	extends Control
	var kind := "ok"

	func _draw() -> void:
		var s := size
		var pts: PackedVector2Array
		if kind == "ok":
			pts = PackedVector2Array([s * Vector2(0.27, 0.52), s * Vector2(0.44, 0.7), s * Vector2(0.75, 0.3)])
			draw_polyline(pts, Color(0.05, 0.2, 0.02), 15.0)
			draw_polyline(pts, Color.WHITE, 9.0)
		else:
			for line in [[Vector2(0.3, 0.28), Vector2(0.7, 0.68)], [Vector2(0.7, 0.28), Vector2(0.3, 0.68)]]:
				draw_line(s * line[0], s * line[1], Color(0.3, 0.02, 0.02), 15.0)
			for line in [[Vector2(0.3, 0.28), Vector2(0.7, 0.68)], [Vector2(0.7, 0.28), Vector2(0.3, 0.68)]]:
				draw_line(s * line[0], s * line[1], Color.WHITE, 9.0)


func _ready() -> void:
	Atlas.load_once()
	_load_meta()
	SoundManager.muted = meta.get("muted", false)
	world = Node2D.new()
	add_child(world)
	map = MapView.new()
	world.add_child(map)
	walkers = Walkers.new()
	world.add_child(walkers)
	walkers.shop_visit.connect(_on_shop_visit)
	fx = FxLayer.new()
	fx.world = world
	add_child(fx)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_hud()
	_build_toast()
	_build_float_ui()
	modal_layer = Control.new()
	modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal_layer)
	_build_title()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_show_title()


func _layout() -> void:
	## Put the edge-bound windows and buttons where the screen is now.
	var size := get_viewport_rect().size
	W = maxf(size.x, BASE.x)
	H = maxf(size.y, BASE.y)
	VIEW = Rect2(0, 0, W, H)
	title_box.position = ((Vector2(W, H) - BASE) * 0.5).round()
	date_box.position.x = roundf((W - date_box.size.x) * 0.5)
	res_box.position.x = W - res_box.size.x - 16
	shop_button.position = Vector2(W - 166, H - 160)
	done_button.position = shop_button.position
	toast_panel.position = Vector2(16, H - 116)
	_apply_camera()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if city != null and not city.finished:
			_save_game()


# ================================================================ title
func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(title_screen)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(bg)
	title_box = Control.new()
	title_box.size = BASE
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_screen.add_child(title_box)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UIKit.window(16))
	frame.position = Vector2(48, 48)
	frame.size = Vector2(624, 624)
	title_box.add_child(frame)
	var art := TextureRect.new()
	art.texture = load("res://assets/art/title.jpg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(6, 6)
	art.size = Vector2(612, 612)
	art.clip_contents = true
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	frame.add_child(art)
	var right := 720.0
	var col_w := BASE.x - right - 48.0
	var title := UIKit.outlined(UIKit.label("도트 미니 시티", 60, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 12)
	title.position = Vector2(right, 110)
	title.size = Vector2(col_w, 80)
	title_box.add_child(title)
	var sub := UIKit.label("구역을 칠하면 도시가 스스로 자라요", 24, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(right, 190)
	sub.size = Vector2(col_w, 36)
	title_box.add_child(sub)
	var col := VBoxContainer.new()
	col.position = Vector2(right + (col_w - 400) / 2.0, 270)
	col.size = Vector2(400, 290)
	col.add_theme_constant_override("separation", 18)
	title_box.add_child(col)
	continue_button = _menu_button(col, "이어하기", "primary", _continue_game)
	_menu_button(col, "새 도시 만들기", "primary", func(): _start_game("normal"))
	_menu_button(col, "오늘의 도시", "secondary", func(): _start_game("daily"))
	best_label = UIKit.label("", 22, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	best_label.position = Vector2(right, 600)
	best_label.size = Vector2(col_w, 34)
	title_box.add_child(best_label)
	var tag := UIKit.label("가칭 · 첫 플레이 버전", 18, Color(UIKit.MUTED, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	tag.position = Vector2(right, 640)
	tag.size = Vector2(col_w, 30)
	title_box.add_child(tag)


func _menu_button(parent: Control, text: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(400, 74)
	UIKit.style_button(b, kind, 28, 14)
	b.pressed.connect(func():
		SoundManager.play("click")
		cb.call())
	parent.add_child(b)
	return b


func _show_title() -> void:
	_close_modal()
	title_screen.visible = true
	continue_button.visible = FileAccess.file_exists(SAVE_PATH)
	var today := _today()
	var daily: int = int(meta["best_daily"].get(today, 0))
	var text := "최고 점수 %s" % UIKit.format_number(int(meta["best"]))
	if daily > 0:
		text += "  ·  오늘의 도시 %s" % UIKit.format_number(daily)
	best_label.text = text
	walkers.clear()


func _today() -> String:
	return Time.get_date_string_from_system()


# ================================================================ game start / save
func _start_game(mode: String) -> void:
	city = City.new()
	var seed_in := randi()
	if mode == "daily":
		seed_in = _today().replace("-", "").to_int()
	city.new_game(seed_in, mode)
	_attach_city()
	_save_game()
	_toast("오른쪽 아래 '건설'에서 도로를 골라 고속도로(왼쪽)에 이어 깔아요", "info")


func _continue_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	city = City.new()
	if typeof(d) != TYPE_DICTIONARY or not city.from_dict(d):
		_toast("저장된 도시를 불러오지 못했어요", "bad")
		return
	_attach_city()


func _attach_city() -> void:
	city.notice.connect(_toast)
	city.built.connect(_on_built)
	city.burned.connect(_on_burned)
	city.rank_up.connect(_on_rank_up)
	city.month_passed.connect(_on_month_passed)
	city.year_end.connect(_on_year_end)
	city.finished_run.connect(_on_finished)
	map.city = city
	walkers.city = city
	walkers.clear()
	title_screen.visible = false
	undo_op = {}
	week_timer = 0.0
	year_start = {"pop": city.pop, "money": city.money}
	year_net = 0
	warned = {}
	_end_build()
	map.selected = -1
	_set_speed(1)
	var a := city.active_rect()
	cam = MapView.grid_to_local(Vector2(a.get_center()) - Vector2(0.5, 0.5))
	zoom = START_ZOOM
	_apply_camera()
	_after_edit()


func _save_game() -> void:
	if city == null:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(city.to_dict()))


func _delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)


func _load_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) == TYPE_DICTIONARY:
		for k in d:
			meta[k] = d[k]


func _save_meta() -> void:
	var f := FileAccess.open(META_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(meta))


# ================================================================ HUD
func _hud_panel(pos: Vector2, size: Vector2) -> Panel:
	## Dark see-through window with a light rim, like the status boxes of pocket management games.
	var p := Panel.new()
	var sb := UIKit.box(Color(0.08, 0.1, 0.2, 0.82), Color(0.86, 0.88, 0.95), 8, 3)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(p)
	return p


func _side_button(icon: String, text: String, pos: Vector2, cb: Callable) -> Button:
	## Square button with a picture and a short label under it (left column).
	var b := Button.new()
	b.text = text
	b.icon = Atlas.icon(icon)
	b.expand_icon = true
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 52)
	b.texture_filter = _icon_filter(icon)
	b.custom_minimum_size = Vector2(80, 86)
	b.size = Vector2(80, 86)
	b.position = pos
	UIKit.style_button(b, "secondary", 17, 10)
	b.pressed.connect(func():
		SoundManager.play("click")
		cb.call())
	add_child(b)
	return b


func _icon_filter(name: String) -> CanvasItem.TextureFilter:
	## Pixel icons shown at whole-number sizes stay crisp; building pictures shrunk into buttons
	## are smoothed.
	return CanvasItem.TEXTURE_FILTER_NEAREST if name.begins_with("ui_") or not Art.has(name) else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _build_hud() -> void:
	# top-left: town rank and the goal for the next one
	var rank_box := _hud_panel(Vector2(16, 12), Vector2(470, 64))
	var chip := PanelContainer.new()
	var csb := UIKit.box(UIKit.ACCENT, Color(1, 0.9, 0.7), 6, 2)
	chip.add_theme_stylebox_override("panel", csb)
	chip.position = Vector2(10, 12)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rank_box.add_child(chip)
	rank_label = UIKit.outlined(UIKit.label("마을", 20), 4)
	chip.add_child(rank_label)
	goals_label = UIKit.label("", 17, UIKit.TEXT)
	goals_label.position = Vector2(104, 4)
	goals_label.size = Vector2(356, 56)
	goals_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	goals_label.add_theme_constant_override("line_spacing", -4)
	rank_box.add_child(goals_label)
	# top middle: date and monthly balance
	date_box = _hud_panel(Vector2(490, 12), Vector2(300, 64))
	date_label = UIKit.outlined(UIKit.label("", 24, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER), 4)
	date_label.position = Vector2(8, 2)
	date_label.size = Vector2(284, 34)
	date_box.add_child(date_label)
	delta_label = UIKit.label("", 17, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	delta_label.position = Vector2(8, 34)
	delta_label.size = Vector2(284, 26)
	date_box.add_child(delta_label)
	# top-right: money, people, demand
	res_box = _hud_panel(Vector2(W - 324, 12), Vector2(308, 140))
	var res := res_box
	var coin := TextureRect.new()
	coin.texture = Atlas.icon("coin")
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = _icon_filter("coin")
	coin.position = Vector2(12, 8)
	coin.size = Vector2(36, 36)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	res.add_child(coin)
	money_label = UIKit.outlined(UIKit.label("$0", 32, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT), 6)
	money_label.position = Vector2(56, 4)
	money_label.size = Vector2(238, 44)
	res.add_child(money_label)
	pop_label = UIKit.label("", 19, UIKit.TEXT)
	pop_label.position = Vector2(14, 50)
	pop_label.size = Vector2(284, 32)
	res.add_child(pop_label)
	var dl := UIKit.label("수요", 16, UIKit.MUTED)
	dl.position = Vector2(14, 92)
	dl.size = Vector2(60, 34)
	res.add_child(dl)
	var names := ["주", "상", "공"]
	for k in 3:
		var x := 80 + k * 72
		var back := ColorRect.new()
		back.color = Color(0, 0, 0, 0.4)
		back.position = Vector2(x, 90)
		back.size = Vector2(24, 34)
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		res.add_child(back)
		var fill := ColorRect.new()
		fill.color = Defs.ZONE_COLORS[k + 1]
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.add_child(fill)
		demand_bars.append(fill)
		var l := UIKit.label(names[k], 16, UIKit.MUTED)
		l.position = Vector2(x + 30, 92)
		l.size = Vector2(30, 30)
		res.add_child(l)
	# left column: menu, speed, undo
	_side_button("ui_menu", "메뉴", Vector2(16, 96), _show_menu)
	speed_button = _side_button("ui_speed", "보통", Vector2(16, 192), func(): _set_speed([1, 2, 3, 0][speed_idx]))
	undo_button = _side_button("ui_undo", "취소", Vector2(16, 288), _undo)
	# bottom-right: the shop
	shop_button = Button.new()
	shop_button.text = "건설"
	shop_button.icon = Atlas.icon("ui_fac")
	shop_button.expand_icon = true
	shop_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	shop_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_button.add_theme_constant_override("icon_max_width", 84)
	shop_button.texture_filter = _icon_filter("ui_fac")
	shop_button.position = Vector2(W - 166, H - 160)
	shop_button.size = Vector2(150, 144)
	UIKit.style_button(shop_button, "primary", 28, 16)
	shop_button.pressed.connect(_open_shop)
	add_child(shop_button)
	done_button = Button.new()
	done_button.text = "완료"
	done_button.expand_icon = true
	done_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	done_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	done_button.add_theme_constant_override("icon_max_width", 72)
	done_button.size = Vector2(150, 144)
	UIKit.style_button(done_button, "selected", 28, 16)
	done_button.visible = false
	done_button.pressed.connect(func():
		SoundManager.play("click")
		_end_build())
	add_child(done_button)


func _explain_warnings() -> void:
	## The first time a kind of warning shows up, say what the bubble means.
	if city == null:
		return
	var texts := {
		"broken": "빨갛게 깜빡이는 도로는 고속도로와 끊긴 도로예요. 화면 왼쪽 끝 고속도로와 이어 주세요",
		"road": "끊긴 도로 말풍선: 고속도로와 이어진 도로가 2칸 안에 없어서 건물이 못 지어져요",
		"power": "번개 말풍선: 전기가 안 닿아요. '건설' → '시설'에서 발전소를 지어요",
		"water": "물방울 말풍선: 물이 안 닿아요. '건설' → '시설'에서 급수탑을 지어요",
	}
	for i in City.CELLS:
		var w := map.warning_of(i)
		if city.obj[i] == Defs.ROAD and city.connected[i] == 0 and city.is_active(i):
			w = "broken"
		if w != "" and not warned.has(w):
			warned[w] = true
			_toast(texts[w], "info")


func _update_hud() -> void:
	if city == null:
		return
	money_label.text = UIKit.money(city.money)
	money_label.add_theme_color_override("font_color", UIKit.GOLD if city.money >= 0 else UIKit.RED)
	var net := city.last_income - city.last_expense
	delta_label.text = "월 %s%s" % ["+" if net >= 0 else "", UIKit.money(net)] if city.month > 0 else "월 수입 —"
	delta_label.add_theme_color_override("font_color", UIKit.GREEN if net >= 0 else UIKit.RED)
	var date := "%d년  %d월" % [mini(city.year(), Defs.YEARS), city.month_of_year()] if not city.finished else "%d년 완료" % Defs.YEARS
	if city.event_key != "":
		for e in Defs.EVENTS:
			if e["key"] == city.event_key:
				date += "  · %s" % e["name"]
	date_label.text = date
	pop_label.text = "인구 %s  ·  행복 %d" % [UIKit.format_number(city.pop), city.happiness]
	rank_label.text = Defs.RANKS[city.rank]["name"]
	if city.rank + 1 < Defs.RANKS.size():
		var parts: Array = []
		for g in city.rank_goals(city.rank + 1):
			parts.append("%s %s/%s" % [g[0], UIKit.format_number(g[1]), UIKit.format_number(g[2])])
		goals_label.text = "다음 '%s': %s" % [Defs.RANKS[city.rank + 1]["name"], "  ".join(parts)]
	else:
		goals_label.text = "최고 랭크예요! 점수를 더 올려 봐요"
	for k in 3:
		var d: float = city.demand[k + 1]
		var bar: ColorRect = demand_bars[k]
		var h := absf(d) * 17.0
		bar.position = Vector2(0, 17.0 - h if d >= 0 else 17.0)
		bar.size = Vector2(24, maxf(h, 2.0))
		bar.color = Defs.ZONE_COLORS[k + 1] if d >= 0 else Color(0.9, 0.3, 0.3)


func _set_speed(k: int) -> void:
	speed_idx = k
	speed_button.text = SPEED_NAMES[k]
	UIKit.style_button(speed_button, "selected" if k == 0 else "secondary", 17, 10)


func _update_context() -> void:
	if city == null:
		return
	undo_button.disabled = undo_op.is_empty() or undo_op.get("month", -1) != city.month
	shop_button.visible = build == Build.NONE
	done_button.visible = _drawing()
	build_ui.visible = build != Build.NONE and _has_preview()
	select_ui.visible = build == Build.NONE and map.selected >= 0 and city.can_bulldoze(map.selected)
	if select_ui.visible:
		var forest := city.obj[map.selected] == 0 and city.zone[map.selected] == Defs.Z.NONE
		demolish_button.text = "철거 %s" % UIKit.money(Defs.CLEAR_COST) if forest else "철거"
	_set_hint(_hint_text())


func _set_hint(text: String) -> void:
	## The advisor says the hint, unless a news message is showing right now.
	current_hint = text
	if toast_time <= 0.0:
		hint_label.text = text
		hint_label.add_theme_color_override("font_color", MSG_TEXT)


func _hint_text() -> String:
	match build:
		Build.FAC:
			var f := Defs.fac(fac_id)
			return "%s %s · %s\n건물을 끌어 옮기고, 초록 체크를 누르면 지어져요" % [f["name"], UIKit.money(f["cost"]), f["desc"]]
		Build.ROAD:
			return "도로 %s/칸 (다리 %s) · 손가락으로 그어서 그려요. 시작과 끝을 차례로 눌러도 돼요\n초록 체크로 짓고, 다 했으면 오른쪽 아래 '완료' · 맵 이동은 두 손가락" % [UIKit.money(Defs.ROAD_COST), UIKit.money(Defs.BRIDGE_COST)]
		Build.ZONE:
			return "%s 구역 %s/칸 · 손가락으로 네모를 그려요. 두 모서리를 차례로 눌러도 돼요\n초록 체크로 칠하고, 다 했으면 오른쪽 아래 '완료' · 맵 이동은 두 손가락" % [Defs.ZONE_NAMES[build_zone], UIKit.money(Defs.ZONE_COST)]
		Build.CLEAR:
			return "철거 (숲은 %s) · 치울 곳을 손가락으로 네모로 그려요. 돈은 돌려받지 못해요\n초록 체크로 치우고, 다 했으면 오른쪽 아래 '완료' · 맵 이동은 두 손가락" % UIKit.money(Defs.CLEAR_COST)
	if map.selected >= 0:
		return _cell_info(map.selected)
	return _advice()


func _advice() -> String:
	## What to do next, for the first minutes of a run.
	var has := {}
	for i in City.CELLS:
		if city.obj[i] >= 2:
			has[city.obj[i]] = true
	var zones := 0
	for i in City.CELLS:
		if city.zone[i] != Defs.Z.NONE:
			zones += 1
	if city.road_count < 14:
		return "도움말: 오른쪽 아래 '건설' → '도로'를 골라 왼쪽 고속도로 끝에서 이어 깔아요\n두 손가락(또는 마우스 휠)으로 확대, 끌어서 이동"
	if zones < 6:
		return "도움말: '건설'에서 '주거 구역'을 골라 도로 옆에 칠해요\n집이 생기면 '상업'·'공업'도 칠해요"
	var broken := 0
	for i in City.CELLS:
		if city.obj[i] == Defs.ROAD and city.connected[i] == 0 and city.is_active(i):
			broken += 1
	var no_power := 0
	var no_water := 0
	var no_road := 0
	for i in City.CELLS:
		match map.warning_of(i):
			"road":
				no_road += 1
			"power":
				no_power += 1
			"water":
				no_water += 1
	if broken > 0:
		return "빨갛게 깜빡이는 도로 %d칸이 고속도로와 끊겨 있어요\n화면 왼쪽 끝 고속도로와 도로로 이어 주세요" % broken
	if no_road >= 1:
		return "도로가 안 닿는 구역이 %d칸 있어요 (끊긴 도로 말풍선)\n고속도로와 이어진 도로가 2칸 안에 있어야 해요" % no_road
	if not has.has(2) or not has.has(3):
		return "도움말: '건설' → '시설'에서 발전소와 급수탑을 지어요\n전기와 물이 닿아야 건물이 자라요"
	if no_power >= 1 and no_power >= no_water:
		return "전기가 안 닿는 구역이 %d칸 있어요 (번개 말풍선)\n발전소를 하나 더 지어요" % no_power
	if no_water >= 1:
		return "물이 안 닿는 구역이 %d칸 있어요 (물방울 말풍선)\n급수탑을 하나 더 지어요" % no_water
	var top := 1
	for z in [2, 3]:
		if city.demand[z] > city.demand[top]:
			top = z
	if city.demand[top] > 0.3:
		return "%s 수요가 높아요! %s 구역을 더 칠해 봐요\n칸을 누르면 건물 정보를 볼 수 있어요" % [Defs.ZONE_NAMES[top], Defs.ZONE_NAMES[top]]
	return "칸을 누르면 정보를 봐요. 공원·나무로 지가를 올리면 건물이 커져요\n경찰서·소방서·학교·병원이 닿으면 행복과 지가가 올라요"


func _lot_reason(i: int) -> String:
	match map.warning_of(i):
		"road":
			return "고속도로와 이어진 도로가 2칸 안에 없어요"
		"power":
			return "전기가 안 닿아요. 발전소를 지어요"
		"water":
			return "물이 안 닿아요. 급수탑을 지어요"
	if city.demand[city.zone[i]] <= 0.0:
		return "%s 수요가 생기면 지어져요" % Defs.ZONE_NAMES[city.zone[i]]
	return "곧 건물이 지어져요"


func _cell_info(i: int) -> String:
	var k := city.kind_of(i)
	var head := ""
	if k != "":
		head = Defs.kind_name(k)
		if city.zone[i] != Defs.Z.NONE:
			head += " (%s %d단계)" % [Defs.ZONE_NAMES[city.zone[i]], city.level[i]]
	elif city.zone[i] != Defs.Z.NONE:
		head = "%s 구역 %s" % [Defs.ZONE_NAMES[city.zone[i]], "(공사 중)" if city.build[i] > 0 else "(빈 땅)"]
		if city.build[i] == 0:
			head += " — " + _lot_reason(i)
	elif city.obj[i] == Defs.ROAD:
		head = "도로" + ("" if city.connected[i] else " (고속도로와 안 이어짐)")
	else:
		head = ["풀밭", "물", "숲"][city.terrain[i]]
	var line2 := "지가 %d" % city.land[i]
	if city.zone[i] != Defs.Z.NONE:
		line2 += "  ·  도로 %s 전기 %s 물 %s" % ["○" if city.access_road[i] >= 0 else "×", "○" if city.power[i] else "×", "○" if city.water[i] else "×"]
		if city.level[i] > 0 and city.level[i] < 3:
			var need: int = Defs.LV_NEED[city.level[i] + 1]
			line2 += "  ·  다음 단계 지가 %d" % need
	return head + "\n" + line2


# ================================================================ shop
func _open_shop() -> void:
	if city == null or build != Build.NONE:
		return
	SoundManager.play("click")
	map.selected = -1
	_update_context()
	map.queue_redraw()
	_show_shop()


func _show_shop() -> void:
	## Shop window like base-builder games: tabs on top, picture cards below. Tap a card to place it.
	_close_modal()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_modal())
	modal_layer.add_child(dim)
	var win := Panel.new()
	win.add_theme_stylebox_override("panel", UIKit.window(16))
	win.size = BASE - Vector2(120, 80)
	win.position = ((Vector2(W, H) - win.size) * 0.5).round()
	win.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.add_child(win)
	var title := UIKit.outlined(UIKit.label("건설", 34, UIKit.GOLD), 6)
	title.position = Vector2(28, 14)
	title.size = Vector2(150, 60)
	win.add_child(title)
	for k in SHOP_TABS.size():
		var tab := Button.new()
		tab.text = SHOP_TABS[k][0]
		tab.position = Vector2(180 + k * 190, 16)
		tab.size = Vector2(176, 58)
		UIKit.style_button(tab, "selected" if k == shop_tab else "secondary", 22, 12)
		tab.pressed.connect(func():
			SoundManager.play("click")
			shop_tab = k
			_show_shop())
		win.add_child(tab)
	var close := _glyph_button("x")
	close.position = Vector2(win.size.x - 96, 12)
	close.pressed.connect(func():
		SoundManager.play("click")
		_close_modal())
	win.add_child(close)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.position = Vector2(24, 98)
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	win.add_child(grid)
	for item in SHOP_TABS[shop_tab][1]:
		grid.add_child(_shop_card(item[0], item[1]))


func _shop_card(kind: String, id: int) -> Button:
	var title := ""
	var icon := ""
	var price := ""
	var desc := ""
	var locked := false
	var done := false
	match kind:
		"road":
			title = "도로"
			icon = "ui_road"
			price = "%s/칸" % UIKit.money(Defs.ROAD_COST)
			desc = "끌어서 길게 그려요\n고속도로와 이어 주세요"
		"zone":
			title = "%s 구역" % Defs.ZONE_NAMES[id]
			icon = ZONE_ICONS[id]
			price = "%s/칸" % UIKit.money(Defs.ZONE_COST)
			desc = ["", "전기·물이 닿으면\n집이 지어져요", "가게가 생겨\n세금과 일자리", "공장이 생겨\n일자리가 늘어요"][id]
		"clear":
			title = "철거"
			icon = "ui_bulldoze"
			price = "무료 (숲 %s)" % UIKit.money(Defs.CLEAR_COST)
			desc = "네모로 골라\n한 번에 치워요"
		"fac":
			var f := Defs.fac(id)
			title = f["name"]
			icon = f["key"]
			price = UIKit.money(f["cost"])
			desc = f["desc"]
			locked = not city.unlocked(id)
			done = Defs.is_landmark(id) and city.has_landmark(id)
			if locked:
				price = "'%s'부터" % Defs.RANKS[int(f["rank"])]["name"]
			elif done:
				price = "완성"
	var b := Button.new()
	b.custom_minimum_size = Vector2(214, 250)
	UIKit.style_button(b, "secondary", 20, 12)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pic := TextureRect.new()
	pic.texture = Atlas.icon(icon)
	pic.custom_minimum_size = Vector2(110, 96)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.texture_filter = _icon_filter(icon)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pic)
	v.add_child(UIKit.outlined(UIKit.label(title, 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER), 4))
	v.add_child(UIKit.outlined(UIKit.label(price, 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 4))
	var d := UIKit.label(desc, 15, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(190, 0)
	v.add_child(d)
	if locked or done:
		b.modulate = Color(1, 1, 1, 0.5)
	b.pressed.connect(func():
		SoundManager.play("click")
		if locked:
			_toast("'%s' 랭크가 되면 지을 수 있어요" % Defs.RANKS[int(Defs.fac(id)["rank"])]["name"], "info")
		elif done:
			_toast("명소는 하나씩만 지을 수 있어요", "info")
		else:
			_begin_build(kind, id))
	return b


func _glyph_button(kind: String) -> Button:
	## Square cancel (red cross) or confirm (green check) button.
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 76)
	b.size = Vector2(84, 76)
	if kind == "ok":
		UIKit.style_raised(b, Color(0.42, 0.78, 0.2), Color(0.85, 1.0, 0.6), Color(0.15, 0.35, 0.05), 12)
	else:
		UIKit.style_button(b, "danger", 20, 12)
	var g := Glyph.new()
	g.kind = kind
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(g)
	return b


# ================================================================ placement
func _build_float_ui() -> void:
	build_ui = Control.new()
	build_ui.size = Vector2(200, 118)
	build_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	build_ui.visible = false
	add_child(build_ui)
	cost_label = UIKit.outlined(UIKit.label("", 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 6)
	cost_label.position = Vector2(-60, 0)
	cost_label.size = Vector2(320, 34)
	build_ui.add_child(cost_label)
	var cancel := _glyph_button("x")
	cancel.position = Vector2(10, 38)
	cancel.pressed.connect(func():
		SoundManager.play("click")
		if _drawing():
			_clear_preview()
			_refresh_ghost()
			_update_context()
		else:
			_end_build())
	build_ui.add_child(cancel)
	ok_button = _glyph_button("ok")
	ok_button.position = Vector2(106, 38)
	ok_button.pressed.connect(_confirm_build)
	build_ui.add_child(ok_button)
	select_ui = Control.new()
	select_ui.size = Vector2(160, 64)
	select_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	select_ui.visible = false
	add_child(select_ui)
	demolish_button = Button.new()
	demolish_button.size = Vector2(160, 60)
	UIKit.style_button(demolish_button, "danger", 22, 12)
	demolish_button.pressed.connect(_demolish_selected)
	select_ui.add_child(demolish_button)


func _begin_build(kind: String, id: int) -> void:
	_close_modal()
	map.selected = -1
	var center := _screen_to_cell(VIEW.get_center())
	if center < 0 or not city.is_active(center):
		var a := city.active_rect()
		center = City.idx(a.position.x + a.size.x / 2, a.position.y + a.size.y / 2)
	match kind:
		"fac":
			build = Build.FAC
			fac_id = id
			fac_cell = center
		"road":
			build = Build.ROAD
			done_button.icon = Atlas.icon("ui_road")
		"zone":
			build = Build.ZONE
			build_zone = id
			done_button.icon = Atlas.icon(ZONE_ICONS[id])
		"clear":
			build = Build.CLEAR
			done_button.icon = Atlas.icon("ui_bulldoze")
	_clear_preview()
	done_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map.overlay = _overlay_for_build()
	_refresh_ghost()
	_update_context()


func _end_build() -> void:
	build = Build.NONE
	if drag != "pan":
		drag = ""
	map.preview = {}
	map.ghost = ""
	map.ghost_cell = -1
	map.ghost_radius = 0
	map.ghost_roads = {}
	map.handle_cell = -1
	map.overlay = ""
	_update_context()
	map.queue_redraw()


func _drawing() -> bool:
	## Road, zone and demolish are drawn with the finger and stay on until '완료'.
	return build in [Build.ROAD, Build.ZONE, Build.CLEAR]


func _has_preview() -> bool:
	match build:
		Build.FAC:
			return true
		Build.ROAD:
			return not road_path.is_empty()
		Build.ZONE, Build.CLEAR:
			return rect_a >= 0
	return false


func _clear_preview() -> void:
	road_path = []
	rect_a = -1
	rect_b = -1


func _overlay_for_build() -> String:
	if build != Build.FAC:
		return ""
	match fac_id:
		2:
			return "power"
		3:
			return "water"
		7, 8, 9, 10:
			return "svc:%d" % Defs.SERVICE_BIT[fac_id]
	return "land"


func _offset_cell(i: int, d: Vector2i) -> int:
	var p := City.pos(i) + d
	return City.idx(clampi(p.x, 0, City.N - 1), clampi(p.y, 0, City.N - 1))


func _ghost_cells() -> Array:
	match build:
		Build.FAC:
			return [fac_cell]
		Build.ROAD:
			return road_path
		Build.ZONE, Build.CLEAR:
			return _rect_cells(rect_a, rect_b)
	return []


func _handle_cell() -> int:
	match build:
		Build.FAC:
			return fac_cell
		Build.ROAD:
			return road_path[-1] if not road_path.is_empty() else -1
		Build.ZONE, Build.CLEAR:
			return rect_b
	return -1


func _rect_cells(a: int, b: int) -> Array:
	if a < 0 or b < 0:
		return []
	var pa := City.pos(a)
	var pb := City.pos(b)
	var out: Array = []
	for y in range(mini(pa.y, pb.y), maxi(pa.y, pb.y) + 1):
		for x in range(mini(pa.x, pb.x), maxi(pa.x, pb.x) + 1):
			out.append(City.idx(x, y))
	return out


func _refresh_ghost() -> void:
	## Green/red ground, cost and whether the check button works, for where the ghost is now.
	if build == Build.NONE:
		return
	if not _has_preview():
		map.preview = {}
		map.ghost_roads = {}
		map.handle_cell = -1
		build_ok = false
		build_ui.visible = false
		map.queue_redraw()
		return
	build_ui.visible = true
	var pv := {}
	var total := 0
	var count := 0
	var reason := ""
	map.ghost = ""
	map.ghost_cell = -1
	map.ghost_radius = 0
	map.ghost_roads = {}
	match build:
		Build.FAC:
			var cost := city.facility_cost(fac_cell, fac_id)
			pv[fac_cell] = cost >= 0
			if cost >= 0:
				total = cost
				count = 1
			else:
				reason = "여기엔 지을 수 없어요"
			map.ghost = Defs.fac(fac_id)["key"]
			map.ghost_cell = fac_cell
			map.ghost_radius = int(Defs.fac(fac_id)["radius"]) if fac_id in [2, 3, 7, 8, 9, 10] else 0
		Build.ROAD:
			for c in road_path:
				var cost := city.road_cost(c)
				pv[c] = cost >= 0 or city.obj[c] == Defs.ROAD
				if pv[c]:
					map.ghost_roads[c] = true
				if cost >= 0:
					total += cost
					count += 1
			if count == 0:
				reason = "끌거나 끝 칸을 눌러 이어요" if road_path.size() == 1 else "도로를 놓을 수 있는 칸이 없어요"
		Build.ZONE:
			for c in _rect_cells(rect_a, rect_b):
				var cost := city.zone_cost(c, build_zone)
				if cost < 0 and city.zone[c] == build_zone:
					continue                # already this zone: leave it alone
				pv[c] = cost >= 0
				if cost >= 0:
					total += cost
					count += 1
			if count == 0:
				reason = "칠할 수 있는 칸이 없어요"
		Build.CLEAR:
			for c in _rect_cells(rect_a, rect_b):
				if city.can_bulldoze(c):
					pv[c] = true
					count += 1
					if city.obj[c] == 0 and city.zone[c] == Defs.Z.NONE:
						total += Defs.CLEAR_COST
			if count == 0:
				reason = "치울 것이 없어요"
	if reason == "" and total > city.money:
		reason = "돈이 부족해요 (%s)" % UIKit.money(total)
	build_ok = reason == ""
	map.preview = pv
	match build:
		Build.CLEAR:
			map.preview_ok = Color(1.0, 0.6, 0.2, 0.5)
		Build.ROAD:
			map.preview_ok = Color(0.4, 1.0, 0.5, 0.15)    # light, so the road picture shows through
		_:
			map.preview_ok = Color(0.4, 1.0, 0.5, 0.45)
	map.handle_cell = _handle_cell()
	ok_button.disabled = not build_ok
	ok_button.modulate = Color.WHITE if build_ok else Color(1, 1, 1, 0.55)
	if reason != "":
		cost_label.text = reason
	elif build == Build.FAC:
		cost_label.text = UIKit.money(total)
	elif build == Build.CLEAR:
		cost_label.text = "%d칸 철거%s" % [count, "  %s" % UIKit.money(total) if total > 0 else ""]
	else:
		cost_label.text = "%d칸  %s" % [count, UIKit.money(total)]
	var just_hint := build == Build.ROAD and road_path.size() == 1 and count == 0
	cost_label.add_theme_color_override("font_color", UIKit.GOLD if build_ok else (UIKit.TEXT if just_hint else UIKit.RED))
	map.queue_redraw()


func _cell_screen(i: int) -> Vector2:
	return world.position + map.cell_center(i) * zoom


func _ghost_top(i: int, key: String) -> float:
	## Screen y of the top of a building picture standing on cell i.
	var t := Art.tex(key) if key != "" else null
	var c := _cell_screen(i)
	if t == null:
		return c.y - MapView.HH * zoom
	return c.y + (MapView.HH * MapView.FOOT - t.get_size().y / MapView.DETAIL) * zoom


func _place_float_ui() -> void:
	## Keep the cancel/confirm buttons over the ghost (and the demolish button over a tapped cell).
	var floor_y := toast_panel.position.y - 8        # stay above the advisor bar
	if build_ui.visible:
		# over the tile the finger works on: the building, the end of the road, the box corner
		var h := _handle_cell()
		var p := _cell_screen(h)
		var top := p.y - (MapView.HH + 22.0) * zoom     # room for the drag arrows
		if build == Build.FAC:
			top = minf(top, _ghost_top(fac_cell, map.ghost))
		var at := Vector2(p.x - build_ui.size.x * 0.5, top - build_ui.size.y - 6)
		if at.y < TOP_SAFE:
			at.y = p.y + (MapView.HH + 22.0) * zoom + 6
		at.x = clampf(at.x, 110, W - build_ui.size.x - 8)
		at.y = clampf(at.y, TOP_SAFE, floor_y - build_ui.size.y)
		build_ui.position = at.round()
	if select_ui.visible:
		var p := _cell_screen(map.selected)
		var key := map.sprite_for(map.selected)
		var at := Vector2(p.x - select_ui.size.x * 0.5, _ghost_top(map.selected, key) - select_ui.size.y - 6)
		at.x = clampf(at.x, 110, W - select_ui.size.x - 8)
		at.y = clampf(at.y, TOP_SAFE, floor_y - select_ui.size.y)
		select_ui.position = at.round()


func _confirm_build() -> void:
	if build == Build.NONE or not build_ok:
		return
	_begin_edit()
	var at := _handle_cell()
	match build:
		Build.FAC:
			_record(fac_cell)
			var cost := city.place_facility(fac_cell, fac_id)
			if cost < 0:
				stroke_changes.erase(fac_cell)
				stroke_failed = true
			else:
				stroke_spent += cost
		Build.ROAD:
			for c in road_path:
				_road_at(c)
		Build.ZONE:
			for c in _rect_cells(rect_a, rect_b):
				if city.zone_cost(c, build_zone) >= 0:
					_record(c)
					var cost := city.place_zone(c, build_zone)
					if cost < 0:
						stroke_changes.erase(c)
						stroke_failed = true
					else:
						stroke_spent += cost
		Build.CLEAR:
			for c in _rect_cells(rect_a, rect_b):
				if city.can_bulldoze(c):
					_record(c)
					var cost := city.bulldoze(c)
					if cost < 0:
						stroke_changes.erase(c)
						stroke_failed = true
					else:
						stroke_spent += cost
	var kind := build
	if _drawing():
		_clear_preview()        # keep drawing; '완료' ends it
	else:
		_end_build()
	_finish_edit("bulldoze" if kind == Build.CLEAR else "place", at)


func _demolish_selected() -> void:
	var c := map.selected
	if city == null or c < 0 or not city.can_bulldoze(c):
		return
	_begin_edit()
	_record(c)
	var cost := city.bulldoze(c)
	if cost < 0:
		stroke_changes.erase(c)
		stroke_failed = true
	else:
		stroke_spent += cost
	map.selected = -1
	_finish_edit("bulldoze", c)


func _begin_edit() -> void:
	stroke_changes = {}
	stroke_spent = 0
	stroke_failed = false


func _record(i: int) -> void:
	if not stroke_changes.has(i):
		stroke_changes[i] = city.cell_state(i)


func _finish_edit(sound: String, at: int) -> void:
	if not stroke_changes.is_empty():
		undo_op = {"changes": stroke_changes, "spent": stroke_spent, "month": city.month}
		city.refresh()
		SoundManager.play(sound)
		if stroke_spent > 0 and at >= 0:
			fx.pop_text(map.cell_center(at), "-" + UIKit.money(stroke_spent), UIKit.RED)
	elif stroke_failed:
		SoundManager.play("invalid")
	if stroke_failed and city.money < 50:
		_toast("돈이 부족해요. 시간이 지나면 세금이 들어와요", "bad")
	stroke_changes = {}
	_after_edit()


func _undo() -> void:
	if undo_op.is_empty() or undo_op["month"] != city.month:
		return
	SoundManager.play("click")
	var changes: Dictionary = undo_op["changes"]
	for c in changes:
		city.set_cell_state(c, changes[c])
	city.money += int(undo_op["spent"])
	undo_op = {}
	city.refresh()
	_after_edit()


func _road_at(cell: int) -> void:
	if cell < 0:
		return
	if city.road_cost(cell) < 0:
		if city.obj[cell] != Defs.ROAD:
			stroke_failed = true
		return
	_record(cell)
	var cost := city.place_road(cell)
	if cost < 0:
		stroke_changes.erase(cell)
		stroke_failed = true
	else:
		stroke_spent += cost


func _extend_path(target: int) -> void:
	## Road drawing: from where the drag began to the finger as a straight line with at most one
	## bend (the first way the finger went decides which side the bend is on). Going back over the
	## path shortens it.
	var k := road_base.find(target)
	if k >= 0:
		road_path = road_base.slice(0, k + 1)
		if k == road_base.size() - 1:
			road_axis = -1
		return
	var a := City.pos(road_base[-1])
	var b := City.pos(target)
	if road_axis < 0:
		road_axis = 0 if absi(b.x - a.x) >= absi(b.y - a.y) else 1
	var corner := Vector2i(b.x, a.y) if road_axis == 0 else Vector2i(a.x, b.y)
	road_path = road_base.duplicate()
	for goal in [corner, b]:
		while a != goal and road_path.size() < MAX_PATH:
			a += Vector2i(signi(goal.x - a.x), signi(goal.y - a.y))
			var c := City.idx(a.x, a.y)
			var j := road_path.find(c)
			if j >= 0:
				road_path.resize(j + 1)
			else:
				road_path.append(c)


func _shift_ghost(d: Vector2i) -> bool:
	## Move the whole ghost by d cells; false (and no move) if it would leave the map.
	var cells: Array = road_path if build == Build.ROAD else ([fac_cell] if build == Build.FAC else [rect_a, rect_b])
	var moved_cells: Array = []
	for c in cells:
		var p: Vector2i = City.pos(c) + d
		if not City.inside(p.x, p.y):
			return false
		moved_cells.append(City.idx(p.x, p.y))
	match build:
		Build.FAC:
			fac_cell = moved_cells[0]
		Build.ROAD:
			road_path = moved_cells
		Build.ZONE, Build.CLEAR:
			rect_a = moved_cells[0]
			rect_b = moved_cells[1]
	return true


func _drag_ghost() -> void:
	var target := _screen_to_cell(finger + drag_offset)
	if target < 0 or target == drag_cell:
		return
	match drag:
		"extend":
			_extend_path(target)
		"resize":
			var pa := City.pos(rect_a)
			var pt := City.pos(target)
			pt.x = clampi(pt.x, pa.x - MAX_RECT + 1, pa.x + MAX_RECT - 1)
			pt.y = clampi(pt.y, pa.y - MAX_RECT + 1, pa.y + MAX_RECT - 1)
			rect_b = City.idx(pt.x, pt.y)
		"move":
			if not _shift_ghost(City.pos(target) - City.pos(drag_cell)):
				return
		_:
			return
	drag_cell = target
	_refresh_ghost()


func _hits(p: Vector2, cell: int, tall: bool) -> bool:
	## Is the finger on this cell (or on the building standing on it)? A little generous for fingers.
	if cell < 0:
		return false
	var d := p - _cell_screen(cell)
	var hw := maxf(MapView.HW * zoom, 40.0)
	var hh := maxf(MapView.HH * zoom, 28.0)
	var up := hh
	if tall:
		up = maxf(up, _cell_screen(cell).y - _ghost_top(cell, map.ghost))
	return absf(d.x) <= hw and d.y >= -up and d.y <= hh


# ================================================================ toast and popups
func _build_toast() -> void:
	## Bottom message bar with the town advisor, like pocket management games: hints and news.
	toast_panel = PanelContainer.new()
	var sb := UIKit.box(Color(0.86, 0.95, 0.74, 0.95), Color(0.36, 0.56, 0.26), 10, 3)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 4
	toast_panel.add_theme_stylebox_override("panel", sb)
	toast_panel.position = Vector2(16, H - 116)
	toast_panel.size = Vector2(900, 104)
	toast_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(toast_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	toast_panel.add_child(row)
	var face := TextureRect.new()
	face.texture = Art.tex("advisor")
	face.custom_minimum_size = Vector2(88, 88)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(face)
	toast_label = UIKit.label("", 19, MSG_TEXT)
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size = Vector2(770, 88)
	toast_label.add_theme_constant_override("line_spacing", -2)
	row.add_child(toast_label)
	hint_label = toast_label


func _toast(text: String, kind: String = "info") -> void:
	if kind in ["event", "bad"]:
		SoundManager.play("notice")
	toast_queue.append([text, kind])
	if toast_queue.size() > 4:
		toast_queue.pop_front()
	if toast_time <= 0.0:
		_next_toast()


func _next_toast() -> void:
	if toast_queue.is_empty():
		toast_time = 0.0
		hint_label.text = current_hint
		hint_label.add_theme_color_override("font_color", MSG_TEXT)
		return
	var t: Array = toast_queue.pop_front()
	var col: Color = {"good": Color(0.1, 0.45, 0.12), "bad": Color(0.7, 0.12, 0.1), "event": Color(0.7, 0.4, 0.0)}.get(t[1], MSG_TEXT)
	toast_label.text = t[0]
	toast_label.add_theme_color_override("font_color", col)
	toast_time = 3.5


func _modal_open() -> bool:
	return modal_layer.get_child_count() > 0


func _close_modal() -> void:
	for c in modal_layer.get_children():
		c.queue_free()
		modal_layer.remove_child(c)


func _show_modal(title: String, body: String, buttons: Array, extra: Control = null) -> void:
	## buttons: [[text, kind, callable], ...]; every button closes the popup first.
	_close_modal()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_layer.add_child(dim)
	var card := PanelContainer.new()
	var sb := UIKit.window(16)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 26
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(640, 0)
	dim.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	card.add_child(col)
	var t := UIKit.outlined(UIKit.label(title, 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 6)
	col.add_child(t)
	if body != "":
		var b := UIKit.label(body, 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(580, 0)
		col.add_child(b)
	if extra != null:
		col.add_child(extra)
	if not buttons.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 14)
		col.add_child(row)
		for spec in buttons:
			var btn := Button.new()
			btn.text = spec[0]
			btn.custom_minimum_size = Vector2(180 if buttons.size() > 2 else 230, 68)
			UIKit.style_button(btn, spec[1], 24, 12)
			var cb: Callable = spec[2]
			btn.pressed.connect(func():
				SoundManager.play("click")
				_close_modal()
				cb.call())
			row.add_child(btn)
	# center once the card knows its size
	card.position = Vector2((W - 640) / 2.0, 300)
	await get_tree().process_frame
	if is_instance_valid(card):
		card.position = Vector2((W - card.size.x) / 2.0, maxf(60.0, (H - card.size.y) / 2.0))


func _show_menu() -> void:
	if city == null:
		return
	SoundManager.play("click")
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var tax_btn := Button.new()
	tax_btn.custom_minimum_size = Vector2(560, 64)
	UIKit.style_button(tax_btn, "secondary", 22, 12)
	var tax_text := func(): return "세금: %s  (낮음 = 수요↑ 수입↓, 높음 = 반대)" % Defs.TAX_NAMES[city.tax]
	tax_btn.text = tax_text.call()
	tax_btn.pressed.connect(func():
		SoundManager.play("click")
		city.tax = (city.tax + 1) % 3
		city.refresh()
		tax_btn.text = tax_text.call()
		_after_edit())
	box.add_child(tax_btn)
	var land_btn := Button.new()
	land_btn.custom_minimum_size = Vector2(560, 64)
	UIKit.style_button(land_btn, "secondary", 22, 12)
	land_btn.text = "지가 지도 보기" if map.overlay != "land" else "지가 지도 끄기"
	land_btn.pressed.connect(func():
		var show := land_btn.text == "지가 지도 보기"
		_end_build()
		map.selected = -1
		map.overlay = "land" if show else ""
		_update_context()
		map.queue_redraw()
		_close_modal())
	box.add_child(land_btn)
	var snd := Button.new()
	snd.custom_minimum_size = Vector2(560, 64)
	UIKit.style_button(snd, "secondary", 22, 12)
	snd.text = "소리 켜기" if SoundManager.muted else "소리 끄기"
	snd.pressed.connect(func():
		SoundManager.muted = not SoundManager.muted
		meta["muted"] = SoundManager.muted
		_save_meta()
		snd.text = "소리 켜기" if SoundManager.muted else "소리 끄기")
	box.add_child(snd)
	_show_modal("메뉴", "", [["타이틀로", "secondary", _to_title], ["계속하기", "primary", func(): pass]], box)


func _to_title() -> void:
	if city != null and not city.finished:
		_save_game()
	_end_build()
	city = null
	_show_title()


# ================================================================ city signals
func _on_built(cell: int) -> void:
	SoundManager.play("build")
	fx.burst(map.cell_center(cell), Color(1, 1, 1), 0.5)


func _on_burned(cell: int) -> void:
	map.fires[cell] = 2.5
	SoundManager.play("bulldoze")


func _on_shop_visit(cell: int) -> void:
	if VIEW.has_point(world.get_transform() * map.cell_center(cell)):
		fx.pop_text(map.cell_center(cell), "", UIKit.GOLD, true)
		SoundManager.play("coin")


func _on_rank_up(r: int) -> void:
	SoundManager.play("rankup")
	var unlocks: Array = []
	for id in Defs.FAC_ORDER:
		if int(Defs.fac(id)["rank"]) == r:
			unlocks.append(Defs.fac(id)["name"])
	var size := Defs.rank_size(r)
	var body := "땅이 %d×%d로 넓어졌어요" % [size, size]
	if not unlocks.is_empty():
		body += "\n새 시설: " + ", ".join(unlocks)
	_show_modal("'%s'(으)로 성장했어요!" % Defs.RANKS[r]["name"], body, [["좋아요", "primary", func(): pass]])
	_after_edit()


func _on_month_passed(income: int, expense: int) -> void:
	var net := income - expense
	year_net += net
	fx.pop_text(world.get_transform().affine_inverse() * Vector2(W - 170, 100), "%s%s" % ["+" if net >= 0 else "", UIKit.money(net)], UIKit.GREEN if net >= 0 else UIKit.RED)
	_save_game()


func _on_year_end(y: int) -> void:
	SoundManager.play("yearend")
	var pop_gain := city.pop - int(year_start.get("pop", 0))
	var net := year_net
	year_net = 0
	year_start = {"pop": city.pop, "money": city.money}
	var headline := "조용하지만 차분한 한 해였어요"
	if pop_gain >= 300:
		headline = "인구 %s명 증가! 도시가 쑥쑥 자라요" % UIKit.format_number(pop_gain)
	elif net >= 3000:
		headline = "흑자 %s! 살림이 넉넉해요" % UIKit.money(net)
	elif net < 0:
		headline = "올해 살림은 적자였어요. 세금이나 유지비를 살펴봐요"
	elif pop_gain > 0:
		headline = "새 주민 %s명이 이사 왔어요" % UIKit.format_number(pop_gain)
	var body := "「%s」\n인구 %s (%s%s)  ·  1년 수지 %s%s\n행복 %d\n\n내년 정책을 하나 골라요" % [
		headline, UIKit.format_number(city.pop), "+" if pop_gain >= 0 else "", UIKit.format_number(pop_gain),
		"+" if net >= 0 else "", UIKit.money(net), city.happiness]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for p in city.policy_choices():
		var b := Button.new()
		b.custom_minimum_size = Vector2(186, 200)
		UIKit.style_button(b, "secondary", 19, 12)
		var v := VBoxContainer.new()
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 12)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		v.add_child(UIKit.outlined(UIKit.label(p["name"], 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER), 4))
		var desc := UIKit.label(p["text"], 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(desc)
		var key: String = p["key"]
		b.pressed.connect(func():
			SoundManager.play("click")
			city.choose_policy(key)
			_close_modal()
			_toast("정책 '%s'을(를) 골랐어요" % p["name"], "good")
			_save_game()
			_after_edit())
		row.add_child(b)
	_show_modal("%d년차 결산" % y, body, [], row)


func _on_finished(score: int) -> void:
	SoundManager.play("rankup")
	var is_best := false
	if city.mode == "daily":
		var today := _today()
		if score > int(meta["best_daily"].get(today, 0)):
			meta["best_daily"][today] = score
			is_best = true
	if score > int(meta["best"]):
		meta["best"] = score
		is_best = true
	_save_meta()
	_delete_save()
	var lines: Array = []
	for p in city.score_parts():
		lines.append("%s %s → %s점" % [p[0], UIKit.format_number(p[1]), UIKit.format_number(p[2])])
	var body := "\n".join(lines) + "\n\n도시 점수 %s%s" % [UIKit.format_number(score), "  (최고 기록!)" if is_best else ""]
	var mode := city.mode
	_show_modal("%d년 완료!" % Defs.YEARS, body, [
		["구경하기", "secondary", func(): pass],
		["새 도시", "primary", func(): _start_game(mode)],
		["타이틀", "secondary", _to_title],
	])


# ================================================================ frame loop
func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		if toast_time <= 0.0:
			_next_toast()
	if city == null or title_screen.visible:
		walkers.speed = 0.0
		return
	_auto_pan(delta)
	_place_float_ui()
	var running := not _modal_open() and not city.finished
	var spd: float = Defs.SPEEDS[speed_idx] if running else 0.0
	walkers.speed = spd if not city.finished else 1.0
	if spd <= 0.0:
		return
	week_timer += delta * spd
	var step := Defs.MONTH_SECONDS / Defs.WEEKS
	if week_timer >= step:
		week_timer -= step
		city.step_week()
		_after_edit()


func _auto_pan(delta: float) -> void:
	## Dragging a ghost to the screen edge moves the map, so long roads fit in one drag.
	if not pressing or drag in ["", "pan"]:
		return
	var v := Vector2.ZERO
	if finger.x < EDGE:
		v.x = -1.0
	elif finger.x > W - EDGE:
		v.x = 1.0
	if finger.y < EDGE:
		v.y = -1.0
	elif finger.y > H - EDGE:
		v.y = 1.0
	if v == Vector2.ZERO:
		return
	cam += v * EDGE_SPEED * delta / zoom
	_apply_camera()
	_drag_ghost()


func _after_edit() -> void:
	_explain_warnings()
	_refresh_ghost()
	map.queue_redraw()
	walkers.city_changed()
	_update_hud()
	_update_context()


# ================================================================ camera
func _apply_camera() -> void:
	if city == null:
		return
	var a := city.active_rect()
	var b := map.active_bounds()
	cam = cam.clamp(b.position, b.end)
	world.scale = Vector2(zoom, zoom)
	# sprites are stored at 2x: below zoom 2 they are shrunk, so smooth them; at 2 and up keep hard pixels
	world.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if zoom < 1.99 else CanvasItem.TEXTURE_FILTER_NEAREST
	world.position = (VIEW.get_center() - cam * zoom).round()
	fx.queue_redraw()


func _screen_to_map(p: Vector2) -> Vector2:
	return (p - world.position) / zoom


func _screen_to_cell(p: Vector2) -> int:
	var m := _screen_to_map(p)
	return map.cell_at(m)


func _zoom_at(screen: Vector2, new_zoom: float) -> void:
	var anchor := _screen_to_map(screen)
	zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	cam = anchor - (screen - VIEW.get_center()) / zoom
	_apply_camera()


# ================================================================ input
func _unhandled_input(event: InputEvent) -> void:
	## One finger: drag the ghost (or its arrows) to change it, drag anywhere else to move the map,
	## tap to look at a cell (or to move the ghost there). Two fingers: zoom and move.
	if city == null or title_screen.visible or _modal_open():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and VIEW.has_point(st.position):
			touches[st.index] = st.position
		elif not st.pressed:
			touches.erase(st.index)
		if touches.size() >= 2 and not multi_touch:
			_begin_pinch()
		elif touches.is_empty() and multi_touch:
			multi_touch = false
			_zoom_at(VIEW.get_center(), roundf(zoom))
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if touches.has(sd.index):
			touches[sd.index] = sd.position
			if multi_touch:
				_update_pinch()
		return
	if multi_touch:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			if VIEW.has_point(mb.position):
				_zoom_at(mb.position, roundf(zoom) + (1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0))
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			panning = mb.pressed and VIEW.has_point(mb.position)
			pan_last = mb.position
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and VIEW.has_point(mb.position):
				_press(mb.position)
			elif not mb.pressed:
				_release(mb.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if panning:
			cam -= (mm.position - pan_last) / zoom
			pan_last = mm.position
			_apply_camera()
		elif pressing:
			_drag_to(mm.position)


func _begin_pinch() -> void:
	if pressing and drew_new:
		road_path = before_press["road"]
		rect_a = before_press["a"]
		rect_b = before_press["b"]
		_refresh_ghost()
	pressing = false
	drag = ""
	multi_touch = true
	var pts: Array = touches.values()
	pinch_dist = maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
	pinch_zoom = zoom
	pinch_anchor = _screen_to_map(((pts[0] as Vector2) + pts[1]) * 0.5)


func _update_pinch() -> void:
	var pts: Array = touches.values()
	if pts.size() < 2:
		return
	var mid: Vector2 = ((pts[0] as Vector2) + pts[1]) * 0.5
	var d := maxf(1.0, (pts[0] as Vector2).distance_to(pts[1]))
	zoom = clampf(pinch_zoom * d / pinch_dist, MIN_ZOOM, MAX_ZOOM)
	cam = pinch_anchor - (mid - VIEW.get_center()) / zoom
	_apply_camera()


func _press(p: Vector2) -> void:
	pressing = true
	moved = false
	press_pos = p
	finger = p
	drag = "pan"
	if build == Build.NONE:
		return
	var cell := _screen_to_cell(p)
	drew_new = false
	before_press = {"road": road_path.duplicate(), "a": rect_a, "b": rect_b}
	if build == Build.FAC:
		if _hits(p, fac_cell, true):
			drag = "move"
			drag_cell = fac_cell
	elif _has_preview() and _hits(p, _handle_cell(), false):
		drag = "extend" if build == Build.ROAD else "resize"
		drag_cell = _handle_cell()
		road_base = road_path.duplicate()
		road_axis = -1
	elif build != Build.ROAD and cell >= 0 and cell in _ghost_cells():
		drag = "move"
		drag_cell = cell
	elif cell >= 0:
		# start a new road / box right under the finger
		drew_new = true
		drag_cell = cell
		if build == Build.ROAD:
			drag = "extend"
			road_path = [cell]
			road_base = [cell]
			road_axis = -1
		else:
			drag = "resize"
			rect_a = cell
			rect_b = cell
		_refresh_ghost()
		_update_context()
	if drag != "pan":
		drag_offset = _cell_screen(drag_cell) - p


func _drag_to(p: Vector2) -> void:
	if not moved and p.distance_to(press_pos) > 12.0:
		moved = true
	if drag == "pan":
		if moved:
			cam -= (p - finger) / zoom
			_apply_camera()
			finger = p
		return
	finger = p
	_drag_ghost()


func _release(p: Vector2) -> void:
	if not pressing:
		return
	pressing = false
	if not moved:
		_tap(p)
	drag = ""


func _tap(p: Vector2) -> void:
	var cell := _screen_to_cell(p)
	if build == Build.NONE:
		map.selected = cell if cell >= 0 and map.selected != cell else -1
		SoundManager.play("click")
		_update_context()
		map.queue_redraw()
		return
	if _drawing():
		# tapping a second cell after a one-cell start makes the road / box between the two
		var prev: Array = before_press["road"]
		var a0: int = before_press["a"]
		var one := prev.size() == 1 if build == Build.ROAD else (a0 >= 0 and a0 == int(before_press["b"]))
		var start: int = (prev[0] if build == Build.ROAD else a0) if one else -1
		if drew_new and one and cell >= 0 and cell != start:
			if build == Build.ROAD:
				road_base = prev.duplicate()
				road_axis = -1
				_extend_path(cell)
			else:
				rect_a = start
				var pa := City.pos(start)
				var pt := City.pos(cell)
				rect_b = City.idx(clampi(pt.x, pa.x - MAX_RECT + 1, pa.x + MAX_RECT - 1), clampi(pt.y, pa.y - MAX_RECT + 1, pa.y + MAX_RECT - 1))
			_refresh_ghost()
		SoundManager.play("click")
		return
	# tapping somewhere else moves the building there
	if cell < 0 or (build == Build.FAC and _hits(p, fac_cell, true)):
		return
	fac_cell = cell
	SoundManager.play("click")
	_refresh_ghost()
