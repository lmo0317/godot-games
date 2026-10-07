class_name LaneGacha
extends ColorRect
# 블록 기사단 soldier gacha (docs/LANE_UNITS.md): gems, the rates shown up front, 1 pull (100) or 10
# pulls (900, one rare or better promised). Results flip over one by one as cards: grade border,
# the soldier, its name, and NEW / level up / gems back.

signal closed

const CARD_SIZE: Vector2 = Vector2(110, 150)

var rng := RandomNumberGenerator.new()
var gems_label: Label
var grid: GridContainer
var note: Label
var pull1: Button
var pull10: Button
var _busy: bool = false

func _ready() -> void:
	rng.randomize()
	visible = false
	z_index = 160
	color = Color(UIKit.BG, 0.99)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var card := Panel.new()
	UIKit.style_modal(card)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -340
	card.offset_right = 340
	card.offset_top = -560
	card.offset_bottom = 560
	add_child(card)

	var title := UIKit.label("병사 뽑기", UIKit.TYPE_MODAL_TITLE, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 22)
	title.size = Vector2(680, 52)
	card.add_child(title)
	gems_label = UIKit.label("", 28, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	gems_label.position = Vector2(0, 78)
	gems_label.size = Vector2(680, 36)
	card.add_child(gems_label)

	# Rates, always visible
	var rates := Panel.new()
	rates.add_theme_stylebox_override("panel", UIKit.inset(16))
	rates.position = Vector2(40, 124)
	rates.size = Vector2(600, 132)
	card.add_child(rates)
	var y := 10
	for r in [3, 2, 1]:
		var kinds: Array = LaneUnits.ORDER.filter(func(k): return LaneUnits.UNITS[k]["rarity"] == r)
		var line := UIKit.label("%s %d%%  ·  %s" % [LaneUnits.RARITY_NAME[r], roundi(LaneUnits.RARITY_RATE[r] * 100.0), ", ".join(kinds.map(func(k): return LaneUnits.UNITS[k]["name"]))], 18, LaneUnits.RARITY_COLOR[r])
		line.position = Vector2(20, y)
		line.size = Vector2(560, 30)
		rates.add_child(line)
		y += 32
	var promise := UIKit.label("10회 뽑기는 희귀 이상 1명 보장 · 이미 있는 병사는 레벨 업", 15, UIKit.MUTED)
	promise.position = Vector2(20, y - 2)
	promise.size = Vector2(560, 24)
	rates.add_child(promise)

	grid = GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	grid.position = Vector2((680 - (CARD_SIZE.x * 5 + 40)) * 0.5, 272)
	card.add_child(grid)

	note = UIKit.label("", UIKit.TYPE_BODY, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 600)
	note.size = Vector2(680, 30)
	card.add_child(note)

	pull1 = Button.new()
	UIKit.style_button(pull1, "primary", 24, 18)
	pull1.position = Vector2(40, 1120 - 180)
	pull1.size = Vector2(290, 80)
	pull1.pressed.connect(func(): pull(1))
	card.add_child(pull1)
	pull10 = Button.new()
	UIKit.style_button(pull10, "primary", 24, 18)
	pull10.position = Vector2(350, 1120 - 180)
	pull10.size = Vector2(290, 80)
	pull10.pressed.connect(func(): pull(10))
	card.add_child(pull10)
	var back := Button.new()
	back.text = "돌아가기"
	UIKit.style_button(back, "secondary", 22, 18)
	back.position = Vector2(40, 1120 - 86)
	back.size = Vector2(600, 58)
	back.pressed.connect(close)
	card.add_child(back)

func open() -> void:
	SoundManager.play_click()
	for c in grid.get_children():
		c.queue_free()
	note.text = "보석은 스테이지를 깨면 받아요"
	_refresh()
	visible = true

func close() -> void:
	SoundManager.play_click()
	visible = false
	closed.emit()

func _refresh() -> void:
	var gems: int = LaneUnits.load_army()["gems"]
	gems_label.text = "보석 %d" % gems
	pull1.text = "1회 뽑기\n보석 %d" % LaneUnits.PULL_COST
	pull10.text = "10회 뽑기\n보석 %d" % LaneUnits.PULL10_COST
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
	note.text = ""
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
		var rarity: int = LaneUnits.UNITS[results[i]["kind"]]["rarity"]
		tw.tween_callback(func():
			if rarity >= 3:
				SoundManager.play_battle("b_cannon", -6.0)
			elif rarity == 2:
				SoundManager.play_battle("b_magic", -6.0)
			else:
				SoundManager.play_battle("b_summon", -8.0))
	get_tree().create_timer(0.12 * results.size() + 0.25).timeout.connect(func():
		_busy = false
		_refresh())
	return results

func _card(res: Dictionary) -> Panel:
	var kind: String = res["kind"]
	var u: Dictionary = LaneUnits.UNITS[kind]
	var col: Color = LaneUnits.RARITY_COLOR[u["rarity"]]
	var c := Panel.new()
	c.custom_minimum_size = CARD_SIZE
	c.add_theme_stylebox_override("panel", UIKit.box(UIKit.SURFACE_HI, col, 14, 3 if u["rarity"] == 1 else 4))
	var art := TextureRect.new()
	art.texture = load("res://assets/art/lane/%s.png" % kind)
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2(10, 8)
	art.size = Vector2(90, 80)
	c.add_child(art)
	var n := UIKit.label(u["name"], 18, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	n.position = Vector2(0, 88)
	n.size = Vector2(CARD_SIZE.x, 24)
	c.add_child(n)
	var tag_text: String = "NEW!" if res["new"] else ("+%d 보석" % res["refund"] if res["refund"] > 0 else "Lv %d ↑" % res["level"])
	var tag := UIKit.label(tag_text, 16, UIKit.GOLD if res["new"] else Color(0.6, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	tag.position = Vector2(0, 114)
	tag.size = Vector2(CARD_SIZE.x, 24)
	c.add_child(tag)
	return c
