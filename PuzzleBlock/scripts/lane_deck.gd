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
var _unit_buttons: Dictionary = {}    # kind -> Button in the collection grid

# Sort / filter state (session-only, 2026-10-09)
const SORT_LABELS: Array[String] = ["합성 가능 ↑", "등급 ↓", "수집순", "이름순"]
var sort_mode: int = 0
var filter_roles: Dictionary = {}     # role name -> true (empty = no filter)
var sort_btn: Button
var filter_chips: HBoxContainer
var _last_power: int = -1

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
var bulk_btn: Button
var shard_btn: Button
var prev_btn: Button
var next_btn: Button

# Long-press drag from the collection to a deck slot (2026-10-09)
const LONG_PRESS: float = 0.4
var _press_kind: String = ""
var _press_time: float = 0.0
var _press_at: Vector2 = Vector2.ZERO
var _drag_ghost: Control = null

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
	count_label.size = Vector2(240, 30)
	unit_board.add_child(count_label)
	sort_btn = Button.new()
	LaneUI.button(sort_btn, "blue", 16)
	sort_btn.position = Vector2(430, 10)
	sort_btn.size = Vector2(224, 34)
	sort_btn.pressed.connect(_cycle_sort)
	unit_board.add_child(sort_btn)
	# Role filter chips: 전체 / 근접 / 원거리 / 마법 / 힐 / 공중 / 탱커
	filter_chips = HBoxContainer.new()
	filter_chips.add_theme_constant_override("separation", 6)
	filter_chips.position = Vector2(14, 50)
	filter_chips.size = Vector2(652, 30)
	unit_board.add_child(filter_chips)
	for role in ["전체", "근접", "원거리", "마법", "힐", "공중", "탱커"]:
		var chip := Button.new()
		LaneUI.button(chip, "grey", 15)
		chip.text = role
		chip.custom_minimum_size = Vector2(84, 30)
		chip.pressed.connect(_toggle_filter.bind(role))
		filter_chips.add_child(chip)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.position = Vector2((680 - (CARD_SIZE.x * 4 + 30)) * 0.5, 90)
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

# Called when the gacha "합성하러 가기" opens straight to a specific soldier
func open_with(kind: String) -> void:
	if kind != "" and LaneUnits.UNITS.has(kind):
		selected = kind
	open()
	if kind != "" and LaneUnits.load_army()["owned"].has(kind):
		_show_info(LaneUnits.load_army())
		_open_detail()

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
	_update_power(LaneUnits.deck_power(army))
	count_label.text = "보유 %d / %d  💎 %d" % [army["owned"].size(), LaneUnits.ORDER.size(), int(army.get("universal_shards", 0))]
	for c in slots_box.get_children():
		c.queue_free()
	for c in grid.get_children():
		c.queue_free()
	_cards.clear()
	_unit_buttons.clear()
	for i in range(LaneUnits.DECK_SIZE):
		slots_box.add_child(_slot(i, army["deck"][i], army))
	for k in _sorted_filtered_kinds(army):
		grid.add_child(_unit_card(k, army))
	_update_filter_chip_look()
	sort_btn.text = "정렬: " + SORT_LABELS[sort_mode]
	_show_info(army)

func _sorted_filtered_kinds(army: Dictionary) -> Array:
	var kinds: Array = LaneUnits.ORDER.duplicate()
	if not filter_roles.is_empty():
		kinds = kinds.filter(func(k):
			var role: String = LaneUnits.UNITS[k]["role"]
			var reach: String = "원거리" if LaneUnits.UNITS[k].has("shot") else "근거리"
			var is_air: bool = bool(LaneUnits.UNITS[k].get("flying", false))
			var is_heal: bool = LaneUnits.UNITS[k].has("heal")
			for want in filter_roles.keys():
				match want:
					"근접": if reach == "근거리": return true
					"원거리": if reach == "원거리": return true
					"마법": if role.contains("마법") or LaneUnits.UNITS[k].get("shot", "") in ["orb", "ice"]: return true
					"힐": if is_heal: return true
					"공중": if is_air: return true
					"탱커": if role == "탱커" or role == "수호": return true
			return false)
	match sort_mode:
		0: # 합성 가능 ↑ then by tier desc
			kinds.sort_custom(func(a, b):
				var ca: bool = LaneUnits.can_merge(a, army)
				var cb: bool = LaneUnits.can_merge(b, army)
				if ca != cb:
					return ca
				return _tier_or_base(a, army) > _tier_or_base(b, army))
		1: # 등급 ↓
			kinds.sort_custom(func(a, b): return _tier_or_base(a, army) > _tier_or_base(b, army))
		2: # 수집순 (ORDER as-is)
			pass
		3: # 이름순 (Korean)
			kinds.sort_custom(func(a, b): return LaneUnits.UNITS[a]["name"] < LaneUnits.UNITS[b]["name"])
	return kinds

func _tier_or_base(k: String, army: Dictionary) -> int:
	if army["owned"].has(k):
		return int(army["owned"][k]["tier"])
	return int(LaneUnits.UNITS[k]["tier"])

func _cycle_sort() -> void:
	SoundManager.play_click()
	sort_mode = (sort_mode + 1) % SORT_LABELS.size()
	refresh()

func _toggle_filter(role: String) -> void:
	SoundManager.play_click()
	if role == "전체":
		filter_roles.clear()
	elif filter_roles.has(role):
		filter_roles.erase(role)
	else:
		filter_roles[role] = true
	refresh()

func _update_filter_chip_look() -> void:
	for c in filter_chips.get_children():
		if c is Button:
			var role: String = (c as Button).text
			var on: bool = (role == "전체" and filter_roles.is_empty()) or filter_roles.has(role)
			# Rewrap the chip's stylebox: green when on, grey when off
			LaneUI.button(c, "green" if on else "grey", 15)

# Live power rolling + flash (초록 올라감, 빨강 내려감)
func _update_power(now: int, animate: bool = true) -> void:
	if not animate or _last_power < 0:
		power_label.text = "전투력 %d" % now
		power_label.add_theme_color_override("font_color", LaneUI.TEXT)
		_last_power = now
		return
	if now == _last_power:
		power_label.text = "전투력 %d" % now
		return
	var from: int = _last_power
	var col: Color = Color(0.6, 1.0, 0.6) if now > from else Color(1.0, 0.65, 0.65)
	power_label.add_theme_color_override("font_color", col)
	var tw := create_tween()
	tw.tween_method(func(v): power_label.text = "전투력 %d" % int(v), float(from), float(now), 0.35)
	tw.tween_callback(func(): power_label.add_theme_color_override("font_color", LaneUI.TEXT))
	_last_power = now

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
	var flash: bool = false
	if army["owned"].has(kind):
		var o: Dictionary = army["owned"][kind]
		var need: int = LaneUnits.merge_need(int(o["tier"]))
		if need <= 0:
			text = "MAX"
			ratio = 1.0
			col = LaneUI.GOLD
		else:
			ratio = clampf(float(o["copies"]) / need, 0.0, 1.0)
			if o["copies"] >= need:
				text = "합성!"
				col = LaneUI.GOLD
			else:
				text = "%d / %d" % [o["copies"], need]
				if ratio >= 0.8:
					col = Color(1.0, 0.86, 0.32)
					flash = true
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
	if flash:
		var tw := l.create_tween().set_loops()
		tw.tween_property(l, "modulate:a", 0.4, 0.4)
		tw.tween_property(l, "modulate:a", 1.0, 0.4)
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
	_unit_buttons[kind] = b
	var card: Control = b.get_node("Card")
	_cards[kind] = card
	_art(card, kind, Vector2(CARD_SIZE.x - 20, 92), 6, not owned)
	var n := LaneUI.label(u["name"] if owned else "?", 16, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	n.position = Vector2(0, 98)
	n.size = Vector2(CARD_SIZE.x, 22)
	card.add_child(n)
	_copies_bar(card, Vector2(10, 120), Vector2(CARD_SIZE.x - 20, 22), kind, army, 18)
	if owned and army["deck"].has(kind):
		var d := LaneUI.label("덱", 15, Color(0.6, 1.0, 0.6))
		d.position = Vector2(30, 6)
		d.size = Vector2(30, 20)
		card.add_child(d)
	if owned and card is LaneTierCard:
		(card as LaneTierCard).set_mergeable(LaneUnits.has_copies(kind, army))
	b.pressed.connect(func():
		selected = kind
		note.text = ""
		SoundManager.play_click()
		_show_info(LaneUnits.load_army())
		_open_detail())
	# Long-press drag to a deck slot (owned soldiers only)
	if owned:
		b.gui_input.connect(_on_unit_press.bind(kind, b))
	return b

func _on_unit_press(ev: InputEvent, kind: String, src: Control) -> void:
	if ev is InputEventMouseButton or ev is InputEventScreenTouch:
		if ev.pressed:
			_press_kind = kind
			_press_time = _now()
			_press_at = ev.position
		else:
			if _drag_ghost != null:
				_finish_drag(ev.global_position if ev is InputEventMouseButton else (src.get_global_transform() * ev.position))
			_press_kind = ""
			_press_time = 0.0
	elif ev is InputEventMouseMotion or ev is InputEventScreenDrag:
		if _press_kind == kind and _drag_ghost == null:
			if (_now() - _press_time) >= LONG_PRESS and (ev.position - _press_at).length() < 24.0:
				_start_drag(kind, src)
			elif (ev.position - _press_at).length() > 32.0:
				_press_kind = "" # user is scrolling, not dragging
		if _drag_ghost != null:
			_drag_ghost.position = get_global_mouse_position() - _drag_ghost.size * 0.5

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func _start_drag(kind: String, _src: Control) -> void:
	SoundManager.play_click()
	var army := LaneUnits.load_army()
	var tier: int = int(army["owned"][kind]["tier"])
	_drag_ghost = Control.new()
	_drag_ghost.size = SLOT_SIZE
	_drag_ghost.modulate.a = 0.9
	_drag_ghost.top_level = true
	_drag_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_ghost.z_index = 200
	var tcard := LaneTierCard.new(tier, SLOT_SIZE)
	_drag_ghost.add_child(tcard)
	_art(tcard, kind, Vector2(SLOT_SIZE.x - 20, 90), 12, false)
	add_child(_drag_ghost)
	_drag_ghost.position = get_global_mouse_position() - _drag_ghost.size * 0.5

func _finish_drag(at: Vector2) -> void:
	if _drag_ghost == null:
		return
	_drag_ghost.queue_free()
	_drag_ghost = null
	# Find which deck slot the drop landed on
	for i in range(slots_box.get_child_count()):
		var slot: Control = slots_box.get_child(i)
		var r: Rect2 = slot.get_global_rect()
		if r.has_point(at):
			_do_place_in_slot(_press_kind, i)
			return

func _do_place_in_slot(kind: String, i: int) -> void:
	var army := LaneUnits.load_army()
	if not army["owned"].has(kind):
		return
	var existing_at: int = army["deck"].find(kind)
	# Replace: slot gets the new kind. If kind was elsewhere, that slot becomes empty.
	if existing_at >= 0 and existing_at != i:
		LaneUnits.set_deck_slot(existing_at, "")
	LaneUnits.set_deck_slot(i, kind)
	note.text = "덱 %d칸에 %s 넣음" % [i + 1, LaneUnits.UNITS[kind]["name"]]
	SoundManager.play_click()
	refresh()

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
	LaneUI.button(action_btn, "blue", 18)
	action_btn.position = Vector2(24, 548)
	action_btn.size = Vector2(300, 64)
	action_btn.pressed.connect(_on_action)
	board.add_child(action_btn)
	merge_btn = Button.new()
	LaneUI.button(merge_btn, "red", 18)
	merge_btn.position = Vector2(336, 548)
	merge_btn.size = Vector2(300, 64)
	merge_btn.pressed.connect(_on_merge)
	board.add_child(merge_btn)
	bulk_btn = Button.new()
	LaneUI.button(bulk_btn, "red", 16)
	bulk_btn.position = Vector2(24, 620)
	bulk_btn.size = Vector2(300, 54)
	bulk_btn.pressed.connect(_on_bulk_merge)
	board.add_child(bulk_btn)
	shard_btn = Button.new()
	LaneUI.button(shard_btn, "blue", 16)
	shard_btn.position = Vector2(336, 620)
	shard_btn.size = Vector2(300, 54)
	shard_btn.pressed.connect(_on_shard)
	board.add_child(shard_btn)
	# Prev / next arrows (쿠키런식)
	prev_btn = Button.new()
	LaneUI.button(prev_btn, "grey", 22)
	prev_btn.text = "◀"
	prev_btn.position = Vector2(24, 684)
	prev_btn.size = Vector2(80, 56)
	prev_btn.pressed.connect(_on_prev)
	board.add_child(prev_btn)
	next_btn = Button.new()
	LaneUI.button(next_btn, "grey", 22)
	next_btn.text = "▶"
	next_btn.position = Vector2(556, 684)
	next_btn.size = Vector2(80, 56)
	next_btn.pressed.connect(_on_next)
	board.add_child(next_btn)
	var shut := Button.new()
	shut.text = "닫기"
	LaneUI.button(shut, "grey", 20)
	shut.position = Vector2(130, 684)
	shut.size = Vector2(400, 56)
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
		var next_st: Dictionary = LaneUnits.stats(selected, tier + 1)
		info_next.text = "다음: %s  ·  HP %d → %d  ·  ATK %d → %d" % [LaneUnits.TIER_NAME[tier + 1], roundi(st["hp"]), roundi(next_st["hp"]), roundi(st["atk"]), roundi(next_st["atk"])]
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
	if owned and tier < LaneUnits.MAX_TIER:
		var g_need: int = LaneUnits.merge_gems(tier)
		var c_need: int = LaneUnits.merge_need(tier)
		merge_btn.text = "합성 · 성급 +1\n복제 %d · 💎 %d" % [c_need, g_need]
		merge_btn.disabled = not LaneUnits.can_merge(selected, army)
	else:
		merge_btn.text = "최고 성급" if owned else "합성"
		merge_btn.disabled = true
	# 최대까지 합성: estimate how many steps are possible with current copies + gems
	var chain: int = _max_chain(selected, army) if owned else 0
	if owned and chain >= 2:
		bulk_btn.visible = true
		bulk_btn.disabled = false
		bulk_btn.text = "최대까지 합성 ×%d" % chain
	else:
		bulk_btn.visible = false
	var shards: int = int(army.get("universal_shards", 0))
	if owned and tier < LaneUnits.MAX_TIER and shards > 0:
		shard_btn.visible = true
		shard_btn.disabled = false
		shard_btn.text = "💎 파편 1개로 복제 +1\n(보유 %d)" % shards
	else:
		shard_btn.visible = false

func _max_chain(kind: String, army_in: Dictionary) -> int:
	var army: Dictionary = army_in.duplicate(true)
	var count: int = 0
	while LaneUnits.can_merge(kind, army):
		var t: int = int(army["owned"][kind]["tier"])
		army["gems"] = int(army["gems"]) - LaneUnits.merge_gems(t)
		army["owned"][kind]["copies"] = int(army["owned"][kind]["copies"]) - LaneUnits.merge_need(t)
		army["owned"][kind]["tier"] = t + 1
		count += 1
	return count

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

func _on_prev() -> void:
	_cycle_detail(-1)

func _on_next() -> void:
	_cycle_detail(1)

func _cycle_detail(delta: int) -> void:
	SoundManager.play_click()
	var army := LaneUnits.load_army()
	var kinds: Array = _sorted_filtered_kinds(army)
	if kinds.is_empty():
		return
	var at: int = kinds.find(selected)
	if at < 0:
		at = 0
	else:
		at = posmod(at + delta, kinds.size())
	selected = kinds[at]
	_show_info(army)

func _on_bulk_merge() -> void:
	SoundManager.play_click()
	var army := LaneUnits.load_army()
	var steps: int = _max_chain(selected, army)
	if steps <= 0:
		return
	SoundManager.play_battle("g_fuse_chain", -5.0)
	var last_t: int = -1
	for s in range(steps):
		var t: int = LaneUnits.merge(selected)
		if t < 0:
			break
		last_t = t
	refresh()
	_show_info(LaneUnits.load_army())
	if last_t >= 0:
		_merge_banner(last_t)
	note.text = "최대까지 합성 ×%d" % steps

func _on_shard() -> void:
	if LaneUnits.spend_shard(selected):
		SoundManager.play_battle("g_shard", -5.0)
		refresh()
		_show_info(LaneUnits.load_army())
		note.text = "💎 파편 1개를 복제 1개로 바꿨어요"

func _merge_banner(t: int) -> void:
	var col: Color = LaneUnits.tier_color(t)
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

# Merge: spend copies, go up a tier, then a burst on the card and a banner with the new tier
func _on_merge() -> void:
	var t: int = LaneUnits.merge(selected)
	if t < 0:
		note.text = "복제·보석이 모자라요"
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
