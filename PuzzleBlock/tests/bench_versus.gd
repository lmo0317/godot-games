extends Node
# Attack battle benchmark: the computer at each level plays MATCHES matches against a stand-in
# player that places one piece every BENCH_PACE seconds (default 2.0, an unhurried person) with
# the "normal" move choice. Both boards run in simulated time with the real tray generator,
# attacks, cancelling and stones. Reports the computer's win rate and match length. No rendering.
# Run: Godot_console.exe --headless --path . res://tests/bench_versus.tscn
#   BENCH_GAMES=<n>, BENCH_PACE=<seconds per piece>, BENCH_LEVELS=easy,hard

const BoardScene: PackedScene = preload("res://scenes/board.tscn")
const MAX_TIME: float = 600.0

var MATCHES: int = int(OS.get_environment("BENCH_GAMES")) if not OS.get_environment("BENCH_GAMES").is_empty() else 200
var pace: float = float(OS.get_environment("BENCH_PACE")) if not OS.get_environment("BENCH_PACE").is_empty() else 2.0
var gen_board: Board

func _ready() -> void:
	gen_board = BoardScene.instantiate()
	add_child(gen_board)
	_run.call_deferred()

func _run() -> void:
	var player_ai := VersusMatch.new()
	player_ai.level = "normal"
	var cpu_ai := VersusMatch.new()
	add_child(player_ai)
	add_child(cpu_ai)
	var levels: Array = OS.get_environment("BENCH_LEVELS").split(",") if not OS.get_environment("BENCH_LEVELS").is_empty() else ["easy", "normal", "hard"]
	for level in levels:
		cpu_ai.level = level
		var interval: float = VersusMatch.level_info(level)["interval"]
		var wins := 0
		var timeouts := 0
		var times: Array[float] = []
		var stones := 0
		for m in range(MATCHES):
			BlockData.get_default_rng().seed = 7000 + m
			player_ai.rng.seed = 100 + m
			cpu_ai.rng.seed = 900 + m
			var r: Dictionary = _match(player_ai, cpu_ai, interval)
			if r["winner"] == 1:
				wins += 1
			elif r["winner"] < 0:
				timeouts += 1
			times.append(r["time"])
			stones += r["stones"]
		times.sort()
		print("BENCH_VS %s (player every %.1fs): computer wins %d%%, unfinished %d%% | match length median %ds, p75 %ds | stones per match %.1f" % [
			level, pace, 100 * wins / MATCHES, 100 * timeouts / MATCHES, int(times[times.size() / 2]), int(times[times.size() * 3 / 4]), float(stones) / MATCHES])
	get_tree().quit()

func _match(player_ai: VersusMatch, cpu_ai: VersusMatch, cpu_interval: float) -> Dictionary:
	var start := PackedByteArray()
	start.resize(64)
	for p in BlockData.generate_start_pattern():
		for o in BlockData.get_offsets(p["shape"]):
			start[(p["x"] + o.x) + (p["y"] + o.y) * 8] = 1
	var sides: Array = []
	for i in range(2):
		sides.append({"grid": start.duplicate(), "tray": [], "combo": 0, "grace": 0, "incoming": 0, "next": 0.0, "first": true})
	sides[0]["ai"] = player_ai
	sides[0]["interval"] = pace
	sides[1]["ai"] = cpu_ai
	sides[1]["interval"] = cpu_interval
	sides[0]["next"] = pace
	sides[1]["next"] = cpu_interval
	var stones := 0
	var t := 0.0
	while t < MAX_TIME:
		var who: int = 0 if sides[0]["next"] <= sides[1]["next"] else 1
		var s: Dictionary = sides[who]
		var o: Dictionary = sides[1 - who]
		t = s["next"]
		s["next"] += s["interval"]
		if s["tray"].all(func(p): return p == null):
			_sync(s["grid"])
			s["tray"] = BlockData.get_adaptive_trio(gen_board, s["combo"], 0, maxi(s["grace"], 1), null, VersusMatch.PRESSURE, s["first"]).map(func(sh): return VersusMatch.ShapeRef.new(sh))
			s["first"] = false
		var move: Dictionary = s["ai"].choose_move(s["grid"], s["tray"], s["combo"])
		if move.is_empty():
			return {"winner": 1 - who, "time": t, "stones": stones}
		s["tray"][move["slot"]] = null
		s["grid"] = move["grid"]
		if move["lines"] > 0:
			s["combo"] += 1
			s["grace"] = 3
			var atk: int = VersusMatch.attack_for(move["lines"], s["combo"], VersusMatch._free(s["grid"]) == 64)
			var cancel: int = mini(atk, s["incoming"])
			s["incoming"] -= cancel
			o["incoming"] += atk - cancel
		else:
			if s["combo"] > 0:
				s["grace"] -= 1
				if s["grace"] <= 0:
					s["combo"] = 0
			var n: int = mini(s["incoming"], VersusMatch.MAX_DROP)
			s["incoming"] -= n
			stones += n
			s["grid"] = VersusMatch.drop_stones(s["grid"], n, s["ai"].rng)
		# Pieces left that fit nowhere: this side loses
		var left: Array = s["tray"].filter(func(p): return p != null)
		if not left.is_empty() and s["ai"]._moves(s["grid"], left).is_empty():
			return {"winner": 1 - who, "time": t, "stones": stones}
	return {"winner": -1, "time": t, "stones": stones}

func _sync(grid: PackedByteArray) -> void:
	for x in range(8):
		for y in range(8):
			gen_board.grid_state[x][y] = "blue" if grid[x + y * 8] != 0 else null
