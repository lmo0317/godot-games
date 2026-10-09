class_name LaneStageSelect
extends Control
# 블록 기사단 base (docs/LANE_STAGES.md, docs/LANE_UNITS.md): the gem bar on top, title ribbon,
# deck power vs the next stage's recommended power, then a themed board per chapter (초원·숲·묘지·마왕성
# tints) with stage cards (number, monster portrait, stars, recommended power). Boss stages (6/12/18/
# 24) are bigger with a red stone frame and the boss name. Locked stages show a lock on a dim card.
# A chapter with all three stars on every stage gets a gold "완료" ribbon next to its name.

signal stage_selected(stage_id: int)
signal gacha_pressed
signal deck_pressed
signal closed

const CARD: Vector2 = Vector2(90, 108)
const BOSS_CARD: Vector2 = Vector2(108, 128)

var rows: VBoxContainer
var gem_bar: Panel
var power_label: Label

const POWER_OK: Color = Color(0.62, 0.95, 0.55)
const POWER_LOW: Color = Color(1.0, 0.5, 0.42)
# Chapter inner backgrounds: 초원 연녹, 숲 짙은 녹, 묘지 보라/안개, 마왕성 어두운 빨강
const CHAPTER_TINTS: Array[Color] = [
	Color(0.55, 0.78, 0.42),
	Color(0.26, 0.46, 0.28),
	Color(0.42, 0.36, 0.56),
	Color(0.55, 0.22, 0.24),
]
# Each chapter's representative monster (fallback for card icons); boss stage uses its boss kind
const CHAPTER_ICON: Array[String] = ["slime", "goblin", "skeleton", "orc"]

func _ready() -> void:
	visible = false
	z_index = 150
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	LaneUI.backdrop(self)

	gem_bar = LaneUI.gem_bar(680)
	gem_bar.position = Vector2(20, 18)
	add_child(gem_bar)
	var title := LaneUI.ribbon("블록 기사단", 440, 32)
	title.position = Vector2(140, 92)
	add_child(title)

	power_label = LaneUI.label("", 22, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	power_label.position = Vector2(20, 154)
	power_label.size = Vector2(680, 32)
	add_child(power_label)

	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.position = Vector2(20, 192)
	rows.size = Vector2(680, 0)
	add_child(rows)

	var gacha := Button.new()
	gacha.text = "병사 뽑기"
	LaneUI.button(gacha, "red", 26)
	gacha.position = Vector2(20, 1000)
	gacha.size = Vector2(334, 84)
	gacha.pressed.connect(func(): gacha_pressed.emit())
	add_child(gacha)
	var gi := LaneUI.icon("icon_gem", Vector2(28, 32))
	gi.position = Vector2(30, 24)
	gacha.add_child(gi)
	var deck := Button.new()
	deck.text = "덱 편성"
	LaneUI.button(deck, "blue", 26)
	deck.position = Vector2(366, 1000)
	deck.size = Vector2(334, 84)
	deck.pressed.connect(func(): deck_pressed.emit())
	add_child(deck)
	var back := Button.new()
	back.text = "홈으로"
	LaneUI.button(back, "green", 22)
	back.position = Vector2(220, 1100)
	back.size = Vector2(280, 64)
	back.pressed.connect(close)
	add_child(back)

func open() -> void:
	SoundManager.play_click()
	refresh()
	visible = true
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.2)

func close() -> void:
	SoundManager.play_click()
	visible = false
	closed.emit()

func gem_bar_text() -> String:
	return gem_bar.get_node("Gems").text

func refresh() -> void:
	LaneUI.set_gem_bar(gem_bar)
	for child in rows.get_children():
		child.queue_free()
	var progress: Dictionary = LaneStages.load_progress()
	var power: int = LaneUnits.deck_power()
	var next_id: int = int(progress["unlocked"])
	var next_rec: int = LaneStages.recommended_power(next_id)
	power_label.text = "내 덱 전투력 %d  ·  STAGE %d 권장 %d" % [power, next_id, next_rec]
	power_label.add_theme_color_override("font_color", POWER_OK if power >= next_rec else POWER_LOW)
	var per: int = LaneStages.PER_CHAPTER
	for c in range(LaneStages.CHAPTERS.size()):
		rows.add_child(_chapter_board(c, progress, power, per))

# One chapter row: wooden plank, tinted inner board, chapter name + optional 완료 ribbon,
# then the 6 stage cards (boss is bigger, so it wraps onto its own centred second line)
func _chapter_board(c: int, progress: Dictionary, power: int, per: int) -> Panel:
	var board := Panel.new()
	LaneUI.dress(board, "panel_wood")
	board.custom_minimum_size = Vector2(680, 212)
	# Tinted inner panel so each chapter reads at a glance
	var inner := Panel.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.position = Vector2(14, 46)
	inner.size = Vector2(652, 152)
	inner.add_theme_stylebox_override("panel", UIKit.box(CHAPTER_TINTS[c].darkened(0.1), CHAPTER_TINTS[c].lightened(0.25), 10, 2))
	board.add_child(inner)
	var head := LaneUI.label(LaneStages.CHAPTERS[c]["name"], 22, LaneUI.GOLD)
	head.position = Vector2(26, 12)
	head.size = Vector2(300, 30)
	board.add_child(head)
	# 완료 badge: all 6 stages of this chapter at 3 stars
	var chapter_done: bool = true
	for i in range(per):
		var sid := c * per + i + 1
		if int(progress["stars"].get(str(sid), 0)) < 3:
			chapter_done = false
			break
	if chapter_done:
		var badge := LaneUI.label("★ 완료", 18, LaneUI.GOLD)
		badge.position = Vector2(330, 14)
		badge.size = Vector2(120, 26)
		board.add_child(badge)
	# Row of stages, split so the oversized boss sits on its own centred line
	var normals := HBoxContainer.new()
	normals.add_theme_constant_override("separation", 10)
	normals.position = Vector2(26, 54)
	normals.size = Vector2(628, CARD.y)
	normals.alignment = BoxContainer.ALIGNMENT_CENTER
	board.add_child(normals)
	var slice: Array = LaneStages.STAGES.slice(c * per, c * per + per)
	for s in slice:
		var sid: int = s["id"]
		if s["boss"] != "":
			continue
		normals.add_child(_stage_card(s, int(progress["stars"].get(str(sid), 0)), sid > int(progress["unlocked"]), power))
	# Boss row: centred below
	var boss_row := HBoxContainer.new()
	boss_row.add_theme_constant_override("separation", 10)
	boss_row.position = Vector2(26, 54 + CARD.y + 2)
	boss_row.size = Vector2(628, 0)
	boss_row.alignment = BoxContainer.ALIGNMENT_CENTER
	board.add_child(boss_row)
	# If chapter has 5 normals + 1 boss we need extra height for the boss row
	for s in slice:
		var sid2: int = s["id"]
		if s["boss"] == "":
			continue
		board.custom_minimum_size = Vector2(680, 212 + BOSS_CARD.y + 6)
		inner.size = Vector2(652, 152 + BOSS_CARD.y + 6)
		boss_row.add_child(_stage_card(s, int(progress["stars"].get(str(sid2), 0)), sid2 > int(progress["unlocked"]), power))
	return board

# One stage: a stone-framed card with the number on top, the chapter/boss monster portrait in the
# middle, three stars and the recommended power at the bottom. Locked = dim with a lock.
func _stage_card(s: Dictionary, stars: int, locked: bool, power: int) -> Control:
	var sid: int = s["id"]
	var boss: bool = s["boss"] != ""
	var sz: Vector2 = BOSS_CARD if boss else CARD
	var btn := TextureButton.new()
	btn.name = "Stage%d" % sid
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = sz
	btn.size = sz
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = s["name"]
	# Stone frame on every card; boss gets a red tint so it reads as the chapter wall
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = sz
	frame.add_theme_stylebox_override("panel", LaneUI.box("card_frame", 4, Color(1.4, 0.55, 0.45) if boss else Color.WHITE))
	btn.add_child(frame)
	# Stage number up top
	var num := LaneUI.label(str(sid), 20 if boss else 18, LaneUI.GOLD if boss else LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	num.position = Vector2(0, 6)
	num.size = Vector2(sz.x, 22)
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(num)
	# Monster portrait: boss kind for boss stages, else first in the pool, else chapter icon
	var icon_kind: String = ""
	if boss:
		icon_kind = LaneStages.BOSSES[s["boss"]]["kind"]
	elif s.has("pool") and not s["pool"].is_empty():
		icon_kind = s["pool"][0]
	if icon_kind == "":
		icon_kind = CHAPTER_ICON[(sid - 1) / LaneStages.PER_CHAPTER]
	var mon_tex: Texture2D = _load_tex("res://assets/art/lane/%s.png" % icon_kind)
	var mon_h: float = sz.y - 60.0
	if mon_tex != null:
		var mon := TextureRect.new()
		mon.texture = mon_tex
		mon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mon.position = Vector2(6, 28)
		mon.size = Vector2(sz.x - 12, mon_h)
		if boss:
			mon.scale = Vector2(1.1, 1.1)
			mon.pivot_offset = mon.size * 0.5
		btn.add_child(mon)
	# Boss name underneath the number
	if boss:
		var bn := LaneUI.label(LaneStages.BOSSES[s["boss"]]["name"], 12, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		bn.position = Vector2(0, 28)
		bn.size = Vector2(sz.x, 16)
		bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bn)
	# Stars + recommended power
	var st := LaneUI.stars(stars, 14 if not boss else 16)
	st.position = Vector2(0, sz.y - 34)
	st.size = Vector2(sz.x, 16)
	btn.add_child(st)
	if locked:
		btn.disabled = true
		btn.modulate = Color(0.42, 0.42, 0.5)
		num.visible = false
		if boss:
			btn.get_child(-2).visible = false  # boss name
		var lock := LaneUI.icon("icon_lock", Vector2(32, 42))
		lock.position = Vector2((sz.x - lock.size.x) * 0.5, (sz.y - lock.size.y) * 0.5)
		lock.modulate = Color(2.4, 2.4, 2.4)
		btn.add_child(lock)
	else:
		btn.pressed.connect(func(): stage_selected.emit(sid))
		btn.mouse_entered.connect(func(): btn.modulate = Color(1.15, 1.15, 1.15))
		btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
	st.modulate = Color(1, 1, 1, 0.35) if locked else Color.WHITE
	if not locked:
		var rec: int = LaneStages.recommended_power(sid)
		var rl := LaneUI.label("권장 %d" % rec, 12, POWER_OK if power >= rec else POWER_LOW, HORIZONTAL_ALIGNMENT_CENTER)
		rl.name = "Rec"
		rl.position = Vector2(0, sz.y - 18)
		rl.size = Vector2(sz.x, 16)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(rl)
	return btn

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
