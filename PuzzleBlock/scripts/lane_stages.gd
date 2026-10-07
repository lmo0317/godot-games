class_name LaneStages
extends RefCounted
# 블록 기사단 stages (docs/LANE_STAGES.md): 3 chapters x 4 stages, played one at a time from the
# stage select. Each stage: fortress HP, monster power, single-monster interval and pool, scripted
# waves, an optional boss at half the fortress, and the soldiers available.

const PROGRESS_PATH: String = "user://lane_progress.json"

# Sky tint per chapter (the lane picture stays the same)
const CHAPTERS: Array[Dictionary] = [
	{"name": "1장 초원", "tint": Color(1, 1, 1)},
	{"name": "2장 해질녘", "tint": Color(1.0, 0.66, 0.5)},
	{"name": "3장 밤", "tint": Color(0.42, 0.48, 0.82)},
]

# Each chapter starts with a bigger purse and a higher income level (there are no upgrades between
# stages, so this stands in for growing stronger)
static func start_wallet(stage_id: int) -> int:
	return clampi((stage_id - 1) / 4, 0, 2)

static func start_gold(stage_id: int) -> int:
	return 60 + 30 * (stage_id - 1)

# Soldier -> first stage that has it
const UNLOCK: Dictionary = {"knight": 1, "archer": 2, "mage": 3, "spearman": 6}

const BOSSES: Dictionary = {
	"slime_king": {"name": "왕슬라임", "kind": "slime", "hp": 12.0, "atk": 3.0, "scale": 2.0, "kb": 3},
	"goblin_chief": {"name": "고블린 대장", "kind": "goblin", "hp": 6.0, "atk": 2.0, "scale": 1.6, "kb": 4},
	"iron_captain": {"name": "철갑 대장", "kind": "armored", "hp": 4.5, "atk": 1.6, "scale": 1.5, "kb": 4},
	"orc_king": {"name": "오크 왕", "kind": "orc", "hp": 5.0, "atk": 1.8, "scale": 2.0, "kb": 5},
}

# waves: [seconds after the start, [monster kinds]]; after the last one it repeats every 30 s.
# swarm: false keeps slimes single (stage 1)
const STAGES: Array[Dictionary] = [
	{"id": 1, "name": "첫 출정", "fortress": 1100, "power": 1.0, "every": 10.0, "pool": ["slime"], "swarm": false,
		"waves": [[35.0, ["slime", "slime", "slime"]]], "boss": "", "new": "기사와 대포로 시작해요"},
	{"id": 2, "name": "고블린 정찰대", "fortress": 1250, "power": 1.0, "every": 10.0, "pool": ["slime", "goblin"], "swarm": false,
		"waves": [[30.0, ["goblin", "goblin", "slime", "slime"]], [65.0, ["goblin", "goblin", "goblin"]]], "boss": "", "new": "새 병사: 궁수"},
	{"id": 3, "name": "슬라임 늪", "fortress": 1450, "power": 1.05, "every": 10.0, "pool": ["slime"],
		"waves": [[30.0, ["slime", "slime", "slime", "slime"]], [60.0, ["slime", "slime", "slime", "goblin", "goblin"]]], "boss": "slime_king", "new": "새 병사: 마법사 · 보스 등장"},
	{"id": 4, "name": "박쥐 동굴", "fortress": 1600, "power": 1.1, "every": 10.0, "pool": ["goblin", "bat"],
		"waves": [[30.0, ["bat", "bat", "bat"]], [60.0, ["bat", "bat", "goblin", "goblin"]]], "boss": "", "new": "박쥐는 궁수·마법사만 맞혀요"},
	{"id": 5, "name": "해골 묘지", "fortress": 1600, "power": 1.1, "every": 11.0, "pool": ["skeleton", "goblin", "slime"],
		"waves": [[30.0, ["skeleton", "skeleton", "skeleton"]], [60.0, ["skeleton", "skeleton", "bat", "bat"]]], "boss": "", "new": "해골 전사 등장"},
	{"id": 6, "name": "고블린 대장", "fortress": 1800, "power": 1.15, "every": 11.0, "pool": ["goblin", "skeleton", "bat"],
		"waves": [[30.0, ["goblin", "goblin", "goblin", "goblin"]], [60.0, ["skeleton", "skeleton", "bat", "bat"]]], "boss": "goblin_chief", "new": "새 병사: 창병 · 보스 등장"},
	{"id": 7, "name": "철갑 부대", "fortress": 1800, "power": 1.05, "every": 11.0, "pool": ["armored", "skeleton"],
		"waves": [[30.0, ["armored", "armored", "skeleton", "skeleton"]], [60.0, ["armored", "armored", "skeleton"]]], "boss": "", "new": "갑옷 해골은 창병에게 약해요"},
	{"id": 8, "name": "혼성 부대", "fortress": 2000, "power": 1.15, "every": 10.0, "pool": ["slime", "goblin", "skeleton", "bat", "armored"],
		"waves": [[25.0, ["bat", "bat", "bat", "armored"]], [50.0, ["slime", "slime", "goblin", "goblin"]], [75.0, ["armored", "armored", "skeleton", "skeleton"]]], "boss": "", "new": ""},
	{"id": 9, "name": "오크 선봉대", "fortress": 2150, "power": 1.25, "every": 10.0, "pool": ["orc", "goblin"],
		"waves": [[30.0, ["orc", "goblin", "goblin", "goblin"]], [60.0, ["orc", "orc"]]], "boss": "iron_captain", "new": "오크 등장 · 보스 등장"},
	{"id": 10, "name": "밤하늘 습격", "fortress": 2350, "power": 1.3, "every": 9.0, "pool": ["bat", "bat", "armored"],
		"waves": [[25.0, ["bat", "bat", "bat", "bat"]], [50.0, ["bat", "bat", "armored", "armored"]]], "boss": "", "new": ""},
	{"id": 11, "name": "총공세", "fortress": 2500, "power": 1.35, "every": 9.0, "pool": ["slime", "goblin", "skeleton", "bat", "armored", "orc"],
		"waves": [[25.0, ["goblin", "goblin", "bat", "bat"]], [50.0, ["armored", "orc", "slime", "slime", "slime"]], [75.0, ["orc", "orc", "skeleton", "skeleton"]]], "boss": "", "new": ""},
	{"id": 12, "name": "오크 왕", "fortress": 2900, "power": 1.4, "every": 9.0, "pool": ["orc", "armored", "bat", "skeleton"],
		"waves": [[30.0, ["orc", "orc", "bat", "bat"]], [60.0, ["armored", "armored", "skeleton", "skeleton"]]], "boss": "orc_king", "new": "최종 보스"},
]

static func count() -> int:
	return STAGES.size()

static func get_stage(stage_id: int) -> Dictionary:
	for s in STAGES:
		if s["id"] == stage_id:
			return s
	return {}

static func chapter(stage_id: int) -> Dictionary:
	return CHAPTERS[clampi((stage_id - 1) / 4, 0, CHAPTERS.size() - 1)]

static func unlocked(kind: String, stage_id: int) -> bool:
	return stage_id >= int(UNLOCK.get(kind, 1))

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
