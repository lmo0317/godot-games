extends Node
# Battle benchmark: the computer at each level plays MATCHES matches against a stand-in player
# using the BENCH_PLAYER move choice (default "normal"). Each side solves its own board; one
# piece each per round; clears deal damage (with criticals) until one side's HP is gone or a side
# is stuck. Reports the computer's win rate, how matches end and their length. No rendering.
# Run: Godot_console.exe --headless --path . res://tests/bench_versus.tscn
#   BENCH_GAMES=<n>, BENCH_PLAYER=easy|normal|hard, BENCH_LEVELS=easy,hard

const BoardScene: PackedScene = preload("res://scenes/board.tscn")
const MAX_ROUNDS: int = 400

var MATCHES: int = int(OS.get_environment("BENCH_GAMES")) if not OS.get_environment("BENCH_GAMES").is_empty() else 200
var gen_board: Board
var crit_rng := RandomNumberGenerator.new()

func _ready() -> void:
	gen_board = BoardScene.instantiate()
	add_child(gen_board)
	_run.call_deferred()

func _run() -> void:
	var player_ai := VersusMatch.new()
	player_ai.level = OS.get_environment("BENCH_PLAYER") if not OS.get_environment("BENCH_PLAYER").is_empty() else "normal"
	var cpu_ai := VersusMatch.new()
	add_child(player_ai)
	add_child(cpu_ai)
	var levels: Array = OS.get_environment("BENCH_LEVELS").split(",") if not OS.get_environment("BENCH_LEVELS").is_empty() else ["easy", "normal", "hard"]
	for level in levels:
		cpu_ai.level = level
		var wins := 0
		var stuck := 0
		var rounds: Array[int] = []
		var hp_left := 0
		for m in range(MATCHES):
			BlockData.get_default_rng().seed = 7000 + m
			player_ai.rng.seed = 100 + m
			cpu_ai.rng.seed = 900 + m
			crit_rng.seed = 500 + m
			var r: Dictionary = _match([player_ai, cpu_ai])
			if r["winner"] == 1:
				wins += 1
			if r["stuck"]:
				stuck += 1
			rounds.append(r["rounds"])
			hp_left += r["winner_hp"]
		rounds.sort()
		print("BENCH_VS %s vs player %s: computer wins %d%% | ended by stuck %d%% | rounds median %d, p25 %d, p75 %d | winner HP left avg %d" % [
			level, player_ai.level, 100 * wins / MATCHES, 100 * stuck / MATCHES,
			rounds[rounds.size() / 2], rounds[rounds.size() / 4], rounds[rounds.size() * 3 / 4], hp_left / MATCHES])
	get_tree().quit()

func _match(ais: Array) -> Dictionary:
	var start := PackedByteArray()
	start.resize(64)
	for p in BlockData.generate_start_pattern():
		for o in BlockData.get_offsets(p["shape"]):
			start[(p["x"] + o.x) + (p["y"] + o.y) * 8] = 1
	var sides: Array = []
	for i in range(2):
		sides.append({"grid": start.duplicate(), "tray": [], "combo": 0, "grace": 0, "hp": VersusMatch.MAX_HP, "first": true})
	for round_i in range(MAX_ROUNDS):
		for who in [0, 1]:
			var s: Dictionary = sides[who]
			var o: Dictionary = sides[1 - who]
			if s["tray"].all(func(p): return p == null):
				_sync(s["grid"])
				s["tray"] = BlockData.get_adaptive_trio(gen_board, s["combo"], 0, maxi(s["grace"], 1), null, VersusMatch.PRESSURE, s["first"]).map(func(sh): return VersusMatch.ShapeRef.new(sh))
				s["first"] = false
			var move: Dictionary = ais[who].choose_move(s["grid"], s["tray"], s["combo"])
			if move.is_empty():
				return {"winner": 1 - who, "stuck": true, "rounds": round_i + 1, "winner_hp": o["hp"]}
			s["tray"][move["slot"]] = null
			s["grid"] = move["grid"]
			if move["lines"] > 0:
				s["combo"] += 1
				s["grace"] = 3
				var dmg: int = VersusMatch.damage_for(move["lines"], s["combo"], VersusMatch._free(s["grid"]) == 64)
				if crit_rng.randf() < VersusMatch.CRIT_CHANCE:
					dmg = int(dmg * VersusMatch.CRIT_MULT)
				o["hp"] -= dmg
				if o["hp"] <= 0:
					return {"winner": who, "stuck": false, "rounds": round_i + 1, "winner_hp": s["hp"]}
			elif s["combo"] > 0:
				s["grace"] -= 1
				if s["grace"] <= 0:
					s["combo"] = 0
			var left: Array = s["tray"].filter(func(p): return p != null)
			if not left.is_empty() and ais[who]._moves(s["grid"], left).is_empty():
				return {"winner": 1 - who, "stuck": true, "rounds": round_i + 1, "winner_hp": o["hp"]}
	return {"winner": -1, "stuck": false, "rounds": MAX_ROUNDS, "winner_hp": 0}

func _sync(grid: PackedByteArray) -> void:
	for x in range(8):
		for y in range(8):
			gen_board.grid_state[x][y] = "blue" if grid[x + y * 8] != 0 else null
