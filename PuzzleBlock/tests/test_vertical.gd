extends Node
# 세로 전투 스모크 테스트: 씬을 띄우고 몇 초 돌려 유닛이 움직이고 HP가 변하는지 확인.

func _ready() -> void:
	var vb := VerticalBattle.new()
	add_child(vb)
	await get_tree().process_frame
	vb.start()
	# 아군 2명, 적 3명 소환해 2초 돌림
	vb._summon("knight", true)
	vb._summon("archer", true)
	vb._summon("goblin", false)
	vb._summon("slime", false)
	vb._summon("wolf", false)
	var t0: float = 0.0
	while t0 < 2.0:
		await get_tree().process_frame
		t0 += get_process_delta_time()
	assert(vb.units.size() >= 2, "유닛이 전부 사라졌음")
	# 유닛이 바라던 방향으로 움직였는지(아군은 y 감소, 적은 y 증가)
	var moved: bool = false
	for u in vb.units:
		if u["ally"] and u["pos"].y < vb.CASTLE_Y - 65:
			moved = true
			break
		if not u["ally"] and u["pos"].y > vb.FORT_Y + 65:
			moved = true
			break
	assert(moved, "2초 지났는데 유닛이 안 움직임")
	print("VERTICAL OK  (units=%d, castle=%.0f, fort=%.0f)" % [vb.units.size(), vb.castle_hp, vb.fort_hp])
	get_tree().quit()
