extends Node
# Headless test for the versus mode: plays whole matches at each level with a simple player
# (the "normal" move choice) and checks turns alternate, the tray is locked on the computer's
# turn, each side's points go to that side, and every match ends with a result window.
# Also reports the player's win rate per level and how long the computer takes to choose.
# Run: Godot_console.exe --headless --path . res://tests/test_versus.tscn

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const USER_FILES: Array[String] = [
	"user://game_settings.json",
	"user://block_blast_save.cfg",
	"user://achievements.json",
]
const MATCHES: int = 4

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
	Engine.time_scale = 4.0
	var me_ai := VersusMatch.new() # used only for its move choice, as the player
	me_ai.level = "normal"
	add_child(me_ai)
	for level in ["easy", "normal", "hard"]:
		var wins := 0
		var think_max := 0
		for m in range(MATCHES):
			main._start_versus(level)
			var r: Dictionary = await _play_match(me_ai)
			think_max = maxi(think_max, r["think_us"])
			if r["result"] == "win":
				wins += 1
		print("VERSUS %s: player won %d/%d, slowest computer choice %.1f ms" % [level, wins, MATCHES, think_max / 1000.0])
	Engine.time_scale = 1.0
	_finish()

func _play_match(me_ai: VersusMatch) -> Dictionary:
	var vs: VersusMatch = main.versus
	_expect(main.game_mode == "versus" and vs.visible, "versus header shows")
	_expect(not main.get_node("UI/Header/ScoreBox").visible, "classic score is hidden in versus")
	var think_us := 0
	var last_turn := -1
	var cpu_moves := 0
	for step in range(400):
		if main.is_game_over:
			break
		await get_tree().create_timer(0.1).timeout
		if main.is_game_over or main._is_tray_empty():
			continue
		if not vs.is_my_turn():
			# Tray is locked for the player on the computer's turn
			var any: BlockPiece = null
			for p in main.tray_pieces:
				if p != null and is_instance_valid(p):
					any = p
			if any != null:
				main._on_pointer_down(any.global_position, -1)
				_expect(main.dragging_piece == null, "cannot grab a piece on the computer's turn")
			if last_turn != VersusMatch.CPU:
				var t0 := Time.get_ticks_usec()
				vs.choose_move(main.board.get_occupancy_snapshot(), main.tray_pieces)
				think_us = maxi(think_us, Time.get_ticks_usec() - t0)
				cpu_moves += 1
			last_turn = VersusMatch.CPU
			continue
		last_turn = VersusMatch.ME
		var move: Dictionary = me_ai.choose_move(main.board.get_occupancy_snapshot(), main.tray_pieces)
		if move.is_empty():
			continue # the turn start will end the match
		var piece: BlockPiece = main.tray_pieces[move["slot"]]
		var before: int = vs.scores[VersusMatch.CPU]
		var b: Rect2i = BlockData.get_bounds(piece.shape_data["cells"])
		var half: Vector2 = Vector2(b.size) * Board.CELL_SPACING * 0.5 - Vector2.ONE * Board.CELL_GAP * 0.5
		piece.global_position = main.board.to_global(Vector2(move["x"], move["y"]) * Board.CELL_SPACING + half)
		var ok: bool = main._commit_placement(piece)
		_expect(ok, "player's move is placed")
		_expect(vs.scores[VersusMatch.CPU] == before, "player's points never go to the computer")
	for i in range(30):
		if main.game_over_panel.visible:
			break
		await get_tree().create_timer(0.1).timeout
	_expect(main.is_game_over, "match ends")
	_expect(main.game_over_panel.visible, "result window shows")
	_expect(cpu_moves > 0, "the computer moved")
	var used: int = 2 * VersusMatch.TURNS - vs.moves_left[0] - vs.moves_left[1]
	_expect(used <= 2 * VersusMatch.TURNS, "no more than %d moves" % (2 * VersusMatch.TURNS))
	_expect(absi(vs.moves_left[0] - vs.moves_left[1]) <= 1, "turns alternate (left %s)" % str(vs.moves_left))
	var title: String = main.go_title.text
	_expect(title in ["WIN!", "LOSE", "DRAW"], "result title: %s" % title)
	main.game_over_panel.visible = false
	return {"result": "win" if title == "WIN!" else "other", "think_us": think_us, "moves": used}

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
