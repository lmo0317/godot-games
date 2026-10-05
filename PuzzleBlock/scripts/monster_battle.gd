class_name MonsterBattle
extends Control
# Monster Battle (Puzzle & Dragons style): the puzzle stays exactly as in classic, on a board
# shrunk to 85% (MainGame's compact layout); the stage above it shows one monster at a time.
# - Points from a clear are its damage to the monster (more lines and a combo hit harder).
# - The monster attacks after a countdown of the player's moves ("N턴 후 공격").
# - Beat it and the next, stronger monster comes; every BOSS_EVERY stages a boss.
# - The run ends when the player's HP runs out (or the board is stuck, handled by MainGame);
#   the record is the stage reached.

signal defeated(stage: int)
signal player_hit(damage: int)

const STAGE_TOP: float = 90.0
const STAGE_SIZE := Vector2(720, 437)
const PLAYER_HP: int = 300
const HEAL_ON_CLEAR: int = 40
const BOSS_EVERY: int = 5
const STAGE_GROWTH: float = 1.22      # monster HP per stage
const ATTACK_GROWTH: float = 1.10     # monster attack per stage
const MONSTERS: Array[Dictionary] = [
	{"name": "슬라임", "tex": preload("res://assets/art/battle/slime.png"), "hp": 120.0, "atk": 20.0, "every": 3, "height": 170.0, "flip": false},
	{"name": "고블린", "tex": preload("res://assets/art/battle/goblin.png"), "hp": 160.0, "atk": 26.0, "every": 3, "height": 230.0, "flip": true},
]
const BOSS := {"name": "대마법사", "tex": preload("res://assets/art/battle/wizard.png"), "hp": 420.0, "atk": 40.0, "every": 2, "height": 290.0, "flip": true}
const SLASH: Texture2D = preload("res://assets/art/battle/fx_slash.png")
const FIRE: Texture2D = preload("res://assets/art/battle/fx_fireball.png")
const BACKDROP: Texture2D = preload("res://assets/art/battle/battlefield.jpg")

var stage: int = 1
var hp: int = PLAYER_HP
var finished: bool = true
var switching: bool = false   # between a monster going down and the next one arriving
var monster: Dictionary = {}
var m_hp: float = 0.0
var m_max: float = 1.0
var countdown: int = 3
var rng := RandomNumberGenerator.new()

var _stage_label: Label
var _monster: Sprite2D
var _m_name: Label
var _m_fill: Panel
var _bubble: Panel
var _bubble_num: Label
var _p_fill: Panel
var _p_label: Label
var _monster_home := Vector2(360, 0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(0, STAGE_TOP)
	size = STAGE_SIZE
	clip_contents = true
	_build()

# =========================================================
# Flow (called by MainGame)
# =========================================================

func begin() -> void:
	rng.randomize()
	stage = 1
	hp = PLAYER_HP
	finished = false
	switching = false
	visible = true
	_spawn_monster(false)
	_refresh()

func stop() -> void:
	finished = true

# A clear: its points are the damage; lines/combo/perfect pick how big the slash looks
func player_attack(damage: int, lines: int, combo: int, perfect: bool) -> void:
	if finished or switching or damage <= 0:
		return
	var tier: int = 2 if (lines >= 3 or perfect) else (1 if (lines >= 2 or combo >= 3) else 0)
	var slashes: int = tier + 1
	for i in range(slashes):
		var s := Sprite2D.new()
		s.texture = SLASH
		s.position = _monster.position + Vector2(rng.randf_range(-30, 30), -_monster_height() * 0.5 + rng.randf_range(-30, 30))
		s.rotation = [0.0, 1.1, -0.9][i] + rng.randf_range(-0.2, 0.2)
		s.scale = Vector2.ZERO
		s.z_index = 5
		add_child(s)
		var size: float = (0.9 + 0.25 * tier) * 200.0 / SLASH.get_height()
		var tw := s.create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(s, "scale", Vector2.ONE * size, 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "modulate:a", 0.0, 0.22).set_delay(0.05)
		tw.tween_callback(s.queue_free)
	_hit_monster(damage, combo)

# Each piece the player places counts the monster's attack down
func on_player_move() -> void:
	if finished or switching:
		return
	countdown -= 1
	if countdown <= 0:
		countdown = monster["every"]
		_monster_attack()
	_refresh()

# =========================================================
# Monster
# =========================================================

func _spawn_monster(slide_in: bool) -> void:
	var boss: bool = stage % BOSS_EVERY == 0
	monster = BOSS if boss else MONSTERS[(stage - 1) % MONSTERS.size()]
	var k: float = pow(STAGE_GROWTH, stage - 1)
	m_max = monster["hp"] * k
	m_hp = m_max
	countdown = monster["every"]
	_monster.texture = monster["tex"]
	_monster.offset = Vector2(0, -monster["tex"].get_height() * 0.5)   # position = feet
	_monster.flip_h = monster["flip"]
	var sc: float = monster["height"] / monster["tex"].get_height()
	_monster.scale = Vector2.ONE * sc
	_monster.modulate = Color.WHITE
	_monster.rotation = 0.0
	_monster_home = Vector2(STAGE_SIZE.x * 0.5, STAGE_SIZE.y - 70.0)
	_monster.position = _monster_home + (Vector2(420, 0) if slide_in else Vector2.ZERO)
	if slide_in:
		_monster.create_tween().tween_property(_monster, "position", _monster_home, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_m_name.text = ("BOSS · " if boss else "") + monster["name"]
	_stage_label.text = "STAGE %d" % stage
	_refresh()

func _monster_height() -> float:
	return _monster.texture.get_height() * _monster.scale.y

func _hit_monster(damage: int, combo: int) -> void:
	m_hp = maxf(0.0, m_hp - damage)
	_monster.modulate = Color(2.2, 1.6, 1.6)
	var tw := _monster.create_tween()
	tw.tween_property(_monster, "position:x", _monster_home.x + 16.0, 0.05)
	tw.tween_property(_monster, "position:x", _monster_home.x, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_monster, "modulate", Color.WHITE, 0.25)
	_number("-%d" % damage, _monster.position + Vector2(-60, -_monster_height() * 0.6), Color(1.0, 0.9, 0.45), 46)
	if combo >= 2:
		_number("Combo %d" % combo, _monster.position + Vector2(-60, -_monster_height() * 0.6 + 46), Color(0.75, 0.9, 1.0), 26)
	_refresh()
	if m_hp <= 0.0:
		_monster_down()

func _monster_down() -> void:
	switching = true
	var tw := _monster.create_tween().set_parallel(true)
	tw.tween_property(_monster, "modulate:a", 0.0, 0.5)
	tw.tween_property(_monster, "scale", _monster.scale * 1.2, 0.5)
	hp = mini(PLAYER_HP, hp + HEAL_ON_CLEAR)
	_banner("STAGE %d 클리어!" % stage, "체력 +%d" % HEAL_ON_CLEAR)
	_refresh()
	get_tree().create_timer(1.3).timeout.connect(func():
		if finished:
			return
		stage += 1
		_spawn_monster(true)
		switching = false)

func _monster_attack() -> void:
	# The monster lunges and a fireball flies down at the player's HP bar
	var dmg: int = roundi(monster["atk"] * pow(ATTACK_GROWTH, stage - 1))
	var lunge := _monster.create_tween()
	lunge.tween_property(_monster, "position:y", _monster_home.y + 14.0, 0.1)
	lunge.tween_property(_monster, "position:y", _monster_home.y, 0.18)
	var f := Sprite2D.new()
	f.texture = FIRE
	f.position = _monster.position + Vector2(0, -_monster_height() * 0.5)
	f.rotation = Vector2.LEFT.angle_to(Vector2(0, 1))
	f.scale = Vector2.ONE * 90.0 / FIRE.get_width()
	f.z_index = 6
	add_child(f)
	var to := Vector2(_p_fill.get_parent().position.x + 300, _p_fill.get_parent().position.y)
	var ft := f.create_tween()
	ft.tween_property(f, "position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	ft.tween_callback(func():
		f.queue_free()
		if finished:
			return
		hp = maxi(0, hp - dmg)
		_number("-%d" % dmg, to + Vector2(-60, -60), Color(1.0, 0.45, 0.4), 40)
		player_hit.emit(dmg)
		_refresh()
		if hp <= 0:
			finished = true
			_banner("쓰러졌어요", "STAGE %d" % stage)
			get_tree().create_timer(1.0).timeout.connect(func(): defeated.emit(stage)))

# =========================================================
# Display
# =========================================================

func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = BACKDROP
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = STAGE_SIZE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.05, 0.12, 0.28)
	shade.size = STAGE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_monster = Sprite2D.new()
	add_child(_monster)
	_stage_label = _outlined("", 28, UIKit.GOLD)
	_stage_label.position = Vector2(20, 12)
	_stage_label.size = Vector2(240, 40)
	add_child(_stage_label)
	var m_bar := _bar(Vector2(210, 18), Vector2(300, 20))
	_m_fill = m_bar.get_child(0)
	_m_name = _outlined("", 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_m_name.position = Vector2(160, 40)
	_m_name.size = Vector2(400, 28)
	add_child(_m_name)
	# Attack countdown bubble
	_bubble = Panel.new()
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.size = Vector2(70, 70)
	_bubble.position = Vector2(560, 120)
	_bubble.add_theme_stylebox_override("panel", UIKit.box(Color(0.16, 0.08, 0.24, 0.92), Color(1.0, 0.47, 0.35), 35, 4))
	add_child(_bubble)
	_bubble_num = _outlined("3", 40, Color(1.0, 0.55, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	_bubble_num.size = Vector2(70, 70)
	_bubble_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bubble.add_child(_bubble_num)
	var cap := _outlined("턴 후 공격", 16, Color(1.0, 0.8, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	cap.position = Vector2(-25, 72)
	cap.size = Vector2(120, 24)
	_bubble.add_child(cap)
	# Player HP along the bottom of the stage
	var me := _outlined("내 체력", 20, UIKit.TEXT)
	me.position = Vector2(20, STAGE_SIZE.y - 44)
	me.size = Vector2(100, 30)
	add_child(me)
	var p_bar := _bar(Vector2(110, STAGE_SIZE.y - 40), Vector2(590, 22))
	_p_fill = p_bar.get_child(0)
	_p_label = _outlined("", 18, Color(0.85, 1.0, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
	_p_label.position = Vector2(400, STAGE_SIZE.y - 70)
	_p_label.size = Vector2(300, 26)
	add_child(_p_label)

func _bar(pos: Vector2, sz: Vector2) -> Panel:
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = pos
	bg.size = sz
	bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.6), Color.TRANSPARENT, int(sz.y / 2)))
	add_child(bg)
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
	var mr: float = clampf(m_hp / m_max, 0.0, 1.0)
	var mw: float = _m_fill.get_parent().size.x - 4
	_m_fill.create_tween().tween_property(_m_fill, "size:x", maxf(0.0, mw * mr), 0.2)
	_m_fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.92, 0.32, 0.28), Color.TRANSPARENT, 8))
	var pr: float = float(hp) / PLAYER_HP
	var pw: float = _p_fill.get_parent().size.x - 4
	_p_fill.create_tween().tween_property(_p_fill, "size:x", maxf(0.0, pw * pr), 0.2)
	_p_fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.35, 0.86, 0.43) if pr > 0.35 else Color(1.0, 0.4, 0.35), Color.TRANSPARENT, 9))
	_p_label.text = "%d / %d" % [hp, PLAYER_HP]
	_bubble_num.text = str(countdown)
	_bubble.modulate = Color(1.3, 0.9, 0.9) if countdown <= 1 else Color.WHITE

func _number(text: String, pos: Vector2, col: Color, size_px: int) -> void:
	var l := _outlined(text, size_px, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 10)
	l.size = Vector2(240, size_px + 16)
	l.position = pos - Vector2(60, 0)
	l.z_index = 8
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ONE * 0.4
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", l.position.y - 30, 0.55)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.25)
	tw.tween_callback(l.queue_free)

func _banner(title: String, sub: String) -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(0, 120)
	box.size = Vector2(STAGE_SIZE.x, 120)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.z_index = 10
	add_child(box)
	box.add_child(_outlined(title, 46, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_outlined(sub, 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.pivot_offset = box.size * 0.5
	box.scale = Vector2.ONE * 0.6
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.8)
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(box.queue_free)
