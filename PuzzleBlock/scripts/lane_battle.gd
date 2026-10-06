class_name LaneBattle
extends Control
# "블록 기사단": a side-view lane battle above the normal puzzle (board shrunk by MainGame).
# - Every piece the player places is one turn: each unit on the lane either walks forward or
#   hits the enemy in range once, and both sides trade blows at the same time.
# - Clearing lines earns gold (more for bigger clears and combos), and every piece a little.
# - Gold buys soldiers with the summon buttons (this does not use a turn).
# - The enemy fortress sends monsters every few turns. Destroy it to reach the next stage; the run
#   ends when the castle falls (or the board is stuck, handled by MainGame).
# Art: Codex pixel art cut by tools/import_lane_art.py, drawn at whole-number scales.

signal defeated(stage: int)
signal castle_hit(damage: int)

const LANE_H: float = 330.0
const BAR_H: float = 96.0
const PX: float = 2.0                 # unit and base sprites are drawn at x2
const GROUND: float = 296.0           # feet line in the lane
const ALLY_START: float = 150.0
const ENEMY_START: float = 566.0
const ALLY_BASE_X: float = 140.0      # where enemies hit the castle
const ENEMY_BASE_X: float = 572.0     # where soldiers hit the fortress
const STEP: float = 44.0              # walk per turn
const GAP: float = 26.0               # a unit stops this far behind a friend ahead
const MAX_UNITS: int = 10
const CASTLE_HP: int = 400
const START_GOLD: int = 60
const GOLD_PER_MOVE: int = 4
const GOLD_PER_LINE: int = 15
const GOLD_PER_POINT: float = 0.5
const BOSS_EVERY: int = 5
const ALLIES := {
	"knight": {"name": "기사", "cost": 50, "hp": 60.0, "atk": 12.0, "range": 44.0},
	"archer": {"name": "궁수", "cost": 80, "hp": 34.0, "atk": 9.0, "range": 140.0, "shot": "arrow"},
	"mage": {"name": "마법사", "cost": 120, "hp": 30.0, "atk": 14.0, "range": 110.0, "shot": "orb", "splash": 50.0},
	"spearman": {"name": "창병", "cost": 160, "hp": 110.0, "atk": 16.0, "range": 60.0},
}
const ALLY_ORDER: Array[String] = ["knight", "archer", "mage", "spearman"]
const ENEMIES := {
	"slime": {"hp": 36.0, "atk": 6.0, "range": 40.0},
	"goblin": {"hp": 52.0, "atk": 9.0, "range": 44.0},
	"skeleton": {"hp": 64.0, "atk": 11.0, "range": 44.0},
	"orc": {"hp": 130.0, "atk": 18.0, "range": 50.0},
}
const ENEMY_GROWTH: float = 1.15
const FORTRESS_HP: float = 200.0
const FORTRESS_GROWTH: float = 1.25

var stage: int = 1
var turn: int = 0
var gold: int = START_GOLD
var castle_hp: int = CASTLE_HP
var fortress_hp: float = FORTRESS_HP
var fortress_max: float = FORTRESS_HP
var finished: bool = true
var switching: bool = false
var units: Array = []                 # {node, side (1 ally / -1 enemy), kind, hp, max_hp, atk, range, shot, splash, bar}
var rng := RandomNumberGenerator.new()
var tex: Dictionary = {}

var _view: Control
var _units_layer: Node2D
var _bars_layer: Node2D
var _stage_label: Label
var _castle_fill: Panel
var _castle_label: Label
var _fort_fill: Panel
var _fort_label: Label
var _gold_label: Label
var _buttons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(0, 90)
	size = Vector2(720, LANE_H + 8 + BAR_H)
	var names: Array = ["castle", "fortress", "lane"]
	names.append_array(ALLY_ORDER)
	names.append_array(ENEMIES.keys())
	for k in names:
		tex[k] = load("res://assets/art/lane/%s.png" % k)
	_build()

# =========================================================
# Flow (called by MainGame)
# =========================================================

func begin() -> void:
	rng.randomize()
	stage = 1
	turn = 0
	gold = START_GOLD
	castle_hp = CASTLE_HP
	finished = false
	switching = false
	for u in units:
		u["node"].queue_free()
	units.clear()
	visible = true
	_start_stage()

func stop() -> void:
	finished = true

# Gold for a clear: a fixed amount per line plus half the clear's points (combos pay more)
func on_clear(lines: int, points: int) -> void:
	if finished:
		return
	var n: int = GOLD_PER_LINE * lines + int(points * GOLD_PER_POINT)
	gold = mini(9999, gold + n)
	var l := _outlined("+%d" % n, 26, UIKit.GOLD)
	l.position = _gold_label.position + Vector2(90, 4)
	l.size = Vector2(90, 34)
	_gold_label.get_parent().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 20, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.tween_callback(l.queue_free)
	_refresh()

func summon(kind: String) -> bool:
	var st: Dictionary = ALLIES[kind]
	if finished or gold < st["cost"] or _count(1) >= MAX_UNITS:
		return false
	gold -= st["cost"]
	_spawn(kind, 1, 1.0)
	SoundManager.play_click()
	_refresh()
	return true

# One turn per piece the player places
func on_player_move() -> void:
	if finished or switching:
		return
	turn += 1
	gold = mini(9999, gold + GOLD_PER_MOVE)
	_resolve_turn()
	if not finished and not switching and turn % _spawn_every() == 0 and _count(-1) < MAX_UNITS:
		_spawn(_pick_enemy(), -1, pow(ENEMY_GROWTH, stage - 1))
	_refresh()

# =========================================================
# Turn
# =========================================================

func _resolve_turn() -> void:
	var hits: Array = []        # [target dict or "castle"/"fortress", damage, attacker]
	var moves: Array = []       # [unit, new x]
	var front_x: Dictionary = {}  # side -> x of the friend just ahead (after its move)
	# Front units first, so each one can stop just behind the friend ahead of it
	var order: Array = units.duplicate()
	order.sort_custom(func(a, b): return a["node"].position.x * a["side"] > b["node"].position.x * b["side"])
	for u in order:
		var x: float = u["node"].position.x
		var side: int = u["side"]
		var target = _target_for(u)
		if target != null:
			hits.append([target, u["atk"], u])
			front_x[side] = x
			continue
		# Walk forward, stopping just short of the nearest opponent or the enemy base
		var limit: float = ENEMY_BASE_X if side == 1 else ALLY_BASE_X
		var front = _nearest_opponent(u)
		if front != null:
			limit = front["node"].position.x - side * minf(u["range"], 40.0)
		if front_x.has(side):
			limit = minf(limit, front_x[side] - GAP) if side == 1 else maxf(limit, front_x[side] + GAP)
		var nx: float = x + side * STEP
		nx = minf(nx, limit) if side == 1 else maxf(nx, limit)
		nx = maxf(nx, x) if side == 1 else minf(nx, x)
		front_x[side] = nx
		moves.append([u, nx])
	for m in moves:
		var node: Sprite2D = m[0]["node"]
		node.create_tween().tween_property(node, "position:x", m[1], 0.22).set_trans(Tween.TRANS_SINE)
		_hop(node)
	for h in hits:
		_attack_fx(h[2], h[0])
		_apply_hit(h[0], h[1], h[2])
	# Remove the fallen
	for u in units.duplicate():
		if u["hp"] <= 0.0:
			_kill(u)
	if fortress_hp <= 0.0 and not switching:
		_stage_cleared()
	elif castle_hp <= 0 and not finished:
		finished = true
		_banner("성이 무너졌어요", "STAGE %d" % stage)
		get_tree().create_timer(1.0).timeout.connect(func(): defeated.emit(stage))

# The nearest opponent within range ahead, else the enemy base if it is in range
func _target_for(u: Dictionary):
	var o = _nearest_opponent(u)
	var x: float = u["node"].position.x
	if o != null and absf(o["node"].position.x - x) <= u["range"]:
		return o
	if u["side"] == 1 and ENEMY_BASE_X - x <= u["range"]:
		if o == null or o["node"].position.x > ENEMY_BASE_X:
			return "fortress"
	if u["side"] == -1 and x - ALLY_BASE_X <= u["range"]:
		if o == null or o["node"].position.x < ALLY_BASE_X:
			return "castle"
	return null

func _nearest_opponent(u: Dictionary):
	var best = null
	var x: float = u["node"].position.x
	for o in units:
		if o["side"] == u["side"] or o["hp"] <= 0.0:
			continue
		var d: float = (o["node"].position.x - x) * u["side"]
		if d < -10.0:
			continue
		if best == null or d < (best["node"].position.x - x) * u["side"]:
			best = o
	return best

func _apply_hit(target, dmg: float, attacker: Dictionary) -> void:
	if target is String:
		if target == "fortress":
			fortress_hp = maxf(0.0, fortress_hp - dmg)
			_number(Vector2(ENEMY_BASE_X + 50, GROUND - 160), dmg, Color(1.0, 0.9, 0.5))
		else:
			castle_hp = maxi(0, castle_hp - roundi(dmg))
			_number(Vector2(ALLY_BASE_X - 60, GROUND - 160), dmg, Color(1.0, 0.45, 0.4))
			castle_hit.emit(roundi(dmg))
		return
	target["hp"] -= dmg
	_flash(target["node"])
	_number(target["node"].position + Vector2(0, -_height(target["node"]) - 6), dmg, Color(1.0, 0.95, 0.6) if attacker["side"] == 1 else Color(1.0, 0.5, 0.45))
	# Mage fire also hits the target's neighbours
	if attacker.get("splash", 0.0) > 0.0:
		for o in units:
			if o != target and o["side"] == target["side"] and absf(o["node"].position.x - target["node"].position.x) <= attacker["splash"]:
				o["hp"] -= dmg * 0.6
				_flash(o["node"])

func _spawn_every() -> int:
	return maxi(2, 4 - (stage - 1) / 3)

func _pick_enemy() -> String:
	var pool: Array = ["slime"]
	if stage >= 2:
		pool += ["goblin", "goblin"]
	if stage >= 3:
		pool += ["skeleton", "skeleton"]
	if stage >= 4:
		pool.append("orc")
	return pool[rng.randi() % pool.size()]

func _start_stage() -> void:
	fortress_max = FORTRESS_HP * pow(FORTRESS_GROWTH, stage - 1)
	fortress_hp = fortress_max
	turn = 0
	_stage_label.text = "STAGE %d" % stage
	_spawn(_pick_enemy(), -1, pow(ENEMY_GROWTH, stage - 1))
	if stage % BOSS_EVERY == 0:
		var boss := _spawn("orc", -1, pow(ENEMY_GROWTH, stage - 1) * 3.0)
		boss["node"].scale = Vector2.ONE * PX * 1.5
	_refresh()

func _stage_cleared() -> void:
	switching = true
	castle_hp = mini(CASTLE_HP, castle_hp + 80)
	for u in units.duplicate():
		if u["side"] == -1:
			_kill(u)
	_banner("STAGE %d 클리어!" % stage, "성 체력 +80")
	_refresh()
	get_tree().create_timer(1.3).timeout.connect(func():
		if finished:
			return
		stage += 1
		_start_stage()
		switching = false)

# =========================================================
# Units
# =========================================================

func _spawn(kind: String, side: int, k: float) -> Dictionary:
	var st: Dictionary = ALLIES[kind] if side == 1 else ENEMIES[kind]
	var node := Sprite2D.new()
	node.texture = tex[kind]
	node.scale = Vector2.ONE * PX
	node.offset = Vector2(0, -node.texture.get_height() * 0.5)
	node.position = Vector2(ALLY_START if side == 1 else ENEMY_START, GROUND + [0.0, 8.0, 4.0, 12.0][units.size() % 4])
	_units_layer.add_child(node)
	var hp: float = st["hp"] * k
	var u := {"node": node, "side": side, "kind": kind, "hp": hp, "max_hp": hp, "atk": st["atk"] * k,
		"range": st["range"], "shot": st.get("shot", ""), "splash": st.get("splash", 0.0)}
	u["bar"] = _unit_bar(node)
	units.append(u)
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, 0.2)
	return u

func _count(side: int) -> int:
	return units.filter(func(u): return u["side"] == side).size()

func _kill(u: Dictionary) -> void:
	units.erase(u)
	var node: Sprite2D = u["node"]
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate:a", 0.0, 0.3)
	tw.tween_property(node, "position:y", node.position.y + 8, 0.3)
	tw.chain().tween_callback(node.queue_free)

func _height(node: Sprite2D) -> float:
	return node.texture.get_height() * node.scale.y

func _hop(node: Sprite2D) -> void:
	var base: float = -node.texture.get_height() * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "offset:y", base - 3.0, 0.1)
	tw.tween_property(node, "offset:y", base, 0.12)

func _flash(node: CanvasItem) -> void:
	node.modulate = Color(2.0, 1.6, 1.6)
	node.create_tween().tween_property(node, "modulate", Color.WHITE, 0.2)

# Melee units lunge; archers and mages send a small pixel shot
func _attack_fx(u: Dictionary, target) -> void:
	var node: Sprite2D = u["node"]
	var to: Vector2
	if target is String:
		to = Vector2(ENEMY_BASE_X + 40 if target == "fortress" else ALLY_BASE_X - 40, GROUND - 80)
	else:
		to = target["node"].position + Vector2(0, -_height(target["node"]) * 0.5)
	if u["shot"] == "":
		var tw := node.create_tween()
		tw.tween_property(node, "position:x", node.position.x + u["side"] * 10.0, 0.08)
		tw.tween_property(node, "position:x", node.position.x, 0.12)
		return
	var shot := ColorRect.new()
	shot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if u["shot"] == "arrow":
		shot.size = Vector2(14, 3)
		shot.color = Color(0.95, 0.9, 0.75)
	else:
		shot.size = Vector2(8, 8)
		shot.color = Color(1.0, 0.55, 0.2)
	var from: Vector2 = node.position + Vector2(u["side"] * 12.0, -_height(node) * 0.6)
	shot.position = from
	_view.add_child(shot)
	var tw := shot.create_tween()
	tw.tween_property(shot, "position", to, 0.18)
	tw.tween_callback(shot.queue_free)

func _unit_bar(owner: Sprite2D) -> Panel:
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.6), Color.TRANSPARENT, 2))
	bg.size = Vector2(36, 5)
	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(1, 1)
	fill.size = Vector2(34, 3)
	bg.add_child(fill)
	_bars_layer.add_child(bg)
	owner.tree_exiting.connect(bg.queue_free)
	return bg

# =========================================================
# Display
# =========================================================

func _build() -> void:
	_view = Control.new()
	_view.size = Vector2(720, LANE_H)
	_view.clip_contents = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_view)
	var lane_tex: Texture2D = tex["lane"]
	var k: float = ceil(maxf(720.0 / lane_tex.get_width(), LANE_H / lane_tex.get_height()))
	var bg := TextureRect.new()
	bg.texture = lane_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(lane_tex.get_width(), lane_tex.get_height()) * k
	bg.position = Vector2((720.0 - bg.size.x) * 0.5, LANE_H - bg.size.y)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(bg)
	for side in [1, -1]:
		var t: Texture2D = tex["castle" if side == 1 else "fortress"]
		var b := Sprite2D.new()
		b.texture = t
		b.scale = Vector2.ONE * PX
		b.centered = false
		b.position = Vector2(6.0 if side == 1 else 720.0 - 6.0 - t.get_width() * PX, GROUND + 6.0 - t.get_height() * PX)
		_view.add_child(b)
	_units_layer = Node2D.new()
	_units_layer.y_sort_enabled = true
	_view.add_child(_units_layer)
	_bars_layer = Node2D.new()
	_view.add_child(_bars_layer)
	_stage_label = _outlined("", 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_stage_label.position = Vector2(260, 8)
	_stage_label.size = Vector2(200, 36)
	_view.add_child(_stage_label)
	var cb := _bar(_view, Vector2(16, 46), Vector2(200, 18))
	_castle_fill = cb.get_child(0)
	_castle_label = _outlined("", 16, Color(0.9, 1.0, 0.9))
	_castle_label.position = Vector2(16, 64)
	_castle_label.size = Vector2(200, 22)
	_view.add_child(_castle_label)
	var fb := _bar(_view, Vector2(504, 46), Vector2(200, 18))
	_fort_fill = fb.get_child(0)
	_fort_label = _outlined("", 16, Color(1.0, 0.88, 0.88), HORIZONTAL_ALIGNMENT_RIGHT)
	_fort_label.position = Vector2(504, 64)
	_fort_label.size = Vector2(200, 22)
	_view.add_child(_fort_label)
	# Summon bar: gold on the left, a button per soldier
	var bar := Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(10, LANE_H + 8)
	bar.size = Vector2(700, BAR_H)
	bar.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE, UIKit.BORDER, 18, 2))
	add_child(bar)
	var gcap := UIKit.label("금화", UIKit.TYPE_SMALL, UIKit.MUTED)
	gcap.position = Vector2(18, 12)
	gcap.size = Vector2(150, 24)
	bar.add_child(gcap)
	_gold_label = _outlined("0", 34, UIKit.GOLD)
	_gold_label.position = Vector2(18, 38)
	_gold_label.size = Vector2(160, 44)
	bar.add_child(_gold_label)
	for i in range(ALLY_ORDER.size()):
		var kind: String = ALLY_ORDER[i]
		var st: Dictionary = ALLIES[kind]
		var btn := Button.new()
		btn.position = Vector2(186 + i * 128, 8)
		btn.size = Vector2(116, 80)
		btn.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(btn, "primary", 16, 14)
		btn.pressed.connect(func(): summon(kind))
		bar.add_child(btn)
		var icon := TextureRect.new()
		icon.texture = tex[kind]
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(6, 10)
		icon.size = Vector2(52, 60)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		var n := _outlined(st["name"], 16, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		n.position = Vector2(56, 10)
		n.size = Vector2(56, 24)
		btn.add_child(n)
		var c := _outlined(str(st["cost"]), 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		c.position = Vector2(56, 38)
		c.size = Vector2(56, 30)
		btn.add_child(c)
		_buttons[kind] = btn

func _bar(parent: Control, pos: Vector2, sz: Vector2) -> Panel:
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = pos
	bg.size = sz
	bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.6), Color.TRANSPARENT, int(sz.y / 2)))
	parent.add_child(bg)
	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(2, 2)
	fill.size = sz - Vector2(4, 4)
	bg.add_child(fill)
	return bg

func _outlined(text: String, size_px: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UIKit.label(text, size_px, col, align)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.12))
	return l

func _refresh() -> void:
	var cr: float = float(castle_hp) / CASTLE_HP
	_castle_fill.size.x = 196.0 * cr
	_castle_fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.35, 0.86, 0.43) if cr > 0.3 else Color(1.0, 0.4, 0.35), Color.TRANSPARENT, 7))
	_castle_label.text = "내 성 %d" % castle_hp
	var fr: float = clampf(fortress_hp / fortress_max, 0.0, 1.0)
	_fort_fill.size.x = 196.0 * fr
	_fort_fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.92, 0.32, 0.28), Color.TRANSPARENT, 7))
	_fort_label.text = "적 요새 %d" % ceili(fortress_hp)
	_gold_label.text = str(gold)
	for kind in _buttons:
		var ok: bool = gold >= ALLIES[kind]["cost"] and _count(1) < MAX_UNITS and not finished
		_buttons[kind].modulate = Color.WHITE if ok else Color(0.45, 0.45, 0.5)
	for u in units:
		var bg: Panel = u["bar"]
		bg.visible = u["hp"] < u["max_hp"]
		var fill: Panel = bg.get_child(0)
		fill.size.x = 34.0 * clampf(u["hp"] / u["max_hp"], 0.0, 1.0)
		fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.35, 0.86, 0.43) if u["side"] == 1 else Color(1.0, 0.4, 0.35), Color.TRANSPARENT, 1))

func _process(_delta: float) -> void:
	for u in units:
		var node: Sprite2D = u["node"]
		u["bar"].position = node.position + Vector2(-18, -_height(node) - 8)

func _number(pos: Vector2, dmg: float, col: Color) -> void:
	var l := _outlined(str(roundi(dmg)), 18, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(60, 24)
	l.position = pos - l.size * 0.5
	l.z_index = 8
	_view.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 22, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tw.tween_callback(l.queue_free)

func _banner(title: String, sub: String) -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(0, 100)
	box.size = Vector2(720, 110)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.z_index = 10
	_view.add_child(box)
	box.add_child(_outlined(title, 42, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_outlined(sub, 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var tw := box.create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(box.queue_free)
