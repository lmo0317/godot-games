class_name HomeScreen
extends ColorRect
# Full-screen home: profile bar, logo, best score, play button, mode cards and ranking.
# main.gd fills it through refresh() and listens to the signals.

signal play_pressed
signal daily_pressed
signal adventure_pressed
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
var daily_status: Label
var adventure_status: Label
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
	_build_best_panel()
	_build_play_button()
	_build_mode_cards()
	_build_ranking_button()
	var footer := UIKit.label("퍼즐블록 · Godot 4.7", UIKit.TYPE_SMALL, Color(UIKit.MUTED, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	_place(footer, 0, 1198, W, 32)
	add_child(footer)

# info: nickname, sub, avatar, best, rank, daily_best (-1 = not played today), stars, stars_total,
#       next_stage, muted
func refresh(info: Dictionary) -> void:
	avatar.texture = info.get("avatar")
	name_label.text = str(info.get("nickname", "플레이어"))
	sub_label.text = str(info.get("sub", "프로필 편집"))
	best_value.text = UIKit.format_number(int(info.get("best", 0)))
	var rank: int = int(info.get("rank", -1))
	rank_value.text = "전체 %d위" % rank if rank > 0 else "기록 없음"
	var daily_best: int = int(info.get("daily_best", -1))
	daily_status.text = "오늘 최고 %s점" % UIKit.format_number(daily_best) if daily_best > 0 else "오늘 첫 도전!"
	adventure_status.text = "★ %d / %d  ·  %d단계" % [int(info.get("stars", 0)), int(info.get("stars_total", 60)), int(info.get("next_stage", 1))]
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

func _build_best_panel() -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UIKit.inset(24))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(panel, MARGIN, 506, W - MARGIN * 2, 124)
	add_child(panel)
	var best_title := UIKit.label("최고 점수", UIKit.TYPE_BODY, UIKit.MUTED)
	_place(best_title, 30, 18, 280, 26)
	panel.add_child(best_title)
	best_value = UIKit.label("0", 48, UIKit.GOLD)
	_place(best_value, 30, 46, 340, 60)
	panel.add_child(best_value)
	rank_title = UIKit.label("클래식 랭킹", UIKit.TYPE_BODY, UIKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(rank_title, 330, 18, 280, 26)
	panel.add_child(rank_title)
	rank_value = UIKit.label("", 28, UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(rank_value, 330, 50, 280, 52)
	panel.add_child(rank_value)

func _build_play_button() -> void:
	var play := Button.new()
	play.text = "▶  게임 시작"
	UIKit.style_button(play, "primary", 38, 28)
	_place(play, MARGIN, 666, W - MARGIN * 2, 124)
	play.pivot_offset = play.size * 0.5
	play.pressed.connect(func(): play_pressed.emit())
	add_child(play)

func _build_mode_cards() -> void:
	var card_w: float = (W - MARGIN * 2 - 20) * 0.5
	daily_status = _mode_card(MARGIN, "오늘의 챌린지", "모두 같은 블록으로 겨루기", UIKit.PURPLE, "purple", func(): daily_pressed.emit())
	adventure_status = _mode_card(MARGIN + card_w + 20, "어드벤처", "목표가 있는 스테이지 20개", UIKit.CYAN, "cyan", func(): adventure_pressed.emit())

func _mode_card(x: float, title: String, desc: String, accent: Color, block_color: String, on_press: Callable) -> Label:
	var card := Button.new()
	UIKit.style_raised(card, Color(0.11, 0.14, 0.23), Color(accent, 0.85), accent.darkened(0.7), 24)
	_place(card, x, 818, (W - MARGIN * 2 - 20) * 0.5, 184)
	card.pressed.connect(on_press)
	add_child(card)

	var chip := TextureRect.new()
	chip.texture = BlockSkins.texture(block_color, "classic")
	chip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(chip, 24, 22, 28, 28)
	card.add_child(chip)
	var t := UIKit.label(title, 26)
	_place(t, 24, 56, 270, 36)
	card.add_child(t)
	var d := UIKit.label(desc, UIKit.TYPE_SMALL, UIKit.MUTED)
	_place(d, 24, 94, 270, 26)
	card.add_child(d)
	var status := UIKit.label("", 20, accent)
	_place(status, 24, 132, 270, 30)
	card.add_child(status)
	return status

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
	_place(btn, MARGIN, 1030, W - MARGIN * 2, 96)
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
