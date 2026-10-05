class_name VersusMatch
extends Control
# Battle against the computer. Each side solves its own board in peace (nothing ever lands on the
# other board). Clearing lines makes your character hit the other one: more lines, a combo and a
# perfect clear hit harder, and now and then a hit is critical. The computer places one piece on
# its own board each time the player places one, so there is time to think and nothing to wait
# for. Whoever takes the other's HP to 0 wins; a side whose pieces fit nowhere loses.
# This node is the strip in the header (both characters with HP bars, the computer's mini board)
# and plays the computer's board; MainGame runs the player's board and calls in here.

signal cpu_defeated(reason: String)     # "ko" or "stuck"
signal player_defeated(reason: String)  # "ko"

const ME: int = 0
const CPU: int = 1
const CPU_AVATAR: int = 5
const MAX_HP: int = 300
const PRESSURE: float = 0.3       # tray generator pressure, the same for both sides
const CRIT_CHANCE: float = 0.15
const CRIT_MULT: float = 2.0
const LEVELS: Array[Dictionary] = [
	{"id": "easy", "name": "쉬움", "desc": "대충 둠"},
	{"id": "normal", "name": "보통", "desc": "줄을 잘 지움"},
	{"id": "hard", "name": "어려움", "desc": "콤보를 노리고 미리 계획함"},
]
const HIT_COLOR := Color(1.0, 0.42, 0.3)
const MY_COLOR := Color(0.35, 0.8, 1.0)

var level: String = "normal"
var hp: Array[int] = [MAX_HP, MAX_HP]
var dealt: Array[int] = [0, 0]   # damage dealt over the match
var finished: bool = false
var rng := RandomNumberGenerator.new()

var cpu_grid := PackedByteArray()
var cpu_tray: Array = []
var cpu_combo: int = 0
var cpu_grace: int = 0
var _sim_board: Board

var _mini: MiniBoard
var _cards: Array[Panel] = []
var _avatars: Array[TextureRect] = []
var _names: Array[Label] = []
var _hp_fill: Array[Panel] = []
var _hp_labels: Array[Label] = []

# A shape standing in for a tray piece (the move search only reads shape_data)
class ShapeRef:
	var shape_data: Dictionary
	func _init(s: Dictionary) -> void:
		shape_data = s

# The computer's board, drawn small
class MiniBoard:
	extends Control
	const CELL: float = 8.0
	const GAP: float = 1.0
	var grid := PackedByteArray()
	var flash: float = 0.0
	func _init() -> void:
		custom_minimum_size = Vector2.ONE * (CELL * 8 + GAP * 7)
		size = custom_minimum_size
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), Color(0.03, 0.05, 0.1, 0.9))
		for y in range(8):
			for x in range(8):
				var v: int = grid[x + y * 8] if grid.size() == 64 else 0
				draw_rect(Rect2(Vector2(x, y) * (CELL + GAP), Vector2(CELL, CELL)),
					Color(0.45, 0.7, 1.0) if v != 0 else Color(1, 1, 1, 0.06))
		if flash > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, flash * 0.5))

static func level_name(id: String) -> String:
	for l in LEVELS:
		if l["id"] == id:
			return l["name"]
	return id

# Damage for a clear before any critical: lines at once, the mover's combo after it, perfect
static func damage_for(lines: int, combo: int, perfect: bool) -> int:
	if lines <= 0:
		return 0
	var d: int = [0, 10, 25, 45, 70][mini(lines, 4)] + maxi(0, lines - 4) * 25
	if combo >= 2:
		d += mini(combo - 1, 6) * 6
	if perfect:
		d += 60
	return d

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(42, 96)
	size = Vector2(636, 120)
	for side in [ME, CPU]:
		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(0 if side == ME else 340, 0)
		card.size = Vector2(296, 120)
		card.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.SURFACE, 0.85), UIKit.BORDER, 20, 2))
		add_child(card)
		_cards.append(card)
		var av := TextureRect.new()
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.size = Vector2(64, 64)
		av.position = Vector2(14, 14)
		av.pivot_offset = av.size * 0.5
		card.add_child(av)
		_avatars.append(av)
		var name_l := UIKit.label("", UIKit.TYPE_SMALL, UIKit.TEXT)
		name_l.position = Vector2(88, 16)
		name_l.size = Vector2(120 if side == CPU else 196, 26)
		name_l.clip_text = true
		card.add_child(name_l)
		_names.append(name_l)
		var bar_bg := Panel.new()
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_bg.position = Vector2(14, 88)
		bar_bg.size = Vector2(268, 18)
		bar_bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.45), Color.TRANSPARENT, 9))
		card.add_child(bar_bg)
		var fill := Panel.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.position = Vector2(2, 2)
		fill.size = Vector2(264, 14)
		fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.35, 0.9, 0.45), Color.TRANSPARENT, 7))
		bar_bg.add_child(fill)
		_hp_fill.append(fill)
		var hp_l := UIKit.label("", UIKit.TYPE_CAPTION, UIKit.TEXT)
		hp_l.position = Vector2(88, 52)
		hp_l.size = Vector2(120, 24)
		card.add_child(hp_l)
		_hp_labels.append(hp_l)
	_mini = MiniBoard.new()
	_mini.position = Vector2(296 - 14 - _mini.size.x, 10)
	_cards[CPU].add_child(_mini)
	var vs := UIKit.label("VS", 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vs.position = Vector2(296, 38)
	vs.size = Vector2(44, 40)
	add_child(vs)
	# Hidden board used only so the computer's trays come from the same generator as the player's
	_sim_board = preload("res://scenes/board.tscn").instantiate()
	_sim_board.visible = false
	_sim_board.position = Vector2(-5000, -5000)
	add_child(_sim_board)

# start_cells: board indexes filled at the start (the same pattern as the player's board)
func begin(lvl: String, player_name: String, player_avatar: Texture2D, start_cells: Array) -> void:
	level = lvl
	hp = [MAX_HP, MAX_HP]
	dealt = [0, 0]
	finished = false
	cpu_combo = 0
	cpu_grace = 0
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
	_avatars[CPU].flip_h = true
	_refresh()

func _process(delta: float) -> void:
	if _mini.flash > 0.0:
		_mini.flash = maxf(0.0, _mini.flash - delta * 3.0)
		_mini.queue_redraw()

# =========================================================
# Turns (called by MainGame)
# =========================================================

# The player cleared lines: the player's character hits the computer
func player_cleared(lines: int, combo: int, perfect: bool, from_global: Vector2) -> void:
	_attack(ME, damage_for(lines, combo, perfect), from_global)

# After each of the player's pieces the computer places one on its own board
func cpu_turn() -> void:
	if finished:
		return
	if cpu_tray.all(func(p): return p == null):
		_deal_cpu()
	var move: Dictionary = choose_move(cpu_grid, cpu_tray, cpu_combo)
	if move.is_empty():
		_end_cpu("stuck")
		return
	cpu_tray[move["slot"]] = null
	cpu_grid = move["grid"]
	_mini.grid = cpu_grid
	_mini.queue_redraw()
	var lines: int = move["lines"]
	if lines > 0:
		cpu_combo += 1
		cpu_grace = 3
		_mini.flash = 1.0
		_attack(CPU, damage_for(lines, cpu_combo, _free(cpu_grid) == 64), _avatars[CPU].global_position + _avatars[CPU].size * 0.5)
	elif cpu_combo > 0:
		cpu_grace -= 1
		if cpu_grace <= 0:
			cpu_combo = 0
	# Pieces left that fit nowhere: the computer is stuck
	var left: Array = cpu_tray.filter(func(p): return p != null)
	if not left.is_empty() and _moves(cpu_grid, left).is_empty():
		_end_cpu("stuck")

func _attack(side: int, base: int, from_global: Vector2) -> void:
	if base <= 0 or finished:
		return
	var crit: bool = rng.randf() < CRIT_CHANCE
	var dmg: int = int(base * CRIT_MULT) if crit else base
	var target: int = 1 - side
	var to: Vector2 = _avatars[target].global_position + _avatars[target].size * 0.5
	_lunge(side)
	_fly(from_global, to, clampi(dmg / 15, 1, 6), MY_COLOR if side == ME else HIT_COLOR, func():
		if finished:
			return
		hp[target] = maxi(0, hp[target] - dmg)
		dealt[side] += dmg
		_hit(target, dmg, crit)
		_refresh()
		if hp[target] <= 0:
			if target == CPU:
				_end_cpu("ko")
			else:
				finished = true
				player_defeated.emit("ko"))

func _end_cpu(reason: String) -> void:
	if finished:
		return
	finished = true
	cpu_defeated.emit(reason)

# The player's board is stuck: MainGame ends the match
func stop() -> void:
	finished = true

func _deal_cpu() -> void:
	for x in range(8):
		for y in range(8):
			_sim_board.grid_state[x][y] = "blue" if cpu_grid[x + y * 8] != 0 else null
	var trio: Array = BlockData.get_adaptive_trio(_sim_board, cpu_combo, 0, maxi(cpu_grace, 1), rng, PRESSURE)
	cpu_tray = trio.map(func(s): return ShapeRef.new(s))

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
		m["value"] = damage_for(m["lines"], c, _free(m["grid"]) == 64) + m["snug"] * 6.0 + _free(m["grid"]) * 0.3
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
					var c2: int = combo + 1 if m["lines"] > 0 else combo
					var f_best := 0.0
					for f in _moves(m["grid"], rest):
						var fc: int = c2 + 1 if f["lines"] > 0 else c2
						f_best = maxf(f_best, damage_for(f["lines"], fc, false) + f["snug"] * 6.0 + _free(f["grid"]) * 0.3)
					v += f_best * 0.7
				if v > best_v:
					best_v = v
					best = m
			return best
		_:
			for m in moves:
				m["value"] += rng.randf() * 6.0
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
		var ratio: float = float(hp[side]) / MAX_HP
		var col: Color = Color(0.35, 0.9, 0.45) if ratio > 0.5 else (Color(1.0, 0.8, 0.25) if ratio > 0.25 else Color(1.0, 0.35, 0.3))
		_hp_fill[side].add_theme_stylebox_override("panel", UIKit.box(col, Color.TRANSPARENT, 7))
		_hp_fill[side].create_tween().tween_property(_hp_fill[side], "size:x", maxf(0.0, 264.0 * ratio), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hp_labels[side].text = "HP %d / %d" % [hp[side], MAX_HP]
	_mini.grid = cpu_grid
	_mini.queue_redraw()

# The attacker's character jumps toward the other side
func _lunge(side: int) -> void:
	var av: TextureRect = _avatars[side]
	var home := Vector2(14, 14)
	var tw := av.create_tween()
	tw.tween_property(av, "position", home + Vector2(18 if side == ME else -18, -6), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(av, "position", home, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# The hit character shakes and flashes; the damage number pops up over it
func _hit(side: int, dmg: int, crit: bool) -> void:
	var av: TextureRect = _avatars[side]
	av.modulate = Color(2.0, 0.8, 0.8)
	var tw := av.create_tween()
	for i in range(3):
		tw.tween_property(av, "rotation", 0.18 if i % 2 == 0 else -0.18, 0.05)
	tw.tween_property(av, "rotation", 0.0, 0.05)
	tw.parallel().tween_property(av, "modulate", Color.WHITE, 0.25)
	var text := ("CRITICAL! -%d" if crit else "-%d") % dmg
	var l := UIKit.label(text, 46 if crit else 40, UIKit.GOLD if crit else Color(1.0, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.02))
	l.size = Vector2(320, 60)
	l.z_index = 140
	add_child(l)
	# Pops out of the hit character and floats up over the header
	l.global_position = av.global_position + av.size * 0.5 - l.size * 0.5 + Vector2(0, 10)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ONE * 0.3
	var lt := l.create_tween()
	lt.tween_property(l, "scale", Vector2.ONE * (1.3 if crit else 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.parallel().tween_property(l, "position:y", l.position.y - 46, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lt.tween_property(l, "position:y", l.position.y - 76, 0.7)
	lt.parallel().tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.3)
	lt.tween_callback(l.queue_free)

# Glowing shots flying from one place to another; on_arrive runs when the first one lands
func _fly(from: Vector2, to: Vector2, shots: int, col: Color, on_arrive: Callable) -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in range(shots):
		var s := Sprite2D.new()
		s.texture = preload("res://assets/sprites/sparkle.png")
		s.material = add
		s.modulate = col
		s.scale = Vector2.ONE * 1.5
		s.z_index = 140
		get_tree().root.add_child(s)
		var start: Vector2 = from + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
		s.global_position = start
		var mid: Vector2 = (start + to) * 0.5 + Vector2(rng.randf_range(-120, 120), -60)
		var tw := s.create_tween()
		tw.tween_method(func(t: float):
			s.global_position = start.lerp(mid, t).lerp(mid.lerp(to, t), t), 0.0, 1.0, 0.45 + i * 0.04).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		if i == 0:
			tw.tween_callback(on_arrive)
		tw.tween_callback(s.queue_free)
