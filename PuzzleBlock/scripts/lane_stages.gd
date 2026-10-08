class_name LaneStages
extends RefCounted
# 블록 기사단 stages (docs/LANE_STAGES.md): 4 chapters x 6 stages, played one at a time from the
# stage select. Each stage: fortress HP, monster power, single-monster interval and pool, scripted
# waves, an optional boss at half the fortress, and the soldiers available.

const PROGRESS_PATH: String = "user://lane_progress.json"

# Sky tint per chapter (the lane picture stays the same)
const CHAPTERS: Array[Dictionary] = [
	{"name": "1장 초원", "tint": Color(1, 1, 1)},
	{"name": "2장 숲", "tint": Color(1.0, 0.66, 0.5)},
	{"name": "3장 묘지", "tint": Color(0.42, 0.48, 0.82)},
	{"name": "4장 마왕성", "tint": Color(0.95, 0.42, 0.42)},
]
const PER_CHAPTER: int = 6

# Difficulty assumes the army grows: the tiers a deck is expected to have gained by each stage when
# the player only spends first-clear gems (docs/LANE_STAGES.md "밸런스"). Monster power includes it,
# so an army that never pulls or merges gets stuck and has to replay, pull and merge to go on
const EXPECTED: Array[float] = [0.0, 0.0, 0.5, 0.6, 0.8, 0.9, 1.2, 1.3, 1.4, 1.5, 1.6, 1.75,
	1.9, 2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.85, 2.9]

static func expected_tier(stage_id: int) -> float:
	return EXPECTED[clampi(stage_id - 1, 0, EXPECTED.size() - 1)]

# Sawtooth inside each chapter (docs/LANE_STAGES.md): a stage that teaches a new monster is a little
# easier, a test is even, a twist mixes earlier monsters, the boss is the wall at the end
const ROLE_PACE: Dictionary = {"teach": 0.9, "test": 1.0, "twist": 1.05, "boss": 1.06}
const ROLE_NAME: Dictionary = {"teach": "새 적", "test": "시험", "twist": "응용", "boss": "보스"}

# Recommended deck power (LaneUnits.deck_power): what a deck at the expected tier has, raised or
# lowered with the stage's place in the sawtooth. Stages 1-2 are for the two starters
static func recommended_power(stage_id: int) -> int:
	if stage_id <= 2:
		return 200
	var s := get_stage(stage_id)
	var pace: float = ROLE_PACE.get(s.get("role", "test"), 1.0)
	return int(round((425.0 + 100.0 * expected_tier(stage_id)) * pace / 10.0)) * 10

# Each chapter starts with a bigger purse and a higher income level
static func start_wallet(stage_id: int) -> int:
	return clampi((stage_id - 1) / PER_CHAPTER, 0, 3)

static func start_gold(stage_id: int) -> int:
	return 60 + 15 * (stage_id - 1)

const BOSSES: Dictionary = {
	"slime_king": {"name": "왕슬라임", "kind": "slime", "hp": 12.0, "atk": 3.0, "scale": 2.0, "kb": 3},
	"goblin_chief": {"name": "고블린 대장", "kind": "goblin", "hp": 6.0, "atk": 2.0, "scale": 1.6, "kb": 4},
	"iron_captain": {"name": "철갑 대장", "kind": "armored", "hp": 4.5, "atk": 1.6, "scale": 1.5, "kb": 4},
	"demon_lord": {"name": "마왕", "kind": "demon", "hp": 4.5, "atk": 1.25, "scale": 1.6, "kb": 5},
}

# waves: [seconds after the start, [monster kinds]]; after the last one it repeats every 40 s.
# swarm: false keeps slimes single
const STAGES: Array[Dictionary] = [
	{"id": 1, "name": "첫 출정", "role": "teach", "fortress": 1000, "power": 0.95, "every": 11.0, "pool": ["slime"], "swarm": false,
		"waves": [[35.0, ["slime", "slime", "slime"]]], "boss": "", "new": "기사로 막고 줄을 지워 금화를 모아요"},
	{"id": 2, "name": "고블린 정찰대", "role": "teach", "fortress": 1100, "power": 0.95, "every": 10.0, "pool": ["slime", "goblin"], "swarm": false,
		"waves": [[30.0, ["goblin", "goblin", "slime", "slime"]], [65.0, ["goblin", "goblin", "goblin"]]], "boss": "", "new": "궁수를 섞어 보세요"},
	{"id": 3, "name": "고블린 무리", "role": "test", "fortress": 1350, "power": 1.21, "every": 10.0, "pool": ["goblin"],
		"waves": [[25.0, ["goblin", "goblin", "goblin"]], [55.0, ["goblin", "goblin", "goblin", "goblin"]]], "boss": "", "new": "방패병으로 앞줄을 버텨요"},
	{"id": 4, "name": "박쥐 동굴", "role": "teach", "fortress": 1450, "power": 1.22, "every": 10.0, "pool": ["goblin", "bat"],
		"waves": [[30.0, ["bat", "bat", "bat"]], [60.0, ["bat", "bat", "goblin", "goblin"]]], "boss": "", "new": "박쥐는 원거리 병사만 맞혀요"},
	{"id": 5, "name": "슬라임 늪", "role": "twist", "fortress": 1750, "power": 1.48, "every": 10.0, "pool": ["slime"],
		"waves": [[30.0, ["slime", "slime", "slime", "slime"]], [60.0, ["slime", "slime", "slime", "slime", "bat", "goblin"]]], "boss": "", "new": "떼는 마법사 광역으로"},
	{"id": 6, "name": "왕슬라임", "role": "boss", "fortress": 1900, "power": 1.53, "every": 10.0, "pool": ["slime", "goblin", "bat"],
		"waves": [[30.0, ["slime", "slime", "slime", "slime"]], [60.0, ["goblin", "goblin", "bat", "bat"]]], "boss": "slime_king", "new": "보스 등장"},
	{"id": 7, "name": "늑대 습격", "role": "teach", "fortress": 2000, "power": 1.42, "every": 10.0, "pool": ["wolf", "goblin"],
		"waves": [[25.0, ["wolf", "wolf", "wolf"]], [55.0, ["wolf", "wolf", "wolf", "goblin"]]], "boss": "", "new": "늑대는 아주 빨라요"},
	{"id": 8, "name": "고블린 궁수대", "role": "teach", "fortress": 2100, "power": 1.45, "every": 10.0, "pool": ["goblin", "gob_archer"],
		"waves": [[30.0, ["gob_archer", "gob_archer", "goblin", "goblin"]], [60.0, ["gob_archer", "gob_archer", "gob_archer"]]], "boss": "", "new": "원거리 적은 방패로 받아요"},
	{"id": 9, "name": "숲의 혼전", "role": "twist", "fortress": 2500, "power": 1.72, "every": 9.0, "pool": ["goblin", "gob_archer", "wolf", "bat"],
		"waves": [[25.0, ["wolf", "wolf", "bat", "bat"]], [50.0, ["gob_archer", "gob_archer", "goblin", "goblin"]], [75.0, ["wolf", "wolf", "wolf", "bat"]]], "boss": "", "new": ""},
	{"id": 10, "name": "철갑 부대", "role": "teach", "fortress": 2600, "power": 1.51, "every": 11.0, "pool": ["armored", "goblin"],
		"waves": [[30.0, ["armored", "armored", "goblin", "goblin"]], [60.0, ["armored", "armored", "goblin"]]], "boss": "", "new": "갑옷은 창병이 2배"},
	{"id": 11, "name": "숲길 매복", "role": "twist", "fortress": 2750, "power": 1.79, "every": 10.0, "pool": ["wolf", "gob_archer", "armored"],
		"waves": [[25.0, ["wolf", "wolf", "armored"]], [55.0, ["gob_archer", "gob_archer", "armored", "wolf"]]], "boss": "", "new": ""},
	{"id": 12, "name": "고블린 대장", "role": "boss", "fortress": 2900, "power": 1.85, "every": 9.0, "pool": ["goblin", "gob_archer", "wolf"],
		"waves": [[30.0, ["goblin", "goblin", "goblin", "goblin"]], [60.0, ["gob_archer", "gob_archer", "wolf", "wolf"]]], "boss": "goblin_chief", "new": "보스 등장"},
	{"id": 13, "name": "해골 묘지 입구", "role": "teach", "fortress": 3300, "power": 1.41, "every": 10.0, "pool": ["skeleton", "wolf"],
		"waves": [[30.0, ["skeleton", "skeleton", "skeleton"]], [60.0, ["skeleton", "skeleton", "wolf", "wolf"]]], "boss": "", "new": "해골 전사 등장"},
	{"id": 14, "name": "어둠의 사제", "role": "teach", "fortress": 3450, "power": 1.44, "every": 9.0, "pool": ["skeleton", "priest"],
		"waves": [[30.0, ["skeleton", "skeleton", "priest"]], [60.0, ["skeleton", "skeleton", "skeleton", "priest"]]], "boss": "", "new": "회복하는 사제를 먼저 잡아요"},
	{"id": 15, "name": "뼈의 행진", "role": "test", "fortress": 3600, "power": 1.62, "every": 9.0, "pool": ["skeleton", "armored"],
		"waves": [[25.0, ["armored", "armored", "skeleton", "skeleton"]], [55.0, ["armored", "armored", "armored"]]], "boss": "", "new": ""},
	{"id": 16, "name": "골렘", "role": "teach", "fortress": 3750, "power": 1.10, "every": 9.0, "pool": ["golem", "skeleton"],
		"waves": [[35.0, ["golem", "skeleton", "skeleton"]], [70.0, ["golem", "golem"]]], "boss": "", "new": "거대한 골렘은 대포로"},
	{"id": 17, "name": "밤박쥐 떼", "role": "twist", "fortress": 4200, "power": 1.76, "every": 8.0, "pool": ["bat", "bat", "skeleton"],
		"waves": [[25.0, ["bat", "bat", "bat", "bat"]], [50.0, ["bat", "bat", "bat", "armored"]]], "boss": "", "new": "하늘을 막을 원거리 병사를"},
	{"id": 18, "name": "철갑 대장", "role": "boss", "fortress": 4400, "power": 1.80, "every": 8.0, "pool": ["armored", "priest", "skeleton"],
		"waves": [[30.0, ["armored", "armored", "priest"]], [60.0, ["skeleton", "skeleton", "skeleton", "armored"]]], "boss": "iron_captain", "new": "보스 등장"},
	{"id": 19, "name": "오크 전사", "role": "teach", "fortress": 4550, "power": 1.36, "every": 8.0, "pool": ["orc", "goblin", "gob_archer"],
		"waves": [[30.0, ["orc", "goblin", "goblin", "goblin"]], [60.0, ["orc", "orc", "gob_archer"]]], "boss": "", "new": "오크 등장"},
	{"id": 20, "name": "마왕성 정문", "role": "twist", "fortress": 4700, "power": 1.61, "every": 8.0, "pool": ["orc", "wolf", "armored"],
		"waves": [[25.0, ["wolf", "wolf", "wolf", "orc"]], [55.0, ["armored", "armored", "orc"]]], "boss": "", "new": ""},
	{"id": 21, "name": "골렘과 사제", "role": "twist", "fortress": 5250, "power": 1.28, "every": 8.0, "pool": ["golem", "priest"],
		"waves": [[30.0, ["golem", "priest", "priest"]], [65.0, ["golem", "golem", "priest"]]], "boss": "", "new": ""},
	{"id": 22, "name": "하늘을 덮는 날개", "role": "test", "fortress": 5400, "power": 1.58, "every": 7.0, "pool": ["bat", "bat", "gob_archer"],
		"waves": [[20.0, ["bat", "bat", "bat", "bat"]], [45.0, ["bat", "bat", "bat", "bat", "gob_archer"]], [70.0, ["bat", "bat", "bat", "wolf", "wolf"]]], "boss": "", "new": ""},
	{"id": 23, "name": "총공세", "role": "twist", "fortress": 5600, "power": 1.67, "every": 7.0, "pool": ["slime", "goblin", "wolf", "gob_archer", "skeleton", "bat", "armored", "priest", "golem", "orc"],
		"waves": [[20.0, ["wolf", "wolf", "bat", "bat"]], [45.0, ["armored", "armored", "golem", "priest"]], [70.0, ["orc", "orc", "gob_archer", "gob_archer"]]], "boss": "", "new": ""},
	{"id": 24, "name": "마왕", "role": "boss", "fortress": 6100, "power": 1.46, "every": 7.0, "pool": ["orc", "golem", "armored", "bat", "priest"],
		"waves": [[30.0, ["orc", "orc", "bat", "bat"]], [60.0, ["golem", "armored", "armored"]]], "boss": "demon_lord", "new": "최종 보스"},
]

# What to tell a player who lost: the counters the stage asks for that the deck is missing, then
# whether the deck is below the recommended power. Returns up to two short lines
static func fail_advice(stage_id: int, deck: Array, power: int) -> Array:
	var s := get_stage(stage_id)
	var kinds: Array = s["pool"].duplicate()
	for w in s["waves"]:
		kinds.append_array(w[1])
	if s["boss"] != "":
		kinds.append(BOSSES[s["boss"]]["kind"])
	var has := func(list: Array) -> bool: return list.any(func(k): return deck.has(k))
	var lines: Array = []
	if kinds.has("bat") and not has.call(["archer", "crossbow", "mage", "cannoneer", "cleric"]):
		lines.append("박쥐는 원거리 병사(궁수·석궁병)만 맞혀요")
	elif kinds.count("bat") >= 4 and not deck.has("crossbow"):
		lines.append("박쥐 떼는 석궁병이 2.5배로 잡아요")
	if (kinds.has("armored") or kinds.has("golem")) and not has.call(["spearman", "cannoneer"]):
		lines.append("갑옷·골렘은 창병·대포병이 강해요")
	if kinds.has("priest") and not has.call(["archer", "crossbow", "mage"]):
		lines.append("회복하는 사제는 원거리로 먼저 잡아요")
	if (kinds.count("slime") >= 4 or kinds.count("goblin") >= 4) and not has.call(["mage", "cannoneer"]):
		lines.append("떼로 오는 적은 마법사 광역으로")
	var rec: int = recommended_power(stage_id)
	if power < rec:
		lines.append("권장 전투력 %d · 내 덱 %d — 뽑고 합성해서 키워요" % [rec, power])
	if lines.is_empty():
		lines.append("성급을 올리면 더 쉬워져요 — 뽑고 합성해 보세요")
	return lines.slice(0, 2)

static func count() -> int:
	return STAGES.size()

static func get_stage(stage_id: int) -> Dictionary:
	for s in STAGES:
		if s["id"] == stage_id:
			return s
	return {}

static func chapter(stage_id: int) -> Dictionary:
	return CHAPTERS[clampi((stage_id - 1) / PER_CHAPTER, 0, CHAPTERS.size() - 1)]

# Stars from the castle HP left at the clear
static func stars_for(castle_ratio: float) -> int:
	if castle_ratio >= 0.8:
		return 3
	if castle_ratio >= 0.5:
		return 2
	return 1

static func star_text(stars: int) -> String:
	return "★".repeat(stars) + "☆".repeat(3 - stars)

static func load_progress() -> Dictionary:
	var progress: Dictionary = {"unlocked": 1, "stars": {}}
	if not FileAccess.file_exists(PROGRESS_PATH):
		return progress
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.READ)
	var data = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		progress["unlocked"] = clampi(int(data.get("unlocked", 1)), 1, count())
		if data.get("stars") is Dictionary:
			progress["stars"] = data["stars"]
	return progress

static func total_stars() -> int:
	var total := 0
	for v in load_progress()["stars"].values():
		total += int(v)
	return total

# Saves a clear; returns true when the stars improved
static func record_clear(stage_id: int, stars: int) -> bool:
	var progress := load_progress()
	var key := str(stage_id)
	var improved: bool = stars > int(progress["stars"].get(key, 0))
	if improved:
		progress["stars"][key] = stars
	progress["unlocked"] = clampi(maxi(int(progress["unlocked"]), stage_id + 1), 1, count())
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(progress))
	return improved
