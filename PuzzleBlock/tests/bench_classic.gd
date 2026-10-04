extends Node
# Classic-mode balance benchmark: a greedy bot plays GAMES games against the real piece generator
# (no rendering) and reports game length, score, max combo and time spent in the crisis zone.
# Scoring mirrors main.gd (placement, line clears, combo grace, perfect clear, fever).
# Run: Godot_console.exe --headless --path . res://tests/bench_classic.tscn

const BoardScene: PackedScene = preload("res://scenes/board.tscn")

# Perfect-clear chance (BlockData.get_perfect_trio): searches run, time, and sets dealt
var perfect_searches := 0
var perfect_search_total := 0
var perfect_search_max := 0
var perfect_deals := 0
var GAMES: int = int(OS.get_environment("BENCH_GAMES")) if not OS.get_environment("BENCH_GAMES").is_empty() else 200
const MAX_MOVES: int = 1500

var board: Board
var bot_rng := RandomNumberGenerator.new()
# BENCH_NO_PRESSURE=1 measures the game without the difficulty curve (baseline)
var use_pressure: bool = OS.get_environment("BENCH_NO_PRESSURE").is_empty()
# BENCH_EMPTY_START=1 starts from an empty board instead of the classic start pattern
var use_start: bool = OS.get_environment("BENCH_EMPTY_START").is_empty()
# BENCH_SNUG=<weight> sets how much the bot likes snug fits: 3 (default) = careful bot that
# stacks pieces neatly like a practised player, 0 = greedy bot that only chases clears (beginner)
var snug_weight: float = float(OS.get_environment("BENCH_SNUG")) if not OS.get_environment("BENCH_SNUG").is_empty() else 3.0
# BENCH_GAMES=<n> plays fewer or more games
# BENCH_NO_FUN=1 deals opening sets with the plain generator instead of get_fun_trio
var use_fun: bool = OS.get_environment("BENCH_NO_FUN").is_empty()
const EARLY_MOVES: int = 15
var early := {"clears": 0, "multi": 0, "snug": 0, "chains": 0, "deal_us": 0, "deals": 0}
# Opening window for combo and perfect-clear feel (8 sets). The bot reads the whole tray like a
# person for this many sets, whatever the generator does, so versions compare fairly.
const OPENING_MOVES: int = 24
const PLAN_DEALS: int = 8
var opening := {"combo_moves": 0, "perfects": 0, "games_perfect": 0, "breaks": 0}
var opening_combos: Array[int] = []

func _ready() -> void:
	board = BoardScene.instantiate()
	add_child(board)
	_run.call_deferred()

func _run() -> void:
	var moves: Array[int] = []
	var scores: Array[int] = []
	var combos: Array[int] = []
	var crisis_moves := 0
	var tense_moves := 0
	var total_moves := 0
	var fever_clears := 0
	var perfects := 0
	var games_with_perfect := 0
	var capped := 0
	var first_clears: Array[int] = []
	for g in range(GAMES):
		BlockData.get_default_rng().seed = 5000 + g
		bot_rng.seed = 9000 + g
		var r := _play_game()
		moves.append(r["moves"])
		scores.append(r["score"])
		combos.append(r["max_combo"])
		crisis_moves += r["crisis"]
		tense_moves += r["tense"]
		total_moves += r["moves"]
		fever_clears += r["fever_clears"]
		perfects += r["perfects"]
		if r["perfects"] > 0:
			games_with_perfect += 1
		first_clears.append(r["first_clear"])
		if r["moves"] >= MAX_MOVES:
			capped += 1
	moves.sort()
	scores.sort()
	combos.sort()
	print("BENCH games=%d capped=%d snug=%.1f" % [GAMES, capped, snug_weight])
	print("BENCH moves  p25=%d median=%d p75=%d" % [_pct(moves, 25), _pct(moves, 50), _pct(moves, 75)])
	print("BENCH score  p25=%d median=%d p75=%d p90=%d" % [_pct(scores, 25), _pct(scores, 50), _pct(scores, 75), _pct(scores, 90)])
	print("BENCH combo  median=%d p90=%d" % [_pct(combos, 50), _pct(combos, 90)])
	first_clears.sort()
	print("BENCH first line clear at move  p25=%d median=%d p75=%d" % [_pct(first_clears, 25), _pct(first_clears, 50), _pct(first_clears, 75)])
	print("BENCH early (first %d moves, per game): clears %.2f, multi-line %.2f, chained clears %.2f, snug fits %.2f | opening deal %.1f ms" % [EARLY_MOVES, float(early["clears"]) / GAMES, float(early["multi"]) / GAMES, float(early["chains"]) / GAMES, float(early["snug"]) / GAMES, early["deal_us"] / 1000.0 / max(1, early["deals"])])
	print("BENCH perfect clears (theme changes): %.2f per game, %d%% of games have one | search %d runs -> %d sets dealt, avg %.1f ms, max %.1f ms" % [float(perfects) / GAMES, 100 * games_with_perfect / GAMES, perfect_searches, perfect_deals, perfect_search_total / 1000.0 / max(1, perfect_searches), perfect_search_max / 1000.0])
	opening_combos.sort()
	print("BENCH opening (first %d moves, per game): max combo median=%d p75=%d p90=%d | moves in combo %.0f%% | combo breaks %.2f | perfect clears %.2f, %d%% of games" % [OPENING_MOVES, _pct(opening_combos, 50), _pct(opening_combos, 75), _pct(opening_combos, 90), 100.0 * opening["combo_moves"] / (GAMES * OPENING_MOVES), float(opening["breaks"]) / GAMES, float(opening["perfects"]) / GAMES, 100 * opening["games_perfect"] / GAMES])
	print("BENCH tension: fill>=50%% %.1f%% of moves, fill>=70%% %.1f%%  | fever clears/game %.1f" % [100.0 * tense_moves / max(1, total_moves), 100.0 * crisis_moves / max(1, total_moves), float(fever_clears) / GAMES])
	get_tree().quit()

func _play_game() -> Dictionary:
	var grid := PackedByteArray()
	grid.resize(64)
	var score := 0
	var combo := 0
	var grace := 0
	var moves := 0
	var max_combo := 0
	var crisis := 0
	var tense := 0
	var fever_clears := 0
	var perfects := 0
	var first_clear := 0
	var first_deal := false
	var deals := 0
	var last_cleared := false
	var opening_max_combo := 0
	var opening_perfects := 0
	if use_start:
		for p in BlockData.generate_start_pattern():
			for o in BlockData.get_offsets(p["shape"]):
				grid[(p["x"] + o.x) + (p["y"] + o.y) * 8] = 1
			first_deal = true
	while moves < MAX_MOVES:
		_sync(grid)
		var t0 := Time.get_ticks_usec()
		var fun_phase: bool = use_fun and deals < BlockData.FUN_DEALS and score < BlockData.FUN_SCORE_MAX
		var tray: Array = []
		if fun_phase:
			tray = BlockData.get_fun_trio(board, combo, score, grace, null, first_deal).duplicate()
		else:
			tray = BlockData.get_perfect_trio(board, null, first_deal).duplicate()
		var perfect_deal: bool = BlockData.last_generation_note == "perfect" and not tray.is_empty()
		BlockData.last_generation_note = ""
		if perfect_deal:
			perfect_deals += 1
		if BlockData.perfect_search_usec > 0:
			perfect_search_total += BlockData.perfect_search_usec
			perfect_search_max = maxi(perfect_search_max, BlockData.perfect_search_usec)
			perfect_searches += 1
			BlockData.perfect_search_usec = 0
		if tray.is_empty():
			tray = BlockData.get_adaptive_trio(board, combo, score, grace, null, BlockData.pressure_for_score(score) if use_pressure else 0.0, first_deal).duplicate()
		if deals < BlockData.FUN_DEALS:
			early["deal_us"] += Time.get_ticks_usec() - t0
			early["deals"] += 1
		deals += 1
		first_deal = false
		# Opening sets: the bot plans all three pieces like a person reading the tray (same for both modes)
		# A perfect-clear set is only worth something if the player spots it; the bot does
		var plan: Array = BlockData.evaluate_fun(grid, tray)["plan"] if deals <= PLAN_DEALS or perfect_deal else []
		while not tray.is_empty():
			var best := _best_move(grid, tray)
			if not plan.is_empty():
				var step: Dictionary = plan.pop_front()
				for k in range(tray.size()):
					if tray[k]["id"] == step["id"]:
						best = {"i": k, "x": step["x"], "y": step["y"]}
						break
			if best.is_empty():
				_record_opening(moves, opening_max_combo, opening_perfects)
				return {"moves": moves, "score": score, "max_combo": max_combo, "crisis": crisis, "tense": tense, "fever_clears": fever_clears, "first_clear": first_clear, "perfects": perfects}
			var shape: Dictionary = tray[best["i"]]
			tray.remove_at(best["i"])
			var offsets: Array[Vector2i] = BlockData.get_offsets(shape)
			var before := _count(grid)
			var snug_fit: bool = BlockData._snugness(grid, offsets, best["x"], best["y"]) >= 0.85
			grid = BlockData.place_and_clear(grid, offsets, best["x"], best["y"])
			moves += 1
			score += offsets.size()
			var cleared: int = before + offsets.size() - _count(grid)
			var lines: int = _lines_for(cleared, offsets.size())
			if moves <= EARLY_MOVES:
				if lines > 0:
					early["clears"] += 1
				if lines >= 2:
					early["multi"] += 1
				if snug_fit:
					early["snug"] += 1
				if lines > 0 and last_cleared:
					early["chains"] += 1
			last_cleared = lines > 0
			if lines > 0 and first_clear == 0:
				first_clear = moves
			if lines > 0:
				combo += 1
				grace = MainGame.MAX_COMBO_GRACE
				var gain: int = int(MainGame.LINE_SCORE_BASE * lines * lines * (1.0 + MainGame.COMBO_ALPHA * combo)) \
					+ int(MainGame.COMBO_BONUS_LINEAR * combo + MainGame.COMBO_BONUS_QUADRATIC * combo * combo)
				if combo >= MainGame.FEVER_COMBO:
					gain = int(gain * MainGame.FEVER_MULTIPLIER)
					fever_clears += 1
				score += gain
				if _count(grid) == 0:
					score += roundi(MainGame.PERFECT_CLEAR_BASE * (1.0 + MainGame.COMBO_ALPHA * combo))
					perfects += 1
					if moves <= OPENING_MOVES:
						opening_perfects += 1
			elif combo > 0:
				grace -= 1
				if grace <= 0:
					combo = 0
					if moves <= OPENING_MOVES:
						opening["breaks"] += 1
			max_combo = max(max_combo, combo)
			if moves <= OPENING_MOVES:
				opening_max_combo = max(opening_max_combo, combo)
				if combo > 0:
					opening["combo_moves"] += 1
			if _count(grid) >= 45:
				crisis += 1
			if _count(grid) >= 32:
				tense += 1
	_record_opening(moves, opening_max_combo, opening_perfects)
	return {"moves": moves, "score": score, "max_combo": max_combo, "crisis": crisis, "tense": tense, "fever_clears": fever_clears, "first_clear": first_clear, "perfects": perfects}

func _record_opening(_moves: int, max_combo: int, perfects: int) -> void:
	opening_combos.append(max_combo)
	opening["perfects"] += perfects
	if perfects > 0:
		opening["games_perfect"] += 1

func _best_move(grid: PackedByteArray, tray: Array) -> Dictionary:
	var before := _count(grid)
	var best := {}
	var best_s := -1.0
	for i in range(tray.size()):
		var shape: Dictionary = tray[i]
		var offsets: Array[Vector2i] = BlockData.get_offsets(shape)
		var b: Rect2i = BlockData.get_bounds(shape["cells"])
		for y in range(8 - b.size.y + 1):
			for x in range(8 - b.size.x + 1):
				var ok := true
				for o in offsets:
					if grid[(x + o.x) + (y + o.y) * 8] != 0:
						ok = false
						break
				if not ok:
					continue
				var after := _count(BlockData.place_and_clear(grid, offsets, x, y))
				var s: float = (before + offsets.size() - after) * 10.0 + BlockData._snugness(grid, offsets, x, y) * snug_weight + bot_rng.randf()
				if s > best_s:
					best_s = s
					best = {"i": i, "x": x, "y": y}
	return best

func _lines_for(cleared_cells: int, _piece_cells: int) -> int:
	# 8 cells per line, minus 1 shared cell per row/column crossing; good enough for 1-2 crossings
	if cleared_cells <= 0:
		return 0
	for rows in range(0, 9):
		for cols in range(0, 9):
			if rows + cols > 0 and rows * 8 + cols * 8 - rows * cols == cleared_cells:
				return rows + cols
	return int(ceil(cleared_cells / 8.0))

func _count(grid: PackedByteArray) -> int:
	var n := 0
	for v in grid:
		n += v
	return n

func _sync(grid: PackedByteArray) -> void:
	for x in range(8):
		for y in range(8):
			board.grid_state[x][y] = "blue" if grid[x + y * 8] != 0 else null

func _pct(a: Array[int], p: int) -> int:
	if a.is_empty():
		return 0
	return a[clampi(int(a.size() * p / 100.0), 0, a.size() - 1)]
