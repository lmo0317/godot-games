extends Node
# Headless test for the attack battle: attack sizes, cancelling, stones never completing a line,
# stones falling on the player's board after a piece without a clear, the computer playing its
# own board in real time and pausing under a panel, and both ways a match ends.
# Run: Godot_console.exe --headless --path . res://tests/test_versus.tscn

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
	# Attack sizes
	_expect(VersusMatch.attack_for(0, 1, false) == 0, "no lines, no attack")
	_expect(VersusMatch.attack_for(1, 1, false) == 1, "one line attacks 1")
	_expect(VersusMatch.attack_for(2, 1, false) == 3, "two lines attack 3")
	_expect(VersusMatch.attack_for(1, 4, false) == 4, "combo 4 adds 3")
	_expect(VersusMatch.attack_for(1, 1, true) == 7, "perfect clear adds 6")

	# Stones never complete a row or column, even on a nearly full board
	var r := RandomNumberGenerator.new()
	r.seed = 3
	var g := PackedByteArray()
	g.resize(64)
	for i in range(64):
		g[i] = 1 if (i % 8) < 6 and (i / 8) < 6 else 0
	var after := VersusMatch.drop_stones(g, 20, r)
	for y in range(8):
		var full := true
		for x in range(8):
			full = full and after[x + y * 8] != 0
		_expect(not full, "stones never fill a row")
	for x in range(8):
		var full := true
		for y in range(8):
			full = full and after[x + y * 8] != 0
		_expect(not full, "stones never fill a column")

	main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.profile_setup_modal.visible = false
	SoundManager.is_muted = true
	SettingsManager.tutorial_state = "done"
	var vs: VersusMatch = main.versus

	main._start_versus("hard")
	await _wait_for_tray()
	_expect(vs.visible and vs.running, "battle starts with the computer running")
	_expect(not main.get_node("UI/Header/ScoreBox").visible, "classic score is hidden")
	var player_cells := 0
	for v in main.board.get_occupancy_snapshot():
		player_cells += 1 if v != 0 else 0
	var cpu_cells := 64 - VersusMatch._free(vs.cpu_grid)
	_expect(player_cells == cpu_cells, "same start board on both sides (%d vs %d)" % [player_cells, cpu_cells])

	# The computer plays on its own
	var before := vs.cpu_grid.duplicate()
	await get_tree().create_timer(3.5).timeout
	_expect(vs.cpu_grid != before, "the computer placed pieces on its board")

	# Pauses under a panel
	main._open_settings()
	await get_tree().create_timer(0.1).timeout
	_expect(vs.paused, "the computer pauses while settings are open")
	main.settings_modal.close()
	await get_tree().create_timer(0.4).timeout
	_expect(not vs.paused, "and goes on after")

	# Cancelling: an attack first eats what waits for the attacker
	vs.incoming[VersusMatch.ME] = 5
	vs.player_cleared(2, 1, false, Vector2(360, 600))
	_expect(vs.incoming[VersusMatch.ME] == 2, "a 3-attack cancels 3 of 5 waiting (left %d)" % vs.incoming[VersusMatch.ME])

	# Waiting stones fall on the player's board after a piece that clears nothing
	main.board.reset_board()
	vs.incoming[VersusMatch.ME] = 3
	var piece := _any_piece()
	var dot: Dictionary = BlockData.SHAPES[0]
	piece.setup(dot, piece.slot_index, piece.tray_position)
	piece.global_position = main.board.to_global(Vector2(Board.CELL_SIZE, Board.CELL_SIZE) * 0.5)
	main._commit_placement(piece)
	var stones := 0
	for x in range(8):
		for y in range(8):
			stones += 1 if main.board.grid_state[x][y] == "stone" else 0
	_expect(stones == 3, "3 stones fell on the player's board (got %d)" % stones)
	_expect(vs.incoming[VersusMatch.ME] == 0, "waiting attack is used up")

	# Computer stuck -> win
	vs.cpu_lost.emit()
	await _wait_for_result()
	_expect(main.go_title.text == "WIN!", "computer stuck shows WIN! (got %s)" % main.go_title.text)
	_expect(not vs.running, "the computer stops after the match")

	# Player stuck -> lose
	main._start_versus("easy")
	await _wait_for_tray()
	main.board.load_layout(["kkkkkkk.", "kkkkkk.k", "kkkkk.kk", "kkkk.kkk", "kkk.kkkk", "kk.kkkkk", "k.kkkkkk", ".kkkkkkk"])
	for p in main.tray_pieces:
		if p != null and is_instance_valid(p):
			p.setup(_shape_of_size(4), p.slot_index, p.tray_position)
	main._check_piece_usability_and_game_over()
	await _wait_for_result()
	_expect(main.go_title.text == "LOSE", "player stuck shows LOSE (got %s)" % main.go_title.text)
	_finish()

func _any_piece() -> BlockPiece:
	for p in main.tray_pieces:
		if p != null and is_instance_valid(p):
			return p
	main._spawn_new_tray()
	return main.tray_pieces[0]

func _shape_of_size(n: int) -> Dictionary:
	for s in BlockData.SHAPES:
		if s["cells"].size() == n and BlockData.get_bounds(s["cells"]).size == Vector2i(2, 2):
			return s
	return BlockData.SHAPES[0]

func _wait_for_tray() -> void:
	for i in range(80):
		if not main._is_tray_empty() and main.versus.running:
			return
		await get_tree().create_timer(0.05).timeout

func _wait_for_result() -> void:
	for i in range(40):
		if main.game_over_panel.visible:
			return
		await get_tree().create_timer(0.05).timeout

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
		print("VERSUS OK")
	else:
		for f in failures:
			printerr("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
