class_name DefenseMode
extends Control
# Block Defense: puzzle and battle take turns on the whole (portrait) screen.
#  1. Puzzle phase (PUZZLE_TIME seconds): the player breaks blocks on the normal board. The HUD in
#     the header shows the wave, the castle's HP, the time left and what the points so far buy.
#  2. The points of the phase turn into allies automatically: a spearman per SOLDIER_COST points
#     and a sniper per SNIPER_COST (up to the caps; extra points repair the castle).
#  3. Wave phase: the battlefield covers the screen. Monsters walk down the road from the top;
#     spearmen stand in a row of lanes above the wall at the bottom and block their lane, snipers
#     shoot from the wall. A lane with no spearman lets monsters reach the wall. Clear the wave to
#     go back to the puzzle; allies that survive stay. Every BOSS_EVERY waves a wizard boss comes.
#  The run ends when the castle falls; the score is the number of waves held off.
# Characters are pixel art scaled up with nearest filtering so the pixels stay crisp.
# MainGame runs the board and calls add_points() / board_stuck(); this node owns the rest.

signal wave_started
signal puzzle_started(fresh_board: bool)
signal defeated(waves_cleared: int)

const PUZZLE_TIME: float = 40.0
const SOLDIER_COST: int = 120
const SNIPER_COST: int = 300
const MAX_SOLDIERS: int = 8
const MAX_SNIPERS: int = 6
const CASTLE_HP: int = 300
const BOSS_EVERY: int = 5
const FIELD_TOP: float = 92.0
const FIELD_SIZE := Vector2(720, 1100)
# On-screen height of each pixel-art character (nearest filtering keeps the pixels crisp)
const HEIGHTS := {"soldier": 112.0, "sniper": 104.0, "slime": 84.0, "goblin": 112.0, "boss": 180.0}
# Columns: monsters walk down one of these x lanes; a spearman blocks the lane he stands in
const LANES: Array[float] = [80.0, 160.0, 240.0, 320.0, 400.0, 480.0, 560.0, 640.0]
const LANE_ORDER: Array[int] = [3, 4, 2, 5, 1, 6, 0, 7]   # centre lanes are filled first
const SNIPER_X: Array[float] = [310.0, 410.0, 210.0, 510.0, 110.0, 610.0]
const BLOCK_REACH: float = 44.0   # a spearman blocks monsters this close to his lane

const TEX := {
	"soldier": preload("res://assets/art/defense/soldier.png"),
	"sniper": preload("res://assets/art/defense/sniper.png"),
	"slime": preload("res://assets/art/defense/slime.png"),
	"goblin": preload("res://assets/art/defense/goblin.png"),
	"boss": preload("res://assets/art/defense/boss.png"),
	"wall": preload("res://assets/art/defense/wall.png"),
	"field": preload("res://assets/art/defense/field.png"),
}
# Monster stats at wave 1; HP and damage grow by MONSTER_GROWTH per wave
const MONSTERS := {
	"slime": {"hp": 40.0, "dps": 8.0, "speed": 42.0},
	"goblin": {"hp": 75.0, "dps": 14.0, "speed": 62.0},
	"boss": {"hp": 520.0, "dps": 30.0, "speed": 24.0},
}
const MONSTER_GROWTH: float = 1.13
const SOLDIER := {"hp": 70.0, "dps": 16.0}
const SNIPER := {"damage": 22.0, "interval": 1.3}

var phase: String = "idle"       # idle / puzzle / wave / over
var paused: bool = false
var speed: float = 1.0
var wave: int = 1
var castle_hp: float = CASTLE_HP
var time_left: float = PUZZLE_TIME
var phase_points: int = 0
var soldiers: Array = []         # {node, hp, max_hp}
var snipers: Array = []          # {node, cooldown}
var monsters: Array = []         # {node, kind, hp, max_hp, dps, speed, bar}
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
	for list in [soldiers, snipers, monsters]:
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

func _start_puzzle(fresh: bool) -> void:
	phase = "puzzle"
	time_left = PUZZLE_TIME
	phase_points = 0
	hud.visible = true
	field.visible = false
	_refresh_hud()
	puzzle_started.emit(fresh)

func _end_puzzle() -> void:
	# Points become allies; anything over the caps repairs the castle
	var new_soldiers: int = phase_points / SOLDIER_COST
	var new_snipers: int = phase_points / SNIPER_COST
	var overflow := 0
	for i in range(new_soldiers):
		if soldiers.size() < MAX_SOLDIERS:
			_add_soldier()
		else:
			overflow += 1
	for i in range(new_snipers):
		if snipers.size() < MAX_SNIPERS:
			_add_sniper()
		else:
			overflow += 1
	castle_hp = minf(CASTLE_HP, castle_hp + overflow * 20)
	# Survivors heal up a bit between waves
	for s in soldiers:
		s["hp"] = minf(s["max_hp"], s["hp"] + s["max_hp"] * 0.5)
	_start_wave(new_soldiers, new_snipers)

func _start_wave(new_soldiers: int, new_snipers: int) -> void:
	phase = "wave"
	hud.visible = false
	field.visible = true
	_layout_army()
	var k: float = pow(MONSTER_GROWTH, wave - 1)
	_spawn_queue.clear()
	for i in range(3 + wave):
		_spawn_queue.append("slime")
	for i in range(maxi(0, wave - 2)):
		_spawn_queue.insert(rng.randi_range(0, _spawn_queue.size()), "goblin")
	if wave % BOSS_EVERY == 0:
		_spawn_queue.append("boss")
	_spawn_clock = 0.6
	_field_title.text = "WAVE %d" % wave
	_banner("WAVE %d" % wave, "병사 +%d · 저격수 +%d" % [new_soldiers, new_snipers])
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
	# Spawning at the top of the road
	if not _spawn_queue.is_empty():
		_spawn_clock -= dt
		if _spawn_clock <= 0.0:
			_spawn_monster(_spawn_queue.pop_front(), k)
			_spawn_clock = 1.1
	# Monsters walk down their lane until a spearman in the lane or the wall stops them
	var wall_y: float = _wall_top() + 18.0
	for m in monsters:
		var node: Sprite2D = m["node"]
		var blocker: Dictionary = _blocker(node.position.x)
		var stop_y: float = wall_y
		if not blocker.is_empty():
			stop_y = blocker["node"].position.y - _height(blocker["node"]) * 0.55
		if node.position.y < stop_y:
			node.position.y = minf(stop_y, node.position.y + m["speed"] * dt)
			m["walk"] += dt
			node.rotation = sin(m["walk"] * 9.0) * 0.07
		else:
			node.rotation = 0.0
			var dmg: float = m["dps"] * dt
			if not blocker.is_empty():
				blocker["hp"] -= dmg
				if blocker["hp"] <= 0.0:
					_kill_soldier(blocker)
			else:
				castle_hp = maxf(0.0, castle_hp - dmg)
				_refresh_field()
				if castle_hp <= 0.0:
					_castle_fallen()
					return
	# Spearmen hit a monster that reached them in their lane
	for s in soldiers:
		var target: Dictionary = _monster_at(s["node"].position, 150.0)
		if not target.is_empty():
			_damage_monster(target, SOLDIER["dps"] * dt * (1.0 + 0.04 * (wave - 1)))
	# Snipers shoot the monster closest to the wall
	for sn in snipers:
		sn["cooldown"] -= dt
		if sn["cooldown"] <= 0.0 and not monsters.is_empty():
			var t: Dictionary = _lowest_monster()
			if not t.is_empty():
				sn["cooldown"] = SNIPER["interval"]
				_shoot(sn["node"].position + Vector2(0, -_height(sn["node"]) * 0.8), t, SNIPER["damage"] * (1.0 + 0.05 * (wave - 1)))
	_update_bars()
	if _spawn_queue.is_empty() and monsters.is_empty() and phase == "wave":
		_wave_cleared()

func _wall_scale() -> float:
	return FIELD_SIZE.x / TEX["wall"].get_width()

func _wall_top() -> float:
	return FIELD_SIZE.y - TEX["wall"].get_height() * _wall_scale()

func _height(node: Sprite2D) -> float:
	return node.texture.get_height() * node.scale.y

# The spearman standing in the lane at x, if any
func _blocker(x: float) -> Dictionary:
	for s in soldiers:
		if absf(s["node"].position.x - x) <= BLOCK_REACH:
			return s
	return {}

# A monster in the spearman's lane that is within reach above him
func _monster_at(pos: Vector2, reach: float) -> Dictionary:
	var best: Dictionary = {}
	for m in monsters:
		var mp: Vector2 = m["node"].position
		if absf(mp.x - pos.x) > BLOCK_REACH or pos.y - mp.y > reach:
			continue
		if best.is_empty() or mp.y > best["node"].position.y:
			best = m
	return best

func _lowest_monster() -> Dictionary:
	var best: Dictionary = {}
	for m in monsters:
		if m["node"].position.y < 0.0:
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

func _kill_soldier(s: Dictionary) -> void:
	soldiers.erase(s)
	var node: Sprite2D = s["node"]
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "modulate", Color(1, 0.3, 0.3, 0.0), 0.35)
	tw.tween_property(node, "position:y", node.position.y + 20.0, 0.35)
	tw.chain().tween_callback(node.queue_free)

# A crossbow bolt flies up at the target
func _shoot(from: Vector2, target: Dictionary, dmg: float) -> void:
	var bolt := Line2D.new()
	bolt.width = 4.0
	bolt.default_color = Color(1.0, 0.95, 0.6)
	bolt.points = PackedVector2Array([Vector2.ZERO, Vector2(-22, 0)])
	bolt.position = from
	bolt.z_index = 5
	_units_layer.add_child(bolt)
	var to: Vector2 = target["node"].position + Vector2(0, -_height(target["node"]) * 0.5)
	bolt.rotation = (to - bolt.position).angle()
	var tw := bolt.create_tween()
	tw.tween_property(bolt, "position", to, maxf(0.08, bolt.position.distance_to(to) / 1400.0) / speed)
	tw.tween_callback(func():
		bolt.queue_free()
		if monsters.has(target):
			_damage_monster(target, dmg)
			_flash(target["node"]))

func _flash(node: CanvasItem) -> void:
	node.modulate = Color(2.0, 1.6, 1.6)
	node.create_tween().tween_property(node, "modulate", Color.WHITE, 0.15)

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

func _add_soldier() -> void:
	var node := _sprite("soldier")
	node.position = Vector2(FIELD_SIZE.x * 0.5, FIELD_SIZE.y + 40.0)
	soldiers.append({"node": node, "hp": SOLDIER["hp"], "max_hp": SOLDIER["hp"], "bar": _bar(node)})

func _add_sniper() -> void:
	var node := _sprite("sniper")
	node.position = Vector2(FIELD_SIZE.x * 0.5, FIELD_SIZE.y + 40.0)
	snipers.append({"node": node, "cooldown": rng.randf_range(0.2, 1.0)})

func _spawn_monster(kind: String, k: float) -> void:
	var st: Dictionary = MONSTERS[kind]
	var node := _sprite(kind)
	var lane: float = LANES[rng.randi() % LANES.size()] + rng.randf_range(-10.0, 10.0)
	if kind == "boss":
		lane = FIELD_SIZE.x * 0.5
	node.position = Vector2(lane, -10.0)
	var hp: float = st["hp"] * k
	monsters.append({"node": node, "kind": kind, "hp": hp, "max_hp": hp, "dps": st["dps"] * k,
		"speed": st["speed"], "walk": rng.randf() * 3.0, "bar": _bar(node)})

# Spearmen stand in a row just above the wall, centre lanes first; snipers on the wall
func _layout_army() -> void:
	var front_y: float = _wall_top() + 4.0
	for i in range(soldiers.size()):
		var target := Vector2(LANES[LANE_ORDER[i]], front_y)
		soldiers[i]["node"].create_tween().tween_property(soldiers[i]["node"], "position", target, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in range(snipers.size()):
		var target := Vector2(SNIPER_X[i], _wall_top() + 120.0)
		snipers[i]["node"].create_tween().tween_property(snipers[i]["node"], "position", target, 0.5)

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
	bg.add_child(fill)
	_units_layer.add_child(bg)
	owner.tree_exiting.connect(bg.queue_free)
	return bg

func _update_bars() -> void:
	for list in [soldiers, monsters]:
		for u in list:
			var bg: Panel = u["bar"]
			var node: Sprite2D = u["node"]
			bg.position = node.position + Vector2(-30, -_height(node) - 10)
			var ratio: float = clampf(u["hp"] / u["max_hp"], 0.0, 1.0)
			var fill: Panel = bg.get_child(0)
			fill.size.x = 58.0 * ratio
			var col: Color = Color(0.35, 0.9, 0.45) if list == soldiers else Color(1.0, 0.4, 0.35)
			fill.add_theme_stylebox_override("panel", UIKit.box(col, Color.TRANSPARENT, 2))

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
	var castle_icon := TextureRect.new()
	castle_icon.texture = TEX["soldier"]
	castle_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	castle_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	castle_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	castle_icon.position = Vector2(300, 8)
	castle_icon.size = Vector2(40, 40)
	castle_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(castle_icon)
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
	_castle_label.text = "성 %d / %d" % [ceili(castle_hp), CASTLE_HP]
	var s: int = phase_points / SOLDIER_COST
	var n: int = phase_points / SNIPER_COST
	_points_label.text = "모은 점수 %s  →  병사 +%d · 저격수 +%d" % [UIKit.format_number(phase_points), s, n]
	_army_label.text = "지금 병력: 병사 %d · 저격수 %d   (병사 %d점, 저격수 %d점마다)" % [soldiers.size(), snipers.size(), SOLDIER_COST, SNIPER_COST]
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
