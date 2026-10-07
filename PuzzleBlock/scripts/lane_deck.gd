class_name LaneDeck
extends Control
# 블록 기사단 deck screen (docs/LANE_UNITS.md), in the pixel-art UI (LaneUI): the gem bar, the 4 deck
# slots on a wooden board (tap one to take it out), the 8 soldiers as stone cards tinted by grade
# (missing ones dark "?"), the chosen soldier's stats on parchment and a button to put it in or out.

signal closed

const SLOT_SIZE: Vector2 = Vector2(140, 150)
const CARD_SIZE: Vector2 = Vector2(140, 140)
const GRADE_TINT: Dictionary = {1: Color(1, 1, 1), 2: Color(0.6, 0.8, 1.25), 3: Color(1.35, 1.1, 0.5)}

var gem_bar: Panel
var slots_box: HBoxContainer
var grid: GridContainer
var info_name: Label
var info_stats: Label
var info_desc: Label
var action_btn: Button
var note: Label
var selected: String = "knight"

func _ready() -> void:
	visible = false
	z_index = 160
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	LaneUI.backdrop(self)

	gem_bar = LaneUI.gem_bar(680)
	gem_bar.position = Vector2(20, 18)
	add_child(gem_bar)
	var title := LaneUI.ribbon("덱 편성", 400, 32)
	title.position = Vector2(160, 92)
	add_child(title)

	var deck_board := Panel.new()
	LaneUI.dress(deck_board, "panel_wood")
	deck_board.position = Vector2(20, 166)
	deck_board.size = Vector2(680, 226)
	add_child(deck_board)
	var dh := LaneUI.label("덱 · 전투에서는 이 4명만 소환해요", 20, LaneUI.GOLD)
	dh.position = Vector2(26, 14)
	dh.size = Vector2(620, 28)
	deck_board.add_child(dh)
	slots_box = HBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 12)
	slots_box.position = Vector2((680 - (SLOT_SIZE.x * 4 + 36)) * 0.5, 50)
	deck_board.add_child(slots_box)

	var unit_board := Panel.new()
	LaneUI.dress(unit_board, "panel_wood")
	unit_board.position = Vector2(20, 400)
	unit_board.size = Vector2(680, 362)
	add_child(unit_board)
	var uh := LaneUI.label("병사", 20, LaneUI.GOLD)
	uh.position = Vector2(26, 14)
	uh.size = Vector2(300, 28)
	unit_board.add_child(uh)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.position = Vector2((680 - (CARD_SIZE.x * 4 + 36)) * 0.5, 50)
	unit_board.add_child(grid)

	var info := Panel.new()
	LaneUI.dress(info, "panel_paper")
	info.position = Vector2(20, 770)
	info.size = Vector2(680, 186)
	add_child(info)
	info_name = LaneUI.label("", 26, LaneUI.INK, HORIZONTAL_ALIGNMENT_LEFT, false)
	info_name.position = Vector2(26, 16)
	info_name.size = Vector2(630, 34)
	info.add_child(info_name)
	info_stats = LaneUI.label("", 18, Color(0.24, 0.18, 0.12), HORIZONTAL_ALIGNMENT_LEFT, false)
	info_stats.position = Vector2(26, 54)
	info_stats.size = Vector2(630, 30)
	info.add_child(info_stats)
	info_desc = LaneUI.label("", 19, Color(0.36, 0.25, 0.15), HORIZONTAL_ALIGNMENT_LEFT, false)
	info_desc.position = Vector2(26, 92)
	info_desc.size = Vector2(630, 80)
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(info_desc)

	action_btn = Button.new()
	LaneUI.button(action_btn, "green", 24)
	action_btn.position = Vector2(20, 966)
	action_btn.size = Vector2(680, 78)
	action_btn.pressed.connect(_on_action)
	add_child(action_btn)
	note = LaneUI.label("", 18, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 1050)
	note.size = Vector2(720, 34)
	add_child(note)

	var back := Button.new()
	back.text = "본부로"
	LaneUI.button(back, "blue", 22)
	back.position = Vector2(220, 1100)
	back.size = Vector2(280, 64)
	back.pressed.connect(close)
	add_child(back)

func open() -> void:
	SoundManager.play_click()
	note.text = ""
	refresh()
	visible = true

func close() -> void:
	SoundManager.play_click()
	visible = false
	closed.emit()

func refresh() -> void:
	LaneUI.set_gem_bar(gem_bar)
	var army: Dictionary = LaneUnits.load_army()
	for c in slots_box.get_children():
		c.queue_free()
	for c in grid.get_children():
		c.queue_free()
	for i in range(LaneUnits.DECK_SIZE):
		slots_box.add_child(_slot(i, army["deck"][i], army))
	for k in LaneUnits.ORDER:
		grid.add_child(_unit_card(k, army))
	_show_info(army)

# A stone card button tinted by grade (and lit when selected)
func _card_button(sz: Vector2, tint: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_stylebox_override("normal", LaneUI.box("card_frame", 8, tint))
	b.add_theme_stylebox_override("hover", LaneUI.box("card_frame", 8, tint * 1.15))
	b.add_theme_stylebox_override("pressed", LaneUI.box("card_frame", 8, tint * 0.85))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b

func _slot(i: int, kind: String, army: Dictionary) -> Button:
	if kind == "":
		var e := _card_button(SLOT_SIZE, Color(0.55, 0.55, 0.6))
		e.name = "Slot%d" % i
		var t := LaneUI.label("빈 칸", 20, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
		t.size = SLOT_SIZE
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		e.add_child(t)
		return e
	var u: Dictionary = LaneUnits.UNITS[kind]
	var b := _card_button(SLOT_SIZE, GRADE_TINT[u["rarity"]])
	b.name = "Slot%d" % i
	_fill(b, kind, "Lv %d" % int(army["owned"].get(kind, 1)), SLOT_SIZE, false, u["cost"])
	b.pressed.connect(func():
		selected = kind
		if army["deck"].filter(func(k): return k != "").size() <= 1:
			note.text = "덱에는 1명 이상 있어야 해요"
		else:
			LaneUnits.set_deck_slot(i, "")
			note.text = "%s을(를) 덱에서 뺐어요" % u["name"]
		SoundManager.play_click()
		refresh())
	return b

func _unit_card(kind: String, army: Dictionary) -> Button:
	var u: Dictionary = LaneUnits.UNITS[kind]
	var owned: bool = army["owned"].has(kind)
	var tint: Color = GRADE_TINT[u["rarity"]] if owned else Color(0.4, 0.4, 0.45)
	if kind == selected:
		tint = Color(1.5, 1.35, 0.85)
	var b := _card_button(CARD_SIZE, tint)
	b.name = "Unit_%s" % kind
	var line: String = ("Lv %d" % int(army["owned"][kind])) + ("  · 덱" if army["deck"].has(kind) else "") if owned else "미보유"
	_fill(b, kind, line, CARD_SIZE, not owned)
	b.pressed.connect(func():
		selected = kind
		note.text = ""
		SoundManager.play_click()
		refresh())
	return b

func _fill(b: Button, kind: String, line: String, sz: Vector2, dark: bool = false, cost: int = -1) -> void:
	var u: Dictionary = LaneUnits.UNITS[kind]
	var art := TextureRect.new()
	art.texture = load("res://assets/art/lane/%s.png" % kind)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(16, 14)
	art.size = Vector2(sz.x - 32, sz.y - 70)
	if dark:
		art.modulate = Color(0.06, 0.06, 0.1)
	b.add_child(art)
	var n := LaneUI.label("?" if dark else u["name"], 18, Color(0.7, 0.7, 0.75) if dark else LaneUnits.RARITY_COLOR[u["rarity"]].lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER)
	n.position = Vector2(0, sz.y - 58)
	n.size = Vector2(sz.x, 24)
	b.add_child(n)
	var l := LaneUI.label(line, 15, Color(0.7, 0.7, 0.75) if dark else Color(0.85, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(0, sz.y - 34)
	l.size = Vector2(sz.x, 22)
	b.add_child(l)
	if cost >= 0:
		var coin := LaneUI.icon("icon_coin", Vector2(18, 18))
		coin.position = Vector2(sz.x - 66, 12)
		b.add_child(coin)
		var c := LaneUI.label(str(cost), 16, LaneUI.GOLD)
		c.position = Vector2(sz.x - 46, 8)
		c.size = Vector2(40, 24)
		b.add_child(c)

func _show_info(army: Dictionary) -> void:
	var u: Dictionary = LaneUnits.UNITS[selected]
	var owned: bool = army["owned"].has(selected)
	var lv: int = int(army["owned"].get(selected, 1))
	var st: Dictionary = LaneUnits.stats(selected, lv)
	info_name.text = "%s  ·  %s  ·  %s" % [u["name"], u["role"], LaneUnits.RARITY_NAME[u["rarity"]]]
	info_stats.text = "Lv %d   체력 %d   공격 %d   사거리 %d   금화 %d   대기 %d초" % [lv, roundi(st["hp"]), roundi(st["atk"]), int(u["range"]), u["cost"], int(u["cool"])]
	info_desc.text = u["desc"] if owned else "뽑기로 얻을 수 있어요. " + u["desc"]
	if not owned:
		action_btn.text = "아직 없는 병사"
		action_btn.disabled = true
	elif army["deck"].has(selected):
		action_btn.text = "덱에서 빼기"
		action_btn.disabled = false
		LaneUI.button(action_btn, "red", 24)
	else:
		action_btn.text = "덱에 넣기"
		action_btn.disabled = false
		LaneUI.button(action_btn, "green", 24)

func _on_action() -> void:
	var army: Dictionary = LaneUnits.load_army()
	if not army["owned"].has(selected):
		return
	var at: int = army["deck"].find(selected)
	if at >= 0:
		if army["deck"].filter(func(k): return k != "").size() <= 1:
			note.text = "덱에는 1명 이상 있어야 해요"
		else:
			LaneUnits.set_deck_slot(at, "")
			note.text = "덱에서 뺐어요"
	else:
		var empty: int = army["deck"].find("")
		if empty < 0:
			note.text = "덱이 가득 찼어요. 위의 칸을 눌러 한 명을 빼 주세요"
		else:
			LaneUnits.set_deck_slot(empty, selected)
			note.text = "덱에 넣었어요"
	SoundManager.play_click()
	refresh()
