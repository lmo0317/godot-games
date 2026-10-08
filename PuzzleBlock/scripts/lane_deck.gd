class_name LaneDeck
extends Control
# 블록 기사단 soldiers & deck screen (docs/LANE_UNITS.md "병사·덱 화면"), in the pixel-art UI
# (LaneUI), laid out like a card collection (Clash Royale):
#   the gem bar; the 4 deck slots (tap one to take it out); "보유 n / 16" and the 16 soldiers as big
#   tier cards (LaneTierCard) with the soldier, its name and a copies bar toward the next merge
#   (green and "합성!" when ready; missing soldiers dark "?"); tapping a card opens its detail: the
#   soldier big, tier, role, stats, the copies bar, what the next tier gives, the description, and
#   [덱에 넣기/빼기] [합성 · 성급 올리기] (spends copies, burst and banner).

signal closed

const SLOT_SIZE: Vector2 = Vector2(140, 150)
const CARD_SIZE: Vector2 = Vector2(150, 150)   # 16 soldiers: 4 x 4
const DETAIL_CARD: Vector2 = Vector2(250, 290)

var gem_bar: Panel
var slots_box: HBoxContainer
var grid: GridContainer
var count_label: Label
var power_label: Label
var note: Label
var selected: String = "knight"
var _cards: Dictionary = {}           # kind -> LaneTierCard in the collection

# Detail popup
var detail: Control
var _detail_card_holder: Control
var info_name: Label
var info_role: Label
var info_stats: Label
var info_copies: Label
var info_next: Label
var info_desc: Label
var _detail_bar: Panel
var action_btn: Button
var merge_btn: Button

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
	deck_board.position = Vector2(20, 160)
	deck_board.size = Vector2(680, 250)
	add_child(deck_board)
	var dh := LaneUI.label("덱 · 전투에서는 이 4명만 나가요", 20, LaneUI.GOLD)
	dh.position = Vector2(26, 12)
	dh.size = Vector2(400, 28)
	deck_board.add_child(dh)
	power_label = LaneUI.label("", 20, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	power_label.position = Vector2(420, 12)
	power_label.size = Vector2(234, 28)
	deck_board.add_child(power_label)
	slots_box = HBoxContainer.new()
	slots_box.add_theme_constant_override("separation", 12)
	slots_box.position = Vector2((680 - (SLOT_SIZE.x * 4 + 36)) * 0.5, 46)
	deck_board.add_child(slots_box)
	note = LaneUI.label("", 16, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 202)
	note.size = Vector2(680, 24)
	deck_board.add_child(note)

	var unit_board := Panel.new()
	LaneUI.dress(unit_board, "panel_wood")
	unit_board.position = Vector2(20, 418)
	unit_board.size = Vector2(680, 676)
	add_child(unit_board)
	count_label = LaneUI.label("", 22, LaneUI.GOLD)
	count_label.position = Vector2(26, 12)
	count_label.size = Vector2(300, 30)
	unit_board.add_child(count_label)
	var uh := LaneUI.label("카드를 누르면 자세히 · 같은 병사를 모아 합성", 16, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	uh.position = Vector2(300, 16)
	uh.size = Vector2(354, 24)
	unit_board.add_child(uh)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.position = Vector2((680 - (CARD_SIZE.x * 4 + 30)) * 0.5, 48)
	unit_board.add_child(grid)

	var back := Button.new()
	back.text = "본부로"
	LaneUI.button(back, "green", 22)
	back.position = Vector2(220, 1104)
	back.size = Vector2(280, 64)
	back.pressed.connect(close)
	add_child(back)

	_build_detail()

func open() -> void:
	SoundManager.play_click()
	note.text = ""
	detail.visible = false
	refresh()
	visible = true

func close() -> void:
	SoundManager.play_click()
	detail.visible = false
	visible = false
	closed.emit()

# Back (Android / browser): the detail first, then the screen
func back_pressed() -> void:
	if detail.visible:
		SoundManager.play_click()
		detail.visible = false
	else:
		close()

func refresh() -> void:
	LaneUI.set_gem_bar(gem_bar)
	var army: Dictionary = LaneUnits.load_army()
	power_label.text = "전투력 %d" % LaneUnits.deck_power(army)
	count_label.text = "보유 병사 %d / %d" % [army["owned"].size(), LaneUnits.ORDER.size()]
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

# The soldier at a whole-number scale that fits the area, centred at the top of a card
func _art(card: Control, kind: String, area: Vector2, top: float, dark: bool) -> TextureRect:
	var tex: Texture2D = load("res://assets/art/lane/%s.png" % kind)
	var art := TextureRect.new()
	art.texture = tex
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Rounded, so a tall soldier still gets the bigger scale and stands a little over the frame top
	var k: float = maxf(1.0, roundf(minf(area.x / tex.get_width(), area.y / tex.get_height())))
	art.size = Vector2(tex.get_width(), tex.get_height()) * k
	art.position = Vector2((card.size.x - art.size.x) * 0.5, top + area.y - art.size.y)
	if dark:
		art.modulate = Color(0.05, 0.05, 0.08)
	card.add_child(art)
	return art

# Copies toward the next merge: a bar with "n / m", green and "합성!" when ready
func _copies_bar(parent: Control, pos: Vector2, sz: Vector2, kind: String, army: Dictionary, font: int) -> Panel:
	var bar := Panel.new()
	bar.position = pos
	bar.size = sz
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.04, 0.08, 0.85), Color(0.0, 0.0, 0.0, 0.6), 6, 2))
	parent.add_child(bar)
	var text: String = "미보유"
	var ratio: float = 0.0
	var col := Color(0.35, 0.6, 1.0)
	if army["owned"].has(kind):
		var o: Dictionary = army["owned"][kind]
		var need: int = LaneUnits.merge_need(int(o["tier"]))
		if need <= 0:
			text = "MAX"
			ratio = 1.0
			col = LaneUI.GOLD
		else:
			ratio = clampf(float(o["copies"]) / need, 0.0, 1.0)
			text = "합성!" if o["copies"] >= need else "%d / %d" % [o["copies"], need]
			if o["copies"] >= need:
				col = Color(0.35, 0.85, 0.35)
	var fill := Panel.new()
	fill.position = Vector2(3, 3)
	fill.size = Vector2((sz.x - 6) * ratio, sz.y - 6)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", UIKit.box(col, Color.TRANSPARENT, 4))
	fill.visible = ratio > 0.0
	bar.add_child(fill)
	var l := LaneUI.label(text, font, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = sz
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(l)
	return bar

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
	var card: Control = b.get_node("Card")
	_art(card, kind, Vector2(SLOT_SIZE.x - 20, 90), 12, false)
	var n := LaneUI.label(u["name"], 18, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	n.position = Vector2(0, SLOT_SIZE.y - 50)
	n.size = Vector2(SLOT_SIZE.x, 24)
	card.add_child(n)
	var coin := LaneUI.icon("icon_coin", Vector2(16, 16))
	coin.position = Vector2(SLOT_SIZE.x * 0.5 - 26, SLOT_SIZE.y - 26)
	card.add_child(coin)
	var c := LaneUI.label(str(u["cost"]), 15, LaneUI.GOLD)
	c.position = Vector2(SLOT_SIZE.x * 0.5 - 6, SLOT_SIZE.y - 30)
	c.size = Vector2(50, 22)
	card.add_child(c)
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
	var u: Dictionary = LaneUnits.UNITS[kind]
	var tier: int = int(army["owned"][kind]["tier"]) if owned else int(u["tier"])
	var b := _card_button(CARD_SIZE, tier, not owned)
	b.name = "Unit_%s" % kind
	var card: Control = b.get_node("Card")
	_cards[kind] = card
	_art(card, kind, Vector2(CARD_SIZE.x - 20, 92), 6, not owned)
	var n := LaneUI.label(u["name"] if owned else "?", 16, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	n.position = Vector2(0, 98)
	n.size = Vector2(CARD_SIZE.x, 22)
	card.add_child(n)
	_copies_bar(card, Vector2(14, 122), Vector2(CARD_SIZE.x - 28, 20), kind, army, 13)
	if owned and army["deck"].has(kind):
		var d := LaneUI.label("덱", 15, Color(0.6, 1.0, 0.6))
		d.position = Vector2(30, 6)
		d.size = Vector2(30, 20)
		card.add_child(d)
	if owned and LaneUnits.can_merge(kind):
		var tw := b.create_tween().set_loops()
		tw.tween_property(card, "modulate", Color(1.25, 1.25, 1.1), 0.5)
		tw.tween_property(card, "modulate", Color.WHITE, 0.5)
	b.pressed.connect(func():
		selected = kind
		note.text = ""
		SoundManager.play_click()
		_show_info(LaneUnits.load_army())
		_open_detail())
	return b

# ---------------------------------------------------------------------------
# Detail popup

func _build_detail() -> void:
	detail = Control.new()
	detail.visible = false
	detail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(detail)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.06, 0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
			back_pressed())
	detail.add_child(shade)
	var board := Panel.new()
	board.name = "Board"
	LaneUI.dress(board, "panel_wood")
	board.position = Vector2(30, 240)
	board.size = Vector2(660, 760)
	detail.add_child(board)
	_detail_card_holder = Control.new()
	_detail_card_holder.position = Vector2(24, 26)
	_detail_card_holder.size = DETAIL_CARD
	board.add_child(_detail_card_holder)
	info_name = LaneUI.label("", 32, LaneUI.TEXT)
	info_name.position = Vector2(292, 26)
	info_name.size = Vector2(350, 42)
	board.add_child(info_name)
	info_role = LaneUI.label("", 20, LaneUI.GOLD)
	info_role.position = Vector2(292, 72)
	info_role.size = Vector2(350, 28)
	board.add_child(info_role)
	info_stats = LaneUI.label("", 19, LaneUI.TEXT)
	info_stats.position = Vector2(292, 108)
	info_stats.size = Vector2(350, 130)
	board.add_child(info_stats)
	info_copies = LaneUI.label("", 18, LaneUI.TEXT)
	info_copies.position = Vector2(292, 238)
	info_copies.size = Vector2(350, 26)
	board.add_child(info_copies)
	_detail_bar = Panel.new()
	_detail_bar.position = Vector2(292, 268)
	_detail_bar.size = Vector2(340, 30)
	_detail_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	board.add_child(_detail_bar)
	var paper := Panel.new()
	LaneUI.dress(paper, "panel_paper")
	paper.position = Vector2(24, 334)
	paper.size = Vector2(612, 200)
	board.add_child(paper)
	info_next = LaneUI.label("", 19, Color(0.45, 0.2, 0.55), HORIZONTAL_ALIGNMENT_LEFT, false)
	info_next.position = Vector2(20, 16)
	info_next.size = Vector2(572, 28)
	paper.add_child(info_next)
	info_desc = LaneUI.label("", 20, LaneUI.INK, HORIZONTAL_ALIGNMENT_LEFT, false)
	info_desc.position = Vector2(20, 54)
	info_desc.size = Vector2(572, 130)
	info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	paper.add_child(info_desc)
	action_btn = Button.new()
	LaneUI.button(action_btn, "blue", 22)
	action_btn.position = Vector2(24, 556)
	action_btn.size = Vector2(300, 80)
	action_btn.pressed.connect(_on_action)
	board.add_child(action_btn)
	merge_btn = Button.new()
	LaneUI.button(merge_btn, "red", 22)
	merge_btn.position = Vector2(336, 556)
	merge_btn.size = Vector2(300, 80)
	merge_btn.pressed.connect(_on_merge)
	board.add_child(merge_btn)
	var shut := Button.new()
	shut.text = "닫기"
	LaneUI.button(shut, "grey", 20)
	shut.position = Vector2(210, 660)
	shut.size = Vector2(240, 64)
	shut.pressed.connect(back_pressed)
	board.add_child(shut)

func _open_detail() -> void:
	detail.visible = true
	var board: Control = detail.get_node("Board")
	board.pivot_offset = board.size * 0.5
	board.scale = Vector2(0.9, 0.9)
	board.create_tween().tween_property(board, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _show_info(army: Dictionary) -> void:
	var u: Dictionary = LaneUnits.UNITS[selected]
	var owned: bool = army["owned"].has(selected)
	var tier: int = int(army["owned"][selected]["tier"]) if owned else int(u["tier"])
	var st: Dictionary = LaneUnits.stats(selected, tier)
	for c in _detail_card_holder.get_children():
		_detail_card_holder.remove_child(c)
		c.queue_free()
	var card := LaneTierCard.new(tier, DETAIL_CARD)
	card.name = "Card"
	_detail_card_holder.add_child(card)
	_art(card, selected, Vector2(DETAIL_CARD.x - 30, 200), 24, not owned)
	var tl := LaneUI.label(LaneUnits.TIER_NAME[tier], 22, LaneUnits.tier_color(tier).lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER)
	tl.position = Vector2(0, DETAIL_CARD.y - 56)
	tl.size = Vector2(DETAIL_CARD.x, 30)
	card.add_child(tl)
	info_name.text = u["name"] if owned else "%s (미보유)" % u["name"]
	info_name.add_theme_color_override("font_color", LaneUnits.tier_color(tier).lightened(0.45))
	var reach: String = "원거리" if u.has("shot") else "근거리"
	info_role.text = u["role"] if u["role"] == reach else "%s  ·  %s" % [u["role"], reach]
	info_stats.text = "체력  %d\n공격  %d\n사거리  %d\n금화 %d  ·  대기 %d초" % [roundi(st["hp"]), roundi(st["atk"]), int(u["range"]), u["cost"], int(u["cool"])]
	for c in _detail_bar.get_children():
		c.queue_free()
	_copies_bar(_detail_bar, Vector2.ZERO, _detail_bar.size, selected, army, 18)
	if not owned:
		info_copies.text = "뽑기로 얻을 수 있어요"
		info_next.text = ""
	elif tier >= LaneUnits.MAX_TIER:
		info_copies.text = "복제"
		info_next.text = "최고 성급(전설)이에요"
	else:
		info_copies.text = "복제 (합성까지)"
		info_next.text = "다음 성급: %s  ·  체력·공격 +%d%%" % [LaneUnits.TIER_NAME[tier + 1], roundi(LaneUnits.TIER_BONUS * 100.0)]
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
			note.text = "덱이 가득 찼어요. 위의 덱 칸을 눌러 한 명을 빼 주세요"
		else:
			LaneUnits.set_deck_slot(empty, selected)
			note.text = "덱에 넣었어요"
	SoundManager.play_click()
	refresh()
	detail.visible = false

# Merge: spend copies, go up a tier, then a burst on the card and a banner with the new tier
func _on_merge() -> void:
	var t: int = LaneUnits.merge(selected)
	if t < 0:
		note.text = "복제가 모자라요"
		return
	refresh()
	var card: LaneTierCard = _detail_card_holder.get_node_or_null("Card") if detail.visible else _cards.get(selected)
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
	banner.position = Vector2(0, 180)
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
