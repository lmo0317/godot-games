class_name HomeScreen
extends Control
# Full-screen home as a game lobby, in the 블록 기사단 pixel UI (LaneUI):
#   top     profile chip, gems, sound, settings
#   middle  the title ribbon, the next stage, and the deck's soldiers standing in front of the castle
#   bottom  a tab bar: 병사 (soldiers & deck), 뽑기 (gacha), 출전 (big, the stage select),
#           블록 퍼즐 (the classic game, with its best score), 랭킹 (with the player's rank)
# main.gd fills it through refresh() and listens to the signals.

signal play_pressed
signal battle_pressed
signal gacha_pressed
signal deck_pressed
signal ranking_pressed
signal settings_pressed
signal profile_pressed
signal sound_pressed

const W: float = 720.0
const GROUND: float = 820.0
const NAV_Y: float = 1100.0

var sound_on_tex: Texture2D = preload("res://assets/sprites/sound_on.png")
var sound_off_tex: Texture2D = preload("res://assets/sprites/sound_off.png")

var avatar: TextureRect
var name_label: Label
var sub_label: Label
var sound_btn: Button
var settings_btn: Button
var top_chip: Button
var gem_label: Label
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

	sound_btn = _icon_button(sound_on_tex)
	_place(sound_btn, 504, 14, 74, 74)
	sound_btn.pressed.connect(func(): sound_pressed.emit())
	add_child(sound_btn)
	settings_btn = _icon_button(preload("res://assets/sprites/settings_icon.png"))
	_place(settings_btn, 590, 14, 74, 74)
	settings_btn.pressed.connect(func(): settings_pressed.emit())
	add_child(settings_btn)

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
		var tier: int = int(army["owned"][kind]["tier"])
		var holder := Node2D.new()
		holder.position = Vector2(x0 + step * (i + 0.5), GROUND + (i % 2) * 18.0)
		holder.set_meta("base_y", holder.position.y)
		_squad.add_child(holder)
		# A glow on the ground in the soldier's tier colour
		var glow := Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(LaneUnits.tier_color(tier), 0.45)
		sb.set_corner_radius_all(40)
		glow.add_theme_stylebox_override("panel", sb)
		glow.position = Vector2(-52, -10)
		glow.size = Vector2(104, 22)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(glow)
		var sp := Sprite2D.new()
		sp.texture = load("res://assets/art/lane/%s.png" % kind)
		sp.scale = Vector2(3, 3)
		sp.offset = Vector2(0, -sp.texture.get_height() * 0.5)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		holder.add_child(sp)
		var tag := LaneUI.label(LaneUnits.TIER_NAME[tier], 15, LaneUnits.tier_color(tier).lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER)
		tag.position = Vector2(-60, 14)
		tag.size = Vector2(120, 22)
		holder.add_child(tag)
	var tap := Button.new()
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		tap.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	_place(tap, x0 - 20, GROUND - 170, W - x0, 210)
	tap.pressed.connect(func(): deck_pressed.emit())
	_squad.add_child(tap)

# Bottom tab bar: 병사 · 뽑기 · 출전 (big) · 블록 퍼즐 · 랭킹
func _build_nav() -> void:
	var bar := Panel.new()
	LaneUI.dress(bar, "panel_wood")
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(bar, 0, NAV_Y, W, 1280 - NAV_Y)
	add_child(bar)
	var tabs := [
		{"label": "병사", "x": 8.0, "sig": deck_pressed, "art": "res://assets/art/lane/knight.png"},
		{"label": "뽑기", "x": 148.0, "sig": gacha_pressed, "art": "res://assets/art/ui/icon_gem.png"},
		{"label": "블록 퍼즐", "x": 432.0, "sig": play_pressed, "art": "res://assets/sprites/block_cyan.png"},
		{"label": "랭킹", "x": 572.0, "sig": ranking_pressed, "art": "res://assets/sprites/crown_icon.png"},
	]
	for t in tabs:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		LaneUI.button(b, "blue", 18)
		_place(b, t["x"], NAV_Y + 14, 140, 150)
		var sig: Signal = t["sig"]
		b.pressed.connect(func(): sig.emit())
		add_child(b)
		var art := TextureRect.new()
		art.texture = load(t["art"])
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(art, 40, 18, 60, 56)
		b.add_child(art)
		var l := LaneUI.label(t["label"], 20, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		_place(l, 0, 78, 140, 30)
		b.add_child(l)
		var sub := LaneUI.label("", 14, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_place(sub, 0, 108, 140, 24)
		b.add_child(sub)
		if t["label"] == "블록 퍼즐":
			best_value = sub
		elif t["label"] == "랭킹":
			ranking_button = b
			ranking_label = l
			rank_value = sub
			rank_title = LaneUI.label("", 12, LaneUI.TEXT)
			rank_title.visible = false
			b.add_child(rank_title)
	# 출전: the big red one in the middle, raised above the bar
	var go := Button.new()
	go.focus_mode = Control.FOCUS_NONE
	go.text = ""
	LaneUI.button(go, "red", 26)
	_place(go, 290, NAV_Y - 36, 140, 186)
	go.pressed.connect(func(): battle_pressed.emit())
	add_child(go)
	var fort := TextureRect.new()
	fort.texture = load("res://assets/art/lane/fortress.png")
	fort.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fort.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fort.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fort.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(fort, 30, 16, 80, 96)
	go.add_child(fort)
	var gl := LaneUI.label("출전", 28, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_place(gl, 0, 116, 140, 40)
	go.add_child(gl)
	var tw := go.create_tween().set_loops()
	go.pivot_offset = go.size * 0.5
	tw.tween_property(go, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(go, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)

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
