class_name VersusMatch
extends Control
# Battle against the computer: a knight (the player) and a wizard (the computer) fight on a small
# stage above the board. Each side solves its own board in peace and nothing lands on the other
# board; the computer's board is not shown. Clearing lines charges the knight, who uses a skill
# on the wizard (more lines, a combo or a perfect clear unlock stronger skills, and now and then a
# hit is critical). The computer places one piece on its own board each time the player places
# one, and its clears make the wizard cast at the knight. Whoever takes the other's HP to 0 wins;
# a side whose pieces fit nowhere loses. MainGame runs the player's board and calls in here.

signal cpu_defeated(reason: String)     # "ko" or "stuck"
signal player_defeated(reason: String)  # "ko"
signal impact(side: int, strength: int)  # a hit landed on side; strength 0..3 for shake

const ME: int = 0
const CPU: int = 1
const MAX_HP: int = 300
const PRESSURE: float = 0.3       # tray generator pressure, the same for both sides
const CRIT_CHANCE: float = 0.15
const CRIT_MULT: float = 2.0
const LEVELS: Array[Dictionary] = [
	{"id": "easy", "name": "쉬움", "desc": "대충 둠"},
	{"id": "normal", "name": "보통", "desc": "줄을 잘 지움"},
	{"id": "hard", "name": "어려움", "desc": "콤보를 노리고 미리 계획함"},
]
# Skills by tier (see skill_tier): the knight's and the wizard's
const SKILLS: Array = [
	["베기", "돌진 베기", "회오리 베기"],
	["매직 볼트", "파이어볼", "메테오"],
]
const KNIGHT_TEX: Texture2D = preload("res://assets/art/battle/knight.png")
const WIZARD_TEX: Texture2D = preload("res://assets/art/battle/wizard.png")
const SLASH_TEX: Texture2D = preload("res://assets/art/battle/fx_slash.png")
const FIRE_TEX: Texture2D = preload("res://assets/art/battle/fx_fireball.png")
const STAGE_SIZE := Vector2(636, 170)
const HERO_SIZE: float = 118.0
const HOME_X: Array[float] = [70.0, 566.0]   # character centres on the stage
const HOME_Y: float = 110.0
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

var _heroes: Array[Sprite2D] = []
var _names: Array[Label] = []
var _hp_fill: Array[Panel] = []
var _hp_labels: Array[Label] = []
var _idle: Array[Tween] = []

# A shape standing in for a tray piece (the move search only reads shape_data)
class ShapeRef:
	var shape_data: Dictionary
	func _init(s: Dictionary) -> void:
		shape_data = s

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

# 0 basic, 1 strong (2 lines or a combo of 3+), 2 ultimate (3+ lines or a perfect clear)
static func skill_tier(lines: int, combo: int, perfect: bool) -> int:
	if lines >= 3 or perfect:
		return 2
	if lines >= 2 or combo >= 3:
		return 1
	return 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(42, 92)
	size = STAGE_SIZE
	var stage := Panel.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.size = STAGE_SIZE
	var sb := UIKit.box(Color(0.06, 0.08, 0.15, 0.85), UIKit.BORDER, 22, 2)
	stage.add_theme_stylebox_override("panel", sb)
	add_child(stage)
	# A faint floor line the two stand on
	var floor_line := ColorRect.new()
	floor_line.color = Color(1, 1, 1, 0.06)
	floor_line.position = Vector2(20, HOME_Y + HERO_SIZE * 0.46)
	floor_line.size = Vector2(STAGE_SIZE.x - 40, 2)
	floor_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(floor_line)
	for side in [ME, CPU]:
		var hero := Sprite2D.new()
		hero.texture = KNIGHT_TEX if side == ME else WIZARD_TEX
		hero.scale = Vector2.ONE * HERO_SIZE / hero.texture.get_height()
		hero.position = Vector2(HOME_X[side], HOME_Y)
		add_child(hero)
		_heroes.append(hero)
		# Name and HP bar above each character, on its own half of the stage
		var x0: float = 14.0 if side == ME else STAGE_SIZE.x - 14.0 - 250.0
		var name_l := UIKit.label("", UIKit.TYPE_SMALL, UIKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT if side == ME else HORIZONTAL_ALIGNMENT_RIGHT)
		name_l.position = Vector2(x0 if side == ME else x0 + 80.0, 8)
		name_l.size = Vector2(170, 24)
		name_l.clip_text = true
		add_child(name_l)
		_names.append(name_l)
		var bar_bg := Panel.new()
		bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_bg.position = Vector2(x0, 34)
		bar_bg.size = Vector2(250, 16)
		bar_bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.5), Color.TRANSPARENT, 8))
		add_child(bar_bg)
		var fill := Panel.new()
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fill.position = Vector2(2, 2)
		fill.size = Vector2(246, 12)
		bar_bg.add_child(fill)
		_hp_fill.append(fill)
		# HP number on the name line, at the end nearer the middle
		var hp_l := UIKit.label("", UIKit.TYPE_CAPTION, UIKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT if side == ME else HORIZONTAL_ALIGNMENT_LEFT)
		hp_l.position = Vector2(x0, 10)
		hp_l.size = Vector2(250, 22)
		add_child(hp_l)
		_hp_labels.append(hp_l)
		_idle.append(null)
	var vs := UIKit.label("VS", 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vs.position = Vector2(STAGE_SIZE.x * 0.5 - 30, 14)
	vs.size = Vector2(60, 36)
	add_child(vs)
	# Hidden board used only so the computer's trays come from the same generator as the player's
	_sim_board = preload("res://scenes/board.tscn").instantiate()
	_sim_board.visible = false
	_sim_board.position = Vector2(-5000, -5000)
	add_child(_sim_board)

# start_cells: board indexes filled at the start (the same pattern as the player's board)
func begin(lvl: String, player_name: String, _player_avatar: Texture2D, start_cells: Array) -> void:
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
	_names[ME].text = "기사 · %s" % player_name
	_names[CPU].text = "마법사 · %s" % level_name(level)
	for side in [ME, CPU]:
		_heroes[side].position = Vector2(HOME_X[side], HOME_Y)
		_heroes[side].modulate = Color.WHITE
		_heroes[side].rotation = 0.0
		_start_idle(side)
	_refresh()

# Gentle breathing bob while waiting
func _start_idle(side: int) -> void:
	if _idle[side]:
		_idle[side].kill()
	var h: Sprite2D = _heroes[side]
	var base: float = h.scale.y
	var tw := h.create_tween().set_loops()
	tw.tween_property(h, "scale:y", base * 1.03, 0.6 + side * 0.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(h, "scale:y", base, 0.6 + side * 0.1).set_trans(Tween.TRANS_SINE)
	_idle[side] = tw

# =========================================================
# Turns (called by MainGame)
# =========================================================

# The player cleared lines: light gathers from the cleared lines into the knight, who strikes
func player_cleared(lines: int, combo: int, perfect: bool, from_global: Vector2) -> void:
	var base: int = damage_for(lines, combo, perfect)
	if base <= 0 or finished:
		return
	var tier: int = skill_tier(lines, combo, perfect)
	_charge(from_global, func(): _cast(ME, base, tier))

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
	var lines: int = move["lines"]
	if lines > 0:
		cpu_combo += 1
		cpu_grace = 3
		var perfect: bool = _free(cpu_grid) == 64
		_cast(CPU, damage_for(lines, cpu_combo, perfect), skill_tier(lines, cpu_combo, perfect))
	elif cpu_combo > 0:
		cpu_grace -= 1
		if cpu_grace <= 0:
			cpu_combo = 0
	# Pieces left that fit nowhere: the computer is stuck
	var left: Array = cpu_tray.filter(func(p): return p != null)
	if not left.is_empty() and _moves(cpu_grid, left).is_empty():
		_end_cpu("stuck")

func _cast(side: int, base: int, tier: int) -> void:
	if finished:
		return
	var crit: bool = rng.randf() < CRIT_CHANCE
	var dmg: int = int(base * CRIT_MULT) if crit else base
	_skill_name(side, tier)
	var land := func(): _land(1 - side, dmg, crit, tier)
	if side == ME:
		_knight_attack(tier, land)
	else:
		_wizard_attack(tier, land)

func _land(target: int, dmg: int, crit: bool, tier: int) -> void:
	if finished:
		return
	hp[target] = maxi(0, hp[target] - dmg)
	dealt[1 - target] += dmg
	_hit(target, dmg, crit, tier)
	_refresh()
	if hp[target] <= 0:
		if target == CPU:
			_end_cpu("ko")
		else:
			finished = true
			player_defeated.emit("ko")

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
		_hp_fill[side].add_theme_stylebox_override("panel", UIKit.box(col, Color.TRANSPARENT, 6))
		var w: float = maxf(0.0, 246.0 * ratio)
		_hp_fill[side].create_tween().tween_property(_hp_fill[side], "size:x", w, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if side == CPU:
			# The wizard's bar drains toward the right edge
			_hp_fill[side].create_tween().tween_property(_hp_fill[side], "position:x", 2.0 + 246.0 - w, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hp_labels[side].text = "%d / %d" % [hp[side], MAX_HP]

# Light flies from the cleared lines into the knight before the skill
func _charge(from_global: Vector2, then: Callable) -> void:
	var orb := _fx_sprite(preload("res://assets/sprites/sparkle.png"), MY_COLOR, 2.2)
	orb.global_position = from_global
	var to: Vector2 = _heroes[ME].global_position
	var tw := orb.create_tween()
	tw.tween_property(orb, "global_position", to, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(orb, "scale", Vector2.ONE * 1.0, 0.28)
	tw.tween_callback(orb.queue_free)
	tw.tween_callback(then)

# Knight: dashes to the wizard and slashes (once, twice, or a whirl of three)
func _knight_attack(tier: int, on_hit: Callable) -> void:
	var k: Sprite2D = _heroes[ME]
	var target: Vector2 = Vector2(HOME_X[CPU] - 96.0, HOME_Y)
	var tw := k.create_tween()
	tw.tween_property(k, "position", target, 0.16 - 0.02 * tier).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		var slashes: int = [1, 2, 3][tier]
		for i in range(slashes):
			var s := _fx_sprite(SLASH_TEX, Color.WHITE, 0.0)
			s.position = Vector2(HOME_X[CPU] + randf_range(-12, 12), HOME_Y + randf_range(-14, 10))
			s.rotation = [0.0, 1.2, -1.0][i] + randf_range(-0.2, 0.2)
			var size: float = (0.55 + 0.15 * tier) * 118.0 / SLASH_TEX.get_height()
			var st := s.create_tween()
			st.tween_interval(i * 0.09)
			st.tween_property(s, "scale", Vector2.ONE * size, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			st.tween_property(s, "modulate:a", 0.0, 0.22).set_delay(0.06)
			st.tween_callback(s.queue_free)
		on_hit.call())
	tw.tween_interval(0.12 + 0.09 * tier)
	tw.tween_property(k, "position", Vector2(HOME_X[ME], HOME_Y), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Wizard: raises the staff and throws a bolt, a fireball, or a meteor shower of three
func _wizard_attack(tier: int, on_hit: Callable) -> void:
	var w: Sprite2D = _heroes[CPU]
	var tw := w.create_tween()
	tw.tween_property(w, "position:y", HOME_Y - 14.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(w, "position:y", HOME_Y, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var knight: Vector2 = Vector2(HOME_X[ME], HOME_Y)
	var shots: int = 3 if tier == 2 else 1
	for i in range(shots):
		var f := _fx_sprite(FIRE_TEX, Color(0.7, 0.75, 1.3) if tier == 0 else Color.WHITE, 0.0)
		var start: Vector2 = Vector2(HOME_X[CPU] - 46.0, HOME_Y - 34.0)
		var end: Vector2 = knight + Vector2(randf_range(-10, 10), randf_range(-8, 8))
		if tier == 2:
			# Meteors fall from above the stage
			start = Vector2(HOME_X[ME] + 170.0 + i * 50.0, -60.0)
		f.position = start
		var dir: Vector2 = (end - start).normalized()
		f.rotation = Vector2.LEFT.angle_to(dir)
		var size: float = [0.35, 0.55, 0.5][tier] * 118.0 / FIRE_TEX.get_height()
		var ft := f.create_tween()
		ft.tween_interval(0.1 + i * 0.12)
		ft.tween_property(f, "scale", Vector2.ONE * size, 0.06)
		ft.tween_property(f, "position", end, 0.34 if tier < 2 else 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		ft.tween_property(f, "modulate:a", 0.0, 0.1)
		if i == 0:
			ft.tween_callback(on_hit)
		ft.tween_callback(f.queue_free)

# Skill name pops over the attacker's half of the stage
func _skill_name(side: int, tier: int) -> void:
	var l := UIKit.label(SKILLS[side][tier] + "!", 26 + tier * 4, MY_COLOR if side == ME else HIT_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color(0.03, 0.04, 0.1))
	l.size = Vector2(260, 44)
	l.position = Vector2(STAGE_SIZE.x * (0.3 if side == ME else 0.7) - 130.0, 56)
	l.pivot_offset = l.size * 0.5
	l.z_index = 5
	l.scale = Vector2.ONE * 0.4
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.45)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)

# The hit character flashes and is knocked back; the damage number pops up over it
func _hit(side: int, dmg: int, crit: bool, tier: int) -> void:
	var h: Sprite2D = _heroes[side]
	h.modulate = Color(2.2, 0.9, 0.9)
	var push: float = (-1.0 if side == ME else 1.0) * (10.0 + 6.0 * tier)
	var tw := h.create_tween()
	tw.tween_property(h, "position:x", HOME_X[side] + push, 0.06)
	tw.tween_property(h, "position:x", HOME_X[side], 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(h, "modulate", Color.WHITE, 0.3)
	impact.emit(side, tier + (1 if crit else 0))
	var text := ("CRITICAL! -%d" if crit else "-%d") % dmg
	var l := UIKit.label(text, 44 if crit else 38, UIKit.GOLD if crit else Color(1.0, 0.5, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 12)
	l.add_theme_color_override("font_outline_color", Color(0.18, 0.02, 0.02))
	l.size = Vector2(320, 60)
	l.z_index = 10
	add_child(l)
	l.position = Vector2(HOME_X[side], HOME_Y - 40.0) - l.size * 0.5
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ONE * 0.3
	var lt := l.create_tween()
	lt.tween_property(l, "scale", Vector2.ONE * (1.25 if crit else 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	lt.parallel().tween_property(l, "position:y", l.position.y - 30, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lt.tween_property(l, "position:y", l.position.y - 54, 0.6)
	lt.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.3)
	lt.tween_callback(l.queue_free)

func _fx_sprite(tex: Texture2D, col: Color, start_scale: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.modulate = col
	s.scale = Vector2.ONE * start_scale
	s.z_index = 8
	add_child(s)
	return s
