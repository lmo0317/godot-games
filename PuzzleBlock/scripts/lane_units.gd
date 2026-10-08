class_name LaneUnits
extends RefCounted
# 블록 기사단 soldiers and the army kept outside battles (docs/LANE_UNITS.md): 8 soldiers by role,
# star tiers (노멀 → 레어 → 유니크 → 레전더리 → 신화 → 전설) raised by merging duplicate copies, gems,
# the gacha, and the 4-slot deck used in battle.

const ARMY_PATH: String = "user://lane_army.json"
const DECK_SIZE: int = 4
const START_GEMS: int = 300
const PULL_COST: int = 100
const PULL10_COST: int = 900
const MAXED_REFUND: int = 20

# Star tiers. Each soldier starts at its base tier ("tier" in UNITS) and merges copies to go up
const TIER_NAME: Array[String] = ["노멀", "레어", "유니크", "레전더리", "신화", "전설"]
const TIER_COLOR: Array[Color] = [
	Color(0.58, 0.62, 0.68),   # 노멀: grey
	Color(0.22, 0.55, 1.0),    # 레어: blue
	Color(0.66, 0.32, 1.0),    # 유니크: purple
	Color(1.0, 0.56, 0.1),     # 레전더리: orange
	Color(1.0, 0.2, 0.32),     # 신화: red
	Color(1.0, 0.86, 0.3),     # 전설: gold (and a rainbow shimmer on cards)
]
const MAX_TIER: int = 5
const MERGE_COST: Array[int] = [1, 2, 3, 4, 5]   # copies to go from tier i to i + 1
const TIER_BONUS: float = 0.25                  # +25% HP and attack per tier above the base
# The gacha picks a base tier first, then a soldier of that tier
const BASE_RATE: Dictionary = {0: 0.65, 1: 0.28, 2: 0.07}

# speed: px per second, every: seconds between hits, cool: summon cooldown, kb: knockbacks per life
# shot: projectile (ranged), splash: px around the target, air: x vs flying, armor_break: x vs armor,
# siege: x vs the fortress, guard: share of damage taken away, heal: HP every 2 s around (heal_r px)
const UNITS: Dictionary = {
	"knight": {"name": "기사", "role": "근거리", "tier": 0, "cost": 50, "hp": 70.0, "atk": 12.0, "range": 44.0, "speed": 34.0, "every": 1.0, "cool": 2.0, "kb": 2,
		"desc": "싸고 빠른 앞줄. 자주 뽑아 벽을 세워요."},
	"shield": {"name": "방패병", "role": "탱커", "tier": 0, "cost": 75, "hp": 190.0, "atk": 4.0, "range": 36.0, "speed": 20.0, "every": 1.4, "cool": 6.0, "kb": 4, "guard": 0.3,
		"desc": "받는 피해 30% 감소, 잘 안 밀려요. 원거리 병사를 지켜요."},
	"spearman": {"name": "창병", "role": "갑옷 파괴", "tier": 0, "cost": 130, "hp": 110.0, "atk": 16.0, "range": 60.0, "speed": 26.0, "every": 1.2, "cool": 9.0, "kb": 3, "armor_break": 2.0,
		"desc": "갑옷 입은 적에게 2배 피해."},
	"archer": {"name": "궁수", "role": "원거리", "tier": 0, "cost": 80, "hp": 34.0, "atk": 9.0, "range": 140.0, "speed": 30.0, "every": 1.2, "cool": 4.0, "kb": 1, "shot": "arrow",
		"desc": "멀리서 화살을 쏴요. 날아다니는 적도 맞혀요."},
	"crossbow": {"name": "석궁병", "role": "공중 공격", "tier": 1, "cost": 110, "hp": 40.0, "atk": 12.0, "range": 170.0, "speed": 26.0, "every": 1.4, "cool": 6.0, "kb": 1, "shot": "bolt", "air": 2.5,
		"desc": "날아다니는 적에게 2.5배. 가장 멀리 쏴요."},
	"mage": {"name": "마법사", "role": "마법", "tier": 1, "cost": 120, "hp": 30.0, "atk": 14.0, "range": 110.0, "speed": 28.0, "every": 1.6, "cool": 8.0, "kb": 1, "shot": "orb", "splash": 50.0,
		"desc": "화염구가 옆의 적까지 태워요. 떼로 오는 적에 강해요."},
	"cleric": {"name": "사제", "role": "힐러", "tier": 1, "cost": 100, "hp": 45.0, "atk": 4.0, "range": 90.0, "speed": 26.0, "every": 1.5, "cool": 10.0, "kb": 1, "shot": "light", "heal": 12.0, "heal_r": 100.0,
		"desc": "2초마다 주변 아군 체력을 12씩 회복해요."},
	"cannoneer": {"name": "대포병", "role": "공성", "tier": 2, "cost": 200, "hp": 60.0, "atk": 30.0, "range": 180.0, "speed": 20.0, "every": 3.0, "cool": 15.0, "kb": 1, "shot": "ball", "splash": 40.0, "siege": 4.0,
		"desc": "적 요새에 4배 피해. 포탄이 주변까지 터져요."},
}
const ORDER: Array[String] = ["knight", "shield", "spearman", "archer", "crossbow", "mage", "cleric", "cannoneer"]

# Clear rewards are gems only (soldiers come from the gacha): first clear, boss first clear, new star,
# replay
const GEMS_FIRST: int = 150
const GEMS_FIRST_BOSS: int = 300
const GEMS_PER_STAR: int = 30
const GEMS_REPLAY: int = 50
const GEMS_FAIL_MAX: int = 60          # a lost stage still pays, by how much of the fortress fell

static func melee(kind: String) -> bool:
	return not UNITS[kind].has("shot")

static func tier_color(tier: int) -> Color:
	return TIER_COLOR[clampi(tier, 0, MAX_TIER)]

# Stats at a tier: HP, attack and healing grow by TIER_BONUS per tier above the soldier's base
static func stats(kind: String, tier: int) -> Dictionary:
	var st: Dictionary = UNITS[kind].duplicate()
	var k: float = 1.0 + TIER_BONUS * maxi(0, tier - int(st["tier"]))
	st["hp"] = st["hp"] * k
	st["atk"] = st["atk"] * k
	if st.has("heal"):
		st["heal"] = st["heal"] * k
	return st

# ---------------------------------------------------------------------------
# Army: gems, owned soldiers (kind -> {"tier", "copies"}) and the deck

# Everyone starts with a melee and a ranged soldier, so flying monsters can always be answered
const STARTERS: Array[String] = ["knight", "archer"]

static func _fresh(kind: String) -> Dictionary:
	return {"tier": int(UNITS[kind]["tier"]), "copies": 0}

static func default_army() -> Dictionary:
	return {"gems": START_GEMS, "owned": {"knight": _fresh("knight"), "archer": _fresh("archer")}, "deck": ["knight", "archer", "", ""]}

static func load_army() -> Dictionary:
	var army := default_army()
	if not FileAccess.file_exists(ARMY_PATH):
		return army
	var data = JSON.parse_string(FileAccess.open(ARMY_PATH, FileAccess.READ).get_as_text())
	if not data is Dictionary:
		return army
	army["gems"] = maxi(0, int(data.get("gems", START_GEMS)))
	if data.get("owned") is Dictionary:
		var owned: Dictionary = {}
		for k in data["owned"]:
			if not UNITS.has(k):
				continue
			var v = data["owned"][k]
			if v is Dictionary:
				owned[k] = {"tier": clampi(int(v.get("tier", UNITS[k]["tier"])), int(UNITS[k]["tier"]), MAX_TIER), "copies": maxi(0, int(v.get("copies", 0)))}
			else:
				# Older saves kept a level (1-5): its duplicates become copies to merge
				owned[k] = {"tier": int(UNITS[k]["tier"]), "copies": maxi(0, int(v) - 1)}
		if not owned.is_empty():
			army["owned"] = owned
	if data.get("deck") is Array:
		var deck: Array = []
		for k in data["deck"]:
			deck.append(str(k) if army["owned"].has(str(k)) and not deck.has(str(k)) else "")
		deck.resize(DECK_SIZE)
		army["deck"] = deck.map(func(k): return "" if k == null else k)
	# Older saves started with the knight only: hand them the starters too
	for k in STARTERS:
		if not army["owned"].has(k):
			army["owned"][k] = _fresh(k)
			var empty: int = army["deck"].find("")
			if empty >= 0 and not army["deck"].has(k):
				army["deck"][empty] = k
	if army["deck"].all(func(k): return k == ""):
		army["deck"][0] = army["owned"].keys()[0]
	return army

static func save_army(army: Dictionary) -> void:
	var f := FileAccess.open(ARMY_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(army))

static func deck() -> Array:
	return load_army()["deck"]

static func tier_of(kind: String) -> int:
	var o = load_army()["owned"].get(kind)
	return int(o["tier"]) if o is Dictionary else int(UNITS[kind]["tier"])

# Adds a soldier: new -> its base tier (and into an empty deck slot), owned -> one more copy to merge,
# already 전설 -> gems back. Returns {"kind", "new", "tier", "copies", "refund"}
static func add_unit(army: Dictionary, kind: String) -> Dictionary:
	var res := {"kind": kind, "new": false, "tier": int(UNITS[kind]["tier"]), "copies": 0, "refund": 0}
	if not army["owned"].has(kind):
		army["owned"][kind] = _fresh(kind)
		res["new"] = true
		var empty: int = army["deck"].find("")
		if empty >= 0:
			army["deck"][empty] = kind
	elif int(army["owned"][kind]["tier"]) < MAX_TIER:
		army["owned"][kind]["copies"] = int(army["owned"][kind]["copies"]) + 1
	else:
		army["gems"] += MAXED_REFUND
		res["refund"] = MAXED_REFUND
	res["tier"] = int(army["owned"][kind]["tier"])
	res["copies"] = int(army["owned"][kind]["copies"])
	return res

# Copies needed for the next tier (0 at 전설)
static func merge_need(tier: int) -> int:
	return MERGE_COST[tier] if tier < MAX_TIER else 0

static func can_merge(kind: String) -> bool:
	var o = load_army()["owned"].get(kind)
	return o is Dictionary and int(o["tier"]) < MAX_TIER and int(o["copies"]) >= merge_need(int(o["tier"]))

# Merges copies into the next tier; returns the new tier (-1 when not possible)
static func merge(kind: String) -> int:
	var army := load_army()
	var o = army["owned"].get(kind)
	if not o is Dictionary or int(o["tier"]) >= MAX_TIER or int(o["copies"]) < merge_need(int(o["tier"])):
		return -1
	o["copies"] = int(o["copies"]) - merge_need(int(o["tier"]))
	o["tier"] = int(o["tier"]) + 1
	save_army(army)
	return int(o["tier"])

# ---------------------------------------------------------------------------
# Gacha

static func roll_kind(rng: RandomNumberGenerator, min_tier: int = 0) -> String:
	var r: float = rng.randf()
	var base: int = 0
	if r < BASE_RATE[2]:
		base = 2
	elif r < BASE_RATE[2] + BASE_RATE[1]:
		base = 1
	base = maxi(base, min_tier)
	var pool: Array = ORDER.filter(func(k): return UNITS[k]["tier"] == base)
	return pool[rng.randi() % pool.size()]

# Spends gems and returns the results (empty when there are not enough gems). Ten pulls promise at
# least one 레어 or better
static func pull(count: int, rng: RandomNumberGenerator) -> Array:
	var army := load_army()
	var cost: int = PULL10_COST if count >= 10 else PULL_COST * count
	if army["gems"] < cost:
		return []
	army["gems"] -= cost
	var kinds: Array = []
	for i in range(count):
		kinds.append(roll_kind(rng))
	if count >= 10 and kinds.all(func(k): return UNITS[k]["tier"] == 0):
		kinds[rng.randi() % count] = roll_kind(rng, 1)
	var results: Array = []
	for k in kinds:
		results.append(add_unit(army, k))
	save_army(army)
	return results

# ---------------------------------------------------------------------------
# Deck

# Deck power shown against each stage's recommended power: 100 per soldier plus 25 per tier (the
# stat bonus per tier), counted from 노멀, so a higher-base soldier counts for more
static func unit_power(kind: String, tier: int) -> int:
	return 100 + 25 * tier

static func deck_power(army: Dictionary = {}) -> int:
	if army.is_empty():
		army = load_army()
	var total := 0
	for k in army["deck"]:
		if k != "" and army["owned"].has(k):
			total += unit_power(k, int(army["owned"][k]["tier"]))
	return total

static func set_deck_slot(slot: int, kind: String) -> void:
	var army := load_army()
	if kind != "" and not army["owned"].has(kind):
		return
	var d: Array = army["deck"]
	var at: int = d.find(kind)
	if kind != "" and at >= 0:
		d[at] = ""
	d[slot] = kind
	if d.all(func(k): return k == ""):
		return # the deck is never empty
	save_army(army)

# Test reset (the home's "리셋", dev builds only): back to the two starters and the starting gems
static func reset_army() -> void:
	if FileAccess.file_exists(ARMY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARMY_PATH))

# Test gems (the home's "+" next to the gem count, dev builds only)
static func add_gems(n: int) -> int:
	var army := load_army()
	army["gems"] = int(army["gems"]) + n
	save_army(army)
	return int(army["gems"])

# ---------------------------------------------------------------------------
# A lost stage pays a little, by the share of the fortress destroyed, so replays keep the army growing
static func reward_fail(fortress_damaged: float) -> Dictionary:
	var army := load_army()
	var gems: int = int(round(GEMS_FAIL_MAX * clampf(fortress_damaged, 0.0, 1.0)))
	army["gems"] += gems
	save_army(army)
	return {"gems": gems}

# Rewards for a stage clear: gems only. Returns {"gems"}
static func reward_clear(stage_id: int, first: bool, new_stars: int, boss: bool) -> Dictionary:
	var army := load_army()
	var gems: int = ((GEMS_FIRST_BOSS if boss else GEMS_FIRST) if first else GEMS_REPLAY) + GEMS_PER_STAR * new_stars
	army["gems"] += gems
	save_army(army)
	return {"gems": gems}
