class_name HomeScreen
extends Control
# Full-screen home as a game lobby, in the 블록 기사단 pixel UI (LaneUI):
#   top     profile chip, gems, sound, settings
#   middle  the title ribbon, the next stage, and the deck's soldiers standing in front of the castle
#   right   other modes as wooden tiles: 블록 퍼즐 (the classic game, best score), 랭킹 (rank)
#   bottom  a tab bar: 병사 (soldiers & deck), 출전 (big medallion, the stage select), 뽑기 (gacha)
# main.gd fills it through refresh() and listens to the signals.

signal play_pressed
signal battle_pressed
signal gacha_pressed
signal deck_pressed
signal ranking_pressed
signal settings_pressed
signal profile_pressed
signal sound_pressed
signal lane_reset_pressed
signal battle_test_pressed       # 모드 1: 세로 전투 (풀스크린 lane_battle + 하단 소환 panel)
signal puzzle_test_pressed       # 모드 2: 블록 퍼즐만 (classic)
signal lane_test_pressed         # 모드 3: 블록 + 가로 전투 (stage 1 바로)

const W: float = 720.0
const GROUND: float = 820.0
const NAV_Y: float = 1100.0

# Test tools for the dev build (user requests 2026-10-08): the "+" on the gem count adds DEV_GEMS,
# and "리셋" on the left starts 블록 기사단 over. DEV_TOOLS = false hides both before dev goes to
# master for the stores
const DEV_TOOLS: bool = true
const DEV_GEMS: int = 1000

var sound_on_tex: Texture2D = preload("res://assets/sprites/sound_on.png")
var sound_off_tex: Texture2D = preload("res://assets/sprites/sound_off.png")

var avatar: TextureRect
var name_label: Label
var sub_label: Label
var sound_btn: Button
var settings_btn: Button
var top_chip: Button
var gem_label: Label
var gem_add: Button
var reset_btn: Button
var _reset_armed: bool = false
var gem_box: Panel
var battle_status: Label
var next_label: Label
var best_value: Label
var rank_value: Label
var rank_title: Label
var ranking_button: Button
var ranking_label: Label
var _squad: Node2D
var _clock: float = 0.0

func _ready() -> void:
	z_index = 150
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sky := ColorRect.new()
	sky.color = Color("#2b3b5c")
	sky.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	# The battlefield fills the lobby; the castle stands on the left with the squad in front
	var lane := TextureRect.new()
	lane.texture = load("res://assets/art/lane/lane.png")
	lane.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lane.stretch_mode = TextureRect.STRETCH_SCALE
	lane.size = Vector2(296, 148) * 6.0 # big enough that its sky reaches the top of the screen
	lane.position = Vector2((W - lane.size.x) * 0.5, GROUND + 40 - lane.size.y)
	lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lane)
	var ground := ColorRect.new()
	ground.color = Color("#3b5a2a")
	ground.position = Vector2(0, GROUND + 38)
	ground.size = Vector2(W, 1280 - GROUND)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	var castle := TextureRect.new()
	castle.texture = load("res://assets/art/lane/castle.png")
	castle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	castle.size = Vector2(74, 113) * 3.0
	castle.position = Vector2(-70, GROUND + 14 - castle.size.y)
	castle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(castle)
	_squad = Node2D.new()
	add_child(_squad)
	_build_top_bar()
	if DEV_TOOLS:
		_build_reset()
	_build_title()
	_build_nav()

# info: nickname, sub, avatar, best, rank, muted (other keys are ignored)
func refresh(info: Dictionary) -> void:
	avatar.texture = info.get("avatar")
	name_label.text = str(info.get("nickname", "플레이어"))
	sub_label.text = str(info.get("sub", "프로필 편집"))
	best_value.text = "최고 " + UIKit.format_number(int(info.get("best", 0)))
	var rank: int = int(info.get("rank", -1))
	rank_value.text = "전체 %d위" % rank if rank > 0 else "기록 없음"
	var lane: Dictionary = LaneStages.load_progress()
	var next: int = int(lane["unlocked"])
	battle_status.text = "STAGE %d / %d  ·  ★ %d" % [next, LaneStages.count(), LaneStages.total_stars()]
	var st: Dictionary = LaneStages.get_stage(next)
	next_label.text = "다음 전투  STAGE %d · %s" % [next, st.get("name", "")]
	gem_label.text = str(LaneUnits.load_army()["gems"])
	_build_squad()
	set_muted(bool(info.get("muted", false)))

func set_muted(muted: bool) -> void:
	sound_btn.icon = sound_off_tex if muted else sound_on_tex

func set_ranking_visible(on: bool, show_rank: bool = true) -> void:
	# show_rank: our own server knows the player's rank; Toss's leaderboard does not tell us
	ranking_button.visible = on
	rank_title.visible = on and show_rank
	rank_value.visible = on and show_rank

func clear_top_right() -> void:
	# Apps in Toss floats its "more" and X buttons over the top-right corner: keep ours out of it
	top_chip.size.x = 230
	name_label.size.x = 140
	sub_label.size.x = 140
	gem_box.position.x = 254
	sound_btn.position.x = 254 + 150 + 8
	settings_btn.position.x = 254 + 150 + 8 + 64 + 8

func flash_ranking_note(text: String) -> void:
	# Shows why the ranking could not open on the button itself for a moment
	ranking_label.text = text
	ranking_label.add_theme_font_size_override("font_size", 14)
	get_tree().create_timer(3.0).timeout.connect(func():
		ranking_label.text = "랭킹"
		ranking_label.add_theme_font_size_override("font_size", 20))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	# The squad breathes: a small idle bob, each soldier on its own beat
	for i in range(_squad.get_child_count()):
		var n = _squad.get_child(i)
		if n is Node2D and n.has_meta("base_y"):
			n.position.y = n.get_meta("base_y") - absf(sin(_clock * 2.2 + i * 0.9)) * 4.0

# ---------------------------------------------------------------------------

func _build_top_bar() -> void:
	var chip := Button.new()
	top_chip = chip
	_wood_button(chip)
	_place(chip, 14, 14, 300, 74)
	chip.pressed.connect(func(): profile_pressed.emit())
	add_child(chip)
	avatar = TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(avatar, 14, 11, 52, 52)
	chip.add_child(avatar)
	name_label = LaneUI.label("", 20, LaneUI.TEXT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(name_label, 76, 10, 210, 28)
	chip.add_child(name_label)
	sub_label = LaneUI.label("", 15, LaneUI.GOLD)
	sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(sub_label, 76, 38, 210, 24)
	chip.add_child(sub_label)

	gem_box = Panel.new()
	LaneUI.dress(gem_box, "panel_wood")
	gem_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(gem_box, 324, 14, 170, 74)
	add_child(gem_box)
	var gem := LaneUI.icon("icon_gem", Vector2(28, 32))
	gem.position = Vector2(18, 21)
	gem_box.add_child(gem)
	gem_label = LaneUI.label("0", 26, LaneUI.GOLD)
	_place(gem_label, 54, 16, 110, 40)
	gem_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gem_box.add_child(gem_label)
	# Test button (user request 2026-10-08): "+" tops up gems for trying the gacha. dev branch only;
	# take it out (DEV_GEMS = 0) before dev goes to master for the stores
	if DEV_TOOLS:
		_place(gem_label, 50, 16, 76, 40)
		gem_label.add_theme_font_size_override("font_size", 22)
		gem_add = Button.new()
		gem_add.text = "+"
		LaneUI.button(gem_add, "green", 24)
		# A small square: no padding, so the 9-slice stays at its size
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var sb: StyleBox = gem_add.get_theme_stylebox(st)
			sb.content_margin_left = 0
			sb.content_margin_right = 0
			sb.content_margin_top = 0
			sb.content_margin_bottom = 2
		_place(gem_add, 126, 19, 36, 36)
		gem_add.tooltip_text = "보석 +%d (테스트)" % DEV_GEMS
		gem_add.pressed.connect(_on_gem_add)
		gem_box.mouse_filter = Control.MOUSE_FILTER_PASS
		gem_box.add_child(gem_add)

	sound_btn = _icon_button(sound_on_tex)
	_place(sound_btn, 504, 14, 74, 74)
	sound_btn.pressed.connect(func(): sound_pressed.emit())
	add_child(sound_btn)
	settings_btn = _icon_button(preload("res://assets/sprites/settings_icon.png"))
	_place(settings_btn, 590, 14, 74, 74)
	settings_btn.pressed.connect(func(): settings_pressed.emit())
	add_child(settings_btn)

# Test reset on the left of the field (mirrors the mode tiles on the right): tap twice
func _build_reset() -> void:
	reset_btn = Button.new()
	reset_btn.text = "리셋"
	LaneUI.button(reset_btn, "red", 22)
	_place(reset_btn, 16, 300, 96, 56)
	reset_btn.tooltip_text = "블록 기사단 처음부터 (테스트)"
	reset_btn.pressed.connect(_on_reset)
	add_child(reset_btn)
	var cap := LaneUI.label("테스트", 15, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_place(cap, 16, 358, 96, 22)
	add_child(cap)
	# 테스트 모드 선택 (dev 전용, 2026-10-10): 3가지 플레이 방식을 바로 띄워 시험.
	#   1) 세로 전투 - 퍼즐 숨기고 풀스크린 전투 + 하단 소환 버튼
	#   2) 블록 퍼즐만 - classic 모드
	#   3) 블록 + 가로 전투 - stage 1 정규 흐름 (영웅 선택 생략, 저장된 선택 사용)
	var tcap := LaneUI.label("모드 테스트", 13, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_place(tcap, 16, 386, 96, 20)
	add_child(tcap)
	var t1 := Button.new()
	t1.text = "세로\n전투"
	LaneUI.button(t1, "blue", 14)
	_place(t1, 16, 408, 96, 56)
	t1.tooltip_text = "1. 세로 전투 (풀스크린 + 하단 소환)"
	t1.pressed.connect(func():
		SoundManager.play_click()
		battle_test_pressed.emit())
	add_child(t1)
	var t2 := Button.new()
	t2.text = "블록\n퍼즐"
	LaneUI.button(t2, "green", 14)
	_place(t2, 16, 468, 96, 56)
	t2.tooltip_text = "2. 블록 퍼즐만 (classic)"
	t2.pressed.connect(func():
		SoundManager.play_click()
		puzzle_test_pressed.emit())
	add_child(t2)
	var t3 := Button.new()
	t3.text = "블록+\n가로전투"
	LaneUI.button(t3, "red", 13)
	_place(t3, 16, 528, 96, 56)
	t3.tooltip_text = "3. 블록 + 가로 전투 (stage 1)"
	t3.pressed.connect(func():
		SoundManager.play_click()
		lane_test_pressed.emit())
	add_child(t3)

func _on_reset() -> void:
	SoundManager.play_click()
	if not _reset_armed:
		_reset_armed = true
		reset_btn.text = "한 번 더"
		get_tree().create_timer(3.0).timeout.connect(func():
			_reset_armed = false
			reset_btn.text = "리셋")
		return
	_reset_armed = false
	reset_btn.text = "리셋"
	lane_reset_pressed.emit()

func _on_gem_add() -> void:
	SoundManager.play_battle("g_new", -6.0)
	gem_label.text = str(LaneUnits.add_gems(DEV_GEMS))
	gem_label.pivot_offset = gem_label.size * 0.5
	gem_label.scale = Vector2(1.3, 1.3)
	gem_label.create_tween().tween_property(gem_label, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var pop := LaneUI.label("+%d" % DEV_GEMS, 24, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_place(pop, gem_box.position.x, gem_box.position.y + 70, gem_box.size.x, 30)
	add_child(pop)
	var tw := pop.create_tween().set_parallel(true)
	tw.tween_property(pop, "position:y", pop.position.y + 26, 0.6)
	tw.tween_property(pop, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tw.chain().tween_callback(pop.queue_free)

func _build_title() -> void:
	var rib := LaneUI.ribbon("블록 기사단", 520, 40)
	rib.size = Vector2(520, 76)
	rib.get_child(0).size = Vector2(520, 52)
	rib.position = Vector2(100, 112)
	add_child(rib)
	var pill := Panel.new()
	LaneUI.dress(pill, "panel_wood")
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(pill, 180, 196, 360, 52)
	add_child(pill)
	battle_status = LaneUI.label("", 20, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_place(battle_status, 0, 8, 360, 36)
	battle_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pill.add_child(battle_status)
	# The next stage on parchment, tap to go
	var next := Button.new()
	next.focus_mode = Control.FOCUS_NONE
	next.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		next.add_theme_stylebox_override(st, LaneUI.box("panel_paper", 10, Color(1, 1, 1) if st == "normal" else (Color(1.08, 1.08, 1.08) if st == "hover" else Color(0.9, 0.9, 0.9))))
	next.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_place(next, 60, 920, 600, 120)
	next.pressed.connect(func(): battle_pressed.emit())
	add_child(next)
	next_label = LaneUI.label("", 24, LaneUI.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_place(next_label, 0, 22, 600, 36)
	next.add_child(next_label)
	var hint := LaneUI.label("눌러서 스테이지 고르기", 17, Color(0.4, 0.28, 0.16), HORIZONTAL_ALIGNMENT_CENTER, false)
	_place(hint, 0, 64, 600, 28)
	next.add_child(hint)

# The deck's soldiers, x3, on the grass in front of the castle; tap one to open the soldiers screen
func _build_squad() -> void:
	for c in _squad.get_children():
		c.queue_free()
	var army: Dictionary = LaneUnits.load_army()
	var kinds: Array = army["deck"].filter(func(k): return k != "")
	var x0: float = 250.0
	var step: float = (W - 40.0 - x0) / maxf(1.0, kinds.size())
	for i in range(kinds.size()):
		var kind: String = kinds[i]
		var holder := Node2D.new()
		holder.position = Vector2(x0 + step * (i + 0.5), GROUND + (i % 2) * 18.0)
		holder.set_meta("base_y", holder.position.y)
		_squad.add_child(holder)
		# A soft shadow on the ground (tiers show on the cards, not here)
		var shadow := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.28)
		sb.set_corner_radius_all(40)
		shadow.add_theme_stylebox_override("panel", sb)
		shadow.position = Vector2(-40, -8)
		shadow.size = Vector2(80, 16)
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(shadow)
		var sp := Sprite2D.new()
		sp.texture = load("res://assets/art/lane/%s.png" % kind)
		sp.scale = Vector2(3, 3)
		sp.offset = Vector2(0, -sp.texture.get_height() * 0.5)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder.add_child(sp)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		tap.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_place(tap, x0 - 20, GROUND - 170, W - x0, 210)
	tap.pressed.connect(func(): deck_pressed.emit())
	_squad.add_child(tap)

# Bottom tab bar for the knights: 병사 · 출전 (a big medallion in the middle) · 뽑기. The block puzzle
# and the ranking are other modes, so they stand as icons on the right side of the scene instead
func _build_nav() -> void:
	var bar := Panel.new()
	LaneUI.dress(bar, "panel_wood")
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(bar, 0, NAV_Y, W, 1280 - NAV_Y)
	add_child(bar)
	_nav_tab("병사", "res://assets/art/lane/knight.png", 40.0, deck_pressed)
	_nav_tab("뽑기", "res://assets/art/ui/icon_gem.png", 520.0, gacha_pressed)
	# 출전: the bronze stage medallion, big, raised above the bar, with the fortress inside
	var go := TextureButton.new()
	go.texture_normal = LaneUI.tex("medal")
	go.ignore_texture_size = true
	go.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	go.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	go.focus_mode = Control.FOCUS_NONE
	_place(go, 270, NAV_Y - 56, 180, 184)
	go.pressed.connect(func(): battle_pressed.emit())
	add_child(go)
	var fort := TextureRect.new()
	fort.texture = load("res://assets/art/lane/fortress.png")
	fort.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fort.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fort.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(fort, 46, 30, 88, 106)
	go.add_child(fort)
	var gl := LaneUI.label("출전", 32, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_place(gl, 270, NAV_Y + 126, 180, 44)
	add_child(gl)
	go.pivot_offset = go.size * 0.5
	var tw := go.create_tween().set_loops()
	tw.tween_property(go, "scale", Vector2(1.05, 1.05), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(go, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	go.button_down.connect(func(): go.modulate = Color(0.85, 0.85, 0.85))
	go.button_up.connect(func(): go.modulate = Color.WHITE)
	# Other modes on the right of the scene
	var puzzle := _mode_button("블록 퍼즐", "res://assets/sprites/block_cyan.png", 300.0, play_pressed)
	best_value = puzzle["sub"]
	var rank := _mode_button("랭킹", "res://assets/sprites/crown_icon.png", 456.0, ranking_pressed)
	ranking_button = rank["button"]
	ranking_label = rank["label"]
	rank_value = rank["sub"]
	rank_title = LaneUI.label("", 12, LaneUI.TEXT)
	rank_title.visible = false
	ranking_button.add_child(rank_title)

# A tab on the bar: icon and word, no button art
func _nav_tab(text: String, art_path: String, x: float, sig: Signal) -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "pressed", "hover_pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 0.9, 0.6, 0.1)
	hover.set_corner_radius_all(12)
	b.add_theme_stylebox_override("hover", hover)
	_place(b, x, NAV_Y + 22, 160, 150)
	b.pivot_offset = b.size * 0.5
	b.pressed.connect(func(): sig.emit())
	b.button_down.connect(func(): b.scale = Vector2(0.92, 0.92))
	b.button_up.connect(func(): b.scale = Vector2.ONE)
	add_child(b)
	var art := TextureRect.new()
	art.texture = load(art_path)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(art, 44, 14, 72, 70)
	b.add_child(art)
	var l := LaneUI.label(text, 24, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_place(l, 0, 90, 160, 34)
	b.add_child(l)

# A side mode button: a small wooden tile with the icon, the name under it and one line of info
func _mode_button(text: String, art_path: String, y: float, sig: Signal) -> Dictionary:
	var b := Button.new()
	_wood_button(b)
	_place(b, W - 112, y, 96, 96)
	b.pivot_offset = b.size * 0.5
	b.pressed.connect(func(): sig.emit())
	b.button_down.connect(func(): b.scale = Vector2(0.92, 0.92))
	b.button_up.connect(func(): b.scale = Vector2.ONE)
	add_child(b)
	var art := TextureRect.new()
	art.texture = load(art_path)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(art, 22, 20, 52, 52)
	b.add_child(art)
	var l := LaneUI.label(text, 18, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_place(l, -30, 96, 156, 26)
	b.add_child(l)
	var sub := LaneUI.label("", 14, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_place(sub, -30, 120, 156, 22)
	b.add_child(sub)
	return {"button": b, "label": l, "sub": sub}

func _wood_button(b: Button) -> void:
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.add_theme_stylebox_override("normal", LaneUI.box("panel_wood", 10))
	b.add_theme_stylebox_override("hover", LaneUI.box("panel_wood", 10, Color(1.12, 1.12, 1.12)))
	b.add_theme_stylebox_override("pressed", LaneUI.box("panel_wood", 10, Color(0.85, 0.85, 0.85)))
	b.add_theme_stylebox_override("hover_pressed", LaneUI.box("panel_wood", 10, Color(0.85, 0.85, 0.85)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _icon_button(tex: Texture2D) -> Button:
	var b := Button.new()
	_wood_button(b)
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 34)
	return b

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
