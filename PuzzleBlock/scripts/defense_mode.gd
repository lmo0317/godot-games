class_name DefenseMode
extends Control
# Block Defense: puzzle and battle take turns on the whole (portrait) screen.
#  1. Puzzle phase (PUZZLE_TIME seconds): the player breaks blocks on the normal board. The HUD in
#     the header shows the wave, the wall's HP, the time left and what the points so far buy.
#  2. The points of the phase turn into defenders automatically: an archer per ARCHER_COST points
#     and a mage per MAGE_COST (up to the wall's SLOTS; extra points repair the wall).
#  3. Wave phase: the battlefield covers the screen. Monsters walk down the road from the top to
#     the wall at the bottom and hit it. Every defender stands on the wall either side of the gate
#     and shoots: archers fast single arrows, mages slower fireballs that burst on everything
#     nearby. Clear the wave to go back to the puzzle; defenders stay. Every BOSS_EVERY waves a
#     wizard boss comes. The run ends when the wall falls; the score is the waves held off.
# Characters are pixel art scaled up with nearest filtering so the pixels stay crisp.
# MainGame runs the board and calls add_points() / board_stuck(); this node owns the rest.

signal wave_started
signal puzzle_started(fresh_board: bool)
signal defeated(waves_cleared: int)

const PUZZLE_TIME: float = 40.0
const ARCHER_COST: int = 100
const MAGE_COST: int = 250
const CASTLE_HP: int = 300
const BOSS_EVERY: int = 5
const FIELD_TOP: float = 92.0
const FIELD_SIZE := Vector2(720, 1188)
# Spots on the wall walkway, either side of the gate (x), filled from the gate outward
const SLOTS: Array[float] = [272.0, 448.0, 200.0, 520.0, 128.0, 592.0, 56.0, 664.0]
const SPAWN_X := Vector2(70.0, 650.0)   # monsters enter anywhere across the top

const TEX := {
	"archer": preload("res://assets/art/defense/archer.png"),
	"mage": preload("res://assets/art/defense/mage.png"),
	"slime": preload("res://assets/art/defense/slime.png"),
	"goblin": preload("res://assets/art/defense/goblin.png"),
	"boss": preload("res://assets/art/defense/boss.png"),
	"wall": preload("res://assets/art/defense/wall.png"),
	"field": preload("res://assets/art/defense/field.png"),
}
const SPARK: Texture2D = preload("res://assets/sprites/sparkle.png")
# On-screen height of each pixel-art character (nearest filtering keeps the pixels crisp)
const HEIGHTS := {"archer": 92.0, "mage": 92.0, "slime": 80.0, "goblin": 104.0, "boss": 170.0}
# Monster stats at wave 1; HP and damage grow by MONSTER_GROWTH per wave
const MONSTERS := {
	"slime": {"hp": 40.0, "dps": 8.0, "speed": 70.0},
	"goblin": {"hp": 75.0, "dps": 14.0, "speed": 95.0},
	"boss": {"hp": 520.0, "dps": 30.0, "speed": 38.0},
}
const MONSTER_GROWTH: float = 1.13
const MONSTER_HIT_INTERVAL: float = 0.8
# Defenders: archers hit one target often, mages hit everything around the target
const UNITS := {
	"archer": {"damage": 13.0, "interval": 0.75, "splash": 0.0},
	"mage": {"damage": 26.0, "interval": 1.7, "splash": 80.0},
}
const UNIT_GROWTH: float = 0.06   # defenders hit this much harder each wave

var phase: String = "idle"       # idle / puzzle / wave / between / over
var paused: bool = false
var speed: float = 1.0
var wave: int = 1
var castle_hp: float = CASTLE_HP
var time_left: float = PUZZLE_TIME
var phase_points: int = 0
var units: Array = []            # {node, kind, cool}
var monsters: Array = []         # {node, kind, hp, max_hp, dps, speed, walk, cool, bar}
var _spawn_queue: Array = []
var _spawn_clock: float = 0.0
var _board_was_stuck: bool = false
var rng := RandomNumberGenerator.new()

# HUD (over the header during the puzzle phase)
var hud: Control
var _wave_label: Label
var _castle_label: Label
var _castle_fill: Panel
var _time_fill: Panel
var _time_label: Label
var _points_label: Label
var _army_label: Label
# Battlefield (whole screen during a wave)
var field: Control
var _units_layer: Node2D
var _field_title: Label
var _field_castle_fill: Panel
var _speed_btn: Button
var _wall_rect: TextureRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hud()
	_build_field()

# =========================================================
# Run flow
# =========================================================

func begin() -> void:
	rng.randomize()
	wave = 1
	castle_hp = CASTLE_HP
	speed = 1.0
	_speed_btn.text = "2배속"
	for list in [units, monsters]:
		for u in list:
			u["node"].queue_free()
		list.clear()
	_spawn_queue.clear()
	visible = true
	_start_puzzle(false)

func stop() -> void:
	phase = "over"
	field.visible = false

func add_points(n: int) -> void:
	if phase != "puzzle":
		return
	phase_points += n
	_refresh_hud()

# The board has nothing that fits: end the puzzle phase now; the next one starts on a new board
func board_stuck() -> void:
	if phase != "puzzle":
		return
	_board_was_stuck = true
	_end_puzzle()

func count(kind: String) -> int:
	return units.filter(func(u): return u["kind"] == kind).size()

func _start_puzzle(fresh: bool) -> void:
	phase = "puzzle"
	time_left = PUZZLE_TIME
	phase_points = 0
	hud.visible = true
	field.visible = false
	_refresh_hud()
	puzzle_started.emit(fresh)

func _end_puzzle() -> void:
	# Points become defenders while there are free spots on the wall; the rest repairs it
	var new_archers: int = phase_points / ARCHER_COST
	var new_mages: int = phase_points / MAGE_COST
	var added := {"archer": 0, "mage": 0}
	var overflow := 0
	for kind in ["mage", "archer"]:
		for i in range(new_mages if kind == "mage" else new_archers):
			if units.size() < SLOTS.size():
				_add_unit(kind)
				added[kind] += 1
			else:
				overflow += 1
	castle_hp = minf(CASTLE_HP, castle_hp + overflow * 20)
	_start_wave(added["archer"], added["mage"])

func _start_wave(new_archers: int, new_mages: int) -> void:
	phase = "wave"
	hud.visible = false
	field.visible = true
	_layout_units()
	_spawn_queue.clear()
	for i in range(3 + wave):
		_spawn_queue.append("slime")
	for i in range(maxi(0, wave - 2)):
		_spawn_queue.insert(rng.randi_range(0, _spawn_queue.size()), "goblin")
	if wave % BOSS_EVERY == 0:
		_spawn_queue.append("boss")
	_spawn_clock = 0.6
	_field_title.text = "WAVE %d" % wave
	_banner("WAVE %d" % wave, "궁수 +%d · 마법사 +%d" % [new_archers, new_mages])
	_refresh_field()
	wave_started.emit()

func _wave_cleared() -> void:
	_banner("WAVE %d 클리어!" % wave, "다시 블록을 깨서 병력을 모으세요")
	wave += 1
	phase = "between"
	get_tree().create_timer(1.6).timeout.connect(func():
		if phase == "between":
			var fresh := _board_was_stuck
			_board_was_stuck = false
			_start_puzzle(fresh))

func _castle_fallen() -> void:
	phase = "over"
	_banner("성이 무너졌어요", "WAVE %d까지 막았어요" % (wave - 1))
	get_tree().create_timer(1.4).timeout.connect(func(): defeated.emit(wave - 1))

func _process(delta: float) -> void:
	if paused or not visible:
		return
	match phase:
		"puzzle":
			time_left -= delta
			_refresh_timer()
			if time_left <= 0.0:
				_end_puzzle()
		"wave":
			_simulate(delta * speed)

# =========================================================
# Battle simulation (field coordinates)
# =========================================================

func _simulate(dt: float) -> void:
	var k: float = pow(MONSTER_GROWTH, wave - 1)
	if not _spawn_queue.is_empty():
		_spawn_clock -= dt
		if _spawn_clock <= 0.0:
			_spawn_monster(_spawn_queue.pop_front(), k)
			_spawn_clock = 0.8
	# Monsters walk down to the wall and slam it
	var stop_y: float = _wall_top() + 14.0
	for m in monsters:
		var node: Sprite2D = m["node"]
		if node.position.y < stop_y:
			node.position.y = minf(stop_y, node.position.y + m["speed"] * dt)
			m["walk"] += dt
			node.rotation = sin(m["walk"] * 9.0) * 0.07
			continue
		node.rotation = 0.0
		m["cool"] -= dt
		if m["cool"] > 0.0:
			continue
		m["cool"] = MONSTER_HIT_INTERVAL
		var dmg: float = m["dps"] * MONSTER_HIT_INTERVAL
		_bump(node, 8.0)
		castle_hp = maxf(0.0, castle_hp - dmg)
		_flash(_wall_rect, Color(1.8, 0.8, 0.8))
		_number(node.position + Vector2(0, 26), dmg, Color(1.0, 0.45, 0.4))
		_refresh_field()
		if castle_hp <= 0.0:
			_castle_fallen()
			return
	# Every defender fires at the monster closest to the wall
	for u in units:
		u["cool"] -= dt
		if u["cool"] > 0.0:
			continue
		var t: Dictionary = _closest_monster()
		if t.is_empty():
			continue
		var st: Dictionary = UNITS[u["kind"]]
		u["cool"] = st["interval"]
		_bump(u["node"], -6.0)
		_fire(u, t, st["damage"] * (1.0 + UNIT_GROWTH * (wave - 1)), st["splash"])
	_update_bars()
	if _spawn_queue.is_empty() and monsters.is_empty() and phase == "wave":
		_wave_cleared()

func _wall_scale() -> float:
	return FIELD_SIZE.x / TEX["wall"].get_width()

func _wall_top() -> float:
	return FIELD_SIZE.y - TEX["wall"].get_height() * _wall_scale()

func _height(node: Sprite2D) -> float:
	return node.texture.get_height() * node.scale.y

func _closest_monster() -> Dictionary:
	var best: Dictionary = {}
	for m in monsters:
		if m["node"].position.y < 20.0:
			continue # not on screen yet
		if best.is_empty() or m["node"].position.y > best["node"].position.y:
			best = m
	return best

func _damage_monster(m: Dictionary, dmg: float) -> void:
	if m["hp"] <= 0.0:
		return
	m["hp"] -= dmg
	if m["hp"] <= 0.0:
		monsters.erase(m)
		var node: Sprite2D = m["node"]
		var tw := node.create_tween().set_parallel(true)
		tw.tween_property(node, "modulate:a", 0.0, 0.3)
		tw.tween_property(node, "scale", node.scale * 1.25, 0.3)
		tw.chain().tween_callback(node.queue_free)

# Archers shoot an arrow; mages throw a fireball that bursts on everything near the target
func _fire(u: Dictionary, target: Dictionary, dmg: float, splash: float) -> void:
	var from: Vector2 = u["node"].position + Vector2(0, -_height(u["node"]) * 0.7)
	var to: Vector2 = target["node"].position + Vector2(0, -_height(target["node"]) * 0.5)
	var shot: Node2D
	if splash > 0.0:
		var orb := Sprite2D.new()
		orb.texture = SPARK
		orb.modulate = Color(1.0, 0.55, 0.15)
		orb.scale = Vector2.ONE * 1.3
		shot = orb
	else:
		# Bright arrow with a fading trail so it reads at a glance
		var arrow := Line2D.new()
		arrow.width = 9.0
		arrow.points = PackedVector2Array([Vector2.ZERO, Vector2(-48, 0)])
		arrow.begin_cap_mode = Line2D.LINE_CAP_ROUND
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 1.0, 0.75))
		g.set_color(1, Color(1.0, 0.8, 0.2, 0.0))
		arrow.gradient = g
		arrow.rotation = (to - from).angle()
		shot = arrow
	shot.position = from
	shot.z_index = 5
	_units_layer.add_child(shot)
	var tw := shot.create_tween()
	tw.tween_property(shot, "position", to, maxf(0.1, from.distance_to(to) / (1300.0 if splash <= 0.0 else 900.0)) / speed)
	tw.tween_callback(func():
		shot.queue_free()
		if splash > 0.0:
			_burst(to, splash)
			for m in monsters.duplicate():
				if m["node"].position.distance_to(target["node"].position if monsters.has(target) else to) <= splash:
					_impact(m, dmg, Color(1.0, 0.6, 0.2))
		elif monsters.has(target):
			_impact(target, dmg, Color(1.0, 0.95, 0.6)))

func _burst(at: Vector2, radius: float) -> void:
	var ring := Sprite2D.new()
	ring.texture = SPARK
	ring.modulate = Color(1.0, 0.5, 0.1, 0.9)
	ring.position = at
	ring.z_index = 6
	ring.scale = Vector2.ONE * 0.5
	_units_layer.add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector2.ONE * radius / 22.0, 0.22)
	tw.tween_property(ring, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(ring.queue_free)

# A hit on a monster: damage, a flash, a spark and the number
func _impact(m: Dictionary, dmg: float, col: Color) -> void:
	var node: Sprite2D = m["node"]
	var at: Vector2 = node.position + Vector2(rng.randf_range(-10, 10), -_height(node) * 0.45)
	_damage_monster(m, dmg)
	_flash(node, Color(2.2, 2.0, 2.0))
	var spark := Sprite2D.new()
	spark.texture = SPARK
	spark.modulate = col
	spark.position = at
	spark.z_index = 7
	spark.scale = Vector2.ONE * 0.4
	_units_layer.add_child(spark)
	var tw := spark.create_tween().set_parallel(true)
	tw.tween_property(spark, "scale", Vector2.ONE * 1.4, 0.18)
	tw.tween_property(spark, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(spark.queue_free)
	_number(at + Vector2(0, -16), dmg, Color(1.0, 0.95, 0.6))

func _flash(node: CanvasItem, col: Color) -> void:
	node.modulate = col
	node.create_tween().tween_property(node, "modulate", Color.WHITE, 0.18)

# Quick nudge along y (negative = up) using the sprite's offset so it doesn't fight its movement
func _bump(node: Sprite2D, amount: float) -> void:
	var base: float = -node.texture.get_height() * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "offset:y", base + amount / node.scale.y, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "offset:y", base, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# Small damage number that rises and fades
func _number(pos: Vector2, dmg: float, col: Color) -> void:
	var l := UIKit.label(str(roundi(dmg)), 22, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.05))
	l.size = Vector2(80, 30)
	l.position = pos - l.size * 0.5
	l.z_index = 9
	field.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 28, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tw.tween_callback(l.queue_free)

# =========================================================
# Units
# =========================================================

# Pixel art sprite standing on its feet at position, scaled to its kind's height
func _sprite(kind: String) -> Sprite2D:
	var tex: Texture2D = TEX[kind]
	var s := Sprite2D.new()
	s.texture = tex
	s.scale = Vector2.ONE * HEIGHTS[kind] / tex.get_height()
	s.offset = Vector2(0, -tex.get_height() * 0.5)
	_units_layer.add_child(s)
	return s

func _add_unit(kind: String) -> void:
	var node := _sprite(kind)
	node.position = Vector2(FIELD_SIZE.x * 0.5, FIELD_SIZE.y + 60.0)
	units.append({"node": node, "kind": kind, "cool": rng.randf_range(0.1, 0.6)})

func _spawn_monster(kind: String, k: float) -> void:
	var st: Dictionary = MONSTERS[kind]
	var node := _sprite(kind)
	var x: float = FIELD_SIZE.x * 0.5 if kind == "boss" else rng.randf_range(SPAWN_X.x, SPAWN_X.y)
	node.position = Vector2(x, -10.0)
	var hp: float = st["hp"] * k
	monsters.append({"node": node, "kind": kind, "hp": hp, "max_hp": hp, "dps": st["dps"] * k,
		"speed": st["speed"], "walk": rng.randf() * 3.0, "cool": 0.3, "bar": _bar(node)})

# Defenders stand on the wall walkway, filling the spots next to the gate first
func _layout_units() -> void:
	var y: float = _wall_top() + 30.0
	for i in range(units.size()):
		var target := Vector2(SLOTS[i], y)
		units[i]["node"].create_tween().tween_property(units[i]["node"], "position", target, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _bar(owner: Sprite2D) -> Panel:
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.6), Color.TRANSPARENT, 3))
	bg.size = Vector2(60, 8)
	bg.z_index = 6
	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(1, 1)
	fill.size = Vector2(58, 6)
	fill.add_theme_stylebox_override("panel", UIKit.box(Color(1.0, 0.4, 0.35), Color.TRANSPARENT, 2))
	bg.add_child(fill)
	_units_layer.add_child(bg)
	owner.tree_exiting.connect(bg.queue_free)
	return bg

func _update_bars() -> void:
	for m in monsters:
		var bg: Panel = m["bar"]
		var node: Sprite2D = m["node"]
		bg.position = node.position + Vector2(-30, -_height(node) - 10)
		var fill: Panel = bg.get_child(0)
		fill.size.x = 58.0 * clampf(m["hp"] / m["max_hp"], 0.0, 1.0)

# =========================================================
# HUD and screens
# =========================================================

func _build_hud() -> void:
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.position = Vector2(42, 92)
	hud.size = Vector2(636, 170)
	add_child(hud)
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size = hud.size
	panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.06, 0.08, 0.15, 0.85), UIKit.BORDER, 22, 2))
	hud.add_child(panel)
	_wave_label = UIKit.label("", 30, UIKit.GOLD)
	_wave_label.position = Vector2(20, 10)
	_wave_label.size = Vector2(200, 40)
	hud.add_child(_wave_label)
	var icon := TextureRect.new()
	icon.texture = TEX["archer"]
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(300, 8)
	icon.size = Vector2(40, 40)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(icon)
	var castle_bg := Panel.new()
	castle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	castle_bg.position = Vector2(346, 20)
	castle_bg.size = Vector2(270, 16)
	castle_bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.5), Color.TRANSPARENT, 8))
	hud.add_child(castle_bg)
	_castle_fill = Panel.new()
	_castle_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_castle_fill.position = Vector2(2, 2)
	_castle_fill.size = Vector2(266, 12)
	castle_bg.add_child(_castle_fill)
	_castle_label = UIKit.label("", UIKit.TYPE_CAPTION, UIKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	_castle_label.position = Vector2(346, 38)
	_castle_label.size = Vector2(270, 20)
	hud.add_child(_castle_label)
	var time_bg := Panel.new()
	time_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_bg.position = Vector2(20, 66)
	time_bg.size = Vector2(530, 20)
	time_bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.5), Color.TRANSPARENT, 10))
	hud.add_child(time_bg)
	_time_fill = Panel.new()
	_time_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_time_fill.position = Vector2(2, 2)
	_time_fill.size = Vector2(526, 16)
	time_bg.add_child(_time_fill)
	_time_label = UIKit.label("", 22, UIKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	_time_label.position = Vector2(550, 60)
	_time_label.size = Vector2(66, 30)
	hud.add_child(_time_label)
	_points_label = UIKit.label("", UIKit.TYPE_BODY, UIKit.TEXT)
	_points_label.position = Vector2(20, 96)
	_points_label.size = Vector2(600, 28)
	hud.add_child(_points_label)
	_army_label = UIKit.label("", UIKit.TYPE_SMALL, UIKit.MUTED)
	_army_label.position = Vector2(20, 128)
	_army_label.size = Vector2(600, 26)
	hud.add_child(_army_label)

func _build_field() -> void:
	field = Control.new()
	field.position = Vector2(0, FIELD_TOP)
	field.size = FIELD_SIZE
	field.clip_contents = true
	field.z_index = 200
	field.mouse_filter = Control.MOUSE_FILTER_STOP
	field.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
	field.visible = false
	add_child(field)
	# Top-down road from the top of the screen down to the wall
	var bg := TextureRect.new()
	bg.texture = TEX["field"]
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = FIELD_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(bg)
	var wall := TextureRect.new()
	_wall_rect = wall
	wall.texture = TEX["wall"]
	wall.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wall.stretch_mode = TextureRect.STRETCH_SCALE
	wall.size = Vector2(TEX["wall"].get_width(), TEX["wall"].get_height()) * _wall_scale()
	wall.position = Vector2(0, FIELD_SIZE.y - wall.size.y)
	wall.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.add_child(wall)
	_units_layer = Node2D.new()
	field.add_child(_units_layer)
	_field_title = UIKit.label("", 40, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_field_title.add_theme_constant_override("outline_size", 10)
	_field_title.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	_field_title.position = Vector2(0, 14)
	_field_title.size = Vector2(FIELD_SIZE.x, 54)
	field.add_child(_field_title)
	var castle_bg := Panel.new()
	castle_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	castle_bg.position = Vector2(160, 72)
	castle_bg.size = Vector2(400, 20)
	castle_bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.55), Color.TRANSPARENT, 10))
	field.add_child(castle_bg)
	_field_castle_fill = Panel.new()
	_field_castle_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_field_castle_fill.position = Vector2(2, 2)
	_field_castle_fill.size = Vector2(396, 16)
	castle_bg.add_child(_field_castle_fill)
	_speed_btn = Button.new()
	_speed_btn.text = "2배속"
	UIKit.style_button(_speed_btn, "secondary", UIKit.TYPE_BODY, 14)
	_speed_btn.position = Vector2(FIELD_SIZE.x - 160, 20)
	_speed_btn.size = Vector2(140, 56)
	_speed_btn.pressed.connect(func():
		speed = 2.0 if speed == 1.0 else 1.0
		_speed_btn.text = "1배속" if speed == 2.0 else "2배속")
	field.add_child(_speed_btn)

func _refresh_hud() -> void:
	_wave_label.text = "WAVE %d" % wave
	_set_castle_bar(_castle_fill, 266.0)
	_castle_label.text = "성벽 %d / %d" % [ceili(castle_hp), CASTLE_HP]
	_points_label.text = "모은 점수 %s  →  궁수 +%d · 마법사 +%d" % [UIKit.format_number(phase_points), phase_points / ARCHER_COST, phase_points / MAGE_COST]
	_army_label.text = "지금 병력: 궁수 %d · 마법사 %d  (궁수 %d점, 마법사 %d점마다 · 최대 %d명)" % [count("archer"), count("mage"), ARCHER_COST, MAGE_COST, SLOTS.size()]
	_refresh_timer()

func _refresh_timer() -> void:
	var r: float = clampf(time_left / PUZZLE_TIME, 0.0, 1.0)
	_time_fill.size.x = 526.0 * r
	_time_fill.add_theme_stylebox_override("panel", UIKit.box(UIKit.CYAN if r > 0.25 else UIKit.DANGER, Color.TRANSPARENT, 8))
	_time_label.text = "%d초" % ceili(maxf(time_left, 0.0))

func _refresh_field() -> void:
	_set_castle_bar(_field_castle_fill, 396.0)

func _set_castle_bar(fill: Panel, full: float) -> void:
	var r: float = castle_hp / CASTLE_HP
	fill.size.x = full * r
	fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.35, 0.9, 0.45) if r > 0.5 else (Color(1.0, 0.8, 0.25) if r > 0.25 else Color(1.0, 0.35, 0.3)), Color.TRANSPARENT, 7))

# Big text in the middle of the battlefield for a moment
func _banner(title: String, sub: String) -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(0, 300)
	box.size = Vector2(FIELD_SIZE.x, 140)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	field.add_child(box)
	var t := UIKit.label(title, 54, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_constant_override("outline_size", 12)
	t.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	box.add_child(t)
	var st := UIKit.label(sub, 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	st.add_theme_constant_override("outline_size", 8)
	st.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	box.add_child(st)
	box.pivot_offset = box.size * 0.5
	box.scale = Vector2.ONE * 0.6
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(box.queue_free)
