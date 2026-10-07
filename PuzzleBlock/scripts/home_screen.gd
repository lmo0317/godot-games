class_name HomeScreen
extends ColorRect
# Full-screen home: profile bar, logo, two game buttons (블록 기사단 on top, the block game under it)
# and ranking.
# main.gd fills it through refresh() and listens to the signals.

signal play_pressed
signal battle_pressed
signal ranking_pressed
signal settings_pressed
signal profile_pressed
signal sound_pressed

const W: float = 720.0
const MARGIN: float = 40.0
const LOGO_Y: float = 176.0

var sound_on_tex: Texture2D = preload("res://assets/sprites/sound_on.png")
var sound_off_tex: Texture2D = preload("res://assets/sprites/sound_off.png")

var avatar: TextureRect
var name_label: Label
var sub_label: Label
var sound_btn: Button
var best_value: Label
var rank_value: Label
var battle_status: Label
var logo: Control
var ranking_button: Button
var ranking_label: Label
var top_chip: Button
var settings_btn: Button
var rank_title: Label

func _ready() -> void:
	color = UIKit.BG
	z_index = 150
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var glow := GradientTexture2D.new()
	glow.gradient = Gradient.new()
	glow.gradient.set_color(0, Color(0.1, 0.16, 0.3))
	glow.gradient.set_color(1, UIKit.BG)
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.22)
	glow.fill_to = Vector2(1.15, 0.72)
	var bg := UIKit.backdrop(glow)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	_build_top_bar()
	_build_logo()
	_build_battle_card()
	_build_classic_card()
	_build_ranking_button()
	var footer := UIKit.label("퍼즐블록 · Godot 4.7", UIKit.TYPE_SMALL, Color(UIKit.MUTED, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	_place(footer, 0, 1198, W, 32)
	add_child(footer)

# info: nickname, sub, avatar, best, rank, muted (other keys are ignored)
func refresh(info: Dictionary) -> void:
	avatar.texture = info.get("avatar")
	name_label.text = str(info.get("nickname", "플레이어"))
	sub_label.text = str(info.get("sub", "프로필 편집"))
	best_value.text = UIKit.format_number(int(info.get("best", 0)))
	var rank: int = int(info.get("rank", -1))
	rank_value.text = "전체 %d위" % rank if rank > 0 else "기록 없음"
	var lane: Dictionary = LaneStages.load_progress()
	battle_status.text = "STAGE %d / %d  ·  ★ %d" % [int(lane["unlocked"]), LaneStages.count(), LaneStages.total_stars()]
	set_muted(bool(info.get("muted", false)))

func set_muted(muted: bool) -> void:
	sound_btn.icon = sound_off_tex if muted else sound_on_tex

# ---------------------------------------------------------------------------

func _build_top_bar() -> void:
	var chip := Button.new()
	top_chip = chip
	UIKit.style_button(chip, "secondary", 20, 36)
	_place(chip, MARGIN, 36, 420, 76)
	chip.pressed.connect(func(): profile_pressed.emit())
	add_child(chip)

	avatar = TextureRect.new()
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(avatar, 10, 10, 56, 56)
	chip.add_child(avatar)
	name_label = UIKit.label("", 22)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(name_label, 78, 10, 320, 30)
	chip.add_child(name_label)
	sub_label = UIKit.label("", UIKit.TYPE_SMALL, UIKit.MUTED)
	sub_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place(sub_label, 78, 40, 320, 24)
	chip.add_child(sub_label)

	sound_btn = _icon_button(sound_on_tex)
	_place(sound_btn, W - MARGIN - 76 - 12 - 76, 36, 76, 76)
	sound_btn.pressed.connect(func(): sound_pressed.emit())
	add_child(sound_btn)
	settings_btn = _icon_button(preload("res://assets/sprites/settings_icon.png"))
	_place(settings_btn, W - MARGIN - 76, 36, 76, 76)
	settings_btn.pressed.connect(func(): settings_pressed.emit())
	add_child(settings_btn)

func _build_logo() -> void:
	logo = Control.new()
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(logo, 0, LOGO_Y, W, 290)
	add_child(logo)
	# A piece about to drop into its hole (tools/generate_store_assets.py draws it, same as the app icon)
	var mark := TextureRect.new()
	mark.texture = preload("res://assets/sprites/logo.png")
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(mark, (W - 200) * 0.5, -40, 200, 200)
	logo.add_child(mark)
	var title := UIKit.label("퍼즐블록", UIKit.TYPE_DISPLAY, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_color_override("font_shadow_color", Color(UIKit.ACCENT, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 0)
	title.add_theme_constant_override("shadow_offset_y", 5)
	_place(title, 0, 158, W, 84)
	logo.add_child(title)
	var tagline := UIKit.label("PUZZLE BLOCK · 8×8", 22, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_place(tagline, 0, 250, W, 32)
	logo.add_child(tagline)
	# Gentle idle float
	var tw := logo.create_tween().set_loops()
	tw.tween_property(logo, "position:y", LOGO_Y - 8.0, 1.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(logo, "position:y", LOGO_Y, 1.6).set_trans(Tween.TRANS_SINE)

const CARD_H: float = 220.0
const BATTLE_Y: float = 508.0
const CLASSIC_Y: float = 752.0
const RANKING_Y: float = 1000.0

# Top button: 블록 기사단, a little pixel battle scene inside the card
func _build_battle_card() -> void:
	var accent: Color = Color(1.0, 0.5, 0.42)
	var card := Button.new()
	UIKit.style_raised(card, Color(0.2, 0.12, 0.14), Color(accent, 0.9), accent.darkened(0.6), 26)
	_place(card, MARGIN, BATTLE_Y, W - MARGIN * 2, CARD_H)
	card.pressed.connect(func(): battle_pressed.emit())
	add_child(card)
	# The battlefield picture, clipped to the card's rounded shape
	var mask := Panel.new()
	mask.add_theme_stylebox_override("panel", UIKit.box(Color.WHITE, Color.TRANSPARENT, 22))
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_place(mask, 4, 4, card.size.x - 8, CARD_H - 8 - UIKit.BUTTON_DEPTH)
	card.add_child(mask)
	var lane: Texture2D = preload("res://assets/art/lane/lane.png")
	var bg := TextureRect.new()
	bg.texture = lane
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k: float = 3.0
	bg.size = Vector2(lane.get_width(), lane.get_height()) * k
	bg.position = Vector2((mask.size.x - bg.size.x) * 0.5, mask.size.y - bg.size.y + 10)
	mask.add_child(bg)
	# Darker on the left so the title reads well
	var shade := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0.05, 0.04, 0.1, 0.78))
	g.gradient.set_color(1, Color(0.05, 0.04, 0.1, 0.0))
	g.fill_to = Vector2(1, 0)
	shade.texture = g
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(shade, 0, 0, mask.size.x * 0.62, mask.size.y)
	mask.add_child(shade)
	var ground: float = mask.size.y - 14
	for u in [["knight", 352.0], ["spearman", 404.0], ["slime", 500.0], ["goblin", 556.0]]:
		var t: Texture2D = load("res://assets/art/lane/%s.png" % u[0])
		var sp := TextureRect.new()
		sp.texture = t
		sp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sp.stretch_mode = TextureRect.STRETCH_SCALE
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sp.size = Vector2(t.get_width(), t.get_height()) * 2.0
		sp.position = Vector2(u[1] - sp.size.x * 0.5, ground - sp.size.y)
		mask.add_child(sp)
	var title := _outlined("블록 기사단", 44)
	_place(title, 26, 22, 360, 56)
	card.add_child(title)
	var d := _outlined("블록을 깨 금화로 병사 소환", UIKit.TYPE_SMALL, Color(0.92, 0.94, 1.0))
	_place(d, 28, 82, 360, 28)
	card.add_child(d)
	battle_status = _outlined("", 24, UIKit.GOLD)
	_place(battle_status, 28, 148, 300, 34)
	card.add_child(battle_status)

# Second button: the block game (classic), with its best score and rank
func _build_classic_card() -> void:
	var card := Button.new()
	UIKit.style_raised(card, Color(0.11, 0.2, 0.4), Color(UIKit.ACCENT_HI, 0.9), UIKit.ACCENT.darkened(0.6), 26)
	_place(card, MARGIN, CLASSIC_Y, W - MARGIN * 2, CARD_H)
	card.pressed.connect(func(): play_pressed.emit())
	add_child(card)
	# A few pieces made of real block tiles
	var cells := [[0, 0, "cyan"], [0, 1, "cyan"], [0, 2, "cyan"], [1, 2, "cyan"], [2, 1, "yellow"], [3, 1, "yellow"], [2, 2, "yellow"], [3, 2, "yellow"], [3, 0, "pink"]]
	for c in cells:
		var chip := TextureRect.new()
		chip.texture = BlockSkins.texture(c[2], "classic")
		chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(chip, 34 + c[0] * 40, 46 + c[1] * 40, 38, 38)
		card.add_child(chip)
	var title := UIKit.label("블록 게임", 44)
	_place(title, 220, 22, 360, 56)
	card.add_child(title)
	var d := UIKit.label("8×8 블록 퍼즐", UIKit.TYPE_SMALL, Color(0.8, 0.86, 1.0))
	_place(d, 222, 82, 360, 28)
	card.add_child(d)
	var best_title := UIKit.label("최고 점수", UIKit.TYPE_SMALL, Color(0.8, 0.86, 1.0))
	_place(best_title, 222, 124, 200, 26)
	card.add_child(best_title)
	best_value = UIKit.label("0", 36, UIKit.GOLD)
	_place(best_value, 222, 148, 220, 44)
	card.add_child(best_value)
	rank_title = UIKit.label("클래식 랭킹", UIKit.TYPE_SMALL, Color(0.8, 0.86, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	_place(rank_title, 400, 124, 214, 26)
	card.add_child(rank_title)
	rank_value = UIKit.label("", 26, UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(rank_value, 400, 150, 214, 40)
	card.add_child(rank_value)

func _outlined(text: String, size_px: int, col: Color = UIKit.TEXT) -> Label:
	var l := UIKit.label(text, size_px, col)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.04, 0.1))
	return l

func set_ranking_visible(on: bool, show_rank: bool = true) -> void:
	# show_rank: our own server knows the player's rank; Toss's leaderboard does not tell us
	ranking_button.visible = on
	rank_title.visible = on and show_rank
	rank_value.visible = on and show_rank

func clear_top_right() -> void:
	# Apps in Toss floats its "more" and X buttons over the top-right corner: keep ours out of it
	top_chip.size.x = 260
	name_label.size.x = 170
	sub_label.size.x = 170
	sound_btn.position.x = MARGIN + 260 + 12
	settings_btn.position.x = MARGIN + 260 + 12 + 76 + 12

func flash_ranking_note(text: String) -> void:
	# Shows why the ranking could not open on the button itself for a moment
	ranking_label.text = text
	ranking_label.add_theme_font_size_override("font_size", 19)
	get_tree().create_timer(3.0).timeout.connect(func():
		ranking_label.text = "랭킹"
		ranking_label.add_theme_font_size_override("font_size", 24))

func _build_ranking_button() -> void:
	var btn := Button.new()
	ranking_button = btn
	UIKit.style_button(btn, "secondary", 24, 24)
	_place(btn, MARGIN, RANKING_Y, W - MARGIN * 2, 88)
	btn.pressed.connect(func(): ranking_pressed.emit())
	add_child(btn)
	# Crown + label centered as one group
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(row)
	var crown := TextureRect.new()
	crown.texture = preload("res://assets/sprites/crown_icon.png")
	crown.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crown.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crown.custom_minimum_size = Vector2(34, 34)
	crown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	crown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(crown)
	ranking_label = UIKit.label("랭킹", 24)
	row.add_child(ranking_label)

func _icon_button(tex: Texture2D) -> Button:
	var b := Button.new()
	UIKit.style_button(b, "secondary", 16, 38)
	b.icon = tex
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 38)
	return b

func _place(c: Control, x: float, y: float, w: float, h: float) -> void:
	c.position = Vector2(x, y)
	c.size = Vector2(w, h)
