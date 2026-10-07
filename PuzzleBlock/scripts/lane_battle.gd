class_name LaneBattle
extends Control
# "블록 기사단": a real-time side-view lane battle above the normal puzzle (board shrunk by MainGame).
# Ideas taken from The Battle Cats, Paladog, Stick War and Plants vs Zombies (docs/BATTLE_RESEARCH.md):
# - Units walk at their own speed and hit the first enemy in range on their own attack timer.
#   Big hits knock units back (each kind has a knockback count), deaths fly off with a poof.
# - Gold trickles in up to the wallet's limit; clears pay more. "수입 UP" raises income and limit.
# - Each soldier has a summon cooldown, so cheap walls and expensive dealers get mixed.
# - Clears and combos charge the cannon; one tap pushes back and hurts every enemy.
# - Stages have a rhythm: single monsters, a big wave after a horn warning, and a boss that roars
#   in with a shockwave when the fortress drops to half.
# - Enemy traits ask for the right soldier: bats fly (only archers and mages reach them), armored
#   skeletons shrug off everything but spears, slimes come in swarms (mage splash).
# - One toggle switches the army between charging and holding in front of the castle.
# - Auto mode plays the battle so the player can stay on the puzzle: it summons as gold comes in
#   (a front line of knights, archers for bats, spears for armor, a mix otherwise), fires the cannon
#   into crowds or the boss, and buys income upgrades once the army stands.
# The battle pauses while the settings window is open (MainGame sets `paused`).
# Art: Codex pixel art cut by tools/import_lane_art.py, drawn at whole-number scales.

signal defeated(stage: int)
signal castle_hit(damage: int)
# The game's header is hidden in this mode; its home / settings / sound buttons live in the lane
signal home_pressed
signal settings_pressed
signal sound_pressed

const LANE_H: float = 330.0
const BAR_H: float = 100.0
const PX: float = 2.0                 # unit and base sprites are drawn at x2
const GROUND: float = 296.0           # feet line in the lane
const FLY_H: float = 58.0             # bats hover this high
const ALLY_START: float = 192.0       # just in front of the castle (it ends at x 154)
const ENEMY_START: float = 520.0      # just in front of the fortress (it starts at x 558)
const ALLY_BASE_X: float = 190.0      # where enemies stand to hit the castle
const ENEMY_BASE_X: float = 528.0     # where soldiers stand to hit the fortress
const DEFEND_X: float = 300.0         # soldiers hold here in defend mode
const CASTLE_X: float = 80.0          # building centres, for hit effects and HP bars
const FORT_X: float = 636.0
const BASE_BAR_W: float = 132.0
const KB_DIST: float = 36.0
const KB_TIME: float = 0.45
const MAX_ALLIES: int = 10
const MAX_ENEMIES: int = 14
const CASTLE_HP: int = 600
const START_GOLD: int = 60
# Wallet levels: limit, gold per second, cost of the next level
const WALLET_MAX: Array[int] = [200, 320, 480, 700, 1000]
const WALLET_INCOME: Array[float] = [3.0, 4.0, 5.0, 6.2, 7.5]
const WALLET_COST: Array[int] = [80, 160, 260, 400]
const GOLD_PER_LINE: int = 18
const GOLD_PER_POINT: float = 0.5
const CANNON_PER_LINE: float = 12.0
const CANNON_PER_POINT: float = 0.08
const CANNON_DAMAGE: float = 30.0
const BIG_WAVE_FIRST: float = 30.0
const BIG_WAVE_EVERY: float = 30.0
const WARN_TIME: float = 3.0
const ALLIES := {
	# speed: px per second, every: seconds between hits, cool: summon cooldown, kb: knockbacks per life
	"knight": {"name": "기사", "cost": 50, "hp": 70.0, "atk": 12.0, "range": 44.0, "speed": 34.0, "every": 1.0, "cool": 2.0, "kb": 2},
	"archer": {"name": "궁수", "cost": 80, "hp": 34.0, "atk": 9.0, "range": 140.0, "speed": 30.0, "every": 1.2, "cool": 4.0, "kb": 1, "shot": "arrow"},
	"mage": {"name": "마법사", "cost": 120, "hp": 30.0, "atk": 14.0, "range": 110.0, "speed": 28.0, "every": 1.6, "cool": 8.0, "kb": 1, "shot": "orb", "splash": 50.0},
	"spearman": {"name": "창병", "cost": 160, "hp": 110.0, "atk": 16.0, "range": 60.0, "speed": 26.0, "every": 1.2, "cool": 12.0, "kb": 3},
}
const ALLY_ORDER: Array[String] = ["knight", "archer", "mage", "spearman"]
const ENEMIES := {
	"slime": {"hp": 18.0, "atk": 5.0, "range": 40.0, "speed": 22.0, "every": 1.2, "kb": 1, "swarm": 2},
	"goblin": {"hp": 52.0, "atk": 9.0, "range": 44.0, "speed": 30.0, "every": 1.1, "kb": 2},
	"skeleton": {"hp": 64.0, "atk": 11.0, "range": 44.0, "speed": 26.0, "every": 1.2, "kb": 2},
	"bat": {"hp": 30.0, "atk": 7.0, "range": 40.0, "speed": 40.0, "every": 1.0, "kb": 1, "flying": true},
	"armored": {"hp": 80.0, "atk": 12.0, "range": 44.0, "speed": 20.0, "every": 1.3, "kb": 3, "armor": true},
	"orc": {"hp": 130.0, "atk": 18.0, "range": 50.0, "speed": 20.0, "every": 1.5, "kb": 2},
}
const ENEMY_GROWTH: float = 1.12
const FORTRESS_HP: float = 240.0
const FORTRESS_GROWTH: float = 1.25

var stage: int = 1
var paused: bool = false
var gold: int = START_GOLD
var wallet: int = 0                   # wallet level index
var cannon: float = 0.0               # 0..100
var charging: bool = true             # false = hold in front of the castle
var auto_summon: bool = false         # kept between runs in this session
var _auto_timer: float = 0.0
var castle_hp: int = CASTLE_HP
var fortress_hp: float = FORTRESS_HP
var fortress_max: float = FORTRESS_HP
var boss_out: bool = false
var finished: bool = true
var switching: bool = false
var trickle_timer: float = 0.0
var wave_timer: float = 0.0
var warned: bool = false
var cooldown: Dictionary = {}         # kind -> seconds left
var units: Array = []                 # see _spawn for the fields
var rng := RandomNumberGenerator.new()
var tex: Dictionary = {}

var _gold_acc: float = 0.0
var _clock: float = 0.0
var _hitstop: float = 0.0
var _dirty: bool = false
var _sfx_last: Dictionary = {}
var _castle_hit_last: float = -9.0
var _pending: Array = []              # [seconds left, kind, k] enemies of a wave still to come
var _view: Control
var _units_layer: Node2D
var _bars_layer: Node2D
var _castle_sprite: Sprite2D
var _cannon_sprite: Sprite2D
var _fort_sprite: Sprite2D
var _stage_label: Label
var _castle_fill: Panel
var _castle_label: Label
var _fort_fill: Panel
var _fort_label: Label
var _menu: Dictionary = {}
var _gold_label: Label
var _wallet_label: Label
var _income_btn: Button
var _march_btn: Button
var _auto_btn: Button
var _cannon_btn: Button
var _cannon_fill: ColorRect
var _cannon_label: Label
var _buttons: Dictionary = {}
var _cool_veils: Dictionary = {}
var _icons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(720, LANE_H + BAR_H)
	var names: Array = ["castle", "fortress", "lane"]
	names.append_array(ALLY_ORDER)
	names.append_array(ENEMIES.keys())
	names.append_array(["cannon", "cannonball", "flash", "boom_s", "boom_l", "smoke"])
	for k in names:
		tex[k] = load("res://assets/art/lane/%s.png" % k)
	_icons["armor"] = _pixel_icon([".XXXXX.", "XWWWWWX", "XWWWWWX", "XWWWWWX", ".XWWWX.", "..XWX..", "...X..."], Color(0.8, 0.85, 0.95))
	_icons["flying"] = _pixel_icon(["X.....X", "XX...XX", "XWX.XWX", "XWWXWWX", ".XWWWX.", "..XXX.."], Color(0.75, 0.9, 1.0))
	_build()

# =========================================================
# Flow (called by MainGame)
# =========================================================

func begin() -> void:
	rng.randomize()
	stage = 1
	paused = false
	gold = START_GOLD
	wallet = 0
	cannon = 0.0
	charging = true
	_gold_acc = 0.0
	_hitstop = 0.0
	castle_hp = CASTLE_HP
	finished = false
	switching = false
	for k in ALLY_ORDER:
		cooldown[k] = 0.0
	for u in units:
		u["node"].queue_free()
	units.clear()
	_pending.clear()
	visible = true
	_start_stage()

func stop() -> void:
	finished = true

func wallet_max() -> int:
	return WALLET_MAX[wallet]

# Gold and cannon charge for a clear: per line plus a share of the clear's points (combos pay more)
func on_clear(lines: int, points: int) -> void:
	if finished:
		return
	var n: int = mini(GOLD_PER_LINE * lines + int(points * GOLD_PER_POINT), wallet_max() - gold)
	gold += n
	var was_full: bool = cannon >= 100.0
	cannon = minf(100.0, cannon + CANNON_PER_LINE * lines + points * CANNON_PER_POINT)
	if cannon >= 100.0 and not was_full:
		_sfx("b_summon", -4.0)
	if n > 0:
		var l := _outlined("+%d" % n, 24, UIKit.GOLD)
		l.position = _gold_label.position + Vector2(80, -2)
		l.size = Vector2(90, 32)
		_gold_label.get_parent().add_child(l)
		var tw := l.create_tween()
		tw.tween_property(l, "position:y", l.position.y - 18, 0.6)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.4)
		tw.tween_callback(l.queue_free)
	_refresh()

func summon(kind: String) -> bool:
	var st: Dictionary = ALLIES[kind]
	if finished or gold < st["cost"] or cooldown.get(kind, 0.0) > 0.0 or _count(1) >= MAX_ALLIES:
		return false
	gold -= st["cost"]
	cooldown[kind] = st["cool"]
	_spawn(kind, 1, 1.0)
	_sfx("b_summon", -10.0)
	_refresh()
	return true

func upgrade_wallet() -> bool:
	if finished or wallet >= WALLET_COST.size() or gold < WALLET_COST[wallet]:
		return false
	gold -= WALLET_COST[wallet]
	wallet += 1
	SoundManager.play_click()
	_refresh()
	return true

# The castle cannon fires: recoil and muzzle flash, a cannonball arcs to the nearest monster, then
# explosions ripple through every monster on the lane (damage and knockback land with each blast)
func fire_cannon() -> bool:
	if finished or switching or cannon < 100.0:
		return false
	cannon = 0.0
	_sfx("b_cannon", -3.0)
	castle_hit.emit(0) # a small screen shake
	var gun: Sprite2D = _cannon_sprite
	var rest: Vector2 = gun.position
	var rt := gun.create_tween()
	rt.tween_property(gun, "position:x", rest.x - 8.0, 0.05)
	rt.tween_property(gun, "position:x", rest.x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tip: Vector2 = rest + Vector2(gun.texture.get_width() * PX, gun.texture.get_height() * PX * 0.35)
	_fx(["flash"], tip + Vector2(10, 0), [0.12])
	var foes: Array = units.filter(func(u): return u["side"] == -1)
	foes.sort_custom(func(a, b): return a["node"].position.x < b["node"].position.x)
	var land: Vector2 = Vector2(360, GROUND - 20) if foes.is_empty() else _mid(foes[0])
	var ball := Sprite2D.new()
	ball.texture = tex["cannonball"]
	ball.scale = Vector2.ONE * PX
	ball.position = tip
	ball.z_index = 6
	_view.add_child(ball)
	var flight: float = 0.28
	var bt := ball.create_tween()
	bt.tween_method(func(t: float):
		ball.position = tip.lerp(land, t) + Vector2(0, -70.0 * sin(PI * t))
		ball.rotation = lerpf(-0.5, 0.6, t), 0.0, 1.0, flight)
	bt.tween_callback(ball.queue_free)
	var dmg: float = CANNON_DAMAGE * pow(ENEMY_GROWTH, stage - 1)
	if foes.is_empty():
		get_tree().create_timer(flight).timeout.connect(func(): _boom(land))
	for i in range(foes.size()):
		var u: Dictionary = foes[i]
		get_tree().create_timer(flight + i * 0.07).timeout.connect(func():
			if not units.has(u):
				return
			_boom(_mid(u))
			u["hp"] -= dmg
			_flash(u["node"])
			_number(_head(u), dmg, Color(1.0, 0.9, 0.4))
			if u["hp"] > 0.0:
				_knock(u, KB_DIST * 1.5)
			_dirty = true)
	return true

func _boom(at: Vector2) -> void:
	_fx(["boom_s", "boom_l", "smoke"], at, [0.06, 0.12, 0.3])
	_sfx("b_hit", -8.0)
	_hitstop = maxf(_hitstop, 0.04)

func _mid(u: Dictionary) -> Vector2:
	return u["node"].position + Vector2(0, -_height(u["node"]) * 0.5)

# A short frame-by-frame effect; the last frame fades out
func _fx(frames: Array, at: Vector2, times: Array) -> void:
	var sp := Sprite2D.new()
	sp.texture = tex[frames[0]]
	sp.scale = Vector2.ONE * PX
	sp.position = at
	sp.z_index = 7
	_view.add_child(sp)
	var tw := sp.create_tween()
	for i in range(frames.size()):
		if i > 0:
			var f: String = frames[i]
			tw.tween_callback(func(): sp.texture = tex[f])
		if i == frames.size() - 1:
			tw.tween_property(sp, "modulate:a", 0.0, times[i])
		else:
			tw.tween_interval(times[i])
	tw.tween_callback(sp.queue_free)

func toggle_auto() -> void:
	auto_summon = not auto_summon
	_auto_timer = 0.0
	_auto_index = 0
	SoundManager.play_click()
	_refresh()

# What auto mode summons next: answer bats with archers and armor with spears, keep knights in
# front when monsters come close, otherwise follow a steady rotation. A soldier that is not ready
# is skipped for a knight, so gold keeps turning into an army.
const AUTO_ROTATION: Array[String] = ["knight", "archer", "knight", "mage", "knight", "spearman"]
var _auto_index: int = 0

func auto_pick() -> String:
	var mine: Dictionary = {"knight": 0, "archer": 0, "mage": 0, "spearman": 0}
	for u in units:
		if u["side"] == 1:
			mine[u["kind"]] += 1
	var foes: Array = units.filter(func(u): return u["side"] == -1)
	var bats: int = foes.filter(func(u): return u["flying"]).size()
	var armored: int = foes.filter(func(u): return u["armor"]).size()
	var close: bool = foes.any(func(u): return u["node"].position.x < DEFEND_X + 40.0)
	var want: String = AUTO_ROTATION[_auto_index % AUTO_ROTATION.size()]
	if mine["knight"] == 0 or (close and mine["knight"] < 3):
		want = "knight"
	elif bats > 0 and mine["archer"] + mine["mage"] < bats + 1:
		want = "archer"
	elif armored > 0 and mine["spearman"] < armored:
		want = "spearman"
	if not _can_summon(want) and _can_summon("knight") and want != "knight" and mine["knight"] < 3:
		return "knight"
	return want

func _can_summon(kind: String) -> bool:
	return gold >= ALLIES[kind]["cost"] and cooldown.get(kind, 0.0) <= 0.0

func _auto_step() -> void:
	# The cannon goes off when it can hit a crowd (or the boss); the wallet grows once the army stands
	var foes: Array = units.filter(func(u): return u["side"] == -1)
	if cannon >= 100.0 and (foes.size() >= 2 or foes.any(func(u): return u.get("boss", false))):
		fire_cannon()
	if wallet < 2 and gold >= WALLET_COST[wallet] + 40:
		upgrade_wallet()
	if _count(1) >= MAX_ALLIES:
		return
	var kind: String = auto_pick()
	if kind == AUTO_ROTATION[_auto_index % AUTO_ROTATION.size()] and _can_summon(kind):
		_auto_index += 1
	if summon(kind):
		var btn: Button = _buttons[kind]
		btn.scale = Vector2(0.92, 0.92)
		btn.pivot_offset = btn.size * 0.5
		btn.create_tween().tween_property(btn, "scale", Vector2.ONE, 0.15)

func toggle_march() -> void:
	charging = not charging
	SoundManager.play_click()
	_refresh()

# =========================================================
# Real-time battle
# =========================================================

func _tick(delta: float) -> void:
	_clock += delta
	for k in cooldown:
		cooldown[k] = maxf(0.0, cooldown[k] - delta)
	if gold < wallet_max():
		_gold_acc += WALLET_INCOME[wallet] * delta
		if _gold_acc >= 1.0:
			gold = mini(wallet_max(), gold + int(_gold_acc))
			_gold_acc -= int(_gold_acc)
			_dirty = true
	else:
		_gold_acc = 0.0
	if not switching:
		_waves(delta)
	if auto_summon:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_auto_timer = 0.3
			_auto_step()
	# Units may overlap (as in The Battle Cats) so a crowd fights together; each stands at its own
	# distance inside its range, which spreads them out
	for u in units.duplicate():
		var node: Sprite2D = u["node"]
		var x: float = node.position.x
		var side: int = u["side"]
		var base_off: float = -node.texture.get_height() * 0.5
		u["cd"] = maxf(0.0, u["cd"] - delta)
		if u["stun"] > 0.0:
			u["stun"] -= delta
			continue
		var target = _target_for(u)
		if target != null:
			node.offset.y = base_off
			if u["cd"] <= 0.0:
				u["cd"] = u["every"]
				_attack_fx(u, target)
				_apply_hit(target, _damage(u, target), u)
			continue
		# Walk forward, stopping at this unit's standing distance from the nearest opponent or the base
		var limit: float = ENEMY_BASE_X if side == 1 else ALLY_BASE_X
		if side == 1 and not charging:
			limit = DEFEND_X
		var front = _nearest_opponent(u)
		if front != null:
			var stop_at: float = front["node"].position.x - side * u["stand"]
			limit = minf(limit, stop_at) if side == 1 else maxf(limit, stop_at)
		var nx: float = x
		if side == 1 and not charging and x > limit + 1.0:
			nx = maxf(limit, x - u["speed"] * delta) # fall back to the hold line
		else:
			nx = x + side * u["speed"] * delta
			nx = minf(nx, limit) if side == 1 else maxf(nx, limit)
			nx = maxf(nx, x) if side == 1 else minf(nx, x)
		node.position.x = nx
		# A small hop while walking
		node.offset.y = base_off - (absf(sin(_clock * 9.0 + u["phase"])) * 3.0 if absf(nx - x) > 0.01 else 0.0)
	# Remove the fallen
	for u in units.duplicate():
		if u["hp"] <= 0.0:
			_kill(u)
	if fortress_hp <= fortress_max * 0.5 and not boss_out and not switching:
		_boss_entry()
	if fortress_hp <= 0.0 and not switching:
		_stage_cleared()
	elif castle_hp <= 0 and not finished:
		finished = true
		_banner("성이 무너졌어요", "STAGE %d" % stage)
		get_tree().create_timer(1.0).timeout.connect(func(): defeated.emit(stage))
	if _dirty:
		_dirty = false
		_refresh()

# Single monsters on a timer, a horn and a big wave every BIG_WAVE_EVERY seconds
func _waves(delta: float) -> void:
	var k: float = pow(ENEMY_GROWTH, stage - 1)
	trickle_timer -= delta
	if trickle_timer <= 0.0:
		trickle_timer = _trickle_every()
		_spawn_enemy(_pick_enemy(), k)
	wave_timer -= delta
	if wave_timer <= WARN_TIME and not warned:
		warned = true
		_sfx("b_horn", -4.0)
		_banner("적 대군이 몰려와요!", "", Color(1.0, 0.55, 0.45))
	if wave_timer <= 0.0:
		wave_timer = BIG_WAVE_EVERY
		warned = false
		for i in range(mini(2 + stage / 2, 8)):
			_pending.append([i * 0.7, _pick_enemy(), k])
	for p in _pending.duplicate():
		p[0] -= delta
		if p[0] <= 0.0:
			_pending.erase(p)
			_spawn_enemy(p[1], p[2], false)

# Swarm monsters come in a group, except inside a big wave (which is crowded already)
func _spawn_enemy(kind: String, k: float, group: bool = true) -> void:
	var n: int = ENEMIES[kind].get("swarm", 1) if group else 1
	for i in range(n):
		if _count(-1) >= MAX_ENEMIES:
			return
		var u := _spawn(kind, -1, k)
		u["node"].position.x += i * 18.0

func _boss_entry() -> void:
	boss_out = true
	_sfx("b_roar", -2.0)
	_banner("보스 등장!", "충격파에 밀려나요", Color(1.0, 0.45, 0.4))
	castle_hit.emit(0)
	# Boss: an orc with x2 HP and x1.2 attack, bigger and slower
	var boss := _spawn("orc", -1, pow(ENEMY_GROWTH, stage - 1) * 1.2)
	boss["max_hp"] *= 1.67
	boss["hp"] = boss["max_hp"]
	boss["speed"] = 16.0
	boss["node"].scale = Vector2.ONE * PX * 1.5
	boss["kb"] = 4
	boss["kb_mark"] = boss["max_hp"] * 0.75
	boss["boss"] = true
	# The shockwave pushes every soldier back
	for u in units:
		if u["side"] == 1:
			_knock(u, KB_DIST * 2.5)
	_hitstop = 0.1
	_pending.append([0.8, _pick_enemy(), pow(ENEMY_GROWTH, stage - 1)])

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

# Melee soldiers can neither hit nor be blocked by flying enemies
func _nearest_opponent(u: Dictionary):
	var best = null
	var x: float = u["node"].position.x
	var melee: bool = u["side"] == 1 and u["shot"] == ""
	for o in units:
		if o["side"] == u["side"] or o["hp"] <= 0.0:
			continue
		if melee and o.get("flying", false):
			continue
		var d: float = (o["node"].position.x - x) * u["side"]
		if d < -10.0:
			continue
		if best == null or d < (best["node"].position.x - x) * u["side"]:
			best = o
	return best

func _damage(attacker: Dictionary, target) -> float:
	var dmg: float = attacker["atk"]
	if target is Dictionary and target.get("armor", false):
		dmg *= 2.0 if attacker["kind"] == "spearman" else 0.5
	return dmg

func _apply_hit(target, dmg: float, attacker: Dictionary) -> void:
	_dirty = true
	if target is String:
		if target == "fortress":
			fortress_hp = maxf(0.0, fortress_hp - dmg)
			_number(Vector2(FORT_X, GROUND - 170), dmg, Color(1.0, 0.9, 0.5))
			_flash(_fort_sprite)
			_sfx("b_hit", -12.0)
		else:
			castle_hp = maxi(0, castle_hp - roundi(dmg))
			_number(Vector2(CASTLE_X, GROUND - 170), dmg, Color(1.0, 0.45, 0.4))
			_flash(_castle_sprite)
			_sfx("b_castle", -8.0)
			if _clock - _castle_hit_last > 0.8:
				_castle_hit_last = _clock
				castle_hit.emit(roundi(dmg))
		return
	_hurt(target, dmg, attacker["side"] == 1)
	if attacker["shot"] == "":
		_sfx("b_hit", -12.0)
	# Mage fire also hits the target's neighbours
	if attacker.get("splash", 0.0) > 0.0:
		for o in units.duplicate():
			if o != target and o["side"] == target["side"] and absf(o["node"].position.x - target["node"].position.x) <= attacker["splash"]:
				_hurt(o, _damage(attacker, o) * 0.6, true)

func _hurt(u: Dictionary, dmg: float, by_ally: bool) -> void:
	u["hp"] -= dmg
	_flash(u["node"])
	_number(_head(u), dmg, Color(1.0, 0.95, 0.6) if by_ally else Color(1.0, 0.5, 0.45))
	# Knockback each time the HP drops past the next mark
	if u["hp"] > 0.0 and u["hp"] <= u["kb_mark"]:
		u["kb_mark"] -= u["max_hp"] / u["kb"]
		_knock(u, KB_DIST)
		if dmg >= 15.0:
			_hitstop = maxf(_hitstop, 0.05)

func _knock(u: Dictionary, dist: float) -> void:
	var node: Sprite2D = u["node"]
	var side: int = u["side"]
	u["stun"] = KB_TIME
	var to_x: float = clampf(node.position.x - side * dist, ALLY_START - 20.0, ENEMY_START + 20.0)
	var base_off: float = -node.texture.get_height() * 0.5
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position:x", to_x, KB_TIME * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "offset:y", base_off - 10.0, KB_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(node, "offset:y", base_off, KB_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _trickle_every() -> float:
	return maxf(4.0, 10.0 - 0.6 * (stage - 1))

func _pick_enemy() -> String:
	var pool: Array = ["slime", "slime"]
	if stage >= 2:
		pool += ["goblin", "goblin", "skeleton"]
	if stage >= 3:
		pool += ["bat", "bat"]
	if stage >= 4:
		pool += ["armored", "armored"]
	if stage >= 5:
		pool.append("orc")
	return pool[rng.randi() % pool.size()]

func _start_stage() -> void:
	fortress_max = FORTRESS_HP * pow(FORTRESS_GROWTH, stage - 1)
	fortress_hp = fortress_max
	boss_out = false
	trickle_timer = 4.0
	wave_timer = BIG_WAVE_FIRST
	warned = false
	_stage_label.text = "STAGE %d" % stage
	_spawn_enemy(_pick_enemy(), pow(ENEMY_GROWTH, stage - 1))
	_refresh()

func _stage_cleared() -> void:
	switching = true
	castle_hp = mini(CASTLE_HP, castle_hp + 80)
	_pending.clear()
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
	var y: float = GROUND + [0.0, 8.0, 4.0, 12.0][units.size() % 4]
	if st.get("flying", false):
		y = GROUND - FLY_H
	node.position = Vector2(ALLY_START if side == 1 else ENEMY_START, y)
	_units_layer.add_child(node)
	var hp: float = st["hp"] * k
	var u := {"node": node, "side": side, "kind": kind, "hp": hp, "max_hp": hp, "atk": st["atk"] * k,
		"range": st["range"], "shot": st.get("shot", ""), "splash": st.get("splash", 0.0),
		"speed": st["speed"], "every": st["every"], "cd": st["every"] * 0.5, "phase": rng.randf() * TAU,
		"kb": st["kb"], "kb_mark": hp * (st["kb"] - 1) / st["kb"], "stun": 0.0,
		"stand": maxf(18.0, st["range"] * rng.randf_range(0.5, 0.9)),
		"flying": st.get("flying", false), "armor": st.get("armor", false)}
	u["bar"] = _unit_bar(node)
	for mark in ["armor", "flying"]:
		if u[mark]:
			var icon := Sprite2D.new()
			icon.texture = _icons[mark]
			icon.position = Vector2(0, -node.texture.get_height() - 7)
			node.add_child(icon)
	units.append(u)
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, 0.2)
	return u

func _count(side: int) -> int:
	return units.filter(func(u): return u["side"] == side).size()

# Fallen units fly back with a spin and burst into a few pixels
func _kill(u: Dictionary) -> void:
	units.erase(u)
	var node: Sprite2D = u["node"]
	var side: int = u["side"]
	_sfx("b_death", -10.0)
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position", node.position + Vector2(-side * 46.0, -34.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", -side * 1.6, 0.4)
	tw.tween_property(node, "modulate:a", 0.0, 0.4).set_delay(0.1)
	tw.chain().tween_callback(node.queue_free)
	var c: Vector2 = _head(u) + Vector2(0, 16)
	for i in range(6):
		var bit := ColorRect.new()
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.size = Vector2(4, 4)
		bit.color = Color(1.0, 0.95, 0.8) if i % 2 == 0 else (Color(0.6, 0.85, 1.0) if side == 1 else Color(1.0, 0.55, 0.4))
		bit.position = c
		bit.z_index = 7
		_view.add_child(bit)
		var a: float = TAU * i / 6.0 + rng.randf() * 0.5
		var bt := bit.create_tween().set_parallel(true)
		bt.tween_property(bit, "position", c + Vector2(cos(a), sin(a)) * rng.randf_range(16, 30), 0.35).set_ease(Tween.EASE_OUT)
		bt.tween_property(bit, "modulate:a", 0.0, 0.35)
		bt.chain().tween_callback(bit.queue_free)

func _head(u: Dictionary) -> Vector2:
	return u["node"].position + Vector2(0, -_height(u["node"]) - 6)

func _height(node: Sprite2D) -> float:
	return node.texture.get_height() * node.scale.y

func _flash(node: CanvasItem) -> void:
	node.modulate = Color(2.0, 1.6, 1.6, node.modulate.a)
	node.create_tween().tween_property(node, "modulate", Color(1, 1, 1, node.modulate.a), 0.2)

# Melee units lunge; archers and mages send a small pixel shot
func _attack_fx(u: Dictionary, target) -> void:
	var node: Sprite2D = u["node"]
	var to: Vector2
	if target is String:
		to = Vector2(FORT_X if target == "fortress" else CASTLE_X, GROUND - 80)
	else:
		to = target["node"].position + Vector2(0, -_height(target["node"]) * 0.5)
	if u["shot"] == "":
		# Lunge with the sprite offset so it never fights the walking position
		var tw := node.create_tween()
		tw.tween_property(node, "offset:x", u["side"] * 5.0, 0.08)
		tw.tween_property(node, "offset:x", 0.0, 0.12)
		return
	_sfx("b_arrow" if u["shot"] == "arrow" else "b_magic", -12.0)
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
	shot.rotation = (to - from).angle() if u["shot"] == "arrow" else 0.0
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

# Quiet battle sounds, at most one of each kind every 0.08 s, never cutting puzzle sounds
func _sfx(key: String, volume_db: float) -> void:
	if _clock - _sfx_last.get(key, -9.0) < 0.08:
		return
	_sfx_last[key] = _clock
	SoundManager.play_battle(key, volume_db)

func _pixel_icon(rows: Array, fill: Color) -> ImageTexture:
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		for x in range(rows[y].length()):
			var ch: String = rows[y][x]
			img.set_pixel(x, y, Color(0.1, 0.08, 0.16) if ch == "X" else (fill if ch == "W" else Color.TRANSPARENT))
	return ImageTexture.create_from_image(img)

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
		if side == 1:
			_castle_sprite = b
		else:
			_fort_sprite = b
	# The cannon stands on the castle's right tower (its top is 52 art pixels below the castle top)
	_cannon_sprite = Sprite2D.new()
	_cannon_sprite.texture = tex["cannon"]
	_cannon_sprite.scale = Vector2.ONE * PX
	_cannon_sprite.centered = false
	_cannon_sprite.position = Vector2(_castle_sprite.position.x + 112.0 - tex["cannon"].get_width() * PX * 0.35, _castle_sprite.position.y + 106.0 - tex["cannon"].get_height() * PX)
	_view.add_child(_cannon_sprite)
	_units_layer = Node2D.new()
	_units_layer.y_sort_enabled = true
	_view.add_child(_units_layer)
	_bars_layer = Node2D.new()
	_view.add_child(_bars_layer)
	_stage_label = _outlined("", 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_stage_label.position = Vector2(352, 8)
	_stage_label.size = Vector2(140, 44)
	_stage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view.add_child(_stage_label)
	# HP bars sit on the ground under each building (the top-right corner is Toss's button area)
	var cb := _bar(_view, Vector2(CASTLE_X - BASE_BAR_W * 0.5, LANE_H - 26), Vector2(BASE_BAR_W, 20))
	_castle_fill = cb.get_child(0)
	_castle_label = _outlined("", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_castle_label.size = cb.size
	_castle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cb.add_child(_castle_label)
	var fb := _bar(_view, Vector2(FORT_X - BASE_BAR_W * 0.5, LANE_H - 26), Vector2(BASE_BAR_W, 20))
	_fort_fill = fb.get_child(0)
	_fort_label = _outlined("", 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_fort_label.size = fb.size
	_fort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fb.add_child(_fort_label)
	# Top-left of the lane: home / settings / sound on a dark pill, then the charge/hold toggle
	var pill := Panel.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_theme_stylebox_override("panel", UIKit.box(Color(0.04, 0.05, 0.1, 0.55), Color.TRANSPARENT, 22))
	pill.position = Vector2(8, 8)
	pill.size = Vector2(140, 44)
	_view.add_child(pill)
	var i_menu := 0
	for key in ["home", "settings", "sound"]:
		var mb := TextureButton.new()
		mb.ignore_texture_size = true
		mb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		mb.position = Vector2(8 + i_menu * 44, 4)
		mb.size = Vector2(36, 36)
		mb.focus_mode = Control.FOCUS_NONE
		mb.pressed.connect(func(): (home_pressed if key == "home" else (settings_pressed if key == "settings" else sound_pressed)).emit())
		pill.add_child(mb)
		_menu[key] = mb
		i_menu += 1
	pill.mouse_filter = Control.MOUSE_FILTER_PASS
	_march_btn = Button.new()
	_march_btn.position = Vector2(156, 8)
	_march_btn.size = Vector2(90, 44)
	_march_btn.focus_mode = Control.FOCUS_NONE
	_march_btn.pressed.connect(toggle_march)
	_view.add_child(_march_btn)
	_auto_btn = Button.new()
	_auto_btn.position = Vector2(254, 8)
	_auto_btn.size = Vector2(92, 44)
	_auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.pressed.connect(toggle_auto)
	_view.add_child(_auto_btn)
	# Summon bar right under the lane: gold and income on the left, soldiers, then the cannon
	var bar := Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(0, LANE_H)
	bar.size = Vector2(720, BAR_H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIKit.SURFACE
	sb.border_color = UIKit.BORDER
	sb.border_width_top = 3
	sb.border_width_bottom = 2
	bar.add_theme_stylebox_override("panel", sb)
	add_child(bar)
	var coin := Panel.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.position = Vector2(12, 14)
	coin.size = Vector2(22, 22)
	coin.add_theme_stylebox_override("panel", UIKit.box(UIKit.GOLD, Color(0.75, 0.5, 0.1), 11, 3))
	bar.add_child(coin)
	_gold_label = _outlined("0", 26, UIKit.GOLD)
	_gold_label.position = Vector2(40, 6)
	_gold_label.size = Vector2(70, 36)
	bar.add_child(_gold_label)
	_wallet_label = _outlined("", 15, UIKit.MUTED)
	_wallet_label.position = Vector2(104, 14)
	_wallet_label.size = Vector2(70, 24)
	bar.add_child(_wallet_label)
	_income_btn = Button.new()
	_income_btn.position = Vector2(8, 46)
	_income_btn.size = Vector2(164, 46)
	_income_btn.focus_mode = Control.FOCUS_NONE
	UIKit.style_button(_income_btn, "secondary", 16, 12)
	_income_btn.pressed.connect(upgrade_wallet)
	bar.add_child(_income_btn)
	for i in range(ALLY_ORDER.size()):
		var kind: String = ALLY_ORDER[i]
		var st: Dictionary = ALLIES[kind]
		var btn := Button.new()
		btn.position = Vector2(180 + i * 106, 10)
		btn.size = Vector2(100, 80)
		btn.focus_mode = Control.FOCUS_NONE
		UIKit.style_button(btn, "primary", 16, 14)
		btn.pressed.connect(func(): summon(kind))
		bar.add_child(btn)
		var icon := TextureRect.new()
		icon.texture = tex[kind]
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(2, 10)
		icon.size = Vector2(44, 58)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		var n := _outlined(st["name"], 15, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		n.position = Vector2(42, 10)
		n.size = Vector2(58, 22)
		btn.add_child(n)
		var c := _outlined(str(st["cost"]), 21, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		c.position = Vector2(42, 36)
		c.size = Vector2(58, 28)
		btn.add_child(c)
		# Cooldown veil: covers the button and shrinks as the cooldown runs out
		var veil := ColorRect.new()
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.color = Color(0.02, 0.03, 0.08, 0.6)
		veil.position = Vector2.ZERO
		veil.size = Vector2(100, 0)
		btn.add_child(veil)
		_buttons[kind] = btn
		_cool_veils[kind] = veil
	_cannon_btn = Button.new()
	_cannon_btn.position = Vector2(606, 10)
	_cannon_btn.size = Vector2(106, 80)
	_cannon_btn.focus_mode = Control.FOCUS_NONE
	_cannon_btn.clip_contents = true
	UIKit.style_raised(_cannon_btn, Color(0.32, 0.12, 0.1), Color(1.0, 0.55, 0.3), Color(0.18, 0.06, 0.05), 14)
	_cannon_btn.pressed.connect(fire_cannon)
	bar.add_child(_cannon_btn)
	_cannon_fill = ColorRect.new()
	_cannon_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cannon_fill.color = Color(1.0, 0.55, 0.15, 0.55)
	_cannon_btn.add_child(_cannon_fill)
	var gun := TextureRect.new()
	gun.texture = tex["cannon"]
	gun.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gun.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gun.position = Vector2(13, 6)
	gun.size = Vector2(80, 40)
	_cannon_btn.add_child(gun)
	_cannon_label = _outlined("", 18, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_cannon_label.position = Vector2(0, 46)
	_cannon_label.size = Vector2(106, 26)
	_cannon_btn.add_child(_cannon_label)

func set_menu_icons(home: Texture2D, settings: Texture2D, sound: Texture2D) -> void:
	_menu["home"].texture_normal = home
	_menu["settings"].texture_normal = settings
	_menu["sound"].texture_normal = sound

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
	_castle_fill.size.x = (BASE_BAR_W - 4.0) * cr
	_castle_fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.35, 0.86, 0.43) if cr > 0.3 else Color(1.0, 0.4, 0.35), Color.TRANSPARENT, 7))
	_castle_label.text = str(castle_hp)
	var fr: float = clampf(fortress_hp / fortress_max, 0.0, 1.0)
	_fort_fill.size.x = (BASE_BAR_W - 4.0) * fr
	_fort_fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.92, 0.32, 0.28), Color.TRANSPARENT, 7))
	_fort_label.text = str(ceili(fortress_hp))
	_gold_label.text = str(gold)
	_wallet_label.text = "/%d" % wallet_max()
	if wallet < WALLET_COST.size():
		_income_btn.text = "수입 UP  %d" % WALLET_COST[wallet]
		_income_btn.modulate = Color.WHITE if gold >= WALLET_COST[wallet] else Color(0.6, 0.6, 0.65)
	else:
		_income_btn.text = "수입 MAX"
		_income_btn.modulate = Color(0.6, 0.6, 0.65)
	UIKit.style_button(_march_btn, "primary" if charging else "secondary", 18, 22)
	_march_btn.text = "돌격" if charging else "수비"
	UIKit.style_button(_auto_btn, "secondary", 18, 22)
	if auto_summon: # green while on, so it reads as a mode rather than a button
		UIKit.style_raised(_auto_btn, Color(0.16, 0.6, 0.34), Color(0.5, 0.92, 0.62), Color(0.04, 0.24, 0.12), 22)
	_auto_btn.text = "자동 ON" if auto_summon else "자동"
	for kind in _buttons:
		var ok: bool = gold >= ALLIES[kind]["cost"] and _count(1) < MAX_ALLIES and not finished
		_buttons[kind].modulate = Color.WHITE if ok else Color(0.5, 0.5, 0.56)
	_cannon_label.text = "발사!" if cannon >= 100.0 else "%d%%" % int(cannon)
	for u in units:
		var bg: Panel = u["bar"]
		bg.visible = u["hp"] < u["max_hp"]
		var fill: Panel = bg.get_child(0)
		fill.size.x = 34.0 * clampf(u["hp"] / u["max_hp"], 0.0, 1.0)
		fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.35, 0.86, 0.43) if u["side"] == 1 else Color(1.0, 0.4, 0.35), Color.TRANSPARENT, 1))

func _process(delta: float) -> void:
	if not finished and not paused and visible:
		if _hitstop > 0.0:
			_hitstop -= delta # a short freeze sells heavy hits
		else:
			_tick(delta)
	for u in units:
		var node: Sprite2D = u["node"]
		u["bar"].position = node.position + Vector2(-18, -_height(node) - 8)
	for kind in _cool_veils:
		var left: float = cooldown.get(kind, 0.0)
		_cool_veils[kind].size.y = 80.0 * left / ALLIES[kind]["cool"]
	if _cannon_fill != null:
		_cannon_fill.size = Vector2(106, 80.0 * cannon / 100.0)
		_cannon_fill.position = Vector2(0, 80.0 - _cannon_fill.size.y)
		# A full cannon pulses so it is noticed from the puzzle
		var pulse: float = 1.0 + (0.25 * (0.5 + 0.5 * sin(_clock * 8.0)) if cannon >= 100.0 else 0.0)
		_cannon_btn.self_modulate = Color(pulse, pulse, pulse)
	# A full wallet blinks: gold is going to waste
	if gold >= wallet_max():
		_gold_label.modulate.a = 0.55 + 0.45 * absf(sin(_clock * 5.0))
	else:
		_gold_label.modulate.a = 1.0

func _number(pos: Vector2, dmg: float, col: Color) -> void:
	var big: bool = dmg >= 20.0
	var l := _outlined(str(roundi(dmg)), 22 if big else 17, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(60, 26)
	l.position = pos - l.size * 0.5
	l.z_index = 8
	_view.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 22, 0.5)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tw.tween_callback(l.queue_free)

func _banner(title: String, sub: String, col: Color = UIKit.TEXT) -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(0, 90)
	box.size = Vector2(720, 110)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.z_index = 10
	_view.add_child(box)
	box.add_child(_outlined(title, 40, col, HORIZONTAL_ALIGNMENT_CENTER))
	if sub != "":
		box.add_child(_outlined(sub, 22, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.scale = Vector2(1.0, 0.2)
	box.pivot_offset = box.size * 0.5
	var tw := box.create_tween()
	tw.tween_property(box, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(box.queue_free)
