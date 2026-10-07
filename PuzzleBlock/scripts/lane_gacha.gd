class_name LaneGacha
extends Control
# 블록 기사단 soldier gacha (docs/LANE_UNITS.md), in the pixel-art UI (LaneUI): the gem bar, the
# rates on parchment, 1 pull (100) or 10 pulls (900, one 레어 or better promised). Results flip over
# one by one as tier cards (LaneTierCard): the soldier, its name, and NEW / +1 copy / gems back.

signal closed

const CARD_SIZE: Vector2 = Vector2(110, 150)

var rng := RandomNumberGenerator.new()
var gem_bar: Panel
var grid: GridContainer
var note: Label
var pull1: Button
var pull10: Button
var _busy: bool = false

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

	# Rates, always visible, on parchment
	var rates := Panel.new()
	LaneUI.dress(rates, "panel_paper")
	rates.position = Vector2(40, 170)
	rates.size = Vector2(640, 150)
	add_child(rates)
	var y := 18
	for t in [2, 1, 0]:
		var kinds: Array = LaneUnits.ORDER.filter(func(k): return LaneUnits.UNITS[k]["tier"] == t)
		var col: Color = LaneUnits.tier_color(t).darkened(0.45) if t > 0 else LaneUI.INK
		var line := LaneUI.label("%s %d%%  ·  %s" % [LaneUnits.TIER_NAME[t], roundi(LaneUnits.BASE_RATE[t] * 100.0), ", ".join(kinds.map(func(k): return LaneUnits.UNITS[k]["name"]))], 19, col, HORIZONTAL_ALIGNMENT_LEFT, false)
		line.position = Vector2(26, y)
		line.size = Vector2(590, 30)
		rates.add_child(line)
		y += 32
	var promise := LaneUI.label("10회 뽑기는 레어 이상 1명 보장 · 같은 병사는 복제가 되어 합성에 써요", 16, Color(0.36, 0.25, 0.15), HORIZONTAL_ALIGNMENT_LEFT, false)
	promise.position = Vector2(26, y + 2)
	promise.size = Vector2(590, 24)
	rates.add_child(promise)

	var board := Panel.new()
	LaneUI.dress(board, "panel_wood")
	board.position = Vector2(20, 336)
	board.size = Vector2(680, 380)
	add_child(board)
	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 14)
	grid.position = Vector2((680 - (CARD_SIZE.x * 5 + 40)) * 0.5, 30)
	board.add_child(grid)
	note = LaneUI.label("", 22, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 170)
	note.size = Vector2(680, 40)
	board.add_child(note)

	pull1 = Button.new()
	LaneUI.button(pull1, "green", 24)
	pull1.position = Vector2(20, 740)
	pull1.size = Vector2(334, 96)
	pull1.pressed.connect(func(): pull(1))
	add_child(pull1)
	pull10 = Button.new()
	LaneUI.button(pull10, "red", 24)
	pull10.position = Vector2(366, 740)
	pull10.size = Vector2(334, 96)
	pull10.pressed.connect(func(): pull(10))
	add_child(pull10)
	for b in [pull1, pull10]:
		var gi := LaneUI.icon("icon_gem", Vector2(26, 30))
		gi.position = Vector2(24, 33)
		b.add_child(gi)
	var back := Button.new()
	back.text = "본부로"
	LaneUI.button(back, "blue", 22)
	back.position = Vector2(220, 1100)
	back.size = Vector2(280, 64)
	back.pressed.connect(close)
	add_child(back)

func open() -> void:
	SoundManager.play_click()
	for c in grid.get_children():
		c.queue_free()
	note.text = "보석은 스테이지를 깨면 받아요"
	note.visible = true
	_refresh()
	visible = true

func close() -> void:
	SoundManager.play_click()
	visible = false
	closed.emit()

func _refresh() -> void:
	LaneUI.set_gem_bar(gem_bar)
	var gems: int = LaneUnits.load_army()["gems"]
	pull1.text = "1회 뽑기\n%d" % LaneUnits.PULL_COST
	pull10.text = "10회 뽑기\n%d" % LaneUnits.PULL10_COST
	pull1.disabled = gems < LaneUnits.PULL_COST or _busy
	pull10.disabled = gems < LaneUnits.PULL10_COST or _busy

# Pulls and shows the cards; returns the results (empty if gems ran short)
func pull(count: int) -> Array:
	if _busy:
		return []
	var results: Array = LaneUnits.pull(count, rng)
	if results.is_empty():
		note.text = "보석이 모자라요"
		return []
	SoundManager.play_click()
	for c in grid.get_children():
		c.queue_free()
	_busy = true
	note.visible = false
	_refresh()
	for i in range(results.size()):
		var c := _card(results[i])
		grid.add_child(c)
		c.pivot_offset = CARD_SIZE * 0.5
		c.scale = Vector2(0.0, 1.0)
		var tw := c.create_tween()
		tw.tween_interval(0.12 * i)
		tw.tween_property(c, "scale", Vector2(1.08, 1.08), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, 0.08)
		var rarity: int = int(LaneUnits.UNITS[results[i]["kind"]]["tier"])
		tw.tween_callback(func():
			if rarity >= 2:
				c.burst()
				SoundManager.play_battle("b_cannon", -6.0)
			elif rarity == 1:
				SoundManager.play_battle("b_magic", -6.0)
			else:
				SoundManager.play_battle("b_summon", -8.0))
	get_tree().create_timer(0.12 * results.size() + 0.25).timeout.connect(func():
		_busy = false
		_refresh())
	return results

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
