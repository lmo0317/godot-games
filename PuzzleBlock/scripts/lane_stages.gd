class_name LaneStages
extends RefCounted
# 블록 기사단 stages (docs/LANE_STAGES.md): 4 chapters x 6 stages, played one at a time from the
# stage select. Each stage: fortress HP, monster power, single-monster interval and pool, scripted
# waves, an optional boss at half the fortress, and the soldiers available.

const PROGRESS_PATH: String = "user://lane_progress.json"

# 서유기 4장 재편 (2026-10-10 docs/JOURNEY_WEST_PLAN.md): 1장만 리소스 제작, 5~16은 "준비 중"
const CHAPTERS: Array[Dictionary] = [
	{"name": "1장 동녘 길 떠남", "tint": Color(1, 1, 1)},
	{"name": "2장 서역 길목",   "tint": Color(1.0, 0.72, 0.58)},
	{"name": "3장 거친 땅",     "tint": Color(0.52, 0.56, 0.86)},
	{"name": "4장 영산을 향해", "tint": Color(1.0, 0.5, 0.46)},
]
const PER_CHAPTER: int = 4

# 서유기 16스테이지: 4챕터 × 4 (더 가파름). 5~16은 준비 중이지만 EXPECTED는 채워둠.
const EXPECTED: Array[float] = [0.0, 0.4, 0.7, 1.0,
	1.2, 1.3, 1.5, 1.7,
	1.9, 2.0, 2.1, 2.3,
	2.5, 2.6, 2.75, 2.9]

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
	# 서유기 1장 (2026-10-10 docs/JOURNEY_WEST_PLAN.md). 신규 trait:
	# stun_roar (주기마다 전체 아군 2초 스턴), multi_form (HP 70%/40% 변신, 3단), charge (HP 50% 이하 돌진),
	# wave_push (5초마다 전장 전체 아군 뒤로 밀기)
	"tiger_vanguard": {"name": "호선봉", "kind": "tiger_mob", "tex": "boss_tiger_vanguard", "hint": "포효로 아군을 2초간 얼려요",
		"hp": 6.0, "atk": 2.2, "scale": 2.0, "kb": 4, "stun_roar": true},
	"white_bone": {"name": "백골정", "kind": "skeleton", "tex": "boss_white_bone", "hint": "체력 70%·40%에 모습이 바뀌어요",
		"hp": 7.0, "atk": 2.0, "scale": 1.9, "kb": 4, "multi_form": true},
	"black_bear": {"name": "흑웅정", "kind": "bandit", "tex": "boss_black_bear", "hint": "체력 절반 이하가 되면 전장을 돌파해요",
		"hp": 8.0, "atk": 2.4, "scale": 2.2, "kb": 5, "charge": true},
	"sand_monk": {"name": "사오정 (요괴)", "kind": "water_ghoul", "tex": "boss_sand_monk", "hint": "물결을 일으켜 아군을 뒤로 밀어요",
		"hp": 9.0, "atk": 2.3, "scale": 2.0, "kb": 5, "wave_push": true},
}

# 2026-10-10 서유기 재편 (docs/JOURNEY_WEST_PLAN.md + HERO_SYSTEM_PLAN.md).
# 1~4는 상세, 5~16은 "준비 중" 플레이스홀더 (locked=true). reward_hero는 스테이지 첫 클리어 보상.
# waves: [seconds after the start, [monster kinds]]; after the last one it repeats every 40 s.
const STAGES: Array[Dictionary] = [
	# 1장 — 동녘 길 떠남 (서유기 1장)
	{"id": 1, "name": "오지산", "role": "boss", "fortress": 1200, "power": 0.95, "every": 11.0, "pool": ["tiger_mob"], "swarm": false,
		"waves": [[25.0, ["tiger_mob", "tiger_mob", "tiger_mob"]], [50.0, ["tiger_mob", "tiger_mob", "tiger_mob", "tiger_mob"]]],
		"boss": "tiger_vanguard", "bg": "bg_mt_wuzhi", "clear_gem": 220, "reward_hero": "wukong",
		"new": "손오공이 봉인에서 풀려나려 해요. 호랑이 요괴를 몰아내요"},
	{"id": 2, "name": "백골산", "role": "boss", "fortress": 1500, "power": 1.08, "every": 10.0, "pool": ["skeleton", "tiger_mob"],
		"waves": [[20.0, ["skeleton", "skeleton", "skeleton"]], [45.0, ["skeleton", "skeleton", "skeleton", "skeleton"]]],
		"boss": "white_bone", "bg": "bg_white_bone", "clear_gem": 260, "reward_hero": "bajie",
		"new": "백골정이 세 번 모습을 바꿔요"},
	{"id": 3, "name": "흑풍산", "role": "boss", "fortress": 1800, "power": 1.22, "every": 10.0, "pool": ["bandit", "tiger_mob"],
		"waves": [[20.0, ["bandit", "bandit", "bandit"]], [45.0, ["bandit", "bandit", "bandit", "bandit"]]],
		"boss": "black_bear", "bg": "bg_black_wind", "clear_gem": 300,
		"new": "흑웅정이 절반 체력부터 돌진해요"},
	{"id": 4, "name": "유사하", "role": "boss", "fortress": 2200, "power": 1.38, "every": 10.0, "pool": ["water_ghoul", "bandit"],
		"waves": [[20.0, ["water_ghoul", "water_ghoul"]], [45.0, ["water_ghoul", "water_ghoul", "water_ghoul", "bandit"]]],
		"boss": "sand_monk", "bg": "bg_flowing_sand", "clear_gem": 360, "reward_hero": "wujing",
		"new": "사오정의 물결에 밀리지 마세요"},
	# 5~16 플레이스홀더 (리소스 다음 세션). locked=true, 쇼케이스에서 "준비 중"으로 표시.
	{"id": 5,  "name": "오계국",       "role": "boss", "fortress": 2800, "power": 1.5, "every": 10.0, "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 6,  "name": "평정산",       "role": "boss", "fortress": 3200, "power": 1.6, "every": 10.0, "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 7,  "name": "반사동",       "role": "boss", "fortress": 3700, "power": 1.7, "every": 10.0, "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 8,  "name": "비파정",       "role": "boss", "fortress": 4300, "power": 1.8, "every": 10.0, "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 9,  "name": "호산",         "role": "boss", "fortress": 5000, "power": 1.9, "every": 9.0,  "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 10, "name": "흑수하",       "role": "boss", "fortress": 5500, "power": 2.0, "every": 9.0,  "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 11, "name": "통천하",       "role": "boss", "fortress": 6200, "power": 2.1, "every": 9.0,  "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 12, "name": "거지국",       "role": "boss", "fortress": 7000, "power": 2.2, "every": 9.0,  "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 13, "name": "소뇌음사",     "role": "boss", "fortress": 7800, "power": 2.3, "every": 8.0,  "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 14, "name": "금두동",       "role": "boss", "fortress": 8600, "power": 2.4, "every": 8.0,  "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 15, "name": "화염산",       "role": "boss", "fortress": 9500, "power": 2.5, "every": 8.0,  "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
	{"id": 16, "name": "서천 영산",    "role": "boss", "fortress": 11000, "power": 2.7, "every": 8.0, "pool": ["bandit"], "waves": [], "boss": "", "locked": true, "new": "준비 중"},
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
	if kinds.has("bat") and not has.call(["archer", "crossbow", "mage", "cannoneer", "cleric", "icemage", "bard", "dragon"]):
		lines.append("박쥐는 원거리 병사(궁수·석궁병·용기사)만 맞혀요")
	elif kinds.count("bat") >= 4 and not deck.has("crossbow"):
		lines.append("박쥐 떼는 석궁병이 2.5배로 잡아요")
	if (kinds.has("armored") or kinds.has("golem")) and not has.call(["spearman", "cannoneer", "hero"]):
		lines.append("갑옷·골렘은 창병·대포병·영웅 검사가 강해요")
	if kinds.has("priest") and not has.call(["archer", "crossbow", "mage", "icemage", "dragon"]):
		lines.append("회복하는 사제는 원거리로 먼저 잡아요")
	if (kinds.count("slime") >= 4 or kinds.count("goblin") >= 4) and not has.call(["mage", "cannoneer", "berserker", "hero", "dragon"]):
		lines.append("떼로 오는 적은 마법사·광전사 광역으로")
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

# Test reset (the home's "리셋"): stage 1 again, no stars
static func reset_progress() -> void:
	if FileAccess.file_exists(PROGRESS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESS_PATH))

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
