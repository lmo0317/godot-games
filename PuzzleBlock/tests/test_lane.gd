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

	# Real time: the monster walks toward the castle and gold trickles in without any move
	var enemy: Dictionary = b.units[0]
	var x0: float = enemy["node"].position.x
	var g0: int = b.gold
	await get_tree().create_timer(1.2).timeout
	_expect(enemy["node"].position.x < x0, "the monster walks by itself (%.0f -> %.0f)" % [x0, enemy["node"].position.x])
	_expect(b.gold > g0, "gold trickles in over time (%d -> %d)" % [g0, b.gold])

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

	# The horn and a big wave (stage 1: three slimes)
	b.next_wave_at = b.elapsed + 0.05
	await get_tree().create_timer(0.2).timeout
	_expect(b._pending.size() + b._count(-1) >= 2, "a big wave arrives (%d queued, %d out)" % [b._pending.size(), b._count(-1)])
	await get_tree().create_timer(1.6).timeout
	_expect(b._pending.is_empty(), "the wave has marched out")

	# The boss comes when the fortress drops to half (borrow stage 6's slime king)
	_expect(b.boss_out, "stage 1 has no boss")
	b.stage_data = LaneStages.get_stage(6)
	b.boss_out = false
	b.fortress_hp = b.fortress_max * 0.49
	await get_tree().create_timer(0.3).timeout
	_expect(b.boss_out and b.units.any(func(u): return u.get("boss", false) and u["kind"] == "slime"), "the slime king appears at half the fortress")
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
	for u in b.units.duplicate():
		if u["side"] == 1:
			b._kill(u)
	var e2 := b._spawn("goblin", -1, 1.0)
	e2["node"].position.x = LaneBattle.ALLY_BASE_X + 10.0
	b.castle_hp = 1
	await _wait_until(func(): return main.lane_result.visible, 5.0)
	_expect(main.lane_result.title.get_child(0).text == "STAGE 2 실패", "a fallen castle fails the stage (%s)" % main.lane_result.title.get_child(0).text)
	_expect(LaneStages.load_progress()["unlocked"] == 2, "a failed stage opens nothing")

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
	main.lane_select.gacha_pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_gacha.visible, "the base opens the gacha")
	main.lane_gacha.close()
	main.lane_select.deck_pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_deck.visible, "the base opens the deck screen")
	# Merging copies raises the star tier
	var army3 := LaneUnits.load_army()
	army3["owned"]["knight"] = {"tier": 0, "copies": 3}
	LaneUnits.save_army(army3)
	_expect(LaneUnits.can_merge("knight") and LaneUnits.merge("knight") == 1, "1 copy merges a 노멀 knight into 레어")
	_expect(LaneUnits.merge("knight") == 2 and LaneUnits.load_army()["owned"]["knight"]["copies"] == 0, "2 more copies make it 유니크")
	_expect(LaneUnits.merge("knight") == -1, "no merge without copies")
	_expect(is_equal_approx(LaneUnits.stats("knight", 2)["atk"], LaneUnits.UNITS["knight"]["atk"] * 1.5), "유니크 knight hits 50% harder")
	army3 = LaneUnits.load_army()
	army3["owned"]["archer"] = {"tier": 0, "copies": 1}
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

	# The home lobby: tabs open the gacha and the soldiers screen and come back home, gems on top
	main._open_home_screen()
	await get_tree().process_frame
	_expect(main.start_screen.gem_label.text == str(LaneUnits.load_army()["gems"]), "the home shows the gems")
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
