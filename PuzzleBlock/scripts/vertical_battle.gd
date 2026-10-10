class_name VerticalBattle
extends Control
# 진짜 세로 레인 전투 테스트 모드 (dev, 2026-10-11).
#
# 화면 레이아웃 (720 x 1280):
#   y   0..60     상단 요새 HP 바
#   y  60..980    전장 (아군은 아래→위, 적은 위→아래)
#   y 980..1280   하단 소환 패널 (아군·적 유닛 버튼, 영웅 스킬, 홈 버튼)
#
# 성(아군) = 화면 바닥 중앙 (360, 920), 요새(적) = 상단 중앙 (360, 60)
# 유닛 데이터는 LaneBattle.ALLIES / LaneBattle.ENEMIES 를 그대로 재사용 (중복 금지)
# 금화·쿨다운·덱 없이 자유 소환 (사용자 "느낌" 확인용)

signal home_pressed

const W: float = 720.0
const H: float = 1280.0
const FIELD_TOP: float = 60.0
const FIELD_BOTTOM: float = 980.0
const PANEL_TOP: float = 980.0
const CASTLE_Y: float = 920.0        # 아군 성 중심
const FORT_Y: float = 100.0           # 적 요새 중심
const LANE_CX: float = 360.0
const LANE_HALF_W: float = 140.0     # 좌우 흔들림 허용 범위
const CASTLE_HP_MAX: float = 800.0
const FORT_HP_MAX: float = 1200.0
const UNIT_SCALE: float = 1.4
const BAR_W: float = 44.0
const BAR_H: float = 5.0

var castle_hp: float = CASTLE_HP_MAX
var fort_hp: float = FORT_HP_MAX
var elapsed: float = 0.0
var finished: bool = false
var units: Array = []                 # 각 유닛 Dictionary (아래 _spawn 참고)
var tex_cache: Dictionary = {}
var rng := RandomNumberGenerator.new()

# 영웅
var hero_id: String = "sanzang"
var hero_unit: Dictionary = {}
var hero_cool: float = 0.0

# UI 노드
var _field: Node2D
var _bars_layer: Control
var _panel: Panel
var _castle_hp_fill: ColorRect
var _fort_hp_fill: ColorRect
var _castle_hp_label: Label
var _fort_hp_label: Label
var _result_label: Label
var _hero_skill_btn: Button
var _hero_cool_fill: ColorRect

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	position = Vector2.ZERO
	size = Vector2(W, H)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rng.randomize()
	_load_textures()
	_build_scene()

func start() -> void:
	castle_hp = CASTLE_HP_MAX
	fort_hp = FORT_HP_MAX
	elapsed = 0.0
	finished = false
	hero_cool = 0.0
	for u in units:
		if u.has("node") and is_instance_valid(u["node"]):
			u["node"].queue_free()
		if u.has("bar") and is_instance_valid(u["bar"]):
			u["bar"].queue_free()
	units.clear()
	_spawn_hero()
	_update_hp_bars()
	_result_label.visible = false
	visible = true
	set_process(true)

func stop() -> void:
	set_process(false)

# ---------------------------------------------------------------------------

func _load_textures() -> void:
	var names: Array = ["castle", "fortress"]
	names.append_array(LaneBattle.ALLY_ORDER)
	names.append_array(LaneBattle.ENEMIES.keys())
	names.append_array(["hero_sanzang", "hero_wukong", "hero_bajie", "hero_wujing"])
	for k in names:
		var path := "res://assets/art/lane/%s.png" % k
		if ResourceLoader.exists(path):
			tex_cache[k] = load(path)

func _build_scene() -> void:
	# 하늘 배경
	var sky := ColorRect.new()
	sky.color = Color("#2b3b5c")
	sky.position = Vector2(0, 0)
	sky.size = Vector2(W, FIELD_BOTTOM)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	# 지면
	var ground := ColorRect.new()
	ground.color = Color("#3b5a2a")
	ground.position = Vector2(0, FIELD_BOTTOM - 30)
	ground.size = Vector2(W, 30)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	# 중앙선(장식)
	var mid := ColorRect.new()
	mid.color = Color(1, 1, 1, 0.08)
	mid.position = Vector2(0, (FIELD_TOP + FIELD_BOTTOM) * 0.5 - 2)
	mid.size = Vector2(W, 4)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mid)
	# 요새 (위) 와 성 (아래) 스프라이트
	_field = Node2D.new()
	add_child(_field)
	var fort_sp := Sprite2D.new()
	fort_sp.texture = tex_cache.get("fortress")
	fort_sp.scale = Vector2(2.4, 2.4)
	fort_sp.position = Vector2(LANE_CX, FORT_Y)
	fort_sp.rotation = PI  # 요새는 아래를 향함
	_field.add_child(fort_sp)
	var castle_sp := Sprite2D.new()
	castle_sp.texture = tex_cache.get("castle")
	castle_sp.scale = Vector2(2.4, 2.4)
	castle_sp.position = Vector2(LANE_CX, CASTLE_Y)
	_field.add_child(castle_sp)

	# 상/하단 HP 바
	_bars_layer = Control.new()
	_bars_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_layer.position = Vector2.ZERO
	_bars_layer.size = Vector2(W, H)
	add_child(_bars_layer)
	# 요새 HP (상단)
	var fort_bg := ColorRect.new()
	fort_bg.color = Color(0, 0, 0, 0.5)
	fort_bg.position = Vector2(80, 14)
	fort_bg.size = Vector2(560, 26)
	_bars_layer.add_child(fort_bg)
	_fort_hp_fill = ColorRect.new()
	_fort_hp_fill.color = Color(0.9, 0.3, 0.3)
	_fort_hp_fill.position = Vector2(82, 16)
	_fort_hp_fill.size = Vector2(556, 22)
	_bars_layer.add_child(_fort_hp_fill)
	_fort_hp_label = _mk_label("요새 1200/1200", 16, HORIZONTAL_ALIGNMENT_CENTER)
	_fort_hp_label.position = Vector2(80, 14)
	_fort_hp_label.size = Vector2(560, 26)
	_fort_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bars_layer.add_child(_fort_hp_label)
	# 성 HP (전장 바닥, 소환 패널 위)
	var castle_bg := ColorRect.new()
	castle_bg.color = Color(0, 0, 0, 0.5)
	castle_bg.position = Vector2(80, FIELD_BOTTOM - 36)
	castle_bg.size = Vector2(560, 26)
	_bars_layer.add_child(castle_bg)
	_castle_hp_fill = ColorRect.new()
	_castle_hp_fill.color = Color(0.3, 0.85, 0.4)
	_castle_hp_fill.position = Vector2(82, FIELD_BOTTOM - 34)
	_castle_hp_fill.size = Vector2(556, 22)
	_bars_layer.add_child(_castle_hp_fill)
	_castle_hp_label = _mk_label("성 800/800", 16, HORIZONTAL_ALIGNMENT_CENTER)
	_castle_hp_label.position = Vector2(80, FIELD_BOTTOM - 36)
	_castle_hp_label.size = Vector2(560, 26)
	_castle_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_bars_layer.add_child(_castle_hp_label)

	# 결과 라벨 (가운데)
	_result_label = _mk_label("", 48, HORIZONTAL_ALIGNMENT_CENTER)
	_result_label.position = Vector2(0, 440)
	_result_label.size = Vector2(W, 100)
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.visible = false
	add_child(_result_label)

	# 하단 소환 패널
	_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.08, 0.05)
	sb.set_corner_radius_all(0)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.position = Vector2(0, PANEL_TOP)
	_panel.size = Vector2(W, H - PANEL_TOP)
	add_child(_panel)
	_build_panel()

func _build_panel() -> void:
	# 상단 가로: 홈 버튼 + 영웅 스킬 버튼
	var home_btn := Button.new()
	home_btn.text = "홈"
	LaneUI.button(home_btn, "red", 18)
	home_btn.position = Vector2(10, 8)
	home_btn.size = Vector2(80, 44)
	home_btn.pressed.connect(func():
		SoundManager.play_click()
		home_pressed.emit())
	_panel.add_child(home_btn)

	_hero_skill_btn = Button.new()
	_hero_skill_btn.text = "스킬"
	LaneUI.button(_hero_skill_btn, "green", 18)
	_hero_skill_btn.position = Vector2(W - 160, 8)
	_hero_skill_btn.size = Vector2(150, 44)
	_hero_skill_btn.pressed.connect(_on_hero_skill)
	_panel.add_child(_hero_skill_btn)
	# 스킬 쿨 게이지
	_hero_cool_fill = ColorRect.new()
	_hero_cool_fill.color = Color(0, 0, 0, 0.55)
	_hero_cool_fill.position = Vector2(W - 160, 8)
	_hero_cool_fill.size = Vector2(0, 44)
	_hero_cool_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_hero_cool_fill)

	var title := _mk_label("아군 소환", 14, HORIZONTAL_ALIGNMENT_LEFT)
	title.position = Vector2(104, 14)
	title.size = Vector2(200, 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	_panel.add_child(title)

	# 아군 16종 - 가로 스크롤
	var ally_scroll := ScrollContainer.new()
	ally_scroll.position = Vector2(8, 58)
	ally_scroll.size = Vector2(W - 16, 110)
	ally_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	ally_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(ally_scroll)
	var ally_row := HBoxContainer.new()
	ally_row.add_theme_constant_override("separation", 6)
	ally_scroll.add_child(ally_row)
	for k in LaneBattle.ALLY_ORDER:
		ally_row.add_child(_make_summon_button(k, true))

	# 적 8종 - 두 번째 가로 스크롤
	var etitle := _mk_label("적 소환 (테스트)", 14, HORIZONTAL_ALIGNMENT_LEFT)
	etitle.position = Vector2(10, 170)
	etitle.size = Vector2(300, 20)
	etitle.add_theme_color_override("font_color", Color(0.9, 0.55, 0.55))
	_panel.add_child(etitle)
	var enemy_scroll := ScrollContainer.new()
	enemy_scroll.position = Vector2(8, 196)
	enemy_scroll.size = Vector2(W - 16, 100)
	enemy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	enemy_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(enemy_scroll)
	var enemy_row := HBoxContainer.new()
	enemy_row.add_theme_constant_override("separation", 6)
	enemy_scroll.add_child(enemy_row)
	for k in LaneBattle.ENEMIES.keys():
		enemy_row.add_child(_make_summon_button(k, false))

func _make_summon_button(kind: String, is_ally: bool) -> Control:
	var box := Button.new()
	box.focus_mode = Control.FOCUS_NONE
	box.custom_minimum_size = Vector2(76, 90)
	box.flat = false
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.18, 0.14) if is_ally else Color(0.3, 0.14, 0.14)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.6, 0.5, 0.3) if is_ally else Color(0.7, 0.3, 0.3)
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		box.add_theme_stylebox_override(st, sb)
	box.pressed.connect(func():
		SoundManager.play_click()
		_summon(kind, is_ally))
	# 아이콘
	if tex_cache.has(kind):
		var icon := TextureRect.new()
		icon.texture = tex_cache[kind]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(4, 4)
		icon.size = Vector2(68, 60)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		box.add_child(icon)
	# 이름
	var nm: String = kind
	if is_ally and LaneBattle.ALLIES.has(kind):
		nm = str(LaneBattle.ALLIES[kind].get("name", kind))
	var l := _mk_label(nm, 11, HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(0, 66)
	l.size = Vector2(76, 22)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return box

func _mk_label(text: String, size: int, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

# ---------------------------------------------------------------------------
# 소환
# ---------------------------------------------------------------------------

func _spawn_hero() -> void:
	var hdata: Dictionary = LaneBattle.HEROES.get(hero_id, {})
	if hdata.is_empty():
		return
	hero_unit = _make_unit(hero_id, true, Vector2(LANE_CX, CASTLE_Y - 80), {
		"hp": hdata.get("hp", 300.0),
		"atk": hdata.get("atk", 10.0),
		"range": hdata.get("range", 60.0),
		"speed": 0.0,  # 영웅은 가만히 있음
		"every": hdata.get("every", 1.2),
		"kb": hdata.get("kb", 3),
		"is_hero": true,
	}, "hero_" + hero_id)
	hero_unit["speed"] = 0.0
	hero_cool = 6.0  # 시작 쿨 짧게

func _summon(kind: String, is_ally: bool) -> void:
	if finished:
		return
	var data: Dictionary = LaneBattle.ALLIES.get(kind, {}) if is_ally else LaneBattle.ENEMIES.get(kind, {})
	if data.is_empty():
		return
	var x: float = LANE_CX + rng.randf_range(-LANE_HALF_W * 0.6, LANE_HALF_W * 0.6)
	var y: float = (CASTLE_Y - 60.0) if is_ally else (FORT_Y + 60.0)
	_make_unit(kind, is_ally, Vector2(x, y), data, kind)

func _make_unit(kind: String, is_ally: bool, pos: Vector2, data: Dictionary, tex_key: String) -> Dictionary:
	var sp := Sprite2D.new()
	sp.texture = tex_cache.get(tex_key, tex_cache.get("knight"))
	sp.scale = Vector2(UNIT_SCALE, UNIT_SCALE)
	if sp.texture != null:
		sp.offset = Vector2(0, -sp.texture.get_height() * 0.5)
	sp.position = pos
	_field.add_child(sp)
	# HP 바
	var bar := Node2D.new()
	bar.position = pos
	_field.add_child(bar)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.position = Vector2(-BAR_W * 0.5, -40)
	bg.size = Vector2(BAR_W, BAR_H)
	bar.add_child(bg)
	var fill := ColorRect.new()
	fill.color = Color(0.3, 0.95, 0.4) if is_ally else Color(0.95, 0.4, 0.4)
	fill.position = Vector2(-BAR_W * 0.5 + 1, -39)
	fill.size = Vector2(BAR_W - 2, BAR_H - 2)
	bar.add_child(fill)
	var u: Dictionary = {
		"kind": kind,
		"ally": is_ally,
		"hp": float(data.get("hp", 50.0)),
		"hp_max": float(data.get("hp", 50.0)),
		"atk": float(data.get("atk", 10.0)),
		"range": float(data.get("range", 44.0)),
		"speed": float(data.get("speed", 25.0)),
		"every": float(data.get("every", 1.2)),
		"attack_t": 0.0,
		"node": sp,
		"bar": bar,
		"hp_fill": fill,
		"pos": pos,
		"is_hero": bool(data.get("is_hero", false)),
	}
	units.append(u)
	return u

# ---------------------------------------------------------------------------
# 메인 루프
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	hero_cool = max(0.0, hero_cool - delta)
	_update_hero_cool()
	# 이동 + 공격
	var dead: Array = []
	for u in units:
		if u["hp"] <= 0.0:
			dead.append(u)
			continue
		_tick_unit(u, delta)
	for u in dead:
		if is_instance_valid(u["node"]):
			u["node"].queue_free()
		if is_instance_valid(u["bar"]):
			u["bar"].queue_free()
		if u.get("is_hero", false):
			hero_unit = {}
		units.erase(u)
	_update_hp_bars()
	# 승패
	if fort_hp <= 0.0:
		_finish(true)
	elif castle_hp <= 0.0:
		_finish(false)

func _tick_unit(u: Dictionary, delta: float) -> void:
	# 성/요새 중 어느 쪽을 목표로 할지
	var target_pos: Vector2
	var target_is_struct: bool = false
	var enemy: Dictionary = _nearest_enemy(u)
	if enemy.is_empty():
		target_pos = Vector2(LANE_CX, FORT_Y) if u["ally"] else Vector2(LANE_CX, CASTLE_Y)
		target_is_struct = true
	else:
		target_pos = enemy["pos"]
	# 거리
	var dy: float = target_pos.y - u["pos"].y
	var dist: float = u["pos"].distance_to(target_pos)
	# 이동
	if dist > u["range"] - 4.0 and u["speed"] > 0.0:
		var dir: float = -1.0 if u["ally"] else 1.0  # 아군 위로, 적 아래로
		# 적이 있으면 y 기반, 없으면 요새/성을 향해
		if not enemy.is_empty():
			dir = sign(dy)
			if dir == 0:
				dir = -1.0 if u["ally"] else 1.0
		u["pos"].y += dir * u["speed"] * delta
		# 좌우로 살짝 몰리는 효과
		var dx: float = target_pos.x - u["pos"].x
		if absf(dx) > 2.0:
			u["pos"].x += sign(dx) * min(absf(dx), u["speed"] * 0.4 * delta)
		u["node"].position = u["pos"]
		u["bar"].position = u["pos"]
	# 공격
	u["attack_t"] = max(0.0, u["attack_t"] - delta)
	if dist <= u["range"] and u["attack_t"] <= 0.0:
		u["attack_t"] = u["every"]
		if target_is_struct:
			if u["ally"]:
				fort_hp = max(0.0, fort_hp - u["atk"])
			else:
				castle_hp = max(0.0, castle_hp - u["atk"])
		else:
			enemy["hp"] -= u["atk"]
			# 넉백 효과 간단히: 피격 시 살짝 뒤로
			var push: float = 6.0
			var pdir: float = sign(enemy["pos"].y - u["pos"].y)
			if pdir == 0:
				pdir = 1.0
			enemy["pos"].y += pdir * push
			if is_instance_valid(enemy["node"]):
				enemy["node"].position = enemy["pos"]
			if is_instance_valid(enemy["bar"]):
				enemy["bar"].position = enemy["pos"]
			# HP 바
			if is_instance_valid(enemy["hp_fill"]):
				var r: float = max(0.0, enemy["hp"] / enemy["hp_max"])
				enemy["hp_fill"].size.x = (BAR_W - 2) * r

func _nearest_enemy(u: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = 1e9
	for v in units:
		if v["ally"] == u["ally"]:
			continue
		if v["hp"] <= 0.0:
			continue
		var d: float = u["pos"].distance_to(v["pos"])
		if d < best_d:
			best_d = d
			best = v
	# 사거리의 2.5배 안의 적만 추적; 그 외엔 성/요새로 전진
	if best.is_empty() or best_d > u["range"] + 300.0:
		return {}
	return best

# ---------------------------------------------------------------------------
# HP 바 / 결과
# ---------------------------------------------------------------------------

func _update_hp_bars() -> void:
	var cr: float = castle_hp / CASTLE_HP_MAX
	_castle_hp_fill.size.x = 556.0 * cr
	_castle_hp_label.text = "성  %d / %d" % [int(castle_hp), int(CASTLE_HP_MAX)]
	var fr: float = fort_hp / FORT_HP_MAX
	_fort_hp_fill.size.x = 556.0 * fr
	_fort_hp_label.text = "요새  %d / %d" % [int(fort_hp), int(FORT_HP_MAX)]

func _update_hero_cool() -> void:
	if hero_unit.is_empty():
		_hero_skill_btn.disabled = true
		_hero_cool_fill.size.x = 150.0
		_hero_skill_btn.text = "사망"
		return
	var hdata: Dictionary = LaneBattle.HEROES.get(hero_id, {})
	var total: float = float(hdata.get("cool", 25.0))
	if hero_cool > 0.0:
		_hero_skill_btn.disabled = true
		_hero_cool_fill.size.x = 150.0 * (hero_cool / total)
		_hero_skill_btn.text = "스킬  %d" % int(ceil(hero_cool))
	else:
		_hero_skill_btn.disabled = false
		_hero_cool_fill.size.x = 0.0
		_hero_skill_btn.text = str(hdata.get("skill_name", "스킬"))

func _on_hero_skill() -> void:
	if finished or hero_unit.is_empty() or hero_cool > 0.0:
		return
	var hdata: Dictionary = LaneBattle.HEROES.get(hero_id, {})
	var kind: String = str(hdata.get("skill", ""))
	match kind:
		"line_sweep":
			# 전장의 모든 적에게 100 피해 + 넉백
			for v in units:
				if not v["ally"] and v["hp"] > 0.0:
					v["hp"] -= 100.0
					v["pos"].y -= 40.0
					if is_instance_valid(v["node"]):
						v["node"].position = v["pos"]
		"aura_buff":
			# 아군 전원 20% 회복 (간단화)
			for v in units:
				if v["ally"] and v["hp"] > 0.0:
					v["hp"] = min(v["hp_max"], v["hp"] + v["hp_max"] * 0.2)
		"cone_dash":
			# 가장 앞선 적 라인 쪽으로 150 광역
			for v in units:
				if not v["ally"] and v["hp"] > 0.0 and v["pos"].y > FIELD_TOP + 150:
					v["hp"] -= 150.0
		"heal_wave":
			for v in units:
				if v["ally"] and v["hp"] > 0.0:
					v["hp"] = min(v["hp_max"], v["hp"] + v["hp_max"] * 0.3)
		_:
			for v in units:
				if not v["ally"] and v["hp"] > 0.0:
					v["hp"] -= 80.0
	hero_cool = float(hdata.get("cool", 25.0))
	SoundManager.play_battle("hero_skill", -6.0)

func _finish(won: bool) -> void:
	finished = true
	_result_label.text = "승리!" if won else "패배..."
	_result_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if won else Color(1.0, 0.4, 0.4))
	_result_label.visible = true
	# 2.5초 뒤 홈으로
	get_tree().create_timer(2.5).timeout.connect(func(): home_pressed.emit())
