class_name LaneStageSelect
extends Control
# 블록 기사단 base — 전면 쇼케이스 (한 화면 = 한 스테이지, 좌우 쓸기로 다음/이전).
# 2026-10-09 재설계: 카드 그리드 버리고 쇼케이스 패턴으로 (사용자 요청).
#   row 1 (18~82)    gem bar + 홈으로
#   row 2 (92~156)   리본 "블록 기사단"
#   row 3 (170~204)  내 덱 전투력 / 현재 쇼케이스 스테이지 권장
#   row 4 (220~920)  풀 너비 쇼케이스 카드 (680x700): 스테이지 배경 + 보스 큰 아트 +
#                    이름/특기/별/권장/시작버튼. 좌우 쓸기 or ◀/▶로 이전/다음 스테이지.
#   row 5 (936~968)  "스테이지 N / 24 · ★ x / 72" 큰 라벨 (28px, outline).
#                    2026-10-10: 24개 점이 버튼과 겹친다는 피드백으로 제거 (SKILL 4b-6).
#   row 6 (984~1076) [병사 뽑기] [덱 편성]
#
# test_lane.gd 호환:
# - `rows`에 Stage1..Stage24 노드가 전부 있어야 함 (잠긴 건 disabled, 열린 건 Rec 자식 라벨 포함).
#   화면에는 안 보이지만 find_child로 접근 가능해야 함.

signal stage_selected(stage_id: int)
signal gacha_pressed
signal deck_pressed
signal closed

const SHOWCASE_POS: Vector2 = Vector2(20, 220)
const SHOWCASE_SIZE: Vector2 = Vector2(680, 700)
const SWIPE_THRESHOLD: float = 60.0   # 쓸기로 인정하는 최소 가로 이동
const DRAG_THRESHOLD: float = 10.0    # 드래그로 인식 시작

var rows: Control                       # 테스트가 Stage*/Rec를 찾는 숨은 컨테이너
var gem_bar: Panel
var power_label: Label

var _showcase: Control                  # 현재 보이는 큰 쇼케이스 패널 (교체됨)
var _showcase_slot: Control             # 쇼케이스가 들어가는 자리 (clip)
var _page_label: Label
var _prev_btn: Button
var _next_btn: Button
var _start_btn: Button

var _current: int = 1                   # 현재 쇼케이스 스테이지 id (1~24)
var _progress: Dictionary = {"unlocked": 1, "stars": {}}
var _animating: bool = false
var _drag_from_x: float = 0.0
var _drag_active: bool = false

const POWER_OK: Color = Color(0.62, 0.95, 0.55)
const POWER_LOW: Color = Color(1.0, 0.5, 0.42)
const CHAPTER_TINTS: Array[Color] = [
	Color(0.55, 0.78, 0.42),
	Color(0.26, 0.46, 0.28),
	Color(0.42, 0.36, 0.56),
	Color(0.55, 0.22, 0.24),
]
# 1~3장은 전용 배경 있음; 나머지는 챕터별로 재활용 (3·4장은 틴트로 분위기 바꿈)
const CHAPTER_ICON: Array[String] = ["slime", "goblin", "skeleton", "orc"]
const CHAPTER_BG: Array[String] = ["bg_grassland", "bg_goblin_camp", "bg_bat_cave", "bg_bat_cave"]
const CHAPTER_BG_TINT: Array[Color] = [
	Color(1.0, 1.0, 1.0, 1.0),
	Color(1.0, 1.0, 1.0, 1.0),
	Color(0.72, 0.74, 1.05, 1.0),   # 3장 묘지: 푸른빛
	Color(1.1, 0.72, 0.72, 1.0),    # 4장 마왕성: 붉은빛
]
# 배경 창 (쇼케이스 안 상단) 과 보스 배치
const BG_RECT: Rect2 = Rect2(14, 100, 652, 340)
const BOSS_SCALE: int = 4   # 정수배 스케일 — 원본 ~70px → 280px

func _ready() -> void:
	visible = false
	z_index = 150
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	LaneUI.backdrop(self)

	# Row 1: gem bar + 홈
	gem_bar = LaneUI.gem_bar(540)
	gem_bar.position = Vector2(20, 18)
	add_child(gem_bar)
	var back := Button.new()
	back.text = "홈으로"
	LaneUI.button(back, "grey", 22)
	back.position = Vector2(570, 18)
	back.size = Vector2(130, 64)
	back.pressed.connect(close)
	add_child(back)

	# Row 2: 리본
	var title := LaneUI.ribbon("블록 기사단", 440, 32)
	title.position = Vector2(140, 92)
	add_child(title)

	# Row 3: 전투력 안내
	power_label = LaneUI.label("", 24, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	power_label.position = Vector2(20, 170)
	power_label.size = Vector2(680, 34)
	add_child(power_label)

	# Row 4: 쇼케이스 자리 (clip + 이벤트 수신)
	_showcase_slot = Control.new()
	_showcase_slot.position = SHOWCASE_POS
	_showcase_slot.size = SHOWCASE_SIZE
	_showcase_slot.clip_contents = true
	_showcase_slot.mouse_filter = Control.MOUSE_FILTER_STOP
	_showcase_slot.gui_input.connect(_on_showcase_input)
	add_child(_showcase_slot)

	# Row 5: 페이지 라벨 "스테이지 N / 24 · ★ x / 72" — 24개 점은 폭이 24px 미만이라
	# cramped + 하단 버튼과 겹침 피드백 (2026-10-10). SKILL 4b-6: dot row 대신 label.
	# 쇼케이스 bottom=920, 라벨 top=936 → 16px 간격 (스택 룰).
	# 라벨 bottom=968, 다음 버튼 top=984 → 16px 간격.
	_page_label = LaneUI.label("", 28, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_page_label.position = Vector2(20, 936)
	_page_label.size = Vector2(680, 32)
	add_child(_page_label)

	# `rows`: 테스트가 Stage1..Stage24를 찾아보는 숨은 컨테이너.
	# 화면에는 안 그려지지만 노드는 모두 존재한다.
	rows = Control.new()
	rows.visible = false
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rows)

	# Row 6: 하단 2버튼
	var gacha := Button.new()
	gacha.text = "병사 뽑기"
	LaneUI.button(gacha, "red", 26)
	gacha.position = Vector2(20, 984)
	gacha.size = Vector2(334, 92)
	gacha.pressed.connect(func(): gacha_pressed.emit())
	add_child(gacha)
	var gi := LaneUI.icon("icon_gem", Vector2(30, 34))
	gi.position = Vector2(30, 28)
	gacha.add_child(gi)
	var deck := Button.new()
	deck.text = "덱 편성"
	LaneUI.button(deck, "blue", 26)
	deck.position = Vector2(366, 984)
	deck.size = Vector2(334, 92)
	deck.pressed.connect(func(): deck_pressed.emit())
	add_child(deck)

func open() -> void:
	SoundManager.play_click()
	refresh()
	visible = true
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)

func close() -> void:
	SoundManager.play_click()
	visible = false
	closed.emit()

func gem_bar_text() -> String:
	return gem_bar.get_node("Gems").text

func refresh() -> void:
	LaneUI.set_gem_bar(gem_bar)
	_progress = LaneStages.load_progress()
	# `rows` 재구성: 24개 Stage{N} 노드를 숨은 컨테이너에 담아둔다 (테스트용).
	for child in rows.get_children():
		child.queue_free()
	for s in LaneStages.STAGES:
		rows.add_child(_hidden_stage_stub(s))
	# 처음 열 때는 "마지막 깬 다음" 스테이지를 보여줌 (= 잠금 해제된 최신)
	_current = clampi(int(_progress["unlocked"]), 1, LaneStages.count())
	_render_showcase(_current, 0)   # 0 = cut, 애니메이션 없이

func _hidden_stage_stub(s: Dictionary) -> Control:
	# 테스트가 요구하는 최소 구조: TextureButton "Stage{id}" + locked면 disabled,
	# 열렸으면 "Rec" 라벨 자식 포함.
	var sid: int = s["id"]
	var locked: bool = sid > int(_progress["unlocked"])
	var btn := TextureButton.new()
	btn.name = "Stage%d" % sid
	btn.disabled = locked
	if not locked:
		var rec: int = LaneStages.recommended_power(sid)
		var rl := Label.new()
		rl.name = "Rec"
		rl.text = "권장 %d" % rec
		btn.add_child(rl)
	return btn

# --------- 쇼케이스 렌더링 ---------

func _render_showcase(stage_id: int, direction: int) -> void:
	# direction: -1 왼쪽에서 들어옴(이전으로 이동), +1 오른쪽에서 들어옴(다음으로 이동), 0 cut
	var card := _build_showcase_card(stage_id)
	_showcase_slot.add_child(card)
	# 이전 쇼케이스가 있으면 애니메이션으로 교체
	var old := _showcase
	_showcase = card
	if old != null and direction != 0:
		_animating = true
		card.position = Vector2(direction * SHOWCASE_SIZE.x, 0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(card, "position:x", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(old, "position:x", -direction * SHOWCASE_SIZE.x, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.chain().tween_callback(func():
			if is_instance_valid(old):
				old.queue_free()
			_animating = false
		)
	else:
		if old != null:
			old.queue_free()
		card.position = Vector2.ZERO

	# 전투력 안내 + 하단 인디케이터 갱신
	var power: int = LaneUnits.deck_power()
	var rec: int = LaneStages.recommended_power(stage_id)
	power_label.text = "내 덱 전투력 %d  ·  STAGE %d 권장 %d" % [power, stage_id, rec]
	power_label.add_theme_color_override("font_color", POWER_OK if power >= rec else POWER_LOW)
	_update_page_label(stage_id)

func _update_page_label(stage_id: int) -> void:
	_page_label.text = "스테이지 %d / %d  ·  ★ %d / %d" % [
		stage_id, LaneStages.count(), LaneStages.total_stars(), LaneStages.count() * 3]

func _build_showcase_card(stage_id: int) -> Control:
	var s: Dictionary = LaneStages.get_stage(stage_id)
	var locked: bool = stage_id > int(_progress["unlocked"])
	var stars: int = int(_progress["stars"].get(str(stage_id), 0))
	var power: int = LaneUnits.deck_power()
	var rec: int = LaneStages.recommended_power(stage_id)
	var chapter_idx: int = clampi((stage_id - 1) / LaneStages.PER_CHAPTER, 0, 3)
	var tint: Color = CHAPTER_TINTS[chapter_idx]

	var root := Panel.new()
	root.size = SHOWCASE_SIZE
	root.custom_minimum_size = SHOWCASE_SIZE
	LaneUI.dress(root, "panel_wood")

	# 배경 — 쇼케이스 상단에 큰 창으로 선명하게 (1~3은 전용, 4~24는 챕터 재활용 + 틴트)
	var bg_name: String = s.get("bg", "")
	var bg_tint: Color = Color(1, 1, 1, 1)
	if bg_name == "" or _load_tex("res://assets/art/lane/%s.png" % bg_name) == null:
		bg_name = CHAPTER_BG[chapter_idx]
		bg_tint = CHAPTER_BG_TINT[chapter_idx]
	var bg_tex: Texture2D = _load_tex("res://assets/art/lane/%s.png" % bg_name)
	if bg_tex != null:
		var bg := TextureRect.new()
		bg.texture = bg_tex
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.position = BG_RECT.position
		bg.size = BG_RECT.size
		bg.modulate = bg_tint
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bg)
	else:
		var tinted := Panel.new()
		tinted.position = BG_RECT.position
		tinted.size = BG_RECT.size
		tinted.add_theme_stylebox_override("panel", UIKit.box(tint.darkened(0.35), tint.darkened(0.1), 10, 2))
		tinted.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tinted)
	# 하단 그라데이션(어두워지는 띠) — 배경과 아래 UI 영역을 자연스럽게 연결
	var fade := Panel.new()
	fade.position = Vector2(BG_RECT.position.x, BG_RECT.position.y + BG_RECT.size.y - 40)
	fade.size = Vector2(BG_RECT.size.x, 40)
	fade.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.45), Color(0, 0, 0, 0), 0, 0))
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	# 상단 챕터·번호·이름
	var chap_name: String = LaneStages.CHAPTERS[chapter_idx]["name"]
	var head := LaneUI.label("%s  ·  STAGE %d" % [chap_name, stage_id], 22, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	head.position = Vector2(0, 24)
	head.size = Vector2(SHOWCASE_SIZE.x, 28)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(head)
	var nm := LaneUI.label(s.get("name", ""), 34, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	nm.position = Vector2(0, 56)
	nm.size = Vector2(SHOWCASE_SIZE.x, 44)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(nm)

	# 보스/대표 몹 아트: 보스 있으면 전용 tex, 없으면 챕터 쫄몹 크게
	var icon_kind: String = ""
	var boss_name: String = ""
	var boss_hint: String = ""
	var is_boss: bool = s.get("boss", "") != ""
	if is_boss:
		var bd: Dictionary = LaneStages.BOSSES[s["boss"]]
		boss_name = bd["name"]
		boss_hint = bd.get("hint", "")
		icon_kind = bd.get("tex", "")
		if icon_kind == "" or _load_tex("res://assets/art/lane/%s.png" % icon_kind) == null:
			icon_kind = bd["kind"]
	elif s.has("pool") and not s["pool"].is_empty():
		icon_kind = s["pool"][0]
	if icon_kind == "":
		icon_kind = CHAPTER_ICON[chapter_idx]
	var mon_tex: Texture2D = _load_tex("res://assets/art/lane/%s.png" % icon_kind)
	if mon_tex != null:
		# 정수배 스케일 — nearest에서 깔끔하게. 원본이 커서 BG 창을 넘기면 x3로 낮춤.
		var src: Vector2 = mon_tex.get_size()
		var scale_i: int = BOSS_SCALE
		var max_h: float = BG_RECT.size.y - 20.0   # 배경 창 안에서만
		var max_w: float = BG_RECT.size.x - 60.0
		while scale_i > 2 and (src.y * scale_i > max_h or src.x * scale_i > max_w):
			scale_i -= 1
		var draw_size: Vector2 = src * scale_i
		var mon := TextureRect.new()
		mon.texture = mon_tex
		mon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mon.stretch_mode = TextureRect.STRETCH_SCALE
		mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 배경 창 하단 중앙에 "지면에 선 듯" 배치 (하단에서 12px 띄움)
		mon.size = draw_size
		mon.position = Vector2(
			BG_RECT.position.x + (BG_RECT.size.x - draw_size.x) * 0.5,
			BG_RECT.position.y + BG_RECT.size.y - draw_size.y - 12.0,
		)
		if locked:
			mon.modulate = Color(0.4, 0.4, 0.4, 1.0)
		root.add_child(mon)

	# 이름 + 특기 (배경 창 아래로 시작)
	var y: float = BG_RECT.position.y + BG_RECT.size.y + 8.0  # 448
	if is_boss:
		var tag := LaneUI.label("☠ BOSS", 20, Color(1.0, 0.7, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		tag.position = Vector2(0, y)
		tag.size = Vector2(SHOWCASE_SIZE.x, 24)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(tag)
		y += 26.0
		var bn := LaneUI.label(boss_name, 32, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		bn.position = Vector2(0, y)
		bn.size = Vector2(SHOWCASE_SIZE.x, 40)
		bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bn)
		y += 42.0
		if boss_hint != "":
			var hl := LaneUI.label(boss_hint, 20, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			hl.position = Vector2(20, y)
			hl.size = Vector2(SHOWCASE_SIZE.x - 40, 26)
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(hl)
			y += 30.0
	else:
		var role_nm: String = LaneStages.ROLE_NAME.get(s.get("role", "test"), "")
		var sub := LaneUI.label(role_nm, 22, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		sub.position = Vector2(0, y)
		sub.size = Vector2(SHOWCASE_SIZE.x, 28)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(sub)
		y += 32.0
		var newtxt: String = s.get("new", "")
		if newtxt != "":
			var hl := LaneUI.label(newtxt, 20, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
			hl.position = Vector2(20, y)
			hl.size = Vector2(SHOWCASE_SIZE.x - 40, 26)
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(hl)
			y += 30.0

	# 별 + 권장
	y = 548.0
	var st := LaneUI.stars(stars, 28)
	st.position = Vector2(0, y)
	st.size = Vector2(SHOWCASE_SIZE.x, 32)
	root.add_child(st)
	y += 36.0
	var rec_col: Color = POWER_OK if power >= rec else POWER_LOW
	var rl := LaneUI.label("권장 전투력 %d" % rec, 22, rec_col, HORIZONTAL_ALIGNMENT_CENTER)
	rl.position = Vector2(0, y)
	rl.size = Vector2(SHOWCASE_SIZE.x, 26)
	rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(rl)

	# 하단 버튼들: ◀ 이전 · 시작! · 다음 ▶
	var btn_y: float = SHOWCASE_SIZE.y - 90.0
	_prev_btn = Button.new()
	_prev_btn.text = "◀"
	LaneUI.button(_prev_btn, "grey", 28)
	_prev_btn.position = Vector2(26, btn_y)
	_prev_btn.size = Vector2(90, 72)
	_prev_btn.disabled = stage_id <= 1
	_prev_btn.pressed.connect(func(): _go_to(_current - 1, true))
	root.add_child(_prev_btn)

	_start_btn = Button.new()
	_start_btn.position = Vector2(140, btn_y)
	_start_btn.size = Vector2(400, 72)
	if locked:
		_start_btn.text = "🔒 잠김"
		LaneUI.button(_start_btn, "grey", 28)
		_start_btn.disabled = true
	else:
		_start_btn.text = "시작!"
		LaneUI.button(_start_btn, "green", 32)
		var sid: int = stage_id
		_start_btn.pressed.connect(func(): stage_selected.emit(sid))
	root.add_child(_start_btn)

	_next_btn = Button.new()
	_next_btn.text = "▶"
	LaneUI.button(_next_btn, "grey", 28)
	_next_btn.position = Vector2(564, btn_y)
	_next_btn.size = Vector2(90, 72)
	_next_btn.disabled = stage_id >= LaneStages.count()
	_next_btn.pressed.connect(func(): _go_to(_current + 1, true))
	root.add_child(_next_btn)

	# 잠긴 경우: 큰 자물쇠 + 안내 (배경 창 위에 겹쳐)
	if locked:
		var lock := LaneUI.icon("icon_lock", Vector2(96, 112))
		lock.position = Vector2((SHOWCASE_SIZE.x - lock.size.x) * 0.5,
			BG_RECT.position.y + (BG_RECT.size.y - 112) * 0.5)
		lock.modulate = Color(2.4, 2.4, 2.4)
		root.add_child(lock)

	return root

# --------- 네비게이션 (쓸기 · 버튼 · 키보드) ---------

func _go_to(stage_id: int, animate: bool) -> void:
	var target: int = clampi(stage_id, 1, LaneStages.count())
	if target == _current or _animating:
		return
	var dir: int = 1 if target > _current else -1
	_current = target
	_render_showcase(_current, dir if animate else 0)

func _on_showcase_input(ev: InputEvent) -> void:
	if _animating:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_drag_from_x = ev.position.x
			_drag_active = false
		else:
			if _drag_active:
				var dx: float = ev.position.x - _drag_from_x
				if absf(dx) >= SWIPE_THRESHOLD:
					# 오른쪽으로 쓸면 이전으로, 왼쪽으로 쓸면 다음으로
					_go_to(_current + (-1 if dx > 0 else 1), true)
				_drag_active = false
				get_viewport().set_input_as_handled()
	elif ev is InputEventMouseMotion:
		if (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			if absf(ev.position.x - _drag_from_x) > DRAG_THRESHOLD:
				_drag_active = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible or _animating:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_LEFT:
			_go_to(_current - 1, true)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
			_go_to(_current + 1, true)
			get_viewport().set_input_as_handled()

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
