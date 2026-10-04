extends Node
# Versus balance benchmark: the computer at each level plays MATCHES matches against a stand-in
# player using the "normal" move choice, on the real tray generator, with main.gd's scoring
# (own combo per side, fever multiplier, perfect clear). Reports the computer's win rate and how
# matches end. No rendering.
# Run: Godot_console.exe --headless --path . res://tests/bench_versus.tscn

const BoardScene: PackedScene = preload("res://scenes/board.tscn")
var MATCHES: int = int(OS.get_environment("BENCH_GAMES")) if not OS.get_environment("BENCH_GAMES").is_empty() else 200

var board: Board

# Stand-in for BlockPiece in VersusMatch.choose_move (it reads shape_data only)
class FakePiece:
	var shape_data: Dictionary
	func _init(s: Dictionary) -> void:
		shape_data = s

func _ready() -> void:
	board = BoardScene.instantiate()
	add_child(board)
	_run.call_deferred()

func _run() -> void:
	var player := VersusMatch.new()
	# BENCH_PLAYER=hard pits each level against a stand-in that plays like the hard computer
	player.level = OS.get_environment("BENCH_PLAYER") if not OS.get_environment("BENCH_PLAYER").is_empty() else "normal"
	var cpu := VersusMatch.new()
	add_child(player)
	add_child(cpu)
	# BENCH_LEVELS=hard (comma separated) measures only those levels
	var levels: Array = OS.get_environment("BENCH_LEVELS").split(",") if not OS.get_environment("BENCH_LEVELS").is_empty() else ["easy", "normal", "hard"]
	for level in levels:
		cpu.level = level
		var res := {"cpu": 0, "player": 0, "draw": 0, "stuck": 0, "margin": 0}
		for m in range(MATCHES):
			BlockData.get_default_rng().seed = 7000 + m
			player.rng.seed = 100 + m
			cpu.rng.seed = 900 + m
			var r: Dictionary = _match([player, cpu], m % 2)
			res[r["winner"]] += 1
			if r["stuck"]:
				res["stuck"] += 1
			res["margin"] += absi(r["scores"][0] - r["scores"][1])
		print("BENCH_VS (player %s) %s: computer wins %d%%, player %d%%, draw %d%% | ended by stuck %d%% | avg margin %d" % [
			player.level, level, 100 * res["cpu"] / MATCHES, 100 * res["player"] / MATCHES, 100 * res["draw"] / MATCHES,
			100 * res["stuck"] / MATCHES, res["margin"] / MATCHES])
	get_tree().quit()

# sides[0] = player, sides[1] = computer; first = who moves first
func _match(sides: Array, first: int) -> Dictionary:
	var grid := PackedByteArray()
	grid.resize(64)
	for p in BlockData.generate_start_pattern():
		for o in BlockData.get_offsets(p["shape"]):
			grid[(p["x"] + o.x) + (p["y"] + o.y) * 8] = 1
	var scores := [0, 0]
	var combos := [0, 0]
	var graces := [0, 0]
	var left := [VersusMatch.TURNS, VersusMatch.TURNS]
	var turn: int = first
	var tray: Array = []
	var first_deal := true
	while left[0] > 0 or left[1] > 0:
		if tray.all(func(p): return p == null):
			_sync(grid)
			tray = BlockData.get_adaptive_trio(board, 0, 0, 3, null, MainGame.VERSUS_PRESSURE, first_deal).map(func(s): return FakePiece.new(s))
			first_deal = false
		var st := {"scores": scores.duplicate(), "combos": combos.duplicate(), "graces": graces.duplicate(), "left": left.duplicate(), "turn": turn}
		var move: Dictionary = sides[turn].choose_move(grid, tray, st)
		if move.is_empty():
			return {"winner": "player" if turn == 1 else "cpu", "stuck": true, "scores": scores}
		var shape: Dictionary = tray[move["slot"]].shape_data
		tray[move["slot"]] = null
		var offsets: Array[Vector2i] = BlockData.get_offsets(shape)
		var before := _count(grid)
		grid = BlockData.place_and_clear(grid, offsets, move["x"], move["y"])
		scores[turn] += offsets.size()
		var lines: int = VersusMatch._lines_for(before + offsets.size() - _count(grid))
		if lines > 0:
			combos[turn] += 1
			graces[turn] = MainGame.MAX_COMBO_GRACE
			var c: int = combos[turn]
			var gain: int = int(MainGame.LINE_SCORE_BASE * lines * lines * (1.0 + MainGame.COMBO_ALPHA * c)) \
				+ int(MainGame.COMBO_BONUS_LINEAR * c + MainGame.COMBO_BONUS_QUADRATIC * c * c)
			if c >= MainGame.FEVER_COMBO:
				gain = int(gain * MainGame.FEVER_MULTIPLIER)
			scores[turn] += gain
			if _count(grid) == 0:
				scores[turn] += roundi(MainGame.PERFECT_CLEAR_BASE * (1.0 + MainGame.COMBO_ALPHA * c))
		elif combos[turn] > 0:
			graces[turn] -= 1
			if graces[turn] <= 0:
				combos[turn] = 0
		left[turn] -= 1
		turn = 1 - turn
	var w := "draw"
	if scores[0] != scores[1]:
		w = "player" if scores[0] > scores[1] else "cpu"
	return {"winner": w, "stuck": false, "scores": scores}

func _sync(grid: PackedByteArray) -> void:
	for x in range(8):
		for y in range(8):
			board.grid_state[x][y] = "blue" if grid[x + y * 8] != 0 else null

func _count(grid: PackedByteArray) -> int:
	var n := 0
	for v in grid:
		if v != 0:
			n += 1
	return n
