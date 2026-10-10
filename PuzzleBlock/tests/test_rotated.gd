extends Node
# 90° 회전된 세로 전투 테스트 모드 스모크: 소환 + 몇 초 돌림

func _ready() -> void:
	var MainScene: PackedScene = load("res://scenes/main.tscn")
	var main = MainScene.instantiate()
	add_child(main)
	await get_tree().process_frame
	main.profile_setup_modal.visible = false
	main._start_vertical_battle()
	await get_tree().create_timer(2.0).timeout
	var b: LaneBattle = main.battle
	assert(b.test_mode, "test_mode true 여야 함")
	assert(b.test_rotated, "test_rotated true 여야 함")
	assert(b._view.rotation != 0.0, "_view 회전됨")
	# 아군, 적 소환
	b.summon("knight")
	b.summon("archer")
	b._spawn_enemy("goblin", 1.0)
	b._spawn_enemy("slime", 1.0)
	var t: float = 0.0
	while t < 2.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	assert(b.units.size() >= 2, "유닛이 모두 사라짐")
	print("ROTATED OK  (units=%d, castle=%d, fort=%d)" % [b.units.size(), b.castle_hp, int(b.fortress_hp)])
	get_tree().quit()
