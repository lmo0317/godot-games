class_name BlockData
extends RefCounted

# Color list matching generated sprites:
# "blue", "orange", "green", "purple", "yellow", "red", "cyan", "pink"

const SHAPES: Array[Dictionary] = [
	# 1. Single Dot (1 cell)
	{
		"id": "dot_1x1",
		"category": "small",
		"color": "yellow",
		"cells": [Vector2i(0, 0)]
	},
	# 2. Dominoes (2 cells)
	{
		"id": "line_2_h",
		"category": "small",
		"color": "cyan",
		"cells": [Vector2i(0, 0), Vector2i(1, 0)]
	},
	{
		"id": "line_2_v",
		"category": "small",
		"color": "cyan",
		"cells": [Vector2i(0, 0), Vector2i(0, 1)]
	},
	# 3. Triominoes (3 cells)
	{
		"id": "line_3_h",
		"category": "medium",
		"color": "blue",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	},
	{
		"id": "line_3_v",
		"category": "medium",
		"color": "blue",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2)]
	},
	# 4. Small Corners (3 cells)
	{
		"id": "corner_2x2_1",
		"category": "medium",
		"color": "orange",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]
	},
	{
		"id": "corner_2x2_2",
		"category": "medium",
		"color": "orange",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)]
	},
	{
		"id": "corner_2x2_3",
		"category": "medium",
		"color": "orange",
		"cells": [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]
	},
	{
		"id": "corner_2x2_4",
		"category": "medium",
		"color": "orange",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)]
	},
	# 5. 2x2 Square (4 cells)
	{
		"id": "square_2x2",
		"category": "medium",
		"color": "green",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
	},
	# 6. Straight Tetrominoes (4 cells)
	{
		"id": "line_4_h",
		"category": "medium",
		"color": "pink",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	},
	{
		"id": "line_4_v",
		"category": "medium",
		"color": "pink",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3)]
	},
	# 7. Classic L & J shapes (4 cells)
	{
		"id": "l_4_1",
		"category": "medium",
		"color": "orange",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2)]
	},
	{
		"id": "l_4_2",
		"category": "medium",
		"color": "orange",
		"cells": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 2)]
	},
	{
		"id": "l_4_3",
		"category": "medium",
		"color": "orange",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)]
	},
	{
		"id": "l_4_4",
		"category": "medium",
		"color": "orange",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)]
	},
	# 8. T-Shapes (4 cells)
	{
		"id": "t_1",
		"category": "medium",
		"color": "purple",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]
	},
	{
		"id": "t_2",
		"category": "medium",
		"color": "purple",
		"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	},
	{
		"id": "t_3",
		"category": "medium",
		"color": "purple",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 1)]
	},
	{
		"id": "t_4",
		"category": "medium",
		"color": "purple",
		"cells": [Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(0, 1)]
	},
	# 9. Z & S Shapes (4 cells)
	{
		"id": "z_h",
		"category": "medium",
		"color": "green",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)]
	},
	{
		"id": "z_v",
		"category": "medium",
		"color": "green",
		"cells": [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 2)]
	},
	{
		"id": "s_h",
		"category": "medium",
		"color": "green",
		"cells": [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]
	},
	{
		"id": "s_v",
		"category": "medium",
		"color": "green",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 2)]
	},
	# 10. Large Straight (5 cells)
	{
		"id": "line_5_h",
		"category": "large",
		"color": "red",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0)]
	},
	{
		"id": "line_5_v",
		"category": "large",
		"color": "red",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(0, 4)]
	},
	# 11. Large L-shapes (5 cells - 3x3 corner)
	{
		"id": "big_l_1",
		"category": "large",
		"color": "purple",
		"cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(0, 2)]
	},
	{
		"id": "big_l_2",
		"category": "large",
		"color": "purple",
		"cells": [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2), Vector2i(0, 0), Vector2i(1, 0)]
	},
	{
		"id": "big_l_3",
		"category": "large",
		"color": "purple",
		"cells": [Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 0), Vector2i(2, 1)]
	},
	{
		"id": "big_l_4",
		"category": "large",
		"color": "purple",
		"cells": [Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]
	},
	# 12. 3x3 Big Square (9 cells)
	{
		"id": "square_3x3",
		"category": "large",
		"color": "red",
		"cells": [
			Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
			Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
			Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
		]
	}
]

const GRID_N: int = 8
# Max search nodes for the sequential placement check (keeps the worst case cheap on Web)
const SOLVE_NODE_BUDGET: int = 6000
# Role-based rerolls before falling back to rescue pieces
const MAX_TRIO_ATTEMPTS: int = 8

static var _offset_cache: Dictionary = {}
static var _default_rng: RandomNumberGenerator = null
# How the last trio was produced: "roll_N", "rescue", "dots", "dead" (for logging and tests)
static var last_generation_note: String = ""

const SHAPE_BASE_WEIGHTS: Dictionary = {
	"dot_1x1": 0.0,
	# Dominoes (high demand, universal gap pluggers)
	"line_2_h": 4.5, "line_2_v": 4.5,
	# Triominoes (very friendly builders and bridges)
	"line_3_h": 3.8, "line_3_v": 3.8,
	"square_2x2": 3.5,
	"corner_2x2_1": 2.4, "corner_2x2_2": 2.4, "corner_2x2_3": 2.4, "corner_2x2_4": 2.4,
	# Tetrominoes
	"line_4_h": 2.8, "line_4_v": 2.8,
	"t_1": 1.4, "t_2": 1.4, "t_3": 1.4, "t_4": 1.4,
	"l_4_1": 1.5, "l_4_2": 1.5, "l_4_3": 1.5, "l_4_4": 1.5,
	# S and Z (low base weight so they don't spam the board)
	"z_h": 0.7, "z_v": 0.7, "s_h": 0.7, "s_v": 0.7,
	# Pentominoes & Giants (high commitment)
	"line_5_h": 1.2, "line_5_v": 1.2,
	"big_l_1": 0.8, "big_l_2": 0.8, "big_l_3": 0.8, "big_l_4": 0.8,
	"square_3x3": 0.9
}

static func get_default_rng() -> RandomNumberGenerator:
	# Shared randomized RNG for normal play; seeded modes pass their own instance
	if _default_rng == null:
		_default_rng = RandomNumberGenerator.new()
		_default_rng.randomize()
	return _default_rng

static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	# Fisher-Yates driven by the given RNG (Array.shuffle() always uses the global RNG)
	for i in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _pick_weighted_shape(candidate_pool: Array, weights: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	if candidate_pool.is_empty():
		return {}
	var total_w: float = 0.0
	for s in candidate_pool:
		total_w += weights.get(s["id"], 1.0)
	if total_w <= 0.0:
		return candidate_pool[rng.randi() % candidate_pool.size()]
	var roll: float = rng.randf() * total_w
	var accum: float = 0.0
	for s in candidate_pool:
		accum += weights.get(s["id"], 1.0)
		if roll <= accum:
			return s
	return candidate_pool[-1]

# Classic difficulty curve: no change below PRESSURE_START points, full pressure at PRESSURE_FULL.
# Pressure trims the generator's help (line-clearing picks, gap fillers) and lets big pieces in sooner.
# Past OVERDRIVE_START a second stage (pressure 1..2) is for players who stack neatly and would
# otherwise never lose: still less help, and sets are no longer always guaranteed to fit together.
const PRESSURE_START: int = 2000
const PRESSURE_FULL: int = 12000
const OVERDRIVE_START: int = 15000
const OVERDRIVE_FULL: int = 45000

const ASSIST_CUT: float = 0.9
const UNCHECKED_MAX: float = 0.8

static func pressure_for_score(score: int) -> float:
	var p: float = clampf(float(score - PRESSURE_START) / float(PRESSURE_FULL - PRESSURE_START), 0.0, 1.0)
	return p + clampf(float(score - OVERDRIVE_START) / float(OVERDRIVE_FULL - OVERDRIVE_START), 0.0, 1.0)

static func get_adaptive_trio(board, combo_count: int = 0, score: int = 0, combo_grace_moves: int = 3, rng: RandomNumberGenerator = null, pressure: float = 0.0, guarantee_clear: bool = false) -> Array[Dictionary]:
	if rng == null:
		rng = get_default_rng()
	if board == null:
		return get_balanced_trio(rng)
		
	var fill: float = board.get_fill_ratio()
	var overdrive: float = clampf(pressure - 1.0, 0.0, 1.0)
	pressure = minf(pressure, 1.0)
	
	# Calculate affinity and dynamic weight for every shape on this specific board
	var shape_weights: Dictionary = {}
	var shape_affinities: Dictionary = {}
	var all_fitting: Array[Dictionary] = []
	var clearing_shapes: Array[Dictionary] = []
	var near_line_shapes: Array[Dictionary] = []
	
	var solvers: Array[Dictionary] = []
	var triggers: Array[Dictionary] = []
	var hazards: Array[Dictionary] = []
	
	for s in SHAPES:
		if s["id"] == "dot_1x1":
			continue
		var id: String = s["id"]
		var cells_count: int = s["cells"].size()
		var aff: float = board.get_shape_affinity(s)
		shape_affinities[id] = aff
		
		if aff < 0.0:
			continue # Cannot fit anywhere on the board!
			
		all_fitting.append(s)
		
		var base_w: float = SHAPE_BASE_WEIGHTS.get(id, 1.0)
		# Multiplier exponentially boosts shapes that clear lines or advance near-complete lines
		var dyn_w: float = base_w * (1.0 + aff * 0.18 * maxf(0.0, 1.0 - 0.6 * pressure - 0.4 * overdrive))
		shape_weights[id] = dyn_w
		
		if aff >= 100.0:
			clearing_shapes.append(s)
		elif aff >= 20.0:
			near_line_shapes.append(s)
			
		# Role 1: Solver (dominoes, 2x2 square, 3-cell corners)
		if cells_count <= 2 or id.begins_with("corner_2x2") or id == "square_2x2":
			solvers.append(s)
		# Role 2: Line Trigger (straight lines 3, 4, 5, T, L, Z, S)
		if id.begins_with("line_") or id.begins_with("t_") or id.begins_with("l_4") or id.begins_with("z_") or id.begins_with("s_"):
			triggers.append(s)
		# Role 3: Hazard / Large (3x3 big square, big 3x3 L, 5-lines)
		if id == "square_3x3" or id.begins_with("big_l") or id == "line_5_h" or id == "line_5_v":
			hazards.append(s)
			
	# Emergency fallback: If absolutely NO normal shape fits, check 1x1 dot
	if all_fitting.is_empty():
		var dot_shape = SHAPES[0] # dot_1x1
		if board.can_fit_shape(dot_shape):
			return [dot_shape, dot_shape, dot_shape]
		return [SHAPES[1], SHAPES[2], SHAPES[1]]
		
	var is_crisis: bool = (fill >= 0.70 or all_fitting.size() <= 4)
	var is_comfortable: bool = (fill <= 0.45 + 0.15 * pressure + 0.1 * overdrive)
	var assist_chance: float = ((0.95 - 0.3 * pressure) if combo_grace_moves <= 1 else (0.85 - 0.4 * pressure)) * (1.0 - ASSIST_CUT * overdrive)
	var near_line_chance: float = (0.75 - 0.35 * pressure) * (1.0 - ASSIST_CUT * overdrive)
	var hazard_chance: float = minf(1.0, 0.5 + 0.3 * pressure + 0.2 * overdrive)
	# Overdrive: some sets skip the "all three fit in some order" check (each piece still fits now)
	var unchecked: bool = overdrive > 0.0 and not is_crisis and rng.randf() < UNCHECKED_MAX * overdrive

	# In crisis, large hazards are completely banned from slot C
	var safe_pool: Array[Dictionary] = []
	for s in all_fitting:
		if s["cells"].size() <= 4 and s["id"] != "square_3x3" and not s["id"].begins_with("big_l"):
			safe_pool.append(s)

	var grid: PackedByteArray = board.get_occupancy_snapshot()
	var trio: Array[Dictionary] = []

	for attempt in range(MAX_TRIO_ATTEMPTS):
		trio = []

		# =========================================================
		# SLOT A: The Solver (해결사 / 틈새 메우기)
		# =========================================================
		var piece_a: Dictionary = {}
		# Under pressure the "gap filler" slot sometimes becomes an ordinary pick
		if not solvers.is_empty() and rng.randf() >= 0.5 * pressure + 0.5 * overdrive:
			piece_a = _pick_weighted_shape(solvers, shape_weights, rng)
		else:
			piece_a = _pick_weighted_shape(all_fitting, shape_weights, rng)
		trio.append(piece_a)

		# =========================================================
		# SLOT B: The Line Finisher / Clutch Savior (라인 완성기 / 구원 블록)
		# =========================================================
		var piece_b: Dictionary = {}
		var need_clutch = is_crisis and not clearing_shapes.is_empty()
		var should_clear = (combo_count > 0 or fill >= 0.40) and not clearing_shapes.is_empty() and (rng.randf() < assist_chance)

		# guarantee_clear: the first set after a start pattern always includes a line-clearing piece
		if need_clutch or should_clear or (guarantee_clear and not clearing_shapes.is_empty()):
			piece_b = _pick_weighted_shape(clearing_shapes, shape_weights, rng)
		elif not near_line_shapes.is_empty() and rng.randf() < near_line_chance:
			# Give a piece that plugs a 6/8 or 7/8 near-complete line!
			piece_b = _pick_weighted_shape(near_line_shapes, shape_weights, rng)
		elif not triggers.is_empty():
			piece_b = _pick_weighted_shape(triggers, shape_weights, rng)
		else:
			piece_b = _pick_weighted_shape(all_fitting, shape_weights, rng)
		trio.append(piece_b)

		# =========================================================
		# SLOT C: Hazard / Cognitive Dilemma (전략적 압박 / 밸런서)
		# =========================================================
		var piece_c: Dictionary = {}
		if is_crisis:
			if not safe_pool.is_empty():
				piece_c = _pick_weighted_shape(safe_pool, shape_weights, rng)
			else:
				piece_c = _pick_weighted_shape(all_fitting, shape_weights, rng)
		elif is_comfortable and (score >= 400 or combo_count >= 2) and not hazards.is_empty() and rng.randf() < hazard_chance:
			# Challenge the player when they have open space
			piece_c = _pick_weighted_shape(hazards, shape_weights, rng)
		else:
			# General pool with affinity weighting (favors shapes that fit current gaps)
			piece_c = _pick_weighted_shape(all_fitting, shape_weights, rng)
		trio.append(piece_c)

		# =========================================================
		# Solvability Check (죽음 방지 검증): all 3 must be placeable in some order
		# =========================================================
		if unchecked or can_place_all(grid, trio):
			last_generation_note = ("free_%d" if unchecked else "roll_%d") % attempt
			# Shuffle order so the user cannot guess which slot corresponds to which role
			_shuffle(trio, rng)
			return trio

	# Rescue: swap slots (hazard slot first) for the smallest solvers until the set is solvable
	var rescue_pool: Array[Dictionary] = solvers.duplicate() if not solvers.is_empty() else all_fitting.duplicate()
	rescue_pool.sort_custom(func(a, b): return a["cells"].size() < b["cells"].size())
	for slot in [2, 1, 0]:
		for candidate in rescue_pool:
			var attempt_trio: Array[Dictionary] = trio.duplicate()
			attempt_trio[slot] = candidate
			if can_place_all(grid, attempt_trio):
				last_generation_note = "rescue"
				_shuffle(attempt_trio, rng)
				return attempt_trio
		trio[slot] = rescue_pool[0]

	var dot_shape: Dictionary = SHAPES[0]
	var dots: Array[Dictionary] = [dot_shape, dot_shape, dot_shape]
	if can_place_all(grid, dots):
		last_generation_note = "dots"
		return dots

	# Truly dead board: nothing can save it, so hand out the rescue set and let game over happen
	last_generation_note = "dead"
	_shuffle(trio, rng)
	return trio

# =========================================================
# Sequential placement solver on an 8x8 occupancy grid (index = x + y * 8)
# =========================================================

static func can_place_all(grid: PackedByteArray, shapes: Array, node_budget: int = SOLVE_NODE_BUDGET) -> bool:
	# True if every shape can be placed one after another in some order,
	# applying line clears between placements. Exceeding the budget counts as unsolvable.
	var budget: Array[int] = [node_budget]
	return _search_placements(grid, shapes, budget)

static func _search_placements(grid: PackedByteArray, remaining: Array, budget: Array[int]) -> bool:
	if remaining.is_empty():
		return true
	if budget[0] <= 0:
		return false

	var tried_ids: Dictionary = {}
	for i in range(remaining.size()):
		var shape: Dictionary = remaining[i]
		if tried_ids.has(shape["id"]):
			continue
		tried_ids[shape["id"]] = true

		var rest: Array = remaining.duplicate()
		rest.remove_at(i)
		var offsets: Array[Vector2i] = get_offsets(shape)
		var bounds: Rect2i = get_bounds(shape["cells"])

		for by in range(GRID_N - bounds.size.y + 1):
			for bx in range(GRID_N - bounds.size.x + 1):
				if not _fits_at(grid, offsets, bx, by):
					continue
				if rest.is_empty():
					return true
				budget[0] -= 1
				if budget[0] <= 0:
					return false
				if _search_placements(place_and_clear(grid, offsets, bx, by), rest, budget):
					return true
	return false

static func get_offsets(shape: Dictionary) -> Array[Vector2i]:
	var id: String = shape["id"]
	if _offset_cache.has(id):
		return _offset_cache[id]
	var bounds: Rect2i = get_bounds(shape["cells"])
	var offsets: Array[Vector2i] = []
	for c in shape["cells"]:
		offsets.append(Vector2i(c.x - bounds.position.x, c.y - bounds.position.y))
	_offset_cache[id] = offsets
	return offsets

static func _fits_at(grid: PackedByteArray, offsets: Array[Vector2i], bx: int, by: int) -> bool:
	for o in offsets:
		if grid[(bx + o.x) + (by + o.y) * GRID_N] != 0:
			return false
	return true

static func place_and_clear(grid: PackedByteArray, offsets: Array[Vector2i], bx: int, by: int) -> PackedByteArray:
	var g: PackedByteArray = grid.duplicate()
	var rows: Dictionary = {}
	var cols: Dictionary = {}
	for o in offsets:
		var x = bx + o.x
		var y = by + o.y
		g[x + y * GRID_N] = 1
		rows[y] = true
		cols[x] = true

	# Only rows/columns touched by the piece can have become full
	var full_rows: Array[int] = []
	var full_cols: Array[int] = []
	for y in rows:
		var full = true
		for x in range(GRID_N):
			if g[x + y * GRID_N] == 0:
				full = false
				break
		if full:
			full_rows.append(y)
	for x in cols:
		var full = true
		for y in range(GRID_N):
			if g[x + y * GRID_N] == 0:
				full = false
				break
		if full:
			full_cols.append(x)

	for y in full_rows:
		for x in range(GRID_N):
			g[x + y * GRID_N] = 0
	for x in full_cols:
		for y in range(GRID_N):
			g[x + y * GRID_N] = 0
	return g

# =========================================================
# Early-game "fun" trios (classic): instead of handing out whatever the board needs, try a few
# candidate trios, look ahead at how each can be played, and prefer sets that create moments:
# a piece that fits a hole snugly, a double/triple clear, clears chaining across the three pieces,
# a combo that keeps going from set to set, and a board that empties out (perfect clear).
# =========================================================
const FUN_DEALS: int = 8            # first N deals of a classic game
const FUN_SCORE_MAX: int = 6000     # ...while the score is still below this
const FUN_CANDIDATES: int = 4
const FUN_HOLE_CANDIDATES: int = 4  # extra candidates built around a piece that clears 2+ lines
const FUN_CHAIN_CANDIDATES: int = 4 # extra candidates where each piece clears a line after the last
const FUN_BEAM: int = 4
const COMBO_GRACE: int = 3          # same as MainGame.MAX_COMBO_GRACE

static func get_fun_trio(board, combo_count: int, score: int, combo_grace_moves: int, rng: RandomNumberGenerator = null, guarantee_clear: bool = false) -> Array[Dictionary]:
	if rng == null:
		rng = get_default_rng()
	var grid: PackedByteArray = board.get_occupancy_snapshot()
	var ranked: Array = []
	# Pieces that fill a hole to clear two or more lines at once get candidates of their own,
	# so a board with such a hole usually deals the piece that fits it
	var hole_pieces := _multi_clear_shapes(grid)
	# Moves left before a running combo breaks (-1: no combo yet)
	var grace_left: int = combo_grace_moves if combo_count > 0 else -1
	# With few blocks left, a set that can empty the board is dealt whenever one exists
	var perfect := _perfect_candidate(grid, rng)
	if not perfect.is_empty() and (not guarantee_clear or not board.find_clearing_shapes(perfect).is_empty()):
		_shuffle(perfect, rng)
		last_generation_note = "perfect"
		return perfect
	var candidates: Array = []
	# "Needed" sets: pieces that clear a line one after another keep the combo going
	for i in range(FUN_CHAIN_CANDIDATES):
		var chain := _chain_trio(grid, rng)
		if not chain.is_empty() and can_place_all(grid, chain):
			candidates.append(chain)
	for trio in candidates:
		if guarantee_clear and board.find_clearing_shapes(trio).is_empty():
			continue
		var ev := evaluate_fun(grid, trio, true, grace_left)
		ranked.append({"score": ev["score"] + _variety_bonus(trio), "trio": trio, "broke": ev["broke"]})
	for i in range(FUN_CANDIDATES + mini(hole_pieces.size(), FUN_HOLE_CANDIDATES)):
		var trio: Array[Dictionary]
		if i >= FUN_CANDIDATES:
			trio = _free_trio(rng)
			trio[0] = hole_pieces[rng.randi() % hole_pieces.size()]
			if not can_place_all(grid, trio):
				continue
		# Mostly free picks (variety); a third come from the needs-based generator as a safety net
		elif i % 3 == 0:
			trio = get_adaptive_trio(board, combo_count, score, combo_grace_moves, rng, 0.0, guarantee_clear)
		else:
			trio = _free_trio(rng)
			if not can_place_all(grid, trio):
				continue
		var ev := evaluate_fun(grid, trio, true, grace_left)
		if guarantee_clear and board.find_clearing_shapes(trio).is_empty():
			continue
		ranked.append({"score": ev["score"] + _variety_bonus(trio), "trio": trio, "broke": ev["broke"]})
	# Never pick a set whose obvious play breaks the combo when another set keeps it going
	var keeps: Array = ranked.filter(func(r): return not r["broke"])
	if not keeps.is_empty():
		ranked = keeps
	# A hole that one piece fills to clear two lines at once is the opening's "just fits" moment:
	# deal that piece when a good set has it
	if not hole_pieces.is_empty():
		var fits: Array = ranked.filter(func(r): return r["trio"].any(func(s): return hole_pieces.has(s)))
		if not fits.is_empty():
			ranked = fits
	if ranked.is_empty():
		return get_adaptive_trio(board, combo_count, score, combo_grace_moves, rng, 0.0, guarantee_clear)
	ranked.sort_custom(func(a, b): return a["score"] > b["score"])
	# Mostly the best, sometimes the runner-up, so openings don't repeat
	var roll := rng.randf()
	var pick: int = 0 if roll < 0.6 else (1 if roll < 0.85 else 2)
	var chosen: Array[Dictionary] = ranked[mini(pick, ranked.size() - 1)]["trio"]
	chosen = chosen.duplicate()
	_shuffle(chosen, rng)
	last_generation_note = "fun"
	return chosen

# 블록 기사단: the pieces the board needs, in order (docs/LANE_STAGES.md "퍼즐"). Each step picks,
# on the board the previous pieces left, a shape that clears a line (more lines weigh more); when
# nothing can clear, a "builder" that sits snugly and brings rows/columns close to full, and smaller
# pieces when the board is crowded. A set that empties the board is dealt whenever one exists.
# The three are placeable one after another, so the board does not lock up.
const NEED_TOP: int = 3            # pick among the best few for variety
const NEED_CROWDED: float = 0.45   # board fill above which bigger builders are avoided
const NEED_PERFECT_CELLS: int = 10 # look for a set that empties the board at or below this many cells

static func get_needed_trio(board, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	if rng == null:
		rng = get_default_rng()
	var grid: PackedByteArray = board.get_occupancy_snapshot()
	var cells := 0
	for v in grid:
		cells += v
	# The search for an emptying set is the slow part, so only on nearly empty boards
	var perfect: Array[Dictionary] = []
	if cells <= NEED_PERFECT_CELLS:
		perfect = _perfect_candidate(grid, rng)
	if not perfect.is_empty():
		_shuffle(perfect, rng)
		last_generation_note = "perfect"
		return perfect
	var trio: Array[Dictionary] = []
	var g := grid
	for step in range(3):
		var pick := _needed_piece(g, trio, rng)
		if pick.is_empty():
			break
		trio.append(pick["shape"])
		g = place_and_clear(g, get_offsets(pick["shape"]), pick["spot"].x, pick["spot"].y)
	if trio.size() < 3 or not can_place_all(grid, trio):
		return []
	_shuffle(trio, rng)
	last_generation_note = "needed"
	return trio

static func _needed_piece(g: PackedByteArray, taken: Array, rng: RandomNumberGenerator) -> Dictionary:
	var counts := _line_counts(g)
	# First the shapes that clear a line somewhere (cheap: line counts only)
	var pool: Array = []
	for s in SHAPES:
		if s["id"] == "dot_1x1":
			continue
		var offsets := get_offsets(s)
		var b := get_bounds(s["cells"])
		var best_lines := 0
		var spot := Vector2i(-1, -1)
		for y in range(GRID_N - b.size.y + 1):
			for x in range(GRID_N - b.size.x + 1):
				var lines := _lines_with_counts(counts, s, x, y)
				if lines > best_lines and _fits_at(g, offsets, x, y):
					best_lines = lines
					spot = Vector2i(x, y)
		if best_lines > 0:
			var repeat: float = 0.35 if taken.has(s) else 1.0
			pool.append({"shape": s, "spot": spot, "w": float(SHAPE_BASE_WEIGHTS.get(s["id"], 1.0)) * (1.0 + 1.5 * best_lines) * repeat})
	# Nothing clears: a builder that sits snugly and leaves rows/columns close to full
	if pool.is_empty():
		var cells := 0
		for v in g:
			cells += v
		var crowded: bool = float(cells) / (GRID_N * GRID_N) > NEED_CROWDED
		for s in SHAPES:
			if s["id"] == "dot_1x1":
				continue
			var offsets := get_offsets(s)
			var b := get_bounds(s["cells"])
			var best := -INF
			var spot := Vector2i(-1, -1)
			for y in range(GRID_N - b.size.y + 1):
				for x in range(GRID_N - b.size.x + 1):
					if not _fits_at(g, offsets, x, y):
						continue
					var v: float = _snugness(g, offsets, x, y) * 2.0 - _deficit_after(counts, s, x, y) * 0.05
					if v > best:
						best = v
						spot = Vector2i(x, y)
			if spot.x >= 0:
				var size_pen: float = 0.12 * offsets.size() if crowded else 0.0
				pool.append({"shape": s, "spot": spot, "w": (best - size_pen) * (0.35 if taken.has(s) else 1.0)})
	if pool.is_empty():
		return {}
	pool.sort_custom(func(a, b): return a["w"] > b["w"])
	return pool[rng.randi() % mini(NEED_TOP, pool.size())]

static func _multi_clear_shapes(grid: PackedByteArray) -> Array[Dictionary]:
	var counts := _line_counts(grid)
	var found: Array[Dictionary] = []
	for s in SHAPES:
		if s["id"] == "dot_1x1":
			continue
		var offsets := get_offsets(s)
		var b := get_bounds(s["cells"])
		var hit := false
		for y in range(GRID_N - b.size.y + 1):
			for x in range(GRID_N - b.size.x + 1):
				if not hit and _lines_with_counts(counts, s, x, y) >= 2 and _fits_at(grid, offsets, x, y):
					hit = true
		if hit:
			found.append(s)
	return found

static func _chain_trio(grid: PackedByteArray, rng: RandomNumberGenerator) -> Array[Dictionary]:
	# The pieces the board needs, in order: each one clears a line on the board the previous one
	# left (best spot per shape, picked by base weight x lines). Topped up with free picks.
	var trio: Array[Dictionary] = []
	var g := grid
	for step in range(3):
		var counts := _line_counts(g)
		var options: Array = []
		var weights: Array[float] = []
		var total := 0.0
		for s in SHAPES:
			if s["id"] == "dot_1x1":
				continue
			var offsets := get_offsets(s)
			var b := get_bounds(s["cells"])
			var best_lines := 0
			var spot := Vector2i.ZERO
			for y in range(GRID_N - b.size.y + 1):
				for x in range(GRID_N - b.size.x + 1):
					var lines := _lines_with_counts(counts, s, x, y)
					if lines > best_lines and _fits_at(g, offsets, x, y):
						best_lines = lines
						spot = Vector2i(x, y)
			if best_lines > 0:
				var w: float = float(SHAPE_BASE_WEIGHTS.get(s["id"], 1.0)) * (1.0 + best_lines)
				options.append({"shape": s, "spot": spot})
				weights.append(w)
				total += w
		if options.is_empty():
			break
		var roll := rng.randf() * total
		var k := 0
		while k < options.size() - 1 and roll >= weights[k]:
			roll -= weights[k]
			k += 1
		var pick: Dictionary = options[k]
		trio.append(pick["shape"])
		g = place_and_clear(g, get_offsets(pick["shape"]), pick["spot"].x, pick["spot"].y)
	if trio.is_empty():
		return []
	var filler := _free_trio(rng)
	while trio.size() < 3:
		trio.append(filler[trio.size()])
	return trio

static func _perfect_candidate(grid: PackedByteArray, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var cells := 0
	for v in grid:
		cells += v
	if cells == 0 or cells > PERFECT_CHANCE_CELLS:
		return []
	var used := _search_perfect(grid)
	if used.is_empty():
		return []
	var trio: Array[Dictionary] = []
	trio.assign(used)
	var filler := _free_trio(rng)
	while trio.size() < 3:
		trio.append(filler[trio.size()])
	if not can_place_all(grid, trio):
		return []
	return trio

static func _free_trio(rng: RandomNumberGenerator) -> Array[Dictionary]:
	# Board-agnostic trio by base weights (at most one large piece) for variety among candidates
	var pool: Array[Dictionary] = []
	var small_pool: Array[Dictionary] = []
	for s in SHAPES:
		if s["id"] == "dot_1x1":
			continue
		pool.append(s)
		if s["category"] != "large":
			small_pool.append(s)
	var trio: Array[Dictionary] = []
	var has_large := false
	for i in range(3):
		var piece: Dictionary = _pick_weighted_shape(small_pool if has_large else pool, SHAPE_BASE_WEIGHTS, rng)
		has_large = has_large or piece["category"] == "large"
		trio.append(piece)
	return trio

static func _variety_bonus(trio: Array) -> float:
	# Three tiny pieces are dull; a mix of sizes and kinds reads as a puzzle
	var sizes := {}
	var smalls := 0
	for s in trio:
		sizes[s["cells"].size()] = true
		if s["cells"].size() <= 2:
			smalls += 1
	return sizes.size() * 8.0 - maxi(0, smalls - 1) * 15.0

static func evaluate_fun(grid: PackedByteArray, trio: Array, flow: bool = false, grace_left: int = -1) -> Dictionary:
	# Beam search over the three placements. Per move:
	#   lines^2 * 30         multi-line clears feel big
	#   +20                  clear right after a clear (chain within the set)
	#   +6 per cell          snug fit (>= 85% of the piece's outer edges touch blocks or walls)
	#   +12                  exact fit: every outer edge is covered (fills a hole completely)
	#   +200                 perfect clear
	# The search follows the score above: it is how a player reads the tray (take the clears and
	# snug fits in front of you). flow (the dealer) then also judges where that play leads, so it
	# picks sets whose obvious play keeps the combo going and empties the board.
	# grace_left: moves before the running combo breaks (-1: no combo).
	#   +25 per clearing move, -120 if the combo breaks, +150 more for a perfect clear,
	#   and after the set: +8 per grace move left, +10 per line at 6-7/8 (up to 4) for the next
	#   set, +6 per block under 40 still needed to empty the board by whole rows or columns
	var states: Array = [{"grid": grid, "left": trio.duplicate(), "score": 0.0, "flow": 0.0, "lines": 0, "chain": false, "plan": [], "perfect": false, "grace": grace_left, "broke": false}]
	for depth in range(3):
		var next: Array = []
		for st in states:
			var seen := {}
			for i in range(st["left"].size()):
				var shape: Dictionary = st["left"][i]
				if seen.has(shape["id"]):
					continue
				seen[shape["id"]] = true
				var rest: Array = st["left"].duplicate()
				rest.remove_at(i)
				var offsets := get_offsets(shape)
				var b := get_bounds(shape["cells"])
				var g: PackedByteArray = st["grid"]
				if not st.has("counts"):
					st["counts"] = _line_counts(g)
				for y in range(GRID_N - b.size.y + 1):
					for x in range(GRID_N - b.size.x + 1):
						if not _fits_at(g, offsets, x, y):
							continue
						var lines := _lines_with_counts(st["counts"], shape, x, y)
						var snug := _snugness(g, offsets, x, y)
						if lines == 0 and snug < 0.5 and next.size() >= FUN_BEAM * 6:
							continue # plenty of options already; skip loose placements in open space
						var g2 := place_and_clear(g, offsets, x, y) if lines > 0 else _place_only(g, offsets, x, y)
						var s: float = st["score"] + lines * lines * 30.0
						if lines > 0 and st["chain"]:
							s += 20.0
						if snug >= 0.85:
							s += 6.0 * offsets.size()
						if snug >= 0.999 and offsets.size() >= 2:
							s += 12.0
						var emptied: bool = lines > 0 and _is_empty(g2)
						if emptied:
							s += 200.0
						var grace: int = st["grace"]
						var f: float = st["flow"]
						var broke: bool = st["broke"]
						if flow:
							if lines > 0:
								f += 25.0
								grace = COMBO_GRACE
							elif grace > 0:
								grace -= 1
								if grace == 0:
									f -= 120.0
									grace = -1
									broke = true
							if emptied:
								f += 150.0
						next.append({"grid": g2, "left": rest, "score": s, "flow": f, "lines": st["lines"] + lines, "chain": lines > 0,
							"plan": st["plan"] + [{"id": shape["id"], "x": x, "y": y}], "perfect": st["perfect"] or emptied, "grace": grace, "broke": broke})
		if next.is_empty():
			break
		next.sort_custom(func(a, b): return a["score"] > b["score"])
		states = next.slice(0, FUN_BEAM)
	var best: Dictionary = states[0]
	var total: float = best["score"]
	if flow:
		total += best["flow"] + _flow_outlook(best["grid"], best["grace"])
	return {"score": total, "lines": best["lines"], "plan": best["plan"], "perfect": best["perfect"], "broke": best["broke"]}

static func _flow_outlook(grid: PackedByteArray, grace: int) -> float:
	# How well the board left after a set sets up the next one
	var s := 0.0
	if grace > 0:
		s += grace * 8.0
	var counts := _line_counts(grid)
	var near := 0
	for i in range(GRID_N):
		for k in range(2):
			var n: int = counts[k][i]
			if n >= 6 and n < GRID_N:
				near += 1
	s += mini(near, 4) * 10.0
	# Few cells are not enough for a perfect clear: they must sit in a few lines that can be filled
	s += maxf(0.0, 40.0 - _empty_deficit(counts)) * 6.0
	return s

# Blocks needed to empty the board by filling whole rows (or whole columns): the smaller, the
# closer the board is to a perfect clear
static func _empty_deficit(counts: Array) -> int:
	var by_rows := 0
	var by_cols := 0
	for i in range(GRID_N):
		if counts[0][i] > 0:
			by_rows += GRID_N - counts[0][i]
		if counts[1][i] > 0:
			by_cols += GRID_N - counts[1][i]
	return mini(by_rows, by_cols)

# Perfect clear chance (classic): when only a few blocks are left, sometimes deal a set that can
# empty the whole board. Emptying the board pays the perfect clear bonus and moves the screen to
# the next theme (BoardThemes), so it should happen now and then, not almost never.
const PERFECT_CHANCE_CELLS: int = 24
const PERFECT_CHANCE: float = 0.5
const PERFECT_BEAM: int = 8
# Most cells one piece can add; a state that still needs more than the pieces left can add is dropped
const PERFECT_PIECE_MAX: int = 9

static var perfect_search_usec: int = 0

# always: skip the chance roll (the first set after a start board that can be emptied)
static func get_perfect_trio(board, rng: RandomNumberGenerator = null, always: bool = false) -> Array[Dictionary]:
	if rng == null:
		rng = get_default_rng()
	var grid: PackedByteArray = board.get_occupancy_snapshot()
	var cells := 0
	for v in grid:
		cells += v
	if cells == 0 or cells > PERFECT_CHANCE_CELLS or (not always and rng.randf() >= PERFECT_CHANCE):
		return []
	var t0 := Time.get_ticks_usec()
	var used := _search_perfect(grid)
	perfect_search_usec = Time.get_ticks_usec() - t0
	if used.is_empty():
		return []
	# Emptied in fewer than three pieces: the rest are small pieces for the fresh board
	var trio: Array[Dictionary] = []
	trio.assign(used)
	var filler := _free_trio(rng)
	while trio.size() < 3:
		trio.append(filler[trio.size()])
	_shuffle(trio, rng)
	last_generation_note = "perfect"
	return trio

static func _search_perfect(grid: PackedByteArray) -> Array:
	# Beam search over any shapes (not a fixed set) for up to three placements that leave the
	# board empty. States closer to empty go first: fewest blocks still needed to fill whole rows
	# (or whole columns), which favours pieces that line up over pieces that are merely small.
	# Returns the shapes used, or [].
	var beam: Array = [{"grid": grid, "shapes": []}]
	for depth in range(3):
		var room: int = (2 - depth) * PERFECT_PIECE_MAX
		var moves: Array = []
		for bi in range(beam.size()):
			var g: PackedByteArray = beam[bi]["grid"]
			var counts := _line_counts(g)
			for s in SHAPES:
				var offsets := get_offsets(s)
				var b := get_bounds(s["cells"])
				for y in range(GRID_N - b.size.y + 1):
					for x in range(GRID_N - b.size.x + 1):
						if not _fits_at(g, offsets, x, y):
							continue
						var lines := _lines_with_counts(counts, s, x, y)
						var deficit: int
						var g2 := PackedByteArray()
						if lines > 0:
							g2 = place_and_clear(g, offsets, x, y)
							if _is_empty(g2):
								return beam[bi]["shapes"] + [s]
							deficit = _empty_deficit(_line_counts(g2))
						else:
							deficit = _deficit_after(counts, s, x, y)
						if deficit > room:
							continue
						moves.append({"from": bi, "shape": s, "x": x, "y": y, "deficit": deficit, "grid": g2})
		if moves.is_empty():
			return []
		moves.sort_custom(func(a, c): return a["deficit"] < c["deficit"])
		var next: Array = []
		for m in moves.slice(0, PERFECT_BEAM):
			var g2: PackedByteArray = m["grid"]
			if g2.is_empty():
				g2 = _place_only(beam[m["from"]]["grid"], get_offsets(m["shape"]), m["x"], m["y"])
			next.append({"grid": g2, "shapes": beam[m["from"]]["shapes"] + [m["shape"]]})
		beam = next
	return []

static func _deficit_after(counts: Array, shape: Dictionary, bx: int, by: int) -> int:
	# _empty_deficit after placing a shape that clears nothing, from the line counts alone
	var rc: PackedInt32Array = counts[0].duplicate()
	var cc: PackedInt32Array = counts[1].duplicate()
	var prof := _line_profile(shape)
	for r in prof["rows"]:
		rc[by + r[0]] += r[1]
	for c in prof["cols"]:
		cc[bx + c[0]] += c[1]
	return _empty_deficit([rc, cc])

static func _snugness(grid: PackedByteArray, offsets: Array[Vector2i], bx: int, by: int) -> float:
	# Share of the piece's outer edges that touch a filled cell or the board edge
	var own := {}
	for o in offsets:
		own[Vector2i(bx + o.x, by + o.y)] = true
	var touching := 0
	var total := 0
	for cell in own:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cell + d
			if own.has(nb):
				continue
			total += 1
			if nb.x < 0 or nb.y < 0 or nb.x >= GRID_N or nb.y >= GRID_N or grid[nb.x + nb.y * GRID_N] != 0:
				touching += 1
	return float(touching) / float(max(1, total))

static func _place_only(grid: PackedByteArray, offsets: Array[Vector2i], bx: int, by: int) -> PackedByteArray:
	var g := grid.duplicate()
	for o in offsets:
		g[(bx + o.x) + (by + o.y) * GRID_N] = 1
	return g

static func _is_empty(grid: PackedByteArray) -> bool:
	for v in grid:
		if v != 0:
			return false
	return true

# =========================================================
# Classic start pattern: a few real pieces pre-placed so the first moves can already clear lines
# =========================================================
const START_PIECES_MIN: int = 3
const START_PIECES_MAX: int = 5
const START_CELLS_MIN: int = 12
const START_CELLS_MAX: int = 22
const START_NEAR_LINES_MIN: int = 2   # rows/columns left 5-7/8 full
const START_ATTEMPTS: int = 300
const START_HOLE_CHANCE: float = 0.5
const START_CLEAN_CHANCE: float = 0.34  # hole boards with nothing else on them (about 1 game in 6)  # share of games that open with a double-clear "just fits" hole
# Shapes that span exactly two rows (as rows) or two columns (as columns) and make a readable hole
const HOLE_SHAPES_ROWS: Array[String] = ["square_2x2", "line_2_v", "corner_2x2_1", "corner_2x2_2", "corner_2x2_3", "corner_2x2_4", "t_1", "t_2", "z_h", "s_h", "l_4_3", "l_4_4"]
const HOLE_SHAPES_COLS: Array[String] = ["square_2x2", "line_2_h", "corner_2x2_1", "corner_2x2_2", "corner_2x2_3", "corner_2x2_4", "t_3", "t_4", "z_v", "s_v", "l_4_1", "l_4_2"]

static func generate_start_pattern(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	# Returns placements [{"shape": Dictionary, "x": int, "y": int}]. Pieces are steered toward rows and
	# columns that are already partly filled, so the board ends up with near-complete lines, never a
	# full one, and still has room for a 3x3.
	if rng == null:
		rng = get_default_rng()
	var pool: Array[Dictionary] = []
	for s in SHAPES:
		if s["category"] != "large" and s["id"] != "dot_1x1":
			pool.append(s)

	# Half the games open with a built hole: two lines filled except for one piece's exact shape,
	# so dropping that piece clears both at once (the "just fits" moment)
	if rng.randf() < START_HOLE_CHANCE:
		for attempt in range(20):
			var built := _build_hole_pattern(pool, rng)
			if not built.is_empty():
				return built
	for attempt in range(START_ATTEMPTS):
		var grid := PackedByteArray()
		grid.resize(GRID_N * GRID_N)
		var placements: Array[Dictionary] = []
		var counts := _line_counts(grid)
		var count: int = rng.randi_range(START_PIECES_MIN, START_PIECES_MAX)
		for i in range(count):
			var shape: Dictionary = pool[rng.randi() % pool.size()]
			var spot := _pick_start_spot(grid, counts, shape, rng)
			if spot.x < 0:
				break
			for o in get_offsets(shape):
				grid[(spot.x + o.x) + (spot.y + o.y) * GRID_N] = 1
				counts[0][spot.y + o.y] += 1
				counts[1][spot.x + o.x] += 1
			placements.append({"shape": shape, "x": spot.x, "y": spot.y})
		if _start_pattern_ok(grid):
			return placements
	return []

static func _build_hole_pattern(pool: Array[Dictionary], rng: RandomNumberGenerator) -> Array[Dictionary]:
	var as_rows: bool = rng.randf() < 0.5
	var hole_ids: Array[String] = HOLE_SHAPES_ROWS if as_rows else HOLE_SHAPES_COLS
	var hole: Dictionary = _shape_by_id(hole_ids[rng.randi() % hole_ids.size()])
	var hb := get_bounds(hole["cells"])
	# Two adjacent lines; the hole sits across them at a random offset
	var line0: int = rng.randi_range(1, GRID_N - 2)
	var along: int = rng.randi_range(0, GRID_N - (hb.size.x if as_rows else hb.size.y))
	var hx: int = along if as_rows else line0
	var hy: int = line0 if as_rows else along
	var hole_cells := {}
	for o in get_offsets(hole):
		hole_cells[Vector2i(hx + o.x, hy + o.y)] = true
	
	var grid := PackedByteArray()
	grid.resize(GRID_N * GRID_N)
	var placements: Array[Dictionary] = []
	# Fill both lines outside the hole with straight pieces (4/3/2/1 long), which drop in like pieces
	for k in range(2):
		var segment_start := -1
		for i in range(GRID_N + 1):
			var cell: Vector2i = Vector2i(i, line0 + k) if as_rows else Vector2i(line0 + k, i)
			var free: bool = i < GRID_N and not hole_cells.has(cell)
			if free and segment_start < 0:
				segment_start = i
			elif not free and segment_start >= 0:
				_fill_segment(placements, grid, as_rows, line0 + k, segment_start, i - segment_start, rng)
				segment_start = -1
	# One or two random pieces elsewhere, never on the hole. Some boards get none: then the piece
	# that fits the hole empties the whole board on the first move (perfect clear, next theme).
	for c in hole_cells:
		grid[c.x + c.y * GRID_N] = 1
	var counts := _line_counts(grid)
	var extras: int = 0 if rng.randf() < START_CLEAN_CHANCE else rng.randi_range(1, 2)
	for i in range(extras):
		var shape: Dictionary = pool[rng.randi() % pool.size()]
		var spot := _pick_start_spot(grid, counts, shape, rng)
		if spot.x < 0:
			break
		for o in get_offsets(shape):
			grid[(spot.x + o.x) + (spot.y + o.y) * GRID_N] = 1
			counts[0][spot.y + o.y] += 1
			counts[1][spot.x + o.x] += 1
		placements.append({"shape": shape, "x": spot.x, "y": spot.y})
	for c in hole_cells:
		grid[c.x + c.y * GRID_N] = 0
	if not _start_pattern_ok(grid) or _max_lines_move(grid, 2) < 2:
		return []
	return placements

static func _fill_segment(placements: Array[Dictionary], grid: PackedByteArray, as_rows: bool, line: int, start: int, length: int, rng: RandomNumberGenerator) -> void:
	var pos := start
	var left := length
	while left > 0:
		var n: int = mini(left, rng.randi_range(3, 4)) if left > 1 else 1
		var id: String = "dot_1x1" if n == 1 else ("line_%d_%s" % [n, "h" if as_rows else "v"])
		var x: int = pos if as_rows else line
		var y: int = line if as_rows else pos
		placements.append({"shape": _shape_by_id(id), "x": x, "y": y})
		for j in range(n):
			grid[(x + (j if as_rows else 0)) + (y + (0 if as_rows else j)) * GRID_N] = 1
		pos += n
		left -= n

static func _shape_by_id(id: String) -> Dictionary:
	for s in SHAPES:
		if s["id"] == id:
			return s
	return {}

static func _max_lines_move(grid: PackedByteArray, cap: int = 99) -> int:
	# Most lines any single non-dot piece can complete in one placement (stops early at cap)
	var counts := _line_counts(grid)
	var best := 0
	for s in SHAPES:
		if s["id"] == "dot_1x1":
			continue
		var offsets := get_offsets(s)
		var b := get_bounds(s["cells"])
		for y in range(GRID_N - b.size.y + 1):
			for x in range(GRID_N - b.size.x + 1):
				if _fits_at(grid, offsets, x, y):
					best = maxi(best, _lines_with_counts(counts, s, x, y))
					if best >= cap:
						return best
	return best

static var _profile_cache: Dictionary = {}

static func _line_profile(shape: Dictionary) -> Dictionary:
	# Cells per row / column offset for a shape: [[offset, cells], ...]
	var id: String = shape["id"]
	if _profile_cache.has(id):
		return _profile_cache[id]
	var rows := {}
	var cols := {}
	for o in get_offsets(shape):
		rows[o.y] = rows.get(o.y, 0) + 1
		cols[o.x] = cols.get(o.x, 0) + 1
	var prof := {"rows": rows.keys().map(func(k): return [k, rows[k]]), "cols": cols.keys().map(func(k): return [k, cols[k]])}
	_profile_cache[id] = prof
	return prof

static func _line_counts(grid: PackedByteArray) -> Array:
	var rc := PackedInt32Array()
	var cc := PackedInt32Array()
	rc.resize(GRID_N)
	cc.resize(GRID_N)
	for y in range(GRID_N):
		for x in range(GRID_N):
			if grid[x + y * GRID_N] != 0:
				rc[y] += 1
				cc[x] += 1
	return [rc, cc]

static func _lines_with_counts(counts: Array, shape: Dictionary, bx: int, by: int) -> int:
	var prof := _line_profile(shape)
	var rc: PackedInt32Array = counts[0]
	var cc: PackedInt32Array = counts[1]
	var n := 0
	for r in prof["rows"]:
		if rc[by + r[0]] + r[1] == GRID_N:
			n += 1
	for c in prof["cols"]:
		if cc[bx + c[0]] + c[1] == GRID_N:
			n += 1
	return n

static func _pick_start_spot(grid: PackedByteArray, counts: Array, shape: Dictionary, rng: RandomNumberGenerator) -> Vector2i:
	# Weighted random spot: favour cells that push rows/columns toward 5-7/8 without filling them
	var offsets := get_offsets(shape)
	var bounds := get_bounds(shape["cells"])
	var prof := _line_profile(shape)
	var rc: PackedInt32Array = counts[0]
	var cc: PackedInt32Array = counts[1]
	var spots: Array[Vector2i] = []
	var weights: Array[float] = []
	var total := 0.0
	for y in range(GRID_N - bounds.size.y + 1):
		for x in range(GRID_N - bounds.size.x + 1):
			if not _fits_at(grid, offsets, x, y):
				continue
			var w := 1.0
			var full := false
			for r in prof["rows"]:
				var n: int = rc[y + r[0]] + r[1]
				if n >= GRID_N:
					full = true
				elif n >= 4:
					w += float(n - 3) * 1.5
			for c in prof["cols"]:
				var n: int = cc[x + c[0]] + c[1]
				if n >= GRID_N:
					full = true
				elif n >= 4:
					w += float(n - 3) * 1.5
			if full:
				continue
			spots.append(Vector2i(x, y))
			weights.append(w)
			total += w
	if spots.is_empty():
		return Vector2i(-1, -1)
	var roll := rng.randf() * total
	for i in range(spots.size()):
		roll -= weights[i]
		if roll <= 0.0:
			return spots[i]
	return spots[-1]

static func _start_pattern_ok(grid: PackedByteArray) -> bool:
	var cells := 0
	for v in grid:
		cells += v
	if cells < START_CELLS_MIN or cells > START_CELLS_MAX:
		return false
	var near := 0
	for i in range(GRID_N):
		var r := _row_count(grid, i)
		var c := _col_count(grid, i)
		if r >= GRID_N or c >= GRID_N:
			return false
		if r >= 5:
			near += 1
		if c >= 5:
			near += 1
	if near < START_NEAR_LINES_MIN:
		return false
	# Some piece must be able to finish a line on the very first move
	if not _has_clearing_move(grid):
		return false
	# Leave room for the biggest piece
	var big: Dictionary = SHAPES.filter(func(s): return s["id"] == "square_3x3")[0]
	var offsets := get_offsets(big)
	for y in range(GRID_N - 2):
		for x in range(GRID_N - 2):
			if _fits_at(grid, offsets, x, y):
				return true
	return false

static func _has_clearing_move(grid: PackedByteArray) -> bool:
	return _max_lines_move(grid, 1) >= 1

static func _row_count(grid: PackedByteArray, y: int) -> int:
	var n := 0
	for x in range(GRID_N):
		n += grid[x + y * GRID_N]
	return n

static func _col_count(grid: PackedByteArray, x: int) -> int:
	var n := 0
	for y in range(GRID_N):
		n += grid[x + y * GRID_N]
	return n

static func get_seeded_trio(rng: RandomNumberGenerator) -> Array[Dictionary]:
	# Board-independent trio for the daily challenge: the same seed yields the same
	# sequence for every player. Weighted by base weights, at most one large piece per trio.
	var pool: Array[Dictionary] = []
	var small_pool: Array[Dictionary] = []
	for s in SHAPES:
		if s["id"] == "dot_1x1":
			continue
		pool.append(s)
		if s["category"] != "large":
			small_pool.append(s)
	
	var trio: Array[Dictionary] = []
	var has_large := false
	for i in range(3):
		var piece: Dictionary = _pick_weighted_shape(small_pool if has_large else pool, SHAPE_BASE_WEIGHTS, rng)
		if piece["category"] == "large":
			has_large = true
		trio.append(piece)
	_shuffle(trio, rng)
	last_generation_note = "seeded"
	return trio

static func get_balanced_trio(rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	if rng == null:
		rng = get_default_rng()
	# Returns 3 balanced pieces (at least 1 small/medium, at most 1 large)
	var smalls: Array[Dictionary] = []
	var mediums: Array[Dictionary] = []
	var larges: Array[Dictionary] = []
	
	for s in SHAPES:
		match s["category"]:
			"small": smalls.append(s)
			"medium": mediums.append(s)
			"large": larges.append(s)
	
	var result: Array[Dictionary] = []
	
	# Slot 1: small or medium
	if rng.randf() < 0.4:
		result.append(smalls[rng.randi() % smalls.size()])
	else:
		result.append(mediums[rng.randi() % mediums.size()])
	
	# Slot 2: medium or large (35% large)
	if rng.randf() < 0.35:
		result.append(larges[rng.randi() % larges.size()])
	else:
		result.append(mediums[rng.randi() % mediums.size()])
	
	# Slot 3: small or medium
	if rng.randf() < 0.5:
		result.append(smalls[rng.randi() % smalls.size()])
	else:
		result.append(mediums[rng.randi() % mediums.size()])
	
	# Shuffle order so slots feel natural
	_shuffle(result, rng)
	return result

static func get_bounds(cells: Array) -> Rect2i:
	if cells.is_empty():
		return Rect2i(0, 0, 0, 0)
	var min_x = cells[0].x
	var max_x = cells[0].x
	var min_y = cells[0].y
	var max_y = cells[0].y
	for c in cells:
		min_x = mini(min_x, c.x)
		max_x = maxi(max_x, c.x)
		min_y = mini(min_y, c.y)
		max_y = maxi(max_y, c.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
