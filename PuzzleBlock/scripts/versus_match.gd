class_name VersusMatch
extends Control
# Versus mode against the computer: one board and one tray of three pieces, the player and the
# computer take turns placing one piece each. Clears score for whoever made them (with their own
# combo). After TURNS placements each the higher score wins; a side that cannot place any piece
# on its turn loses at once. This node is the scoreboard in the header and holds the match state
# and the computer's move choice; MainGame runs the board and calls in here.

const TURNS: int = 12
const ME: int = 0
const CPU: int = 1
const CPU_AVATAR: int = 5
const LEVELS: Array[Dictionary] = [
	{"id": "easy", "name": "쉬움", "desc": "아무 데나 두는 편"},
	{"id": "normal", "name": "보통", "desc": "줄을 잘 지움"},
	{"id": "hard", "name": "어려움", "desc": "내가 못 놓게 방해함"},
]

var level: String = "normal"
var turn: int = ME
var scores: Array[int] = [0, 0]
var combos: Array[int] = [0, 0]
var graces: Array[int] = [0, 0]
var moves_left: Array[int] = [TURNS, TURNS]
var rng := RandomNumberGenerator.new()

var _cards: Array[Panel] = []
var _score_labels: Array[Label] = []
var _state_labels: Array[Label] = []
var _turns_label: Label
var _avatars: Array[TextureRect] = []

static func level_name(id: String) -> String:
	for l in LEVELS:
		if l["id"] == id:
			return l["name"]
	return id

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(42, 96)
	size = Vector2(636, 120)
	for side in [ME, CPU]:
		var card := Panel.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.position = Vector2(0 if side == ME else 386, 0)
		card.size = Vector2(250, 120)
		add_child(card)
		_cards.append(card)
		var av := TextureRect.new()
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		av.position = Vector2(14, 14)
		av.size = Vector2(40, 40)
		card.add_child(av)
		_avatars.append(av)
		var name_l := UIKit.label("나" if side == ME else "컴퓨터", UIKit.TYPE_SMALL, UIKit.MUTED)
		name_l.position = Vector2(62, 12)
		name_l.size = Vector2(176, 24)
		name_l.clip_text = true
		card.add_child(name_l)
		var state := UIKit.label("", UIKit.TYPE_CAPTION, UIKit.MUTED)
		state.position = Vector2(62, 36)
		state.size = Vector2(176, 22)
		card.add_child(state)
		_state_labels.append(state)
		var sc := UIKit.label("0", 40, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		sc.add_theme_constant_override("outline_size", 6)
		sc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
		sc.position = Vector2(0, 60)
		sc.size = Vector2(250, 52)
		sc.pivot_offset = sc.size * 0.5
		card.add_child(sc)
		_score_labels.append(sc)
	var vs := UIKit.label("VS", 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	vs.position = Vector2(250, 18)
	vs.size = Vector2(136, 44)
	add_child(vs)
	_turns_label = UIKit.label("", UIKit.TYPE_CAPTION, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_turns_label.position = Vector2(250, 66)
	_turns_label.size = Vector2(136, 44)
	_turns_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_turns_label)

func begin(lvl: String, player_name: String, player_avatar: Texture2D) -> void:
	level = lvl
	turn = ME
	scores = [0, 0]
	combos = [0, 0]
	graces = [0, 0]
	moves_left = [TURNS, TURNS]
	rng.randomize()
	(_cards[ME].get_child(1) as Label).text = player_name
	(_cards[CPU].get_child(1) as Label).text = "컴퓨터 · %s" % level_name(level)
	_avatars[ME].texture = player_avatar
	_avatars[CPU].texture = LeaderboardManager.get_avatar_texture(CPU_AVATAR)
	_refresh()

func is_my_turn() -> bool:
	return turn == ME

func add_points(amount: int) -> void:
	scores[turn] += amount
	var l: Label = _score_labels[turn]
	l.text = UIKit.format_number(scores[turn])
	l.scale = Vector2.ONE * (1.12 if amount < 20 else 1.3)
	l.create_tween().tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Called after the mover's piece is down: count the move and pass the turn
func end_move() -> void:
	moves_left[turn] -= 1
	turn = CPU if turn == ME else ME
	_refresh()

func is_finished_by_turns() -> bool:
	return moves_left[ME] <= 0 and moves_left[CPU] <= 0

func winner() -> int:
	if scores[ME] == scores[CPU]:
		return -1
	return ME if scores[ME] > scores[CPU] else CPU

func set_thinking(on: bool) -> void:
	_state_labels[CPU].text = "생각 중..." if on else ("차례" if turn == CPU else "")

func _refresh() -> void:
	for side in [ME, CPU]:
		var active: bool = side == turn and not is_finished_by_turns()
		var col: Color = UIKit.ACCENT_HI if side == ME else UIKit.DANGER
		var sb := UIKit.box(UIKit.SURFACE if active else Color(UIKit.SURFACE, 0.6), col if active else UIKit.BORDER, 20, 3 if active else 2)
		if active:
			sb.shadow_color = Color(col, 0.45)
			sb.shadow_size = 12
		_cards[side].add_theme_stylebox_override("panel", sb)
		_cards[side].modulate = Color.WHITE if active else Color(1, 1, 1, 0.75)
		_state_labels[side].text = ("내 차례" if side == ME else "차례") if active else ""
		_state_labels[side].add_theme_color_override("font_color", col if active else UIKit.MUTED)
		_score_labels[side].text = UIKit.format_number(scores[side])
	var left: int = moves_left[ME] + moves_left[CPU]
	_turns_label.text = "남은 수 %d" % left if left > 0 else "마지막 수"

# =========================================================
# Computer's move
# =========================================================

# tray: Array of BlockPiece or null. Returns {"slot", "x", "y"} or {} when nothing fits.
# state: the match as {scores, combos, graces, left, turn}; defaults to this match with the
# computer to move (the benchmark passes its own).
func choose_move(grid: PackedByteArray, tray: Array, state: Dictionary = {}) -> Dictionary:
	if state.is_empty():
		state = {"scores": scores.duplicate(), "combos": combos.duplicate(), "graces": graces.duplicate(),
			"left": moves_left.duplicate(), "turn": turn}
	var moves: Array = _moves(grid, tray)
	if moves.is_empty():
		return {}
	for m in moves:
		m["value"] = m["lines"] * 10.0 + m["snug"] * 3.0 + rng.randf()
	moves.sort_custom(func(a, b): return a["value"] > b["value"])
	match level:
		"easy":
			# Mostly any spot; takes an obvious clear about half the time
			if moves[0]["lines"] > 0 and rng.randf() < 0.5:
				return moves[0]
			return moves[rng.randi() % moves.size()]
		"hard":
			return _search_root(grid, tray, state)
		_:
			return moves[0]

# Hard: reads the rest of the tray move by move (computer, player, computer...) with the real
# scoring, assumes the player answers as well as it can, and picks the move that comes out best.
# A side with nothing to place on its turn loses, so trapping the player counts as a win.
# Beam widths keep it to a few thousand placements per choice.
const WIN: float = 1000000.0
const BEAM: Array[int] = [16, 10, 6]

func _search_root(grid: PackedByteArray, tray: Array, st: Dictionary) -> Dictionary:
	var me: int = st["turn"]
	var moves: Array = _ordered(grid, tray, st)
	var best: Dictionary = moves[0]
	var best_v: float = -INF
	var alpha: float = -INF
	for k in range(mini(moves.size(), BEAM[0])):
		var m: Dictionary = moves[k]
		var v: float = _search(m["grid"], _without(tray, m["slot"]), m["state"], me, 1, alpha, INF)
		if v > best_v:
			best_v = v
			best = m
		alpha = maxf(alpha, v)
	return best

func _search(grid: PackedByteArray, tray: Array, st: Dictionary, me: int, depth: int, alpha: float, beta: float) -> float:
	if st["left"][0] <= 0 and st["left"][1] <= 0:
		return _leaf(st, me, true)
	if tray.all(func(p): return p == null) or depth >= BEAM.size():
		return _leaf(st, me, false)
	var moves: Array = _ordered(grid, tray, st)
	if moves.is_empty():
		return -WIN if st["turn"] == me else WIN # the side to move is stuck and loses
	var maximizing: bool = st["turn"] == me
	var best: float = -INF if maximizing else INF
	for k in range(mini(moves.size(), BEAM[depth])):
		var m: Dictionary = moves[k]
		var v: float = _search(m["grid"], _without(tray, m["slot"]), m["state"], me, depth + 1, alpha, beta)
		if maximizing:
			best = maxf(best, v)
			alpha = maxf(alpha, v)
		else:
			best = minf(best, v)
			beta = minf(beta, v)
		if beta <= alpha:
			break
	return best

# Score lead for `me`, plus what a live combo is worth on the next clear
func _leaf(st: Dictionary, me: int, final: bool) -> float:
	var diff: float = st["scores"][me] - st["scores"][1 - me]
	if final:
		return (WIN if diff > 0 else (-WIN if diff < 0 else 0.0)) + diff
	return diff + _combo_worth(st, me) - _combo_worth(st, 1 - me)

func _combo_worth(st: Dictionary, side: int) -> float:
	var c: int = st["combos"][side]
	if c <= 0:
		return 0.0
	var n: int = c + 1
	return (main_combo_bonus(n) + 10.0) * 0.5 * st["graces"][side] / float(MainGame.MAX_COMBO_GRACE)

static func main_combo_bonus(c: int) -> float:
	return MainGame.COMBO_BONUS_LINEAR * c + MainGame.COMBO_BONUS_QUADRATIC * c * c

# All moves for the side to move with the state after each, best immediate gain first
func _ordered(grid: PackedByteArray, tray: Array, st: Dictionary) -> Array:
	var moves: Array = _moves(grid, tray)
	var side: int = st["turn"]
	for m in moves:
		var ns: Dictionary = _apply(st, m)
		m["state"] = ns
		m["value"] = (ns["scores"][side] - st["scores"][side]) + m["snug"] * 3.0
	moves.sort_custom(func(a, b): return a["value"] > b["value"])
	return moves

# main.gd's scoring for one move: cells placed, clears with the mover's own combo, fever, perfect
func _apply(st: Dictionary, m: Dictionary) -> Dictionary:
	var side: int = st["turn"]
	var sc: Array = st["scores"].duplicate()
	var co: Array = st["combos"].duplicate()
	var gr: Array = st["graces"].duplicate()
	var le: Array = st["left"].duplicate()
	sc[side] += m["cells"]
	var lines: int = m["lines"]
	if lines > 0:
		co[side] += 1
		gr[side] = MainGame.MAX_COMBO_GRACE
		var c: int = co[side]
		var gain: int = int(MainGame.LINE_SCORE_BASE * lines * lines * (1.0 + MainGame.COMBO_ALPHA * c)) + int(main_combo_bonus(c))
		if c >= MainGame.FEVER_COMBO:
			gain = int(gain * MainGame.FEVER_MULTIPLIER)
		sc[side] += gain
		if _free(m["grid"]) == 64:
			sc[side] += roundi(MainGame.PERFECT_CLEAR_BASE * (1.0 + MainGame.COMBO_ALPHA * c))
	elif co[side] > 0:
		gr[side] -= 1
		if gr[side] <= 0:
			co[side] = 0
	le[side] -= 1
	return {"scores": sc, "combos": co, "graces": gr, "left": le, "turn": 1 - side}

static func _without(tray: Array, slot: int) -> Array:
	var t: Array = tray.duplicate()
	t[slot] = null
	return t

func _moves(grid: PackedByteArray, tray: Array) -> Array:
	var out: Array = []
	var before := 64 - _free(grid)
	for slot in range(tray.size()):
		var piece = tray[slot]
		if piece == null or not is_instance_valid(piece):
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
