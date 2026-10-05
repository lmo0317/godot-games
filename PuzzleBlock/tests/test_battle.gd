extends Node
# Headless test for Monster Battle: the compact layout (board and tray at 85%), a clear hurting
# the monster, the attack countdown hurting the player, the next stage after a kill, the end when
# the player's HP runs out, and the normal layout coming back for classic.
# Run: Godot_console.exe --headless --path . res://tests/test_battle.tscn

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
	SoundManager.is_muted = true
	SettingsManager.tutorial_state = "done"
	var b: MonsterBattle = main.battle

	main._start_battle()
	await _wait_until(func(): return not main._is_tray_empty() and not b.finished)
	_expect(b.visible and b.stage == 1 and b.hp == MonsterBattle.PLAYER_HP, "battle starts at stage 1 with full HP")
	_expect(is_equal_approx(main.board.scale.x, MainGame.COMPACT_SCALE), "board is shrunk in the battle")
	_expect(is_equal_approx(BlockPiece.board_scale, MainGame.COMPACT_SCALE), "held pieces match the board scale")
	_expect(main.tray_slots[0].y > MainGame.TRAY_SLOTS[0].y, "tray moved down")

	# A clear hits the monster
	var hp0: float = b.m_hp
	_place_dot_clearing_row()
	await get_tree().create_timer(0.3).timeout
	_expect(b.m_hp < hp0, "a clear hurts the monster (%.0f -> %.0f)" % [hp0, b.m_hp])

	# The countdown runs out: the monster hits the player
	b.countdown = 1
	var php: int = b.hp
	_place_dot_no_clear()
	await get_tree().create_timer(0.8).timeout
	_expect(b.hp < php, "the monster attacks when its countdown ends (%d -> %d)" % [php, b.hp])
	_expect(b.countdown == b.monster["every"], "countdown resets after the attack")

	# Finishing the monster moves to the next stage
	b.m_hp = 1.0
	_place_dot_clearing_row()
	await _wait_until(func(): return b.stage == 2 and not b.switching, 4.0)
	_expect(b.stage == 2, "beating the monster moves to stage 2")

	# Out of HP: the run ends with the result window
	b.hp = 1
	b.countdown = 1
	_place_dot_no_clear()
	await _wait_until(func(): return main.game_over_panel.visible, 5.0)
	_expect(main.go_title.text == "GAME OVER" and main.go_final_score.text == "STAGE 2", "result shows the stage (%s / %s)" % [main.go_title.text, main.go_final_score.text])

	# Classic gets the normal layout back
	main.game_over_panel.visible = false
	main._on_start_play_pressed()
	await _wait_until(func(): return not main._is_tray_empty())
	_expect(is_equal_approx(main.board.scale.x, 1.0) and not b.visible, "classic uses the normal layout")
	_expect(main.tray_slots[0] == MainGame.TRAY_SLOTS[0], "tray back in place")
	_finish()

func _any_piece() -> BlockPiece:
	for p in main.tray_pieces:
		if p != null and is_instance_valid(p):
			return p
	main._spawn_new_tray()
	return main.tray_pieces[0]

func _place_dot_at(x: int, y: int) -> void:
	var piece := _any_piece()
	piece.setup(BlockData.SHAPES[0], piece.slot_index, piece.tray_position)
	piece.global_position = main.board.to_global(main.board.get_cell_position(x, y))
	_expect(main._commit_placement(piece), "piece placed at %d,%d" % [x, y])

func _place_dot_clearing_row() -> void:
	main.board.load_layout(["kkkkkkk.", "........", "........", "........", "........", "........", "........", "........"])
	_place_dot_at(7, 0)

func _place_dot_no_clear() -> void:
	main.board.load_layout(["........", "........", "........", "........", "........", "........", "........", "........"])
	_place_dot_at(3, 3)

func _wait_until(cond: Callable, limit: float = 6.0) -> void:
	var t := 0.0
	while t < limit and not cond.call():
		await get_tree().create_timer(0.05).timeout
		t += 0.05

func _expect(cond: bool, msg: String) -> void:
	if not cond and not failures.has(msg):
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
		print("BATTLE OK")
	else:
		for f in failures:
			printerr("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
