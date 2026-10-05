class_name MainGame
extends Control

const SAVE_PATH: String = "user://block_blast_save.cfg"

# Tray slot positions in 720x1280 screen
const TRAY_SLOTS: Array[Vector2] = [
	Vector2(140, 1060),
	Vector2(360, 1060),
	Vector2(580, 1060)
]

var block_piece_scene: PackedScene = preload("res://scenes/block_piece.tscn")
var floating_text_scene: PackedScene = preload("res://scenes/floating_text.tscn")
var sound_on_tex: Texture2D = preload("res://assets/sprites/sound_on.png")
var sound_off_tex: Texture2D = preload("res://assets/sprites/sound_off.png")

var score: int = 0
var best_score: int = 0
var combo_count: int = 0
const MAX_COMBO_GRACE: int = 3
# Scoring rules (GAME_DESIGN.md ch.9). tools/export_rules.gd copies these to the server's replay check.
const LINE_SCORE_BASE: int = 10
const COMBO_ALPHA: float = 0.45
const COMBO_BONUS_LINEAR: int = 15
const COMBO_BONUS_QUADRATIC: int = 5
# Perfect clear bonus before the combo multiplier
const PERFECT_CLEAR_BASE: int = 300
# Combo fever: from this combo on, line clear points are multiplied
const FEVER_COMBO: int = 5
const FEVER_MULTIPLIER: float = 1.5
var combo_grace_moves: int = 0
var is_game_over: bool = false
var new_best_achieved: bool = false
var has_revived_this_game: bool = false

# Game mode: "classic" (adaptive endless), "daily" (same seeded sequence for everyone)
# or "adventure" (stage with a start board, goal and move limit)
var game_mode: String = "classic"
var challenge_day: String = ""
var challenge_rng: RandomNumberGenerator = null
var daily_best: int = 0
var stage: Dictionary = {}
var stage_progress: int = 0
var adventure_select: AdventureSelect
# Classic game-over texts, restored after the modal is reused for stage results
var go_default_texts: Dictionary = {}
var go_btn_default_y: Dictionary = {}
# Replay log sent with the score so the server can recompute it (see docs/SCORING_RULES.md):
# ["d", id, id, id] deal · ["p", id, x, y] place at grid origin · ["r", cell, ...] revive
var play_log: Array = []

# Achievement toasts shown one at a time
var toast_queue: Array[Dictionary] = []
var toast_busy: bool = false

# Start pattern: games are numbered so a delayed first deal never lands in a newer game
var game_seq: int = 0
var guarantee_first_clear: bool = false
var deal_index: int = 0

# Record chase: the best score when this game started, and the progress bar in the BEST box
var run_start_best: int = 0
var score_counter: ScoreCounter
# First-game hint (TutorialHint): shown in a player's first classic game until a line is cleared
var tutorial_active: bool = false
var tutorial_trays: int = 0
var tutorial_hint: TutorialHint = null
# Versus mode (VersusMatch): turns against the computer on one board
var versus: VersusMatch
var versus_level: String = "normal"

# Combo fever state (combo_count >= FEVER_COMBO) and its looping board glow
var fever_active: bool = false
var fever_tween: Tween = null

# Per-game stats for analytics
var game_id: String = ""
var game_start_msec: int = 0
var last_game_over_msec: int = -1
var move_count: int = 0
var max_combo: int = 0

# Screen Shake
var shake_intensity: float = 0.0
var shake_duration: float = 0.0

# Current 3 tray pieces (null if placed)
var tray_pieces: Array = [null, null, null]
var dragging_piece: BlockPiece = null
var drag_touch_id: int = -1

# Node references
@onready var camera: Camera2D = $Camera2D
@onready var combo_aura: Panel = $ComboAura
@onready var board_background: Panel = $BoardBackground
@onready var board: Board = $Board
@onready var score_label: Label = $UI/Header/ScoreBox/ScoreValue
@onready var best_label: Label = $UI/Header/BestBox/BestValue
@onready var combo_banner: PanelContainer = $UI/ComboBanner
@onready var combo_label: Label = $UI/ComboBanner/ComboLabel
var combo_caption: Label
var exit_confirm: ColorRect = null
var combo_fx: ComboFx
# Screen theme (BoardThemes): two backdrops so a new theme can fade in over the old one
var theme_index: int = 0
var theme_back: TextureRect
var theme_front: TextureRect
var board_style: StyleBoxFlat
var combo_pips: Array[Panel] = []
@onready var btn_home: TextureButton = $UI/Header/BtnHome
@onready var btn_settings: TextureButton = $UI/Header/BtnSettings
@onready var btn_leaderboard: TextureButton = $UI/Header/BtnLeaderboard
@onready var btn_sound: TextureButton = $UI/Header/BtnSound

# Game Over Dialog
@onready var game_over_panel: ColorRect = $UI/GameOverModal
@onready var go_final_score: Label = $UI/GameOverModal/Card/FinalScore
@onready var go_best_score: Label = $UI/GameOverModal/Card/BestScore
@onready var go_new_badge: Label = $UI/GameOverModal/Card/NewBestBadge
@onready var go_rank_status: Label = $UI/GameOverModal/Card/RankStatus
@onready var go_btn_view_rank: Button = $UI/GameOverModal/Card/BtnViewRank
@onready var go_btn_retry: Button = $UI/GameOverModal/Card/BtnRetry
@onready var go_btn_home: Button = $UI/GameOverModal/Card/BtnGoHome

# Revive Modal
@onready var revive_modal: ReviveModal = $UI/ReviveModal

# Leaderboard Modal
@onready var leaderboard_modal: LeaderboardModal = $UI/LeaderboardModal
var was_in_start_screen: bool = false

# Settings & Setup Modals
@onready var settings_modal: SettingsModal = $UI/SettingsModal
@onready var profile_setup_modal: ProfileSetupModal = $UI/ProfileSetupModal

# Start Screen (Home Screen / Lobby)
# Home screen (built in code by HomeScreen); start_screen keeps the old name used across main.gd
var start_screen: HomeScreen
@onready var best_sub: Label = $UI/Header/BestBox/BestHeader/BestSub
@onready var go_title: Label = $UI/GameOverModal/Card/Title
@onready var header_title: Label = $UI/Header/Title

func _ready() -> void:
	randomize()
	# Painted backdrop behind the board; it changes with the theme on every perfect clear
	_build_theme_backdrop()
	_build_combo_banner()
	combo_fx = ComboFx.new()
	add_child(combo_fx)
	combo_fx.setup_embers(Rect2(board.to_global(Vector2.ZERO), Vector2(Board.BOARD_WIDTH, Board.BOARD_HEIGHT)))
	_build_score_header()
	versus = VersusMatch.new()
	$UI/Header.add_child(versus)
	versus.visible = false
	versus.cpu_defeated.connect(func(reason: String): _finish_versus("cpu_" + reason))
	versus.player_defeated.connect(func(reason: String): _finish_versus("player_" + reason))
	for plate in $TrayPlates.get_children():
		plate.add_theme_stylebox_override("panel", UIKit.tray_plate())
	_load_best_score()
	_update_ui()
	SettingsManager.init_settings()
	BlockSkins.preload_skin(SettingsManager.block_skin)
	
	# Header connections
	btn_home.pressed.connect(_open_home_screen)
	btn_settings.pressed.connect(_open_settings)
	btn_sound.pressed.connect(_on_sound_toggled)
	btn_leaderboard.pressed.connect(_open_leaderboard)
	btn_leaderboard.visible = _has_ranking()
	
	# Revive connections
	Achievements.achievement_unlocked.connect(_on_achievement_unlocked)
	revive_modal.revive_accepted.connect(_on_revive_accepted)
	revive_modal.revive_declined.connect(_on_revive_declined)
	
	# Modals signal connections
	leaderboard_modal.closed.connect(_on_leaderboard_closed)
	settings_modal.closed.connect(_on_settings_closed)
	settings_modal.request_profile_setup.connect(func(): profile_setup_modal.open())
	settings_modal.request_tutorial.connect(func():
		SettingsManager.set_tutorial("pending")
		start_screen.visible = false
		start_new_game(false, "classic"))
	profile_setup_modal.setup_completed.connect(_on_profile_setup_completed)
	LeaderboardManager.profile_updated.connect(func(_n, _a): _update_home_profile_ui())
	
	# Home Screen connections
	start_screen = HomeScreen.new()
	$UI.add_child(start_screen)
	# Keep the home screen behind the popups in sibling order so they get input first
	$UI.move_child(start_screen, settings_modal.get_index())
	start_screen.play_pressed.connect(_on_start_play_pressed)
	start_screen.daily_pressed.connect(_on_start_daily_pressed)
	start_screen.adventure_pressed.connect(_open_adventure_select)
	start_screen.versus_pressed.connect(_start_versus)
	start_screen.ranking_pressed.connect(_open_leaderboard)
	start_screen.set_ranking_visible(_has_ranking(), LeaderboardManager.is_online())
	if Toss.active():
		_setup_toss()
	start_screen.settings_pressed.connect(_open_settings)
	start_screen.profile_pressed.connect(_open_settings.bind("profile"))
	start_screen.sound_pressed.connect(_on_sound_toggled)

	adventure_select = AdventureSelect.new()
	$UI.add_child(adventure_select)
	$UI.move_child(adventure_select, settings_modal.get_index())
	adventure_select.stage_selected.connect(_start_adventure_stage)
	adventure_select.closed.connect(_open_home_screen)
	
	# Game Over connections
	go_btn_retry.pressed.connect(start_new_game.bind(true))
	go_btn_view_rank.pressed.connect(_on_go_primary_pressed)
	go_btn_home.pressed.connect(_on_go_secondary_pressed)
	UIKit.style_modal_backdrop(game_over_panel)
	UIKit.style_modal($UI/GameOverModal/Card, go_title)
	go_title.add_theme_font_size_override("font_size", 42)
	UIKit.style_button(go_btn_retry, "primary", 24, 18)
	UIKit.style_button(go_btn_view_rank, "secondary", 22, 18)
	UIKit.style_button(go_btn_home, "ghost", 22, 18)
	go_btn_default_y = {"retry": go_btn_retry.position.y, "primary": go_btn_view_rank.position.y}
	go_default_texts = {
		"title": go_title.text,
		"primary": go_btn_view_rank.text,
		"retry": go_btn_retry.text,
		"secondary": go_btn_home.text,
		"badge": go_new_badge.text,
		"score_sub": $UI/GameOverModal/Card/ScoreSub.text
	}
	
	combo_banner.visible = false
	combo_aura.visible = false
	revive_modal.visible = false
	game_over_panel.visible = false
	leaderboard_modal.visible = false
	settings_modal.visible = false
	profile_setup_modal.visible = false
	
	# Show Start Screen initially
	start_screen.visible = true
	_update_home_profile_ui()
	
	# First-time user profile setup popup check. Not in Toss: popups on entry are not allowed there,
	# and the Toss game profile name is used instead (see _setup_toss)
	if not LeaderboardManager.is_profile_setup_done and not Toss.active():
		profile_setup_modal.open()

func _notification(what: int) -> void:
	# Android back button (quit_on_go_back is off)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back_pressed()

func _on_back_pressed() -> void:
	# Close the open panel, leave a game for home, and leave the app only from the home screen
	if exit_confirm != null and exit_confirm.visible:
		exit_confirm.visible = false
	elif settings_modal.visible:
		settings_modal.close()
	elif leaderboard_modal.visible:
		leaderboard_modal.close()
	elif adventure_select.visible:
		adventure_select.close()
	elif start_screen.visible and start_screen.versus_picker.visible:
		start_screen.versus_picker.visible = false
	elif start_screen.visible and not profile_setup_modal.visible:
		if Toss.active():
			_show_exit_confirm()
		else:
			get_tree().quit()
	elif not start_screen.visible:
		_open_home_screen()

# --- Apps in Toss ------------------------------------------------------------

func _has_ranking() -> bool:
	return LeaderboardManager.is_online() or Toss.active()

func _setup_toss() -> void:
	# The Toss back button now comes to us, and closing asks first
	Toss.on_back(_on_back_pressed)
	# Keep the game-specific Toss user key as this player's id
	Toss.fetch_user_key(func(hash_value: String):
		if not hash_value.is_empty() and LeaderboardManager.user_id != "toss_" + hash_value:
			LeaderboardManager.user_id = "toss_" + hash_value
			LeaderboardManager.save_profile())
	# Start with the Toss game profile name instead of asking for a nickname
	if not LeaderboardManager.is_profile_setup_done:
		Toss.fetch_nickname(func(nick: String):
			if not nick.is_empty():
				LeaderboardManager.update_profile(nick, LeaderboardManager.avatar_id))
	# Toss floats its "more" and X buttons over the top-right corner: move our header icons left
	var x := 102.0
	for btn in [btn_settings, btn_leaderboard, btn_sound]:
		btn.position.x = x
		x += 60.0
	# Center the title inside the remaining safe strip instead of under the moved buttons.
	header_title.offset_left = 286.0
	header_title.offset_right = -150.0
	start_screen.clear_top_right()

func _show_exit_confirm() -> void:
	if exit_confirm == null:
		exit_confirm = ColorRect.new()
		exit_confirm.color = Color(0, 0, 0, 0.6)
		exit_confirm.z_index = 300
		exit_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		exit_confirm.mouse_filter = Control.MOUSE_FILTER_STOP
		$UI.add_child(exit_confirm)
		var card := Panel.new()
		UIKit.style_modal(card)
		card.position = Vector2(110, 480)
		card.size = Vector2(500, 300)
		exit_confirm.add_child(card)
		var title := UIKit.label("게임을 종료할까요?", 32, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		title.position = Vector2(0, 50)
		title.size = Vector2(500, 50)
		card.add_child(title)
		var stay := Button.new()
		stay.text = "계속하기"
		UIKit.style_button(stay, "primary", 24, 20)
		stay.position = Vector2(40, 150)
		stay.size = Vector2(200, 80)
		stay.pressed.connect(func(): exit_confirm.visible = false)
		card.add_child(stay)
		var leave := Button.new()
		leave.text = "종료"
		UIKit.style_button(leave, "secondary", 24, 20)
		leave.position = Vector2(260, 150)
		leave.size = Vector2(200, 80)
		leave.pressed.connect(Toss.close)
		card.add_child(leave)
	exit_confirm.visible = true

func _process(delta: float) -> void:
	if shake_duration > 0.0:
		shake_duration -= delta
		var ox = randf_range(-shake_intensity, shake_intensity)
		var oy = randf_range(-shake_intensity, shake_intensity)
		camera.offset = Vector2(ox, oy)
		if shake_duration <= 0.0:
			camera.offset = Vector2.ZERO
			shake_intensity = 0.0

func apply_screen_shake(intensity: float, duration: float) -> void:
	if not SettingsManager.screen_shake_enabled:
		return
	shake_intensity = max(shake_intensity, intensity)
	shake_duration = max(shake_duration, duration)

func start_new_game(from_retry: bool = false, mode: String = "") -> void:
	SoundManager.play_click()
	# Every game starts in the first theme; perfect clears move through the rest
	if theme_index != 0:
		_set_theme(0, false)
	
	# Retry keeps the current mode; the home screen buttons choose one explicitly
	if not mode.is_empty():
		game_mode = mode
	if game_mode == "daily":
		challenge_day = LeaderboardManager.get_kst_day_key()
		challenge_rng = RandomNumberGenerator.new()
		challenge_rng.seed = hash("block-daily-" + challenge_day)
		daily_best = _load_daily_best(challenge_day)
		header_title.text = "오늘의 챌린지"
	elif game_mode == "adventure":
		header_title.text = "STAGE %d" % stage["id"]
		stage_progress = 0
	elif game_mode == "versus":
		header_title.text = "대결 · %s" % VersusMatch.level_name(versus_level)
	else:
		header_title.text = "퍼즐블록"

	score = 0
	score_counter.reset(0)
	var vs_mode: bool = game_mode == "versus"
	versus.visible = vs_mode
	$UI/Header/ScoreBox.visible = not vs_mode
	$UI/Header/BestBox.visible = not vs_mode
	if vs_mode:
		versus.begin(versus_level, LeaderboardManager.nickname, LeaderboardManager.get_avatar_texture(), [])
	_dismiss_tutorial_hint()
	tutorial_trays = 0
	tutorial_active = game_mode == "classic" and (SettingsManager.tutorial_state == "pending" 		or (SettingsManager.tutorial_state == "" and Achievements.get_stat("games_played") == 0))
	combo_count = 0
	combo_grace_moves = 0
	_update_fever()
	is_game_over = false
	new_best_achieved = false
	has_revived_this_game = false
	dragging_piece = null
	drag_touch_id = -1

	move_count = 0
	max_combo = 0
	deal_index = 0
	play_log = []
	run_start_best = daily_best if game_mode == "daily" else (best_score if game_mode == "classic" else 0)
	game_start_msec = Time.get_ticks_msec()
	game_id = "g_%d_%d" % [Time.get_unix_time_from_system(), randi() % 100000]
	var since_last_over: float = -1.0
	if last_game_over_msec >= 0:
		since_last_over = (game_start_msec - last_game_over_msec) / 1000.0
	Analytics.log_event("game_start", {
		"game_id": game_id,
		"from_retry": from_retry,
		"mode": game_mode,
		"day_key": challenge_day if game_mode == "daily" else "",
		"stage_id": stage.get("id", 0) if game_mode == "adventure" else 0,
		"secs_since_game_over": since_last_over
	})
	
	revive_modal.close()
	game_over_panel.visible = false
	combo_banner.visible = false
	_update_combo_aura()
	
	board.reset_board()
	if game_mode == "adventure":
		board.load_layout(stage["layout"])
	_clear_tray()
	_update_ui()

	game_seq += 1
	var seq := game_seq
	if game_mode == "classic" or game_mode == "versus":
		# Classic starts from a few pre-placed pieces (see BlockData.generate_start_pattern);
		# the first set always includes a piece that clears a line right away
		var pattern := BlockData.generate_start_pattern()
		if not pattern.is_empty():
			var delay := board.place_start_pattern(pattern)
			var cells: Array = []
			var grid := board.get_occupancy_snapshot()
			for i in range(grid.size()):
				if grid[i] != 0:
					cells.append(i)
			play_log.append(["s"] + cells)
			guarantee_first_clear = true
			if game_mode == "versus":
				versus.begin(versus_level, LeaderboardManager.nickname, LeaderboardManager.get_avatar_texture(), cells)
			await get_tree().create_timer(delay).timeout
			if seq != game_seq or is_game_over:
				return
	_spawn_new_tray()

func _clear_tray() -> void:
	for i in range(3):
		if tray_pieces[i] != null and is_instance_valid(tray_pieces[i]):
			tray_pieces[i].queue_free()
		tray_pieces[i] = null
	dragging_piece = null

func _spawn_new_tray() -> void:
	SoundManager.play_deal()
	var shapes: Array[Dictionary] = []
	var gen_start_usec: int = Time.get_ticks_usec()
	if game_mode == "daily":
		shapes = BlockData.get_seeded_trio(challenge_rng)
	else:
		# The difficulty curve applies to classic only; adventure stages keep their tuned balance
		# Versus deals with a fixed medium pressure for both sides
		var pressure: float = BlockData.pressure_for_score(score) if game_mode == "classic" else (VersusMatch.PRESSURE if game_mode == "versus" else 0.0)
		if game_mode == "classic" and deal_index < BlockData.FUN_DEALS and score < BlockData.FUN_SCORE_MAX:
			# Opening sets are chosen for fun moments: snug fits, multi-line clears, a combo that keeps
			# going, and a set that empties the board whenever one exists
			shapes = BlockData.get_fun_trio(board, combo_count, score, combo_grace_moves, null, guarantee_first_clear)
		elif game_mode == "classic":
			# A set that can empty the board (perfect clear, next theme), sometimes when only a few
			# blocks are left
			shapes = BlockData.get_perfect_trio(board)
		if shapes.is_empty():
			shapes = BlockData.get_adaptive_trio(board, combo_count, score, combo_grace_moves, null, pressure, guarantee_first_clear)
		guarantee_first_clear = false
	deal_index += 1
	play_log.append(["d"] + shapes.map(func(s): return s["id"]))
	Analytics.log_event("tray_dealt", {
		"game_id": game_id,
		"shapes": shapes.map(func(s): return s["id"]),
		"fill": snappedf(board.get_fill_ratio(), 0.001),
		"note": BlockData.last_generation_note,
		"gen_ms": snappedf((Time.get_ticks_usec() - gen_start_usec) / 1000.0, 0.01)
	})

	for i in range(3):
		var piece: BlockPiece = block_piece_scene.instantiate()
		add_child(piece)
		piece.setup(shapes[i], i, TRAY_SLOTS[i])
		tray_pieces[i] = piece
		
		# Pop in animation
		piece.scale = Vector2.ZERO
		var tw = create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(piece, "scale", Vector2.ONE * piece.tray_scale, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	_check_piece_usability_and_game_over()
	if tutorial_active:
		tutorial_trays += 1
		if tutorial_trays > 3:
			_finish_tutorial() # they are playing fine without clearing; stop nagging
		else:
			_show_tutorial_hint_later(0.45)

func _input(event: InputEvent) -> void:
	if is_game_over or start_screen.visible or leaderboard_modal.visible or settings_modal.visible or profile_setup_modal.visible or adventure_select.visible:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_pointer_down(event.position, -1)
			else:
				_on_pointer_up(event.position, -1)
				
	elif event is InputEventMouseMotion:
		if dragging_piece != null and drag_touch_id == -1:
			_on_pointer_move(event.position)
			
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_pointer_down(event.position, event.index)
		else:
			if event.index == drag_touch_id or drag_touch_id == -1:
				_on_pointer_up(event.position, event.index)
				
	elif event is InputEventScreenDrag:
		if dragging_piece != null and (event.index == drag_touch_id or drag_touch_id == -1):
			_on_pointer_move(event.position)

func _on_pointer_down(screen_pos: Vector2, touch_id: int) -> void:
	if dragging_piece != null:
		return
		
	var best_piece: BlockPiece = null
	var best_dist: float = 99999.0
	
	for piece in tray_pieces:
		if piece != null and is_instance_valid(piece):
			if piece.is_point_inside(screen_pos):
				var d = screen_pos.distance_to(piece.global_position)
				if d < best_dist:
					best_dist = d
					best_piece = piece
					
	if best_piece != null:
		_dismiss_tutorial_hint()
		dragging_piece = best_piece
		drag_touch_id = touch_id
		dragging_piece.start_drag(screen_pos)
		SettingsManager.vibrate(8)
		board.update_ghost_preview(dragging_piece.shape_data, dragging_piece)

func _on_pointer_move(screen_pos: Vector2) -> void:
	if dragging_piece == null or not is_instance_valid(dragging_piece):
		return
	dragging_piece.update_drag(screen_pos)
	board.update_ghost_preview(dragging_piece.shape_data, dragging_piece)

func _on_pointer_up(_screen_pos: Vector2, touch_id: int) -> void:
	if dragging_piece == null or not is_instance_valid(dragging_piece):
		return
	if touch_id != -1 and drag_touch_id != -1 and touch_id != drag_touch_id:
		return
		
	var piece = dragging_piece
	dragging_piece = null
	drag_touch_id = -1
	
	board.hide_ghost_preview()
	
	if not _commit_placement(piece):
		piece.return_to_tray()
		if tutorial_active:
			_show_tutorial_hint_later(0.4)

# Puts the piece where it is held (the player's drop or the computer's move) and runs the scoring,
# clears and what comes next. Returns false if it does not fit there.
func _commit_placement(piece: BlockPiece) -> bool:
	if not board.place_piece(piece.shape_data, piece):
		return false
	var slot_idx = piece.slot_index
	tray_pieces[slot_idx] = null
	
	SettingsManager.vibrate(12)
	play_log.append(["p", piece.shape_data["id"], board.last_origin.x, board.last_origin.y])
	
	# (1) Placement Score: N points (1 per placed tile)
	var cell_count = piece.shape_data["cells"].size()
	_add_score(cell_count, "place")
	
	piece.snap_to_board()
	
	# Check lines
	board.clear_combo = combo_count
	var clear_info = board.check_and_clear_lines()
	var lines = clear_info["lines"]
	var perfect: bool = clear_info["perfect"]
	
	if tutorial_active:
		if lines > 0:
			_finish_tutorial()
		elif not _is_tray_empty():
			_show_tutorial_hint_later(0.5)
	if lines > 0:
		combo_count += 1
		combo_grace_moves = MAX_COMBO_GRACE
		_process_line_clears(lines, clear_info["cells"], clear_info["center"])
		if perfect:
			_process_perfect_clear()
	else:
		if combo_count > 0:
			combo_grace_moves -= 1
			if combo_grace_moves <= 0:
				combo_count = 0
				_hide_combo_banner()
				_update_combo_aura()
			else:
				# Grace move consumed, combo streak preserved!
				_show_combo_banner(combo_count, combo_grace_moves)

	_update_fever()
	move_count += 1
	max_combo = max(max_combo, combo_count)
	Achievements.add_stat("total_lines", lines)
	Achievements.max_stat("max_combo", combo_count)
	if perfect:
		Achievements.add_stat("perfect_clears", 1)
	Analytics.log_event("place", {
		"game_id": game_id,
		"shape": piece.shape_data["id"],
		"cells": cell_count,
		"lines": lines,
		"perfect": perfect,
		"combo": combo_count,
		"fever": fever_active,
		"grace": combo_grace_moves,
		"fill_after": snappedf(board.get_fill_ratio(), 0.001)
	})

	if game_mode == "adventure" and _update_stage_after_move(lines, clear_info["gems"]):
		return true
	if game_mode == "versus":
		# A clear hits the computer; then the computer places one piece on its own board
		if lines > 0:
			versus.player_cleared(lines, combo_count, perfect, clear_info["center"])
		var seq := game_seq
		get_tree().create_timer(0.35).timeout.connect(func():
			if seq == game_seq and not is_game_over:
				versus.cpu_turn())

	if _is_tray_empty():
		_spawn_new_tray()
	else:
		_check_piece_usability_and_game_over()
	return true

func _process_line_clears(lines: int, _cells: int, center_pos: Vector2) -> void:
	SoundManager.play_lines_clear(lines, combo_count)
	
	# Juicy dynamic camera shake based on cleared lines and streak combo
	var base_shake: float = 3.5
	match lines:
		1: base_shake = 4.0
		2: base_shake = 8.0
		3: base_shake = 13.0
		_: base_shake = 19.0
	if combo_count >= 3:
		base_shake += min(combo_count * 2.0, 12.0)
	apply_screen_shake(base_shake, 0.12 + lines * 0.04)
	SettingsManager.vibrate(mini(25 + 15 * lines + 3 * combo_count, 90))
	
	_update_combo_aura()
	
	# (2) Line Clear Base Score: 10 * L^2
	var base_line_score: int = LINE_SCORE_BASE * lines * lines
	
	# (3) Combo Multiplier & Escalating Bonus:
	# Score_total = Score_clear * (1 + alpha * C) + Bonus(C)
	# Quadratic bonus triggers explosive growth when C >= 5..10+
	var combo_mult: float = 1.0 + COMBO_ALPHA * combo_count
	var combo_bonus: int = 0
	if combo_count > 0:
		combo_bonus = int(COMBO_BONUS_LINEAR * combo_count + COMBO_BONUS_QUADRATIC * combo_count * combo_count)
		
	var total_gain: int = int(base_line_score * combo_mult) + combo_bonus
	if combo_count >= FEVER_COMBO:
		total_gain = int(total_gain * FEVER_MULTIPLIER)
	_add_score(total_gain, "combo" if combo_count >= 2 else "clear")
	
	if combo_count >= 1:
		_show_combo_banner(combo_count, combo_grace_moves)
	_spawn_combo_popup(lines, total_gain, center_pos)
	# Shockwave (and a flash for bigger ones) that grows with the combo and the lines cleared
	if combo_count >= 2 or lines >= 2:
		var strength: float = clampf(0.6 + combo_count * 0.2 + (lines - 1) * 0.5, 1.0, 3.0)
		var col: Color = Color(1.0, 0.6, 0.15) if combo_count >= FEVER_COMBO else (UIKit.GOLD if combo_count >= 3 else UIKit.CYAN)
		combo_fx.burst(center_pos, col, strength)
		if combo_count >= 3 or lines >= 3:
			combo_fx.flash(col, 0.1 + 0.02 * mini(combo_count, 6))

func _process_perfect_clear() -> void:
	var gain: int = roundi(PERFECT_CLEAR_BASE * (1.0 + COMBO_ALPHA * combo_count))
	_add_score(gain, "perfect")
	
	SoundManager.play_perfect_clear()
	SettingsManager.vibrate(160)
	apply_screen_shake(24.0, 0.45)
	
	# Whole-board flash
	board.modulate = Color(1.9, 1.8, 1.4)
	var tw = create_tween()
	tw.tween_property(board, "modulate", Color.WHITE, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var board_center: Vector2 = board.to_global(Vector2(Board.BOARD_WIDTH, Board.BOARD_HEIGHT) * 0.5)
	_spawn_floating_text("PERFECT!
+%d" % gain, board_center - Vector2(0, 90), Color(1.0, 0.84, 0.3), 1.75)
	# As in Block Blast, an emptied board moves on to the next theme
	_set_theme(theme_index + 1, true)
	var t: Dictionary = BoardThemes.get_theme(theme_index)
	get_tree().create_timer(0.8).timeout.connect(func():
		_spawn_floating_text("%s 테마" % t["name"], board_center + Vector2(0, 60), t["rim"].lightened(0.35), 0.9))

func _build_theme_backdrop() -> void:
	theme_back = UIKit.backdrop(BoardThemes.backdrop(0))
	$Background.add_child(theme_back)
	theme_front = UIKit.backdrop(BoardThemes.backdrop(0))
	theme_front.modulate.a = 0.0
	$Background.add_child(theme_front)
	board_style = (board_background.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	board_background.add_theme_stylebox_override("panel", board_style)
	_set_theme(0, false)

func _set_theme(index: int, animate: bool) -> void:
	theme_index = posmod(index, BoardThemes.count())
	var t: Dictionary = BoardThemes.get_theme(theme_index)
	if not animate:
		theme_back.texture = BoardThemes.backdrop(theme_index)
		theme_front.modulate.a = 0.0
		board_style.bg_color = t["board"]
		board_style.border_color = t["rim"]
		board.slots_container.modulate = t["slots"]
		return
	# Fade the new backdrop in over the old one, then make it the back layer
	theme_front.texture = BoardThemes.backdrop(theme_index)
	theme_front.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(theme_front, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(board_style, "bg_color", t["board"], 0.9)
	tw.tween_property(board_style, "border_color", t["rim"], 0.9)
	tw.tween_property(board.slots_container, "modulate", t["slots"], 0.9)
	tw.chain().tween_callback(func():
		theme_back.texture = theme_front.texture
		theme_front.modulate.a = 0.0)

func _update_fever() -> void:
	var should_be_on: bool = combo_count >= FEVER_COMBO
	if should_be_on == fever_active:
		return
	fever_active = should_be_on
	if fever_tween:
		fever_tween.kill()
		fever_tween = null
	if fever_active:
		# Warm pulsing board and a one-time announcement
		fever_tween = create_tween().set_loops()
		fever_tween.tween_property(board_background, "modulate", Color(1.5, 1.15, 0.7), 0.45).set_trans(Tween.TRANS_SINE)
		fever_tween.tween_property(board_background, "modulate", Color(1.15, 1.0, 0.85), 0.45).set_trans(Tween.TRANS_SINE)
		var center: Vector2 = board.to_global(Vector2(Board.BOARD_WIDTH, Board.BOARD_HEIGHT) * 0.5)
		# After the clear popup has gone, so the two don't overlap
		get_tree().create_timer(1.3).timeout.connect(func():
			if fever_active:
				_spawn_floating_text("FEVER!\n점수 ×%s" % str(FEVER_MULTIPLIER), center + Vector2(0, 40), Color(1.0, 0.62, 0.2), 1.6))
		SoundManager.play_fever()
		SettingsManager.vibrate(60)
		apply_screen_shake(10.0, 0.25)
		# Embers rise around the board and the screen edge glows while fever lasts
		combo_fx.set_fever(true)
		combo_fx.flash(Color(1.0, 0.55, 0.15), 0.35)
		combo_fx.burst(center, Color(1.0, 0.6, 0.15), 3.0)
	else:
		combo_fx.set_fever(false)
		var tw = create_tween()
		tw.tween_property(board_background, "modulate", Color.WHITE, 0.3)

func _build_combo_banner() -> void:
	# Streak badge above the board: "COMBO ×3" and a 3-segment meter of moves left before it ends
	combo_label.free()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combo_banner.add_child(row)
	combo_caption = UIKit.label("COMBO", 18, UIKit.MUTED)
	combo_caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(combo_caption)
	combo_label = UIKit.label("×2", 30)
	combo_label.add_theme_constant_override("outline_size", 6)
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	combo_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(combo_label)
	var meter := HBoxContainer.new()
	meter.add_theme_constant_override("separation", 4)
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(meter)
	for i in range(MAX_COMBO_GRACE):
		var seg := Panel.new()
		seg.custom_minimum_size = Vector2(18, 8)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meter.add_child(seg)
		combo_pips.append(seg)

func _combo_banner_style(col: Color) -> StyleBoxFlat:
	var sb := UIKit.box(Color(0.04, 0.06, 0.11, 0.88), Color(col, 0.7), 22, 2)
	sb.shadow_color = Color(col, 0.35)
	sb.shadow_size = 10
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	return sb

func _show_combo_banner(c: int, grace: int = 3) -> void:
	if c <= 0:
		_hide_combo_banner()
		return
	combo_banner.visible = true
	var fever: bool = c >= FEVER_COMBO
	var col: Color = Color(1.0, 0.6, 0.15) if fever else (UIKit.GOLD if c >= 3 else UIKit.CYAN)
	combo_caption.text = "FEVER" if fever else "COMBO"
	combo_caption.add_theme_color_override("font_color", col if fever else UIKit.MUTED)
	combo_label.text = "×%d" % c
	combo_label.add_theme_color_override("font_color", col)
	combo_banner.add_theme_stylebox_override("panel", _combo_banner_style(col))
	# Filled segments = moves left to clear another line; the last one turns red
	for i in range(combo_pips.size()):
		var seg_col: Color = Color(1, 1, 1, 0.13)
		if i < grace:
			seg_col = UIKit.DANGER if grace == 1 else col
		combo_pips[i].add_theme_stylebox_override("panel", UIKit.box(seg_col, Color.TRANSPARENT, 4))
	combo_banner.modulate = Color.WHITE
	combo_banner.pivot_offset = combo_banner.size * 0.5
	var tw = create_tween()
	if grace == 1:
		# Last chance: a quick shake-pulse
		tw.tween_property(combo_banner, "scale", Vector2.ONE * 1.12, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(combo_banner, "scale", Vector2.ONE, 0.12)
	else:
		combo_banner.scale = Vector2.ONE * 0.8
		tw.tween_property(combo_banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _hide_combo_banner() -> void:
	if combo_banner.visible:
		var tw = create_tween()
		tw.tween_property(combo_banner, "scale", Vector2.ZERO, 0.15)
		tw.tween_callback(func(): combo_banner.visible = false)

func _update_combo_aura() -> void:
	if combo_count < 3:
		if combo_aura.visible:
			var tw = create_tween()
			tw.tween_property(combo_aura, "modulate:a", 0.0, 0.2)
			tw.tween_callback(func(): combo_aura.visible = false)
	elif combo_count < 5:
		combo_aura.visible = true
		combo_aura.modulate = Color(0.2, 0.85, 1.0, 0.85) # Electric cyan neon
		var tw = create_tween()
		tw.tween_property(combo_aura, "scale", Vector2(1.015, 1.015), 0.1)
		tw.tween_property(combo_aura, "scale", Vector2.ONE, 0.1)
	else:
		combo_aura.visible = true
		combo_aura.modulate = Color(1.0, 0.6, 0.15, 1.0) # Fiery gold flame
		var tw = create_tween()
		tw.tween_property(combo_aura, "scale", Vector2(1.03, 1.03), 0.12)
		tw.tween_property(combo_aura, "scale", Vector2.ONE, 0.12)

# Praise for how big the clear was: more lines at once or a longer streak ranks higher.
# The words are pre-drawn images (assets/sprites/combo/praise_1..5: Good! .. Unbelievable!).
const PRAISE_TINTS: Array = [
	Color(0.45, 0.85, 1.0), Color(0.5, 1.0, 0.6), Color(1.0, 0.85, 0.3),
	Color(1.0, 0.6, 0.25), Color(1.0, 0.5, 0.9),
]

func _spawn_combo_popup(lines: int, gain: int, center_pos: Vector2) -> void:
	var line_tier: int = clampi(lines - 1, 0, 4)      # 2 lines Good, 3 Great, 4 Excellent, 5+ Amazing
	var combo_tier := 0
	for need in [3, 5, 8, 12, 16]:
		if combo_count >= need:
			combo_tier += 1
	var tier: int = maxi(line_tier, combo_tier)
	var tint: Color = Color(0.6, 0.8, 1.0) if tier == 0 else PRAISE_TINTS[tier - 1]
	if combo_count >= FEVER_COMBO:
		tint = Color(1.0, 0.6, 0.2)
	var popup := ComboPopup.new()
	add_child(popup)
	popup.setup(tier, combo_count, gain, tint)
	# Keep the words on the board even when the clear is at an edge
	var margin: float = popup.half_width + 10.0
	var left: float = board.to_global(Vector2.ZERO).x + margin
	var right: float = board.to_global(Vector2(Board.BOARD_WIDTH, 0)).x - margin
	var x: float = board.to_global(Vector2(Board.BOARD_WIDTH * 0.5, 0)).x if left > right else clampf(center_pos.x, left, right)
	popup.position = Vector2(x, center_pos.y)

func _spawn_floating_text(text: String, spawn_pos: Vector2, col: Color, scale_mult: float = 1.0) -> void:
	var ft: FloatingText = floating_text_scene.instantiate()
	ft.position = spawn_pos
	add_child(ft)
	ft.setup(text, col, scale_mult)

func _show_tutorial_hint_later(delay: float) -> void:
	var seq := game_seq
	get_tree().create_timer(delay).timeout.connect(func():
		if seq == game_seq:
			_show_tutorial_hint())

func _show_tutorial_hint() -> void:
	if not tutorial_active or is_game_over or dragging_piece != null or start_screen.visible:
		return
	_dismiss_tutorial_hint()
	# The tray piece and spot that clear the most cells right now
	var grid := board.get_occupancy_snapshot()
	var before := 0
	for v in grid:
		before += 1 if v != 0 else 0
	var best := {}
	var best_cleared := 0
	for piece in tray_pieces:
		if piece == null or not is_instance_valid(piece):
			continue
		var offsets: Array[Vector2i] = BlockData.get_offsets(piece.shape_data)
		var b: Rect2i = BlockData.get_bounds(piece.shape_data["cells"])
		for y in range(Board.GRID_SIZE - b.size.y + 1):
			for x in range(Board.GRID_SIZE - b.size.x + 1):
				var fits := true
				for o in offsets:
					if grid[(x + o.x) + (y + o.y) * Board.GRID_SIZE] != 0:
						fits = false
						break
				if not fits:
					continue
				var after := 0
				for v in BlockData.place_and_clear(grid, offsets, x, y):
					after += 1 if v != 0 else 0
				var cleared: int = before + offsets.size() - after
				if cleared > best_cleared:
					best_cleared = cleared
					best = {"piece": piece, "x": x, "y": y, "size": b.size}
	if best.is_empty():
		return # nothing clears with this set; try again after the next one
	var size: Vector2 = Vector2(best["size"]) * Board.CELL_SPACING - Vector2.ONE * (Board.CELL_SPACING - Board.CELL_SIZE)
	var corner: Vector2 = board.get_cell_position(best["x"], best["y"]) - Vector2.ONE * Board.CELL_SIZE * 0.5
	var target: Vector2 = board.to_global(corner + size * 0.5)
	var text_pos: Vector2 = board.to_global(Vector2(Board.BOARD_WIDTH * 0.5, Board.BOARD_HEIGHT + 34))
	tutorial_hint = TutorialHint.new()
	add_child(tutorial_hint)
	tutorial_hint.setup(best["piece"], target, text_pos)

func _dismiss_tutorial_hint() -> void:
	if tutorial_hint != null and is_instance_valid(tutorial_hint):
		tutorial_hint.dismiss()
	tutorial_hint = null

func _finish_tutorial() -> void:
	tutorial_active = false
	_dismiss_tutorial_hint()
	SettingsManager.set_tutorial("done")

func _is_tray_empty() -> bool:
	for p in tray_pieces:
		if p != null and is_instance_valid(p):
			return false
	return true

func _check_piece_usability_and_game_over() -> void:
	var any_can_fit = false
	var remaining_pieces: int = 0
	
	for p in tray_pieces:
		if p != null and is_instance_valid(p):
			remaining_pieces += 1
			var fits = board.can_fit_shape(p.shape_data)
			p.set_dimmed(not fits)
			if fits:
				any_can_fit = true
				
	if remaining_pieces > 0 and not any_can_fit:
		if game_mode == "adventure":
			_finish_stage(false, "stuck")
		elif game_mode == "versus":
			_finish_versus("player_stuck")
		elif not has_revived_this_game:
			_trigger_revive_chance()
		else:
			_trigger_game_over()

func _trigger_revive_chance() -> void:
	_dismiss_tutorial_hint()
	Analytics.log_event("revive_offer", {
		"game_id": game_id,
		"score": score,
		"fill": snappedf(board.get_fill_ratio(), 0.001)
	})
	apply_screen_shake(6.0, 0.25)
	SoundManager.play("invalid", 1.0, 2.0)
	revive_modal.open()

func _on_revive_accepted() -> void:
	has_revived_this_game = true
	SoundManager.play_revive_bomb()
	SettingsManager.vibrate(100)
	apply_screen_shake(18.0, 0.35)
	
	var cleared = board.execute_revive_bomb()
	play_log.append(["r"] + board.last_revive_cells)
	Analytics.log_event("revive_result", {"game_id": game_id, "accepted": true, "cleared": cleared})
	_spawn_floating_text("SECOND CHANCE!\n+%d CLEARED" % cleared, Vector2(360, 580), Color(0.99, 0.82, 0.25), 1.4)
	_clear_tray()
	_spawn_new_tray()

func _on_revive_declined() -> void:
	Analytics.log_event("revive_result", {"game_id": game_id, "accepted": false, "cleared": 0})
	_trigger_game_over()

func _open_leaderboard() -> void:
	if Toss.active():
		# Toss keeps one leaderboard per game: the classic best score
		Toss.open_leaderboard(func(status: String):
			if status != "OK":
				if start_screen.visible:
					start_screen.flash_ranking_note(Toss.status_text(status))
				else:
					_show_notice(Toss.status_text(status)))
		return
	was_in_start_screen = start_screen.visible
	if was_in_start_screen:
		start_screen.visible = false
	# From a daily game (game over or header), jump straight to today's ranking
	var tab = "daily" if (game_mode == "daily" and not was_in_start_screen) else ""
	leaderboard_modal.open(tab)

func _on_leaderboard_closed() -> void:
	if was_in_start_screen:
		start_screen.visible = true

func _open_settings(tab: String = "") -> void:
	was_in_start_screen = start_screen.visible
	if was_in_start_screen:
		start_screen.visible = false
	settings_modal.open(tab)

func _on_settings_closed() -> void:
	if was_in_start_screen:
		start_screen.visible = true
	board.refresh_skin()
	for p in tray_pieces:
		if p != null and is_instance_valid(p):
			p.refresh_skin()
	_update_home_profile_ui()

func _on_profile_setup_completed() -> void:
	_update_home_profile_ui()
	start_screen.visible = true

func _open_home_screen() -> void:
	_dismiss_tutorial_hint()
	SoundManager.play_click()
	if not start_screen.visible and not is_game_over and not game_id.is_empty():
		# Player left a game in progress
		Analytics.log_event("game_quit", {
			"game_id": game_id,
			"score": score,
			"moves": move_count,
			"duration_s": snappedf((Time.get_ticks_msec() - game_start_msec) / 1000.0, 0.1)
		})
		Analytics.flush()
	_update_home_profile_ui()
	start_screen.visible = true
	game_over_panel.visible = false
	if leaderboard_modal.visible:
		leaderboard_modal.close()
	if settings_modal.visible:
		settings_modal.close()
	if profile_setup_modal.visible:
		profile_setup_modal.close()
	adventure_select.visible = false

func _on_start_play_pressed() -> void:
	start_screen.visible = false
	start_new_game(false, "classic")

func _on_start_daily_pressed() -> void:
	start_screen.visible = false
	start_new_game(false, "daily")

func _update_home_profile_ui() -> void:
	var progress: Dictionary = AdventureData.load_progress()
	var stars := 0
	for v in progress["stars"].values():
		stars += int(v)
	var today_best := _load_daily_best(LeaderboardManager.get_kst_day_key())
	start_screen.refresh({
		"nickname": LeaderboardManager.nickname,
		"sub": "프로필 편집",
		"avatar": LeaderboardManager.get_avatar_texture(),
		"best": best_score,
		"rank": LeaderboardManager.last_known_rank,
		"daily_best": today_best if today_best > 0 else -1,
		"stars": stars,
		"stars_total": AdventureData.stage_count() * 3,
		"next_stage": int(progress["unlocked"]),
		"muted": SoundManager.is_muted
	})
	btn_sound.texture_normal = sound_off_tex if SoundManager.is_muted else sound_on_tex

func _trigger_game_over() -> void:
	_dismiss_tutorial_hint()
	if is_game_over:
		return
	is_game_over = true
	last_game_over_msec = Time.get_ticks_msec()
	
	var remaining_shapes: Array = []
	for p in tray_pieces:
		if p != null and is_instance_valid(p):
			remaining_shapes.append(p.shape_data["id"])
	Analytics.log_event("game_over", {
		"game_id": game_id,
		"score": score,
		"best_score": best_score,
		"new_best": new_best_achieved,
		"duration_s": snappedf((last_game_over_msec - game_start_msec) / 1000.0, 0.1),
		"moves": move_count,
		"max_combo": max_combo,
		"remaining_shapes": remaining_shapes,
		"fill": snappedf(board.get_fill_ratio(), 0.001),
		"revived": has_revived_this_game
	})
	Analytics.flush()
	
	SoundManager.play_gameover()
	SettingsManager.vibrate(120)
	_restore_game_over_texts()

	Achievements.add_stat("games_played", 1)
	if new_best_achieved:
		Achievements.add_stat("new_bests", 1)
	if game_mode == "daily":
		Achievements.record_daily_day(challenge_day)
	else:
		Achievements.max_stat("best_score", best_score)

	# Submit score to leaderboard API
	go_rank_status.text = "실시간 랭킹 등록 중..."
	if Toss.active():
		go_rank_status.text = ""
		if game_mode == "classic" and score > 0:
			go_rank_status.text = "토스 랭킹에 기록 중..."
			Toss.submit_score(score, func(status: String):
				if is_instance_valid(go_rank_status):
					go_rank_status.text = "토스 랭킹에 기록했어요" if status == "SUCCESS" else Toss.status_text(status))
	elif not LeaderboardManager.is_online():
		go_rank_status.text = ""
	elif score > 0:
		LeaderboardManager.submit_score(score, _on_leaderboard_score_submitted, game_mode, challenge_day, play_log)
	else:
		go_rank_status.text = "0점은 랭킹에 등록되지 않습니다."
	
	await get_tree().create_timer(0.65).timeout
	
	go_final_score.text = "%s" % _format_number(score)
	if game_mode == "daily":
		go_best_score.text = _best_line("오늘 BEST", daily_best)
	else:
		go_best_score.text = _best_line("BEST", best_score)
	go_new_badge.visible = new_best_achieved
	
	if new_best_achieved:
		SoundManager.play_record()
	
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(game_over_panel, "modulate:a", 1.0, 0.25)

func _on_achievement_unlocked(def: Dictionary) -> void:
	toast_queue.append(def)
	if not toast_busy:
		_show_next_toast()

func _show_notice(text: String) -> void:
	# Short message near the top of the screen (e.g. why the Toss leaderboard did not open)
	if text.is_empty():
		return
	var panel := PanelContainer.new()
	var sb := UIKit.box(Color(0.08, 0.1, 0.17, 0.97), UIKit.BORDER, 16, 2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.z_index = 300
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(UIKit.label(text, 20, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	# Centered at the top by anchors, so it needs no layout pass before it can be placed
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 128.0
	$UI.add_child(panel)
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)

func _show_next_toast() -> void:
	if toast_queue.is_empty():
		toast_busy = false
		return
	toast_busy = true
	var def: Dictionary = toast_queue.pop_front()

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.2, 0.97)
	sb.border_color = Color(0.99, 0.75, 0.35, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	panel.z_index = 300
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.text = "업적 달성 · %s\n%s" % [def["name"], def["desc"]]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", preload("res://assets/fonts/font.ttf"))
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.99, 0.88, 0.55))
	panel.add_child(label)
	$UI.add_child(panel)

	await get_tree().process_frame
	var w: float = panel.size.x
	panel.position = Vector2((720.0 - w) * 0.5, -120.0)
	SoundManager.play("record", 1.5, -6.0)
	var tw = create_tween()
	tw.tween_property(panel, "position:y", 128.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_property(panel, "position:y", -120.0, 0.25)
	tw.tween_callback(func():
		panel.queue_free()
		_show_next_toast()
	)

func _best_line(label: String, best: int) -> String:
	# "BEST: 12,345" plus how many points this game was short, when it didn't beat the record
	var text := "%s: %s" % [label, _format_number(best)]
	if not new_best_achieved and run_start_best > 0 and score < run_start_best:
		text += "  ·  %s점 부족" % _format_number(run_start_best - score)
	return text

func _restore_game_over_buttons() -> void:
	go_btn_retry.position.y = go_btn_default_y["retry"]
	go_btn_view_rank.position.y = go_btn_default_y["primary"]
	UIKit.style_button(go_btn_retry, "primary", 24, 18)
	UIKit.style_button(go_btn_view_rank, "secondary", 22, 18)

func _restore_game_over_texts() -> void:
	_restore_game_over_buttons()
	$UI/GameOverModal/Card/ScoreSub.text = go_default_texts["score_sub"]
	go_title.text = go_default_texts["title"]
	go_btn_view_rank.text = go_default_texts["primary"]
	go_btn_retry.text = go_default_texts["retry"]
	go_btn_home.text = go_default_texts["secondary"]
	go_new_badge.text = go_default_texts["badge"]
	go_btn_view_rank.visible = _has_ranking()

func _on_go_primary_pressed() -> void:
	if game_mode == "adventure":
		_start_adventure_stage(int(stage["id"]) + 1)
	else:
		_open_leaderboard()

func _on_go_secondary_pressed() -> void:
	if game_mode == "adventure":
		_open_adventure_select()
	else:
		_open_home_screen()

# =========================================================
# Versus mode
# =========================================================

func _start_versus(level: String) -> void:
	versus_level = level
	start_screen.visible = false
	start_new_game(false, "versus")

func _finish_versus(reason: String) -> void:
	# reason: cpu_ko / cpu_stuck (win), player_ko / player_stuck (lose)
	if is_game_over:
		return
	is_game_over = true
	versus.stop()
	last_game_over_msec = Time.get_ticks_msec()
	var won: bool = reason.begins_with("cpu_")
	Achievements.add_stat("games_played", 1)
	Achievements.add_stat(("versus_win_" if won else "versus_loss_") + versus_level, 1)
	Analytics.log_event("versus_result", {
		"game_id": game_id,
		"level": versus_level,
		"result": "win" if won else "lose",
		"reason": reason,
		"damage": versus.dealt[VersusMatch.ME],
		"cpu_damage": versus.dealt[VersusMatch.CPU],
		"moves": move_count,
		"duration_s": snappedf((last_game_over_msec - game_start_msec) / 1000.0, 0.1)
	})
	Analytics.flush()
	if won:
		SoundManager.play_record()
		SettingsManager.vibrate(160)
	else:
		SoundManager.play_gameover()
		SettingsManager.vibrate(120)

	await get_tree().create_timer(0.8).timeout

	_restore_game_over_texts()
	go_title.text = "WIN!" if won else "LOSE"
	$UI/GameOverModal/Card/ScoreSub.text = "준 데미지"
	go_final_score.text = "%d : %d" % [versus.dealt[VersusMatch.ME], versus.dealt[VersusMatch.CPU]]
	go_best_score.text = "나 : 컴퓨터(%s)" % VersusMatch.level_name(versus_level)
	go_new_badge.visible = false
	go_rank_status.text = {
		"cpu_ko": "컴퓨터를 쓰러뜨렸어요!",
		"cpu_stuck": "컴퓨터가 놓을 곳이 없어요!",
		"player_ko": "체력이 바닥났어요.",
		"player_stuck": "놓을 수 있는 블록이 없어요.",
	}.get(reason, "")
	go_btn_view_rank.visible = false
	go_btn_retry.text = "다시 대결"
	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(game_over_panel, "modulate:a", 1.0, 0.25)

# =========================================================
# Adventure mode
# =========================================================

func _open_adventure_select() -> void:
	start_screen.visible = false
	game_over_panel.visible = false
	adventure_select.open()

func _start_adventure_stage(stage_id: int) -> void:
	var next: Dictionary = AdventureData.get_stage(stage_id)
	if next.is_empty():
		_open_adventure_select()
		return
	stage = next
	adventure_select.visible = false
	start_screen.visible = false
	game_over_panel.visible = false
	start_new_game(false, "adventure")

func _update_stage_after_move(lines: int, gems: int) -> bool:
	# Returns true when the stage ended (cleared or out of moves)
	match stage["goal"]["type"]:
		"lines":
			stage_progress += lines
		"gems":
			stage_progress += gems
		"score":
			stage_progress = score
	_update_ui()
	if stage_progress >= int(stage["goal"]["target"]):
		_finish_stage(true, "goal")
		return true
	if int(stage["moves"]) > 0 and move_count >= int(stage["moves"]):
		_finish_stage(false, "moves")
		return true
	return false

func _finish_stage(cleared: bool, reason: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	last_game_over_msec = Time.get_ticks_msec()

	var stars: int = AdventureData.stars_for(stage, move_count) if cleared else 0
	var improved: bool = cleared and AdventureData.record_result(int(stage["id"]), stars)
	Achievements.add_stat("games_played", 1)
	var total_stars := 0
	for v in AdventureData.load_progress()["stars"].values():
		total_stars += int(v)
	Achievements.max_stat("adventure_stars", total_stars)
	Analytics.log_event("stage_result", {
		"game_id": game_id,
		"stage_id": stage["id"],
		"cleared": cleared,
		"stars": stars,
		"moves_used": move_count,
		"score": score,
		"progress": stage_progress,
		"reason": reason
	})
	Analytics.flush()

	if cleared:
		SoundManager.play_record()
		SettingsManager.vibrate(160)
	else:
		SoundManager.play_gameover()
		SettingsManager.vibrate(120)

	await get_tree().create_timer(0.65).timeout

	var goal: Dictionary = stage["goal"]
	var progress: int = score if goal["type"] == "score" else stage_progress
	go_title.text = "STAGE CLEAR!" if cleared else "STAGE FAILED"
	go_final_score.text = _format_number(score)
	go_best_score.text = AdventureData.star_text(stars) if cleared else AdventureData.goal_text(goal, progress)
	go_new_badge.text = "★ 새 기록 ★"
	go_new_badge.visible = improved
	match reason:
		"goal":
			go_rank_status.text = "%s 달성! (%d수)" % [AdventureData.goal_text(goal), move_count]
		"moves":
			go_rank_status.text = "이동 횟수를 모두 사용했습니다."
		_:
			go_rank_status.text = "더 이상 놓을 곳이 없습니다."
	var has_next: bool = not AdventureData.get_stage(int(stage["id"]) + 1).is_empty()
	_restore_game_over_buttons()
	go_btn_view_rank.text = "다음 스테이지"
	go_btn_view_rank.visible = cleared and has_next
	go_btn_retry.text = "다시 도전"
	go_btn_home.text = "스테이지 선택"
	if cleared and has_next:
		# Moving on is the main action after a clear: put "next" on top as the primary button
		go_btn_view_rank.position.y = go_btn_default_y["retry"]
		go_btn_retry.position.y = go_btn_default_y["primary"]
		UIKit.style_button(go_btn_view_rank, "primary", 24, 18)
		UIKit.style_button(go_btn_retry, "secondary", 22, 18)

	game_over_panel.visible = true
	game_over_panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(game_over_panel, "modulate:a", 1.0, 0.25)

func _on_leaderboard_score_submitted(res: Dictionary) -> void:
	if not is_instance_valid(go_rank_status):
		return
	if res.get("success", false):
		var r = int(res.get("rank", -1))
		var is_new = bool(res.get("is_new_best", false))
		var scope = "오늘의 챌린지" if res.get("mode", "") == "daily" else "전체"
		if is_new:
			go_rank_status.text = "★ 최고 기록 경신! %s %d위 달성! ★" % [scope, r]
		else:
			go_rank_status.text = "내 최고 순위: %s %d위" % [scope, r]
	else:
		go_rank_status.text = "실시간 랭킹 확인 가능"

func _add_score(amount: int, kind: String = "place") -> void:
	if game_mode == "versus":
		score += amount # no records in a battle
		return
	score += amount
	if game_mode == "adventure":
		pass # Stage scores never touch classic/daily records
	elif game_mode == "daily":
		if score > daily_best:
			daily_best = score
			_on_record_passed()
			_save_daily_best()
	elif score > best_score:
		best_score = score
		_on_record_passed()
		_save_best_score()
	_update_ui()
	score_counter.roll_to(score, kind)

func _on_record_passed() -> void:
	if new_best_achieved:
		return
	new_best_achieved = true
	if run_start_best <= 0:
		return # first game ever: nothing to beat yet
	var center: Vector2 = board.to_global(Vector2(Board.BOARD_WIDTH * 0.5, 120))
	_spawn_floating_text("NEW BEST!", center, UIKit.GOLD, 1.5)
	SoundManager.play_record()
	SettingsManager.vibrate(80)
	best_label.pivot_offset = best_label.size * 0.5
	best_label.scale = Vector2.ONE * 1.3
	var tw = create_tween()
	tw.tween_property(best_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_score_header() -> void:
	# Block Blast style: the record as a small gold line under the top buttons and the score
	# as big rolling digits in the middle (ScoreCounter). The old boxes become plain layout.
	var empty := StyleBoxEmpty.new()
	var score_box: Panel = $UI/Header/ScoreBox
	var best_box: Panel = $UI/Header/BestBox
	for box in [score_box, best_box]:
		box.add_theme_stylebox_override("panel", empty)
	best_box.position = Vector2(42, 96)
	best_box.size = Vector2(636, 36)
	var row: HBoxContainer = $UI/Header/BestBox/BestHeader
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var crown: TextureRect = $UI/Header/BestBox/BestHeader/CrownIcon
	crown.custom_minimum_size = Vector2(30, 24)
	best_label.reparent(row)
	row.move_child(best_label, 1)
	best_label.custom_minimum_size = Vector2.ZERO
	best_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	best_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bls := LabelSettings.new()
	bls.font = UIKit.FONT
	bls.font_size = 28
	bls.font_color = UIKit.GOLD
	bls.outline_size = 6
	bls.outline_color = Color(0.25, 0.13, 0.0, 0.85)
	best_label.label_settings = bls
	var sls := LabelSettings.new()
	sls.font = UIKit.FONT
	sls.font_size = UIKit.TYPE_SMALL
	sls.font_color = UIKit.MUTED
	best_sub.label_settings = sls
	best_sub.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	score_box.position = Vector2(42, 126)
	score_box.size = Vector2(636, 90)
	for c in score_box.get_children():
		c.visible = false
	score_counter = ScoreCounter.new()
	score_counter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	score_box.add_child(score_counter)

func _update_ui() -> void:
	score_label.text = _format_number(score)
	$UI/Header/BestBox/BestHeader/CrownIcon.visible = game_mode != "adventure"
	if game_mode == "adventure" and not stage.is_empty():
		var progress: int = score if stage["goal"]["type"] == "score" else stage_progress
		best_label.text = AdventureData.goal_text(stage["goal"], progress)
		if int(stage["moves"]) > 0:
			best_sub.text = "목표 · 남은 이동 %d" % maxi(0, int(stage["moves"]) - move_count)
		else:
			best_sub.text = "목표"
	else:
		best_label.text = _format_number(daily_best if game_mode == "daily" else best_score)
		if run_start_best > 0 and score < run_start_best:
			best_sub.text = "신기록까지 %s" % _format_number(run_start_best - score)
		elif run_start_best > 0:
			best_sub.text = "신기록 경신 중!"
		else:
			best_sub.text = "BEST"

func _on_sound_toggled() -> void:
	SoundManager.play_click()
	var muted = SoundManager.toggle_mute()
	SettingsManager.set_sound(not muted)
	btn_sound.texture_normal = sound_off_tex if muted else sound_on_tex
	start_screen.set_muted(muted)

func _load_best_score() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load(SAVE_PATH)
	if err == OK:
		best_score = cfg.get_value("game", "best_score", 0)

func _save_best_score() -> void:
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH) # keep other sections (daily bests)
	cfg.set_value("game", "best_score", best_score)
	cfg.save(SAVE_PATH)

func _load_daily_best(day_key: String) -> int:
	var cfg = ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("daily", day_key, 0))

func _save_daily_best() -> void:
	var cfg = ConfigFile.new()
	cfg.load(SAVE_PATH)
	# Only today's entry matters; drop older days
	if cfg.has_section("daily"):
		for key in cfg.get_section_keys("daily"):
			if key != challenge_day:
				cfg.erase_section_key("daily", key)
	cfg.set_value("daily", challenge_day, daily_best)
	cfg.save(SAVE_PATH)

func _format_number(n: int) -> String:
	var s = str(n)
	var res = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res
