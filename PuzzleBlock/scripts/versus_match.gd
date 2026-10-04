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
func choose_move(grid: PackedByteArray, tray: Array) -> Dictionary:
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
			return _look_ahead(moves, tray)
		_:
			return moves[0]

# Hard: for the best few moves, also look at the player's best reply with the pieces left,
# and love a move that leaves the player nothing to place
func _look_ahead(moves: Array, tray: Array) -> Dictionary:
	var best: Dictionary = moves[0]
	var best_v: float = -INF
	for k in range(mini(moves.size(), 10)):
		var m: Dictionary = moves[k]
		var rest: Array = tray.duplicate()
		rest[m["slot"]] = null
		var v: float = m["value"]
		var has_rest := false
		for p in rest:
			has_rest = has_rest or p != null
		if has_rest:
			var replies: Array = _moves(m["grid"], rest)
			if replies.is_empty():
				v += 1000.0 # the player is stuck: that wins the match
			else:
				var reply_best := 0.0
				for r in replies:
					reply_best = maxf(reply_best, r["lines"] * 10.0 + r["snug"] * 3.0)
				v -= reply_best * 0.8
		else:
			# A fresh tray comes next; keep the board roomy for it
			v += _free(m["grid"]) * 0.15
		if v > best_v:
			best_v = v
			best = m
	return best

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
				out.append({"slot": slot, "x": x, "y": y, "grid": after_grid,
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
