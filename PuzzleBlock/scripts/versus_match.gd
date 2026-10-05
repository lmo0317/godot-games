class_name VersusMatch
extends Control
# Attack battle against the computer. Both sides play their own board at the same time (same
# start board, same kind of trays). Clearing lines makes an attack (more for more lines, a combo
# and a perfect clear). An attack first cancels what is waiting to hit the attacker; the rest
# goes into the other side's waiting queue and falls as grey stones on that board the next time
# that side places a piece without clearing. A side with nothing to place loses.
# This node is the strip in the header (player, waiting attacks, the computer's mini board) and
# runs the computer's board in real time; MainGame runs the player's board and calls in here.

signal cpu_lost
signal player_hit(amount: int)

const ME: int = 0
const CPU: int = 1
const CPU_AVATAR: int = 5
const MAX_DROP: int = 8           # stones that fall in one go; the rest keep waiting
const PRESSURE: float = 0.3       # tray generator pressure, the same for both sides
const LEVELS: Array[Dictionary] = [
	{"id": "easy", "name": "쉬움", "desc": "느리게, 대충 둠", "interval": 3.2},
	{"id": "normal", "name": "보통", "desc": "줄을 잘 지움", "interval": 2.2},
	{"id": "hard", "name": "어려움", "desc": "빠르게 콤보로 공격", "interval": 1.5},
]
const STONE_COLOR := Color(0.55, 0.59, 0.68)
const ATTACK_COLOR := Color(1.0, 0.42, 0.3)

var level: String = "normal"
var running: bool = false
var paused: bool = false
var incoming: Array[int] = [0, 0]   # stones waiting to fall on each side
var sent: Array[int] = [0, 0]       # attack sent over the match
var rng := RandomNumberGenerator.new()

var cpu_grid := PackedByteArray()
var cpu_tray: Array = []
var cpu_combo: int = 0
var cpu_grace: int = 0
var _clock: float = 0.0
var _sim_board: Board

var _mini: MiniBoard
var _gauges: Array[HBoxContainer] = []
var _gauge_labels: Array[Label] = []
var _cards: Array[Panel] = []
var _avatars: Array[TextureRect] = []
var _names: Array[Label] = []

# A shape standing in for a tray piece (the move search only reads shape_data)
class ShapeRef:
	var shape_data: Dictionary
	func _init(s: Dictionary) -> void:
		shape_data = s

# The computer's board, drawn small
class MiniBoard:
	extends Control
	const CELL: float = 12.0
	const GAP: float = 1.0
	var grid := PackedByteArray()
	var flash: float = 0.0
	func _init() -> void:
		custom_minimum_size = Vector2.ONE * (CELL * 8 + GAP * 7)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2(-4, -4), size + Vector2(8, 8)), Color(0.03, 0.05, 0.1, 0.9))
		for y in range(8):
			for x in range(8):
				var v: int = grid[x + y * 8] if grid.size() == 64 else 0
				var col: Color = Color(1, 1, 1, 0.06)
				if v == 1:
					col = Color(0.45, 0.7, 1.0)
				elif v == 2:
					col = STONE_COLOR
				draw_rect(Rect2(Vector2(x, y) * (CELL + GAP), Vector2(CELL, CELL)), col)
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash * 0.5))

static func level_name(id: String) -> String:
	for l in LEVELS:
		if l["id"] == id:
			return l["name"]
	return id

static func level_info(id: String) -> Dictionary:
	for l in LEVELS:
		if l["id"] == id:
			return l
	return LEVELS[1]

# Attack for a clear: lines at once, the mover's combo after this clear, perfect clear
static func attack_for(lines: int, combo: int, perfect: bool) -> int:
	if lines <= 0:
		return 0
	var a: int = [0, 1, 3, 5, 7][mini(lines, 4)] + maxi(0, lines - 4) * 2
	if combo >= 2:
		a += mini(combo - 1, 5)
	if perfect:
		a += 6
	return a

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(42, 96)
	size = Vector2(636, 120)
	for side in [ME, CPU]:
		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(0 if side == ME else 330, 0)
		card.size = Vector2(270 if side == ME else 306, 120)
		card.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.SURFACE, 0.85), UIKit.BORDER, 20, 2))
		add_child(card)
		_cards.append(card)
		var av := TextureRect.new()
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.position = Vector2(14, 14)
		av.size = Vector2(36, 36)
		card.add_child(av)
		_avatars.append(av)
		var name_l := UIKit.label("", UIKit.TYPE_SMALL, UIKit.TEXT)
		name_l.position = Vector2(58, 18)
		name_l.size = Vector2(110 if side == CPU else 200, 26)
		name_l.clip_text = true
		card.add_child(name_l)
		_names.append(name_l)
		var cap := UIKit.label("들어올 공격", UIKit.TYPE_CAPTION, UIKit.MUTED)
		cap.position = Vector2(14, 58)
		cap.size = Vector2(110, 22)
		card.add_child(cap)
		var count := UIKit.label("0", UIKit.TYPE_CAPTION, UIKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		count.position = Vector2(110 if side == CPU else 200, 58)
		count.size = Vector2(56, 22)
		card.add_child(count)
		_gauge_labels.append(count)
		var gauge := HBoxContainer.new()
		gauge.add_theme_constant_override("separation", 3)
		gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauge.position = Vector2(14, 86)
		gauge.size = Vector2(152 if side == CPU else 242, 18)
		card.add_child(gauge)
		var pips: int = 8 if side == CPU else 12
		for i in range(pips):
			var pip := Panel.new()
			pip.custom_minimum_size = Vector2(16, 16)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			gauge.add_child(pip)
		_gauges.append(gauge)
	_mini = MiniBoard.new()
	_mini.position = Vector2(184, 9)
	_cards[CPU].add_child(_mini)
	var vs := UIKit.label("VS", 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vs.position = Vector2(270, 38)
	vs.size = Vector2(60, 44)
	add_child(vs)
	# Hidden board used only so the computer's trays come from the same generator as the player's
	_sim_board = preload("res://scenes/board.tscn").instantiate()
	_sim_board.visible = false
	_sim_board.position = Vector2(-5000, -5000)
	add_child(_sim_board)

# start_cells: board indexes filled at the start (the same pattern as the player's board)
func begin(lvl: String, player_name: String, player_avatar: Texture2D, start_cells: Array) -> void:
	level = lvl
	running = false
	paused = false
	incoming = [0, 0]
	sent = [0, 0]
	cpu_combo = 0
	cpu_grace = 0
	_clock = 0.0
	rng.randomize()
	cpu_grid = PackedByteArray()
	cpu_grid.resize(64)
	for i in start_cells:
		cpu_grid[i] = 1
	cpu_tray = []
	_names[ME].text = player_name
	_names[CPU].text = "컴퓨터"
	_avatars[ME].texture = player_avatar
	_avatars[CPU].texture = LeaderboardManager.get_avatar_texture(CPU_AVATAR)
	_refresh()

func start() -> void:
	running = true
	_clock = 0.0

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if _mini.flash > 0.0:
		_mini.flash = maxf(0.0, _mini.flash - delta * 3.0)
		_mini.queue_redraw()
	if not running or paused or not visible:
		return
	_clock += delta
	if _clock >= float(level_info(level)["interval"]):
		_clock = 0.0
		_cpu_step()

# =========================================================
# Player side (called by MainGame)
# =========================================================

# The player cleared lines: cancel what waits for the player, send the rest at the computer
func player_cleared(lines: int, combo: int, perfect: bool, from_global: Vector2) -> void:
	var atk: int = attack_for(lines, combo, perfect)
	if atk <= 0:
		return
	var cancel: int = mini(atk, incoming[ME])
	incoming[ME] -= cancel
	var rest: int = atk - cancel
	sent[ME] += atk
	_refresh()
	if rest > 0:
		var to: Vector2 = _mini.global_position + _mini.size * 0.5
		_fly(from_global, to, rest, UIKit.CYAN, func():
			incoming[CPU] += rest
			_refresh())

# The player placed without clearing: how many stones fall on the player's board now
func take_player_drop() -> int:
	var n: int = mini(incoming[ME], MAX_DROP)
	incoming[ME] -= n
	_refresh()
	return n

# =========================================================
# Computer side
# =========================================================

func _cpu_step() -> void:
	if cpu_tray.all(func(p): return p == null):
		_deal_cpu()
	var move: Dictionary = choose_move(cpu_grid, cpu_tray, cpu_combo)
	if move.is_empty():
		running = false
		cpu_lost.emit()
		return
	cpu_tray[move["slot"]] = null
	cpu_grid = move["grid"]
	var lines: int = move["lines"]
	if lines > 0:
		cpu_combo += 1
		cpu_grace = 3
		var atk: int = attack_for(lines, cpu_combo, _free(cpu_grid) == 64)
		var cancel: int = mini(atk, incoming[CPU])
		incoming[CPU] -= cancel
		var rest: int = atk - cancel
		sent[CPU] += atk
		_mini.flash = 1.0
		if rest > 0:
			var from: Vector2 = _mini.global_position + _mini.size * 0.5
			_fly(from, _gauges[ME].global_position + Vector2(90, 8), rest, ATTACK_COLOR, func():
				if not running:
					return
				incoming[ME] += rest
				_refresh()
				player_hit.emit(rest))
	else:
		if cpu_combo > 0:
			cpu_grace -= 1
			if cpu_grace <= 0:
				cpu_combo = 0
		var n: int = mini(incoming[CPU], MAX_DROP)
		incoming[CPU] -= n
		cpu_grid = drop_stones(cpu_grid, n, rng)
	_mini.grid = cpu_grid
	_mini.queue_redraw()
	_refresh()
	# Lose right away when the pieces left cannot go anywhere
	var left: Array = cpu_tray.filter(func(p): return p != null)
	if not left.is_empty():
		var any := false
		for p in left:
			any = any or not _moves(cpu_grid, [p]).is_empty()
		if not any:
			running = false
			cpu_lost.emit()

func _deal_cpu() -> void:
	for x in range(8):
		for y in range(8):
			_sim_board.grid_state[x][y] = "blue" if cpu_grid[x + y * 8] != 0 else null
	var trio: Array = BlockData.get_adaptive_trio(_sim_board, cpu_combo, 0, maxi(cpu_grace, 1), rng, PRESSURE)
	cpu_tray = trio.map(func(s): return ShapeRef.new(s))

# Stones fall on random empty cells, never completing a row or column. Value 2 marks a stone.
static func drop_stones(grid: PackedByteArray, count: int, r: RandomNumberGenerator) -> PackedByteArray:
	var g := grid.duplicate()
	for i in range(count):
		var spots: Array[int] = []
		for idx in range(64):
			if g[idx] != 0:
				continue
			var x: int = idx % 8
			var y: int = idx / 8
			var row_left := 0
			var col_left := 0
			for k in range(8):
				row_left += 1 if g[k + y * 8] == 0 else 0
				col_left += 1 if g[x + k * 8] == 0 else 0
			if row_left > 1 and col_left > 1:
				spots.append(idx)
		if spots.is_empty():
			break
		g[spots[r.randi() % spots.size()]] = 2
	return g

# =========================================================
# Computer's move choice on its own board
# =========================================================

# tray: Array of pieces (anything with shape_data) or null. Returns {"slot", "x", "y", "grid",
# "lines"} or {} when nothing fits.
func choose_move(grid: PackedByteArray, tray: Array, combo: int) -> Dictionary:
	var moves: Array = _moves(grid, tray)
	if moves.is_empty():
		return {}
	var rest_shapes := func(slot: int) -> Array:
		var out: Array = []
		for i in range(tray.size()):
			if i != slot and tray[i] != null:
				out.append(tray[i].shape_data)
		return out
	for m in moves:
		var c: int = combo + 1 if m["lines"] > 0 else combo
		var atk: int = attack_for(m["lines"], c, _free(m["grid"]) == 64)
		m["value"] = atk * 12.0 + m["lines"] * 4.0 + m["snug"] * 3.0 + _free(m["grid"]) * 0.15
	match level:
		"easy":
			# Any spot that leaves the rest placeable, a clear only now and then
			moves.shuffle()
			for m in moves:
				if m["lines"] > 0 and rng.randf() < 0.4:
					return m
				if BlockData.can_place_all(m["grid"], rest_shapes.call(m["slot"]), 200):
					return m
			return moves[0]
		"hard":
			# Also plan the next piece: the best pair of moves, keeping the rest placeable
			moves.sort_custom(func(a, b): return a["value"] > b["value"])
			var best: Dictionary = {}
			var best_v: float = -INF
			for k in range(mini(moves.size(), 12)):
				var m: Dictionary = moves[k]
				var rest: Array = tray.duplicate()
				rest[m["slot"]] = null
				var v: float = m["value"]
				if not BlockData.can_place_all(m["grid"], rest_shapes.call(m["slot"]), 400):
					v -= 1000.0
				else:
					var follow: Array = _moves(m["grid"], rest)
					var c2: int = combo + 1 if m["lines"] > 0 else combo
					var f_best := 0.0
					for f in follow:
						var fc: int = c2 + 1 if f["lines"] > 0 else c2
						f_best = maxf(f_best, attack_for(f["lines"], fc, false) * 12.0 + f["lines"] * 4.0 + f["snug"] * 3.0 + _free(f["grid"]) * 0.15)
					v += f_best * 0.7
				if v > best_v:
					best_v = v
					best = m
			return best
		_:
			for m in moves:
				m["value"] += rng.randf() * 4.0
			moves.sort_custom(func(a, b): return a["value"] > b["value"])
			for m in moves:
				if BlockData.can_place_all(m["grid"], rest_shapes.call(m["slot"]), 200):
					return m
			return moves[0]

func _moves(grid: PackedByteArray, tray: Array) -> Array:
	var out: Array = []
	var before := 64 - _free(grid)
	for slot in range(tray.size()):
		var piece = tray[slot]
		if piece == null:
			continue
		var offsets: Array[Vector2i] = BlockData.get_offsets(piece.shape_data)
		var b: Rect2i = BlockData.get_bounds(piece.shape_data["cells"])
		for y in range(Board.GRID_SIZE - b.size.y + 1):
			for x in range(Board.GRID_SIZE - b.size.x + 1):
				var fits := true
				for o in offsets:
					if grid[(x + o.x) + (y + o.y) * Board.GRID_SIZE] != 0:
						fits = false
						break
				if not fits:
					continue
				var after_grid: PackedByteArray = BlockData.place_and_clear(grid, offsets, x, y)
				var cleared: int = before + offsets.size() - (64 - _free(after_grid))
				out.append({"slot": slot, "x": x, "y": y, "grid": after_grid, "cells": offsets.size(),
					"lines": _lines_for(cleared), "snug": BlockData._snugness(grid, offsets, x, y)})
	return out

static func _free(grid: PackedByteArray) -> int:
	var n := 0
	for v in grid:
		if v == 0:
			n += 1
	return n

static func _lines_for(cleared: int) -> int:
	if cleared <= 0:
		return 0
	for rows in range(0, 9):
		for cols in range(0, 9):
			if rows + cols > 0 and rows * 8 + cols * 8 - rows * cols == cleared:
				return rows + cols
	return int(ceil(cleared / 8.0))

# =========================================================
# Display
# =========================================================

func _refresh() -> void:
	for side in [ME, CPU]:
		var n: int = incoming[side]
		_gauge_labels[side].text = str(n)
		_gauge_labels[side].add_theme_color_override("font_color", ATTACK_COLOR if n > 0 else UIKit.MUTED)
		var pips: Array = _gauges[side].get_children()
		for i in range(pips.size()):
			var on: bool = i < n
			var col: Color = (ATTACK_COLOR if i < MAX_DROP else Color(1.0, 0.75, 0.3)) if on else Color(1, 1, 1, 0.08)
			pips[i].add_theme_stylebox_override("panel", UIKit.box(col, Color.TRANSPARENT, 4))
		var danger: bool = n >= 4
		_cards[side].add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.SURFACE, 0.85),
			ATTACK_COLOR if danger else UIKit.BORDER, 20, 3 if danger else 2))
	_mini.grid = cpu_grid
	_mini.queue_redraw()

# Glowing shots flying from one place to another; on_arrive runs when the first one lands
func _fly(from: Vector2, to: Vector2, amount: int, col: Color, on_arrive: Callable) -> void:
	var shots: int = clampi(amount, 1, 6)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(shots):
		var s := Sprite2D.new()
		s.texture = preload("res://assets/sprites/sparkle.png")
		s.material = add
		s.modulate = col
		s.scale = Vector2.ONE * 1.4
		s.z_index = 140
		get_tree().root.add_child(s)
		var start: Vector2 = from + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		s.global_position = start
		var mid: Vector2 = (start + to) * 0.5 + Vector2(rng.randf_range(-120, 120), -80)
		var tw := s.create_tween()
		tw.tween_method(func(t: float):
			s.global_position = start.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.5 + i * 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if i == 0:
			tw.tween_callback(on_arrive)
		tw.tween_callback(s.queue_free)
