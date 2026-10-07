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

# Difficulty assumes the army grows: the tier a deck is expected to have reached by each stage
# (docs/LANE_STAGES.md "밸런스"); monster power and fortress HP include it, so an army that never
# pulls or merges gets stuck and has to replay, pull and merge to go on
static func expected_tier(stage_id: int) -> float:
	if stage_id <= 2:
		return 0.0
	if stage_id <= 4:
		return 0.5
	if stage_id <= 8:
		return 1.0
	if stage_id <= 12:
		return 1.5
	if stage_id <= 16:
		return 2.0
	if stage_id <= 20:
		return 2.5
	return 3.0

# Each chapter starts with a bigger purse and a higher income level
static func start_wallet(stage_id: int) -> int:
	return clampi((stage_id - 1) / PER_CHAPTER, 0, 3)

static func start_gold(stage_id: int) -> int:
	return 60 + 15 * (stage_id - 1)

const BOSSES: Dictionary = {
	"slime_king": {"name": "왕슬라임", "kind": "slime", "hp": 12.0, "atk": 3.0, "scale": 2.0, "kb": 3},
	"goblin_chief": {"name": "고블린 대장", "kind": "goblin", "hp": 6.0, "atk": 2.0, "scale": 1.6, "kb": 4},
	"iron_captain": {"name": "철갑 대장", "kind": "armored", "hp": 4.5, "atk": 1.6, "scale": 1.5, "kb": 4},
	"demon_lord": {"name": "마왕", "kind": "demon", "hp": 6.0, "atk": 1.5, "scale": 1.6, "kb": 5},
}

# waves: [seconds after the start, [monster kinds]]; after the last one it repeats every 40 s.
# swarm: false keeps slimes single
const STAGES: Array[Dictionary] = [
	{"id": 1, "name": "첫 출정", "fortress": 1000, "power": 1.00, "every": 11.0, "pool": ["slime"], "swarm": false,
		"waves": [[35.0, ["slime", "slime", "slime"]]], "boss": "", "new": "기사로 막고 줄을 지워 금화를 모아요"},
	{"id": 2, "name": "고블린 정찰대", "fortress": 1100, "power": 1.00, "every": 10.0, "pool": ["slime", "goblin"], "swarm": false,
		"waves": [[30.0, ["goblin", "goblin", "slime", "slime"]], [65.0, ["goblin", "goblin", "goblin"]]], "boss": "", "new": "궁수를 섞어 보세요"},
	{"id": 3, "name": "고블린 무리", "fortress": 1350, "power": 1.17, "every": 10.0, "pool": ["goblin"],
		"waves": [[25.0, ["goblin", "goblin", "goblin"]], [55.0, ["goblin", "goblin", "goblin", "goblin"]]], "boss": "", "new": "방패병으로 앞줄을 버텨요"},
	{"id": 4, "name": "슬라임 늪", "fortress": 1450, "power": 1.17, "every": 10.0, "pool": ["slime"],
		"waves": [[30.0, ["slime", "slime", "slime", "slime"]], [60.0, ["slime", "slime", "slime", "slime", "goblin"]]], "boss": "", "new": "떼는 마법사 광역으로"},
	{"id": 5, "name": "박쥐 동굴", "fortress": 1750, "power": 1.37, "every": 10.0, "pool": ["goblin", "bat"],
		"waves": [[30.0, ["bat", "bat", "bat"]], [60.0, ["bat", "bat", "goblin", "goblin"]]], "boss": "", "new": "박쥐는 원거리 병사만 맞혀요"},
	{"id": 6, "name": "왕슬라임", "fortress": 1900, "power": 1.37, "every": 10.0, "pool": ["slime", "goblin", "bat"],
		"waves": [[30.0, ["slime", "slime", "slime", "slime"]], [60.0, ["goblin", "goblin", "bat", "bat"]]], "boss": "slime_king", "new": "보스 등장"},
	{"id": 7, "name": "늑대 습격", "fortress": 2000, "power": 1.43, "every": 10.0, "pool": ["wolf", "goblin"],
		"waves": [[25.0, ["wolf", "wolf", "wolf"]], [55.0, ["wolf", "wolf", "wolf", "goblin"]]], "boss": "", "new": "늑대는 아주 빨라요"},
	{"id": 8, "name": "고블린 궁수대", "fortress": 2100, "power": 1.43, "every": 10.0, "pool": ["goblin", "gob_archer"],
		"waves": [[30.0, ["gob_archer", "gob_archer", "goblin", "goblin"]], [60.0, ["gob_archer", "gob_archer", "gob_archer"]]], "boss": "", "new": "원거리 적은 방패로 받아요"},
	{"id": 9, "name": "해골 묘지 입구", "fortress": 2500, "power": 1.65, "every": 10.0, "pool": ["skeleton", "wolf"],
		"waves": [[30.0, ["skeleton", "skeleton", "skeleton"]], [60.0, ["skeleton", "skeleton", "wolf", "wolf"]]], "boss": "", "new": "해골 전사 등장"},
	{"id": 10, "name": "숲의 혼전", "fortress": 2600, "power": 1.65, "every": 9.0, "pool": ["goblin", "gob_archer", "wolf", "bat"],
		"waves": [[25.0, ["wolf", "wolf", "bat", "bat"]], [50.0, ["gob_archer", "gob_archer", "goblin", "goblin"]], [75.0, ["wolf", "wolf", "wolf", "bat"]]], "boss": "", "new": ""},
	{"id": 11, "name": "철갑 부대", "fortress": 2750, "power": 1.54, "every": 11.0, "pool": ["armored", "skeleton"],
		"waves": [[30.0, ["armored", "armored", "skeleton", "skeleton"]], [60.0, ["armored", "armored", "skeleton"]]], "boss": "", "new": "갑옷은 창병이 2배"},
	{"id": 12, "name": "고블린 대장", "fortress": 2900, "power": 1.72, "every": 9.0, "pool": ["goblin", "gob_archer", "wolf"],
		"waves": [[30.0, ["goblin", "goblin", "goblin", "goblin"]], [60.0, ["gob_archer", "gob_archer", "wolf", "wolf"]]], "boss": "goblin_chief", "new": "보스 등장"},
	{"id": 13, "name": "어둠의 사제", "fortress": 3300, "power": 1.49, "every": 9.0, "pool": ["skeleton", "priest"],
		"waves": [[30.0, ["skeleton", "skeleton", "priest"]], [60.0, ["skeleton", "skeleton", "skeleton", "priest"]]], "boss": "", "new": "회복하는 사제를 먼저 잡아요"},
	{"id": 14, "name": "뼈의 행진", "fortress": 3450, "power": 1.54, "every": 9.0, "pool": ["skeleton", "armored"],
		"waves": [[25.0, ["armored", "armored", "skeleton", "skeleton"]], [55.0, ["armored", "armored", "armored"]]], "boss": "", "new": ""},
	{"id": 15, "name": "밤박쥐 떼", "fortress": 3600, "power": 1.54, "every": 8.0, "pool": ["bat", "bat", "skeleton"],
		"waves": [[25.0, ["bat", "bat", "bat", "bat"]], [50.0, ["bat", "bat", "bat", "armored"]]], "boss": "", "new": "하늘을 막을 원거리 병사를"},
	{"id": 16, "name": "골렘", "fortress": 3750, "power": 1.21, "every": 9.0, "pool": ["golem", "skeleton"],
		"waves": [[35.0, ["golem", "skeleton", "skeleton"]], [70.0, ["golem", "golem"]]], "boss": "", "new": "거대한 골렘은 대포로"},
	{"id": 17, "name": "오크 전사", "fortress": 4200, "power": 1.45, "every": 8.0, "pool": ["orc", "goblin", "gob_archer"],
		"waves": [[30.0, ["orc", "goblin", "goblin", "goblin"]], [60.0, ["orc", "orc", "gob_archer"]]], "boss": "", "new": "오크 등장"},
	{"id": 18, "name": "철갑 대장", "fortress": 4400, "power": 1.51, "every": 8.0, "pool": ["armored", "priest", "skeleton"],
		"waves": [[30.0, ["armored", "armored", "priest"]], [60.0, ["skeleton", "skeleton", "skeleton", "armored"]]], "boss": "iron_captain", "new": "보스 등장"},
	{"id": 19, "name": "마왕성 정문", "fortress": 4550, "power": 1.36, "every": 8.0, "pool": ["orc", "wolf", "armored"],
		"waves": [[25.0, ["wolf", "wolf", "wolf", "orc"]], [55.0, ["armored", "armored", "orc"]]], "boss": "", "new": ""},
	{"id": 20, "name": "골렘과 사제", "fortress": 4700, "power": 1.14, "every": 8.0, "pool": ["golem", "priest"],
		"waves": [[30.0, ["golem", "priest", "priest"]], [65.0, ["golem", "golem", "priest"]]], "boss": "", "new": ""},
	{"id": 21, "name": "하늘을 덮는 날개", "fortress": 5250, "power": 1.51, "every": 7.0, "pool": ["bat", "bat", "gob_archer"],
		"waves": [[20.0, ["bat", "bat", "bat", "bat"]], [45.0, ["bat", "bat", "bat", "bat", "gob_archer"]], [70.0, ["bat", "bat", "bat", "wolf", "wolf"]]], "boss": "", "new": ""},
	{"id": 22, "name": "오크 군단", "fortress": 5400, "power": 1.58, "every": 8.0, "pool": ["orc", "orc", "gob_archer"],
		"waves": [[30.0, ["orc", "orc", "gob_archer", "gob_archer"]], [60.0, ["orc", "orc", "orc"]]], "boss": "", "new": ""},
	{"id": 23, "name": "총공세", "fortress": 5600, "power": 1.58, "every": 7.0, "pool": ["slime", "goblin", "wolf", "gob_archer", "skeleton", "bat", "armored", "priest", "golem", "orc"],
		"waves": [[20.0, ["wolf", "wolf", "bat", "bat"]], [45.0, ["armored", "armored", "golem", "priest"]], [70.0, ["orc", "orc", "gob_archer", "gob_archer"]]], "boss": "", "new": ""},
	{"id": 24, "name": "마왕", "fortress": 6100, "power": 1.48, "every": 7.0, "pool": ["orc", "golem", "armored", "bat", "priest"],
		"waves": [[30.0, ["orc", "orc", "bat", "bat"]], [60.0, ["golem", "armored", "armored"]]], "boss": "demon_lord", "new": "최종 보스"},
]

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
