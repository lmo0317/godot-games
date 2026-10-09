extends Control
## Game screen (landscape), laid out like the classic base-builder:
##   village   level and trophies top-left, builders top-middle, gold / elixir / gems bars top-right,
##             Attack bottom-left, Shop bottom-right; a tapped building shows its name and a row of
##             round buttons at the bottom (info, upgrade, collect, train, finish now, ...)
##   attack    goblin campaign maps or a generated opponent; troops bar at the bottom, time at the
##             top, stars and destruction bottom-right, loot top-left; result screen at the end
## Rules live in Village and Battle; this script turns input into their calls and draws the windows.

const BASE := Vector2(1280, 720)
const SAVE_PATH := "user://village.json"
const MIN_ZOOM := 0.45
const MAX_ZOOM := 2.0
const START_ZOOM := 0.9
const HOLD_MS := 220                    # hold this long in battle to drop troops in a stream
const STREAM_GAP := 0.12
const SCOUT_TIME := 30.0
const DARK := Color(0.106, 0.094, 0.149)
const PAPER_TEXT := Color(0.29, 0.22, 0.14)

var W := BASE.x
var H := BASE.y

var village: Village
var world: Node2D
var view: IsoView
var zoom := START_ZOOM
var cam := Vector2.ZERO                 # map pixel at the screen middle
var mode := "village"                   # village, battle, result

# village selection / placement
var sel_kind := ""                      # "b" building, "o" obstacle
var sel_id := -1
var placing := {}                       # {type, x, y, ok, last: Vector2i}
var moving := {}                        # {id, x, y, from: Vector2i}
var tick_timer := 0.0
var save_timer := 0.0

# battle
var battle: Battle
var battle_kind := ""                   # "campaign" or "multi"
var battle_map := -1
var battle_loot := {}
var battle_trophies := [0, 0]           # win / lose
var troop_pick := ""
var used := {}
var scout := SCOUT_TIME
var sim_acc := 0.0
var stream_t := 0.0
var search_seed := 0

# pointer
var pressing := false
var moved := false
var press_pos := Vector2.ZERO
var press_ms := 0
var finger := Vector2.ZERO
var drag := ""                          # pan, ghost, move, stream
var drag_grab := Vector2.ZERO
var touches := {}
var pinch_dist := 1.0
var pinch_zoom := 1.0

# UI
var hud: Control
var level_label: Label
var xp_bar: ColorRect
var name_label: Label
var trophy_label: Label
var builder_label: Label
var res_rows := {}                      # res -> {label, fill, max}
var attack_button: Button
var shop_button: Button
var sel_bar: Control
var sel_title: Label
var sel_buttons: HBoxContainer
var place_bar: Control
var place_ok: Button
var toast_label: Label
var toast_time := 0.0
var modal: Control
var bhud: Control                       # battle HUD
var b_time: Label
var b_time_title: Label
var b_loot: Label
var b_stars: Label
var b_percent: Label
var b_bar: HBoxContainer
var b_end: Button
var b_next: Button
var b_cards := {}


class RoundButton:
	## Round action button under a selected building: a shaded cream disc with a dark rim and a gold
	## ring, a big icon, the caption below the disc and an optional price tag on top.
	extends Button
	const INK := Color(0.106, 0.094, 0.149)
	var pic: Texture2D
	var caption := ""
	var price := ""
	var price_icon: Texture2D
	var info := false
	var tint := Color(0.99, 0.96, 0.88)

	func _init() -> void:
		flat = true
		custom_minimum_size = Vector2(112, 136)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _disc(c: Vector2, r: float, top: Color, bottom: Color) -> void:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 40:
			var p := c + Vector2.from_angle(TAU * i / 40.0) * r
			pts.append(p)
			cols.append(top.lerp(bottom, clampf((p.y - (c.y - r)) / (2.0 * r), 0.0, 1.0)))
		draw_polygon(pts, cols)

	func _oval(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 32:
			pts.append(c + Vector2(cos(TAU * i / 32.0) * rx, sin(TAU * i / 32.0) * ry))
		draw_colored_polygon(pts, col)

	func _draw() -> void:
		var down := is_pressed()
		var c := Vector2(size.x * 0.5, 56 + (3 if down else 0))
		var r := 42.0 if not down else 40.0
		if not down:
			draw_circle(c + Vector2(0, 6), r + 5, Color(0, 0, 0, 0.3))
		draw_circle(c, r + 5, INK)
		_disc(c, r + 1, Color(1.0, 0.86, 0.45), Color(0.72, 0.48, 0.16))
		_disc(c, r - 4, tint.lightened(0.3), tint.darkened(0.2))
		_oval(c - Vector2(0, r * 0.45), r * 0.62, r * 0.3, Color(1, 1, 1, 0.45))
		if info:
			draw_circle(c, 25, INK)
			_disc(c, 22, Color(0.45, 0.78, 1.0), Color(0.16, 0.45, 0.85))
			var fi := UIKit.FONT
			var iw := fi.get_string_size("i", HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x
			draw_string_outline(fi, c + Vector2(-iw * 0.5, 13), "i", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, 6, INK)
			draw_string(fi, c + Vector2(-iw * 0.5, 13), "i", HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Color.WHITE)
		elif pic != null:
			var s := 64.0 if price == "" else 54.0
			var at := c if price == "" else c + Vector2(0, 6)
			draw_texture_rect(pic, Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s)), false)
		var f := UIKit.FONT
		var w := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		var y := c.y + r + 30
		draw_string_outline(f, Vector2((size.x - w) * 0.5, y), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, 7, INK)
		draw_string(f, Vector2((size.x - w) * 0.5, y), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
		if price != "":
			var tw := f.get_string_size(price, HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
			var pw := tw + (24.0 if price_icon else 0.0) + 16.0
			var box := Rect2(Vector2((size.x - pw) * 0.5, c.y - r - 16), Vector2(pw, 26))
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.106, 0.094, 0.149, 0.9)
			sb.set_corner_radius_all(13)
			draw_style_box(sb, box)
			var tx := box.position.x + 8
			draw_string(f, Vector2(tx, box.position.y + 20), price, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
			if price_icon:
				draw_texture_rect(price_icon, Rect2(Vector2(tx + tw + 3, box.position.y + 3), Vector2(20, 20)), false)


class Glyph:
	## White check or cross with a dark rim, drawn as lines (the font has no such signs).
	extends Control
	var kind := "ok"

	func _draw() -> void:
		var s := size
		if kind == "ok":
			var pts := PackedVector2Array([s * Vector2(0.27, 0.52), s * Vector2(0.44, 0.7), s * Vector2(0.75, 0.3)])
			draw_polyline(pts, Color(0.05, 0.2, 0.02), 15.0)
			draw_polyline(pts, Color.WHITE, 9.0)
		else:
			var lines := [[Vector2(0.32, 0.3), Vector2(0.68, 0.66)], [Vector2(0.68, 0.3), Vector2(0.32, 0.66)]]
			for line in lines:
				draw_line(s * line[0], s * line[1], Color(0.3, 0.02, 0.02), 14.0)
			for line in lines:
				draw_line(s * line[0], s * line[1], Color.WHITE, 8.0)


class Bar:
	## Resource bar like the top-right of base-builders: dark trough, colored fill, amount on top.
	extends Control
	var fill := Color.GOLD
	var k := 0.0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(0.106, 0.094, 0.149))
		draw_rect(r.grow(-3), Color(0.2, 0.2, 0.26))
		var f := r.grow(-3)
		f.size.x *= clampf(k, 0.0, 1.0)
		draw_rect(f, fill)
		draw_rect(Rect2(f.position, Vector2(f.size.x, f.size.y * 0.4)), Color(1, 1, 1, 0.25))


# ================================================================ start
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	world = Node2D.new()
	add_child(world)
	view = IsoView.new()
	world.add_child(view)
	village = Village.new()
	if not _load():
		village.new_game(_now())
	village.message.connect(func(t): _toast(t))
	village.finished.connect(_on_finished)
	village.tick(_now())
	view.village = village
	_build_hud()
	_build_battle_hud()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(modal)
	toast_label = UIKit.outlined(UIKit.label("", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER), 7)
	toast_label.visible = false
	add_child(toast_label)
	get_viewport().size_changed.connect(_layout)
	_center_on_village()
	_layout()
	_refresh_hud()


func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _load() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	village.from_dict(d)
	return true


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(village.to_dict()))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if village != null:
			_save()


func _layout() -> void:
	var size := get_viewport_rect().size
	W = maxf(size.x, BASE.x)
	H = maxf(size.y, BASE.y)
	if hud == null:
		return
	hud.size = Vector2(W, H)
	bhud.size = Vector2(W, H)
	_apply_camera()


func _center_on_village() -> void:
	var th := {}
	for b in village.buildings:
		if b["type"] == "town_hall":
			th = b
	var g := Vector2(Data.GRID * 0.5, Data.GRID * 0.5) if th.is_empty() else Vector2(th["x"] + 2, th["y"] + 2)
	cam = IsoView.g2l(g)


func _apply_camera() -> void:
	zoom = clampf(zoom, MIN_ZOOM, MAX_ZOOM)
	# keep the field on screen
	var n := float(Data.GRID)
	var left := IsoView.g2l(Vector2(0, n)).x
	var right := IsoView.g2l(Vector2(n, 0)).x
	var top := IsoView.g2l(Vector2(0, 0)).y
	var bottom := IsoView.g2l(Vector2(n, n)).y
	cam.x = clampf(cam.x, left + 100, right - 100)
	cam.y = clampf(cam.y, top - 60, bottom + 60)
	world.scale = Vector2(zoom, zoom)
	world.position = (Vector2(W, H) * 0.5 - cam * zoom).round()


func screen_to_grid(p: Vector2) -> Vector2:
	return IsoView.l2g((p - world.position) / zoom)


func grid_to_screen(g: Vector2) -> Vector2:
	return world.position + IsoView.g2l(g) * zoom


# ================================================================ frame
func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time -= delta
		toast_label.modulate.a = clampf(toast_time * 2.0, 0.0, 1.0)
		toast_label.visible = toast_time > 0.0
	if mode == "village":
		tick_timer += delta
		if tick_timer >= 0.5:
			tick_timer = 0.0
			village.tick(_now())
			_refresh_bubbles()
			_refresh_hud()
			if sel_id >= 0:
				_refresh_selection_bar()
		save_timer += delta
		if save_timer > 10.0:
			save_timer = 0.0
			_save()
		_place_bar_follow()
	elif mode == "battle":
		_battle_process(delta)


# ================================================================ HUD (village)
func _panel(parent: Control, pos: Vector2, size: Vector2) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", UIKit.hud())
	p.position = pos
	p.size = size
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(p)
	return p


func _icon(parent: Control, name: String, pos: Vector2, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Art.vil(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.position = pos
	t.size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	parent.add_child(t)
	return t


func _label(parent: Control, text: String, size: int, pos: Vector2, box: Vector2, color: Color = Color.WHITE, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UIKit.outlined(UIKit.label(text, size, color, align), maxi(4, size / 4))
	l.position = pos
	l.size = box
	parent.add_child(l)
	return l


func _build_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	# top-left: experience level (blue star), name and XP bar, trophies under it
	var lv_box := Control.new()
	lv_box.position = Vector2(14, 10)
	hud.add_child(lv_box)
	var xp_back := ColorRect.new()
	xp_back.color = DARK
	xp_back.position = Vector2(40, 30)
	xp_back.size = Vector2(220, 24)
	lv_box.add_child(xp_back)
	var xp_trough := ColorRect.new()
	xp_trough.color = Color(0.2, 0.22, 0.3)
	xp_trough.position = Vector2(3, 3)
	xp_trough.size = Vector2(214, 18)
	xp_back.add_child(xp_trough)
	xp_bar = ColorRect.new()
	xp_bar.color = Color(0.35, 0.75, 1.0)
	xp_bar.size = Vector2(0, 18)
	xp_trough.add_child(xp_bar)
	var star := _icon(lv_box, "ic_star", Vector2(0, 8), 64)
	star.modulate = Color(0.55, 0.8, 1.0)
	level_label = _label(lv_box, "1", 26, Vector2(0, 18), Vector2(64, 44), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_label = _label(lv_box, "족장", 22, Vector2(70, -2), Vector2(220, 32))
	_icon(lv_box, "ic_trophy", Vector2(10, 74), 40)
	trophy_label = _label(lv_box, "0", 24, Vector2(56, 76), Vector2(120, 36))
	# top-middle: builders
	var bb := _panel(hud, Vector2(0, 10), Vector2(200, 52))
	bb.name = "builders"
	_icon(bb, "ic_builder", Vector2(8, 4), 44)
	_label(bb, "일꾼", 16, Vector2(58, 0), Vector2(80, 24), UIKit.MUTED)
	builder_label = _label(bb, "0/2", 24, Vector2(58, 18), Vector2(130, 32))
	# top-right: gold, elixir, gems
	var y := 10.0
	for res in ["gold", "elixir", "gems"]:
		var row := Control.new()
		row.name = "res_" + res
		row.position = Vector2(0, y)
		hud.add_child(row)
		var bar := Bar.new()
		bar.fill = {"gold": Color(1.0, 0.82, 0.2), "elixir": Color(0.85, 0.35, 0.95), "gems": Color(0.35, 0.85, 0.35)}[res]
		bar.position = Vector2(0, 14)
		bar.size = Vector2(230, 30)
		row.add_child(bar)
		var amt := _label(row, "0", 22, Vector2(6, 10), Vector2(214, 36), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
		var mx := _label(row, "", 14, Vector2(6, -6), Vector2(214, 22), UIKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		_icon(row, "ic_" + ("gem" if res == "gems" else res), Vector2(226, 2), 52)
		if res != "gems":
			# test only: fills this resource up to its storage cap
			var add := Button.new()
			add.text = "+"
			add.position = Vector2(-48, 10)
			add.size = Vector2(42, 38)
			UIKit.style_button(add, "ok", 26, 8)
			add.pressed.connect(func():
				SoundManager.play("click")
				village.add_res(res, village.capacity(res))
				_toast("테스트: %s 가득" % ("금" if res == "gold" else "엘릭서"))
				_after_change())
			row.add_child(add)
		res_rows[res] = {"row": row, "bar": bar, "amt": amt, "max": mx}
		y += 54.0
	# bottom-left: attack; bottom-right: shop
	attack_button = _big_button("공격!", "ic_attack", "primary", _open_attack)
	shop_button = _big_button("상점", "ic_shop", "secondary", _open_shop)
	# bottom-middle: selected building name and round buttons
	sel_bar = Control.new()
	sel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_bar.visible = false
	hud.add_child(sel_bar)
	sel_title = _label(sel_bar, "", 26, Vector2(0, 0), Vector2(800, 40), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	sel_buttons = HBoxContainer.new()
	sel_buttons.add_theme_constant_override("separation", 6)
	sel_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	sel_buttons.position = Vector2(0, 46)
	sel_buttons.size = Vector2(800, 136)
	sel_bar.add_child(sel_buttons)
	# placing: cancel / confirm over the ghost
	place_bar = HBoxContainer.new()
	place_bar.add_theme_constant_override("separation", 14)
	place_bar.visible = false
	hud.add_child(place_bar)
	var no := _square_button("x", "danger", func(): _cancel_place())
	place_bar.add_child(no)
	place_ok = _square_button("ok", "ok", func(): _confirm_place())
	place_bar.add_child(place_ok)


func _big_button(text: String, icon: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = Art.vil(icon)
	b.expand_icon = true
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 80)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	b.size = Vector2(150, 140)
	UIKit.style_button(b, kind, 28, 16)
	b.pressed.connect(func():
		SoundManager.play("click")
		cb.call())
	hud.add_child(b)
	return b


func _glyph(kind: String, size: Vector2) -> Control:
	var g := Glyph.new()
	g.kind = kind
	g.size = size
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


func _square_button(glyph: String, kind: String, cb: Callable) -> Button:
	var b := Button.new()
	b.add_child(_glyph(glyph, Vector2(76, 64)))
	b.custom_minimum_size = Vector2(76, 70)
	UIKit.style_button(b, kind, 34, 12)
	b.pressed.connect(func():
		SoundManager.play("click")
		cb.call())
	return b


func _refresh_hud() -> void:
	if hud == null:
		return
	# positions follow the screen size
	var bb: Control = hud.get_node("builders")
	bb.position.x = roundf((W - bb.size.x) * 0.5)
	for res in res_rows:
		res_rows[res]["row"].position.x = W - 300
	attack_button.position = Vector2(16, H - 156)
	shop_button.position = Vector2(W - 166, H - 156)
	sel_bar.position = Vector2(roundf((W - 800) * 0.5), H - 190)
	sel_bar.size = Vector2(800, 188)
	toast_label.position = Vector2(0, 150)
	toast_label.size = Vector2(W, 40)
	# values
	level_label.text = str(village.xp_level)
	xp_bar.size.x = 214.0 * clampf(float(village.xp) / Data.xp_needed(village.xp_level), 0.0, 1.0)
	trophy_label.text = str(village.trophies)
	builder_label.text = "%d/%d" % [village.builders_free(), village.builders_total()]
	for res in res_rows:
		var r: Dictionary = res_rows[res]
		var amount := village.amount(res)
		r["amt"].text = UIKit.format_number(amount)
		if res == "gems":
			r["bar"].k = 1.0
			r["max"].text = ""
		else:
			var cap := village.capacity(res)
			r["bar"].k = float(amount) / maxf(1.0, cap)
			r["max"].text = "최대: %s" % UIKit.format_number(cap)
		r["bar"].queue_redraw()


func _toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_time = 2.4


func _refresh_bubbles() -> void:
	var b := {}
	for x in village.buildings:
		if village.ready_to_collect(x):
			b[x["id"]] = Data.BUILDINGS[x["type"]]["res"]
	view.bubbles = b


# ================================================================ selection
func _select(kind: String, id: int) -> void:
	sel_kind = kind
	sel_id = id
	view.selected_id = id
	view.range_of = {}
	if kind == "b":
		var b := village.get_b(id)
		if Data.BUILDINGS[b["type"]].has("range"):
			view.range_of = {"type": b["type"], "x": b["x"], "y": b["y"]}
	_refresh_selection_bar()


func _deselect() -> void:
	sel_kind = ""
	sel_id = -1
	view.selected_id = -1
	view.range_of = {}
	sel_bar.visible = false
	sel_sig = ""
	for c in sel_buttons.get_children():
		c.queue_free()


var pending: Array = []
var sel_sig := ""


func _refresh_selection_bar() -> void:
	## Rebuilds the round buttons only when they change, so a tap is never lost to a rebuild.
	pending = []
	_fill_selection()
	var sig := sel_title.text if sel_bar.visible else ""
	for r in pending:
		sig += "|" + r.caption + ":" + r.price
	if sig == sel_sig:
		for r in pending:
			r.free()
		pending = []
		return
	sel_sig = sig
	for c in sel_buttons.get_children():
		c.queue_free()
	for r in pending:
		sel_buttons.add_child(r)
	pending = []


func _fill_selection() -> void:
	if sel_id < 0:
		sel_bar.visible = false
		return
	sel_bar.visible = true
	if sel_kind == "o":
		var o := village.get_o(sel_id)
		if o.is_empty():
			_deselect()
			return
		var od: Dictionary = Data.OBSTACLES[o["type"]]
		sel_title.text = od["name"]
		if o["busy_until"] > 0:
			sel_title.text += "  (치우는 중 %s)" % Data.time_text(o["busy_until"] - village.now)
		else:
			_round("제거", "ic_builder", func(): _do(village.clear_obstacle(o)), UIKit.format_number(od["cost"]), od["res"])
		return
	var b := village.get_b(sel_id)
	if b.is_empty():
		_deselect()
		return
	var d: Dictionary = Data.BUILDINGS[b["type"]]
	sel_title.text = "%s (%d레벨)" % [d["name"], maxi(1, b["lv"])] if b["lv"] > 0 else "%s (공사 중)" % d["name"]
	_round("정보", "", func(): _open_info(b))
	if b["busy_until"] > 0:
		var gems := village.finish_now_cost(b)
		_round("즉시 완료", "ic_gem", func():
			if not village.finish_now(b):
				_toast("보석이 부족해요")
			_after_change(), str(gems), "gems")
		_round("취소", "", func(): _confirm("공사를 취소할까요?\n비용의 절반을 돌려받아요.", func():
			village.cancel_work(b)
			_deselect()
			_after_change()))
	elif b["lv"] < Data.max_level(b["type"]):
		var nxt := Data.level(b["type"], b["lv"] + 1)
		_round("업그레이드", "ic_builder", func(): _open_upgrade(b), Data.short_number(int(nxt["cost"])), nxt["res"])
	if d["kind"] == "collector" and b["busy_until"] == 0:
		var stored := village.stored_now(b)
		if stored >= 1:
			_round("수집", "ic_" + d["res"], func(): _collect(b), UIKit.format_number(stored), "")
	if b["type"] in ["barracks", "army_camp"] and b["lv"] > 0:
		_round("병사 훈련", "ic_attack", _open_train)
	if b["type"] == "laboratory" and b["lv"] > 0:
		_round("연구", "ic_elixir", _open_lab)


func _round(caption: String, icon: String, cb: Callable, price: String = "", price_res: String = "") -> void:
	var r := RoundButton.new()
	r.caption = caption
	r.pic = Art.vil(icon) if icon != "" else Art.vil("ic_star")
	if icon == "":
		r.pic = null
		r.caption = caption
	r.price = price
	if price_res != "":
		r.price_icon = Art.vil("ic_" + ("gem" if price_res == "gems" else price_res))
	if caption == "정보":
		r.pic = null
		r.info = true
	r.pressed.connect(func():
		SoundManager.play("click")
		cb.call())
	pending.append(r)
	if r.pic == null and not r.info:
		var g := Glyph.new()
		g.kind = "x"
		g.position = Vector2(26, 22)
		g.size = Vector2(60, 64)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(g)


func _do(why: String) -> void:
	if why != "":
		SoundManager.play("invalid")
		_toast(why)
	else:
		SoundManager.play("place")
	_after_change()


func _after_change() -> void:
	village.tick(_now())
	_refresh_bubbles()
	_refresh_hud()
	_refresh_selection_bar()
	_save()


func _collect(b: Dictionary) -> void:
	var res: String = Data.BUILDINGS[b["type"]]["res"]
	var got := village.collect(b)
	if got > 0:
		SoundManager.play("coin")
		_toast("+%s %s" % [UIKit.format_number(got), Data.RES_NAME[res]])
	elif village.amount(res) >= village.capacity(res):
		SoundManager.play("invalid")
		_toast("저장소가 가득 찼어요")
	_after_change()


func _on_finished(b: Dictionary) -> void:
	SoundManager.play("build")
	if mode == "village":
		_toast("%s %d레벨 완성!" % [Data.BUILDINGS[b["type"]]["name"], b["lv"]])


# ================================================================ windows
func _close_modal() -> void:
	for c in modal.get_children():
		c.queue_free()


func _window(title: String, size: Vector2) -> Panel:
	## Cream window with a title on top and a red close button, like base-builder popups.
	_close_modal()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)
	var win := Panel.new()
	win.add_theme_stylebox_override("panel", UIKit.frame("paper"))
	win.size = size
	win.position = ((Vector2(W, H) - size) * 0.5).round()
	dim.add_child(win)
	var head := Panel.new()
	head.add_theme_stylebox_override("panel", UIKit.frame("window"))
	head.position = Vector2(0, 0)
	head.size = Vector2(size.x, 64)
	win.add_child(head)
	_label(head, title, 30, Vector2(20, 6), Vector2(size.x - 120, 52), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var close := Button.new()
	close.add_child(_glyph("x", Vector2(58, 52)))
	close.position = Vector2(size.x - 70, 6)
	close.size = Vector2(58, 52)
	UIKit.style_button(close, "danger", 28, 10)
	close.pressed.connect(func():
		SoundManager.play("click")
		_close_modal())
	head.add_child(close)
	return win


func _dark_label(parent: Control, text: String, size: int, pos: Vector2, box: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UIKit.label(text, size, PAPER_TEXT, align)
	l.position = pos
	l.size = box
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _confirm(text: String, yes: Callable) -> void:
	var win := _window("확인", Vector2(520, 300))
	_dark_label(win, text, 24, Vector2(30, 84), Vector2(460, 110), HORIZONTAL_ALIGNMENT_CENTER)
	var ok := Button.new()
	ok.text = "확인"
	ok.position = Vector2(170, 206)
	ok.size = Vector2(180, 68)
	UIKit.style_button(ok, "ok", 26, 12)
	ok.pressed.connect(func():
		SoundManager.play("click")
		_close_modal()
		yes.call())
	win.add_child(ok)


func _stat_rows(type: String, lv: int, next_lv: int) -> Array:
	## [[name, now, next]] for the info and upgrade windows.
	var d: Dictionary = Data.BUILDINGS[type]
	var cur := Data.level(type, maxi(1, lv))
	var nxt := Data.level(type, next_lv) if next_lv > 0 else {}
	var rows := []
	var add := func(name: String, key: String, fmt: String):
		if cur.has(key):
			var a := fmt % [cur[key]] if lv > 0 else "-"
			var bnext := (fmt % [nxt[key]]) if not nxt.is_empty() else ""
			rows.append([name, a, bnext])
	match d["kind"]:
		"collector":
			add.call("시간당 생산", "rate", "%d")
			add.call("저장량", "cap", "%d")
		"storage":
			add.call("저장량", "cap", "%d")
		"defense":
			add.call("초당 피해", "dps", "%d")
		"trap":
			add.call("피해", "damage", "%d")
	if type == "town_hall":
		add.call("금 저장량", "cap_gold", "%d")
		add.call("엘릭서 저장량", "cap_elixir", "%d")
	if type == "army_camp":
		add.call("부대 공간", "housing", "%d")
	add.call("체력", "hp", "%d")
	return rows


func _draw_stats(win: Control, rows: Array, y: float, show_next: bool) -> float:
	for r in rows:
		var card := Panel.new()
		card.add_theme_stylebox_override("panel", UIKit.frame("card", 16))
		card.position = Vector2(30, y)
		card.size = Vector2(win.size.x - 60, 46)
		win.add_child(card)
		_dark_label(card, r[0], 20, Vector2(14, 6), Vector2(220, 34))
		var txt: String = r[1]
		if show_next and r[2] != "" and r[2] != r[1]:
			txt = "%s  →  %s" % [r[1], r[2]]
		var v := _dark_label(card, txt, 22, Vector2(230, 6), Vector2(card.size.x - 250, 34), HORIZONTAL_ALIGNMENT_RIGHT)
		if show_next and r[2] != r[1] and r[2] != "":
			v.add_theme_color_override("font_color", Color(0.15, 0.55, 0.1))
		y += 52
	return y


func _open_info(b: Dictionary) -> void:
	var d: Dictionary = Data.BUILDINGS[b["type"]]
	var win := _window("%s (%d레벨)" % [d["name"], maxi(1, b["lv"])], Vector2(720, 560))
	_icon(win, Data.sprite(b["type"]), Vector2(30, 80), 190)
	_dark_label(win, d["desc"], 19, Vector2(240, 84), Vector2(450, 150))
	var y := _draw_stats(win, _stat_rows(b["type"], b["lv"], 0), 280, false)
	if d.has("range"):
		var extra := "사거리 %s칸 · %s" % [str(d["range"]), {"ground": "지상 공격", "air": "공중 공격", "both": "지상·공중"}[d["targets"]]]
		if d.get("splash", 0.0) > 0.0:
			extra += " · 범위 피해"
		_dark_label(win, extra, 19, Vector2(30, y + 4), Vector2(660, 30))


func _open_upgrade(b: Dictionary) -> void:
	var d: Dictionary = Data.BUILDINGS[b["type"]]
	var nlv: int = b["lv"] + 1
	var nxt := Data.level(b["type"], nlv)
	var win := _window("%d레벨로 업그레이드할까요?" % nlv, Vector2(760, 600))
	_icon(win, Data.sprite(b["type"]), Vector2(30, 80), 190)
	_dark_label(win, d["name"], 26, Vector2(240, 84), Vector2(480, 40))
	if b["type"] == "town_hall":
		var unlocks := Data.unlocks_at(nlv)
		_dark_label(win, "새로 지을 수 있는 것: " + (", ".join(unlocks) if unlocks.size() > 0 else "없음"), 18, Vector2(240, 130), Vector2(490, 130))
	var y := _draw_stats(win, _stat_rows(b["type"], b["lv"], nlv), 280, true)
	_dark_label(win, "업그레이드 시간: %s" % Data.time_text(int(nxt["time"])), 20, Vector2(30, y + 6), Vector2(400, 34))
	var go := Button.new()
	go.text = "  %s" % UIKit.format_number(int(nxt["cost"]))
	go.icon = Art.vil("ic_" + ("gem" if nxt["res"] == "gems" else nxt["res"]))
	go.expand_icon = true
	go.add_theme_constant_override("icon_max_width", 40)
	go.position = Vector2(win.size.x - 290, win.size.y - 100)
	go.size = Vector2(260, 76)
	var why := village.upgrade_check(b)
	UIKit.style_button(go, "ok" if why == "" else "danger", 28, 12)
	go.pressed.connect(func():
		var w := village.upgrade(b)
		if w != "":
			SoundManager.play("invalid")
			_toast(w)
			return
		SoundManager.play("place")
		_close_modal()
		_after_change())
	win.add_child(go)
	if why != "":
		_dark_label(win, why, 20, Vector2(30, win.size.y - 84), Vector2(420, 40)).add_theme_color_override("font_color", Color(0.75, 0.15, 0.1))


# ---------------------------------------------------------------- shop
var shop_tab := 0


func _open_shop() -> void:
	_deselect()
	var win := _window("상점", Vector2(minf(W - 60, 1180), 640))
	for k in Data.SHOP.size():
		var tab := Button.new()
		tab.text = Data.SHOP[k][0]
		tab.position = Vector2(30 + k * 170, 76)
		tab.size = Vector2(160, 54)
		UIKit.style_button(tab, "selected" if k == shop_tab else "secondary", 22, 10)
		tab.pressed.connect(func():
			SoundManager.play("click")
			shop_tab = k
			_open_shop())
		win.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 144)
	scroll.size = Vector2(win.size.x - 48, win.size.y - 164)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	win.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	scroll.add_child(row)
	for type in Data.SHOP[shop_tab][1]:
		row.add_child(_shop_card(type))


func _shop_card(type: String) -> Control:
	var d: Dictionary = Data.BUILDINGS[type]
	var st := village.shop_state(type)
	var can: bool = st["built"] < st["max"]
	var b := Button.new()
	b.custom_minimum_size = Vector2(210, 450)
	b.flat = true
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.frame("card" if can else "card_off", 16))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bg)
	_dark_label(b, d["name"], 21, Vector2(8, 10), Vector2(194, 32), HORIZONTAL_ALIGNMENT_CENTER)
	var pic := _icon(b, Data.sprite(type), Vector2(15, 50), 180)
	if not can:
		pic.modulate = Color(0.6, 0.6, 0.6)
	var lvl := Data.level(type, 1)
	var cost := village.build_cost(type)
	_dark_label(b, "건설 시간: %s" % Data.time_text(int(lvl["time"])), 16, Vector2(8, 240), Vector2(194, 26), HORIZONTAL_ALIGNMENT_CENTER)
	_dark_label(b, "건설: %d/%d" % [st["built"], st["max"]], 18, Vector2(8, 268), Vector2(194, 26), HORIZONTAL_ALIGNMENT_CENTER)
	var desc := _dark_label(b, d.get("short", ""), 15, Vector2(10, 298), Vector2(190, 70), HORIZONTAL_ALIGNMENT_CENTER)
	desc.add_theme_color_override("font_color", Color(0.45, 0.38, 0.3))
	if can:
		var res: String = "gems" if type == "builder_hut" else lvl["res"]
		var price := _label(b, UIKit.format_number(cost), 24, Vector2(8, 390), Vector2(150, 40), Color.WHITE if village.amount(res) >= cost else UIKit.RED, HORIZONTAL_ALIGNMENT_RIGHT)
		price.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon(b, "ic_" + ("gem" if res == "gems" else res), Vector2(162, 390), 38)
	else:
		var why := "마을회관 %d레벨 필요" % st["next_th"] if st["next_th"] > 0 else "최대 개수"
		var l := _label(b, why, 18, Vector2(8, 392), Vector2(194, 36), UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.pressed.connect(func():
		SoundManager.play("click")
		if not can:
			_toast("마을회관을 올려야 더 지을 수 있어요" if st["next_th"] > 0 else "더 지을 수 없어요")
			return
		var res: String = "gems" if type == "builder_hut" else lvl["res"]
		if village.amount(res) < cost:
			_toast("%s이(가) 부족해요" % Data.RES_NAME[res])
			SoundManager.play("invalid")
			return
		_close_modal()
		_begin_place(type, Vector2i(-999, -999)))
	return b


# ---------------------------------------------------------------- placing a new building
func _begin_place(type: String, near: Vector2i) -> void:
	_deselect()
	var size: int = Data.BUILDINGS[type]["size"]
	var spot := _free_spot(type, near)
	placing = {"type": type, "x": spot.x, "y": spot.y, "ok": village.is_free(spot.x, spot.y, size, -1)}
	view.ghost = placing
	if Data.BUILDINGS[type].has("range"):
		view.range_of = {"type": type, "x": spot.x, "y": spot.y}
	place_bar.visible = true
	attack_button.visible = false
	shop_button.visible = false


func _free_spot(type: String, near: Vector2i) -> Vector2i:
	var size: int = Data.BUILDINGS[type]["size"]
	var c := Vector2i(screen_to_grid(Vector2(W, H) * 0.5).floor()) - Vector2i(size / 2, size / 2)
	if near.x > -999:
		c = near
	var best := c
	var best_d := INF
	for y in range(Data.EDGE, Data.GRID - Data.EDGE - size + 1):
		for x in range(Data.EDGE, Data.GRID - Data.EDGE - size + 1):
			var dd := Vector2(x - c.x, y - c.y).length_squared()
			if dd < best_d and village.is_free(x, y, size, -1):
				best_d = dd
				best = Vector2i(x, y)
	return best


func _update_ghost(x: int, y: int) -> void:
	var t: String = placing["type"]
	var size: int = Data.BUILDINGS[t]["size"]
	x = clampi(x, Data.EDGE, Data.GRID - Data.EDGE - size)
	y = clampi(y, Data.EDGE, Data.GRID - Data.EDGE - size)
	placing["x"] = x
	placing["y"] = y
	placing["ok"] = village.is_free(x, y, size, -1)
	view.ghost = placing
	if not view.range_of.is_empty():
		view.range_of = {"type": t, "x": x, "y": y}


func _place_bar_follow() -> void:
	var g := placing if not placing.is_empty() else {}
	if g.is_empty():
		place_bar.visible = false
		return
	var size: int = Data.BUILDINGS[g["type"]]["size"]
	var top := grid_to_screen(Vector2(g["x"] + size * 0.5, g["y"] + size * 0.5))
	var pr := view.sprite_rect(Data.sprite(g["type"]), g["x"], g["y"], size)
	var y := world.position.y + pr.position.y * zoom - 84 if pr.size.y > 0 else top.y - 120
	place_bar.position = Vector2(roundf(top.x - 83), clampf(y, 140, H - 200))
	place_ok.disabled = not g["ok"]


func _cancel_place() -> void:
	placing = {}
	view.ghost = {}
	view.range_of = {}
	place_bar.visible = false
	attack_button.visible = true
	shop_button.visible = true


func _confirm_place() -> void:
	if placing.is_empty() or not placing["ok"]:
		SoundManager.play("invalid")
		return
	var t: String = placing["type"]
	var x: int = placing["x"]
	var y: int = placing["y"]
	var why := village.build_new(t, x, y)
	if why != "":
		_toast(why)
		SoundManager.play("invalid")
		_cancel_place()
		return
	SoundManager.play("place")
	var last: Vector2i = placing.get("last", Vector2i(x, y))
	_cancel_place()
	_after_change()
	# walls go on: the next piece waits beside this one, in the same direction
	if t == "wall":
		var st := village.shop_state("wall")
		if st["built"] < st["max"] and village.gold >= village.build_cost("wall"):
			var dir := Vector2i(x, y) - last
			if dir == Vector2i.ZERO or absi(dir.x) + absi(dir.y) != 1:
				dir = Vector2i(1, 0)
			var nx := Vector2i(x, y) + dir
			_begin_place("wall", nx if village.is_free(nx.x, nx.y, 1, -1) else Vector2i(x, y))
			placing["last"] = Vector2i(x, y)


# ================================================================ input
func _unhandled_input(event: InputEvent) -> void:
	if mode == "result":
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		if touches.size() == 2:
			var pts: Array = touches.values()
			pinch_dist = maxf(1.0, pts[0].distance_to(pts[1]))
			pinch_zoom = zoom
			drag = "pinch"
		return
	if event is InputEventScreenDrag:
		touches[event.index] = event.position
		if touches.size() >= 2:
			var pts: Array = touches.values()
			var d: float = pts[0].distance_to(pts[1])
			_zoom_at((pts[0] + pts[1]) * 0.5, pinch_zoom * d / pinch_dist)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, zoom * 1.1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, zoom / 1.1)
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_press(event.position)
		else:
			_release(event.position)
	elif event is InputEventMouseMotion and pressing:
		_motion(event.position, event.relative)


func _zoom_at(p: Vector2, z: float) -> void:
	var before := (p - world.position) / zoom
	zoom = clampf(z, MIN_ZOOM, MAX_ZOOM)
	cam = before - (p - Vector2(W, H) * 0.5) / zoom
	_apply_camera()


func _press(p: Vector2) -> void:
	pressing = true
	moved = false
	press_pos = p
	finger = p
	press_ms = Time.get_ticks_msec()
	drag = "pan"
	if touches.size() >= 2:
		drag = "pinch"
		return
	var g := screen_to_grid(p)
	if mode == "village":
		if not placing.is_empty():
			var size: int = Data.BUILDINGS[placing["type"]]["size"]
			if Rect2(placing["x"] - 0.5, placing["y"] - 0.5, size + 1, size + 1).has_point(g):
				drag = "ghost"
				drag_grab = g - Vector2(placing["x"], placing["y"])
		elif sel_kind == "b":
			var b := village.get_b(sel_id)
			var size: int = Data.BUILDINGS[b["type"]]["size"]
			if Rect2(b["x"], b["y"], size, size).has_point(g):
				drag = "move"
				drag_grab = g - Vector2(b["x"], b["y"])
				moving = {"id": b["id"], "from": Vector2i(b["x"], b["y"])}
	elif mode == "battle":
		stream_t = 0.0


func _motion(p: Vector2, rel: Vector2) -> void:
	finger = p
	if not moved and p.distance_to(press_pos) > 10.0:
		moved = true
	if drag == "pinch":
		return
	if not moved:
		return
	match drag:
		"pan":
			cam -= rel / zoom
			_apply_camera()
		"ghost":
			var g := screen_to_grid(p) - drag_grab
			_update_ghost(roundi(g.x), roundi(g.y))
		"move":
			var b := village.get_b(moving["id"])
			var size: int = Data.BUILDINGS[b["type"]]["size"]
			var g := screen_to_grid(p) - drag_grab
			var x := clampi(roundi(g.x), Data.EDGE, Data.GRID - Data.EDGE - size)
			var y := clampi(roundi(g.y), Data.EDGE, Data.GRID - Data.EDGE - size)
			view.hide_id = b["id"]
			view.ghost = {"type": b["type"], "x": x, "y": y, "ok": village.is_free(x, y, size, b["id"])}
			moving["x"] = x
			moving["y"] = y
		"stream":
			pass


func _release(p: Vector2) -> void:
	if not pressing:
		return
	pressing = false
	if drag == "pinch":
		if touches.size() < 2:
			drag = ""
		return
	if mode == "battle":
		if not moved and drag != "stream":
			_deploy_at(p)
		drag = ""
		return
	if drag == "move":
		view.hide_id = -1
		view.ghost = {}
		if moved and moving.has("x"):
			var b := village.get_b(moving["id"])
			if village.move(b, moving["x"], moving["y"]):
				SoundManager.play("place")
				_select("b", b["id"])
				_save()
			else:
				SoundManager.play("invalid")
		moving = {}
		if moved:
			drag = ""
			return
	if not moved and drag != "ghost":
		_tap(p)
	drag = ""


func _tap(p: Vector2) -> void:
	if not placing.is_empty():
		return                                   # like the original: tapping elsewhere does not move the ghost
	var g := screen_to_grid(p)
	# front-most building under the finger (check the picture area too, tall buildings)
	var hit := {}
	var best := -INF
	for b in village.buildings:
		var size: int = Data.BUILDINGS[b["type"]]["size"]
		var inside := Rect2(b["x"], b["y"], size, size).has_point(g)
		if not inside:
			var r := view.sprite_rect(Data.sprite(b["type"]), b["x"], b["y"], size)
			var local := (p - world.position) / zoom
			inside = r.size.x > 0 and r.grow(-r.size.x * 0.18).has_point(local) and Data.BUILDINGS[b["type"]]["kind"] != "wall"
		if inside and b["x"] + b["y"] + size > best:
			best = b["x"] + b["y"] + size
			hit = b
	if not hit.is_empty():
		if sel_id == hit["id"] and sel_kind == "b" and not village.ready_to_collect(hit):
			_deselect()
			return
		if village.ready_to_collect(hit):
			_collect(hit)
		SoundManager.play("click")
		_select("b", hit["id"])
		return
	for o in village.obstacles:
		var s: int = Data.OBSTACLES[o["type"]]["size"]
		if Rect2(o["x"], o["y"], s, s).has_point(g):
			SoundManager.play("click")
			_select("o", o["id"])
			return
	_deselect()


# ================================================================ army
func _open_train() -> void:
	## Like the original's army screen: the army on top (tap a troop to send it away), the troops
	## to train below. Training is free and instant.
	var win := _window("병사 훈련", Vector2(minf(W - 60, 1140), 620))
	var cap := village.housing()
	_dark_label(win, "부대  %d/%d" % [village.army_space(), cap], 26, Vector2(30, 76), Vector2(300, 36))
	var bar := Bar.new()
	bar.fill = Color(0.95, 0.7, 0.25)
	bar.k = float(village.army_space()) / maxf(1.0, cap)
	bar.position = Vector2(220, 82)
	bar.size = Vector2(300, 26)
	win.add_child(bar)
	var x := 30.0
	for k in Data.TROOP_ORDER:
		if int(village.army.get(k, 0)) > 0:
			var kind: String = k
			_troop_chip(win, k, "x%d" % village.army[k], Vector2(x, 120), func():
				village.untrain(kind)
				_open_train())
			x += 92
	if x == 30.0:
		_dark_label(win, "아래에서 병사를 눌러 부대를 채우세요", 19, Vector2(30, 146), Vector2(600, 30))
	else:
		_dark_label(win, "부대의 병사를 누르면 한 명씩 빠져요", 16, Vector2(560, 84), Vector2(500, 26))
	_dark_label(win, "병사 훈련 (무료, 바로 완료)", 22, Vector2(30, 222), Vector2(500, 30))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(30, 260)
	win.add_child(row)
	for k in Data.TROOP_ORDER:
		row.add_child(_troop_card(k))


func _troop_chip(parent: Control, kind: String, tag: String, pos: Vector2, cb: Callable) -> void:
	var b := Button.new()
	b.position = pos
	b.size = Vector2(84, 84)
	b.flat = true
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.frame("card", 14))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bg)
	_icon(b, kind, Vector2(8, 4), 68)
	if tag != "":
		_label(b, tag, 18, Vector2(2, 56), Vector2(80, 28), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	if cb.is_valid():
		b.pressed.connect(func():
			SoundManager.play("click")
			cb.call())
	parent.add_child(b)


func _troop_card(kind: String) -> Control:
	var d: Dictionary = Data.TROOPS[kind]
	var ok := village.troop_unlocked(kind)
	var lv := village.troop_level(kind)
	var b := Button.new()
	b.custom_minimum_size = Vector2(142, 300)
	b.flat = true
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.frame("card" if ok else "card_off", 14))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bg)
	var pic := _icon(b, kind, Vector2(15, 10), 112)
	if not ok:
		pic.modulate = Color(0.3, 0.3, 0.3)
	_dark_label(b, d["name"], 19, Vector2(4, 124), Vector2(134, 28), HORIZONTAL_ALIGNMENT_CENTER)
	_label(b, "%d" % lv, 18, Vector2(10, 8), Vector2(30, 26), Color(0.6, 0.85, 1.0))
	if ok:
		var lvl := Data.troop_level(kind, lv)
		_dark_label(b, "공간 %d\n체력 %d · 피해 %d" % [d["housing"], int(lvl["hp"]), int(lvl["dps"])], 15, Vector2(4, 154), Vector2(134, 48), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_label(b, "병영 %d레벨" % int(d["barracks"]), 18, Vector2(4, 200), Vector2(134, 30), UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
	b.pressed.connect(func():
		var why := village.train(kind)
		if why != "":
			SoundManager.play("invalid")
			_toast(why)
		else:
			SoundManager.play("click")
		_open_train()
		_save())
	return b


func _open_lab() -> void:
	var win := _window("연구소", Vector2(minf(W - 60, 1100), 560))
	if not village.research.is_empty():
		var r := village.research
		_dark_label(win, "%s 연구 중 · 남은 시간 %s" % [Data.TROOPS[r["kind"]]["name"], Data.time_text(int(r["until"]) - village.now)], 22, Vector2(30, 80), Vector2(700, 36))
	else:
		_dark_label(win, "병사를 골라 강하게 만들어요", 22, Vector2(30, 80), Vector2(700, 36))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(30, 140)
	win.add_child(row)
	for k in Data.TROOP_ORDER:
		var d: Dictionary = Data.TROOPS[k]
		var lv := village.troop_level(k)
		var b := Button.new()
		b.custom_minimum_size = Vector2(140, 330)
		b.flat = true
		var why := village.research_check(k)
		var bg := Panel.new()
		bg.add_theme_stylebox_override("panel", UIKit.frame("card" if why == "" else "card_off", 14))
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bg)
		_icon(b, k, Vector2(14, 10), 112)
		_dark_label(b, "%s %d레벨" % [d["name"], lv], 18, Vector2(4, 124), Vector2(132, 28), HORIZONTAL_ALIGNMENT_CENTER)
		var levels: Array = d["levels"]
		if lv < levels.size():
			var nxt: Dictionary = levels[lv]
			_dark_label(b, "→ %d레벨\n%s" % [lv + 1, Data.time_text(int(nxt["research_time"]))], 16, Vector2(4, 156), Vector2(132, 60), HORIZONTAL_ALIGNMENT_CENTER)
			_label(b, Data.short_number(int(nxt["research"])), 22, Vector2(4, 270), Vector2(94, 36), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
			_icon(b, "ic_elixir", Vector2(100, 270), 34)
			if why != "" and why != "엘릭서가 부족해요":
				var l := _label(b, why, 15, Vector2(4, 220), Vector2(132, 46), UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			_dark_label(b, "최고 레벨", 18, Vector2(4, 170), Vector2(132, 30), HORIZONTAL_ALIGNMENT_CENTER)
		b.pressed.connect(func():
			var w := village.start_research(k)
			if w != "":
				SoundManager.play("invalid")
				_toast(w)
			else:
				SoundManager.play("place")
			_open_lab()
			_refresh_hud())
		row.add_child(b)


# ================================================================ attack menu
func _open_attack() -> void:
	_deselect()
	var win := _window("공격", Vector2(minf(W - 60, 1160), 640))
	# left: find an opponent (generated village around your town hall level)
	var mp := Button.new()
	mp.position = Vector2(30, 84)
	mp.size = Vector2(330, 520)
	mp.flat = true
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.frame("window"))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp.add_child(bg)
	_icon(mp, "ic_attack", Vector2(85, 30), 160)
	_label(mp, "상대 찾기", 34, Vector2(0, 210), Vector2(330, 50), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var cost := Data.search_cost(village.th_level())
	_label(mp, "다른 마을을 공격해 자원과\n트로피를 빼앗아요", 18, Vector2(10, 270), Vector2(310, 70), UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_label(mp, UIKit.format_number(cost), 30, Vector2(40, 420), Vector2(170, 50), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_icon(mp, "ic_gold", Vector2(216, 420), 50)
	mp.pressed.connect(func():
		if village.army_space() <= 0:
			_toast("먼저 병사를 훈련하세요")
			SoundManager.play("invalid")
			return
		if village.gold < cost:
			_toast("금이 부족해요")
			SoundManager.play("invalid")
			return
		village.gold -= cost
		_close_modal()
		_start_battle("multi", -1))
	win.add_child(mp)
	# right: campaign maps
	_dark_label(win, "고블린 지도 (싱글 플레이)  ★ %d/%d" % [_campaign_stars(), Data.campaign().size() * 3], 24, Vector2(390, 80), Vector2(700, 36))
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(390, 120)
	scroll.size = Vector2(win.size.x - 420, win.size.y - 140)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	win.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var open_upto := 0
	for i in Data.campaign().size():
		if int(village.campaign.get(str(i), 0)) > 0:
			open_upto = i + 1
	for i in mini(Data.campaign().size(), open_upto + 1):
		list.add_child(_map_row(i, scroll.size.x - 20))


func _campaign_stars() -> int:
	var s := 0
	for k in village.campaign:
		s += int(village.campaign[k])
	return s


func _map_row(i: int, w: float) -> Control:
	var m: Dictionary = Data.campaign()[i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, 86)
	b.flat = true
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIKit.frame("card", 14))
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bg)
	_dark_label(b, "%d. %s" % [i + 1, m["name"]], 22, Vector2(16, 8), Vector2(360, 34))
	var stars := int(village.campaign.get(str(i), 0))
	for k in 3:
		var s := _icon(b, "ic_star", Vector2(16 + k * 36, 44), 34)
		s.modulate = Color(1.0, 0.85, 0.2) if k < stars else Color(0.4, 0.4, 0.4, 0.6)
	var left: Dictionary = village.campaign.get("loot_" + str(i), {"gold": m["gold"], "elixir": m["elixir"]})
	_label(b, UIKit.format_number(int(left["gold"])), 20, Vector2(w - 330, 24), Vector2(110, 36), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_icon(b, "ic_gold", Vector2(w - 216, 22), 38)
	_label(b, UIKit.format_number(int(left["elixir"])), 20, Vector2(w - 176, 24), Vector2(110, 36), Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	_icon(b, "ic_elixir", Vector2(w - 62, 22), 38)
	b.pressed.connect(func():
		SoundManager.play("click")
		if village.army_space() <= 0:
			_toast("먼저 병사를 훈련하세요")
			SoundManager.play("invalid")
			return
		_close_modal()
		_start_battle("campaign", i))
	return b


# ================================================================ battle
func _build_battle_hud() -> void:
	bhud = Control.new()
	bhud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bhud.visible = false
	add_child(bhud)
	var lp := _panel(bhud, Vector2(14, 10), Vector2(300, 112))
	lp.name = "loot"
	_label(lp, "획득 가능한 전리품:", 17, Vector2(14, 4), Vector2(270, 26), UIKit.MUTED)
	b_loot = _label(lp, "", 24, Vector2(54, 30), Vector2(230, 76))
	_icon(lp, "ic_gold", Vector2(10, 32), 34)
	_icon(lp, "ic_elixir", Vector2(10, 70), 34)
	var tp := _panel(bhud, Vector2(0, 10), Vector2(260, 78))
	tp.name = "time"
	b_time_title = _label(tp, "", 17, Vector2(0, 2), Vector2(260, 26), UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	b_time = _label(tp, "", 30, Vector2(0, 26), Vector2(260, 46), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var sp := _panel(bhud, Vector2(0, 0), Vector2(220, 110))
	sp.name = "stars"
	b_stars = _label(sp, "", 36, Vector2(0, 2), Vector2(220, 50), Color(1.0, 0.85, 0.2), HORIZONTAL_ALIGNMENT_CENTER)
	b_percent = _label(sp, "", 22, Vector2(0, 52), Vector2(220, 50), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	b_bar = HBoxContainer.new()
	b_bar.add_theme_constant_override("separation", 8)
	bhud.add_child(b_bar)
	b_end = Button.new()
	b_end.size = Vector2(190, 66)
	UIKit.style_button(b_end, "danger", 24, 12)
	b_end.pressed.connect(func():
		SoundManager.play("click")
		_end_pressed())
	bhud.add_child(b_end)
	b_next = Button.new()
	b_next.size = Vector2(200, 80)
	UIKit.style_button(b_next, "primary", 26, 12)
	b_next.pressed.connect(func():
		SoundManager.play("click")
		_next_opponent())
	bhud.add_child(b_next)


func _start_battle(kind: String, map_i: int) -> void:
	battle_kind = kind
	battle_map = map_i
	mode = "battle"
	used = {}
	scout = SCOUT_TIME
	sim_acc = 0.0
	hud.visible = false
	_deselect()
	_cancel_place()
	hud.visible = false
	search_seed = randi()
	_setup_battle()
	bhud.visible = true


func _setup_battle() -> void:
	var layout: Array
	var loot: Dictionary
	if battle_kind == "campaign":
		var m: Dictionary = Data.campaign()[battle_map]
		layout = m["layout"]
		loot = village.campaign.get("loot_" + str(battle_map), {"gold": m["gold"], "elixir": m["elixir"]})
		battle_trophies = [0, 0]
	else:
		var base := BaseGen.opponent(village.th_level(), search_seed)
		layout = base["layout"]
		loot = {"gold": base["gold"], "elixir": base["elixir"]}
		battle_trophies = Data.trophy_offer(village.trophies, search_seed)
	battle_loot = loot.duplicate()
	battle = Battle.new()
	var lv := {}
	for k in Data.TROOPS:
		lv[k] = village.troop_level(k)
	battle.setup(layout, loot, village.army.duplicate(), lv)
	if battle_kind == "campaign":
		battle.time_limit = INF
	battle.shot.connect(func(a, b, k, eta):
		view.add_shot(a, b, k, eta)
		if k in ["cannon", "mortar"]:
			SoundManager.play("place"))
	battle.hit.connect(func(at, k):
		view.add_hit(at, k)
		if k in ["mortar", "bomb"]:
			SoundManager.play("bulldoze"))
	battle.destroyed.connect(func(b):
		view.add_dust(battle.center(b))
		SoundManager.play("bulldoze"))
	battle.loot.connect(func(_r, _a, _at): pass)
	view.battle = battle
	view.village = village
	troop_pick = ""
	for k in Data.TROOP_ORDER:
		if int(battle.army.get(k, 0)) > 0:
			troop_pick = k
			break
	_build_troop_bar()
	_center_on_village_battle()


func _center_on_village_battle() -> void:
	cam = IsoView.g2l(Vector2(Data.GRID * 0.5, Data.GRID * 0.5))
	zoom = 0.75
	_apply_camera()


func _build_troop_bar() -> void:
	for c in b_bar.get_children():
		c.queue_free()
	b_cards = {}
	for k in Data.TROOP_ORDER:
		if not battle.army.has(k):
			continue
		var b := Button.new()
		b.custom_minimum_size = Vector2(96, 112)
		b.flat = true
		var bg := Panel.new()
		bg.add_theme_stylebox_override("panel", UIKit.frame("card", 14))
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(bg)
		_icon(b, k, Vector2(8, 14), 80)
		var cnt := _label(b, "", 22, Vector2(6, 2), Vector2(84, 30), Color.WHITE)
		_label(b, str(village.troop_level(k)), 16, Vector2(6, 84), Vector2(30, 24), Color(0.6, 0.85, 1.0))
		var kind: String = k
		b.pressed.connect(func():
			SoundManager.play("click")
			troop_pick = kind
			_refresh_battle_hud())
		b_bar.add_child(b)
		b_cards[k] = {"btn": b, "bg": bg, "cnt": cnt}
	_refresh_battle_hud()


func _refresh_battle_hud() -> void:
	var tp: Control = bhud.get_node("time")
	tp.position.x = roundf((W - tp.size.x) * 0.5)
	tp.visible = battle_kind == "multi"
	var sp: Control = bhud.get_node("stars")
	sp.position = Vector2(W - 236, H - 130)
	b_bar.position = Vector2(16, H - 128)
	b_end.position = Vector2(16, H - 214)
	b_next.position = Vector2(W - 216, H - 230)
	b_next.visible = battle_kind == "multi" and not battle.started
	b_next.text = "다음  %s" % Data.short_number(Data.search_cost(village.th_level()))
	b_end.text = "항복" if battle.started else "전투 종료"
	var g := maxi(0, int(battle_loot.get("gold", 0)) - battle.gained["gold"])
	var e := maxi(0, int(battle_loot.get("elixir", 0)) - battle.gained["elixir"])
	b_loot.text = "%s\n%s" % [UIKit.format_number(g), UIKit.format_number(e)]
	if battle_kind == "multi":
		b_loot.text += ""
	if not battle.started:
		b_time_title.text = "전투 시작까지:"
		b_time.text = Data.clock_text(scout)
	else:
		b_time_title.text = "전투 종료까지:"
		b_time.text = Data.clock_text(battle.time_limit - battle.time)
	var s := battle.stars()
	b_stars.text = "★".repeat(s) + "☆".repeat(3 - s)
	b_percent.text = "전체 파괴율: %d%%" % battle.percent()
	for k in b_cards:
		var c: Dictionary = b_cards[k]
		var left := int(battle.army.get(k, 0))
		c["cnt"].text = "x%d" % left
		c["bg"].add_theme_stylebox_override("panel", UIKit.frame("card" if left > 0 else "card_off", 14))
		c["btn"].modulate = Color(1.25, 1.2, 0.8) if k == troop_pick else Color.WHITE
		if k == troop_pick:
			c["btn"].position.y = -10
	b_bar.queue_sort()


func _battle_process(delta: float) -> void:
	if not battle.started and battle_kind == "multi":
		scout -= delta
		if scout <= 0.0:
			battle.started = true               # the clock starts on its own after scouting
	# hold to drop a stream of troops
	if pressing and drag == "pan" and not moved and Time.get_ticks_msec() - press_ms > HOLD_MS:
		drag = "stream"
	if pressing and drag == "stream":
		stream_t -= delta
		if stream_t <= 0.0:
			stream_t = STREAM_GAP
			_deploy_at(finger)
	sim_acc += delta
	var steps := 0
	while sim_acc >= Battle.STEP and steps < 8:
		sim_acc -= Battle.STEP
		battle.step()
		steps += 1
	_refresh_battle_hud()
	if battle.over:
		_finish_battle()


func _deploy_at(p: Vector2) -> void:
	if troop_pick == "" or int(battle.army.get(troop_pick, 0)) <= 0:
		# pick the next troop that is left
		troop_pick = ""
		for k in Data.TROOP_ORDER:
			if int(battle.army.get(k, 0)) > 0:
				troop_pick = k
				break
		if troop_pick == "":
			return
	var g := screen_to_grid(p)
	if battle.deploy(troop_pick, g):
		used[troop_pick] = int(used.get(troop_pick, 0)) + 1
		SoundManager.play("click")
	else:
		view.show_deploy = 2.0
		if drag != "stream":
			SoundManager.play("invalid")
			_toast("빨간 곳에는 병사를 내보낼 수 없어요")


func _end_pressed() -> void:
	if not battle.started:
		# nothing used: back home (the search fee is spent)
		_back_home()
		return
	_confirm("정말 항복할까요?", func(): battle.over = true)


func _next_opponent() -> void:
	var cost := Data.search_cost(village.th_level())
	if village.gold < cost:
		_toast("금이 부족해요")
		return
	village.gold -= cost
	search_seed = randi()
	scout = SCOUT_TIME
	_setup_battle()


func _finish_battle() -> void:
	mode = "result"
	var stars := battle.stars()
	var gained: Dictionary = battle.gained.duplicate()
	var trophies := 0
	if battle_kind == "campaign":
		var key := str(battle_map)
		village.campaign[key] = maxi(int(village.campaign.get(key, 0)), stars)
		var left := {"gold": int(battle_loot["gold"]) - gained["gold"], "elixir": int(battle_loot["elixir"]) - gained["elixir"]}
		village.campaign["loot_" + key] = left
	else:
		trophies = battle_trophies[0] if stars > 0 else -battle_trophies[1]
		village.trophies = maxi(0, village.trophies + trophies)
	village.apply_battle(gained, used)
	village.gain_xp(stars * 2 if battle_kind == "multi" else 0)
	_save()
	SoundManager.play("rankup" if stars > 0 else "invalid")
	_show_result(stars, gained, trophies)


func _show_result(stars: int, gained: Dictionary, trophies: int) -> void:
	bhud.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	modal.add_child(dim)
	var title := _label(dim, "승리!" if stars > 0 else "패배", 64, Vector2(0, 40), Vector2(W, 90), Color(1.0, 0.85, 0.2) if stars > 0 else UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 14)
	for k in 3:
		var s := _icon(dim, "ic_star", Vector2(W * 0.5 - 190 + k * 130, 140 if k != 1 else 120), 120 if k != 1 else 140)
		s.modulate = Color(1.0, 0.85, 0.2) if k < stars else Color(0.3, 0.3, 0.35)
	_label(dim, "전체 파괴율 %d%%" % battle.percent(), 30, Vector2(0, 290), Vector2(W, 44), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var box := _panel(dim, Vector2(W * 0.5 - 260, 350), Vector2(520, 170))
	_label(box, "획득한 전리품", 22, Vector2(0, 8), Vector2(520, 30), UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_icon(box, "ic_gold", Vector2(60, 50), 44)
	_label(box, UIKit.format_number(gained["gold"]), 28, Vector2(110, 52), Vector2(140, 40))
	_icon(box, "ic_elixir", Vector2(280, 50), 44)
	_label(box, UIKit.format_number(gained["elixir"]), 28, Vector2(330, 52), Vector2(160, 40))
	if battle_kind == "multi":
		_icon(box, "ic_trophy", Vector2(180, 108), 44)
		_label(box, ("+%d" % trophies) if trophies >= 0 else str(trophies), 28, Vector2(232, 110), Vector2(140, 40), UIKit.GREEN if trophies >= 0 else UIKit.RED)
	var x := W * 0.5 - used.size() * 46.0
	if not used.is_empty():
		_label(dim, "사용한 병력", 20, Vector2(0, 528), Vector2(W, 30), UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	for k in Data.TROOP_ORDER:
		if used.has(k):
			_troop_chip(dim, k, "x%d" % used[k], Vector2(x, 560), Callable())
			x += 92
	var home := Button.new()
	home.text = "홈으로"
	home.position = Vector2(W * 0.5 + 300, H - 120)
	home.size = Vector2(240, 84)
	UIKit.style_button(home, "ok", 32, 14)
	home.pressed.connect(func():
		SoundManager.play("click")
		_close_modal()
		_back_home())
	dim.add_child(home)


func _back_home() -> void:
	mode = "village"
	battle = null
	view.battle = null
	view.effects = []
	bhud.visible = false
	hud.visible = true
	zoom = START_ZOOM
	_center_on_village()
	_apply_camera()
	_after_change()
