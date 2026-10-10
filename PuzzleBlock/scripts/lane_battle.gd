class_name LaneBattle
extends Control
# "블록 기사단": a real-time side-view lane battle above the normal puzzle (board shrunk by MainGame).
# Ideas taken from The Battle Cats, Paladog, Stick War and Plants vs Zombies (docs/BATTLE_RESEARCH.md):
# - Units walk at their own speed and hit the first enemy in range on their own attack timer.
#   Big hits knock units back (each kind has a knockback count), deaths fly off with a poof.
# - The 4 summon buttons are the player's deck (LaneUnits, built outside battles with the gacha and
#   the deck screen). Each soldier has a role: melee, tank, armor breaker, ranged, anti-air, mage,
#   healer, siege; star tiers (merged from duplicates) raise HP and attack.
# - Gold comes only from clearing puzzle lines; "지갑 확장" only raises the max carry limit.
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

# 2026-10-08: auto plays the deck, so the summon bar is gone (hidden, BAR_H 0) and the lane takes
# its space; soldiers and monsters drawn 1.4x
const LANE_H: float = 470.0
const BAR_H: float = 0.0
const UNIT_PX: float = 1.4            # soldiers and monsters, a little over their pixel size
const BASE_PX: float = 1.0            # cannon, cannonball, flash, boom (keep original scale)
const STRUCT_PX: float = 1.8          # castle and fortress structures (bigger so hero fits naturally at the gate)
const FX_PX: float = 1.0              # effects
const GROUND: float = 412.0           # feet line in the lane (on the dirt road)
const FLY_H: float = 56.0             # bats hover this high
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
const WALLET_INCOME: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
const WALLET_COST: Array[int] = [60, 130, 220, 340]
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
	# 서유기 1장 쫄몹 (2026-10-10 docs/JOURNEY_WEST_PLAN.md)
	"tiger_mob":   {"hp": 46.0, "atk": 10.0, "range": 44.0, "speed": 36.0, "every": 1.0, "kb": 2},
	"bandit":      {"hp": 58.0, "atk": 11.0, "range": 44.0, "speed": 28.0, "every": 1.1, "kb": 2},
	"water_ghoul": {"hp": 110.0, "atk": 9.0,  "range": 44.0, "speed": 16.0, "every": 1.5, "kb": 2},
}

# 영웅 수치 (docs/HERO_SYSTEM_PLAN.md 표). cool: 스킬 쿨, skill: 액티브 스킬 이름.
# 전투 시작 시 자동 소환 (금화 비용 없음, 성 바로 앞). 사망 시 영구.
const HEROES: Dictionary = {
	"sanzang":  {"hp": 300.0, "atk": 6.0,  "range": 80.0, "speed": 24.0, "every": 1.5, "kb": 3, "cool": 25.0,
		"skill": "aura_buff",  "skill_name": "염불 결계",  "shot": ""},
	"wukong":   {"hp": 450.0, "atk": 32.0, "range": 50.0, "speed": 36.0, "every": 0.9, "kb": 4, "cool": 30.0,
		"skill": "line_sweep", "skill_name": "여의봉 광풍", "shot": ""},
	"bajie":    {"hp": 600.0, "atk": 20.0, "range": 44.0, "speed": 24.0, "every": 1.3, "kb": 5, "cool": 28.0,
		"skill": "cone_dash",  "skill_name": "쇄기 돌진",   "shot": ""},
	"wujing":   {"hp": 400.0, "atk": 24.0, "range": 70.0, "speed": 28.0, "every": 1.1, "kb": 4, "cool": 32.0,
		"skill": "heal_wave",  "skill_name": "수룡 재생",   "shot": ""},
}
# Projectile sprite per shot kind
const SHOT_TEX: Dictionary = {"arrow": "arrow", "bolt": "bolt", "orb": "fireball", "light": "holy", "ball": "cannonball", "dark": "fireball", "ice": "holy", "note": "holy", "fireball": "fireball"}
# Tints for shots that reuse another projectile
const SHOT_TINT: Dictionary = {"dark": Color(0.75, 0.45, 1.0), "ice": Color(0.55, 0.9, 1.0), "note": Color(1.0, 0.85, 0.35)}
const SLOW_K: float = 0.5             # speed while slowed (얼음 마법사)
const SLOWED_TINT: Color = Color(0.6, 0.85, 1.0)
const CHEERED_TINT: Color = Color(1.15, 1.05, 0.75)

# 전투 테스트 모드 (dev 전용, 2026-10-10): 홈의 "전투 테스트" 버튼으로 켜짐. 퍼즐 보드/트레이는
# 완전히 숨기고, 전장 아래 빈 영역에 쫄몹·아군 소환 버튼을 배치해 전투만 손으로 시험한다.
# 소환은 금화·쿨다운·덱 체크 없이 자유. master로 머지 전 자동 비활성(홈의 DEV_TOOLS로 가림).
var test_mode: bool = false
# 2026-10-11: test_mode를 세로 화면에 쓸 때 전체를 90° CCW 회전시켜 성(원래 LEFT)=바닥,
# 요새(원래 RIGHT)=상단으로 보이게 한다. 전투 로직(가로)은 그대로 두고 뷰만 돌린다.
var test_rotated: bool = false
# 2026-10-11: "전투만" 모드. 블록 퍼즐 없이 가로 전투만. 덱의 4명만 소환 버튼, 자동 wave 유지,
# 금화는 1/sec 트리클 + 시작 100 (퍼즐 클리어 수익이 없으므로). test_mode와 다르게 금화/쿨/덱 규칙은 지킨다.
var battle_only_mode: bool = false
const BATTLE_ONLY_INCOME: float = 1.0
const BATTLE_ONLY_START_GOLD: int = 100
# 2026-10-11: 전투만 모드에서는 레인 뷰를 세로로 더 넓게 보여 "넉넉한 전장"을 만든다.
# LANE_H(=470)는 그대로 두고 _view.size.y만 680으로 override, 하단 패널은 y=680~1280 (600px).
const BO_VIEW_H: float = 680.0
const BO_PANEL_TOP: float = 680.0
var _bo_panel: Control = null
var _bo_ground_fill: ColorRect = null
# 하단 전용 위젯 (전투만 모드)
var _bo_back_btn: Button = null
var _bo_skill_btn: Button = null
var _bo_skill_icon: TextureRect = null
var _bo_skill_veil: ColorRect = null
var _bo_skill_label: Label = null
var _bo_skill_name_label: Label = null
var _bo_auto_btn: Button = null
var _bo_march_btn: Button = null
var _bo_cannon_btn: Button = null
var _bo_cannon_fill: ColorRect = null
var _bo_cannon_label: Label = null
var _bo_wallet_btn: Button = null
var _bo_wave_label: Label = null
var _bo_enemy_list: HBoxContainer = null
var _test_panel: Control = null

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
var rally_done: int = 0               # counterattacks sent (at 2/3 and 1/3 of the fortress)
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
var _sky: ColorRect
var _boss_timer: float = 0.0           # night_eye swoop clock
var _splits_pending: Array = []        # [[kind, pos], ...] mini-mobs that spawn after a boss dies
# 영웅 시스템 (2026-10-10 docs/HERO_SYSTEM_PLAN.md)
var hero_id: String = ""               # 이번 전투의 영웅 ID ("sanzang" 등)
var hero_unit: Dictionary = {}         # 전장 위 영웅 유닛 (units 안에 들어감). hp 0이면 사망
var hero_dead: bool = false            # 영구 사망 플래그 (스테이지 끝까지)
var hero_cool: float = 0.0             # 스킬 쿨 남은 초
var _hero_portrait: TextureRect
var _hero_hp_fill: Panel
var _hero_hp_label: Label
var _hero_dead_x: Label                # 사망 시 보이는 X 표시
var _hero_name_label: Label
var _hero_skill_btn: Button
var _hero_skill_fill: ColorRect
var _hero_skill_label: Label
var _hero_skill_icon: TextureRect
var _hero_skill_name_label: Label
var _hero_skill_name_bg: Panel
var _hero_skill_ready_pulse: float = 0.0  # 쿨 끝났을 때 "준비!" 깜빡임 타이머
var _hero_skill_breath: float = 0.0       # 호흡 애니 clock
var _wave_push_t: float = 0.0          # 사오정 보스의 wave_push 타이머
var _stun_roar_t: float = 0.0          # 호선봉 보스의 stun_roar 타이머
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
	# 2026-10-09: per-stage backgrounds and boss sprites
	names.append_array(["bg_grassland", "bg_goblin_camp", "bg_bat_cave", "boss_king_slime", "boss_goblin_chief", "boss_night_eye"])
	# 2026-10-10 서유기 1장: heroes, 1장 보스·쫄몹, 1장 배경 (docs/JOURNEY_WEST_PLAN.md + HERO_SYSTEM_PLAN.md)
	names.append_array(["hero_sanzang", "hero_wukong", "hero_bajie", "hero_wujing",
		"boss_tiger_vanguard", "boss_white_bone", "boss_black_bear", "boss_sand_monk",
		"tiger_mob", "bandit", "water_ghoul",
		"bg_mt_wuzhi", "bg_white_bone", "bg_black_wind", "bg_flowing_sand"])
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
	# 영웅 선택 (저장된 선택값, 없으면 삼장). 전투 시작 시 자동 소환.
	hero_id = LaneUnits.selected_hero()
	hero_dead = false
	hero_unit = {}
	hero_cool = 0.0
	_wave_push_t = 0.0
	_stun_roar_t = 0.0
	visible = true
	_start_stage()
	_spawn_hero()
	_refresh_hero_ui()
	_apply_test_mode()

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
	if finished or kind == "":
		return false
	# 전투 테스트: 덱/금화/쿨 무시, 유닛 상한만 지킴
	if test_mode:
		if not ALLIES.has(kind) or _count(1) >= MAX_ALLIES:
			return false
		var u := _spawn(kind, 1, 1.0)
		var node: Sprite2D = u["node"]
		node.position.y -= 16.0
		node.create_tween().tween_property(node, "position:y", node.position.y + 16.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		get_tree().create_timer(0.18).timeout.connect(func(): _fx_once("dust", node.position + Vector2(0, -4), 0.35))
		_sfx("b_summon", -10.0)
		return true
	if not deck.has(kind):
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

# Who holds the line, who answers bats, who breaks armor (best first), and supports kept to 2
# The front-liner is summoned most, so cheap ones come first
const FRONT_KINDS: Array[String] = ["knight", "rogue", "shield", "berserker", "spearman", "cavalry", "hero", "paladin"]
const AIR_KINDS: Array[String] = ["crossbow", "dragon", "archer", "mage", "icemage"]
const BREAKER_KINDS: Array[String] = ["spearman", "cannoneer", "hero"]
const SUPPORT_KINDS: Array[String] = ["cleric", "bard"]

func _front_kind() -> String:
	for k in FRONT_KINDS:
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
		# 영웅은 자동 소환 집계에서 제외 (ALLIES/LaneUnits.UNITS에 없음)
		if u["side"] == 1 and not u.get("hero", false):
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
	var air: String = _first_in_deck(AIR_KINDS)
	var breaker: String = _first_in_deck(BREAKER_KINDS)
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
	if SUPPORT_KINDS.has(want) and mine.get(want, 0) >= 2:
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
	if test_mode:
		for k in cooldown:
			cooldown[k] = 0.0
		hero_cool = 0.0
		gold = wallet_max()
	# 영웅 스킬 쿨 감소 + UI 리프레시 (매 틱 호출해도 가벼움)
	var was_cooling: bool = hero_cool > 0.0
	if hero_cool > 0.0:
		hero_cool = maxf(0.0, hero_cool - delta)
		if hero_cool <= 0.0 and was_cooling:
			_hero_skill_ready_pulse = 0.8  # 쿨 끝남 → "준비!" 짧게
	if _hero_skill_ready_pulse > 0.0:
		_hero_skill_ready_pulse = maxf(0.0, _hero_skill_ready_pulse - delta)
	# 쿨 아님 상태에서 호흡 (±2%)
	_hero_skill_breath += delta
	if _hero_skill_btn != null and _hero_skill_btn.visible:
		var ready: bool = hero_cool <= 0.0 and not hero_dead
		if ready:
			var s: float = 1.0 + 0.02 * sin(_hero_skill_breath * 3.0)
			_hero_skill_btn.pivot_offset = _hero_skill_btn.size * 0.5
			_hero_skill_btn.scale = Vector2(s, s)
		else:
			_hero_skill_btn.scale = Vector2.ONE
	_refresh_hero_ui()
	if gold < wallet_max():
		# 전투만 모드: 퍼즐 클리어 수익이 없으므로 금화를 초당 1씩 트리클
		var inc: float = BATTLE_ONLY_INCOME if battle_only_mode else WALLET_INCOME[wallet]
		_gold_acc += inc * delta
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
		_tick_effects(u, delta)
		if u.get("boss", false):
			_tick_boss(u, delta)
		if u["heal"] > 0.0:
			u["heal_t"] -= delta
			if u["heal_t"] <= 0.0:
				u["heal_t"] = HEAL_EVERY
				_heal_around(u)
		if u["stun"] > 0.0:
			u["stun"] -= delta
			continue
		# 영웅(caster)은 성 쪽에 고정 — 자동 공격·전진 안 함. 스킬 버튼으로만 행동
		if u.get("role", "") == "caster":
			node.position.x = u.get("anchor_x", node.position.x)
			node.offset.y = base_off
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
			nx = maxf(limit, x - _speed(u) * delta) # fall back to the hold line
		else:
			nx = x + side * _speed(u) * delta
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
	# The fortress fights back as it falls: a big wave at 2/3 and at 1/3, so wins stay close
	if not switching and rally_done < 2 and fortress_hp <= fortress_max * (2.0 - rally_done) / 3.0:
		rally_done += 1
		_rally()
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

func _rally() -> void:
	_sfx("b_horn", -3.0)
	_banner("요새의 반격!", "적 대군이 몰려와요", Color(1.0, 0.55, 0.45))
	_shake_lane(5.0, 0.25)
	var pool: Array = stage_data["pool"]
	var n: int = 3 + rally_done + stage / 8
	for i in range(n):
		_pending.append([0.5 + i * 0.5, pool[rng.randi() % pool.size()], power])

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
	# Swap in the boss sprite if the data carries a dedicated texture (e.g. boss_king_slime)
	var btex: String = bd.get("tex", "")
	if btex != "" and tex.has(btex):
		boss["node"].texture = tex[btex]
		boss["node"].offset = Vector2(0, -tex[btex].get_height() * 0.5)
		# A dedicated boss sprite is already drawn big, so no extra 2x; just keep the stage scale
		boss["base_scale"] = Vector2.ONE * UNIT_PX
	boss["node"].scale = boss["base_scale"]
	boss["kb"] = bd["kb"]
	boss["kb_mark"] = boss["max_hp"] * (bd["kb"] - 1) / bd["kb"]
	boss["boss"] = true
	# Trait flags copied from the boss data (used by _tick and _kill)
	boss["boss_key"] = stage_data["boss"]
	boss["splits_into"] = bd.get("splits_into", [])
	boss["berserk"] = bd.get("berserk", false)
	boss["berserked"] = false
	boss["swoop"] = bd.get("swoop", false)
	boss["swoop_t"] = 10.0 if boss["swoop"] else 0.0
	# 서유기 1장 메카닉 (2026-10-10): 호선봉(stun_roar), 백골정(multi_form), 흑웅정(charge→bear_charge), 사오정(wave_push)
	boss["stun_roar"] = bd.get("stun_roar", false)
	if boss["stun_roar"]:
		_stun_roar_t = 10.0
	boss["multi_form"] = bd.get("multi_form", false)
	if boss["multi_form"]:
		boss["form_stage"] = 0
	boss["bear_charge"] = bd.get("charge", false)
	if boss["bear_charge"]:
		boss["charge_t"] = 10.0
	boss["wave_push"] = bd.get("wave_push", false)
	if boss["wave_push"]:
		_wave_push_t = 5.0
	if boss["swoop"]:
		# 밤의 눈: hover above the ground (flying). The base atk range is small, so a swoop acts as its reach
		boss["flying"] = true
		boss["node"].position.y = GROUND - FLY_H - 10.0
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
	# Melee can't reach flyers: soldiers vs bats, monsters vs the 용기사
	var melee: bool = u["shot"] == ""
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

# Melee units can neither hit nor be blocked by flyers
func _nearest_opponent(u: Dictionary):
	var best = null
	var x: float = u["node"].position.x
	var melee: bool = u["shot"] == ""
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
	# 음유시인's cheer, 도적's critical hits, 기마 기사's first charge
	if u["buff_t"] > 0.0:
		dmg *= 1.0 + u["buff"]
	if u.get("crit", 0.0) > 0.0 and rng.randf() < u["crit"]:
		dmg *= 2.0
	if u.get("charge", 0.0) > 0.0:
		dmg *= u["charge"]
		u["charge"] = 0.0
		_fx_once("ring", _mid(target) if not target is String else Vector2(FORT_X, GROUND - 40), 0.3)
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
	if SHOT_TINT.has(u["shot"]):
		sp.modulate = SHOT_TINT[u["shot"]]
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
	if attacker.get("slow", 0.0) > 0.0:
		target["slow_t"] = attacker["slow"]
	if attacker["shot"] == "":
		_slash(target, attacker["side"])
		_sfx("b_hit", -12.0)
	if attacker.get("splash", 0.0) > 0.0:
		_fx_once("boom_s", _mid(target), 0.18)
		for o in units.duplicate():
			if o != target and o["side"] == target["side"] and absf(o["node"].position.x - target["node"].position.x) <= attacker["splash"]:
				_hurt(o, _damage(attacker, o) * 0.6, attacker["side"] == 1)

func _hurt(u: Dictionary, dmg: float, by_ally: bool) -> void:
	# 삼장 "염불 결계" buff_guard: 아군이 받는 피해 ½ (버프 지속 중만)
	if u["side"] == 1 and u.get("buff_t", 0.0) > 0.0 and u.get("buff_guard", 0.0) > 0.0:
		dmg *= (1.0 - u["buff_guard"])
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

# Slow and cheer timers (with their tints), and the bard's song every HEAL_EVERY seconds
func _tick_effects(u: Dictionary, delta: float) -> void:
	var node: Sprite2D = u["node"]
	if u["slow_t"] > 0.0:
		u["slow_t"] -= delta
		node.self_modulate = SLOWED_TINT if u["slow_t"] > 0.0 else Color.WHITE
	elif u["buff_t"] > 0.0:
		u["buff_t"] -= delta
		node.self_modulate = CHEERED_TINT if u["buff_t"] > 0.0 else Color.WHITE
	if u["aura"] > 0.0:
		u["aura_t"] -= delta
		if u["aura_t"] <= 0.0:
			u["aura_t"] = HEAL_EVERY
			_cheer_around(u)

func _speed(u: Dictionary) -> float:
	return u["speed"] * (SLOW_K if u["slow_t"] > 0.0 else 1.0)

# Boss trait tick (2026-10-09): goblin chief berserks past half HP, night-eye bat swoops on a timer
func _tick_boss(u: Dictionary, delta: float) -> void:
	if u.get("berserk", false) and not u["berserked"] and u["hp"] <= u["max_hp"] * 0.5:
		u["berserked"] = true
		u["every"] = maxf(0.3, u["every"] / 1.5)
		u["node"].self_modulate = Color(1.6, 0.55, 0.55)
		_fx_once("ring", _mid(u), 0.4, 1.6)
		_banner("고블린 두목이 광폭화!", "", Color(1.0, 0.3, 0.3))
		_shake_lane(5.0, 0.2)
	if u.get("swoop", false):
		u["swoop_t"] -= delta
		if u["swoop_t"] <= 0.0:
			u["swoop_t"] = 10.0
			_boss_swoop(u)
	# 서유기 1장 신규 메카닉 (2026-10-10)
	if u.get("stun_roar", false):
		_stun_roar_t -= delta
		if _stun_roar_t <= 0.0:
			_stun_roar_t = 10.0
			_boss_stun_roar(u)
	if u.get("multi_form", false):
		_boss_multi_form(u, delta)
	if u.get("bear_charge", false):
		_boss_charge_tick(u, delta)
	if u.get("wave_push", false):
		_boss_wave_push_tick(u, delta)

# =========================================================
# 서유기 1장 신규 보스 메카닉 (docs/JOURNEY_WEST_PLAN.md + HERO_SYSTEM_PLAN.md)
# =========================================================

# 호선봉 — 포효 2초 전체 아군 스턴 (쿨 10초)
func _boss_stun_roar(u: Dictionary) -> void:
	_sfx("b_roar", -4.0)
	_banner("호선봉이 포효한다!", "", Color(1.0, 0.8, 0.3))
	_shake_lane(6.0, 0.3)
	_fx_once("ring", _mid(u), 0.5, 3.0)
	for o in units:
		if o["side"] == 1:
			o["stun"] = maxf(o["stun"], 2.0)
			o["node"].self_modulate = Color(1.4, 1.4, 0.6)
			# 시각적 스턴: 노란 번쩍 → 복원은 _tick_effects 처리
	_hitstop = maxf(_hitstop, 0.08)

# 백골정 — HP 70%/40% 변신. 1→2단: 근접→원거리 (shot=orb, 사거리↑). 2→3단: 공속↑, 공격력↑ (분신 효과).
func _boss_multi_form(u: Dictionary, delta: float) -> void:
	var stage_now: int = int(u.get("form_stage", 0))
	var r: float = u["hp"] / u["max_hp"]
	if stage_now == 0 and r <= 0.7:
		u["form_stage"] = 1
		u["shot"] = "orb"
		u["range"] = 120.0
		u["splash"] = 40.0
		u["atk"] *= 1.1
		u["node"].self_modulate = Color(0.9, 0.7, 1.1)
		_fx_once("ring", _mid(u), 0.5, 2.5)
		_banner("백골정 변신!", "원거리로 바뀌었어요", Color(1.0, 0.85, 1.0))
	elif stage_now == 1 and r <= 0.4:
		u["form_stage"] = 2
		u["every"] = maxf(0.4, u["every"] * 0.6)
		u["atk"] *= 1.3
		u["speed"] *= 1.4
		u["node"].self_modulate = Color(1.3, 0.6, 0.9)
		_fx_once("ring", _mid(u), 0.5, 2.5)
		_banner("백골정 분신!", "더 빠르고 강해졌어요", Color(1.0, 0.5, 0.85))

# 흑웅정 — HP 50% 이하일 때 10초마다 전장 돌파, 통과한 아군에 100 피해 + 넉백 60px, 끝에 원위치.
func _boss_charge_tick(u: Dictionary, delta: float) -> void:
	if u["hp"] > u["max_hp"] * 0.5:
		return
	u["charge_t"] = u.get("charge_t", 10.0) - delta
	if u["charge_t"] <= 0.0:
		u["charge_t"] = 10.0
		_boss_charge_run(u)

func _boss_charge_run(u: Dictionary) -> void:
	var node: Sprite2D = u["node"]
	var start_pos: Vector2 = node.position
	_sfx("b_roar", -6.0)
	_banner("흑웅정 돌진!", "", Color(1.0, 0.6, 0.4))
	var tw := node.create_tween()
	tw.tween_property(node, "position:x", ALLY_BASE_X - 10.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _charge_impact(u))
	tw.tween_property(node, "position", start_pos, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _charge_impact(u: Dictionary) -> void:
	_shake_lane(8.0, 0.3)
	for o in units.duplicate():
		if o["side"] != 1 or o["hp"] <= 0.0:
			continue
		_hurt(o, 100.0, false)
		_knock(o, 60.0)

# 사오정 (보스) — 5초마다 전장 전체 아군 30px 뒤로 밀기, 파란 파도 FX
func _boss_wave_push_tick(u: Dictionary, delta: float) -> void:
	_wave_push_t -= delta
	if _wave_push_t > 0.0:
		return
	_wave_push_t = 5.0
	_sfx("b_summon", -8.0)
	_banner("사오정 물결!", "", Color(0.5, 0.85, 1.0))
	_fx_once("ring", Vector2(360, GROUND - 30), 0.6, 4.0)
	for o in units:
		if o["side"] == 1:
			_knock(o, 30.0)

# =========================================================
# 영웅 (삼장·손오공·저팔계·사오정) — 자동 소환, 전용 HP 바, 액티브 스킬, 영구 사망
# =========================================================

func _spawn_hero() -> void:
	if hero_id == "" or not HEROES.has(hero_id):
		return
	var h: Dictionary = HEROES[hero_id]
	var hero_info: Dictionary = LaneUnits.HEROES.get(hero_id, {})
	var tex_name: String = hero_info.get("tex", "hero_sanzang")
	var node := Sprite2D.new()
	node.texture = tex.get(tex_name, tex["knight"])
	# 영웅 크기 = 쫄몹 렌더 높이 × 1.5 (스프라이트 원본이 영웅마다 달라 동적 계산)
	# 쫄몹 평균 원본 h ≈ 37px, UNIT_PX=1.4 → 쫄몹 렌더 h ≈ 52px, 영웅 목표 ≈ 78px
	var tex_h: float = maxf(1.0, float(node.texture.get_height()))
	var hero_scale: float = 78.0 / tex_h
	node.scale = Vector2.ONE * hero_scale
	node.offset = Vector2(0, -node.texture.get_height() * 0.5)
	# 영웅은 성 문 앞(성 오른쪽 가장자리 지면)에 자연스럽게 서서 캐스팅. 성 위로 보이게 z=5.
	node.position = Vector2(CASTLE_X + 44.0, GROUND)
	node.z_index = 5
	_units_layer.add_child(node)
	var hp: float = h["hp"]
	var u := {"node": node, "side": 1, "kind": hero_id, "hp": hp, "max_hp": hp, "atk": 0.0,
		"range": 0.0, "shot": "", "splash": 0.0,
		"speed": 0.0, "every": 999.0, "cd": 999.0, "phase": rng.randf() * TAU,
		"kb": 9999.0, "kb_mark": -1.0, "stun": 0.0,
		"stand": 0.0,
		"flying": false, "armor": false, "guard": 0.3,  # 영웅은 받는 피해 30% 감소
		"heal": 0.0, "heal_r": 0.0, "heal_t": HEAL_EVERY,
		"aura": 0.0, "aura_r": 0.0, "aura_t": HEAL_EVERY * 0.5,
		"slow_t": 0.0, "buff_t": 0.0, "buff": 0.0,
		"base_scale": Vector2.ONE * hero_scale,
		"hero": true, "hero_id": hero_id, "role": "caster", "anchor_x": CASTLE_X + 44.0}
	u["bar"] = _unit_bar(node)
	units.append(u)
	hero_unit = u
	node.modulate.a = 0.0
	node.create_tween().tween_property(node, "modulate:a", 1.0, 0.25)
	hero_cool = 0.0

# 영웅 HP 바 + 스킬 버튼 갱신 (화면 좌상단 · 우하단)
func _refresh_hero_ui() -> void:
	if _hero_portrait == null:
		return
	var active: bool = hero_id != "" and HEROES.has(hero_id)
	# 영웅 좌상단 HP 패널은 사용자 요청으로 영구 숨김 (2026-10-10)
	_hero_portrait.visible = false
	_hero_hp_fill.get_parent().get_parent().visible = false  # HeroBox 숨김
	# 2026-10-11 전투만 모드: 레인 안의 스킬 버튼·이름 양피지를 하단 패널로 옮겼으므로 모두 숨김.
	var bo_hide: bool = battle_only_mode
	_hero_skill_btn.visible = active and not bo_hide
	if _hero_skill_name_bg != null:
		_hero_skill_name_bg.visible = active and not bo_hide
		_hero_skill_name_label.visible = active and not bo_hide
	if not active:
		return
	var info: Dictionary = LaneUnits.HEROES.get(hero_id, {})
	_hero_name_label.text = info.get("name", "")
	var tex_name: String = info.get("tex", "")
	if tex.has(tex_name):
		_hero_portrait.texture = tex[tex_name]
		# 스킬 버튼 안에 영웅 얼굴 미니 아이콘
		if _hero_skill_icon != null:
			_hero_skill_icon.texture = tex[tex_name]
	# 스킬 이름 양피지 라벨
	_hero_skill_name_label.text = HEROES[hero_id].get("skill_name", "스킬")
	# HP 바
	var alive: bool = not hero_dead and hero_unit.has("hp") and hero_unit["hp"] > 0.0
	var hp_bar_w: float = 106.0
	if alive:
		var r: float = clampf(hero_unit["hp"] / hero_unit["max_hp"], 0.0, 1.0)
		_hero_hp_fill.size.x = hp_bar_w * r
		_hero_hp_fill.add_theme_stylebox_override("panel", UIKit.box(_hp_color(r), Color.TRANSPARENT, 8))
		_hero_hp_label.text = "%d / %d" % [maxi(0, roundi(hero_unit["hp"])), roundi(hero_unit["max_hp"])]
		_hero_dead_x.visible = false
		_hero_portrait.modulate = Color.WHITE
	else:
		_hero_hp_fill.size.x = 0.0
		_hero_hp_label.text = "쓰러짐"
		_hero_dead_x.visible = true
		_hero_portrait.modulate = Color(0.4, 0.4, 0.4, 1)
	# 스킬 버튼: 쿨 중엔 숫자만, 쿨 아님엔 아이콘만. 호흡 애니.
	var ready: bool = alive and hero_cool <= 0.0
	_hero_skill_btn.disabled = not ready
	if ready:
		_hero_skill_icon.visible = true
		_hero_skill_fill.size.y = 0.0
		if _hero_skill_ready_pulse > 0.0:
			_hero_skill_label.text = "준비!"
			_hero_skill_label.visible = true
		else:
			_hero_skill_label.text = ""
			_hero_skill_label.visible = false
	else:
		_hero_skill_icon.visible = false
		var left: float = hero_cool
		_hero_skill_label.text = "%d" % ceili(left)
		_hero_skill_label.visible = true
		var cool_total: float = HEROES[hero_id]["cool"]
		var veil_h: float = 96.0 * clampf(left / cool_total, 0.0, 1.0)
		_hero_skill_fill.size = Vector2(96, veil_h)
		_hero_skill_fill.position = Vector2(0, 96.0 - veil_h)

func activate_hero_skill() -> bool:
	if hero_dead or hero_cool > 0.0 or hero_id == "" or not HEROES.has(hero_id):
		return false
	if not hero_unit.has("hp") or hero_unit["hp"] <= 0.0:
		return false
	var skill: String = HEROES[hero_id]["skill"]
	hero_cool = HEROES[hero_id]["cool"]
	_hero_skill_ready_pulse = 0.0
	_sfx("b_summon", -2.0)
	# 버튼 scale punch
	if _hero_skill_btn != null:
		_hero_skill_btn.pivot_offset = _hero_skill_btn.size * 0.5
		_hero_skill_btn.scale = Vector2(1.18, 1.18)
		_hero_skill_btn.create_tween().tween_property(_hero_skill_btn, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	match skill:
		"aura_buff":  _skill_aura_buff()
		"line_sweep": _skill_line_sweep()
		"cone_dash":  _skill_cone_dash()
		"heal_wave":  _skill_heal_wave()
	_refresh_hero_ui()
	return true

# 삼장 "염불 결계" — 아군 전원 4초간 받는 피해 ×0.5 (buff_guard), 공격력 ×1.3
func _skill_aura_buff() -> void:
	_banner("염불 결계", "4초간 아군 보호", Color(1.0, 0.85, 0.4))
	_fx_once("ring", _mid(hero_unit), 0.6, 3.5)
	for o in units:
		if o["side"] != 1:
			continue
		o["buff_t"] = 4.0
		o["buff"] = 0.3
		o["buff_guard"] = 0.5  # 받는 피해 × (1 - 0.5) = ½
		o["node"].self_modulate = Color(1.3, 1.2, 0.7)

# 손오공 "여의봉 광풍" — 전장 가로 전체 적에게 100 피해 + 큰 넉백 (80px)
func _skill_line_sweep() -> void:
	_banner("여의봉 광풍!", "", Color(1.0, 0.7, 0.3))
	_shake_lane(10.0, 0.4)
	_hitstop = maxf(_hitstop, 0.1)
	for o in units.duplicate():
		if o["side"] != -1 or o["hp"] <= 0.0:
			continue
		var x: float = o["node"].position.x
		if x >= 180.0 and x <= ENEMY_BASE_X:
			_hurt(o, 100.0, true)
			if o["hp"] > 0.0:
				_knock(o, 80.0)
			_fx_once("slash", _mid(o), 0.25, 1.5)

# 저팔계 "환영 쇄기 돌진" — 적이 가장 몰린 지점에 환영을 투사해 180px 범위 150 피해 + 넉백 + 2초 스턴
# 영웅 위치와 무관. 전장에 적이 없으면 전장 가운데에 터트림
func _skill_cone_dash() -> void:
	_banner("쇄기 돌진!", "", Color(1.0, 0.6, 0.3))
	# 적 밀집 지점 찾기: 각 적을 중심으로 180px 창에 들어오는 적 수 최대인 x 선택
	var enemies: Array = []
	for o in units:
		if o["side"] == -1 and o["hp"] > 0.0:
			enemies.append(o)
	var center_x: float = 360.0  # 적이 없으면 전장 가운데
	if not enemies.is_empty():
		var best_cnt: int = -1
		var best_x: float = enemies[0]["node"].position.x
		for a in enemies:
			var ax: float = a["node"].position.x
			var cnt: int = 0
			for b in enemies:
				if absf(b["node"].position.x - ax) <= 90.0:
					cnt += 1
			if cnt > best_cnt:
				best_cnt = cnt
				best_x = ax
		center_x = best_x
	_fx_once("boom_l", Vector2(center_x, GROUND - 30), 0.3, 1.6)
	_shake_lane(7.0, 0.25)
	for o in units.duplicate():
		if o["side"] != -1 or o["hp"] <= 0.0:
			continue
		var d: float = absf(o["node"].position.x - center_x)
		if d <= 90.0:
			_hurt(o, 150.0, true)
			if o["hp"] > 0.0:
				o["stun"] = maxf(o["stun"], 2.0)
				_knock(o, 50.0)

# 사오정 "수룡 재생" — 자신 70% 회복 + 아군 전원 30% 회복
func _skill_heal_wave() -> void:
	_banner("수룡 재생!", "아군을 치유", Color(0.5, 1.0, 0.6))
	_fx_once("ring", _mid(hero_unit) if hero_unit.has("node") else Vector2(100, GROUND - 40), 0.6, 3.0)
	if hero_unit.has("hp") and hero_unit["hp"] > 0.0:
		var gain: float = hero_unit["max_hp"] * 0.7
		hero_unit["hp"] = minf(hero_unit["max_hp"], hero_unit["hp"] + gain)
		_number(_head(hero_unit), gain, Color(0.5, 1.0, 0.55), "+")
	for o in units:
		if o["side"] != 1 or o == hero_unit or o["hp"] <= 0.0:
			continue
		var g: float = o["max_hp"] * 0.3
		o["hp"] = minf(o["max_hp"], o["hp"] + g)
		_fx_once("heal", _head(o) + Vector2(0, 4), 0.5, 1.0, Vector2(0, -16))

# 영웅이 사망했을 때 처리: 배너 + 포털 X + hero_dead = true. _kill에서 호출.
func _on_hero_death() -> void:
	if hero_dead:
		return
	hero_dead = true
	var info: Dictionary = LaneUnits.HEROES.get(hero_id, {})
	var nm: String = info.get("name", "영웅")
	_banner("%s이 쓰러졌다!" % nm, "", Color(1.0, 0.3, 0.3))
	_shake_lane(10.0, 0.5)
	_hitstop = maxf(_hitstop, 0.15)
	_refresh_hero_ui()

# 밤의 눈 급강하: dive at the nearest soldier (or the castle), big damage + knockback, then climb back
func _boss_swoop(u: Dictionary) -> void:
	var node: Sprite2D = u["node"]
	var ground_y: float = GROUND - 10.0
	var hover_y: float = GROUND - FLY_H - 10.0
	var target_x: float = CASTLE_X + 40.0
	var target_u = _nearest_opponent(u)
	if target_u != null:
		target_x = target_u["node"].position.x
	var start: Vector2 = node.position
	var land: Vector2 = Vector2(clampf(target_x, ALLY_BASE_X - 20.0, ENEMY_START), ground_y)
	_sfx("b_roar", -8.0)
	var tw := node.create_tween()
	tw.tween_property(node, "position", land, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _swoop_impact(u, land))
	tw.tween_property(node, "position", Vector2(start.x, hover_y), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _swoop_impact(u: Dictionary, at: Vector2) -> void:
	_shake_lane(8.0, 0.3)
	_hitstop = maxf(_hitstop, 0.08)
	_fx_once("boom_l", at, 0.3, 1.4)
	_fx_once("ring", at, 0.4, 2.2)
	var dmg: float = u["atk"] * 2.0
	for o in units.duplicate():
		if o["side"] == u["side"] or o["hp"] <= 0.0:
			continue
		if absf(o["node"].position.x - at.x) <= 80.0:
			_hurt(o, dmg, false)
			_knock(o, KB_DIST * 1.8)
	if at.x <= ALLY_BASE_X + 40.0:
		castle_hp = maxi(0, castle_hp - roundi(dmg * 0.6))
		_flash(_castle_sprite)
		castle_hit.emit(roundi(dmg))
	_dirty = true

# Boss intro overlay: dim the lane, drop the boss art in big with a parchment name + hint, then
# fade out after a short pause (also auto-dismissed by a tap)
func _show_boss_intro() -> void:
	var bd: Dictionary = LaneStages.BOSSES[stage_data["boss"]]
	var btex: String = bd.get("tex", "")
	if btex == "" or not tex.has(btex):
		return
	var overlay := Control.new()
	overlay.name = "BossIntro"
	overlay.size = Vector2(720, LANE_H)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 50
	# 반투명 블랙은 전체를 덮되 중앙 카드만 또렷하게 — 전투 UI(상단 HP·메뉴 pill)는 카드 바깥에 있어도 가려지지 않도록 어둡기만 50%.
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.0)
	dim.size = overlay.size
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	# 중앙 카드 500×360 (화면 가득이 아니라 중앙 카드만 차지)
	var card_size := Vector2(500, 360)
	var card_pos := Vector2((720 - card_size.x) * 0.5, (LANE_H - card_size.y) * 0.5)
	var card := Panel.new()
	LaneUI.dress(card, "panel_paper")
	card.position = card_pos
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.modulate.a = 0.0
	overlay.add_child(card)
	var shot := Sprite2D.new()
	shot.texture = tex[btex]
	shot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shot.scale = Vector2.ONE * 2.5
	shot.position = card_pos + Vector2(card_size.x * 0.5, 150)
	shot.modulate.a = 0.0
	overlay.add_child(shot)
	var ribbon := LaneUI.ribbon(bd["name"], 300, 34)
	ribbon.position = card_pos + Vector2((card_size.x - 300) * 0.5, 240)
	overlay.add_child(ribbon)
	var hint_pos := card_pos + Vector2(20, 290)
	var hint_size := Vector2(card_size.x - 40, 46)
	var hint := LaneUI.label(bd.get("hint", ""), 18, LaneUI.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	hint.position = hint_pos
	hint.size = hint_size
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	overlay.add_child(hint)
	_view.add_child(overlay)
	# Intro overlay does NOT pause the battle so headless tests and the real-time flow keep ticking.
	# 중앙 카드로만 보여줘 전투 화면 전체를 덮지 않는다.
	var tw := overlay.create_tween()
	tw.tween_property(dim, "color:a", 0.5, 0.3)
	tw.parallel().tween_property(card, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(shot, "modulate:a", 1.0, 0.35)
	tw.parallel().tween_property(shot, "position:y", shot.position.y, 0.35).from(shot.position.y - 40.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var close := func():
		if not is_instance_valid(overlay):
			return
		var ot := overlay.create_tween()
		ot.tween_property(overlay, "modulate:a", 0.0, 0.3)
		ot.tween_callback(overlay.queue_free)
	overlay.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close.call())
	get_tree().create_timer(2.2).timeout.connect(close)

func _cheer_around(u: Dictionary) -> void:
	var any := false
	for o in units:
		if o["side"] != u["side"] or o == u or o["hp"] <= 0.0:
			continue
		if absf(o["node"].position.x - u["node"].position.x) > u["aura_r"]:
			continue
		o["buff_t"] = HEAL_EVERY + 0.5
		o["buff"] = maxf(o["buff"], u["aura"])
		any = true
	if any:
		_fx_once("ring", _mid(u), 0.35)

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
	rally_done = 0
	elapsed = 0.0
	wave_index = 0
	var waves: Array = stage_data["waves"]
	next_wave_at = waves[0][0] if not waves.is_empty() else INF
	trickle_timer = 6.0
	warned = false
	_stage_label.text = "STAGE %d" % stage
	_stage_name.text = stage_data["name"]
	# 2026-10-09: per-stage background (bg name in stage data, fallback to the generic lane picture)
	_apply_background(stage_data.get("bg", "lane"))
	_bg.self_modulate = LaneStages.chapter(stage)["tint"]
	_boss_timer = 0.0
	_splits_pending.clear()
	# Boss intro overlay before the fight starts (fade-in boss shot + name + hint, then tap to start)
	if stage_data.get("boss", "") != "":
		_show_boss_intro()
	_banner("STAGE %d · %s" % [stage, stage_data["name"]], stage_data.get("new", ""))
	_spawn_enemy(_pick_enemy(), power)
	_refresh()

# Swap the lane picture for a per-stage background. Keeps the same ground line by anchoring the
# picture's bottom to the fortress feet (as the default lane does)
func _apply_background(name: String) -> void:
	var t: Texture2D = tex.get(name)
	if t == null:
		t = tex["lane"]
	_bg.texture = t
	var k: float = ceil(maxf(720.0 / t.get_width(), LANE_H / t.get_height()))
	_bg.size = Vector2(t.get_width(), t.get_height()) * k
	_bg.position = Vector2((720.0 - _bg.size.x) * 0.5, LANE_H - _bg.size.y + 4.0)
	if _sky != null:
		_sky.color = t.get_image().get_pixel(t.get_width() / 2, 0)
		_sky.size.y = _bg.position.y + 44.0

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
		"aura": st.get("aura", 0.0), "aura_r": st.get("aura_r", 0.0), "aura_t": HEAL_EVERY * 0.5,
		"slow_t": 0.0, "buff_t": 0.0, "buff": 0.0, "buff_guard": 0.0,
		"base_scale": Vector2.ONE * UNIT_PX}
	for key in ["air", "armor_break", "siege", "crit", "charge", "slow"]:
		if st.has(key):
			u[key] = st[key]
	u["bar"] = _unit_bar(node)
	for mark in ["armor", "flying"]:
		if u[mark] and side == -1:
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

# 왕슬라임 분열: spawn each queued mini-mob at 60% HP, with a little pop
func _spawn_splits() -> void:
	for entry in _splits_pending:
		var kind: String = entry[0]
		var pos: Vector2 = entry[1]
		if _count(-1) >= MAX_ENEMIES:
			continue
		var m := _spawn(kind, -1, power * 0.6)
		m["node"].position.x = clampf(pos.x, ALLY_BASE_X + 20.0, ENEMY_START)
		m["node"].scale = m["base_scale"] * 1.2
		m["base_scale"] = m["node"].scale
		_fx_once("ring", m["node"].position + Vector2(0, -6), 0.3, 1.0)
	_splits_pending.clear()

# Fallen units fly back with a spin, a dust puff and a burst of pixels
func _kill(u: Dictionary) -> void:
	# 영웅 사망: 영구 (스테이지 끝까지 재소환 안 됨). 보통 유닛 사망 애니는 그대로 돌림.
	if u.get("hero", false):
		_on_hero_death()
	# Boss death triggers (2026-10-09): the king slime splits into mini-slimes with 60% HP each
	if u.get("boss", false) and (u.get("splits_into") as Array).size() > 0:
		var spawn_pos: Vector2 = u["node"].position
		var kinds: Array = u["splits_into"]
		for i in range(kinds.size()):
			var k: String = kinds[i]
			var offset: float = (i - (kinds.size() - 1) * 0.5) * 24.0
			_splits_pending.append([k, spawn_pos + Vector2(offset, 0)])
		get_tree().create_timer(0.25).timeout.connect(_spawn_splits)
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
	# The lane is taller than the picture: the sky colour fills the strip above it
	var sky := ColorRect.new()
	sky.color = lane_tex.get_image().get_pixel(lane_tex.get_width() / 2, 0)
	sky.position = Vector2(-40, -40)
	sky.size = Vector2(800, bg.position.y + 44.0)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky = sky
	_shake.add_child(sky)
	_shake.add_child(bg)
	for side in [1, -1]:
		var t: Texture2D = tex["castle" if side == 1 else "fortress"]
		var b := Sprite2D.new()
		b.texture = t
		b.scale = Vector2.ONE * STRUCT_PX
		b.centered = false
		b.position = Vector2(CASTLE_LEFT if side == 1 else FORT_RIGHT - t.get_width() * STRUCT_PX, GROUND + 4.0 - t.get_height() * STRUCT_PX)
		_shake.add_child(b)
		if side == 1:
			_castle_sprite = b
		else:
			_fort_sprite = b
	# The cannon stands on the castle's right tower (its top is 53 art pixels below the castle top)
	_cannon_sprite = Sprite2D.new()
	_cannon_sprite.texture = tex["cannon"]
	_cannon_sprite.scale = Vector2.ONE * STRUCT_PX
	_cannon_sprite.centered = false
	_cannon_sprite.position = Vector2(_castle_sprite.position.x + (56.0 - tex["cannon"].get_width() * 0.35) * STRUCT_PX, _castle_sprite.position.y + (53.0 - tex["cannon"].get_height()) * STRUCT_PX)
	_shake.add_child(_cannon_sprite)
	_units_layer = Node2D.new()
	_units_layer.y_sort_enabled = true
	_shake.add_child(_units_layer)
	_fx_layer = Node2D.new()
	_shake.add_child(_fx_layer)
	_bars_layer = Node2D.new()
	_shake.add_child(_bars_layer)
	# 2026-10-11 UI fix: ribbon narrower (150) + shifted right so it does not touch the gold pill
	# (gold ends at x=448, ribbon starts at x=460). Parchment subline sits directly under the ribbon
	# at y=68 — the ribbon's visible content ends at y≈60, so a 20px gap keeps the stage name legible.
	var rib := LaneUI.ribbon("", 150, 22)
	rib.name = "StageRibbon"
	rib.position = Vector2(460, 2)
	_view.add_child(rib)
	_stage_label = rib.get_child(0)
	var sub := Panel.new()
	LaneUI.dress(sub, "panel_paper")
	sub.name = "StageSub"
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.position = Vector2(465, 68)
	sub.size = Vector2(140, 22)
	_view.add_child(sub)
	_stage_name = LaneUI.label("", 13, LaneUI.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_stage_name.position = Vector2(465, 68)
	_stage_name.size = Vector2(140, 22)
	_stage_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_view.add_child(_stage_name)
	# HP bars on the ground in front of each building: wider, stone frame, big outlined number
	var cb := _bar(_view, Vector2(4, LANE_H - 32), Vector2(BASE_BAR_W + 36, 26))
	_castle_fill = cb.get_child(0)
	_castle_label = _outlined("", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_castle_label.size = cb.size
	_castle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cb.add_child(_castle_label)
	var fb := _bar(_view, Vector2(720 - 4 - (BASE_BAR_W + 36), LANE_H - 32), Vector2(BASE_BAR_W + 36, 26))
	_fort_fill = fb.get_child(0)
	_fort_label = _outlined("", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_fort_label.size = fb.size
	_fort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fb.add_child(_fort_label)
	# Boss badge above the fortress HP bar, shown while the boss is on the lane
	var boss_badge := Panel.new()
	boss_badge.name = "BossBadge"
	boss_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_badge.position = fb.position + Vector2(fb.size.x - 54, -22)
	boss_badge.size = Vector2(52, 20)
	boss_badge.add_theme_stylebox_override("panel", UIKit.box(Color(0.9, 0.2, 0.22), Color(1.0, 0.95, 0.6), 7, 2))
	boss_badge.visible = false
	_view.add_child(boss_badge)
	var bl := _outlined("BOSS", 13, Color(1.0, 0.95, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	bl.size = boss_badge.size
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	boss_badge.add_child(bl)
	# 영웅 패널 (좌상단): 큰 초상 + 이름 + 두꺼운 HP 바.
	# 상단 메뉴 pill(y=6~54) 아래 16px 간격 → y=70부터 88px 세로 패널.
	var hero_box := Panel.new()
	LaneUI.dress(hero_box, "panel_wood")
	hero_box.name = "HeroBox"
	hero_box.position = Vector2(6, 70)
	hero_box.size = Vector2(200, 88)
	hero_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(hero_box)
	# 초상 프레임: 좌측 64×64 돌 테두리
	var portrait_frame := Panel.new()
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.position = Vector2(8, 12)
	portrait_frame.size = Vector2(64, 64)
	portrait_frame.add_theme_stylebox_override("panel", UIKit.box(Color(0.08, 0.06, 0.12, 0.95), Color(0.78, 0.62, 0.32, 1.0), 8, 2))
	hero_box.add_child(portrait_frame)
	_hero_portrait = TextureRect.new()
	_hero_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_portrait.position = Vector2(2, 2)
	_hero_portrait.size = Vector2(60, 60)
	_hero_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(_hero_portrait)
	_hero_dead_x = _outlined("✕", 44, Color(1.0, 0.3, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
	_hero_dead_x.position = Vector2(2, 2)
	_hero_dead_x.size = Vector2(60, 60)
	_hero_dead_x.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hero_dead_x.visible = false
	portrait_frame.add_child(_hero_dead_x)
	# 이름: 패널 우측 상단
	_hero_name_label = _outlined("", 20, Color(1.0, 0.95, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
	_hero_name_label.position = Vector2(80, 10)
	_hero_name_label.size = Vector2(112, 24)
	_hero_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_box.add_child(_hero_name_label)
	# HP 바: 패널 우측 하단, 큼직하게 (돌 테두리 트로프 + 녹색 fill + 중앙 숫자)
	var hpbg := Panel.new()
	hpbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hpbg.position = Vector2(80, 42)
	hpbg.size = Vector2(112, 32)
	hpbg.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.04, 0.08, 0.88), Color(0.78, 0.62, 0.32, 1.0), 10, 2))
	hero_box.add_child(hpbg)
	_hero_hp_fill = Panel.new()
	_hero_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_hp_fill.position = Vector2(3, 3)
	_hero_hp_fill.size = Vector2(106, 26)
	_hero_hp_fill.add_theme_stylebox_override("panel", UIKit.box(Color(0.35, 0.86, 0.43), Color.TRANSPARENT, 8))
	hpbg.add_child(_hero_hp_fill)
	_hero_hp_label = _outlined("", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_hero_hp_label.position = Vector2(0, 0)
	_hero_hp_label.size = Vector2(112, 32)
	_hero_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hpbg.add_child(_hero_hp_label)

	# 영웅 스킬 버튼 (우상단, 96×96).
	# 2026-10-10 UI fix: 전장 가림 방지 — 상단 메뉴 pill(y=6-54) 아래 16px → y=70.
	# 이전: Vector2(614, LANE_H - 144.0) = (614, 326), 전장(y≈430) 가림.
	# 좌상단 영웅 HP 패널은 숨겨져 있어 그 반대편(우상단)이 비어있음. 금화·STAGE 리본은 x≈540~720 범위라
	# y=70부터 시작하면 세로로 겹치지 않는다.
	_hero_skill_btn = Button.new()
	_hero_skill_btn.name = "HeroSkillBtn"
	# 2026-10-11 UI fix: shifted to (618, 76) — right edge 714 (6px margin from view width 720),
	# top below the stage ribbon's lower edge (ribbon y=2..~66) → y=76 keeps a 10px breathing gap.
	_hero_skill_btn.position = Vector2(618, 76)
	_hero_skill_btn.size = Vector2(96, 96)
	_hero_skill_btn.focus_mode = Control.FOCUS_NONE
	# 둥근 금테 패널 느낌의 스타일박스
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var fill := Color(0.14, 0.10, 0.22, 0.95) if st != "pressed" else Color(0.08, 0.06, 0.15, 0.95)
		var border := Color(1.00, 0.82, 0.36, 1.0) if st != "disabled" else Color(0.55, 0.48, 0.32, 1.0)
		_hero_skill_btn.add_theme_stylebox_override(st, UIKit.box(fill, border, 48, 3))
	_hero_skill_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_hero_skill_btn.pressed.connect(activate_hero_skill)
	_view.add_child(_hero_skill_btn)
	_hero_skill_btn.clip_contents = true
	# 스킬 아이콘 — 영웅 초상 미니 (2026-10-10). nearest filter + aspect centered.
	_hero_skill_icon = TextureRect.new()
	_hero_skill_icon.name = "SkillIcon"
	_hero_skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_skill_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero_skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_skill_icon.position = Vector2(14, 14)
	_hero_skill_icon.size = Vector2(68, 68)
	_hero_skill_btn.add_child(_hero_skill_icon)
	# 쿨 베일 (반투명, 아래→위로 줄어듦)
	_hero_skill_fill = ColorRect.new()
	_hero_skill_fill.color = Color(0.02, 0.03, 0.08, 0.68)
	_hero_skill_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_skill_fill.size = Vector2(96, 0)
	_hero_skill_fill.position = Vector2(0, 96)
	_hero_skill_btn.add_child(_hero_skill_fill)
	# 쿨 중 큰 숫자 (중앙, 28px)
	_hero_skill_label = _outlined("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_hero_skill_label.size = Vector2(96, 96)
	_hero_skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hero_skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_skill_btn.add_child(_hero_skill_label)
	# 버튼 아래 작은 양피지 라벨 (스킬 이름)
	var skill_name_bg := Panel.new()
	LaneUI.dress(skill_name_bg, "panel_paper")
	skill_name_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 2026-10-11 UI fix: 스킬 버튼 (618, 76, 96×96) 바로 아래 → y=76+96+4=176.
	# 가로는 폭 108로 줄여 x=608..716 (view=720, 4px 여백). 이전 (602, 170) size (120, 22)는 x 끝이 722로 화면 밖.
	skill_name_bg.position = Vector2(608, 176)
	skill_name_bg.size = Vector2(108, 22)
	_view.add_child(skill_name_bg)
	_hero_skill_name_label = LaneUI.label("", 14, LaneUI.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_hero_skill_name_label.position = skill_name_bg.position
	_hero_skill_name_label.size = skill_name_bg.size
	_hero_skill_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hero_skill_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_hero_skill_name_label)
	_hero_skill_name_bg = skill_name_bg

	# Top-left of the lane: home / settings / sound on a dark pill, then charge/hold and auto.
	# 2026-10-11 UI fix: 상단 한 줄 레이아웃을 모두 겹치지 않게 재배치.
	#   pill   (6..156)   |  march (164..250)  |  auto hidden (258..344)  |  gold (352..448)  |  ribbon (460..610)  |  skill btn (618..714)
	#   가로 간격 ≥ 8px, 세로는 ribbon(y=2-66) 아래로 skill btn(y=76)·sub(y=68) 배치.
	var pill := Panel.new()
	LaneUI.dress(pill, "panel_wood")
	pill.name = "MenuPill"
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
	_march_btn.name = "MarchBtn"
	_march_btn.position = Vector2(164, 8)
	_march_btn.size = Vector2(86, 44)
	_march_btn.focus_mode = Control.FOCUS_NONE
	_march_btn.pressed.connect(toggle_march)
	_view.add_child(_march_btn)
	# Auto always plays (user request 2026-10-08): the toggle stays for tests but is not shown.
	# 보이지 않더라도 혹시 보일 상황에 대비해 겹치지 않는 자리를 잡아둔다 (258..344).
	_auto_btn = Button.new()
	_auto_btn.name = "AutoBtn"
	_auto_btn.position = Vector2(258, 8)
	_auto_btn.size = Vector2(86, 44)
	_auto_btn.visible = false
	_auto_btn.pressed.connect(toggle_auto)
	_view.add_child(_auto_btn)
	# Gold from the puzzle, next to the menu, so clears still show where the soldiers come from
	var gold_pill := Panel.new()
	LaneUI.dress(gold_pill, "panel_wood")
	gold_pill.name = "GoldPill"
	gold_pill.position = Vector2(352, 6)
	gold_pill.size = Vector2(96, 48)
	gold_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(gold_pill)
	var coin := LaneUI.icon("icon_coin", Vector2(22, 22))
	coin.position = Vector2(10, 13)
	gold_pill.add_child(coin)
	_gold_label = _outlined("0", 22, UIKit.GOLD)
	_gold_label.position = Vector2(36, 6)
	_gold_label.size = Vector2(52, 36)
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_pill.add_child(_gold_label)
	# The old summon bar (deck buttons, income, cannon) is kept hidden: auto summons, buys income
	# and fires the cannon, and the tests still drive it by hand
	var bar := Panel.new()
	bar.visible = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(0, LANE_H)
	bar.size = Vector2(720, 100)
	LaneUI.dress(bar, "panel_wood")
	add_child(bar)
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
	# 2026-10-11 UI gate: print each top-of-battle widget's rect and check that no two overlap.
	# This runs once per battle build; any overlap pushes an error that shows in the editor log and
	# in the exported web console, so regressions are caught before capture.
	_log_top_ui_rects(pill, gold_pill)

func _log_top_ui_rects(pill: Panel, gold_pill: Panel) -> void:
	# Pull the three ribbon/subline/skill nodes we built above by node name so this helper does not
	# need five extra arguments.
	var ribbon: Control = _view.get_node_or_null("StageRibbon")
	var stage_sub: Control = _view.get_node_or_null("StageSub")
	var skill_bg: Control = _hero_skill_name_bg
	var items: Array = [
		{"name": "menu_pill",     "node": pill},
		{"name": "march_btn",     "node": _march_btn},
		{"name": "auto_btn",      "node": _auto_btn},
		{"name": "gold_pill",     "node": gold_pill},
		{"name": "stage_ribbon",  "node": ribbon},
		{"name": "stage_sub",     "node": stage_sub},
		{"name": "hero_skill",    "node": _hero_skill_btn},
		{"name": "skill_name_bg", "node": skill_bg},
	]
	for it in items:
		var n: Control = it["node"]
		if n == null:
			continue
		print("[UI] ", it["name"], ": pos=", n.position, " size=", n.size, " visible=", n.visible)
	for i in range(items.size()):
		var a_it: Dictionary = items[i]
		var a: Control = a_it["node"]
		if a == null or not a.visible:
			continue
		var ra := Rect2(a.position, a.size)
		for j in range(i + 1, items.size()):
			var b_it: Dictionary = items[j]
			var b: Control = b_it["node"]
			if b == null or not b.visible:
				continue
			var rb := Rect2(b.position, b.size)
			if ra.intersects(rb):
				push_error("[UI OVERLAP] %s %s vs %s %s" % [a_it["name"], ra, b_it["name"], rb])
	# Also guard: no widget may extend past the 720×LANE_H battle view.
	for it2 in items:
		var n2: Control = it2["node"]
		if n2 == null or not n2.visible:
			continue
		if n2.position.x < 0 or n2.position.y < 0 or n2.position.x + n2.size.x > 720.0:
			push_error("[UI OUT OF BOUNDS] %s pos=%s size=%s" % [it2["name"], n2.position, n2.size])

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
	# Stone trough: dark fill with a lighter outline so it reads as a frame on the lane
	bg.add_theme_stylebox_override("panel", UIKit.box(Color(0.05, 0.04, 0.08, 0.82), Color(0.75, 0.65, 0.4, 0.9), int(sz.y / 2), 2))
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

# HP bar colour: green when safe, yellow when hurt, red when about to fall. Enemy side stays red-ish
func _hp_color(r: float, enemy: bool = false) -> Color:
	if enemy:
		if r > 0.6:
			return Color(0.92, 0.32, 0.28)
		return Color(0.72, 0.14, 0.14) if r > 0.3 else Color(0.5, 0.08, 0.1)
	if r > 0.6:
		return Color(0.35, 0.86, 0.43)
	if r > 0.3:
		return Color(0.98, 0.78, 0.28)
	return Color(1.0, 0.4, 0.35)

func _refresh() -> void:
	var full_w: float = (BASE_BAR_W + 36) - 4.0
	var cr: float = float(castle_hp) / CASTLE_HP
	_castle_fill.size.x = full_w * cr
	_castle_fill.add_theme_stylebox_override("panel", UIKit.box(_hp_color(cr), Color.TRANSPARENT, 9))
	_castle_label.text = "%d / %d" % [castle_hp, CASTLE_HP]
	var fr: float = clampf(fortress_hp / fortress_max, 0.0, 1.0)
	_fort_fill.size.x = full_w * fr
	_fort_fill.add_theme_stylebox_override("panel", UIKit.box(_hp_color(fr, true), Color.TRANSPARENT, 9))
	_fort_label.text = "%d / %d" % [ceili(fortress_hp), ceili(fortress_max)]
	var badge: Panel = _view.get_node_or_null("BossBadge")
	if badge != null:
		badge.visible = boss_out and stage_data.get("boss", "") != "" and not finished
	_gold_label.text = str(gold)
	_wallet_label.text = "/%d" % wallet_max()
	if wallet < WALLET_COST.size():
		_income_btn.text = "지갑 확장  %d" % WALLET_COST[wallet]
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
	_rot_refresh()
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
	if battle_only_mode:
		_bo_tick(delta)

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
	# 상단 중앙 양피지 작은 배너 — 가로 전체를 덮지 않아 전투 UI(좌상단 영웅 HP) 가림 없음.
	var banner_size := Vector2(360, 60) if sub != "" else Vector2(300, 40)
	var paper := Panel.new()
	LaneUI.dress(paper, "panel_paper")
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.size = banner_size
	paper.position = Vector2((720 - banner_size.x) * 0.5, 96)
	paper.z_index = 10
	_view.add_child(paper)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.size = banner_size
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	paper.add_child(box)
	box.add_child(_outlined(title, 20, col, HORIZONTAL_ALIGNMENT_CENTER))
	if sub != "":
		box.add_child(_outlined(sub, 16, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	paper.scale = Vector2(1.0, 0.2)
	paper.pivot_offset = banner_size * 0.5
	var tw := paper.create_tween()
	tw.tween_property(paper, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(paper, "modulate:a", 0.0, 0.3)
	tw.tween_callback(paper.queue_free)

# =========================================================
# 전투 테스트 모드 (dev 전용, 2026-10-10)
# =========================================================

# 테스트 모드일 때만 하단 빈 영역(y=LANE_H ~ 1280)에 소환 버튼 패널을 켠다. 자동 소환 off.
# battle_only_mode: 덱의 4명만 가로 소환 바를 하단에 띄움 (자동 wave 유지, 금화·쿨 적용)
func _apply_test_mode() -> void:
	# 둘 다 꺼져 있으면 패널 전부 숨김
	if not test_mode and not battle_only_mode:
		if _test_panel != null:
			_test_panel.visible = false
		if _bo_panel != null:
			_bo_panel.visible = false
		_apply_bo_view(false)
		_apply_test_rotation(false)
		return
	if test_mode:
		auto_summon = false
		gold = wallet_max()
		for k in cooldown:
			cooldown[k] = 0.0
		hero_cool = 0.0
		if _test_panel == null:
			_build_test_panel()
		_test_panel.visible = true
		if _bo_panel != null:
			_bo_panel.visible = false
		_apply_bo_view(false)
		_apply_test_rotation(test_rotated)
	elif battle_only_mode:
		# 자동 소환 off (덱 4명을 눌러서 소환하는 재미), 자동 wave는 _waves()가 그대로 돈다
		auto_summon = false
		gold = BATTLE_ONLY_START_GOLD
		if _test_panel != null:
			_test_panel.visible = false
		# rotation(false)는 _view 자식을 전부 visible=true로 되돌리므로, bo_view 숨김은 그 뒤에.
		_apply_test_rotation(false)
		_apply_bo_view(true)
		if _bo_panel == null:
			_build_bo_panel()
		_bo_panel.visible = true
		_bo_refresh_slots()

# 2026-10-11 전투만 모드: 레인 _view를 세로로 680까지 늘려 전장을 넉넉하게 보여준다.
# LANE_H(=470) 아래의 여백은 바닥(흙색) ColorRect로 채워 자연스럽게 이어보이게 한다.
# 레인 안에 있던 상단 UI(pill·금화·리본·영웅박스·스킬 버튼 등)는 전부 숨긴다 — 하단 패널에 재배치했다.
const BO_HIDE_FROM_VIEW: Array[String] = [
	"MenuPill", "GoldPill", "StageRibbon", "StageSub", "HeroBox", "HeroSkillBtn",
	"MarchBtn", "AutoBtn", "BossBadge",
]

func _apply_bo_view(on: bool) -> void:
	if _view == null:
		return
	if on:
		_view.size = Vector2(720, BO_VIEW_H)
		if _bo_ground_fill == null:
			# 지면 연장용 — lane bg 바닥 색과 비슷한 흙빛. _view 바로 아래 두고 바닥을 채운다.
			# bg(ChildOf _shake)의 아래쪽 색이 어두운 흙이라 비슷한 톤으로.
			_bo_ground_fill = ColorRect.new()
			_bo_ground_fill.color = Color(0.26, 0.19, 0.14, 1.0)
			_bo_ground_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_bo_ground_fill.position = Vector2(0, LANE_H)
			_bo_ground_fill.size = Vector2(720, BO_VIEW_H - LANE_H)
			_view.add_child(_bo_ground_fill)
			_view.move_child(_bo_ground_fill, 0)  # 가장 뒤로 (shake 아래)
		_bo_ground_fill.visible = true
		for nm in BO_HIDE_FROM_VIEW:
			var n: Node = _view.get_node_or_null(nm)
			if n != null and n is CanvasItem:
				n.visible = false
			else:
				push_warning("[BO] can't hide %s (null=%s)" % [nm, n == null])
		# 스킬 이름 양피지도 숨김 (이름이 없어 조회)
		if _hero_skill_name_bg != null:
			_hero_skill_name_bg.visible = false
		if _hero_skill_name_label != null:
			_hero_skill_name_label.visible = false
		# 사이드 하단 HP 바(성·요새)는 레인 UI지만 LANE_H-32에 걸려 있어 유지한다.
		size = Vector2(720, 1280)
	else:
		_view.size = Vector2(720, LANE_H)
		if _bo_ground_fill != null:
			_bo_ground_fill.visible = false
		for nm in BO_HIDE_FROM_VIEW:
			var n: Node = _view.get_node_or_null(nm)
			if n != null and n is CanvasItem:
				n.visible = true
		if _hero_skill_name_bg != null:
			_hero_skill_name_bg.visible = true
		if _hero_skill_name_label != null:
			_hero_skill_name_label.visible = true
		size = Vector2(720, LANE_H + BAR_H)

# 2026-10-11: 세로 화면용 90° CCW 회전. 레인(_view)만 돌리고, 하단 소환 패널은 그대로 둔다.
# 전투 로직(x축 이동, CASTLE_LEFT 등)은 변경 없음.
var _rot_overlay: Control = null
var _rot_castle_fill: ColorRect = null
var _rot_castle_label: Label = null
var _rot_fort_fill: ColorRect = null
var _rot_fort_label: Label = null
var _rot_summon_panel: Control = null

func _apply_test_rotation(on: bool) -> void:
	if _view == null:
		return
	# 회전 중 숨길 _view 내부 UI 목록: 상단 pill·금화·STAGE 리본·영웅 패널·스킬 버튼 등
	var hide_names: Array = ["BossBadge", "HeroBox", "HeroSkillBtn"]
	if on:
		_view.pivot_offset = Vector2.ZERO
		_view.rotation = -PI * 0.5
		_view.scale = Vector2(1.53, 1.53)
		_view.position = Vector2(0, 1100)
		# _view의 자식 중 Panel/Button/Label(즉 UI 요소)은 모두 숨긴다. _shake(Node2D)는 레인 본체라 유지.
		for c in _view.get_children():
			if c == _shake:
				continue
			if c is Control:
				c.visible = false
		# 기본 테스트 패널(세로형 그리드)은 숨기고, 전용 가로 컴팩트 패널을 띄운다
		if _test_panel != null:
			_test_panel.visible = false
		if _rot_summon_panel == null:
			_build_rot_summon_panel()
		_rot_summon_panel.visible = true
		if _rot_overlay == null:
			_build_rot_overlay()
		_rot_overlay.visible = true
		_rot_refresh()
	else:
		_view.rotation = 0.0
		_view.scale = Vector2.ONE
		_view.position = Vector2.ZERO
		for c in _view.get_children():
			if c is Control:
				c.visible = true
		if _test_panel != null:
			_test_panel.visible = true
		if _rot_overlay != null:
			_rot_overlay.visible = false
		if _rot_summon_panel != null:
			_rot_summon_panel.visible = false

func _build_rot_overlay() -> void:
	_rot_overlay = Control.new()
	_rot_overlay.position = Vector2.ZERO
	_rot_overlay.size = Vector2(720, 64)
	_rot_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rot_overlay)
	# 상단: 요새(원래 RIGHT) HP + 성(원래 LEFT) HP + 홈 버튼
	# 요새 바 (위쪽 = 적)
	var fb_bg := Panel.new()
	fb_bg.position = Vector2(60, 6)
	fb_bg.size = Vector2(300, 24)
	fb_bg.add_theme_stylebox_override("panel", UIKit.box(Color(0.1, 0.07, 0.1, 0.9), Color(0.9, 0.3, 0.3), 8, 2))
	fb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rot_overlay.add_child(fb_bg)
	_rot_fort_fill = ColorRect.new()
	_rot_fort_fill.position = Vector2(3, 3)
	_rot_fort_fill.size = Vector2(294, 18)
	_rot_fort_fill.color = Color(0.9, 0.3, 0.3)
	fb_bg.add_child(_rot_fort_fill)
	_rot_fort_label = _outlined("요새", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_rot_fort_label.size = fb_bg.size
	_rot_fort_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fb_bg.add_child(_rot_fort_label)
	# 성 바 (아래쪽 = 아군)
	var cb_bg := Panel.new()
	cb_bg.position = Vector2(60, 34)
	cb_bg.size = Vector2(300, 24)
	cb_bg.add_theme_stylebox_override("panel", UIKit.box(Color(0.1, 0.1, 0.07, 0.9), Color(0.4, 0.7, 1.0), 8, 2))
	cb_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rot_overlay.add_child(cb_bg)
	_rot_castle_fill = ColorRect.new()
	_rot_castle_fill.position = Vector2(3, 3)
	_rot_castle_fill.size = Vector2(294, 18)
	_rot_castle_fill.color = Color(0.4, 0.7, 1.0)
	cb_bg.add_child(_rot_castle_fill)
	_rot_castle_label = _outlined("성", 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_rot_castle_label.size = cb_bg.size
	_rot_castle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cb_bg.add_child(_rot_castle_label)
	# 홈 버튼 (왼쪽)
	var home := Button.new()
	home.position = Vector2(6, 10)
	home.size = Vector2(48, 44)
	home.text = "←"
	home.focus_mode = Control.FOCUS_NONE
	LaneUI.button(home, "red", 20)
	home.pressed.connect(func(): home_pressed.emit())
	_rot_overlay.add_child(home)

func _build_rot_summon_panel() -> void:
	_rot_summon_panel = Control.new()
	_rot_summon_panel.position = Vector2(0, 1102)
	_rot_summon_panel.size = Vector2(720, 178)
	_rot_summon_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_rot_summon_panel)
	var bg := Panel.new()
	LaneUI.dress(bg, "panel_wood")
	bg.position = Vector2.ZERO
	bg.size = _rot_summon_panel.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rot_summon_panel.add_child(bg)
	# 아군 1줄: 16종, 셀 40×54 (아이콘 36 + 라벨 자리 짧게)
	var cell_w: float = 42.0
	var cell_h: float = 54.0
	var pad_x: float = (720.0 - cell_w * ALLY_ORDER.size()) * 0.5
	var ally_y: float = 8.0
	for i in range(ALLY_ORDER.size()):
		var kind: String = ALLY_ORDER[i]
		var b := _rot_kind_button(kind, true)
		b.position = Vector2(pad_x + i * cell_w, ally_y)
		b.size = Vector2(cell_w - 4, cell_h)
		_rot_summon_panel.add_child(b)
	# 적 1줄
	var enemy_kinds: Array = ENEMIES.keys()
	var pad_x2: float = (720.0 - cell_w * enemy_kinds.size()) * 0.5
	var enemy_y: float = ally_y + cell_h + 6.0
	for i in range(enemy_kinds.size()):
		var kind2: String = enemy_kinds[i]
		var b2 := _rot_kind_button(kind2, false)
		b2.position = Vector2(pad_x2 + i * cell_w, enemy_y)
		b2.size = Vector2(cell_w - 4, cell_h)
		_rot_summon_panel.add_child(b2)
	# 유틸 1줄
	var util_y: float = enemy_y + cell_h + 6.0
	var u1 := _test_util_button("아군 제거", func(): _test_clear_side(1))
	u1.position = Vector2(10, util_y); u1.size = Vector2(170, 42); _rot_summon_panel.add_child(u1)
	var u2 := _test_util_button("적 제거", func(): _test_clear_side(-1))
	u2.position = Vector2(188, util_y); u2.size = Vector2(170, 42); _rot_summon_panel.add_child(u2)
	var u3 := _test_util_button("체력 회복", func(): _test_full_heal())
	u3.position = Vector2(366, util_y); u3.size = Vector2(170, 42); _rot_summon_panel.add_child(u3)
	var u4 := _test_util_button("대포 충전", func(): cannon = 100.0; _refresh())
	u4.position = Vector2(544, util_y); u4.size = Vector2(170, 42); _rot_summon_panel.add_child(u4)

func _rot_kind_button(kind: String, ally: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tint: Color = Color(0.25, 0.5, 0.75) if ally else Color(0.65, 0.25, 0.3)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var kk: float = 1.0
		if st == "hover": kk = 1.15
		elif st == "pressed" or st == "hover_pressed": kk = 0.8
		b.add_theme_stylebox_override(st, UIKit.box(Color(tint.r * kk, tint.g * kk, tint.b * kk, 1.0), Color(0.95, 0.85, 0.4), 6, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(2, 2)
	icon.size = Vector2(34, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = tex.get(kind)
	b.add_child(icon)
	var nm: String = kind
	if ally and ALLIES.has(kind):
		nm = ALLIES[kind].get("name", kind)
	var lab := _outlined(nm, 10, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	lab.position = Vector2(0, 38)
	lab.size = Vector2(38, 14)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	if ally:
		b.pressed.connect(func(): summon(kind))
	else:
		b.pressed.connect(func(): _spawn_enemy(kind, 1.0))
	return b

func _rot_refresh() -> void:
	if _rot_overlay == null or not _rot_overlay.visible:
		return
	if _rot_castle_fill != null:
		var cp: float = clampf(float(castle_hp) / float(CASTLE_HP), 0.0, 1.0)
		_rot_castle_fill.size.x = 294.0 * cp
		_rot_castle_label.text = "성  %d / %d" % [max(0, castle_hp), CASTLE_HP]
	if _rot_fort_fill != null:
		var fmax: float = maxf(1.0, fortress_max)
		var fp: float = clampf(fortress_hp / fmax, 0.0, 1.0)
		_rot_fort_fill.size.x = 294.0 * fp
		_rot_fort_label.text = "요새  %d / %d" % [max(0, int(fortress_hp)), int(fmax)]

func _build_test_panel() -> void:
	# Control의 size를 늘려서 터치가 들어오게 한다 (버튼은 자식이라 Control size 밖이어도 그려짐)
	size = Vector2(720, 1280)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_test_panel = Control.new()
	_test_panel.position = Vector2(0, LANE_H + 8)
	_test_panel.size = Vector2(720, 1280 - LANE_H - 8)
	_test_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_test_panel)
	var bg := Panel.new()
	LaneUI.dress(bg, "panel_wood")
	bg.position = Vector2.ZERO
	bg.size = _test_panel.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_test_panel.add_child(bg)
	var title := _outlined("전투 테스트 (dev)", 20, Color(1.0, 0.85, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 6)
	title.size = Vector2(720, 26)
	_test_panel.add_child(title)
	var al := _outlined("아군 소환 (무료)", 16, Color(0.7, 0.95, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
	al.position = Vector2(14, 36)
	al.size = Vector2(300, 22)
	_test_panel.add_child(al)
	# 아군 그리드 (16종, 8열 × 2줄, 셀 84×84)
	var cols: int = 8
	var cell: float = 84.0
	var pad_x: float = 10.0
	var pad_y: float = 60.0
	for i in range(ALLY_ORDER.size()):
		var kind: String = ALLY_ORDER[i]
		var r: int = i / cols
		var c: int = i % cols
		var b := _test_kind_button(kind, true)
		b.position = Vector2(pad_x + c * cell, pad_y + r * (cell + 8))
		b.size = Vector2(cell - 4, cell)
		_test_panel.add_child(b)
	var ally_rows: int = int(ceil(float(ALLY_ORDER.size()) / cols))
	var el_y: float = pad_y + ally_rows * (cell + 8) + 10
	var el := _outlined("적 소환 (전체 종류)", 16, Color(1.0, 0.75, 0.75), HORIZONTAL_ALIGNMENT_LEFT)
	el.position = Vector2(14, el_y)
	el.size = Vector2(400, 22)
	_test_panel.add_child(el)
	var enemy_kinds: Array = ENEMIES.keys()
	var ey: float = el_y + 24
	for i in range(enemy_kinds.size()):
		var kind2: String = enemy_kinds[i]
		var r2: int = i / cols
		var c2: int = i % cols
		var b2 := _test_kind_button(kind2, false)
		b2.position = Vector2(pad_x + c2 * cell, ey + r2 * (cell + 8))
		b2.size = Vector2(cell - 4, cell)
		_test_panel.add_child(b2)
	var enemy_rows: int = int(ceil(float(enemy_kinds.size()) / cols))
	var ub_y: float = ey + enemy_rows * (cell + 8) + 12
	# 유틸: 아군/적 전원 제거, 체력 회복, 대포 충전
	var u1 := _test_util_button("아군 제거", func(): _test_clear_side(1))
	u1.position = Vector2(14, ub_y); _test_panel.add_child(u1)
	var u2 := _test_util_button("적 제거", func(): _test_clear_side(-1))
	u2.position = Vector2(188, ub_y); _test_panel.add_child(u2)
	var u3 := _test_util_button("체력 회복", func(): _test_full_heal())
	u3.position = Vector2(362, ub_y); _test_panel.add_child(u3)
	var u4 := _test_util_button("대포 충전", func(): cannon = 100.0; _refresh())
	u4.position = Vector2(536, ub_y); _test_panel.add_child(u4)

func _test_kind_button(kind: String, ally: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tint: Color = Color(0.25, 0.5, 0.75) if ally else Color(0.65, 0.25, 0.3)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var kk: float = 1.0
		if st == "hover": kk = 1.15
		elif st == "pressed" or st == "hover_pressed": kk = 0.8
		b.add_theme_stylebox_override(st, UIKit.box(Color(tint.r * kk, tint.g * kk, tint.b * kk, 1.0), Color(0.95, 0.85, 0.4), 8, 2))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var icon := TextureRect.new()
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(4, 4)
	icon.size = Vector2(72, 56)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = tex.get(kind)
	b.add_child(icon)
	var nm: String = kind
	if ally and ALLIES.has(kind):
		nm = ALLIES[kind].get("name", kind)
	var lab := _outlined(nm, 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	lab.position = Vector2(0, 60)
	lab.size = Vector2(80, 20)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lab)
	if ally:
		b.pressed.connect(func(): summon(kind))
	else:
		b.pressed.connect(func(): _spawn_enemy(kind, 1.0))
	return b

func _test_util_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	LaneUI.button(b, "red", 15)
	b.focus_mode = Control.FOCUS_NONE
	b.size = Vector2(160, 44)
	b.text = text
	b.pressed.connect(cb)
	return b

func _test_clear_side(side: int) -> void:
	for u in units.duplicate():
		if u["side"] == side and not u.get("hero", false):
			_kill(u)

func _test_full_heal() -> void:
	castle_hp = CASTLE_HP
	fortress_hp = fortress_max
	if not hero_unit.is_empty() and hero_unit.has("hp") and hero_unit.has("hp_max"):
		hero_unit["hp"] = hero_unit["hp_max"]
	_refresh()

# =========================================================
# 전투만 모드 (battle_only_mode): 덱 4명만 가로 소환 바
# =========================================================

var _bo_slots: Array = []  # {btn, cost_label, veil, kind}
var _bo_gold_label: Label = null
var _bo_home_btn: Button = null

func _build_bo_panel() -> void:
	# 2026-10-11 전투만 모드 하단 UI 전면 재구성 (720×1280, 패널 y=680..1280, 600px).
	# 4 섹션: ① 상태 바(y=0..80) ② 덱 소환(y=90..260) ③ 전투 컨트롤(y=280..360) ④ 상태 요약(y=380..590).
	# 좌표는 _bo_panel 로컬 (0..600). view=720 가로.
	size = Vector2(720, 1280)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_bo_panel = Control.new()
	_bo_panel.position = Vector2(0, BO_PANEL_TOP)
	_bo_panel.size = Vector2(720, 1280 - BO_PANEL_TOP)
	_bo_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_bo_panel)
	var bg := Panel.new()
	LaneUI.dress(bg, "panel_wood")
	bg.position = Vector2.ZERO
	bg.size = _bo_panel.size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bo_panel.add_child(bg)

	# =================== Section 1 — 상태 바 (y=0..80) ===================
	# 뒤로(10,12,56×56) · 금화(80,12,180×56) · 영웅 스킬 버튼(312,-8,96×96) · 자동 토글(596,16,110×48)
	_bo_back_btn = Button.new()
	_bo_back_btn.name = "BoBack"
	LaneUI.button(_bo_back_btn, "red", 22)
	_bo_back_btn.text = "◀"
	_bo_back_btn.focus_mode = Control.FOCUS_NONE
	_bo_back_btn.position = Vector2(10, 12)
	_bo_back_btn.size = Vector2(56, 56)
	_bo_back_btn.pressed.connect(func(): home_pressed.emit())
	_bo_panel.add_child(_bo_back_btn)
	# 금화 pill
	var gold_pill := Panel.new()
	gold_pill.name = "BoGoldPill"
	LaneUI.dress(gold_pill, "panel_wood")
	gold_pill.position = Vector2(80, 12)
	gold_pill.size = Vector2(180, 56)
	gold_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bo_panel.add_child(gold_pill)
	var coin_icon := LaneUI.icon("icon_coin", Vector2(32, 32))
	coin_icon.position = Vector2(10, 12)
	gold_pill.add_child(coin_icon)
	_bo_gold_label = _outlined("0", 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	_bo_gold_label.position = Vector2(50, 10)
	_bo_gold_label.size = Vector2(124, 36)
	_bo_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	gold_pill.add_child(_bo_gold_label)
	# 영웅 스킬 버튼 — 가운데 (312,-8), 96×96. 상단으로 8px 돌출시켜 바에 걸치는 큰 원 느낌.
	_bo_skill_btn = Button.new()
	_bo_skill_btn.name = "BoSkillBtn"
	_bo_skill_btn.position = Vector2(312, -8)
	_bo_skill_btn.size = Vector2(96, 96)
	_bo_skill_btn.focus_mode = Control.FOCUS_NONE
	_bo_skill_btn.clip_contents = true
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var fill := Color(0.14, 0.10, 0.22, 0.95) if st != "pressed" else Color(0.08, 0.06, 0.15, 0.95)
		var border := Color(1.00, 0.82, 0.36, 1.0) if st != "disabled" else Color(0.55, 0.48, 0.32, 1.0)
		_bo_skill_btn.add_theme_stylebox_override(st, UIKit.box(fill, border, 48, 3))
	_bo_skill_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_bo_skill_btn.pressed.connect(activate_hero_skill)
	_bo_panel.add_child(_bo_skill_btn)
	_bo_skill_icon = TextureRect.new()
	_bo_skill_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bo_skill_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bo_skill_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_bo_skill_icon.position = Vector2(14, 14)
	_bo_skill_icon.size = Vector2(68, 68)
	_bo_skill_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bo_skill_btn.add_child(_bo_skill_icon)
	_bo_skill_veil = ColorRect.new()
	_bo_skill_veil.color = Color(0.02, 0.03, 0.08, 0.68)
	_bo_skill_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bo_skill_veil.size = Vector2(96, 0)
	_bo_skill_veil.position = Vector2(0, 96)
	_bo_skill_btn.add_child(_bo_skill_veil)
	_bo_skill_label = _outlined("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_bo_skill_label.size = Vector2(96, 96)
	_bo_skill_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bo_skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bo_skill_btn.add_child(_bo_skill_label)
	# 스킬 이름 양피지 — 섹션 1 하단에 조그마하게.
	var skname_bg := Panel.new()
	skname_bg.name = "BoSkillName"
	LaneUI.dress(skname_bg, "panel_paper")
	skname_bg.position = Vector2(290, 56)
	skname_bg.size = Vector2(140, 22)
	skname_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bo_panel.add_child(skname_bg)
	_bo_skill_name_label = LaneUI.label("", 13, LaneUI.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_bo_skill_name_label.position = Vector2(290, 56)
	_bo_skill_name_label.size = Vector2(140, 22)
	_bo_skill_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bo_skill_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bo_panel.add_child(_bo_skill_name_label)
	# 자동 토글
	_bo_auto_btn = Button.new()
	_bo_auto_btn.name = "BoAutoBtn"
	LaneUI.button(_bo_auto_btn, "green" if auto_summon else "blue", 15)
	_bo_auto_btn.focus_mode = Control.FOCUS_NONE
	_bo_auto_btn.text = "자동 ON" if auto_summon else "자동 OFF"
	_bo_auto_btn.position = Vector2(596, 16)
	_bo_auto_btn.size = Vector2(110, 48)
	_bo_auto_btn.pressed.connect(func(): toggle_auto(); _bo_refresh_controls())
	_bo_panel.add_child(_bo_auto_btn)

	# =================== Section 2 — 덱 소환 카드 (y=90..260) ===================
	# 4 cards, 160×170, 간격 12, 총 가로 160*4+12*3=688, pad_x=16.
	_bo_slots.clear()
	var cell_w: float = 160.0
	var cell_h: float = 170.0
	var pad_x: float = 16.0
	var y_card: float = 90.0
	for i in range(LaneUnits.DECK_SIZE):
		var btn := Button.new()
		btn.name = "BoCard%d" % i
		btn.focus_mode = Control.FOCUS_NONE
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		btn.position = Vector2(pad_x + i * (cell_w + 12), y_card)
		btn.size = Vector2(cell_w, cell_h)
		btn.clip_contents = true
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			var kk: float = 1.0
			if st == "hover": kk = 1.12
			elif st == "pressed" or st == "hover_pressed": kk = 0.82
			btn.add_theme_stylebox_override(st, UIKit.box(Color(0.22 * kk, 0.42 * kk, 0.7 * kk, 1.0), Color(0.95, 0.85, 0.4), 12, 2))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var slot_i := i
		btn.pressed.connect(func():
			var k: String = deck[slot_i] if slot_i < deck.size() else ""
			if k == "":
				return
			var tw := btn.create_tween()
			btn.pivot_offset = btn.size * 0.5
			tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.06)
			tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
			summon(k))
		_bo_panel.add_child(btn)
		# 포트레이트 (큼지막): 상단 100×100 중앙
		var icon := TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2((cell_w - 100.0) * 0.5, 10)
		icon.size = Vector2(100, 100)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)
		# 이름
		var name_lab := _outlined("", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		name_lab.position = Vector2(0, 112)
		name_lab.size = Vector2(cell_w, 24)
		name_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(name_lab)
		# 비용
		var cost_lab := _outlined("", 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		cost_lab.position = Vector2(0, 138)
		cost_lab.size = Vector2(cell_w, 24)
		cost_lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(cost_lab)
		# 쿨 베일
		var veil := ColorRect.new()
		veil.color = Color(0.02, 0.03, 0.08, 0.55)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.size = Vector2(cell_w, 0)
		veil.position = Vector2(0, 0)
		btn.add_child(veil)
		_bo_slots.append({"btn": btn, "icon": icon, "name": name_lab, "cost": cost_lab, "veil": veil, "kind": ""})

	# =================== Section 3 — 전투 컨트롤 (y=280..360) ===================
	# 돌격/수비 (28,284,160×64) · 대포 (280,284,240×64, 내부 가로 충전 바) · 지갑 확장 (500,284,192×64).
	_bo_march_btn = Button.new()
	_bo_march_btn.name = "BoMarchBtn"
	LaneUI.button(_bo_march_btn, "red" if charging else "blue", 20)
	_bo_march_btn.focus_mode = Control.FOCUS_NONE
	_bo_march_btn.text = "돌격" if charging else "수비"
	_bo_march_btn.position = Vector2(28, 284)
	_bo_march_btn.size = Vector2(160, 64)
	_bo_march_btn.pressed.connect(func(): toggle_march(); _bo_refresh_controls())
	_bo_panel.add_child(_bo_march_btn)
	# 대포 — 버튼 안쪽에 가로 충전 바 fill 넣기.
	_bo_cannon_btn = Button.new()
	_bo_cannon_btn.name = "BoCannonBtn"
	LaneUI.button(_bo_cannon_btn, "blue", 20)
	_bo_cannon_btn.focus_mode = Control.FOCUS_NONE
	_bo_cannon_btn.text = ""
	_bo_cannon_btn.position = Vector2(280, 284)
	_bo_cannon_btn.size = Vector2(240, 64)
	_bo_cannon_btn.clip_contents = true
	_bo_cannon_btn.pressed.connect(fire_cannon)
	_bo_panel.add_child(_bo_cannon_btn)
	# 충전 바 (가로)
	_bo_cannon_fill = ColorRect.new()
	_bo_cannon_fill.color = Color(1.0, 0.7, 0.25, 0.55)
	_bo_cannon_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bo_cannon_fill.position = Vector2(2, 2)
	_bo_cannon_fill.size = Vector2(0, 60)
	_bo_cannon_btn.add_child(_bo_cannon_fill)
	_bo_cannon_label = _outlined("", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_bo_cannon_label.position = Vector2(0, 0)
	_bo_cannon_label.size = Vector2(240, 64)
	_bo_cannon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bo_cannon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bo_cannon_btn.add_child(_bo_cannon_label)
	# 지갑 확장
	_bo_wallet_btn = Button.new()
	_bo_wallet_btn.name = "BoWalletBtn"
	LaneUI.button(_bo_wallet_btn, "green", 17)
	_bo_wallet_btn.focus_mode = Control.FOCUS_NONE
	_bo_wallet_btn.text = "지갑 확장"
	_bo_wallet_btn.position = Vector2(532, 284)
	_bo_wallet_btn.size = Vector2(176, 64)
	_bo_wallet_btn.pressed.connect(func(): upgrade_wallet(); _bo_refresh_controls())
	_bo_panel.add_child(_bo_wallet_btn)

	# =================== Section 4 — 상태 요약 (y=380..590) ===================
	var sum_title := _outlined("전장 상황", 20, Color(0.78, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	sum_title.name = "BoSumTitle"
	sum_title.position = Vector2(0, 384)
	sum_title.size = Vector2(720, 24)
	_bo_panel.add_child(sum_title)
	# 적 유닛 미니 리스트 (가로 스크롤 컨테이너)
	var scroll := ScrollContainer.new()
	scroll.name = "BoEnemyScroll"
	scroll.position = Vector2(16, 412)
	scroll.size = Vector2(688, 72)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bo_panel.add_child(scroll)
	_bo_enemy_list = HBoxContainer.new()
	_bo_enemy_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_bo_enemy_list)
	# 웨이브 정보 라벨
	_bo_wave_label = _outlined("", 20, Color(1.0, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	_bo_wave_label.name = "BoWaveLabel"
	_bo_wave_label.position = Vector2(0, 498)
	_bo_wave_label.size = Vector2(720, 24)
	_bo_panel.add_child(_bo_wave_label)

	# ---------- UI 품질 게이트: 겹침 자동 검출 ----------
	_bo_check_overlaps()

func _bo_check_overlaps() -> void:
	# 섹션 간 세로 영역을 분리해 가로 겹침만 검사 (영웅 스킬 버튼은 Section 1·2 경계에 걸침 → 제외하고 섹션 내부끼리만).
	var sec1: Dictionary = {
		"back": _bo_back_btn.get_rect(),
		"gold": Rect2(Vector2(80, 12), Vector2(180, 56)),
		"skill_btn": _bo_skill_btn.get_rect(),
		"auto": _bo_auto_btn.get_rect(),
	}
	# gold vs skill_btn: skill_btn x=312 ≥ gold 끝 x=260 (여유 52). OK.
	# skill_btn vs auto: skill_btn 끝 x=408, auto x=596. OK.
	for a in sec1:
		for b in sec1:
			if a == b:
				continue
			if sec1[a].intersects(sec1[b]):
				push_error("[UI OVERLAP] section1: %s vs %s" % [a, b])
	var sec2: Dictionary = {}
	for i in range(_bo_slots.size()):
		sec2["card_%d" % i] = (_bo_slots[i]["btn"] as Button).get_rect()
	for a in sec2:
		for b in sec2:
			if a == b:
				continue
			if sec2[a].intersects(sec2[b]):
				push_error("[UI OVERLAP] section2: %s vs %s" % [a, b])
	var sec3: Dictionary = {
		"march": _bo_march_btn.get_rect(),
		"cannon": _bo_cannon_btn.get_rect(),
		"wallet": _bo_wallet_btn.get_rect(),
	}
	for a in sec3:
		for b in sec3:
			if a == b:
				continue
			if sec3[a].intersects(sec3[b]):
				push_error("[UI OVERLAP] section3: %s vs %s" % [a, b])
	# 세로 겹침 검사 (각 섹션 Y 밴드)
	var bands: Array = [
		["sec1", 0, 80],
		["sec2", 90, 260],
		["sec3", 280, 360],
		["sec4", 380, 598],
	]
	for i in range(bands.size()):
		for j in range(i + 1, bands.size()):
			if bands[i][2] > bands[j][1] and bands[j][2] > bands[i][1]:
				push_error("[UI OVERLAP] band %s vs %s" % [bands[i][0], bands[j][0]])
	print("[UI OK] bo panel sections laid out")

func _bo_refresh_slots() -> void:
	if _bo_panel == null:
		return
	for i in range(_bo_slots.size()):
		var s: Dictionary = _bo_slots[i]
		var kind: String = deck[i] if i < deck.size() else ""
		s["kind"] = kind
		if kind == "" or not ALLIES.has(kind):
			s["icon"].texture = null
			s["name"].text = ""
			s["cost"].text = "-"
			s["btn"].modulate = Color(0.4, 0.4, 0.44)
			continue
		var st: Dictionary = ALLIES[kind]
		s["icon"].texture = tex.get(kind)
		s["name"].text = str(st.get("name", kind))
		s["cost"].text = "💰%d" % int(st["cost"])
	_bo_refresh_controls()

func _bo_tick(delta: float) -> void:
	if _bo_panel == null or not _bo_panel.visible:
		return
	_bo_refresh_controls()
	if _bo_gold_label != null:
		_bo_gold_label.text = str(gold)
	for i in range(_bo_slots.size()):
		var s: Dictionary = _bo_slots[i]
		var kind: String = str(s.get("kind", ""))
		if kind == "" or not ALLIES.has(kind):
			continue
		var st: Dictionary = ALLIES[kind]
		var cool_left: float = float(cooldown.get(kind, 0.0))
		var cool_total: float = float(st.get("cool", 1.0))
		var veil: ColorRect = s["veil"]
		var ch: float = s["btn"].size.y
		var cw: float = s["btn"].size.x
		if cool_left > 0.0:
			var p: float = clampf(cool_left / maxf(0.01, cool_total), 0.0, 1.0)
			veil.size = Vector2(cw, ch * p)
			veil.position = Vector2(0, ch - ch * p)
			veil.visible = true
		else:
			veil.visible = false
		var ok: bool = gold >= int(st["cost"]) and cool_left <= 0.0 and _count(1) < MAX_ALLIES and not finished
		s["btn"].modulate = Color.WHITE if ok else Color(0.6, 0.6, 0.66)
	# 영웅 스킬 아이콘·쿨 베일·호흡
	if _bo_skill_btn != null:
		if _bo_skill_icon.texture == null and not hero_unit.is_empty():
			var hero_kind: String = str(hero_unit.get("kind", ""))
			if hero_kind != "":
				_bo_skill_icon.texture = tex.get("hero_" + hero_kind, tex.get("knight"))
		var cool: float = hero_cool
		var max_cool: float = 1.0
		if not hero_unit.is_empty() and hero_unit.has("kind"):
			var hk: String = str(hero_unit["kind"])
			if HEROES.has(hk):
				max_cool = float(HEROES[hk].get("cool", 1.0))
		if cool > 0.0:
			var p2: float = clampf(cool / max_cool, 0.0, 1.0)
			_bo_skill_veil.size = Vector2(96, 96.0 * p2)
			_bo_skill_veil.position = Vector2(0, 96.0 - 96.0 * p2)
			_bo_skill_veil.visible = true
			_bo_skill_label.text = "%d" % int(ceil(cool))
			_bo_skill_label.visible = true
		else:
			_bo_skill_veil.visible = false
			_bo_skill_label.visible = false
		var breathe: float = 1.0 + (0.08 * (0.5 + 0.5 * sin(_clock * 5.0)) if cool <= 0.0 else 0.0)
		_bo_skill_btn.scale = Vector2(breathe, breathe)
		_bo_skill_btn.pivot_offset = Vector2(48, 48)
	# 대포 가로 충전 바
	if _bo_cannon_btn != null and _bo_cannon_fill != null:
		var cp: float = clampf(cannon / 100.0, 0.0, 1.0)
		_bo_cannon_fill.size = Vector2(236.0 * cp, 60.0)
		_bo_cannon_label.text = "🎯 발사!" if cannon >= 100.0 else "🎯 대포 %d%%" % int(cannon)
		var pulse: float = 1.0 + (0.08 * (0.5 + 0.5 * sin(_clock * 8.0)) if cannon >= 100.0 else 0.0)
		_bo_cannon_btn.self_modulate = Color(pulse, pulse, pulse)
	# 웨이브 라벨 + 다음 웨이브 카운트다운
	if _bo_wave_label != null:
		var waves: Array = stage_data.get("waves", [])
		var total_w: int = waves.size()
		var cur_w: int = mini(wave_index + 1, maxi(1, total_w))
		var next_in: float = maxf(0.0, next_wave_at - elapsed)
		if wave_index >= total_w:
			_bo_wave_label.text = "웨이브 %d / %d  ·  반복 전진" % [total_w, total_w]
		else:
			_bo_wave_label.text = "웨이브 %d / %d  ·  다음 %ds" % [cur_w, total_w, int(ceil(next_in))]
	# 적 유닛 미니 리스트 — kind별 집계. 10 frames에 한번만 다시 그려 비용을 줄인다.
	_bo_enemy_tick += delta
	if _bo_enemy_tick >= 0.25:
		_bo_enemy_tick = 0.0
		_bo_refresh_enemy_list()

func _bo_refresh_controls() -> void:
	if _bo_march_btn != null:
		LaneUI.button(_bo_march_btn, "red" if charging else "blue", 20)
		_bo_march_btn.text = "돌격" if charging else "수비"
	if _bo_auto_btn != null:
		LaneUI.button(_bo_auto_btn, "green" if auto_summon else "blue", 15)
		_bo_auto_btn.text = "자동 ON" if auto_summon else "자동 OFF"
	if _bo_wallet_btn != null:
		if wallet < WALLET_COST.size():
			_bo_wallet_btn.text = "지갑 +%d" % WALLET_COST[wallet]
			_bo_wallet_btn.modulate = Color.WHITE if gold >= WALLET_COST[wallet] else Color(0.6, 0.6, 0.66)
		else:
			_bo_wallet_btn.text = "지갑 MAX"
			_bo_wallet_btn.modulate = Color(0.6, 0.6, 0.66)
	if _bo_skill_name_label != null:
		var nm: String = ""
		if not hero_unit.is_empty() and hero_unit.has("kind"):
			var hk: String = str(hero_unit["kind"])
			if HEROES.has(hk):
				nm = str(HEROES[hk].get("skill_name", ""))
		_bo_skill_name_label.text = nm

var _bo_enemy_tick: float = 0.0
var _bo_enemy_items: Dictionary = {}  # kind -> {panel, count_label}

func _bo_refresh_enemy_list() -> void:
	if _bo_enemy_list == null:
		return
	# 현재 적 유닛 kind별 개수
	var counts: Dictionary = {}
	for u in units:
		if u["side"] == -1 and not u.get("hero", false):
			var k: String = str(u.get("kind", "?"))
			counts[k] = int(counts.get(k, 0)) + 1
	# 사라진 kind 제거
	for k in _bo_enemy_items.keys():
		if not counts.has(k):
			var it: Dictionary = _bo_enemy_items[k]
			if it["panel"] != null and is_instance_valid(it["panel"]):
				it["panel"].queue_free()
			_bo_enemy_items.erase(k)
	# 추가·업데이트
	for k in counts:
		if not _bo_enemy_items.has(k):
			var panel := Panel.new()
			panel.custom_minimum_size = Vector2(72, 60)
			panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.1, 0.08, 0.14, 0.75), Color(0.55, 0.4, 0.2), 8, 2))
			_bo_enemy_list.add_child(panel)
			var ic := TextureRect.new()
			ic.texture = tex.get(k)
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.position = Vector2(4, 4)
			ic.size = Vector2(40, 40)
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(ic)
			var cnt := _outlined("", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
			cnt.position = Vector2(44, 20)
			cnt.size = Vector2(28, 20)
			cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			panel.add_child(cnt)
			_bo_enemy_items[k] = {"panel": panel, "count": cnt}
		_bo_enemy_items[k]["count"].text = "×%d" % counts[k]

