class_name LaneDeck
extends ColorRect
# 블록 기사단 deck screen (docs/LANE_UNITS.md): the 4 deck slots on top (tap one to take it out),
# the 8 soldiers below (owned ones bright with their level, missing ones as dark "?"), and the chosen
# soldier's stats with a button to put it in or take it out.

signal closed

const SLOT_SIZE: Vector2 = Vector2(136, 150)
const CARD_SIZE: Vector2 = Vector2(136, 140)

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
	color = Color(UIKit.BG, 0.99)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var card := Panel.new()
	UIKit.style_modal(card)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -340
	card.offset_right = 340
	card.offset_top = -560
	card.offset_bottom = 560
	add_child(card)

	var title := UIKit.label("덱 편성", UIKit.TYPE_MODAL_TITLE, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 22)
	title.size = Vector2(680, 52)
	card.add_child(title)
	var sub := UIKit.label("전투에서는 덱 4칸의 병사만 소환할 수 있어요", 17, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 74)
	sub.size = Vector2(680, 26)
	card.add_child(sub)

	slots_box = HBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 12)
	slots_box.position = Vector2((680 - (SLOT_SIZE.x * 4 + 36)) * 0.5, 110)
	card.add_child(slots_box)

	var have := UIKit.label("병사", UIKit.TYPE_SECTION, UIKit.GOLD)
	have.position = Vector2(46, 274)
	have.size = Vector2(300, 30)
	card.add_child(have)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.position = Vector2((680 - (CARD_SIZE.x * 4 + 36)) * 0.5, 308)
	card.add_child(grid)

	var info := Panel.new()
	info.add_theme_stylebox_override("panel", UIKit.inset(16))
	info.position = Vector2(40, 620)
	info.size = Vector2(600, 196)
	card.add_child(info)
	info_name = UIKit.label("", 26, UIKit.TEXT)
	info_name.position = Vector2(20, 12)
	info_name.size = Vector2(560, 34)
	info.add_child(info_name)
	info_stats = UIKit.label("", 17, Color(0.75, 0.88, 1.0))
	info_stats.position = Vector2(20, 50)
	info_stats.size = Vector2(560, 52)
	info_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(info_stats)
	info_desc = UIKit.label("", 18, UIKit.MUTED)
	info_desc.position = Vector2(20, 104)
	info_desc.size = Vector2(560, 80)
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(info_desc)

	action_btn = Button.new()
	UIKit.style_button(action_btn, "primary", 24, 18)
	action_btn.position = Vector2(40, 832)
	action_btn.size = Vector2(600, 70)
	action_btn.pressed.connect(_on_action)
	card.add_child(action_btn)
	note = UIKit.label("", 17, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 908)
	note.size = Vector2(680, 26)
	card.add_child(note)

	var back := Button.new()
	back.text = "돌아가기"
	UIKit.style_button(back, "secondary", 22, 18)
	back.position = Vector2(40, 1120 - 86)
	back.size = Vector2(600, 58)
	back.pressed.connect(close)
	card.add_child(back)

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

func _slot(i: int, kind: String, army: Dictionary) -> Button:
	var b := Button.new()
	b.name = "Slot%d" % i
	b.custom_minimum_size = SLOT_SIZE
	b.focus_mode = Control.FOCUS_NONE
	if kind == "":
		UIKit.style_button(b, "secondary", 18, 16)
		b.text = "빈 칸"
		return b
	var u: Dictionary = LaneUnits.UNITS[kind]
	UIKit.style_raised(b, UIKit.SURFACE_HI, LaneUnits.RARITY_COLOR[u["rarity"]], Color(0.02, 0.03, 0.06), 16)
	_fill(b, kind, "Lv %d · 금화 %d" % [int(army["owned"].get(kind, 1)), u["cost"]], SLOT_SIZE)
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
	var b := Button.new()
	b.name = "Unit_%s" % kind
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_NONE
	var border: Color = LaneUnits.RARITY_COLOR[u["rarity"]] if owned else Color(UIKit.BORDER, 0.7)
	if kind == selected:
		border = Color.WHITE
	UIKit.style_raised(b, UIKit.SURFACE_HI if owned else UIKit.SURFACE, border, Color(0.02, 0.03, 0.06), 16)
	var line: String = ("Lv %d" % int(army["owned"][kind])) + ("  · 덱" if army["deck"].has(kind) else "") if owned else "미보유"
	_fill(b, kind, line, CARD_SIZE, not owned)
	b.pressed.connect(func():
		selected = kind
		note.text = ""
		SoundManager.play_click()
		refresh())
	return b

func _fill(b: Button, kind: String, line: String, sz: Vector2, dark: bool = false) -> void:
	var u: Dictionary = LaneUnits.UNITS[kind]
	var art := TextureRect.new()
	art.texture = load("res://assets/art/lane/%s.png" % kind)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(10, 8)
	art.size = Vector2(sz.x - 20, sz.y - 66)
	if dark:
		art.modulate = Color(0.08, 0.08, 0.12)
	b.add_child(art)
	var n := UIKit.label("?" if dark else u["name"], 18, UIKit.MUTED if dark else UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	n.position = Vector2(0, sz.y - 58)
	n.size = Vector2(sz.x, 24)
	b.add_child(n)
	var l := UIKit.label(line, 14, UIKit.MUTED if dark else Color(0.7, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(0, sz.y - 34)
	l.size = Vector2(sz.x, 22)
	b.add_child(l)

func _show_info(army: Dictionary) -> void:
	var u: Dictionary = LaneUnits.UNITS[selected]
	var owned: bool = army["owned"].has(selected)
	var lv: int = int(army["owned"].get(selected, 1))
	var st: Dictionary = LaneUnits.stats(selected, lv)
	info_name.text = "%s  ·  %s  ·  %s" % [u["name"], u["role"], LaneUnits.RARITY_NAME[u["rarity"]]]
	info_name.add_theme_color_override("font_color", LaneUnits.RARITY_COLOR[u["rarity"]])
	info_stats.text = "Lv %d   체력 %d   공격 %d   사거리 %d   금화 %d   대기 %d초" % [lv, roundi(st["hp"]), roundi(st["atk"]), int(u["range"]), u["cost"], int(u["cool"])]
	info_desc.text = u["desc"] if owned else "뽑기로 얻을 수 있어요. " + u["desc"]
	if not owned:
		action_btn.text = "아직 없는 병사"
		action_btn.disabled = true
	elif army["deck"].has(selected):
		action_btn.text = "덱에서 빼기"
		action_btn.disabled = false
	else:
		action_btn.text = "덱에 넣기"
		action_btn.disabled = false

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
