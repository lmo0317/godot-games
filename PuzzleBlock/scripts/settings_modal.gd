class_name SettingsModal
extends ColorRect

signal closed
signal request_profile_setup
signal request_tutorial

@onready var card: Panel = $Card
@onready var btn_close: Button = $Card/BtnClose
@onready var preview_avatar: TextureRect = $Card/ScrollContainer/Content/ProfileBox/Margin/VBox/PreviewBox/PreviewAvatar
@onready var avatar_grid: GridContainer = $Card/ScrollContainer/Content/ProfileBox/Margin/VBox/AvatarGrid
@onready var input_nick: LineEdit = $Card/ScrollContainer/Content/ProfileBox/Margin/VBox/NickEdit
@onready var btn_save_nick: Button = $Card/ScrollContainer/Content/ProfileBox/Margin/VBox/BtnSaveProfile
@onready var nick_status: Label = $Card/ScrollContainer/Content/ProfileBox/Margin/VBox/StatusLabel

# Game Settings Toggles
@onready var btn_sound: Button = $Card/ScrollContainer/Content/OptionsBox/Margin/VBox/BtnSound
@onready var btn_shake: Button = $Card/ScrollContainer/Content/OptionsBox/Margin/VBox/BtnShake
@onready var btn_ghost: Button = $Card/ScrollContainer/Content/OptionsBox/Margin/VBox/BtnGhost
@onready var btn_vibration: Button = $Card/ScrollContainer/Content/OptionsBox/Margin/VBox/BtnVibration

# Account & Close
@onready var btn_reset_profile: Button = $Card/ScrollContainer/Content/AccountBox/Margin/VBox/BtnResetProfile
@onready var btn_close_bottom: Button = $Card/BtnCloseBottom
@onready var content_box: VBoxContainer = $Card/ScrollContainer/Content
@onready var account_box: PanelContainer = $Card/ScrollContainer/Content/AccountBox
@onready var account_sec_title: Label = $Card/ScrollContainer/Content/AccountBox/Margin/VBox/SecTitle
@onready var scroll: ScrollContainer = $Card/ScrollContainer
@onready var profile_box: PanelContainer = $Card/ScrollContainer/Content/ProfileBox
@onready var options_box: PanelContainer = $Card/ScrollContainer/Content/OptionsBox

# Tabs keep each page short: game options, profile/account, achievements
const TABS: Array[Dictionary] = [
	{"id": "game", "name": "게임"},
	{"id": "profile", "name": "프로필"},
	{"id": "achievements", "name": "업적"},
]
var current_tab: String = "game"
var tab_buttons: Dictionary = {} # tab id -> Button
var achievement_box: PanelContainer

var font_res: Font = preload("res://assets/fonts/font.ttf")
var achievement_summary: Label
var achievement_list: VBoxContainer
var skin_buttons: Dictionary = {} # skin id -> Button

var selected_avatar_id: int = 1
var avatar_buttons: Array[Button] = []

func _ready() -> void:
	visible = false
	UIKit.style_modal_backdrop(self)
	input_nick.max_length = LeaderboardManager.MAX_NICKNAME_LENGTH
	_setup_avatar_grid()
	
	btn_close.pressed.connect(close)
	btn_close_bottom.pressed.connect(close)
	btn_save_nick.pressed.connect(_on_save_profile_pressed)
	input_nick.text_submitted.connect(func(_t): _on_save_profile_pressed())
	
	btn_sound.pressed.connect(_on_sound_toggled)
	btn_shake.pressed.connect(_on_shake_toggled)
	btn_ghost.pressed.connect(_on_ghost_toggled)
	btn_vibration.pressed.connect(_on_vibration_toggled)
	
	btn_reset_profile.pressed.connect(_on_reset_profile_pressed)
	_build_achievement_box()
	_build_skin_picker()
	UIKit.style_modal(card, $Card/Title)
	for panel in [profile_box, options_box, account_box, achievement_box]:
		panel.add_theme_stylebox_override("panel", UIKit.section())
	UIKit.style_avatar_frame($Card/ScrollContainer/Content/ProfileBox/Margin/VBox/PreviewBox/PreviewFrame)
	$Card/Subtitle.visible = false
	_build_tabs()
	DragScroll.attach(scroll)
	UIKit.style_close_button(btn_close)
	UIKit.style_button(btn_close_bottom, "secondary", 20, 16)
	UIKit.style_button(btn_save_nick, "primary", UIKit.TYPE_BODY, 14)
	UIKit.style_button(btn_reset_profile, "danger", UIKit.TYPE_BODY, 14)
	input_nick.add_theme_stylebox_override("normal", UIKit.inset(12))
	input_nick.add_theme_stylebox_override("focus", UIKit.box(Color(UIKit.ACCENT, 0.12), UIKit.ACCENT_HI, 12, 2))

func _setup_avatar_grid() -> void:
	for child in avatar_grid.get_children():
		child.queue_free()
	avatar_buttons.clear()
	
	for i in range(1, 9):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(56, 56)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.expand_icon = true
		
		var tex = LeaderboardManager.get_avatar_texture(i)
		if tex:
			btn.icon = tex
			
		UIKit.style_avatar_button(btn, false)
		
		var avatar_index = i
		btn.pressed.connect(func(): _select_avatar(avatar_index))
		
		avatar_grid.add_child(btn)
		avatar_buttons.append(btn)

func open(tab: String = "") -> void:
	SoundManager.play_click()
	if not tab.is_empty():
		current_tab = tab
	visible = true
	modulate.a = 0.0
	
	selected_avatar_id = LeaderboardManager.avatar_id
	input_nick.text = LeaderboardManager.nickname
	nick_status.text = ""
	
	_select_avatar(selected_avatar_id)
	_update_toggle_buttons()
	_refresh_achievements()
	_show_tab(current_tab)
		
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)

func close() -> void:
	SoundManager.play_click()
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(func():
		visible = false
		closed.emit()
	)

func _select_avatar(id: int) -> void:
	selected_avatar_id = id
	preview_avatar.texture = LeaderboardManager.get_avatar_texture(selected_avatar_id)
	
	for i in range(avatar_buttons.size()):
		var btn = avatar_buttons[i]
		var idx = i + 1
		UIKit.style_avatar_button(btn, idx == selected_avatar_id)

func _on_save_profile_pressed() -> void:
	var nick = input_nick.text.strip_edges()
	if nick.is_empty():
		nick_status.text = "닉네임을 한 글자 이상 입력해 주세요."
		return
	if nick.length() > LeaderboardManager.MAX_NICKNAME_LENGTH:
		nick = nick.substr(0, LeaderboardManager.MAX_NICKNAME_LENGTH)
		
	nick_status.text = "저장 중..."
	SoundManager.play_click()
	
	LeaderboardManager.update_profile(nick, selected_avatar_id, func(ok: bool):
		if ok:
			nick_status.text = "프로필이 성공적으로 저장되었습니다."
		else:
			nick_status.text = "저장 완료 (로컬 저장됨)"
	)

func _update_toggle_buttons() -> void:
	_style_toggle_btn(btn_sound, "효과음", SettingsManager.sound_enabled)
	_style_toggle_btn(btn_shake, "화면 흔들림", SettingsManager.screen_shake_enabled)
	_style_toggle_btn(btn_ghost, "놓을 자리 미리보기", SettingsManager.ghost_piece_enabled)
	_style_toggle_btn(btn_vibration, "진동 (모바일)", SettingsManager.vibration_enabled)
	_update_skin_buttons()

func _style_toggle_btn(btn: Button, title: String, enabled: bool) -> void:
	# Setting row: name on the left, on/off pill on the right
	btn.text = title
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UIKit.style_button(btn, "secondary", UIKit.TYPE_BODY, 14)
	var state: Label = btn.get_node_or_null("State")
	if state == null:
		state = UIKit.label("", UIKit.TYPE_BODY, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		state.name = "State"
		state.anchor_left = 1.0
		state.anchor_right = 1.0
		state.anchor_bottom = 1.0
		state.offset_left = -96
		state.offset_right = -12
		state.offset_top = 9
		state.offset_bottom = -9
		btn.add_child(state)
	state.text = "켜짐" if enabled else "꺼짐"
	state.add_theme_color_override("font_color", UIKit.TEXT if enabled else UIKit.MUTED)
	state.add_theme_stylebox_override("normal", UIKit.box(UIKit.ACCENT if enabled else UIKit.SURFACE, UIKit.BORDER, 12, 0 if enabled else 2))

func _on_sound_toggled() -> void:
	SettingsManager.set_sound(not SettingsManager.sound_enabled)
	SoundManager.play_click()
	_update_toggle_buttons()

func _on_shake_toggled() -> void:
	SettingsManager.set_shake(not SettingsManager.screen_shake_enabled)
	SoundManager.play_click()
	_update_toggle_buttons()

func _on_ghost_toggled() -> void:
	SettingsManager.set_ghost(not SettingsManager.ghost_piece_enabled)
	SoundManager.play_click()
	_update_toggle_buttons()

func _on_vibration_toggled() -> void:
	SettingsManager.set_vibration(not SettingsManager.vibration_enabled)
	SoundManager.play_click()
	SettingsManager.vibrate(30)
	_update_toggle_buttons()

func _build_skin_picker() -> void:
	# Row of skin buttons (preview block + name) under the option toggles
	var options_vbox: VBoxContainer = btn_vibration.get_parent()
	options_vbox.add_child(_small_label("블록 스킨", UIKit.TYPE_BODY, UIKit.TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for s in BlockSkins.SKINS:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 96)
		btn.icon = BlockSkins.texture("blue", s["id"])
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		btn.text = s["name"]
		btn.add_theme_font_override("font", font_res)
		btn.add_theme_font_size_override("font_size", UIKit.TYPE_SMALL)
		btn.add_theme_constant_override("icon_max_width", 44)
		var skin_id: String = s["id"]
		btn.pressed.connect(func(): _on_skin_pressed(skin_id))
		row.add_child(btn)
		skin_buttons[skin_id] = btn
	options_vbox.add_child(row)
	# Replays the first-game hint in a fresh classic game
	var btn_tutorial := Button.new()
	btn_tutorial.text = "게임 방법 다시 보기"
	btn_tutorial.custom_minimum_size = Vector2(0, 56)
	UIKit.style_button(btn_tutorial, "secondary", UIKit.TYPE_BODY, 14)
	btn_tutorial.pressed.connect(func():
		close()
		request_tutorial.emit())
	options_vbox.add_child(btn_tutorial)

func _update_skin_buttons() -> void:
	for skin_id in skin_buttons:
		var btn: Button = skin_buttons[skin_id]
		var selected: bool = skin_id == SettingsManager.block_skin
		var sb := UIKit.box(Color(UIKit.ACCENT, 0.24) if selected else UIKit.SURFACE_HI, UIKit.CYAN if selected else UIKit.BORDER, 14, 3 if selected else 2)
		sb.content_margin_top = 8
		sb.content_margin_bottom = 6
		for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			btn.add_theme_stylebox_override(state, sb)
		btn.add_theme_color_override("font_color", UIKit.TEXT)

func _on_skin_pressed(skin_id: String) -> void:
	SoundManager.play_click()
	SettingsManager.set_skin(skin_id)
	_update_skin_buttons()

func _build_tabs() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.anchor_right = 1.0
	row.offset_left = 25
	row.offset_right = -25
	row.offset_top = 74
	row.offset_bottom = 122
	card.add_child(row)
	for t in TABS:
		var btn := Button.new()
		btn.text = t["name"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tab_id: String = t["id"]
		btn.pressed.connect(func():
			SoundManager.play_click()
			_show_tab(tab_id)
		)
		row.add_child(btn)
		tab_buttons[tab_id] = btn
	# Content starts under the tab row
	scroll.offset_top = 136

func _show_tab(tab_id: String) -> void:
	current_tab = tab_id
	# Short pages stay compact; long lists keep the full scrollable card height.
	var half_height := float({"game": 380.0, "profile": 470.0, "achievements": 460.0}.get(tab_id, 380.0))
	card.offset_top = -half_height
	card.offset_bottom = half_height
	options_box.visible = tab_id == "game"
	profile_box.visible = tab_id == "profile"
	account_box.visible = tab_id == "profile"
	achievement_box.visible = tab_id == "achievements"
	for id in tab_buttons:
		UIKit.style_button(tab_buttons[id], "primary" if id == tab_id else "ghost", 20, 14)
	scroll.scroll_vertical = 0

func _build_achievement_box() -> void:
	var box := PanelContainer.new()
	box.name = "AchievementBox"
	achievement_box = box
	box.add_theme_stylebox_override("panel", account_box.get_theme_stylebox("panel"))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	box.add_child(margin)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	margin.add_child(v)

	var sec := Label.new()
	sec.text = "업적"
	sec.label_settings = account_sec_title.label_settings
	v.add_child(sec)

	achievement_summary = _small_label("", UIKit.TYPE_SMALL, UIKit.MUTED)
	v.add_child(achievement_summary)

	achievement_list = VBoxContainer.new()
	achievement_list.add_theme_constant_override("separation", 6)
	v.add_child(achievement_list)

	content_box.add_child(box)
	content_box.move_child(box, account_box.get_index())

func _refresh_achievements() -> void:
	var defs: Array[Dictionary] = Achievements.DEFS
	var done := 0
	for child in achievement_list.get_children():
		child.queue_free()
	for d in defs:
		var got: bool = Achievements.is_unlocked(d["id"])
		if got:
			done += 1
		# Row: name + description on the left, progress or "달성" on the right
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UIKit.list_row("complete" if got else "normal"))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		texts.add_child(_small_label(d["name"], UIKit.TYPE_BODY, UIKit.GOLD if got else UIKit.TEXT))
		texts.add_child(_small_label(d["desc"], UIKit.TYPE_SMALL, UIKit.MUTED))
		h.add_child(texts)
		var progress := "달성" if got else "%s / %s" % [UIKit.format_number(mini(Achievements.get_stat(d["stat"]), int(d["target"]))), UIKit.format_number(int(d["target"]))]
		var p := _small_label(progress, UIKit.TYPE_SMALL, UIKit.GOLD if got else UIKit.MUTED)
		p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(p)
		achievement_list.add_child(row)
	achievement_summary.text = "달성 %d / %d" % [done, defs.size()]

func _small_label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_res)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

func _on_reset_profile_pressed() -> void:
	SoundManager.play_click()
	LeaderboardManager.reset_profile()
	close()
	request_profile_setup.emit()
