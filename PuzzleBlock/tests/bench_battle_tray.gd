extends Node
# 블록 기사단 puzzle benchmark: a bot plays the first PIECES pieces of a stage against the battle's
# piece generator and reports how often a dealt set can clear a line right away, lines per piece,
# multi-line clears and how often the board locks up. Compares the old generator (adaptive, light
# pressure) with the helpful one (perfect / fun sets every deal).
# Run: Godot_console.exe --headless --path . res://tests/bench_battle_tray.tscn
#   BENCH_GEN=old|fun (default both), BENCH_SNUG=3 careful bot / 0 beginner, BENCH_GAMES=n

const BoardScene: PackedScene = preload("res://scenes/board.tscn")
const PIECES: int = 60
var GAMES: int = int(OS.get_environment("BENCH_GAMES")) if not OS.get_environment("BENCH_GAMES").is_empty() else 80
var snug_weight: float = float(OS.get_environment("BENCH_SNUG")) if not OS.get_environment("BENCH_SNUG").is_empty() else 3.0
var board: Board
var bot_rng := RandomNumberGenerator.new()

func _ready() -> void:
	board = BoardScene.instantiate()
	add_child(board)
	_run.call_deferred()

func _run() -> void:
	var gens: Array = ["old", "fun"] if OS.get_environment("BENCH_GEN").is_empty() else [OS.get_environment("BENCH_GEN")]
	for gen in gens:
		var t := {"pieces": 0, "clears": 0, "lines": 0, "multi": 0, "deals": 0, "ready": 0, "stuck": 0, "us": 0, "possible": 0, "hit": 0}
		for g in range(GAMES):
			_game(gen, t)
		print("%s snug=%.0f: needed piece dealt %d%% (when one exists), clear-ready sets %d%%, lines/piece %.2f, clears/piece %.2f, multi %d%% of clears, stuck %d%% of games, %.1f ms/deal" % [
			gen, snug_weight, 100 * t["hit"] / maxi(1, t["possible"]), 100 * t["ready"] / maxi(1, t["deals"]), float(t["lines"]) / t["pieces"], float(t["clears"]) / t["pieces"],
			100 * t["multi"] / maxi(1, t["clears"]), 100 * t["stuck"] / GAMES, t["us"] / 1000.0 / maxi(1, t["deals"])])
	get_tree().quit()

func _game(gen: String, t: Dictionary) -> void:
	var grid := PackedByteArray()
	grid.resize(64)
	for p in BlockData.generate_start_pattern():
		for o in BlockData.get_offsets(p["shape"]):
			grid[(p["x"] + o.x) + (p["y"] + o.y) * 8] = 1
	var combo := 0
	var grace := 0
	var pieces := 0
	var first := true
	while pieces < PIECES:
		_sync(grid)
		var t0 := Time.get_ticks_usec()
		var tray: Array = MainGame.battle_trio(board, combo, 0, grace, first) if gen == "fun" else BlockData.get_adaptive_trio(board, combo, 0, grace, null, 0.3, first)
		t["us"] += Time.get_ticks_usec() - t0
		first = false
		t["deals"] += 1
		var ready: bool = not board.find_clearing_shapes(tray).is_empty()
		if ready:
			t["ready"] += 1
		if not board.find_clearing_shapes(BlockData.SHAPES.filter(func(sh): return sh["id"] != "dot_1x1")).is_empty():
			t["possible"] += 1
			if ready:
				t["hit"] += 1
		tray = tray.duplicate()
		while not tray.is_empty():
			var best := _best_move(grid, tray)
			if best.is_empty():
				t["stuck"] += 1
				return
			var shape: Dictionary = tray[best["i"]]
			tray.remove_at(best["i"])
			var offsets: Array[Vector2i] = BlockData.get_offsets(shape)
			var before := _count(grid)
			grid = BlockData.place_and_clear(grid, offsets, best["x"], best["y"])
			pieces += 1
			t["pieces"] += 1
			var lines := _lines_for(before + offsets.size() - _count(grid))
			if lines > 0:
				t["clears"] += 1
				t["lines"] += lines
				if lines >= 2:
					t["multi"] += 1
				combo += 1
				grace = MainGame.MAX_COMBO_GRACE
			elif combo > 0:
				grace -= 1
				if grace <= 0:
					combo = 0
			_sync(grid)

func _best_move(grid: PackedByteArray, tray: Array) -> Dictionary:
	var before := _count(grid)
	var best := {}
	var best_s := -1.0
	for i in range(tray.size()):
		var offsets: Array[Vector2i] = BlockData.get_offsets(tray[i])
		var b: Rect2i = BlockData.get_bounds(tray[i]["cells"])
		for y in range(8 - b.size.y + 1):
			for x in range(8 - b.size.x + 1):
				if not BlockData._fits_at(grid, offsets, x, y):
					continue
				var after := _count(BlockData.place_and_clear(grid, offsets, x, y))
				var s: float = (before + offsets.size() - after) * 10.0 + BlockData._snugness(grid, offsets, x, y) * snug_weight + bot_rng.randf()
				if s > best_s:
					best_s = s
					best = {"i": i, "x": x, "y": y}
	return best

func _lines_for(cleared: int) -> int:
	if cleared <= 0:
		return 0
	for rows in range(0, 9):
		for cols in range(0, 9):
			if rows + cols > 0 and rows * 8 + cols * 8 - rows * cols == cleared:
				return rows + cols
	return int(ceil(cleared / 8.0))

func _count(grid: PackedByteArray) -> int:
	var n := 0
	for v in grid:
		n += v
	return n

func _sync(grid: PackedByteArray) -> void:
	for x in range(8):
		for y in range(8):
			board.grid_state[x][y] = "blue" if grid[x + y * 8] != 0 else null
