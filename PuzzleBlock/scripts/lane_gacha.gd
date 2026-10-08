class_name LaneGacha
extends Control
# 블록 기사단 soldier gacha (docs/LANE_UNITS.md "뽑기 연출"), in the pixel-art UI (LaneUI):
#   1 the altar: a summoning altar with a swirling portal and slow light rays, the rates on
#     parchment, 1 pull (100) or 10 pulls (900, one 레어 or better promised)
#   2 charge: sparkles rush into the portal and a pillar of light rises; its colour tells the best
#     soldier coming (white 노멀 / blue 레어 / purple 유니크 / gold 레전더리). Sometimes it shows a lower colour first
#     and then turns (the "shift"), which is the moment players remember
#   3 reveal: every soldier comes out one by one, big, on turning rays, with its name, tier and role,
#     a NEW! stamp or its copies toward the next merge; rarer ones get a starburst, flash and shake.
#     Tap for the next one, or skip to the end
#   4 summary: all cards of the pull, what is new, and which soldiers can now merge (with a button
#     to the soldiers screen)
# Pieces: assets/art/lane/summon_* (Codex sheet, docs/ART_GUIDE.md), sounds g_* (tools/generate_sfx.py).

signal closed
signal deck_requested

const CARD_SIZE: Vector2 = Vector2(110, 150)
const PORTAL_AT: Vector2 = Vector2(360, 430)
const ALTAR_AT: Vector2 = Vector2(360, 600)
# Light colour by the base tier of the soldier coming out
const LIGHT: Array[Color] = [Color(0.92, 0.96, 1.0), Color(0.4, 0.68, 1.0), Color(0.82, 0.5, 1.0), Color(1.0, 0.68, 0.22)]
const SHOW_CARD: Vector2 = Vector2(300, 360)

var rng := RandomNumberGenerator.new()
var gem_bar: Panel
var note: Label
var pull1: Button
var pull10: Button
var back: Button
var _busy: bool = false

# Altar scene
var _stage: Node2D
var _rays: Sprite2D
var _portal: Sprite2D
var _pillar: Sprite2D
var _altar: Sprite2D
var _spin: float = 0.6
var _clock: float = 0.0
var _next_mote: float = 0.0

# Reveal and summary layers
var _show: Control
var _show_rays: Sprite2D
var _show_burst: Sprite2D
var _show_box: Control
var _show_count: Label
var _summary: Control
var _sum_grid: GridContainer
var _sum_line: Label
var _sum_merge: Label
var _sum_ok: Button
var _sum_deck: Button
var _flash: ColorRect
var _advance: bool = false
var _skip: bool = false

func _ready() -> void:
	rng.randomize()
	visible = false
	z_index = 160
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	LaneUI.backdrop(self)

	gem_bar = LaneUI.gem_bar(680)
	gem_bar.position = Vector2(20, 18)
	add_child(gem_bar)
	var title := LaneUI.ribbon("병사 뽑기", 400, 32)
	title.position = Vector2(160, 92)
	add_child(title)

	# The altar: slow rays, the swirling portal over the stone altar
	_stage = Node2D.new()
	add_child(_stage)
	_rays = _sprite("summon_rays", PORTAL_AT, 5.0)
	_rays.modulate = Color(LIGHT[0], 0.18)
	_pillar = _sprite("summon_pillar", ALTAR_AT + Vector2(0, -18), 4.0)
	_pillar.offset = Vector2(0, -_pillar.texture.get_height() * 0.5)
	_pillar.modulate = Color(1, 1, 1, 0)
	_altar = _sprite("summon_altar", ALTAR_AT, 4.0)
	_portal = _sprite("summon_portal", PORTAL_AT, 3.0)
	_portal.modulate = Color(LIGHT[0], 0.85)

	# Rates, always visible, on parchment
	var rates := Panel.new()
	LaneUI.dress(rates, "panel_paper")
	rates.position = Vector2(30, 698)
	rates.size = Vector2(660, 140)
	add_child(rates)
	var y := 10
	for t in [3, 2, 1, 0]:
		var kinds: Array = LaneUnits.ORDER.filter(func(k): return LaneUnits.UNITS[k]["tier"] == t)
		var col: Color = LaneUnits.tier_color(t).darkened(0.45) if t > 0 else LaneUI.INK
		var pct: String = ("%.1f%%" % (LaneUnits.BASE_RATE[t] * 100.0)).replace(".0%", "%")
		var line := LaneUI.label("%s %s  ·  %s" % [LaneUnits.TIER_NAME[t], pct, ", ".join(kinds.map(func(k): return LaneUnits.UNITS[k]["name"]))], 16, col, HORIZONTAL_ALIGNMENT_LEFT, false)
		line.position = Vector2(20, y)
		line.size = Vector2(620, 24)
		rates.add_child(line)
		y += 26
	var promise := LaneUI.label("같은 병사는 복제가 되어 합성(성급 올리기)에 써요", 15, Color(0.36, 0.25, 0.15), HORIZONTAL_ALIGNMENT_LEFT, false)
	promise.position = Vector2(20, y)
	promise.size = Vector2(590, 22)
	rates.add_child(promise)

	pull1 = Button.new()
	LaneUI.button(pull1, "green", 24)
	pull1.position = Vector2(20, 852)
	pull1.size = Vector2(334, 100)
	pull1.pressed.connect(func(): pull(1))
	add_child(pull1)
	pull10 = Button.new()
	LaneUI.button(pull10, "red", 24)
	pull10.position = Vector2(366, 852)
	pull10.size = Vector2(334, 100)
	pull10.pressed.connect(func(): pull(10))
	add_child(pull10)
	for b in [pull1, pull10]:
		var gi := LaneUI.icon("icon_gem", Vector2(26, 30))
		gi.position = Vector2(24, 35)
		b.add_child(gi)
	note = LaneUI.label("", 21, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 964)
	note.size = Vector2(720, 34)
	add_child(note)
	back = Button.new()
	back.text = "본부로"
	LaneUI.button(back, "blue", 22)
	back.position = Vector2(220, 1100)
	back.size = Vector2(280, 64)
	back.pressed.connect(close)
	add_child(back)

	_build_show()
	_build_summary()
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

func _sprite(name: String, at: Vector2, k: float, parent: Node = null) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load("res://assets/art/lane/%s.png" % name)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.position = at
	s.scale = Vector2(k, k)
	(parent if parent else _stage).add_child(s)
	return s

func open() -> void:
	SoundManager.play_click()
	_show.visible = false
	_summary.visible = false
	_busy = false
	note.text = "보석은 스테이지를 깨면 받아요"
	_refresh()
	visible = true

func close() -> void:
	SoundManager.play_click()
	_skip = true
	_show.visible = false
	_summary.visible = false
	visible = false
	closed.emit()

func _refresh() -> void:
	LaneUI.set_gem_bar(gem_bar)
	var gems: int = LaneUnits.load_army()["gems"]
	pull1.text = "1회 뽑기\n%d" % LaneUnits.PULL_COST
	pull10.text = "10회 뽑기 %d\n레어 이상 1명 보장" % LaneUnits.PULL10_COST
	pull1.disabled = gems < LaneUnits.PULL_COST or _busy
	pull10.disabled = gems < LaneUnits.PULL10_COST or _busy
	back.disabled = _busy

# Idle life: the rays and the portal turn, motes drift up from the altar
func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	_rays.rotation += delta * 0.12
	_portal.rotation -= delta * _spin
	_portal.position.y = PORTAL_AT.y + sin(_clock * 1.6) * 6.0
	if _show.visible:
		_show_rays.rotation += delta * 0.35
	_next_mote -= delta
	if _next_mote <= 0.0 and not _busy:
		_next_mote = 0.35
		var m := _sprite("summon_sparkle", ALTAR_AT + Vector2(rng.randf_range(-110, 110), -20), rng.randf_range(1.0, 2.0))
		m.modulate = Color(_portal.modulate, 0.0)
		var tw := m.create_tween().set_parallel(true)
		tw.tween_property(m, "position:y", m.position.y - rng.randf_range(120, 220), 1.6)
		tw.tween_property(m, "modulate:a", 0.8, 0.4)
		tw.chain().tween_property(m, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(m.queue_free)

# Pulls and plays the whole show; returns the results at once (empty if gems ran short)
func pull(count: int) -> Array:
	if _busy:
		return []
	var results: Array = LaneUnits.pull(count, rng)
	if results.is_empty():
		note.text = "보석이 모자라요 · 스테이지를 깨서 모아요"
		SoundManager.play_invalid()
		return []
	SoundManager.play_click()
	_busy = true
	_skip = false
	note.text = ""
	_refresh()
	_play(results)
	return results

func _play(results: Array) -> void:
	var best := 0
	for r in results:
		best = maxi(best, int(LaneUnits.UNITS[r["kind"]]["tier"]))
	await _charge(best, results.size())
	if not visible:
		return
	if not _skip:
		for i in range(results.size()):
			await _reveal(results[i], i, results.size())
			if _skip or not visible:
				break
	_show.visible = false
	if visible:
		_show_summary(results)

# Wait that a tap (or skip) can cut short
func _hold(limit: float) -> void:
	_advance = false
	var t := 0.0
	while t < limit and not _advance and not _skip and visible:
		await get_tree().process_frame
		t += get_process_delta_time()

func _flash_screen(a: float, dur: float, col: Color = Color.WHITE) -> void:
	_flash.color = Color(col, a)
	var tw := _flash.create_tween()
	tw.tween_property(_flash, "color:a", 0.0, dur)

func _shake(node: CanvasItem, power: float, dur: float) -> void:
	var base: Vector2 = node.position
	var tw := node.create_tween()
	var steps := int(dur / 0.04)
	for i in range(steps):
		var k: float = power * (1.0 - float(i) / steps)
		tw.tween_property(node, "position", base + Vector2(rng.randf_range(-k, k), rng.randf_range(-k, k)), 0.04)
	tw.tween_property(node, "position", base, 0.04)

# The altar charges; the light's colour hints at the best soldier coming
func _charge(best: int, count: int) -> void:
	var start := best
	if best == 3 and rng.randf() < 0.6:
		start = 2
	elif best == 2 and rng.randf() < 0.5:
		start = 1
	elif best >= 1 and rng.randf() < 0.3:
		start = 0
	var dur: float = 1.5 if count > 1 else 1.1
	SoundManager.play_battle("g_charge", -4.0)
	_set_light(LIGHT[start], 0.25)
	_spin = 6.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_portal, "scale", Vector2(4.2, 4.2), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_pillar, "modulate:a", 0.95, dur * 0.6)
	tw.tween_property(_pillar, "scale", Vector2(5.0, 6.0), dur)
	tw.tween_property(_rays, "modulate:a", 0.55, dur)
	tw.tween_property(_rays, "scale", Vector2(7.0, 7.0), dur)
	# Sparkles rush in from all sides
	for i in range(18):
		var ang: float = rng.randf() * TAU
		var m := _sprite("summon_sparkle", PORTAL_AT + Vector2.from_angle(ang) * rng.randf_range(260, 360), rng.randf_range(1.5, 3.0))
		m.modulate = Color(LIGHT[start], 0.0)
		var mt := m.create_tween()
		mt.tween_interval(rng.randf() * dur * 0.6)
		mt.tween_property(m, "modulate:a", 1.0, 0.1)
		mt.tween_property(m, "position", PORTAL_AT, rng.randf_range(0.35, 0.6)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		mt.tween_callback(m.queue_free)
	if start != best:
		await get_tree().create_timer(dur * 0.62).timeout
		if not visible:
			return
		SoundManager.play_battle("g_shift", -3.0)
		_flash_screen(0.6, 0.3, LIGHT[best])
		_set_light(LIGHT[best], 0.15)
		_shake(_stage, 8.0, 0.25)
		await get_tree().create_timer(dur * 0.38).timeout
	else:
		await get_tree().create_timer(dur).timeout
	if not visible:
		return
	_flash_screen(0.95, 0.5, Color(1, 1, 1))
	_shake(_stage, 10.0 + 6.0 * best, 0.3)
	# Back to rest under the reveal
	_spin = 0.6
	var back_tw := create_tween().set_parallel(true)
	back_tw.tween_property(_portal, "scale", Vector2(3.0, 3.0), 0.4)
	back_tw.tween_property(_pillar, "modulate:a", 0.0, 0.5)
	back_tw.tween_property(_pillar, "scale", Vector2(4.0, 4.0), 0.5)
	back_tw.tween_property(_rays, "modulate:a", 0.18, 0.5)
	back_tw.tween_property(_rays, "scale", Vector2(5.0, 5.0), 0.5)
	_set_light(LIGHT[0], 0.6)

func _set_light(col: Color, dur: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_portal, "modulate", Color(col, 0.95), dur)
	tw.tween_property(_pillar, "modulate", Color(col, _pillar.modulate.a), dur)
	tw.tween_property(_rays, "modulate", Color(col, _rays.modulate.a), dur)

# ---------------------------------------------------------------------------
# Reveal: one soldier, big

func _build_show() -> void:
	_show = Control.new()
	_show.visible = false
	_show.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show.mouse_filter = Control.MOUSE_FILTER_STOP
	_show.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.pressed:
			_advance = true)
	add_child(_show)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.06, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show.add_child(shade)
	var layer := Node2D.new()
	_show.add_child(layer)
	_show_rays = _sprite("summon_rays", Vector2(360, 540), 6.0, layer)
	_show_burst = _sprite("summon_burst", Vector2(360, 540), 6.0, layer)
	_show_box = Control.new()
	_show_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_show_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_show.add_child(_show_box)
	_show_count = LaneUI.label("", 22, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_show_count.position = Vector2(0, 150)
	_show_count.size = Vector2(720, 30)
	_show.add_child(_show_count)
	var hint := LaneUI.label("화면을 누르면 다음", 18, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 1040)
	hint.size = Vector2(720, 26)
	_show.add_child(hint)
	var skip := Button.new()
	skip.text = "건너뛰기"
	LaneUI.button(skip, "grey", 20)
	skip.position = Vector2(250, 1090)
	skip.size = Vector2(220, 60)
	skip.pressed.connect(func():
		SoundManager.play_click()
		_skip = true)
	_show.add_child(skip)

func _reveal(res: Dictionary, i: int, n: int) -> void:
	var kind: String = res["kind"]
	var u: Dictionary = LaneUnits.UNITS[kind]
	var rarity: int = int(u["tier"])
	var tier: int = int(res["tier"])
	var col: Color = LIGHT[rarity]
	for c in _show_box.get_children():
		c.queue_free()
	_show.visible = true
	_show_count.text = "%d / %d" % [i + 1, n] if n > 1 else ""
	_show_rays.modulate = Color(col, 0.0)
	_show_rays.scale = Vector2(4.0, 4.0)
	var rt := _show_rays.create_tween().set_parallel(true)
	rt.tween_property(_show_rays, "modulate:a", 0.3 + 0.2 * rarity, 0.25)
	rt.tween_property(_show_rays, "scale", Vector2(6.0, 6.0) + Vector2.ONE * rarity, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_burst.modulate = Color(col, 0.0)
	if rarity >= 1:
		_show_burst.scale = Vector2(2.0, 2.0)
		var bt := _show_burst.create_tween().set_parallel(true)
		bt.tween_property(_show_burst, "modulate:a", 1.0, 0.08)
		bt.tween_property(_show_burst, "scale", Vector2(7.0, 7.0) + Vector2.ONE * 2.0 * (rarity - 1), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		bt.chain().tween_property(_show_burst, "modulate:a", 0.0, 0.35)

	# The card with the soldier, big
	var card := LaneTierCard.new(tier, SHOW_CARD)
	card.position = Vector2(360, 540) - SHOW_CARD * 0.5
	card.pivot_offset = SHOW_CARD * 0.5
	_show_box.add_child(card)
	var art := TextureRect.new()
	art.texture = load("res://assets/art/lane/%s.png" % kind)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size = Vector2(art.texture.get_width(), art.texture.get_height())
	# Whole-number scale, x5 for a soldier; big ones (the dragon rider) get less and may reach past
	# the frame a little
	var k: float = clampf(roundf(minf(330.0 / art.size.x, 230.0 / art.size.y)), 2.0, 5.0)
	art.scale = Vector2(k, k)
	art.position = Vector2((SHOW_CARD.x - art.size.x * k) * 0.5, 40 + (230 - art.size.y * k) * 0.5)
	card.add_child(art)
	var role := LaneUI.label(u["role"], 20, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	role.position = Vector2(0, SHOW_CARD.y - 74)
	role.size = Vector2(SHOW_CARD.x, 28)
	card.add_child(role)
	var name_l := LaneUI.label(u["name"], 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_l.position = Vector2(0, 190)
	name_l.size = Vector2(720, 56)
	_show_box.add_child(name_l)
	var tier_l := LaneUI.label(LaneUnits.TIER_NAME[tier], 26, LaneUnits.tier_color(tier).lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
	tier_l.position = Vector2(0, 246)
	tier_l.size = Vector2(720, 34)
	_show_box.add_child(tier_l)
	var desc := LaneUI.label(u["desc"], 19, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	desc.position = Vector2(60, 736)
	desc.size = Vector2(600, 30)
	_show_box.add_child(desc)
	# NEW!, or the copies toward the next merge
	var tag: Control
	if res["new"]:
		tag = LaneUI.ribbon("NEW!", 220, 30)
		tag.position = Vector2(250, 790)
	else:
		var text := "+%d 보석" % res["refund"] if res["refund"] > 0 else _copies_text(kind, int(res["copies"]), tier)
		var ready: bool = LaneUnits.merge_need(tier) > 0 and int(res["copies"]) >= LaneUnits.merge_need(tier)
		tag = LaneUI.label(text, 26, LaneUI.GOLD if ready else Color(0.75, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
		tag.position = Vector2(0, 796)
		tag.size = Vector2(720, 40)
	tag.pivot_offset = tag.size * 0.5 if tag.size != Vector2.ZERO else Vector2(110, 30)
	tag.modulate.a = 0.0
	_show_box.add_child(tag)

	# Entrance: the card spins in like a flipped coin, bigger for rarer soldiers
	card.scale = Vector2(0.05, 1.0)
	name_l.modulate.a = 0.0
	tier_l.modulate.a = 0.0
	var ct := card.create_tween()
	ct.tween_property(card, "scale", Vector2(1.12, 1.12), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ct.tween_property(card, "scale", Vector2.ONE, 0.1)
	var lt := create_tween().set_parallel(true)
	lt.tween_property(name_l, "modulate:a", 1.0, 0.25).set_delay(0.15)
	lt.tween_property(tier_l, "modulate:a", 1.0, 0.25).set_delay(0.25)
	SoundManager.play_battle("g_reveal_%d" % mini(rarity, 2), -2.0 if rarity >= 2 else -4.0)
	if rarity >= 1:
		_flash_screen(minf(0.95, 0.5 + 0.3 * rarity), 0.35 + 0.15 * maxi(0, rarity - 2), col)
	if rarity >= 2:
		_shake(_show_box, 12.0 + 8.0 * (rarity - 2), 0.35 + 0.25 * (rarity - 2))
		card.burst()
	if rarity >= 3:
		# 레전더리: a second boom and a long shower of sparks
		get_tree().create_timer(0.35).timeout.connect(func():
			SoundManager.play_battle("g_reveal_2", -4.0)
			_flash_screen(0.7, 0.4, Color(1, 0.95, 0.7))
			_burst_sparkles(col, 24))
	_burst_sparkles(col, 6 + 8 * rarity)
	# The tag slams in a moment later
	var tt := tag.create_tween()
	tt.tween_interval(0.35)
	tt.tween_callback(func():
		tag.modulate.a = 1.0
		if res["new"]:
			SoundManager.play_battle("g_new", -4.0))
	tag.scale = Vector2(2.2, 2.2)
	tt.tween_property(tag, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# How long it stays: quick for plain repeats in a 10-pull, longer for rare or new ones
	var stay: float = 1.0 if n > 1 else 1.8
	if rarity >= 1 or res["new"]:
		stay += 0.8 + 0.6 * rarity
	await get_tree().create_timer(0.3).timeout
	await _hold(stay)

func _copies_text(kind: String, copies: int, tier: int) -> String:
	var need: int = LaneUnits.merge_need(tier)
	if need <= 0:
		return "+1 복제"
	if copies >= need:
		return "+1 복제 · 합성할 수 있어요!"
	return "+1 복제 · 합성까지 %d / %d" % [copies, need]

func _burst_sparkles(col: Color, count: int) -> void:
	for i in range(count):
		var s := _sprite("summon_sparkle", Vector2(360, 540), rng.randf_range(1.5, 3.5), _show_rays.get_parent())
		s.modulate = col.lightened(0.3)
		var to: Vector2 = Vector2(360, 540) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(160, 330)
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", to, rng.randf_range(0.45, 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "rotation", rng.randf_range(-3, 3), 0.8)
		tw.chain().tween_property(s, "modulate:a", 0.0, 0.3)
		tw.chain().tween_callback(s.queue_free)

# ---------------------------------------------------------------------------
# Summary: every card of the pull, what is new and what can merge now

func _build_summary() -> void:
	_summary = Control.new()
	_summary.visible = false
	_summary.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_summary.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_summary)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.06, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_summary.add_child(shade)
	var board := Panel.new()
	LaneUI.dress(board, "panel_wood")
	board.position = Vector2(20, 230)
	board.size = Vector2(680, 560)
	_summary.add_child(board)
	var title := LaneUI.ribbon("뽑기 결과", 400, 32)
	title.position = Vector2(160, 186)
	_summary.add_child(title)
	_sum_grid = GridContainer.new()
	_sum_grid.columns = 5
	_sum_grid.add_theme_constant_override("h_separation", 10)
	_sum_grid.add_theme_constant_override("v_separation", 14)
	_sum_grid.position = Vector2((680 - (CARD_SIZE.x * 5 + 40)) * 0.5, 66)
	board.add_child(_sum_grid)
	_sum_line = LaneUI.label("", 22, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_sum_line.position = Vector2(0, 410)
	_sum_line.size = Vector2(680, 32)
	board.add_child(_sum_line)
	_sum_merge = LaneUI.label("", 21, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_sum_merge.position = Vector2(20, 448)
	_sum_merge.size = Vector2(640, 64)
	_sum_merge.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.add_child(_sum_merge)
	_sum_ok = Button.new()
	_sum_ok.text = "확인"
	LaneUI.button(_sum_ok, "blue", 24)
	_sum_ok.size = Vector2(300, 84)
	_sum_ok.pressed.connect(func():
		SoundManager.play_click()
		_summary.visible = false
		_busy = false
		_refresh())
	_summary.add_child(_sum_ok)
	_sum_deck = Button.new()
	_sum_deck.text = "합성하러 가기"
	LaneUI.button(_sum_deck, "green", 24)
	_sum_deck.position = Vector2(370, 820)
	_sum_deck.size = Vector2(310, 84)
	_sum_deck.pressed.connect(func():
		SoundManager.play_click()
		_summary.visible = false
		_busy = false
		visible = false
		deck_requested.emit())
	_summary.add_child(_sum_deck)

func _show_summary(results: Array) -> void:
	for c in _sum_grid.get_children():
		c.queue_free()
	var fresh := 0
	var merge: Array = []
	for i in range(results.size()):
		var r: Dictionary = results[i]
		var c := _card(r)
		_sum_grid.add_child(c)
		c.pivot_offset = CARD_SIZE * 0.5
		c.scale = Vector2(0.0, 1.0)
		var tw := c.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_property(c, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if r["new"]:
			fresh += 1
		var nm: String = LaneUnits.UNITS[r["kind"]]["name"]
		if LaneUnits.can_merge(r["kind"]) and not merge.has(nm):
			merge.append(nm)
	_sum_line.text = "새 병사 %d명 · 복제 %d개" % [fresh, results.size() - fresh]
	_sum_merge.text = ("합성할 수 있어요: " + ", ".join(merge)) if not merge.is_empty() else ""
	_sum_deck.visible = not merge.is_empty()
	_sum_ok.position = Vector2(40, 820) if _sum_deck.visible else Vector2(210, 820)
	_summary.visible = true
	_refresh()

func _card(res: Dictionary) -> LaneTierCard:
	var kind: String = res["kind"]
	var u: Dictionary = LaneUnits.UNITS[kind]
	var t: int = int(res["tier"])
	var c := LaneTierCard.new(t, CARD_SIZE)
	var art := TextureRect.new()
	art.texture = load("res://assets/art/lane/%s.png" % kind)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.position = Vector2(14, 14)
	art.size = Vector2(82, 70)
	c.add_child(art)
	var n := LaneUI.label(u["name"], 18, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	n.position = Vector2(0, 84)
	n.size = Vector2(CARD_SIZE.x, 24)
	c.add_child(n)
	var tn := LaneUI.label(LaneUnits.TIER_NAME[t], 14, LaneUnits.tier_color(t).lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER)
	tn.position = Vector2(0, 104)
	tn.size = Vector2(CARD_SIZE.x, 20)
	c.add_child(tn)
	var tag_text: String = "NEW!" if res["new"] else ("+%d 보석" % res["refund"] if res["refund"] > 0 else "+1 복제")
	var tag := LaneUI.label(tag_text, 15, LaneUI.GOLD if res["new"] else Color(0.7, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	tag.position = Vector2(0, 122)
	tag.size = Vector2(CARD_SIZE.x, 22)
	c.add_child(tag)
	return c
