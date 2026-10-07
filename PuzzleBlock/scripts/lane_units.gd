class_name LaneUnits
extends RefCounted
# 블록 기사단 soldiers and the army kept outside battles (docs/LANE_UNITS.md): 8 soldiers by role,
# rarity, levels from duplicates, gems, the gacha, and the 4-slot deck used in battle.

const ARMY_PATH: String = "user://lane_army.json"
const DECK_SIZE: int = 4
const MAX_LEVEL: int = 5
const LEVEL_BONUS: float = 0.1        # +10% HP and attack per level above 1
const START_GEMS: int = 200
const PULL_COST: int = 100
const PULL10_COST: int = 900
const MAXED_REFUND: int = 20

const RARITY_NAME: Dictionary = {1: "일반", 2: "희귀", 3: "영웅"}
const RARITY_COLOR: Dictionary = {1: Color(0.72, 0.75, 0.8), 2: Color(0.35, 0.65, 1.0), 3: Color(1.0, 0.8, 0.25)}
const RARITY_RATE: Dictionary = {1: 0.65, 2: 0.28, 3: 0.07}

# speed: px per second, every: seconds between hits, cool: summon cooldown, kb: knockbacks per life
# shot: projectile (ranged), splash: px around the target, air: x vs flying, armor_break: x vs armor,
# siege: x vs the fortress, guard: share of damage taken away, heal: HP every 2 s around (heal_r px)
const UNITS: Dictionary = {
	"knight": {"name": "기사", "role": "근거리", "rarity": 1, "cost": 50, "hp": 70.0, "atk": 12.0, "range": 44.0, "speed": 34.0, "every": 1.0, "cool": 2.0, "kb": 2,
		"desc": "싸고 빠른 앞줄. 자주 뽑아 벽을 세워요."},
	"shield": {"name": "방패병", "role": "탱커", "rarity": 1, "cost": 75, "hp": 190.0, "atk": 4.0, "range": 36.0, "speed": 20.0, "every": 1.4, "cool": 6.0, "kb": 4, "guard": 0.3,
		"desc": "받는 피해 30% 감소, 잘 안 밀려요. 원거리 병사를 지켜요."},
	"spearman": {"name": "창병", "role": "갑옷 파괴", "rarity": 1, "cost": 130, "hp": 110.0, "atk": 16.0, "range": 60.0, "speed": 26.0, "every": 1.2, "cool": 9.0, "kb": 3, "armor_break": 2.0,
		"desc": "갑옷 입은 적에게 2배 피해."},
	"archer": {"name": "궁수", "role": "원거리", "rarity": 1, "cost": 80, "hp": 34.0, "atk": 9.0, "range": 140.0, "speed": 30.0, "every": 1.2, "cool": 4.0, "kb": 1, "shot": "arrow",
		"desc": "멀리서 화살을 쏴요. 날아다니는 적도 맞혀요."},
	"crossbow": {"name": "석궁병", "role": "공중 공격", "rarity": 2, "cost": 110, "hp": 40.0, "atk": 12.0, "range": 170.0, "speed": 26.0, "every": 1.4, "cool": 6.0, "kb": 1, "shot": "bolt", "air": 2.5,
		"desc": "날아다니는 적에게 2.5배. 가장 멀리 쏴요."},
	"mage": {"name": "마법사", "role": "마법", "rarity": 2, "cost": 120, "hp": 30.0, "atk": 14.0, "range": 110.0, "speed": 28.0, "every": 1.6, "cool": 8.0, "kb": 1, "shot": "orb", "splash": 50.0,
		"desc": "화염구가 옆의 적까지 태워요. 떼로 오는 적에 강해요."},
	"cleric": {"name": "사제", "role": "힐러", "rarity": 2, "cost": 100, "hp": 45.0, "atk": 4.0, "range": 90.0, "speed": 26.0, "every": 1.5, "cool": 10.0, "kb": 1, "shot": "light", "heal": 12.0, "heal_r": 100.0,
		"desc": "2초마다 주변 아군 체력을 12씩 회복해요."},
	"cannoneer": {"name": "대포병", "role": "공성", "rarity": 3, "cost": 200, "hp": 60.0, "atk": 30.0, "range": 180.0, "speed": 20.0, "every": 3.0, "cool": 15.0, "kb": 1, "shot": "ball", "splash": 40.0, "siege": 4.0,
		"desc": "적 요새에 4배 피해. 포탄이 주변까지 터져요."},
}
const ORDER: Array[String] = ["knight", "shield", "spearman", "archer", "crossbow", "mage", "cleric", "cannoneer"]

# Soldier given at a stage's first clear
const STAGE_REWARD: Dictionary = {1: "archer", 2: "shield", 3: "mage", 5: "spearman"}

static func melee(kind: String) -> bool:
	return not UNITS[kind].has("shot")

# Stats at a level: HP and attack grow by LEVEL_BONUS per level
static func stats(kind: String, level: int) -> Dictionary:
	var st: Dictionary = UNITS[kind].duplicate()
	var k: float = 1.0 + LEVEL_BONUS * (clampi(level, 1, MAX_LEVEL) - 1)
	st["hp"] = st["hp"] * k
	st["atk"] = st["atk"] * k
	if st.has("heal"):
		st["heal"] = st["heal"] * k
	return st

# ---------------------------------------------------------------------------
# Army: gems, owned soldiers (kind -> level) and the deck

static func default_army() -> Dictionary:
	return {"gems": START_GEMS, "owned": {"knight": 1}, "deck": ["knight", "", "", ""]}

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
			if UNITS.has(k):
				owned[k] = clampi(int(data["owned"][k]), 1, MAX_LEVEL)
		if not owned.is_empty():
			army["owned"] = owned
	if data.get("deck") is Array:
		var deck: Array = []
		for k in data["deck"]:
			deck.append(str(k) if army["owned"].has(str(k)) and not deck.has(str(k)) else "")
		deck.resize(DECK_SIZE)
		army["deck"] = deck.map(func(k): return "" if k == null else k)
	if army["deck"].all(func(k): return k == ""):
		army["deck"][0] = army["owned"].keys()[0]
	return army

static func save_army(army: Dictionary) -> void:
	var f := FileAccess.open(ARMY_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(army))

static func deck() -> Array:
	return load_army()["deck"]

static func level_of(kind: String) -> int:
	return int(load_army()["owned"].get(kind, 0))

# Adds a soldier: new -> level 1 (and into an empty deck slot), owned -> level up, maxed -> gems.
# Returns {"kind", "new", "level", "refund"}
static func add_unit(army: Dictionary, kind: String) -> Dictionary:
	var res := {"kind": kind, "new": false, "level": 1, "refund": 0}
	if not army["owned"].has(kind):
		army["owned"][kind] = 1
		res["new"] = true
		var empty: int = army["deck"].find("")
		if empty >= 0:
			army["deck"][empty] = kind
	elif int(army["owned"][kind]) < MAX_LEVEL:
		army["owned"][kind] = int(army["owned"][kind]) + 1
	else:
		army["gems"] += MAXED_REFUND
		res["refund"] = MAXED_REFUND
	res["level"] = int(army["owned"][kind])
	return res

# ---------------------------------------------------------------------------
# Gacha

static func roll_kind(rng: RandomNumberGenerator, min_rarity: int = 1) -> String:
	var r: float = rng.randf()
	var rarity: int = 1
	if r < RARITY_RATE[3]:
		rarity = 3
	elif r < RARITY_RATE[3] + RARITY_RATE[2]:
		rarity = 2
	rarity = maxi(rarity, min_rarity)
	var pool: Array = ORDER.filter(func(k): return UNITS[k]["rarity"] == rarity)
	return pool[rng.randi() % pool.size()]

# Spends gems and returns the results (empty when there are not enough gems). Ten pulls promise at
# least one rare or better
static func pull(count: int, rng: RandomNumberGenerator) -> Array:
	var army := load_army()
	var cost: int = PULL10_COST if count >= 10 else PULL_COST * count
	if army["gems"] < cost:
		return []
	army["gems"] -= cost
	var kinds: Array = []
	for i in range(count):
		kinds.append(roll_kind(rng))
	if count >= 10 and kinds.all(func(k): return UNITS[k]["rarity"] == 1):
		kinds[rng.randi() % count] = roll_kind(rng, 2)
	var results: Array = []
	for k in kinds:
		results.append(add_unit(army, k))
	save_army(army)
	return results

# ---------------------------------------------------------------------------
# Deck

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

# ---------------------------------------------------------------------------
# Rewards for a stage clear: gems (first clear 100, boss 200; replay 20) + 20 per new star,
# and the stage's soldier on its first clear. Returns {"gems", "unit"}
static func reward_clear(stage_id: int, first: bool, new_stars: int, boss: bool) -> Dictionary:
	var army := load_army()
	var gems: int = (200 if boss else 100) if first else 20
	gems += 20 * new_stars
	army["gems"] += gems
	var unit: String = ""
	if first and STAGE_REWARD.has(stage_id) and not army["owned"].has(STAGE_REWARD[stage_id]):
		unit = STAGE_REWARD[stage_id]
		add_unit(army, unit)
	save_army(army)
	return {"gems": gems, "unit": unit}
