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
# Gems also go with the copies, so the player picks who to raise (2026-10-09)
const MERGE_GEMS: Array[int] = [50, 150, 400, 800, 1500]
const TIER_BONUS: float = 0.25                  # +25% HP and attack per tier above the base
# Soft pity: 20 pulls with no 유니크+ → the next 10-pull guarantees one. Hard pity: 90 pulls with no
# 레전더리 → the next 10-pull guarantees one (docs/GACHA_RESEARCH.md 피티)
const PITY_UNIQUE: int = 20
const PITY_LEGENDARY: int = 90
# The gacha picks a base tier first, then a soldier of that tier
# (16 soldiers since 2026-10-08: 6 노멀, 6 레어, 3 유니크, 1 레전더리)
const BASE_RATE: Dictionary = {0: 0.60, 1: 0.30, 2: 0.085, 3: 0.015}

# speed: px per second, every: seconds between hits, cool: summon cooldown, kb: knockbacks per life
# shot: projectile (ranged), splash: px around the target, air: x vs flying, armor_break: x vs armor,
# siege: x vs the fortress, guard: share of damage taken away, heal: HP every 2 s around (heal_r px),
# crit: chance of a double hit, charge: x on the first hit, slow: seconds a hit halves the target's
# speed, aura: attack bonus every 2 s to friends within aura_r px, flying: over the ground (melee
# monsters can't hit it and ground monsters don't block it)
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
	# 2026-10-08: 8 more for the collection (docs/LANE_UNITS.md "16종")
	"rogue": {"name": "도적", "role": "암살", "tier": 0, "cost": 70, "hp": 45.0, "atk": 14.0, "range": 36.0, "speed": 55.0, "every": 0.7, "cool": 3.0, "kb": 2, "crit": 0.3,
		"desc": "아주 빠르게 찌르고, 30% 확률로 2배 치명타."},
	"berserker": {"name": "광전사", "role": "광역 근접", "tier": 0, "cost": 110, "hp": 95.0, "atk": 14.0, "range": 44.0, "speed": 30.0, "every": 1.3, "cool": 6.0, "kb": 3, "splash": 35.0,
		"desc": "도끼를 휘둘러 옆의 적까지 베요."},
	"icemage": {"name": "얼음 마법사", "role": "둔화", "tier": 1, "cost": 110, "hp": 32.0, "atk": 10.0, "range": 120.0, "speed": 28.0, "every": 1.5, "cool": 8.0, "kb": 1, "shot": "ice", "slow": 2.5,
		"desc": "맞은 적을 2.5초 동안 절반 속도로 얼려요. 하늘도 맞혀요."},
	"cavalry": {"name": "기마 기사", "role": "돌진", "tier": 1, "cost": 140, "hp": 150.0, "atk": 18.0, "range": 50.0, "speed": 60.0, "every": 1.2, "cool": 9.0, "kb": 4, "charge": 3.0,
		"desc": "빠르게 달려가 첫 공격에 3배 피해. 단단해요."},
	"bard": {"name": "음유시인", "role": "응원", "tier": 1, "cost": 100, "hp": 40.0, "atk": 5.0, "range": 100.0, "speed": 26.0, "every": 1.5, "cool": 10.0, "kb": 1, "shot": "note", "aura": 0.25, "aura_r": 120.0,
		"desc": "노래로 2초마다 주변 아군 공격력 +25%."},
	"paladin": {"name": "성기사", "role": "수호", "tier": 2, "cost": 180, "hp": 220.0, "atk": 12.0, "range": 44.0, "speed": 22.0, "every": 1.3, "cool": 12.0, "kb": 5, "guard": 0.35, "heal": 8.0, "heal_r": 80.0,
		"desc": "받는 피해 35% 감소, 2초마다 주변 아군 체력 8 회복."},
	"hero": {"name": "영웅 검사", "role": "만능", "tier": 2, "cost": 190, "hp": 160.0, "atk": 24.0, "range": 48.0, "speed": 34.0, "every": 1.0, "cool": 12.0, "kb": 4, "splash": 30.0, "armor_break": 1.5,
		"desc": "강한 일격이 옆까지 베고, 갑옷에도 강해요."},
	"dragon": {"name": "용기사", "role": "비행", "tier": 3, "cost": 260, "hp": 180.0, "atk": 20.0, "range": 130.0, "speed": 30.0, "every": 1.6, "cool": 18.0, "kb": 3, "shot": "fireball", "splash": 45.0, "air": 1.5, "siege": 2.0, "flying": true,
		"desc": "하늘을 날아 근접 몬스터에게 맞지 않아요. 불꽃이 광역으로, 요새에 2배."},
}
const ORDER: Array[String] = ["knight", "shield", "spearman", "archer", "rogue", "berserker", "crossbow", "mage", "cleric", "icemage", "cavalry", "bard", "cannoneer", "paladin", "hero", "dragon"]

# Clear rewards are gems only (soldiers come from the gacha): first clear, boss first clear, new star,
# replay
# 16 soldiers spread the copies thinner than 8, so first clears pay a bit more (econ check in
# docs/LANE_UNITS.md)
const GEMS_FIRST: int = 200
const GEMS_FIRST_BOSS: int = 400
const GEMS_PER_STAR: int = 30
const GEMS_REPLAY: int = 50
const GEMS_FAIL_MAX: int = 60          # a lost stage still pays, by how much of the fortress fell

# 영웅 시스템 (2026-10-10 docs/HERO_SYSTEM_PLAN.md): 서유기 4인방, 전투당 1명 선택, 영구 사망.
# 수치는 lane_battle.gd HEROES 상수에 있음 — 여기서는 ID·이름·역할·설명만.
const HEROES: Dictionary = {
	"sanzang":  {"name": "삼장",   "role": "서포터",   "tex": "hero_sanzang",
		"skill": "염불 결계",   "desc": "4초간 아군이 받는 피해 ½ · 공격력 +30%"},
	"wukong":   {"name": "손오공", "role": "광역 공격", "tex": "hero_wukong",
		"skill": "여의봉 광풍", "desc": "전장의 모든 적에게 100 피해 + 큰 넉백"},
	"bajie":    {"name": "저팔계", "role": "탱커",     "tex": "hero_bajie",
		"skill": "쇄기 돌진",   "desc": "전방 150 피해 + 넉백 + 2초 스턴"},
	"wujing":   {"name": "사오정", "role": "균형",     "tex": "hero_wujing",
		"skill": "수룡 재생",   "desc": "자신 70% 회복 + 아군 전원 30% 회복"},
}
const HERO_IDS: Array[String] = ["sanzang", "wukong", "bajie", "wujing"]

static func heroes_unlocked() -> Array:
	return load_army().get("heroes_unlocked", ["sanzang"])

static func is_hero_unlocked(id: String) -> bool:
	return heroes_unlocked().has(id)

static func selected_hero() -> String:
	var a := load_army()
	var sel: String = str(a.get("selected_hero", "sanzang"))
	var list: Array = a.get("heroes_unlocked", ["sanzang"])
	return sel if list.has(sel) else "sanzang"

static func select_hero(id: String) -> void:
	if not HEROES.has(id):
		return
	var a := load_army()
	if not (a["heroes_unlocked"] as Array).has(id):
		return
	a["selected_hero"] = id
	save_army(a)

# 영웅 보상: army를 받아 수정만 함 (저장은 호출측). 이미 가진 영웅이면 아무 것도 안 함; 반환 true면 새로 획득.
static func unlock_hero(army: Dictionary, id: String) -> bool:
	if not HEROES.has(id):
		return false
	var list: Array = army.get("heroes_unlocked", ["sanzang"])
	if list.has(id):
		return false
	list.append(id)
	army["heroes_unlocked"] = list
	# 새로 얻은 영웅으로 자동 선택
	army["selected_hero"] = id
	return true

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
	return {"gems": START_GEMS, "owned": {"knight": _fresh("knight"), "archer": _fresh("archer")}, "deck": ["knight", "archer", "", ""],
		"pulls_since_unique": 0, "pulls_since_legendary": 0, "universal_shards": 0, "auto_flip": false,
		# 영웅 시스템 (2026-10-10 docs/HERO_SYSTEM_PLAN.md): 삼장은 처음부터, 손오공·저팔계·사오정은 스토리 보상
		"heroes_unlocked": ["sanzang"], "selected_hero": "sanzang"}

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
	# 2026-10-09 new fields: default to 0 / false when the save is older
	army["pulls_since_unique"] = maxi(0, int(data.get("pulls_since_unique", 0)))
	army["pulls_since_legendary"] = maxi(0, int(data.get("pulls_since_legendary", 0)))
	army["universal_shards"] = maxi(0, int(data.get("universal_shards", 0)))
	army["auto_flip"] = bool(data.get("auto_flip", false))
	# 영웅: 저장이 없거나 손상되면 삼장만 가짐
	var heroes_raw = data.get("heroes_unlocked", ["sanzang"])
	var heroes: Array = ["sanzang"]
	if heroes_raw is Array:
		for h in heroes_raw:
			var hs: String = str(h)
			if HERO_IDS.has(hs) and not heroes.has(hs):
				heroes.append(hs)
	army["heroes_unlocked"] = heroes
	var sel: String = str(data.get("selected_hero", "sanzang"))
	army["selected_hero"] = sel if heroes.has(sel) else "sanzang"
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
# already 전설 -> a universal shard (2026-10-09, used to be gems).
# Returns {"kind", "new", "tier", "copies", "shard"}
static func add_unit(army: Dictionary, kind: String) -> Dictionary:
	var res := {"kind": kind, "new": false, "tier": int(UNITS[kind]["tier"]), "copies": 0, "shard": 0, "refund": 0}
	if not army["owned"].has(kind):
		army["owned"][kind] = _fresh(kind)
		res["new"] = true
		var empty: int = army["deck"].find("")
		if empty >= 0:
			army["deck"][empty] = kind
	elif int(army["owned"][kind]["tier"]) < MAX_TIER:
		army["owned"][kind]["copies"] = int(army["owned"][kind]["copies"]) + 1
	else:
		army["universal_shards"] = int(army.get("universal_shards", 0)) + 1
		res["shard"] = 1
	res["tier"] = int(army["owned"][kind]["tier"])
	res["copies"] = int(army["owned"][kind]["copies"])
	return res

# Copies needed for the next tier (0 at 전설)
static func merge_need(tier: int) -> int:
	return MERGE_COST[tier] if tier < MAX_TIER else 0

# Gems needed for the next tier (0 at 전설)
static func merge_gems(tier: int) -> int:
	return MERGE_GEMS[tier] if tier < MAX_TIER else 0

static func can_merge(kind: String, army: Dictionary = {}) -> bool:
	if army.is_empty():
		army = load_army()
	var o = army["owned"].get(kind)
	if not (o is Dictionary) or int(o["tier"]) >= MAX_TIER:
		return false
	var t: int = int(o["tier"])
	return int(o["copies"]) >= merge_need(t) and int(army.get("gems", 0)) >= merge_gems(t)

# Copies-only check (used by the gacha "can merge" callout and the result summary)
static func has_copies(kind: String, army: Dictionary = {}) -> bool:
	if army.is_empty():
		army = load_army()
	var o = army["owned"].get(kind)
	return o is Dictionary and int(o["tier"]) < MAX_TIER and int(o["copies"]) >= merge_need(int(o["tier"]))

# Merges copies + gems into the next tier; returns the new tier (-1 when not possible)
static func merge(kind: String) -> int:
	var army := load_army()
	var o = army["owned"].get(kind)
	if not (o is Dictionary) or int(o["tier"]) >= MAX_TIER:
		return -1
	var t: int = int(o["tier"])
	if int(o["copies"]) < merge_need(t) or int(army.get("gems", 0)) < merge_gems(t):
		return -1
	o["copies"] = int(o["copies"]) - merge_need(t)
	army["gems"] = int(army["gems"]) - merge_gems(t)
	o["tier"] = t + 1
	save_army(army)
	return int(o["tier"])

# Spend a universal shard for one copy of any soldier (even 전설, since copies cap at 0 then);
# returns true on success
static func spend_shard(kind: String) -> bool:
	var army := load_army()
	if int(army.get("universal_shards", 0)) <= 0 or not army["owned"].has(kind):
		return false
	var o: Dictionary = army["owned"][kind]
	if int(o["tier"]) >= MAX_TIER:
		return false
	army["universal_shards"] = int(army["universal_shards"]) - 1
	o["copies"] = int(o["copies"]) + 1
	save_army(army)
	return true

# Setter used by UI (auto_flip toggle)
static func set_auto_flip(on: bool) -> void:
	var army := load_army()
	army["auto_flip"] = on
	save_army(army)

# ---------------------------------------------------------------------------
# Gacha

static func roll_kind(rng: RandomNumberGenerator, min_tier: int = 0) -> String:
	# Rarest first: 레전더리, 유니크, 레어, else 노멀
	var r: float = rng.randf()
	var base: int = 0
	var acc: float = 0.0
	for t in [3, 2, 1]:
		acc += BASE_RATE[t]
		if r < acc:
			base = t
			break
	base = maxi(base, min_tier)
	var pool: Array = ORDER.filter(func(k): return UNITS[k]["tier"] == base)
	return pool[rng.randi() % pool.size()]

# Spends gems and returns the results (empty when there are not enough gems). Ten pulls promise at
# least one 레어 or better. Pity: 20 pulls without 유니크+ → next 10-pull has 유니크+. 90 pulls without
# 레전더리 → next 10-pull has 레전더리 (docs/GACHA_RESEARCH.md 피티)
static func pull(count: int, rng: RandomNumberGenerator) -> Array:
	var army := load_army()
	var cost: int = PULL10_COST if count >= 10 else PULL_COST * count
	if army["gems"] < cost:
		return []
	army["gems"] -= cost
	var pity_u: bool = count >= 10 and int(army.get("pulls_since_unique", 0)) >= PITY_UNIQUE
	var pity_l: bool = count >= 10 and int(army.get("pulls_since_legendary", 0)) >= PITY_LEGENDARY
	var kinds: Array = []
	for i in range(count):
		kinds.append(roll_kind(rng))
	if count >= 10 and kinds.all(func(k): return UNITS[k]["tier"] == 0):
		kinds[rng.randi() % count] = roll_kind(rng, 1)
	if pity_u and not kinds.any(func(k): return UNITS[k]["tier"] >= 2):
		kinds[rng.randi() % count] = roll_kind(rng, 2)
	if pity_l and not kinds.any(func(k): return UNITS[k]["tier"] >= 3):
		kinds[rng.randi() % count] = roll_kind(rng, 3)
	# Update pity counters per card (reset when 유니크+ / 레전더리 shows)
	var since_u: int = int(army.get("pulls_since_unique", 0))
	var since_l: int = int(army.get("pulls_since_legendary", 0))
	for k in kinds:
		var t: int = int(UNITS[k]["tier"])
		if t >= 2:
			since_u = 0
		else:
			since_u += 1
		if t >= 3:
			since_l = 0
		else:
			since_l += 1
	army["pulls_since_unique"] = since_u
	army["pulls_since_legendary"] = since_l
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
# 2026-10-09: a stage may set a custom first-clear gem amount (clear_gem). Replays still pay the small
# flat amount so grinding doesn't farm gems.
static func reward_clear(stage_id: int, first: bool, new_stars: int, boss: bool) -> Dictionary:
	var army := load_army()
	var first_gems: int = GEMS_FIRST_BOSS if boss else GEMS_FIRST
	if first:
		var stage: Dictionary = LaneStages.get_stage(stage_id)
		if stage.has("clear_gem"):
			first_gems = int(stage["clear_gem"])
	var gems: int = (first_gems if first else GEMS_REPLAY) + GEMS_PER_STAR * new_stars
	army["gems"] += gems
	save_army(army)
	return {"gems": gems}
