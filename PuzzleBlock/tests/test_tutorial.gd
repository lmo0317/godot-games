extends Node
# Headless test for the first-game hint: it shows for a first-time player, points at a move that
# clears a line, goes away when a piece is grabbed, and is finished by that clear. Players who have
# seen it (or already played) don't get it.
# Run: Godot_console.exe --headless --path . res://tests/test_tutorial.tscn

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const USER_FILES: Array[String] = [
	"user://game_settings.json",
	"user://block_blast_save.cfg",
	"user://achievements.json",
]

var backups: Dictionary = {}
var failures: Array[String] = []
var main: MainGame

func _ready() -> void:
	Analytics.enabled = false
	for p in USER_FILES:
		if FileAccess.file_exists(p):
			backups[p] = FileAccess.get_file_as_bytes(p)
	_run.call_deferred()

func _run() -> void:
	main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.profile_setup_modal.visible = false

	# First-time player
	SettingsManager.tutorial_state = "pending"
	main._on_start_play_pressed()
	await _wait_for_hint()
	var hint: TutorialHint = main.tutorial_hint
	_expect(hint != null and is_instance_valid(hint), "hint shows in the first classic game")
	if hint != null and is_instance_valid(hint):
		var piece: BlockPiece = hint.piece
		var target: Vector2 = hint.target
		var p: Dictionary = main.board.find_placement(piece.shape_data, target)
		_expect(p["valid"], "hint target is a valid spot")
		main._on_pointer_down(piece.global_position, -1)
		_expect(main.tutorial_hint == null, "grabbing a piece hides the hint")
		var screen: Vector2 = target - Vector2(0, BlockPiece.DRAG_OFFSET_Y)
		main._on_pointer_move(screen)
		main._on_pointer_up(screen, -1)
		await get_tree().process_frame
		_expect(main.combo_count >= 1, "the hinted move clears a line")
		_expect(not main.tutorial_active, "a clear finishes the hint")
		_expect(SettingsManager.tutorial_state == "done", "finished hint is saved as done (got '%s')" % SettingsManager.tutorial_state)

	# Seen it already
	main.start_new_game(false, "classic")
	await get_tree().create_timer(2.0).timeout
	_expect(main.tutorial_hint == null and not main.tutorial_active, "no hint once it is done")

	# Older save without the key, but games already played
	SettingsManager.tutorial_state = ""
	Achievements.add_stat("games_played", 1)
	main.start_new_game(false, "classic")
	await get_tree().create_timer(2.0).timeout
	_expect(not main.tutorial_active, "no hint for players who already played")

	# Daily challenge never shows it
	SettingsManager.tutorial_state = "pending"
	main.start_new_game(false, "daily")
	await get_tree().create_timer(1.0).timeout
	_expect(not main.tutorial_active, "no hint in the daily challenge")
	_finish()

func _wait_for_hint() -> void:
	for i in range(80):
		if main.tutorial_hint != null and is_instance_valid(main.tutorial_hint):
			return
		await get_tree().create_timer(0.05).timeout

func _expect(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func _finish() -> void:
	for p in USER_FILES:
		if backups.has(p):
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(backups[p])
			f.close()
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if failures.is_empty():
		print("TUTORIAL OK")
	else:
		for f in failures:
			printerr("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
