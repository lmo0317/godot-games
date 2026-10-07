class_name LaneBattle
extends Control
# "블록 기사단": a real-time side-view lane battle above the normal puzzle (board shrunk by MainGame).
# Ideas taken from The Battle Cats, Paladog, Stick War and Plants vs Zombies (docs/BATTLE_RESEARCH.md):
# - Units walk at their own speed and hit the first enemy in range on their own attack timer.
#   Big hits knock units back (each kind has a knockback count), deaths fly off with a poof.
# - The 4 summon buttons are the player's deck (LaneUnits, built outside battles with the gacha and
#   the deck screen). Each soldier has a role: melee, tank, armor breaker, ranged, anti-air, mage,
#   healer, siege; star tiers (merged from duplicates) raise HP and attack.
# - Gold trickles in up to the wallet's limit; clears pay more. "수입 UP" raises income and limit.
# - Clears and combos charge the castle cannon; one tap blasts every monster.
# - Stages (LaneStages) set the monsters, waves and a boss that roars in at half the fortress.
# - Monster traits: bats fly (only ranged soldiers reach them), armor (spears), goblin archers shoot,
#   dark priests heal monsters, golems are huge, slimes come in swarms.
# - Charge/hold toggle and an auto mode that plays the battle from the deck.
# Sizes follow lane games like The Battle Cats: units at their pixel size (x1, about 1/7 of the
# strip), bosses x2, the castle and fortress x1 and half off-screen, so crowds read well.
# The battle pauses while the settings window is open (MainGame sets `paused`).
# Art: Codex pixel art cut by tools/import_lane_art.py.

signal defeated(stage: int)
signal cleared(stage: int, stars: int)
signal castle_hit(damage: int)
# The game's header is hidden in this mode; its home / settings / sound buttons live in the lane
signal home_pressed
signal settings_pressed
signal sound_pressed

const LANE_H: float = 330.0
const BAR_H: float = 100.0
const UNIT_PX: float = 1.0            # soldiers and monsters at their pixel size
const BASE_PX: float = 1.0            # castle and fortress
const FX_PX: float = 1.0              # effects
const GROUND: float = 272.0           # feet line in the lane (on the dirt road)
const FLY_H: float = 40.0             # bats hover this high
const CASTLE_LEFT: float = -20.0      # the castle sticks out of the left edge
const FORT_RIGHT: float = 740.0       # and the fortress out of the right one
const ALLY_START: float = 70.0        # just in front of the castle
const ENEMY_START: float = 650.0      # just in front of the fortress
const ALLY_BASE_X: float = 68.0       # where enemies stand to hit the castle
const ENEMY_BASE_X: float = 652.0     # where soldiers stand to hit the fortress
const DEFEND_X: float = 200.0         # soldiers hold here in defend mode
const CASTLE_X: float = 26.0          # visible building centres, for hit effects
const FORT_X: float = 694.0
const BASE_BAR_W: float = 104.0
const SPEED_K: float = 1.5            # the field is wider now; everyone walks a bit faster
const KB_DIST: float = 30.0
const KB_TIME: float = 0.45
const MAX_ALLIES: int = 14
const MAX_ENEMIES: int = 16
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
const WAVE_REPEAT: float = 40.0       # after the scripted waves, the last one repeats this often
const WARN_TIME: float = 3.0
const HEAL_EVERY: float = 2.0
const ALLIES: Dictionary = LaneUnits.UNITS
const ALLY_ORDER: Array[String] = LaneUnits.ORDER
const ENEMIES: Dictionary = {
	"slime": {"hp": 18.0, "atk": 5.0, "range": 40.0, "speed": 22.0, "every": 1.2, "kb": 1, "swarm": 2},
	"goblin": {"hp": 52.0, "atk": 9.0, "range": 44.0, "speed": 30.0, "every": 1.1, "kb": 2},
	"wolf": {"hp": 40.0, "atk": 8.0, "range": 36.0, "speed": 55.0, "every": 0.9, "kb": 2},
	"gob_archer": {"hp": 40.0, "atk": 8.0, "range": 130.0, "speed": 26.0, "every": 1.4, "kb": 1, "shot": "arrow"},
	"skeleton": {"hp": 64.0, "atk": 11.0, "range": 44.0, "speed": 26.0, "every": 1.2, "kb": 2},
	"bat": {"hp": 30.0, "atk": 7.0, "range": 40.0, "speed": 40.0, "every": 1.0, "kb": 1, "flying": true},
	"armored": {"hp": 70.0, "atk": 12.0, "range": 44.0, "speed": 20.0, "every": 1.3, "kb": 3, "armor": true},
	"priest": {"hp": 45.0, "atk": 5.0, "range": 100.0, "speed": 22.0, "every": 1.6, "kb": 1, "shot": "dark", "heal": 10.0, "heal_r": 100.0},
	"golem": {"hp": 260.0, "atk": 20.0, "range": 46.0, "speed": 14.0, "every": 1.8, "kb": 1},
	"orc": {"hp": 130.0, "atk": 18.0, "range": 50.0, "speed": 20.0, "every": 1.5, "kb": 2},
	"demon": {"hp": 220.0, "atk": 26.0, "range": 60.0, "speed": 18.0, "every": 1.3, "kb": 3},
}
# Projectile sprite per shot kind
const SHOT_TEX: Dictionary = {"arrow": "arrow", "bolt": "bolt", "orb": "fireball", "light": "holy", "ball": "cannonball", "dark": "fireball"}

var stage: int = 1
var stage_data: Dictionary = {}       # one entry of LaneStages.STAGES
var power: float = 1.0                # monster HP/attack multiplier of this stage
var elapsed: float = 0.0
var wave_index: int = 0
var next_wave_at: float = 0.0
var paused: bool = false
var gold: int = START_GOLD
var wallet: int = 0                   # wallet level index
var cannon: float = 0.0               # 0..100
var charging: bool = true             # false = hold in front of the castle
var auto_summon: bool = true          # every stage starts with auto on (the player can turn it off)
var deck: Array = []                  # the 4 soldier kinds of this battle ("" = empty slot)
var tiers: Dictionary = {}            # kind -> star tier (LaneUnits.TIER_NAME)
var _auto_timer: float = 0.0
var castle_hp: int = CASTLE_HP
var fortress_hp: float = 1.0
var fortress_max: float = 1.0
var boss_out: bool = false
var finished: bool = true
var switching: bool = false
var trickle_timer: float = 0.0
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
var _shake: Node2D                    # everything that shakes with heavy hits
var _units_layer: Node2D
var _fx_layer: Node2D
var _bars_layer: Node2D
var _castle_sprite: Sprite2D
var _cannon_sprite: Sprite2D
var _fort_sprite: Sprite2D
var _stage_label: Label
var _stage_name: Label
var _bg: TextureRect
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
var _slots: Array = []                # {btn, icon, name, cost, lv, veil}
var _icons: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(720, LANE_H + BAR_H)
	var names: Array = ["castle", "fortress", "lane"]
	names.append_array(ALLY_ORDER)
	names.append_array(ENEMIES.keys())
	names.append_array(["cannon", "cannonball", "flash", "boom_s", "boom_l", "smoke"])
	names.append_array(["spark", "slash", "arrow", "bolt", "fireball", "holy", "heal", "dust", "ring"])
	for k in names:
		var path := "res://assets/art/lane/%s.png" % k
		if ResourceLoader.exists(path):
			tex[k] = load(path)
	_icons["armor"] = _pixel_icon([".XXXXX.", "XWWWWWX", "XWWWWWX", "XWWWWWX", ".XWWWX.", "..XWX..", "...X..."], Color(0.8, 0.85, 0.95))
	_icons["flying"] = _pixel_icon(["X.....X", "XX...XX", "XWX.XWX", "XWWXWWX", ".XWWWX.", "..XXX.."], Color(0.75, 0.9, 1.0))
	_icons["heal"] = _pixel_icon(["..XXX..", "..XWX..", "XXXWXXX", "XWWWWWX", "XXXWXXX", "..XWX..", "..XXX.."], Color(0.55, 0.95, 0.55))
	_build()

# =========================================================
# Flow (called by MainGame)
# =========================================================

# Starts one stage (docs/LANE_STAGES.md) with the player's deck; the run ends with cleared() or
# defeated()
func begin(stage_id: int = 1) -> void:
	rng.randomize()
	stage = stage_id
	stage_data = LaneStages.get_stage(stage_id)
	if stage_data.is_empty():
		stage_data = LaneStages.STAGES[0]
	power = stage_data["power"]
	var army: Dictionary = LaneUnits.load_army()
	deck = army["deck"].duplicate()
	tiers = {}
	for k in army["owned"]:
		tiers[k] = int(army["owned"][k]["tier"])
	_setup_slots()
	_rotation = _auto_rotation()
	_auto_index = 0
	auto_summon = true
	_auto_timer = 0.0
	paused = false
	wallet = LaneStages.start_wallet(stage_id)
	gold = mini(wallet_max(), LaneStages.start_gold(stage_id))
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
	if finished or not deck.has(kind) or kind == "":
		return false
	var st: Dictionary = ALLIES[kind]
	if gold < st["cost"] or cooldown.get(kind, 0.0) > 0.0 or _count(1) >= MAX_ALLIES:
		return false
	gold -= st["cost"]
	cooldown[kind] = st["cool"]
	var u := _spawn(kind, 1, 1.0)
	# Drops in with a puff of dust
	var node: Sprite2D = u["node"]
	node.position.y -= 16.0
	node.create_tween().tween_property(node, "position:y", node.position.y + 16.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	get_tree().create_timer(0.18).timeout.connect(func(): _fx_once("dust", node.position + Vector2(0, -4), 0.35))
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
	rt.tween_property(gun, "position:x", rest.x - 6.0, 0.05)
	rt.tween_property(gun, "position:x", rest.x, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var tip: Vector2 = rest + Vector2(gun.texture.get_width() * BASE_PX, gun.texture.get_height() * BASE_PX * 0.35)
	_fx(["flash"], tip + Vector2(8, 0), [0.12])
	var foes: Array = units.filter(func(u): return u["side"] == -1)
	foes.sort_custom(func(a, b): return a["node"].position.x < b["node"].position.x)
	var land: Vector2 = Vector2(360, GROUND - 20) if foes.is_empty() else _mid(foes[0])
	var ball := Sprite2D.new()
	ball.texture = tex["cannonball"]
	ball.scale = Vector2.ONE * BASE_PX
	ball.position = tip
	ball.z_index = 6
	_fx_layer.add_child(ball)
	var flight: float = 0.3
	var bt := ball.create_tween()
	bt.tween_method(func(t: float):
		ball.position = tip.lerp(land, t) + Vector2(0, -80.0 * sin(PI * t))
		ball.rotation = lerpf(-0.5, 0.6, t), 0.0, 1.0, flight)
	bt.tween_callback(ball.queue_free)
	var dmg: float = CANNON_DAMAGE * power
	if foes.is_empty():
		get_tree().create_timer(flight).timeout.connect(func(): _boom(land))
	for i in range(foes.size()):
		var u: Dictionary = foes[i]
		get_tree().create_timer(flight + i * 0.07).timeout.connect(func():
			if not units.has(u):
				return
			_boom(_mid(u))
			_hurt(u, dmg, true)
			if u["hp"] > 0.0:
				_knock(u, KB_DIST * 1.5)
			_dirty = true)
	return true

func toggle_march() -> void:
	charging = not charging
	SoundManager.play_click()
	_refresh()

func toggle_auto() -> void:
	auto_summon = not auto_summon
	_auto_timer = 0.0
	_auto_index = 0
	SoundManager.play_click()
	_refresh()

# =========================================================
# Auto mode (plays from the deck)
# =========================================================

var _auto_index: int = 0
var _rotation: Array = []

# A rotation from the deck: the front-liner between every other soldier, so the line holds while
# the rest of the deck is mixed in
func _auto_rotation() -> Array:
	var kinds: Array = deck.filter(func(k): return k != "")
	var front: String = _front_kind()
	var r: Array = []
	for k in kinds:
		if k != front:
			r.append(front)
			r.append(k)
	if r.is_empty():
		r = [front]
	return r

func _front_kind() -> String:
	for k in ["knight", "shield", "spearman"]:
		if deck.has(k):
			return k
	var kinds: Array = deck.filter(func(k): return k != "")
	return kinds[0] if not kinds.is_empty() else ""

func _first_in_deck(kinds: Array) -> String:
	for k in kinds:
		if deck.has(k):
			return k
	return ""

# What auto mode summons next: the front-liner when monsters are close, the deck's answer to bats
# (crossbow, archer, mage) and to armor (spear, cannon), otherwise the rotation. A counter that is
# not ready is worth saving gold for.
func auto_pick() -> String:
	var mine: Dictionary = {}
	for u in units:
		if u["side"] == 1:
			mine[u["kind"]] = mine.get(u["kind"], 0) + 1
	var foes: Array = units.filter(func(u): return u["side"] == -1)
	var bats: int = foes.filter(func(u): return u["flying"]).size()
	var armored: int = foes.filter(func(u): return u["armor"]).size()
	# "Close" counts ground monsters only: a knight can't stop a bat, so bats near the castle call for
	# a ranged soldier instead
	var close: bool = foes.any(func(u): return not u["flying"] and u["node"].position.x < DEFEND_X + 60.0)
	var air_close: bool = foes.any(func(u): return u["flying"] and u["node"].position.x < DEFEND_X + 60.0)
	var front: String = _front_kind()
	var melee_n: int = 0
	var ranged_n: int = 0
	for k in mine:
		if LaneUnits.melee(k):
			melee_n += mine[k]
		else:
			ranged_n += mine[k]
	var want: String = _rotation[_auto_index % _rotation.size()] if not _rotation.is_empty() else front
	var counter: bool = false
	var air: String = _first_in_deck(["crossbow", "archer", "mage"])
	var breaker: String = _first_in_deck(["spearman", "cannoneer"])
	if armored > 0 and close and breaker != "" and _can_summon(breaker):
		return breaker
	if bats > 0 and air != "" and (air_close or ranged_n < bats + 1):
		want = air
		counter = true
	elif melee_n == 0 or (close and melee_n < 3):
		want = front
	elif armored > 0 and breaker != "" and mine.get(breaker, 0) < armored + 1:
		want = breaker
		counter = true
	if want == "cleric" and mine.get("cleric", 0) >= 2:
		_auto_index += 1
		want = front
	if _can_summon(want):
		return want
	if counter:
		return front if close and _can_summon(front) and melee_n < 2 else ""
	if _can_summon(front) and melee_n < 3:
		return front
	return want

func _can_summon(kind: String) -> bool:
	return kind != "" and deck.has(kind) and gold >= ALLIES[kind]["cost"] and cooldown.get(kind, 0.0) <= 0.0

func _auto_step() -> void:
	# The cannon goes off when it can hit a crowd (or the boss); the wallet grows when gold is spare
	var foes: Array = units.filter(func(u): return u["side"] == -1)
	if cannon >= 100.0 and (foes.size() >= 2 or foes.any(func(u): return u.get("boss", false))):
		fire_cannon()
	if wallet < 2 and gold >= WALLET_COST[wallet] + 40:
		upgrade_wallet()
	if _count(1) >= MAX_ALLIES:
		return
	var kind: String = auto_pick()
	if kind == "":
		return
	if not _rotation.is_empty() and kind == _rotation[_auto_index % _rotation.size()] and _can_summon(kind):
		_auto_index += 1
	if summon(kind):
		var i: int = deck.find(kind)
		if i >= 0:
			var btn: Button = _slots[i]["btn"]
			btn.scale = Vector2(0.92, 0.92)
			btn.pivot_offset = btn.size * 0.5
			btn.create_tween().tween_property(btn, "scale", Vector2.ONE, 0.15)

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
		if u["heal"] > 0.0:
			u["heal_t"] -= delta
			if u["heal_t"] <= 0.0:
				u["heal_t"] = HEAL_EVERY
				_heal_around(u)
		if u["stun"] > 0.0:
			u["stun"] -= delta
			continue
		var target = _target_for(u)
		if target != null:
			node.offset.y = base_off
			if u["cd"] <= 0.0:
				u["cd"] = u["every"]
				_attack(u, target)
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
		node.offset.y = base_off - (absf(sin(_clock * 9.0 + u["phase"])) * 2.0 if absf(nx - x) > 0.01 else 0.0)
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
		_banner("성이 무너졌어요", "STAGE %d" % stage, Color(1.0, 0.55, 0.45))
		get_tree().create_timer(1.0).timeout.connect(func(): defeated.emit(stage))
	if _dirty:
		_dirty = false
		_refresh()

# Single monsters from the stage's pool on a timer, and its scripted waves (a horn and a banner
# first when 3 or more come); after the last wave it repeats every WAVE_REPEAT seconds
func _waves(delta: float) -> void:
	elapsed += delta
	trickle_timer -= delta
	if trickle_timer <= 0.0:
		trickle_timer = stage_data["every"]
		_spawn_enemy(_pick_enemy(), power)
	var waves: Array = stage_data["waves"]
	if not waves.is_empty():
		var wave: Array = waves[mini(wave_index, waves.size() - 1)][1]
		if wave.size() >= 3 and not warned and elapsed >= next_wave_at - WARN_TIME:
			warned = true
			_sfx("b_horn", -4.0)
			_banner("적 대군이 몰려와요!", "", Color(1.0, 0.55, 0.45))
		if elapsed >= next_wave_at:
			for i in range(wave.size()):
				_pending.append([i * 0.7, wave[i], power])
			wave_index += 1
			warned = false
			next_wave_at = waves[wave_index][0] if wave_index < waves.size() else elapsed + WAVE_REPEAT
	for p in _pending.duplicate():
		p[0] -= delta
		if p[0] <= 0.0:
			_pending.erase(p)
			_spawn_enemy(p[1], p[2], false)

# Swarm monsters come in a group, except inside a big wave (which is crowded already)
func _spawn_enemy(kind: String, k: float, group: bool = true) -> void:
	var n: int = ENEMIES[kind].get("swarm", 1) if group and stage_data.get("swarm", true) else 1
	for i in range(n):
		if _count(-1) >= MAX_ENEMIES:
			return
		var u := _spawn(kind, -1, k)
		u["node"].position.x += i * 14.0

func _boss_entry() -> void:
	boss_out = true
	_sfx("b_roar", -2.0)
	var bd: Dictionary = LaneStages.BOSSES[stage_data["boss"]]
	_banner("보스 %s 등장!" % bd["name"], "충격파에 밀려나요", Color(1.0, 0.45, 0.4))
	castle_hit.emit(0)
	_shake_lane(8.0, 0.35)
	var boss := _spawn(bd["kind"], -1, power)
	boss["max_hp"] *= bd["hp"]
	boss["hp"] = boss["max_hp"]
	boss["atk"] *= bd["atk"]
	boss["speed"] *= 0.75
	boss["base_scale"] = Vector2.ONE * UNIT_PX * 2.0 * bd["scale"] / 1.6
	boss["node"].scale = boss["base_scale"]
	boss["kb"] = bd["kb"]
	boss["kb_mark"] = boss["max_hp"] * (bd["kb"] - 1) / bd["kb"]
	boss["boss"] = true
	_fx_once("ring", boss["node"].position + Vector2(0, -6), 0.5, 3.0)
	# The shockwave pushes every soldier back
	for u in units:
		if u["side"] == 1:
			_knock(u, KB_DIST * 2.5)
	_hitstop = 0.12
	_pending.append([0.8, _pick_enemy(), power])

# The nearest opponent in range (also behind: bats fly over the front line), else the enemy base
func _target_for(u: Dictionary):
	var x: float = u["node"].position.x
	var melee: bool = u["side"] == 1 and u["shot"] == ""
	var best = null
	var best_d: float = INF
	for c in units:
		if c["side"] == u["side"] or c["hp"] <= 0.0 or (melee and c.get("flying", false)):
			continue
		var d: float = absf(c["node"].position.x - x)
		if d <= u["range"] and d < best_d:
			best = c
			best_d = d
	if best != null:
		return best
	var o = _nearest_opponent(u)
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

# Damage of one hit: anti-air, armor (spears break it, the rest do half), siege on the fortress,
# and the target's guard
func _damage(attacker: Dictionary, target) -> float:
	var dmg: float = attacker["atk"]
	if target is String:
		if target == "fortress":
			dmg *= attacker.get("siege", 1.0)
		return dmg
	if target.get("flying", false):
		dmg *= attacker.get("air", 1.0)
	if target.get("armor", false):
		dmg *= attacker.get("armor_break", 0.5) if attacker.has("armor_break") else 0.5
	return dmg * (1.0 - target.get("guard", 0.0))

func _attack(u: Dictionary, target) -> void:
	var dmg: float = _damage(u, target)
	if u["shot"] == "":
		_lunge(u)
		_land_hit(u, target, dmg)
		return
	# Ranged: the projectile flies, the hit lands on arrival
	var node: Sprite2D = u["node"]
	var to: Vector2 = Vector2(FORT_X if target is String and target == "fortress" else CASTLE_X, GROUND - 60) if target is String else _mid(target)
	var from: Vector2 = node.position + Vector2(u["side"] * 8.0, -_height(node) * 0.6)
	_sfx("b_arrow" if u["shot"] in ["arrow", "bolt"] else "b_magic", -12.0)
	var sp := Sprite2D.new()
	sp.texture = tex.get(SHOT_TEX.get(u["shot"], "arrow"), tex["cannonball"])
	sp.scale = Vector2.ONE * FX_PX
	sp.position = from
	sp.z_index = 6
	if u["shot"] == "dark":
		sp.modulate = Color(0.75, 0.45, 1.0)
	var flight: float = clampf(from.distance_to(to) / 520.0, 0.12, 0.3)
	var arc: float = 18.0 if u["shot"] in ["arrow", "bolt"] else (34.0 if u["shot"] == "ball" else 0.0)
	_fx_layer.add_child(sp)
	var tw := sp.create_tween()
	tw.tween_method(func(t: float):
		var p: Vector2 = from.lerp(to, t) + Vector2(0, -arc * sin(PI * t))
		if u["shot"] in ["arrow", "bolt", "ball"]:
			sp.rotation = (p - sp.position).angle() if p != sp.position else sp.rotation
		sp.position = p, 0.0, 1.0, flight)
	tw.tween_callback(func():
		sp.queue_free()
		if target is String or units.has(target):
			_land_hit(u, target, dmg))

func _land_hit(attacker: Dictionary, target, dmg: float) -> void:
	_dirty = true
	if target is String:
		if target == "fortress":
			fortress_hp = maxf(0.0, fortress_hp - dmg)
			_number(Vector2(FORT_X, GROUND - 100), dmg, Color(1.0, 0.9, 0.5))
			_flash(_fort_sprite)
			_spark(Vector2(FORT_X - 20, GROUND - 50 - rng.randf() * 40), dmg >= 25.0)
			_sfx("b_hit", -12.0)
		else:
			castle_hp = maxi(0, castle_hp - roundi(dmg))
			_number(Vector2(CASTLE_X + 10, GROUND - 100), dmg, Color(1.0, 0.45, 0.4))
			_flash(_castle_sprite)
			_spark(Vector2(CASTLE_X + 24, GROUND - 50 - rng.randf() * 40), false)
			_sfx("b_castle", -8.0)
			if _clock - _castle_hit_last > 0.8:
				_castle_hit_last = _clock
				castle_hit.emit(roundi(dmg))
		return
	_hurt(target, dmg, attacker["side"] == 1)
	if attacker["shot"] == "":
		_slash(target, attacker["side"])
		_sfx("b_hit", -12.0)
	if attacker.get("splash", 0.0) > 0.0:
		_fx_once("boom_s", _mid(target), 0.18)
		for o in units.duplicate():
			if o != target and o["side"] == target["side"] and absf(o["node"].position.x - target["node"].position.x) <= attacker["splash"]:
				_hurt(o, _damage(attacker, o) * 0.6, attacker["side"] == 1)

func _hurt(u: Dictionary, dmg: float, by_ally: bool) -> void:
	u["hp"] -= dmg
	_flash(u["node"])
	_squash(u)
	_spark(_mid(u) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-6, 6)), dmg >= 20.0)
	_number(_head(u), dmg, Color(1.0, 0.95, 0.6) if by_ally else Color(1.0, 0.5, 0.45))
	if dmg >= 25.0:
		_hitstop = maxf(_hitstop, 0.05)
		_shake_lane(3.0, 0.12)
	# Knockback each time the HP drops past the next mark
	if u["hp"] > 0.0 and u["hp"] <= u["kb_mark"]:
		u["kb_mark"] -= u["max_hp"] / u["kb"]
		_knock(u, KB_DIST)

# Healers: every HEAL_EVERY seconds, hurt friends around get HP back
func _heal_around(u: Dictionary) -> void:
	var healed := false
	for o in units:
		if o["side"] != u["side"] or o["hp"] <= 0.0 or o["hp"] >= o["max_hp"]:
			continue
		if absf(o["node"].position.x - u["node"].position.x) > u["heal_r"]:
			continue
		var gain: float = minf(u["heal"], o["max_hp"] - o["hp"])
		o["hp"] += gain
		healed = true
		_fx_once("heal", _head(o) + Vector2(0, 4), 0.5, 1.0, Vector2(0, -16))
		_number(_head(o) + Vector2(0, -10), gain, Color(0.5, 1.0, 0.55), "+")
	if healed:
		_dirty = true
		_fx_once("holy", _mid(u), 0.35, 1.6)

func _knock(u: Dictionary, dist: float) -> void:
	var node: Sprite2D = u["node"]
	var side: int = u["side"]
	u["stun"] = KB_TIME
	var to_x: float = clampf(node.position.x - side * dist, ALLY_START - 20.0, ENEMY_START + 20.0)
	var base_off: float = -node.texture.get_height() * 0.5
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position:x", to_x, KB_TIME * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "offset:y", base_off - 8.0, KB_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(node, "offset:y", base_off, KB_TIME * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_fx_once("dust", node.position + Vector2(side * 6.0, -3), 0.3)

func _pick_enemy() -> String:
	var pool: Array = stage_data["pool"]
	return pool[rng.randi() % pool.size()]

func _start_stage() -> void:
	fortress_max = float(stage_data["fortress"])
	fortress_hp = fortress_max
	boss_out = stage_data["boss"] == ""
	elapsed = 0.0
	wave_index = 0
	var waves: Array = stage_data["waves"]
	next_wave_at = waves[0][0] if not waves.is_empty() else INF
	trickle_timer = 6.0
	warned = false
	_stage_label.text = "STAGE %d" % stage
	_stage_name.text = stage_data["name"]
	_bg.self_modulate = LaneStages.chapter(stage)["tint"]
	_banner("STAGE %d · %s" % [stage, stage_data["name"]], stage_data.get("new", ""))
	_spawn_enemy(_pick_enemy(), power)
	_refresh()

# The fortress falls: stars from the castle HP left, then cleared() after the banner
func _stage_cleared() -> void:
	switching = true
	finished = true
	_pending.clear()
	for u in units.duplicate():
		if u["side"] == -1:
			_kill(u)
	var stars: int = LaneStages.stars_for(float(castle_hp) / CASTLE_HP)
	_sfx("b_cannon", -4.0)
	for i in range(4):
		get_tree().create_timer(i * 0.12).timeout.connect(func(): _boom(Vector2(FORT_X - 10 + rng.randf_range(-20, 20), GROUND - rng.randf_range(20, 100))))
	_banner("STAGE %d 클리어!" % stage, LaneStages.star_text(stars))
	_refresh()
	get_tree().create_timer(1.3).timeout.connect(func(): cleared.emit(stage, stars))

# =========================================================
# Units
# =========================================================

func _spawn(kind: String, side: int, k: float) -> Dictionary:
	var st: Dictionary = LaneUnits.stats(kind, int(tiers.get(kind, ALLIES[kind]["tier"]))) if side == 1 else ENEMIES[kind]
	var node := Sprite2D.new()
	node.texture = tex[kind]
	node.scale = Vector2.ONE * UNIT_PX
	node.offset = Vector2(0, -node.texture.get_height() * 0.5)
	var y: float = GROUND + [0.0, 6.0, 3.0, 9.0][units.size() % 4]
	if st.get("flying", false):
		y = GROUND - FLY_H
	node.position = Vector2(ALLY_START if side == 1 else ENEMY_START, y)
	_units_layer.add_child(node)
	var hp: float = st["hp"] * k
	var u := {"node": node, "side": side, "kind": kind, "hp": hp, "max_hp": hp, "atk": st["atk"] * k,
		"range": st["range"], "shot": st.get("shot", ""), "splash": st.get("splash", 0.0),
		"speed": st["speed"] * SPEED_K, "every": st["every"], "cd": st["every"] * 0.5, "phase": rng.randf() * TAU,
		"kb": st["kb"], "kb_mark": hp * (st["kb"] - 1) / st["kb"], "stun": 0.0,
		"stand": maxf(16.0, st["range"] * rng.randf_range(0.5, 0.9)),
		"flying": st.get("flying", false), "armor": st.get("armor", false), "guard": st.get("guard", 0.0),
		"heal": st.get("heal", 0.0), "heal_r": st.get("heal_r", 0.0), "heal_t": HEAL_EVERY,
		"base_scale": Vector2.ONE * UNIT_PX}
	for key in ["air", "armor_break", "siege"]:
		if st.has(key):
			u[key] = st[key]
	u["bar"] = _unit_bar(node)
	for mark in ["armor", "flying"]:
		if u[mark]:
			var icon := Sprite2D.new()
			icon.texture = _icons[mark]
			icon.position = Vector2(0, -node.texture.get_height() - 6)
			node.add_child(icon)
	if side == -1 and u["heal"] > 0.0:
		var icon := Sprite2D.new()
		icon.texture = _icons["heal"]
		icon.position = Vector2(0, -node.texture.get_height() - 6)
		node.add_child(icon)
	units.append(u)
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, 0.2)
	return u

func _count(side: int) -> int:
	return units.filter(func(u): return u["side"] == side).size()

# Fallen units fly back with a spin, a dust puff and a burst of pixels
func _kill(u: Dictionary) -> void:
	units.erase(u)
	var node: Sprite2D = u["node"]
	var side: int = u["side"]
	_sfx("b_death", -10.0)
	_fx_once("dust", _mid(u), 0.4, 1.4)
	var tw := node.create_tween().set_parallel(true)
	tw.tween_property(node, "position", node.position + Vector2(-side * 40.0, -30.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "rotation", -side * 1.8, 0.4)
	tw.tween_property(node, "modulate:a", 0.0, 0.4).set_delay(0.1)
	tw.chain().tween_callback(node.queue_free)
	var c: Vector2 = _mid(u)
	for i in range(6):
		var bit := ColorRect.new()
		bit.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bit.size = Vector2(3, 3)
		bit.color = Color(1.0, 0.95, 0.8) if i % 2 == 0 else (Color(0.6, 0.85, 1.0) if side == 1 else Color(1.0, 0.55, 0.4))
		bit.position = c
		bit.z_index = 7
		_view.add_child(bit)
		var a: float = TAU * i / 6.0 + rng.randf() * 0.5
		var bt := bit.create_tween().set_parallel(true)
		bt.tween_property(bit, "position", c + Vector2(cos(a), sin(a)) * rng.randf_range(14, 26), 0.35).set_ease(Tween.EASE_OUT)
		bt.tween_property(bit, "modulate:a", 0.0, 0.35)
		bt.chain().tween_callback(bit.queue_free)

func _head(u: Dictionary) -> Vector2:
	return u["node"].position + Vector2(0, -_height(u["node"]) - 6)

func _mid(u: Dictionary) -> Vector2:
	return u["node"].position + Vector2(0, -_height(u["node"]) * 0.5)

func _height(node: Sprite2D) -> float:
	return node.texture.get_height() * node.scale.y

func _flash(node: CanvasItem) -> void:
	node.modulate = Color(2.6, 2.6, 2.6, node.modulate.a)
	node.create_tween().tween_property(node, "modulate", Color(1, 1, 1, node.modulate.a), 0.16)

# Hit squash: the sprite flattens for a moment and springs back
func _squash(u: Dictionary) -> void:
	var node: Sprite2D = u["node"]
	var s: Vector2 = u["base_scale"]
	node.scale = Vector2(s.x * 1.2, s.y * 0.82)
	node.create_tween().tween_property(node, "scale", s, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

# Melee swing: lunge with the sprite offset so it never fights the walking position
func _lunge(u: Dictionary) -> void:
	var node: Sprite2D = u["node"]
	var tw := node.create_tween()
	tw.tween_property(node, "offset:x", u["side"] * 5.0, 0.06)
	tw.tween_property(node, "offset:x", 0.0, 0.12)

func _slash(target: Dictionary, side: int) -> void:
	if not tex.has("slash"):
		return
	var sp := _fx_once("slash", _mid(target) + Vector2(-side * 4.0, 0), 0.16)
	sp.flip_h = side == -1

func _spark(at: Vector2, big: bool) -> void:
	_fx_once("spark", at, 0.14, 1.4 if big else 1.0)
	if big:
		_fx_once("ring", at, 0.25, 1.2)

func _boom(at: Vector2) -> void:
	_fx(["boom_s", "boom_l", "smoke"], at, [0.06, 0.12, 0.3])
	_sfx("b_hit", -8.0)
	_hitstop = maxf(_hitstop, 0.04)
	_shake_lane(4.0, 0.15)

# A short frame-by-frame effect; the last frame fades out
func _fx(frames: Array, at: Vector2, times: Array) -> void:
	var sp := Sprite2D.new()
	sp.texture = tex[frames[0]]
	sp.scale = Vector2.ONE * BASE_PX
	sp.position = at
	sp.z_index = 7
	_fx_layer.add_child(sp)
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

# One sprite that pops (a little bigger, then fades), optionally drifting
func _fx_once(name: String, at: Vector2, time: float, k: float = 1.0, drift: Vector2 = Vector2.ZERO) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex.get(name, tex["flash"])
	sp.scale = Vector2.ONE * FX_PX * k * 0.7
	sp.position = at
	sp.z_index = 7
	_fx_layer.add_child(sp)
	var tw := sp.create_tween().set_parallel(true)
	tw.tween_property(sp, "scale", Vector2.ONE * FX_PX * k, time * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "modulate:a", 0.0, time * 0.6).set_delay(time * 0.4)
	if drift != Vector2.ZERO:
		tw.tween_property(sp, "position", at + drift, time)
	tw.chain().tween_callback(sp.queue_free)
	return sp

# Shakes only the lane (the puzzle below stays still)
func _shake_lane(strength: float, time: float) -> void:
	var tw := _shake.create_tween()
	var steps: int = 5
	for i in range(steps):
		var f: float = strength * (1.0 - float(i) / steps)
		tw.tween_property(_shake, "position", Vector2(rng.randf_range(-f, f), rng.randf_range(-f, f) * 0.6), time / steps)
	tw.tween_property(_shake, "position", Vector2.ZERO, time / steps)

func _unit_bar(owner: Sprite2D) -> Panel:
	var bg := Panel.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0.6), Color.TRANSPARENT, 2))
	bg.size = Vector2(28, 4)
	var fill := Panel.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(1, 1)
	fill.size = Vector2(26, 2)
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
	_shake = Node2D.new()
	_view.add_child(_shake)
	var lane_tex: Texture2D = tex["lane"]
	var k: float = ceil(maxf(720.0 / lane_tex.get_width(), LANE_H / lane_tex.get_height()))
	var bg := TextureRect.new()
	_bg = bg
	bg.texture = lane_tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.size = Vector2(lane_tex.get_width(), lane_tex.get_height()) * k
	bg.position = Vector2((720.0 - bg.size.x) * 0.5, LANE_H - bg.size.y + 4.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake.add_child(bg)
	for side in [1, -1]:
		var t: Texture2D = tex["castle" if side == 1 else "fortress"]
		var b := Sprite2D.new()
		b.texture = t
		b.scale = Vector2.ONE * BASE_PX
		b.centered = false
		b.position = Vector2(CASTLE_LEFT if side == 1 else FORT_RIGHT - t.get_width() * BASE_PX, GROUND + 4.0 - t.get_height() * BASE_PX)
		_shake.add_child(b)
		if side == 1:
			_castle_sprite = b
		else:
			_fort_sprite = b
	# The cannon stands on the castle's right tower (its top is 53 art pixels below the castle top)
	_cannon_sprite = Sprite2D.new()
	_cannon_sprite.texture = tex["cannon"]
	_cannon_sprite.scale = Vector2.ONE * BASE_PX
	_cannon_sprite.centered = false
	_cannon_sprite.position = Vector2(_castle_sprite.position.x + (56.0 - tex["cannon"].get_width() * 0.35) * BASE_PX, _castle_sprite.position.y + (53.0 - tex["cannon"].get_height()) * BASE_PX)
	_shake.add_child(_cannon_sprite)
	_units_layer = Node2D.new()
	_units_layer.y_sort_enabled = true
	_shake.add_child(_units_layer)
	_fx_layer = Node2D.new()
	_shake.add_child(_fx_layer)
	_bars_layer = Node2D.new()
	_shake.add_child(_bars_layer)
	var rib := LaneUI.ribbon("", 190, 22)
	rib.position = Vector2(352, 2)
	_view.add_child(rib)
	_stage_label = rib.get_child(0)
	_stage_name = _outlined("", 16, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_stage_name.position = Vector2(352, 54)
	_stage_name.size = Vector2(190, 22)
	_view.add_child(_stage_name)
	# HP bars on the ground in front of each building (the top-right corner is Toss's button area)
	var cb := _bar(_view, Vector2(4, LANE_H - 24), Vector2(BASE_BAR_W, 18))
	_castle_fill = cb.get_child(0)
	_castle_label = _outlined("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_castle_label.size = cb.size
	_castle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cb.add_child(_castle_label)
	var fb := _bar(_view, Vector2(720 - 4 - BASE_BAR_W, LANE_H - 24), Vector2(BASE_BAR_W, 18))
	_fort_fill = fb.get_child(0)
	_fort_label = _outlined("", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_fort_label.size = fb.size
	_fort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fb.add_child(_fort_label)
	# Top-left of the lane: home / settings / sound on a dark pill, then charge/hold and auto
	var pill := Panel.new()
	LaneUI.dress(pill, "panel_wood")
	pill.position = Vector2(6, 6)
	pill.size = Vector2(150, 48)
	pill.mouse_filter = Control.MOUSE_FILTER_PASS
	_view.add_child(pill)
	var i_menu := 0
	for key in ["home", "settings", "sound"]:
		var mb := TextureButton.new()
		mb.ignore_texture_size = true
		mb.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		mb.position = Vector2(10 + i_menu * 44, 6)
		mb.size = Vector2(36, 36)
		mb.focus_mode = Control.FOCUS_NONE
		mb.pressed.connect(func(): (home_pressed if key == "home" else (settings_pressed if key == "settings" else sound_pressed)).emit())
		pill.add_child(mb)
		_menu[key] = mb
		i_menu += 1
	_march_btn = Button.new()
	_march_btn.position = Vector2(160, 8)
	_march_btn.size = Vector2(90, 44)
	_march_btn.focus_mode = Control.FOCUS_NONE
	_march_btn.pressed.connect(toggle_march)
	_view.add_child(_march_btn)
	_auto_btn = Button.new()
	_auto_btn.position = Vector2(256, 8)
	_auto_btn.size = Vector2(92, 44)
	_auto_btn.focus_mode = Control.FOCUS_NONE
	_auto_btn.pressed.connect(toggle_auto)
	_view.add_child(_auto_btn)
	# Summon bar right under the lane: gold and income on the left, the deck, then the cannon
	var bar := Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(0, LANE_H)
	bar.size = Vector2(720, BAR_H)
	LaneUI.dress(bar, "panel_wood")
	add_child(bar)
	var coin := LaneUI.icon("icon_coin", Vector2(24, 24))
	coin.position = Vector2(14, 14)
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
	_income_btn.position = Vector2(10, 46)
	_income_btn.size = Vector2(164, 44)
	_income_btn.focus_mode = Control.FOCUS_NONE
	LaneUI.button(_income_btn, "green", 16)
	_income_btn.pressed.connect(upgrade_wallet)
	bar.add_child(_income_btn)
	for i in range(LaneUnits.DECK_SIZE):
		var btn := Button.new()
		btn.position = Vector2(180 + i * 106, 8)
		btn.size = Vector2(100, 84)
		btn.focus_mode = Control.FOCUS_NONE
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var slot := i
		btn.pressed.connect(func(): summon(deck[slot] if slot < deck.size() else ""))
		bar.add_child(btn)
		# Kept simple so it breathes: the soldier in the middle, its price on a small strip below
		# (the tier shows in the frame and colour; name and tier name stay hidden)
		var icon := TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(18, 9)
		icon.size = Vector2(64, 48)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		var n := _outlined("", 15, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		n.visible = false
		btn.add_child(n)
		var strip := Panel.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		strip.add_theme_stylebox_override("panel", UIKit.box(Color(0.04, 0.03, 0.06, 0.7), Color.TRANSPARENT, 9))
		strip.position = Vector2(20, 58)
		strip.size = Vector2(60, 20)
		strip.name = "Strip"
		btn.add_child(strip)
		var cc := LaneUI.icon("icon_coin", Vector2(14, 14))
		cc.position = Vector2(25, 61)
		cc.name = "Coin"
		btn.add_child(cc)
		var c := _outlined("", 17, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		c.position = Vector2(38, 56)
		c.size = Vector2(40, 24)
		btn.add_child(c)
		var lv := _outlined("", 13, Color(0.75, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		lv.visible = false
		btn.add_child(lv)
		# Cooldown veil: covers the button and shrinks as the cooldown runs out
		var veil := ColorRect.new()
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.color = Color(0.02, 0.03, 0.08, 0.6)
		veil.size = Vector2(100, 0)
		veil.position = Vector2(4, 4)
		btn.add_child(veil)
		# The tier card sits behind everything on the button
		var card := LaneTierCard.new(0, btn.size, 0.5)
		btn.add_child(card)
		btn.move_child(card, 0)
		for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		btn.button_down.connect(func(): btn.scale = Vector2(0.94, 0.94))
		btn.button_up.connect(func(): btn.scale = Vector2.ONE)
		btn.pivot_offset = btn.size * 0.5
		_slots.append({"btn": btn, "icon": icon, "name": n, "cost": c, "lv": lv, "veil": veil, "card": card})
	_cannon_btn = Button.new()
	_cannon_btn.position = Vector2(606, 8)
	_cannon_btn.size = Vector2(106, 84)
	_cannon_btn.focus_mode = Control.FOCUS_NONE
	_cannon_btn.clip_contents = true
	_cannon_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		_cannon_btn.add_theme_stylebox_override(st, LaneUI.box("card_frame", 6, Color(1.4, 0.6, 0.45) if st != "pressed" else Color(1.0, 0.45, 0.35)))
	_cannon_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
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

# Fills the 4 summon buttons from the deck
func _setup_slots() -> void:
	for i in range(_slots.size()):
		var s: Dictionary = _slots[i]
		var kind: String = deck[i] if i < deck.size() else ""
		if kind == "":
			s["icon"].texture = null
			s["name"].text = ""
			s["cost"].text = ""
			s["lv"].text = ""
			s["btn"].get_node("Coin").visible = false
			s["btn"].get_node("Strip").visible = false
			s["card"].set_tier(0)
			s["card"].modulate = Color(0.5, 0.5, 0.55)
			continue
		var st: Dictionary = ALLIES[kind]
		var t: int = int(tiers.get(kind, st["tier"]))
		s["btn"].get_node("Coin").visible = true
		s["btn"].get_node("Strip").visible = true
		s["card"].set_tier(t)
		s["card"].modulate = Color.WHITE
		s["icon"].texture = tex[kind]
		s["name"].text = st["name"]
		s["cost"].text = str(st["cost"])
		s["lv"].text = LaneUnits.TIER_NAME[t]
		s["lv"].add_theme_color_override("font_color", LaneUnits.tier_color(t).lightened(0.35))

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
	LaneUI.button(_march_btn, "red" if charging else "blue", 18)
	_march_btn.text = "돌격" if charging else "수비"
	LaneUI.button(_auto_btn, "green" if auto_summon else "blue", 18) # green while on
	_auto_btn.text = "자동 ON" if auto_summon else "자동"
	for i in range(_slots.size()):
		var kind: String = deck[i] if i < deck.size() else ""
		var ok: bool = kind != "" and gold >= ALLIES[kind]["cost"] and _count(1) < MAX_ALLIES and not finished
		_slots[i]["btn"].modulate = Color.WHITE if ok else Color(0.5, 0.5, 0.56)
	_cannon_label.text = "발사!" if cannon >= 100.0 else "%d%%" % int(cannon)
	for u in units:
		var bg: Panel = u["bar"]
		bg.visible = u["hp"] < u["max_hp"]
		var fill: Panel = bg.get_child(0)
		fill.size.x = 26.0 * clampf(u["hp"] / u["max_hp"], 0.0, 1.0)
		fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.35, 0.86, 0.43) if u["side"] == 1 else Color(1.0, 0.4, 0.35), Color.TRANSPARENT, 1))

func _process(delta: float) -> void:
	if not finished and not paused and visible:
		if _hitstop > 0.0:
			_hitstop -= delta # a short freeze sells heavy hits
		else:
			_tick(delta)
	for u in units:
		var node: Sprite2D = u["node"]
		u["bar"].position = node.position + Vector2(-14, -_height(node) - 7)
	for i in range(_slots.size()):
		var kind: String = deck[i] if i < deck.size() else ""
		var left: float = cooldown.get(kind, 0.0) if kind != "" else 0.0
		_slots[i]["veil"].size.y = 80.0 * left / ALLIES[kind]["cool"] if kind != "" else 0.0
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

# Damage (or heal, with "+") numbers pop up big and shrink as they rise
func _number(pos: Vector2, value: float, col: Color, prefix: String = "") -> void:
	var big: bool = value >= 20.0
	var l := _outlined(prefix + str(roundi(value)), 20 if big else 15, col, HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(60, 24)
	l.position = pos - l.size * 0.5 + Vector2(rng.randf_range(-6, 6), 0)
	l.pivot_offset = l.size * 0.5
	l.scale = Vector2.ONE * (1.6 if big else 1.3)
	l.z_index = 8
	_view.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 24, 0.55)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.28)
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
