extends Node
# Headless test for 블록 기사단 (LaneBattle): the compact layout, real-time walking and fighting,
# gold over time and from clears, the wallet limit and income upgrade, summon cooldowns, knockback,
# the cannon, enemy traits (flying, armor), charge/hold, the big wave and the boss at half the
# fortress, pausing for settings, auto mode, and the stage flow (docs/LANE_STAGES.md): the stage
# select, locked soldiers, a clear with stars that opens the next stage, a failed stage, and
# classic's layout coming back.
# Run: Godot_console.exe --headless --path . res://tests/test_lane.tscn

const MainScene: PackedScene = preload("res://scenes/main.tscn")
const USER_FILES: Array[String] = [
	"user://game_settings.json",
	"user://block_blast_save.cfg",
	"user://achievements.json",
	"user://lane_progress.json",
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

	if FileAccess.file_exists(LaneStages.PROGRESS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LaneStages.PROGRESS_PATH))
	main._start_battle()
	await get_tree().process_frame
	_expect(main.lane_select.visible, "the home card opens the stage select")
	var s2: Button = main.lane_select.rows.find_child("Stage2", true, false)
	_expect(s2 != null and s2.disabled, "stage 2 is locked at first")
	main._start_lane_stage(1)
	await _wait_until(func(): return not main._is_tray_empty() and not b.finished)
	_expect(not main.lane_select.visible and b.visible and b.stage == 1 and b.castle_hp == LaneBattle.CASTLE_HP and b.gold == LaneBattle.START_GOLD, "battle starts at stage 1")
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
	_expect(not b.summon("archer") and b.gold == 150, "the archer is locked on stage 1")
	_expect(b._locks["archer"].visible and not b._locks["knight"].visible, "locked buttons show a lock")
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

	# The boss comes when the fortress drops to half (borrow stage 3's slime king)
	_expect(b.boss_out, "stage 1 has no boss")
	b.stage_data = LaneStages.get_stage(3)
	b.boss_out = false
	b.fortress_hp = b.fortress_max * 0.49
	await get_tree().create_timer(0.3).timeout
	_expect(b.boss_out and b.units.any(func(u): return u.get("boss", false) and u["kind"] == "slime"), "the slime king appears at half the fortress")
	b.stage_data = LaneStages.get_stage(1)

	# Auto mode summons by itself and answers the lane
	for u in b.units.duplicate():
		b._kill(u)
	b._pending.clear()
	b.trickle_timer = 99.0
	b.next_wave_at = 9999.0
	for k in LaneBattle.ALLY_ORDER:
		b.cooldown[k] = 0.0
	_expect(b.auto_pick() == "knight", "auto starts with a knight")
	b.stage = 7 # every soldier open, to check the counters
	b.gold = 400
	b.toggle_auto()
	_expect(b.auto_summon, "auto mode on")
	await get_tree().create_timer(0.5).timeout
	_expect(b._count(1) >= 1, "auto mode summons without a tap (%d)" % b._count(1))
	var bat2 := b._spawn("bat", -1, 1.0)
	bat2["node"].position.x = 500.0
	_expect(b.auto_pick() == "archer", "auto answers a bat with an archer (%s)" % b.auto_pick())
	b._kill(bat2)
	var arm2 := b._spawn("armored", -1, 1.0)
	arm2["node"].position.x = 500.0
	_expect(b.auto_pick() == "spearman", "auto answers armor with a spear (%s)" % b.auto_pick())
	b._kill(arm2)
	b.stage = 1
	var bat3 := b._spawn("bat", -1, 1.0)
	bat3["node"].position.x = 500.0
	_expect(b.auto_pick() != "archer", "auto never picks a locked soldier")
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
	await _wait_until(func(): return main.game_over_panel.visible, 6.0)
	_expect(main.go_title.text == "STAGE 1 클리어!", "a broken fortress clears the stage (%s)" % main.go_title.text)
	_expect(LaneStages.load_progress()["unlocked"] == 2 and LaneStages.total_stars() >= 1, "the clear is saved and opens stage 2")
	_expect(main.go_btn_view_rank.visible and main.go_btn_view_rank.text == "다음 스테이지", "next stage button")
	main._on_go_primary_pressed()
	await _wait_until(func(): return b.stage == 2 and not b.finished and not main._is_tray_empty(), 6.0)
	_expect(b.stage == 2 and b.fortress_max == float(LaneStages.get_stage(2)["fortress"]) and b.castle_hp == LaneBattle.CASTLE_HP and b.gold >= LaneStages.start_gold(2), "stage 2 starts fresh")
	_expect(not b._locks["archer"].visible, "the archer opens on stage 2")

	# The castle falls: the run ends with the result window
	for u in b.units.duplicate():
		if u["side"] == 1:
			b._kill(u)
	var e2 := b._spawn("goblin", -1, 1.0)
	e2["node"].position.x = LaneBattle.ALLY_BASE_X + 10.0
	b.castle_hp = 1
	await _wait_until(func(): return main.game_over_panel.visible, 5.0)
	_expect(main.go_title.text == "STAGE 2 실패", "a fallen castle fails the stage (%s)" % main.go_title.text)
	_expect(LaneStages.load_progress()["unlocked"] == 2, "a failed stage opens nothing")

	# The house button in the lane leads back to the stage select
	main.game_over_panel.visible = false
	main.is_game_over = false
	main._start_lane_stage(1)
	await _wait_until(func(): return not main._is_tray_empty() and not b.finished)
	b.home_pressed.emit()
	await get_tree().process_frame
	_expect(main.lane_select.visible and not main.start_screen.visible and not b.visible, "the house button goes to the stage select")
	main.lane_select.close()
	await get_tree().process_frame
	_expect(main.start_screen.visible, "closing the stage select goes home")

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
