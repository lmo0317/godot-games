extends Node
# Headless test for the battle mode (knight vs wizard): damage sizes, skill tiers, the same start board on both sides, a clear
# taking the computer's HP, the computer placing one piece after each of the player's, nothing
# ever landing on the player's board, and every way a match ends.
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
	_expect(VersusMatch.damage_for(0, 1, false) == 0, "no lines, no damage")
	_expect(VersusMatch.damage_for(1, 1, false) == 10, "one line hits 10")
	_expect(VersusMatch.damage_for(2, 1, false) == 25, "two lines hit 25")
	_expect(VersusMatch.damage_for(1, 4, false) == 28, "combo 4 adds 18")
	_expect(VersusMatch.damage_for(1, 1, true) == 70, "perfect clear adds 60")
	_expect(VersusMatch.skill_tier(1, 1, false) == 0, "one line is the basic skill")
	_expect(VersusMatch.skill_tier(2, 1, false) == 1 and VersusMatch.skill_tier(1, 3, false) == 1, "two lines or combo 3 is the strong skill")
	_expect(VersusMatch.skill_tier(3, 1, false) == 2 and VersusMatch.skill_tier(1, 1, true) == 2, "three lines or a perfect clear is the ultimate")

	main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.profile_setup_modal.visible = false
	SoundManager.is_muted = true
	SettingsManager.tutorial_state = "done"
	var vs: VersusMatch = main.versus

	main._start_versus("normal")
	await _wait_for_tray()
	_expect(vs.visible and not vs.finished, "battle starts")
	_expect(not main.get_node("UI/Header/ScoreBox").visible, "classic score is hidden")
	var player_cells := 0
	for v in main.board.get_occupancy_snapshot():
		player_cells += 1 if v != 0 else 0
	_expect(player_cells == 64 - VersusMatch._free(vs.cpu_grid), "same start board on both sides")

	# A clear hits the computer, and the computer answers with one piece of its own
	main.board.load_layout(["kkkkkkk.", "........", "........", "........", "........", "........", "........", "........"])
	var piece := _any_piece()
	piece.setup(BlockData.SHAPES[0], piece.slot_index, piece.tray_position)
	var cpu_before := vs.cpu_grid.duplicate()
	piece.global_position = main.board.to_global(main.board.get_cell_position(7, 0))
	_expect(main._commit_placement(piece), "player's piece is placed")
	await get_tree().create_timer(1.2).timeout
	_expect(vs.hp[VersusMatch.CPU] < VersusMatch.MAX_HP, "a clear takes the computer's HP (%d)" % vs.hp[VersusMatch.CPU])
	_expect(vs.cpu_grid != cpu_before, "the computer placed a piece after the player's")
	var stones := 0
	for x in range(8):
		for y in range(8):
			stones += 1 if main.board.grid_state[x][y] == "stone" else 0
	_expect(stones == 0, "nothing lands on the player's board")
	_expect(not main.combo_banner.visible, "no combo badge in a battle")

	# Computer KO -> win
	vs.hp[VersusMatch.CPU] = 1
	vs._cast(VersusMatch.ME, 10, 0)
	await _wait_for_result()
	_expect(main.go_title.text == "WIN!", "computer KO shows WIN! (got %s)" % main.go_title.text)
	_expect(vs.finished, "the battle is over")

	# Player KO -> lose
	main._start_versus("easy")
	await _wait_for_tray()
	vs.hp[VersusMatch.ME] = 1
	vs._cast(VersusMatch.CPU, 10, 0)
	await _wait_for_result()
	_expect(main.go_title.text == "LOSE", "player KO shows LOSE (got %s)" % main.go_title.text)

	# Player stuck -> lose
	main._start_versus("easy")
	await _wait_for_tray()
	main.board.load_layout(["kkkkkkk.", "kkkkkk.k", "kkkkk.kk", "kkkk.kkk", "kkk.kkkk", "kk.kkkkk", "k.kkkkkk", ".kkkkkkk"])
	for p in main.tray_pieces:
		if p != null and is_instance_valid(p):
			p.setup(_square(), p.slot_index, p.tray_position)
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

func _square() -> Dictionary:
	for s in BlockData.SHAPES:
		if s["cells"].size() == 4 and BlockData.get_bounds(s["cells"]).size == Vector2i(2, 2):
			return s
	return BlockData.SHAPES[0]

func _wait_for_tray() -> void:
	for i in range(80):
		if not main._is_tray_empty():
			return
		await get_tree().create_timer(0.05).timeout

func _wait_for_result() -> void:
	for i in range(60):
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
