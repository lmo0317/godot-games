class_name LaneDeck
extends Control
# 블록 기사단 soldiers & deck screen (docs/LANE_UNITS.md), in the pixel-art UI (LaneUI): the gem bar,
# the 4 deck slots (tap one to take it out), the 8 soldiers as tier cards (LaneTierCard; missing ones
# dark "?"), and for the chosen soldier its stats on parchment, a deck in/out button and the merge
# button that spends duplicate copies to raise its star tier (노멀 → … → 전설) with a burst.

signal closed

const SLOT_SIZE: Vector2 = Vector2(140, 150)
const CARD_SIZE: Vector2 = Vector2(140, 140)

var gem_bar: Panel
var slots_box: HBoxContainer
var grid: GridContainer
var info_name: Label
var info_stats: Label
var info_desc: Label
var info_copies: Label
var action_btn: Button
var merge_btn: Button
var note: Label
var selected: String = "knight"
var _cards: Dictionary = {}           # kind -> LaneTierCard in the soldier grid

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
	var title := LaneUI.ribbon("병사 · 덱", 400, 32)
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
	var uh := LaneUI.label("보유 병사 · 같은 병사를 모아 합성하면 성급이 올라요", 20, LaneUI.GOLD)
	uh.position = Vector2(26, 14)
	uh.size = Vector2(640, 28)
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
	info.size = Vector2(680, 200)
	add_child(info)
	info_name = LaneUI.label("", 26, LaneUI.INK, HORIZONTAL_ALIGNMENT_LEFT, false)
	info_name.position = Vector2(26, 14)
	info_name.size = Vector2(630, 34)
	info.add_child(info_name)
	info_stats = LaneUI.label("", 18, Color(0.24, 0.18, 0.12), HORIZONTAL_ALIGNMENT_LEFT, false)
	info_stats.position = Vector2(26, 52)
	info_stats.size = Vector2(630, 28)
	info.add_child(info_stats)
	info_copies = LaneUI.label("", 18, Color(0.45, 0.2, 0.55), HORIZONTAL_ALIGNMENT_LEFT, false)
	info_copies.position = Vector2(26, 82)
	info_copies.size = Vector2(630, 28)
	info.add_child(info_copies)
	info_desc = LaneUI.label("", 18, Color(0.36, 0.25, 0.15), HORIZONTAL_ALIGNMENT_LEFT, false)
	info_desc.position = Vector2(26, 114)
	info_desc.size = Vector2(630, 76)
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(info_desc)

	action_btn = Button.new()
	LaneUI.button(action_btn, "blue", 22)
	action_btn.position = Vector2(20, 980)
	action_btn.size = Vector2(334, 76)
	action_btn.pressed.connect(_on_action)
	add_child(action_btn)
	merge_btn = Button.new()
	LaneUI.button(merge_btn, "red", 22)
	merge_btn.position = Vector2(366, 980)
	merge_btn.size = Vector2(334, 76)
	merge_btn.pressed.connect(_on_merge)
	add_child(merge_btn)
	note = LaneUI.label("", 18, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 1060)
	note.size = Vector2(720, 34)
	add_child(note)

	var back := Button.new()
	back.text = "본부로"
	LaneUI.button(back, "green", 22)
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
	_cards.clear()
	for i in range(LaneUnits.DECK_SIZE):
		slots_box.add_child(_slot(i, army["deck"][i], army))
	for k in LaneUnits.ORDER:
		grid.add_child(_unit_card(k, army))
	_show_info(army)

# A button showing a tier card (empty styleboxes; the card does the drawing)
func _card_button(sz: Vector2, tier: int, dark: bool = false) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var card := LaneTierCard.new(tier, sz)
	card.name = "Card"
	if dark:
		card.modulate = Color(0.45, 0.45, 0.5)
	b.add_child(card)
	b.pivot_offset = sz * 0.5
	b.button_down.connect(func(): b.scale = Vector2(0.95, 0.95))
	b.button_up.connect(func(): b.scale = Vector2.ONE)
	return b

func _slot(i: int, kind: String, army: Dictionary) -> Button:
	if kind == "":
		var e := _card_button(SLOT_SIZE, 0, true)
		e.name = "Slot%d" % i
		var t := LaneUI.label("빈 칸", 20, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
		t.size = SLOT_SIZE
		t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		e.add_child(t)
		return e
	var u: Dictionary = LaneUnits.UNITS[kind]
	var tier: int = int(army["owned"][kind]["tier"])
	var b := _card_button(SLOT_SIZE, tier)
	b.name = "Slot%d" % i
	_fill(b, kind, LaneUnits.TIER_NAME[tier], SLOT_SIZE, tier, false, u["cost"])
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
	var owned: bool = army["owned"].has(kind)
	var tier: int = int(army["owned"][kind]["tier"]) if owned else int(LaneUnits.UNITS[kind]["tier"])
	var b := _card_button(CARD_SIZE, tier, not owned)
	b.name = "Unit_%s" % kind
	_cards[kind] = b.get_node("Card")
	var line: String = LaneUnits.TIER_NAME[tier] + ("  · 덱" if owned and army["deck"].has(kind) else "") if owned else "미보유"
	_fill(b, kind, line, CARD_SIZE, tier, not owned)
	if kind == selected:
		# Selected: a gold outline that breathes
		var mark := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_border_width_all(4)
		sb.border_color = LaneUI.GOLD
		sb.set_corner_radius_all(8)
		mark.add_theme_stylebox_override("panel", sb)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		b.add_child(mark)
		var mt := mark.create_tween().set_loops()
		mt.tween_property(mark, "modulate:a", 0.4, 0.6)
		mt.tween_property(mark, "modulate:a", 1.0, 0.6)
	if owned and LaneUnits.can_merge(kind):
		var badge := LaneUI.label("합성!", 15, Color(0.6, 1.0, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
		badge.position = Vector2(0, 8)
		badge.size = Vector2(CARD_SIZE.x - 12, 20)
		b.add_child(badge)
		var tw := badge.create_tween().set_loops()
		tw.tween_property(badge, "modulate:a", 0.35, 0.5)
		tw.tween_property(badge, "modulate:a", 1.0, 0.5)
	b.pressed.connect(func():
		selected = kind
		note.text = ""
		SoundManager.play_click()
		refresh())
	return b

func _fill(b: Button, kind: String, line: String, sz: Vector2, tier: int, dark: bool = false, cost: int = -1) -> void:
	var u: Dictionary = LaneUnits.UNITS[kind]
	var card: LaneTierCard = b.get_node("Card")
	var art := TextureRect.new()
	art.texture = load("res://assets/art/lane/%s.png" % kind)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(16, 14)
	art.size = Vector2(sz.x - 32, sz.y - 70)
	if dark:
		art.modulate = Color(0.05, 0.05, 0.08)
	card.add_child(art)
	var n := LaneUI.label("?" if dark else u["name"], 18, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	n.position = Vector2(0, sz.y - 58)
	n.size = Vector2(sz.x, 24)
	card.add_child(n)
	var l := LaneUI.label(line, 15, Color(0.75, 0.75, 0.8) if dark else LaneUnits.tier_color(tier).lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(0, sz.y - 34)
	l.size = Vector2(sz.x, 22)
	card.add_child(l)
	if cost >= 0:
		var coin := LaneUI.icon("icon_coin", Vector2(18, 18))
		coin.position = Vector2(sz.x - 66, 12)
		card.add_child(coin)
		var c := LaneUI.label(str(cost), 16, LaneUI.GOLD)
		c.position = Vector2(sz.x - 46, 8)
		c.size = Vector2(40, 24)
		card.add_child(c)

func _show_info(army: Dictionary) -> void:
	var u: Dictionary = LaneUnits.UNITS[selected]
	var owned: bool = army["owned"].has(selected)
	var tier: int = int(army["owned"][selected]["tier"]) if owned else int(u["tier"])
	var copies: int = int(army["owned"][selected]["copies"]) if owned else 0
	var st: Dictionary = LaneUnits.stats(selected, tier)
	info_name.text = "%s  ·  %s  ·  %s" % [u["name"], u["role"], LaneUnits.TIER_NAME[tier]]
	info_name.add_theme_color_override("font_color", LaneUnits.tier_color(tier).darkened(0.45) if tier > 0 else LaneUI.INK)
	info_stats.text = "체력 %d   공격 %d   사거리 %d   금화 %d   대기 %d초" % [roundi(st["hp"]), roundi(st["atk"]), int(u["range"]), u["cost"], int(u["cool"])]
	if not owned:
		info_copies.text = "뽑기로 얻을 수 있어요"
	elif tier >= LaneUnits.MAX_TIER:
		info_copies.text = "최고 성급(전설)이에요"
	else:
		info_copies.text = "복제 %d / %d  →  %s (체력·공격 +%d%%)" % [copies, LaneUnits.merge_need(tier), LaneUnits.TIER_NAME[tier + 1], roundi(LaneUnits.TIER_BONUS * 100.0)]
	info_desc.text = u["desc"]
	if not owned:
		action_btn.text = "아직 없는 병사"
		action_btn.disabled = true
	elif army["deck"].has(selected):
		action_btn.text = "덱에서 빼기"
		action_btn.disabled = false
	else:
		action_btn.text = "덱에 넣기"
		action_btn.disabled = false
	merge_btn.text = "합성 · 성급 올리기" if owned and tier < LaneUnits.MAX_TIER else ("최고 성급" if owned else "합성")
	merge_btn.disabled = not (owned and LaneUnits.can_merge(selected))

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

# Merge: spend copies, go up a tier, then a burst on the card and a banner with the new tier
func _on_merge() -> void:
	var t: int = LaneUnits.merge(selected)
	if t < 0:
		note.text = "복제가 모자라요"
		return
	refresh()
	var card: LaneTierCard = _cards.get(selected)
	if card == null:
		return
	card.burst()
	var center: Vector2 = card.get_global_rect().get_center()
	var col: Color = LaneUnits.tier_color(t)
	for i in range(14):
		var s := LaneUI.icon("icon_star", Vector2(18, 18))
		s.top_level = true
		s.position = center - s.size * 0.5
		s.modulate = col.lightened(0.3)
		add_child(s)
		var a: float = TAU * i / 14.0
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", center + Vector2(cos(a), sin(a)) * randf_range(70, 120) - s.size * 0.5, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "rotation", 2.0, 0.5)
		tw.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.3)
		tw.chain().tween_callback(s.queue_free)
	var banner := LaneUI.label("%s 달성!" % LaneUnits.TIER_NAME[t], 44, col.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER)
	banner.position = Vector2(0, 560)
	banner.size = Vector2(720, 60)
	banner.pivot_offset = banner.size * 0.5
	banner.scale = Vector2(0.3, 0.3)
	banner.z_index = 5
	add_child(banner)
	var bt := banner.create_tween()
	bt.tween_property(banner, "scale", Vector2(1.15, 1.15), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bt.tween_property(banner, "scale", Vector2.ONE, 0.1)
	bt.tween_interval(0.9)
	bt.tween_property(banner, "modulate:a", 0.0, 0.3)
	bt.tween_callback(banner.queue_free)
	SoundManager.play("fever")
	note.text = "%s이(가) %s(으)로 올랐어요!" % [LaneUnits.UNITS[selected]["name"], LaneUnits.TIER_NAME[t]]
