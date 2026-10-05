extends Node
# Headless test for Block Defense: the timed puzzle phase collects points, points turn into
# archers and mages on the wall, the wave covers the board and blocks input, they clear an early wave
# and the puzzle comes back, a stuck board ends the phase early, and a castle with no defenders
# falls and shows the result.
# Run: Godot_console.exe --headless --path . res://tests/test_defense.tscn

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
	var d: DefenseMode = main.defense

	main._start_defense()
	await _wait_until(func(): return d.phase == "puzzle" and not main._is_tray_empty())
	_expect(d.visible and d.hud.visible and not d.field.visible, "puzzle phase shows the HUD over the board")
	_expect(d.wave == 1 and d.castle_hp == DefenseMode.CASTLE_HP, "run starts at wave 1 with a full castle")
	var t0: float = d.time_left
	await get_tree().create_timer(0.5).timeout
	_expect(d.time_left < t0, "the puzzle timer runs")

	# A clear adds points to this phase
	main.board.load_layout(["kkkkkkk.", "........", "........", "........", "........", "........", "........", "........"])
	var piece := _any_piece()
	piece.setup(BlockData.SHAPES[0], piece.slot_index, piece.tray_position)
	piece.global_position = main.board.to_global(main.board.get_cell_position(7, 0))
	main._commit_placement(piece)
	_expect(d.phase_points > 0, "points collected in the phase (%d)" % d.phase_points)

	# Points become defenders when time runs out; the wave covers the board and input is closed
	d.phase_points = DefenseMode.ARCHER_COST * 4 + 5
	d.time_left = 0.01
	await _wait_until(func(): return d.phase == "wave")
	_expect(d.count("archer") == 4 and d.count("mage") == 1, "405 points -> 4 archers, 1 mage (%d, %d)" % [d.count("archer"), d.count("mage")])
	_expect(d.field.visible and not d.hud.visible, "the battlefield covers the screen during the wave")
	var p2 := _any_piece()
	if p2 != null:
		main._on_pointer_down(p2.global_position, -1)
		_expect(main.dragging_piece == null, "pieces cannot be picked up during a wave")

	# With that army wave 1 is held and the puzzle comes back
	d.speed = 4.0
	await _wait_until(func(): return d.phase == "puzzle" or d.phase == "over", 60.0)
	_expect(d.phase == "puzzle" and d.wave == 2, "wave 1 cleared, back to the puzzle at wave 2 (phase %s, wave %d)" % [d.phase, d.wave])
	_expect(not d.field.visible, "board is back after the wave")

	# A stuck board ends the puzzle phase early
	d.board_stuck()
	_expect(d.phase == "wave", "a stuck board starts the wave right away")
	await _wait_until(func(): return d.phase == "puzzle" or d.phase == "over", 60.0)

	# No defenders and a weak wall: it falls and the result shows
	for u in d.units:
		u["node"].queue_free()
	d.units.clear()
	d.castle_hp = 5.0
	d.phase_points = 0
	d.time_left = 0.01
	await _wait_until(func(): return main.game_over_panel.visible, 60.0)
	_expect(main.go_title.text == "GAME OVER", "castle down shows GAME OVER (got %s)" % main.go_title.text)
	_expect(main.go_final_score.text == str(d.wave - 1), "result shows the waves held (%s)" % main.go_final_score.text)
	_finish()

func _any_piece() -> BlockPiece:
	for p in main.tray_pieces:
		if p != null and is_instance_valid(p):
			return p
	return null

func _wait_until(cond: Callable, limit: float = 8.0) -> void:
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
		print("DEFENSE OK")
	else:
		for f in failures:
			printerr("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
