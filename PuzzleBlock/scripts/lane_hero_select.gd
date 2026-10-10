class_name LaneHeroSelect
extends Control
# 영웅 선택 화면 (2026-10-10 docs/HERO_SYSTEM_PLAN.md).
# 흐름: 쇼케이스에서 [시작] → 이 화면 → 영웅 선택 → [출전!] → 전투.
# 가로 4장 카드 (삼장·손오공·저팔계·사오정), 잠긴 영웅은 흐림 + 자물쇠.
# 선택하면 중앙에 큰 초상 + 이름·역할·HP/공격/스킬 설명. [출전!] 눌러 전투 시작.

signal hero_chosen(stage_id: int, hero_id: String)
signal closed

const PAD: int = 16
const CARD_W: int = 158
const CARD_H: int = 198
const CARD_GAP: int = 14

var _stage_id: int = 0
var _selected: String = "sanzang"
var _cards: Dictionary = {}        # hero_id -> card panel
var _portrait: TextureRect
var _name_label: Label
var _role_label: Label
var _stats_label: Label
var _skill_label: Label
var _confirm_btn: Button

func _ready() -> void:
	visible = false
	z_index = 160
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	LaneUI.backdrop(self)
	_build()

func _build() -> void:
	# 상단 제목
	var title := LaneUI.ribbon("영웅 선택", 440, 32)
	title.position = Vector2(140, 60)
	add_child(title)

	# 카드 4장 가로 (y=140)
	var total_w: int = CARD_W * 4 + CARD_GAP * 3
	var start_x: int = (720 - total_w) / 2
	var ids: Array = LaneUnits.HERO_IDS
	for i in range(ids.size()):
		var id: String = ids[i]
		var card := _make_card(id)
		card.position = Vector2(start_x + i * (CARD_W + CARD_GAP), 140)
		add_child(card)
		_cards[id] = card

	# 중앙 큰 초상 + 상세
	var detail := Panel.new()
	LaneUI.dress(detail, "panel_wood")
	detail.position = Vector2(PAD, 360)
	detail.size = Vector2(720 - PAD * 2, 580)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail)

	_portrait = TextureRect.new()
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.position = Vector2(40, 30)
	_portrait.size = Vector2(240, 300)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(_portrait)

	_name_label = LaneUI.label("", 36, LaneUI.GOLD)
	_name_label.position = Vector2(300, 30)
	_name_label.size = Vector2(360, 44)
	detail.add_child(_name_label)

	_role_label = LaneUI.label("", 22, LaneUI.TEXT)
	_role_label.position = Vector2(300, 80)
	_role_label.size = Vector2(360, 28)
	detail.add_child(_role_label)

	_stats_label = LaneUI.label("", 20, LaneUI.TEXT)
	_stats_label.position = Vector2(300, 120)
	_stats_label.size = Vector2(360, 28)
	detail.add_child(_stats_label)

	var skill_header := LaneUI.label("액티브 스킬", 20, Color(0.75, 0.68, 0.55))
	skill_header.position = Vector2(300, 170)
	skill_header.size = Vector2(360, 24)
	detail.add_child(skill_header)
	_skill_label = LaneUI.label("", 20, LaneUI.TEXT)
	_skill_label.position = Vector2(300, 198)
	_skill_label.size = Vector2(360, 120)
	_skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(_skill_label)

	# 출전 버튼 + 뒤로
	_confirm_btn = Button.new()
	_confirm_btn.text = "출전!"
	LaneUI.button(_confirm_btn, "green", 30)
	_confirm_btn.position = Vector2(40, 460)
	_confirm_btn.size = Vector2(500, 92)
	_confirm_btn.pressed.connect(func(): hero_chosen.emit(_stage_id, _selected))
	detail.add_child(_confirm_btn)

	var back_btn := Button.new()
	back_btn.text = "뒤로"
	LaneUI.button(back_btn, "grey", 22)
	back_btn.position = Vector2(556, 460)
	back_btn.size = Vector2(124, 92)
	back_btn.pressed.connect(close)
	detail.add_child(back_btn)

func _make_card(id: String) -> Panel:
	var info: Dictionary = LaneUnits.HEROES[id]
	var card := Panel.new()
	LaneUI.dress(card, "panel_paper")
	card.size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			var unlocked: bool = LaneUnits.is_hero_unlocked(id)
			if unlocked:
				_select(id))
	var tex_path: String = "res://assets/art/lane/%s.png" % info.get("tex", "")
	if ResourceLoader.exists(tex_path):
		var pic := TextureRect.new()
		pic.texture = load(tex_path)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.position = Vector2(16, 16)
		pic.size = Vector2(CARD_W - 32, 112)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(pic)
	var nm := LaneUI.label(info.get("name", ""), 22, LaneUI.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	nm.position = Vector2(0, 128)
	nm.size = Vector2(CARD_W, 26)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(nm)
	var role := LaneUI.label(info.get("role", ""), 16, Color(0.75, 0.68, 0.55), HORIZONTAL_ALIGNMENT_CENTER, false)
	role.position = Vector2(0, 156)
	role.size = Vector2(CARD_W, 22)
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(role)
	# 잠금 자물쇠 (잠긴 영웅)
	if not LaneUnits.is_hero_unlocked(id):
		card.modulate = Color(0.5, 0.5, 0.56, 1.0)
		var lock := LaneUI.icon("icon_lock", Vector2(48, 56))
		lock.position = Vector2((CARD_W - 48) * 0.5, 42)
		lock.modulate = Color(2.0, 2.0, 2.0)
		card.add_child(lock)
	return card

func _select(id: String) -> void:
	if not LaneUnits.HEROES.has(id) or not LaneUnits.is_hero_unlocked(id):
		return
	_selected = id
	# 카드 하이라이트
	for h in _cards:
		var c: Panel = _cards[h]
		var picked: bool = h == id
		var unlocked: bool = LaneUnits.is_hero_unlocked(h)
		if unlocked:
			c.modulate = Color(1.3, 1.2, 0.9) if picked else Color.WHITE
	# 상세 패널 갱신
	var info: Dictionary = LaneUnits.HEROES[id]
	var tex_path: String = "res://assets/art/lane/%s.png" % info.get("tex", "")
	if ResourceLoader.exists(tex_path):
		_portrait.texture = load(tex_path)
	_name_label.text = info.get("name", "")
	_role_label.text = "역할: " + info.get("role", "")
	var h = LaneBattle.HEROES[id]
	_stats_label.text = "HP %d  ·  공격 %d  ·  쿨 %ds" % [roundi(h["hp"]), roundi(h["atk"]), roundi(h["cool"])]
	_skill_label.text = "%s\n%s" % [info.get("skill", ""), info.get("desc", "")]
	# 선택 상태 저장
	LaneUnits.select_hero(id)

func open(stage_id: int) -> void:
	SoundManager.play_click()
	_stage_id = stage_id
	# 카드 다시 그리기 (잠금 상태가 바뀌었을 수 있음)
	for id in _cards:
		var old: Panel = _cards[id]
		var parent := old.get_parent()
		var pos := old.position
		old.queue_free()
		var card := _make_card(id)
		card.position = pos
		parent.add_child(card)
		_cards[id] = card
	_selected = LaneUnits.selected_hero()
	_select(_selected)
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.2)

func close() -> void:
	SoundManager.play_click()
	visible = false
	closed.emit()
