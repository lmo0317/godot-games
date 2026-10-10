extends Node
# Headless test for 블록 기사단 (LaneBattle): the compact layout, real-time walking and fighting,
# gold over time and from clears, the wallet limit and income upgrade, summon cooldowns, knockback,
# the cannon, enemy traits (flying, armor), charge/hold, the big wave and the boss at half the
# fortress, pausing for settings, auto mode, and the stage flow (docs/LANE_STAGES.md): the stage
# select, the deck (only deck soldiers can be summoned), soldier roles (tank, anti-air, siege,
# healer), a clear with stars, gems and a reward soldier that opens the next stage, a failed stage,
# the gacha and deck screens, and classic's layout coming back.
# Run: Godot_console.exe --headless --path . res://tests/test_lane.tscn

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const USER_FILES: Array[String] = [
	"user://game_settings.json",
	"user://block_blast_save.cfg",
	"user://achievements.json",
	"user://lane_progress.json",
	"user://lane_army.json",
]

var backups: Dictionary = {}
var failures: Array[String] = []
var main: MainGame

func _ready() -> void:
	Analytics.enabled = false
	for p in USER_FILES:
		if FileAccess.file_exists(p):
			backups[p] = FileAccess.get_file_as_bytes(p)
	_run.call_deferred()

func _run() -> void:
	main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.profile_setup_modal.visible = false
	SoundManager.is_muted = true
	SettingsManager.tutorial_state = "done"
	var b: LaneBattle = main.battle

	for path in [LaneStages.PROGRESS_PATH, LaneUnits.ARMY_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	main._start_battle()
	await get_tree().process_frame
	_expect(main.lane_select.visible, "the home card opens the stage select")
	var s2: TextureButton = main.lane_select.rows.find_child("Stage2", true, false)
	_expect(s2 != null and s2.disabled, "stage 2 is locked at first")
	main._start_lane_stage(1)
	await _wait_until(func(): return not main._is_tray_empty() and not b.finished)
	_expect(not main.lane_select.visible and b.visible and b.stage == 1 and b.castle_hp == LaneBattle.CASTLE_HP and b.gold <= LaneBattle.START_GOLD, "battle starts at stage 1")
	_expect(b.auto_summon, "auto mode is on by default")
	b.auto_summon = false # the checks below drive the battle by hand
	for u in b.units.duplicate():
		if u["side"] == 1:
			b._kill(u)
	for k in LaneBattle.ALLY_ORDER:
		b.cooldown[k] = 0.0
	_expect(b._count(-1) >= 1, "the fortress sends a first monster")
	_expect(is_equal_approx(main.board.scale.x, MainGame.COMPACT_SCALE), "board is shrunk in the battle")
	_expect(is_equal_approx(BlockPiece.board_scale, MainGame.COMPACT_SCALE), "held pieces match the board scale")
	_expect(main.tray_slots[0].y > MainGame.TRAY_SLOTS[0].y, "tray moved down")
	var tray_bottom: float = main.tray_slots[0].y + 80.0
	_expect(tray_bottom < 1280.0, "tray stays on screen")
	_expect(not main.btn_home.visible and not main.header_title.visible, "the header is hidden in the battle")
	_expect(main.board_background.position.y > b.size.y, "board sits under the lane and summon bar")
	# The combo glow keeps the shrunk board size
	main.combo_count = 3
	main._update_combo_aura()
	await get_tree().create_timer(0.35).timeout
	_expect(is_equal_approx(main.combo_aura.scale.x, MainGame.COMPACT_SCALE), "combo glow keeps the board scale (%.3f)" % main.combo_aura.scale.x)
	main.combo_count = 0
	main._update_combo_aura()

	# Real time: the monster walks toward the castle. Gold no longer trickles — only puzzle clears pay.
	var enemy: Dictionary = b.units[0]
	var x0: float = enemy["node"].position.x
	var g0: int = b.gold
	await get_tree().create_timer(1.2).timeout
	_expect(enemy["node"].position.x < x0, "the monster walks by itself (%.0f -> %.0f)" % [x0, enemy["node"].position.x])
	_expect(b.gold == g0, "gold stays put without clears (%d -> %d)" % [g0, b.gold])

	# Settings pause the battle
	main._open_settings()
	await get_tree().process_frame
	var xp: float = enemy["node"].position.x
	await get_tree().create_timer(0.5).timeout
	_expect(is_equal_approx(enemy["node"].position.x, xp), "the battle waits while settings are open")
	main.settings_modal.close()
	await get_tree().create_timer(0.3).timeout
	_expect(not b.paused, "the battle goes on after settings")

	# A clear pays gold
	g0 = b.gold
	_place_dot_clearing_row()
	await get_tree().create_timer(0.3).timeout
	_expect(b.gold >= g0 + LaneBattle.GOLD_PER_LINE, "a clear pays gold (%d -> %d)" % [g0, b.gold])

	# Summoning spends gold and starts that soldier's cooldown
	b.gold = 200
	b._gold_acc = 0.0
	_expect(b.summon("knight") and b.gold == 150 and b._count(1) == 1, "summon a knight for 50")
	_expect(not b.summon("knight") and b.gold == 150, "the knight is on cooldown")
	_expect(b.deck == ["knight", "archer", "", ""], "a new army starts with the knight and the archer (%s)" % [b.deck])
	_expect(not b.summon("mage") and b.gold == 150, "a soldier outside the deck can't be summoned")
	b.gold = 10
	b.cooldown["knight"] = 0.0
	_expect(not b.summon("knight"), "no summon without gold")

	# Wallet: gold stops at the limit, the upgrade raises it
	b.gold = b.wallet_max()
	await get_tree().create_timer(0.6).timeout
	_expect(b.gold == LaneBattle.WALLET_MAX[0], "gold stops at the wallet limit (%d)" % b.gold)
	_expect(b.upgrade_wallet() and b.wallet == 1 and b.gold == LaneBattle.WALLET_MAX[0] - LaneBattle.WALLET_COST[0], "income upgrade")
	_expect(b.wallet_max() == LaneBattle.WALLET_MAX[1], "a bigger wallet")

	# Next to each other they fight on their attack timers
	var knight: Dictionary = b.units.filter(func(u): return u["side"] == 1)[0]
	knight["node"].position.x = 300.0
	enemy["node"].position.x = 330.0
	var khp: float = knight["hp"]
	var ehp: float = enemy["hp"]
	await get_tree().create_timer(1.5).timeout
	_expect(knight["hp"] < khp and enemy["hp"] < ehp, "both sides hit (%.0f/%.0f, %.0f/%.0f)" % [knight["hp"], khp, enemy["hp"], ehp])

	# Knockback when the HP drops past a mark
	knight["hp"] = 999.0
	knight["max_hp"] = 999.0
	var gob := b._spawn("goblin", -1, 1.0)
	gob["node"].position.x = 420.0
	var gx: float = gob["node"].position.x
	b._hurt(gob, gob["max_hp"] * 0.6, true)
	_expect(gob["stun"] > 0.0, "a big hit knocks back")
	await get_tree().create_timer(0.4).timeout
	_expect(gob["node"].position.x > gx + 10.0, "knocked back toward its fortress (%.0f -> %.0f)" % [gx, gob["node"].position.x])

	# Cannon: clears charge it, one tap hurts every monster
	b.cannon = 0.0
	b.on_clear(3, 200)
	_expect(b.cannon > 40.0, "clears charge the cannon (%.0f)" % b.cannon)
	_expect(not b.fire_cannon(), "the cannon waits until full")
	b.cannon = 100.0
	var ghp: float = gob["hp"]
	_expect(b.fire_cannon() and b.cannon == 0.0, "fire the cannon")
	await get_tree().create_timer(1.0).timeout # the cannonball flies, then the blasts ripple
	_expect(gob["hp"] < ghp, "the cannon hurts monsters")

	# Traits: melee soldiers ignore bats, archers hit them; armor halves damage except spears
	var bat := b._spawn("bat", -1, 1.0)
	bat["node"].position.x = knight["node"].position.x + 20.0
	_expect(b._nearest_opponent(knight) != bat, "a knight cannot reach a bat")
	var archer := b._spawn("archer", 1, 1.0)
	archer["node"].position.x = bat["node"].position.x - 5.0
	_expect(b._nearest_opponent(archer) == bat, "an archer can target a bat")
	var arm := b._spawn("armored", -1, 1.0)
	var spear := b._spawn("spearman", 1, 1.0)
	_expect(is_equal_approx(b._damage(knight, arm), knight["atk"] * 0.5), "armor halves a knight's hit")
	_expect(is_equal_approx(b._damage(spear, arm), spear["atk"] * 2.0), "spears break armor")

	# Hold: soldiers fall back to the hold line
	b.toggle_march()
	_expect(not b.charging, "switch to hold")
	for u in b.units.duplicate():
		if u["side"] == -1:
			b._kill(u)
	spear["node"].position.x = 450.0
	spear["stun"] = 0.0
	b.trickle_timer = 99.0
	b.next_wave_at = 9999.0
	await get_tree().create_timer(1.5).timeout
	_expect(spear["node"].position.x < 450.0, "held soldiers walk back (%.0f)" % spear["node"].position.x)
	b.toggle_march()

	# The horn and a big wave (stage 1 재설계: four slimes in the first wave)
	b.next_wave_at = b.elapsed + 0.05
	await get_tree().create_timer(0.2).timeout
	_expect(b._pending.size() + b._count(-1) >= 2, "a big wave arrives (%d queued, %d out)" % [b._pending.size(), b._count(-1)])
	await get_tree().create_timer(3.5).timeout
	_expect(b._pending.is_empty(), "the wave has marched out")

	# 서유기 1장 재편: 1 호선봉(stun_roar), 2 백골정(multi_form), 3 흑웅정(bear_charge), 4 사오정(wave_push)
	_expect(not b.boss_out, "stage 1 has a boss (호선봉)")
	for u in b.units.duplicate():
		if u["side"] == -1 and not u.get("hero", false):
			b._kill(u)
	b.fortress_hp = b.fortress_max * 0.49
	await get_tree().create_timer(0.3).timeout
	_expect(b.boss_out and b.units.any(func(u): return u.get("boss", false) and u.get("stun_roar", false)), "호선봉 (stun_roar) appears at half the fortress")
	# 호선봉 포효: 전체 아군 2초 스턴
	var tiger_boss: Dictionary = b.units.filter(func(u): return u.get("boss", false))[0]
	var ally_for_roar := b._spawn("knight", 1, 1.0)
	ally_for_roar["stun"] = 0.0
	b._boss_stun_roar(tiger_boss)
	_expect(ally_for_roar["stun"] >= 1.9, "호선봉 포효가 아군을 2초 스턴 (%.2f)" % ally_for_roar["stun"])
	b._kill(ally_for_roar)
	b._kill(tiger_boss)
	# 백골정 3단 변신 (스테이지 2)
	b.stage_data = LaneStages.get_stage(2)
	b.boss_out = false
	b._boss_entry()
	var bone: Dictionary = b.units.filter(func(u): return u.get("boss", false))[0]
	_expect(int(bone.get("form_stage", 0)) == 0, "백골정 변신 전 (form 0)")
	bone["hp"] = bone["max_hp"] * 0.65
	await get_tree().create_timer(0.2).timeout
	_expect(int(bone.get("form_stage", 0)) == 1 and bone["shot"] == "orb", "백골정 70% → 원거리 (form 1)")
	bone["hp"] = bone["max_hp"] * 0.35
	await get_tree().create_timer(0.2).timeout
	_expect(int(bone.get("form_stage", 0)) == 2, "백골정 40% → 분신 (form 2)")
	b._kill(bone)
	# 흑웅정 돌진 (스테이지 3): 50% 이하에서 _boss_charge_run이 실행되면 아군 피해
	b.stage_data = LaneStages.get_stage(3)
	b.boss_out = false
	b._boss_entry()
	var bear: Dictionary = b.units.filter(func(u): return u.get("boss", false))[0]
	var charge_target := b._spawn("knight", 1, 1.0)
	charge_target["node"].position.x = 300.0
	var cx_hp: float = charge_target["hp"]
	b._charge_impact(bear)
	_expect(charge_target["hp"] < cx_hp, "흑웅정 돌진이 아군을 때림 (%.0f → %.0f)" % [cx_hp, charge_target["hp"]])
	b._kill(charge_target)
	b._kill(bear)
	b.stage_data = LaneStages.get_stage(1)

	# Roles: the tank takes less, the crossbow hits flyers hard, the cannoneer hits the fortress hard,
	# the cleric heals
	b.tiers = {}
	var tank := b._spawn("shield", 1, 1.0)
	var gob2 := b._spawn("goblin", -1, 1.0)
	_expect(is_equal_approx(b._damage(gob2, tank), gob2["atk"] * 0.7), "the shield bearer takes 30% less")
	var xb := b._spawn("crossbow", 1, 1.0)
	var bat4 := b._spawn("bat", -1, 1.0)
	_expect(is_equal_approx(b._damage(xb, bat4), xb["atk"] * 2.5), "the crossbow hits flyers 2.5x")
	var cn := b._spawn("cannoneer", 1, 1.0)
	_expect(is_equal_approx(b._damage(cn, "fortress"), cn["atk"] * 4.0), "the cannoneer hits the fortress 4x")
	var cl := b._spawn("cleric", 1, 1.0)
	tank["hp"] = tank["max_hp"] - 30.0
	tank["node"].position.x = cl["node"].position.x + 20.0
	b._heal_around(cl)
	_expect(tank["hp"] > tank["max_hp"] - 30.0, "the cleric heals")
	var legend := LaneUnits.stats("knight", 5)
	_expect(is_equal_approx(legend["hp"], LaneUnits.UNITS["knight"]["hp"] * 2.25), "a 전설 knight has +125% HP")
	for u in [tank, gob2, xb, bat4, cn, cl]:
		b._kill(u)

	# The 8 soldiers added on 2026-10-08: ice slows, the bard cheers, the cavalry's first hit,
	# the dragon rider flies over melee monsters
	_expect(LaneUnits.ORDER.size() == 16 and LaneUnits.ORDER.all(func(k): return b.tex.has(k)), "16 soldiers, all drawn")
	var ice := b._spawn("icemage", 1, 1.0)
	var gob3 := b._spawn("goblin", -1, 1.0)
	b._land_hit(ice, gob3, 1.0)
	_expect(gob3["slow_t"] > 0.0 and is_equal_approx(b._speed(gob3), gob3["speed"] * LaneBattle.SLOW_K), "the ice mage slows")
	var bard := b._spawn("bard", 1, 1.0)
	var friend := b._spawn("knight", 1, 1.0)
	friend["node"].position.x = bard["node"].position.x + 30.0
	b._cheer_around(bard)
	_expect(friend["buff_t"] > 0.0 and is_equal_approx(friend["buff"], 0.25), "the bard cheers friends nearby")
	var cav := b._spawn("cavalry", 1, 1.0)
	_expect(cav["charge"] == 3.0, "the cavalry charges")
	var dragon := b._spawn("dragon", 1, 1.0)
	dragon["node"].position.x = gob3["node"].position.x - 20.0
	var gob_target = b._target_for(gob3)
	_expect(dragon["flying"] and not (gob_target is Dictionary and gob_target == dragon), "melee monsters can't hit the dragon rider")
	for u in [ice, gob3, bard, friend, cav, dragon]:
		b._kill(u)
	var rng_t := RandomNumberGenerator.new()
	rng_t.seed = 5
	var seen := {}
	for i in range(4000):
		seen[LaneUnits.roll_kind(rng_t)] = true
	_expect(seen.size() == 16, "the gacha can give all 16 (%d seen)" % seen.size())

	# Auto mode summons by itself and answers the lane
	for u in b.units.duplicate():
		b._kill(u)
	b._pending.clear()
	b.trickle_timer = 99.0
	b.next_wave_at = 9999.0
	for k in LaneBattle.ALLY_ORDER:
		b.cooldown[k] = 0.0
	_expect(b.auto_pick() == "knight", "auto starts with a knight")
	b.deck = ["knight", "archer", "spearman", "crossbow"] # to check the counters
	b._rotation = b._auto_rotation()
	b.gold = 400
	b.toggle_auto()
	_expect(b.auto_summon, "auto mode on")
	await get_tree().create_timer(0.5).timeout
	_expect(b._count(1) >= 1, "auto mode summons without a tap (%d)" % b._count(1))
	var bat2 := b._spawn("bat", -1, 1.0)
	bat2["node"].position.x = 500.0
	_expect(b.auto_pick() == "crossbow", "auto answers a bat with the crossbow (%s)" % b.auto_pick())
	b._kill(bat2)
	var arm2 := b._spawn("armored", -1, 1.0)
	arm2["node"].position.x = 500.0
	b.gold = 400
	for k in LaneBattle.ALLY_ORDER:
		b.cooldown[k] = 0.0
	_expect(b.auto_pick() == "spearman", "auto answers armor with a spear (%s)" % b.auto_pick())
	b._kill(arm2)
	# A bat at the castle with only the starters: the archer, not another knight
	b.deck = ["knight", "archer", "", ""]
	b._rotation = b._auto_rotation()
	for u in b.units.duplicate():
		b._kill(u)
	b._spawn("knight", 1, 1.0)
	b.gold = 400
	for k in LaneBattle.ALLY_ORDER:
		b.cooldown[k] = 0.0
	var bat5 := b._spawn("bat", -1, 1.0)
	bat5["node"].position.x = 120.0
	_expect(b.auto_pick() == "archer", "a bat at the castle calls for the archer (%s)" % b.auto_pick())
	b._kill(bat5)
	# Old saves with only the knight get the archer
	var old := {"gems": 50, "owned": {"knight": 3}, "deck": ["knight", "", "", ""]}
	var f := FileAccess.open(LaneUnits.ARMY_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f.close()
	var migrated: Dictionary = LaneUnits.load_army()
	_expect(migrated["owned"].has("archer") and migrated["deck"].has("archer"), "old saves get the starter archer")
	_expect(migrated["owned"]["knight"]["tier"] == 0 and migrated["owned"]["knight"]["copies"] == 2, "an old level 3 becomes 2 copies to merge")
	LaneUnits.save_army(LaneUnits.default_army())
	b.deck = ["knight", "", "", ""]
	b._rotation = b._auto_rotation()
	var bat3 := b._spawn("bat", -1, 1.0)
	bat3["node"].position.x = 500.0
	_expect(b.auto_pick() in ["knight", ""], "auto only picks from the deck (%s)" % b.auto_pick())
	b._kill(bat3)
	b.toggle_auto()

	# 영웅 시스템 (2026-10-10 docs/HERO_SYSTEM_PLAN.md): 자동 소환, HP 바, 스킬, 영구 사망
	_expect(b.hero_id == "sanzang", "default hero is 삼장 (%s)" % b.hero_id)
	# 지금까지 테스트 흐름에서 영웅이 사망·제거되었을 수 있으므로 재소환해서 확인
	if b.hero_dead or not b.hero_unit.has("hp") or b.hero_unit["hp"] <= 0.0 or not b.units.has(b.hero_unit):
		b.hero_dead = false
		b._spawn_hero()
	_expect(b.hero_unit.has("hp") and b.hero_unit["hp"] > 0.0 and b.units.has(b.hero_unit), "영웅이 자동 소환됨")
	_expect(b._hero_hp_fill != null and b._hero_portrait != null, "영웅 HP 바 + 초상 UI 존재")
	# 영웅은 성 쪽 캐스터: role=caster, 자동 공격 없음, 전진 없음, 성 x좌표 고정
	_expect(b.hero_unit.get("role", "") == "caster", "영웅 role=caster")
	_expect(b.hero_unit["atk"] == 0.0 and b.hero_unit["speed"] == 0.0, "영웅은 자동 공격·전진 안 함")
	_expect(absf(b.hero_unit["node"].position.x - (LaneBattle.CASTLE_X + 44.0)) < 1.0, "영웅은 성 옆 x좌표에 고정 (%.1f)" % b.hero_unit["node"].position.x)
	# 전진 금지 확인: 적을 멀리 두고 1프레임 돌려도 x가 안 움직여야 함
	var hero_x0: float = b.hero_unit["node"].position.x
	await get_tree().create_timer(0.3).timeout
	_expect(absf(b.hero_unit["node"].position.x - hero_x0) < 1.0, "영웅이 전진하지 않음 (%.1f → %.1f)" % [hero_x0, b.hero_unit["node"].position.x])
	# 영웅 렌더 높이: 쫄몹의 1.5배 근처 (78px 목표, 65~95 허용)
	var hero_rendered_h: float = b.hero_unit["node"].texture.get_height() * b.hero_unit["node"].scale.y
	_expect(hero_rendered_h >= 65.0 and hero_rendered_h <= 95.0, "영웅 렌더 높이 ≈ 쫄몹의 1.5배 (%.1fpx)" % hero_rendered_h)
	# 스킬 발동: 삼장 "염불 결계" — 아군 전원 buff_t · buff_guard 적용
	var ally_for_skill := b._spawn("knight", 1, 1.0)
	b.hero_cool = 0.0
	_expect(b.activate_hero_skill() and b.hero_cool > 0.0, "삼장 스킬 발동 → 쿨 시작")
	_expect(ally_for_skill["buff_t"] > 0.0 and ally_for_skill.get("buff_guard", 0.0) >= 0.5, "염불 결계: 아군 피해 ½ 버프")
	b._kill(ally_for_skill)
	# 쿨 중에는 재발동 불가
	_expect(not b.activate_hero_skill(), "쿨 중에는 스킬 재발동 불가")
	# 영웅 사망 → 영구 (재소환 없음)
	b.hero_unit["hp"] = 0.0
	b._kill(b.hero_unit)
	_expect(b.hero_dead, "영웅 사망 → hero_dead=true")
	_expect(not b.activate_hero_skill(), "사망한 영웅은 스킬 발동 불가")
	# 손오공·저팔계·사오정 unlock API
	var test_army := LaneUnits.default_army()
	_expect(LaneUnits.unlock_hero(test_army, "wukong") and test_army["heroes_unlocked"].has("wukong"), "unlock_hero(wukong) → 추가")
	_expect(not LaneUnits.unlock_hero(test_army, "wukong"), "이미 가진 영웅은 다시 추가 안 함")
	_expect(test_army["selected_hero"] == "wukong", "새로 얻은 영웅으로 자동 선택")

	# Breaking the fortress moves to the next stage
	for u in b.units.duplicate():
		if u["side"] == -1:
			b._kill(u)
	b.trickle_timer = 99.0
	b.next_wave_at = 9999.0
	b._pending.clear()
	await get_tree().create_timer(0.6).timeout # let the boss shockwave knockback finish
	knight = b._spawn("knight", 1, 1.0)
	knight["hp"] = 999.0
	knight["stun"] = 0.0
	knight["node"].position.x = LaneBattle.ENEMY_BASE_X - 20.0
	b.fortress_hp = 1.0
	await _wait_until(func(): return main.lane_result.visible, 6.0)
	_expect(main.lane_result.title.get_child(0).text == "STAGE 1 클리어!", "a broken fortress clears the stage (%s)" % main.lane_result.title.get_child(0).text)
	_expect(LaneStages.load_progress()["unlocked"] == 2 and LaneStages.total_stars() >= 1, "the clear is saved and opens stage 2")
	# 스테이지 1 클리어 → 손오공 획득 (docs/HERO_SYSTEM_PLAN.md)
	_expect(LaneUnits.is_hero_unlocked("wukong"), "스테이지 1 클리어 → 손오공 획득")
	_expect(main.lane_result.back.text == "본부로 돌아가기" and main.lane_result.gems_label.text.begins_with("+"), "the result shows the gems and leads back to the base")
	var army0: Dictionary = LaneUnits.load_army()
	_expect(army0["owned"].size() == 2 and army0["owned"].has("knight") and army0["owned"].has("archer"), "clears give no soldiers, only gems (%s)" % [army0["owned"]])
	_expect(army0["gems"] >= LaneUnits.START_GEMS + LaneUnits.GEMS_FIRST, "the first clear pays gems (%d)" % army0["gems"])
	main.lane_result.back.pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_select.visible and main.lane_select.gem_bar_text().contains(str(army0["gems"])), "back at the base with the gems on top")
	main._start_lane_stage(2)
	await _wait_until(func(): return b.stage == 2 and not b.finished and not main._is_tray_empty(), 6.0)
	_expect(b.stage == 2 and b.fortress_max == float(LaneStages.get_stage(2)["fortress"]) and b.castle_hp == LaneBattle.CASTLE_HP and b.auto_summon, "stage 2 starts fresh, auto on again")
	_expect(b.deck == ["knight", "archer", "", ""] and b._slots[1]["name"].text == "궁수", "the battle uses the saved deck")

	# The castle falls: the run ends with the result window
	b.auto_summon = false # nobody comes to save the castle
	for u in b.units.duplicate():
		if u["side"] == 1:
			b._kill(u)
	var e2 := b._spawn("goblin", -1, 1.0)
	e2["node"].position.x = LaneBattle.ALLY_BASE_X + 10.0
	b.castle_hp = 1
	await _wait_until(func(): return main.lane_result.visible, 5.0)
	_expect(main.lane_result.title.get_child(0).text == "STAGE 2 실패", "a fallen castle fails the stage (%s)" % main.lane_result.title.get_child(0).text)
	_expect(LaneStages.load_progress()["unlocked"] == 2, "a failed stage opens nothing")
	_expect(main.lane_result.tip.text != "", "a lost stage gives advice (%s)" % main.lane_result.tip.text)

	# Sawtooth stages, recommended power and the advice after a loss (docs/LANE_STAGES.md 2장)
	for s in LaneStages.STAGES:
		_expect(LaneStages.ROLE_PACE.has(s.get("role", "")), "stage %d has a role" % s["id"])
		# 서유기 재편: 1~4는 전부 보스 스테이지, 5~16은 placeholder (boss="" 허용)
		if not bool(s.get("locked", false)):
			_expect((s["boss"] != "") == (s["role"] == "boss"), "stage %d: bosses and boss roles match" % s["id"])
	_expect(LaneStages.recommended_power(1) == 200, "stage 1 recommended power is 200")
	_expect(LaneStages.count() == 16, "16 stages total")
	# 서유기 재편: 1장 스테이지에는 bat/armored 조합이 없음 → 기본 조언 (권장 전투력)이 떠야 함
	var adv: Array = LaneStages.fail_advice(4, ["knight", "shield"], 100)
	_expect(not adv.is_empty(), "a lost stage gives at least one advice line (%s)" % [adv])
	var army_p := LaneUnits.default_army()
	_expect(LaneUnits.deck_power(army_p) == 200, "the two starters make 200 power")
	army_p["owned"]["knight"]["tier"] = 2
	_expect(LaneUnits.deck_power(army_p) == 250, "two tiers add 50 power")

	# The house button in the lane leads back to the stage select
	main.lane_result.visible = false
	main.is_game_over = false
	main._start_lane_stage(1)
	await _wait_until(func(): return not main._is_tray_empty() and not b.finished)
	b.home_pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_select.visible and not main.start_screen.visible and not b.visible, "the house button goes to the stage select")
	main.lane_select.close()
	await get_tree().process_frame
	_expect(main.start_screen.visible, "closing the stage select goes home")

	# Gacha and deck screens (outside battles)
	var army := LaneUnits.load_army()
	army["gems"] = 1000
	LaneUnits.save_army(army)
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	var res: Array = LaneUnits.pull(10, rng2)
	_expect(res.size() == 10 and LaneUnits.load_army()["gems"] == 100 + res.reduce(func(acc, r): return acc + r["refund"], 0), "ten pulls cost 900")
	_expect(res.any(func(r): return LaneUnits.UNITS[r["kind"]]["tier"] >= 1), "ten pulls give a 레어 or better")
	_expect(LaneUnits.pull(10, rng2).is_empty(), "no pull without gems")
	main.lane_select.open()
	_expect(main.lane_select.power_label.text.begins_with("내 덱 전투력 %d" % LaneUnits.deck_power()), "the base shows the deck power (%s)" % main.lane_select.power_label.text)
	_expect(main.lane_select.find_child("Rec", true, false) != null, "open stages show their recommended power")
	main.lane_select.gacha_pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_gacha.visible, "the base opens the gacha")
	# The card pack: pay, rip it open, cards face down, flip one, flip all, the result stays
	var ag := LaneUnits.load_army()
	ag["gems"] = 1000
	LaneUnits.save_army(ag)
	var g: LaneGacha = main.lane_gacha
	g._refresh()
	var got: Array = g.pull(10)
	_expect(got.size() == 10 and g.pull1.disabled and g.back.disabled and g._pack.visible, "a pull puts the sealed pack in play and locks the buttons")
	g.open_pack()
	await _wait_until(func(): return g._cards.size() == 10, 3.0)
	_expect(g._table.visible and g._cards.size() == 10 and g._cards.all(func(c): return not c["open"]), "ten cards are dealt face down")
	g.flip(g._cards[0], true)
	_expect(g._cards[0]["open"], "a tap flips a card")
	g.flip_all()
	var waited := 0.0
	while waited < 15.0 and not g._sum_ok.visible:
		g._advance = true
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
	_expect(g._sum_ok.visible and g._cards.all(func(c): return c["open"]) and g._table_line.text.begins_with("새 병사"), "all flipped: the result stays with the 3 action buttons")
	# [본부로] (now _sum_deck) closes the gacha back to the home base
	g._sum_deck.pressed.emit()
	_expect(not g._busy and not g._table.visible and not g.visible, "본부로 closes the gacha")
	main.lane_gacha.open()
	main.lane_gacha.close()
	main.lane_select.deck_pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_deck.visible, "the base opens the deck screen")
	# Merging copies raises the star tier
	var army3 := LaneUnits.load_army()
	army3["owned"]["knight"] = {"tier": 0, "copies": 3}
	army3["gems"] = 1000 # merges cost gems since 2026-10-09
	LaneUnits.save_army(army3)
	_expect(LaneUnits.can_merge("knight") and LaneUnits.merge("knight") == 1, "1 copy merges a 노멀 knight into 레어")
	_expect(LaneUnits.merge("knight") == 2 and LaneUnits.load_army()["owned"]["knight"]["copies"] == 0, "2 more copies make it 유니크")
	_expect(LaneUnits.merge("knight") == -1, "no merge without copies")
	_expect(is_equal_approx(LaneUnits.stats("knight", 2)["atk"], LaneUnits.UNITS["knight"]["atk"] * 1.5), "유니크 knight hits 50% harder")
	army3 = LaneUnits.load_army()
	army3["owned"]["archer"] = {"tier": 0, "copies": 1}
	army3["gems"] = 1000
	LaneUnits.save_army(army3)
	main.lane_deck.selected = "archer"
	main.lane_deck.refresh()
	_expect(not main.lane_deck.merge_btn.disabled, "the merge button is ready with enough copies")
	main.lane_deck._on_merge()
	_expect(LaneUnits.tier_of("archer") == 1 and main.lane_deck.merge_btn.disabled, "merging from the deck screen")
	var spare: String = ""
	for k in LaneUnits.load_army()["owned"]:
		if not LaneUnits.deck().has(k):
			spare = k
	if spare != "":
		LaneUnits.set_deck_slot(3, spare)
		_expect(LaneUnits.deck()[3] == spare, "put %s in the deck" % spare)
	LaneUnits.set_deck_slot(0, "")
	LaneUnits.set_deck_slot(1, "")
	LaneUnits.set_deck_slot(2, "")
	LaneUnits.set_deck_slot(3, "")
	_expect(LaneUnits.deck().any(func(k): return k != ""), "the deck never goes empty")
	main.lane_deck.close()
	main.lane_select.visible = false

	# Pity, universal shards and bulk merge (2026-10-09 재설계)
	LaneUnits.save_army(LaneUnits.default_army())
	var army4 := LaneUnits.load_army()
	_expect(army4.has("pulls_since_unique") and army4.has("pulls_since_legendary") and army4.has("universal_shards") and army4.has("auto_flip"), "new army fields exist")
	# Soft pity: force 20 pulls_since_unique, then a 10-pull must include a 유니크+
	army4["gems"] = 100000
	army4["pulls_since_unique"] = LaneUnits.PITY_UNIQUE
	LaneUnits.save_army(army4)
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = 42
	var pres: Array = LaneUnits.pull(10, rng3)
	_expect(pres.any(func(r): return LaneUnits.UNITS[r["kind"]]["tier"] >= 2), "pity: next 10 pulls include a 유니크+")
	_expect(LaneUnits.load_army()["pulls_since_unique"] <= LaneUnits.PITY_UNIQUE, "pity counter does not go up without need")
	# Shard: a 전설 duplicate gives a universal shard, not gems
	var army5 := LaneUnits.load_army()
	army5["owned"]["dragon"] = {"tier": LaneUnits.MAX_TIER, "copies": 0}
	army5["universal_shards"] = 0
	LaneUnits.save_army(army5)
	var res_shard: Dictionary = LaneUnits.add_unit(army5, "dragon")
	_expect(int(res_shard.get("shard", 0)) == 1 and int(army5["universal_shards"]) == 1, "전설 중복 → 💎 파편 +1 (not gems)")
	# Shard spend: converts to a copy of any owned soldier not at max
	army5["owned"]["knight"] = {"tier": 0, "copies": 0}
	LaneUnits.save_army(army5)
	_expect(LaneUnits.spend_shard("knight") and LaneUnits.load_army()["owned"]["knight"]["copies"] == 1 and LaneUnits.load_army()["universal_shards"] == 0, "spend_shard: +1 copy, -1 shard")
	# Gem cost: without gems, merge/can_merge fail
	var army6 := LaneUnits.load_army()
	army6["owned"]["knight"] = {"tier": 0, "copies": 1}
	army6["gems"] = 0
	LaneUnits.save_army(army6)
	_expect(LaneUnits.has_copies("knight") and not LaneUnits.can_merge("knight"), "no gems: can_merge false (but copies ready)")
	_expect(LaneUnits.merge("knight") == -1, "no gems: merge refuses")
	army6["gems"] = 50
	LaneUnits.save_army(army6)
	_expect(LaneUnits.can_merge("knight") and LaneUnits.merge("knight") == 1 and LaneUnits.load_army()["gems"] == 0, "gems + copies: merge spends both")
	# Bulk / max chain stops where resources run out
	var army7 := LaneUnits.load_army()
	army7["owned"]["knight"] = {"tier": 0, "copies": 10}
	army7["gems"] = 50 + 150  # covers 노멀→레어 and 레어→유니크; stops before 유니크→레전더리
	LaneUnits.save_army(army7)
	# Open the deck for the detail bulk button
	main.lane_deck.open()
	main.lane_deck.selected = "knight"
	main.lane_deck._show_info(LaneUnits.load_army())
	main.lane_deck._on_bulk_merge()
	_expect(LaneUnits.tier_of("knight") == 2, "bulk merge chains to 유니크 (2) and stops when gems run out: %d" % LaneUnits.tier_of("knight"))
	# Auto-flip toggle saves
	LaneUnits.set_auto_flip(true)
	_expect(bool(LaneUnits.load_army()["auto_flip"]), "auto_flip saved")
	LaneUnits.set_auto_flip(false)
	main.lane_deck.close()

	# The home lobby: tabs open the gacha and the soldiers screen and come back home, gems on top
	main._open_home_screen()
	await get_tree().process_frame
	_expect(main.start_screen.gem_label.text == str(LaneUnits.load_army()["gems"]), "the home shows the gems")
	var gems_before: int = LaneUnits.load_army()["gems"]
	main.start_screen.gem_add.pressed.emit()
	_expect(LaneUnits.load_army()["gems"] == gems_before + HomeScreen.DEV_GEMS and main.start_screen.gem_label.text == str(gems_before + HomeScreen.DEV_GEMS), "the test + button adds gems")
	main.start_screen.reset_btn.pressed.emit()
	_expect(LaneUnits.load_army()["gems"] > LaneUnits.START_GEMS, "one tap on reset only arms it")
	main.start_screen.reset_btn.pressed.emit()
	_expect(LaneUnits.load_army()["gems"] == LaneUnits.START_GEMS and LaneStages.load_progress()["unlocked"] == 1 and main.start_screen.gem_label.text == str(LaneUnits.START_GEMS), "two taps reset 블록 기사단")
	main.start_screen.gacha_pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_gacha.visible, "the home gacha tab opens the gacha")
	main.lane_gacha.close()
	main.start_screen.deck_pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_deck.visible, "the home soldiers tab opens the soldiers screen")
	main.lane_deck.close()
	await get_tree().process_frame
	_expect(main.start_screen.visible and not main.lane_select.visible, "closing goes back to the home")
	main.start_screen.battle_pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_select.visible, "출전 opens the stage select")
	main.lane_select.visible = false

	# 전투만 모드 smoke test (dev, 2026-10-11): 덱 4명만, 보드/트레이 숨김, 트리클 금화
	main.start_screen.visible = true
	main._start_battle_only()
	await _wait_until(func(): return b.battle_only_mode and not b.finished, 4.0)
	_expect(b.battle_only_mode and not b.test_mode, "battle-only: flag on, test_mode off")
	_expect(not main.board.visible and not main.board_background.visible, "battle-only: board hidden")
	_expect(not main.get_node("TrayPlates").visible, "battle-only: tray hidden")
	_expect(main.tray_pieces[0] == null and main.tray_pieces[1] == null and main.tray_pieces[2] == null, "battle-only: no block pieces in tray")
	_expect(b._bo_panel != null and b._bo_panel.visible, "battle-only: bottom summon panel built")
	_expect(b._bo_slots.size() == 4, "battle-only: 4 deck slots")
	var g_start: int = b.gold
	b.gold = 10
	b._gold_acc = 0.0
	await get_tree().create_timer(1.3).timeout
	_expect(b.gold > 10, "battle-only: gold trickles up (%d)" % b.gold)
	# 자동 wave: trickle timer가 돌아 쫄몹이 나와야 함
	_expect(b.trickle_timer < 10.0, "battle-only: waves still running (trickle %.1f)" % b.trickle_timer)
	# 덱만 소환 가능 (test_mode의 "모든 유닛"과 다름): 덱 밖은 거부
	var not_in_deck := ""
	for k in LaneBattle.ALLY_ORDER:
		if not b.deck.has(k):
			not_in_deck = k
			break
	if not_in_deck != "":
		b.gold = 300
		b.cooldown[not_in_deck] = 0.0
		_expect(not b.summon(not_in_deck), "battle-only: deck 밖 유닛 소환 거부 (%s)" % not_in_deck)
	# 홈 복귀로 플래그 해제 + UI 복원
	b.home_pressed.emit()
	await get_tree().process_frame
	_expect(not b.battle_only_mode and main.lane_select.visible, "battle-only: 홈 복귀로 flag 해제")
	main.lane_select.close()
	await get_tree().process_frame

	# Classic gets the normal layout back
	main.game_over_panel.visible = false
	main._on_start_play_pressed()
	await _wait_until(func(): return not main._is_tray_empty())
	_expect(is_equal_approx(main.board.scale.x, 1.0) and not b.visible, "classic uses the normal layout")
	_expect(main.tray_slots[0] == MainGame.TRAY_SLOTS[0], "tray back in place")
	_expect(main.btn_home.visible and main.header_title.visible, "the header comes back for classic")
	_finish()

func _any_piece() -> BlockPiece:
	for p in main.tray_pieces:
		if p != null and is_instance_valid(p):
			return p
	main._spawn_new_tray()
	return main.tray_pieces[0]

func _place_dot_at(x: int, y: int) -> void:
	var piece := _any_piece()
	piece.setup(BlockData.SHAPES[0], piece.slot_index, piece.tray_position)
	piece.global_position = main.board.to_global(main.board.get_cell_position(x, y))
	_expect(main._commit_placement(piece), "piece placed at %d,%d" % [x, y])

func _place_dot_clearing_row() -> void:
	main.board.load_layout(["kkkkkkk.", "........", "........", "........", "........", "........", "........", "........"])
	_place_dot_at(7, 0)

func _place_dot_no_clear() -> void:
	main.board.load_layout(["........", "........", "........", "........", "........", "........", "........", "........"])
	_place_dot_at(3, 3)

func _wait_until(cond: Callable, limit: float = 6.0) -> void:
	var t := 0.0
	while t < limit and not cond.call():
		await get_tree().create_timer(0.05).timeout
		t += 0.05

func _expect(cond: bool, msg: String) -> void:
	if not cond and not failures.has(msg):
		failures.append(msg)

func _finish() -> void:
	for p in USER_FILES:
		if backups.has(p):
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(backups[p])
			f.close()
		elif FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	if failures.is_empty():
		print("LANE OK")
	else:
		for f in failures:
			printerr("FAIL: " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
