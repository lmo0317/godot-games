class_name LaneStageSelect
extends Control
# 블록 기사단 base (docs/LANE_STAGES.md, docs/LANE_UNITS.md). 가로 스크롤 챕터 탭 구조:
#   row 1 (18~82)    gem bar on the left + home button on the right
#   row 2 (96~160)   title ribbon "블록 기사단" (centred)
#   row 3 (170~202)  deck power vs the next stage's recommended power
#   row 4 (210~274)  chapter tabs (4 of them, horizontal); each shows "n장 이름 ★x/18",
#                    gold border + ★ when all stars collected
#   row 5 (284~892)  the picked chapter's board, 652x608: themed inner panel, 6 big stage cards
#                    in 2x3 (card ~204x268); boss has a red stone frame and a BOSS label.
#                    Swipe left/right to switch chapters (DragScroll on the carousel).
#   row 6 (908~998)  [병사 뽑기] [덱 편성] buttons

signal stage_selected(stage_id: int)
signal gacha_pressed
signal deck_pressed
signal closed

const CARD: Vector2 = Vector2(204, 268)
const CARD_GAP: Vector2 = Vector2(16, 16)
const TAB_W: float = 164.0
const TAB_H: float = 64.0
const TAB_GAP: float = 4.0

var rows: Control                       # kept for test_lane: find_child("Stage*")/find_child("Rec")
var gem_bar: Panel
var power_label: Label

var _carousel: ScrollContainer
var _carousel_row: HBoxContainer
var _tab_row: HBoxContainer
var _tab_buttons: Array[Button] = []
var _chapter: int = 0

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

	# Row 1: gem bar + a small home button on the right (gem bar is wide, home is small)
	gem_bar = LaneUI.gem_bar(540)
	gem_bar.position = Vector2(20, 18)
	add_child(gem_bar)
	var back := Button.new()
	back.text = "홈으로"
	LaneUI.button(back, "grey", 22)
	back.position = Vector2(570, 18)
	back.size = Vector2(130, 64)
	back.pressed.connect(close)
	add_child(back)

	# Row 2: title ribbon
	var title := LaneUI.ribbon("블록 기사단", 440, 32)
	title.position = Vector2(140, 92)
	add_child(title)

	# Row 3: deck power / recommended
	power_label = LaneUI.label("", 24, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	power_label.position = Vector2(20, 170)
	power_label.size = Vector2(680, 34)
	add_child(power_label)

	# Row 4: chapter tabs (4 across). Each tab is a Button; selecting one scrolls the carousel.
	_tab_row = HBoxContainer.new()
	_tab_row.add_theme_constant_override("separation", int(TAB_GAP))
	_tab_row.position = Vector2(20, 210)
	_tab_row.size = Vector2(680, TAB_H)
	_tab_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_tab_row)
	for c in range(LaneStages.CHAPTERS.size()):
		var tab := Button.new()
		tab.toggle_mode = false
		tab.custom_minimum_size = Vector2(TAB_W, TAB_H)
		tab.focus_mode = Control.FOCUS_NONE
		LaneUI.button(tab, "grey", 20)
		var idx: int = c
		tab.pressed.connect(func(): _select_chapter(idx, true))
		_tab_row.add_child(tab)
		_tab_buttons.append(tab)

	# Row 5: carousel of 4 chapter boards, one per screen width. Horizontal drag/swipe switches.
	_carousel = ScrollContainer.new()
	_carousel.position = Vector2(20, 284)
	_carousel.size = Vector2(680, 608)
	_carousel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_carousel.clip_contents = true
	add_child(_carousel)
	DragScroll.attach(_carousel)
	_carousel_row = HBoxContainer.new()
	_carousel_row.add_theme_constant_override("separation", 0)
	_carousel.add_child(_carousel_row)

	# `rows` is kept as a container that holds every stage card node (recursive find_child in test)
	rows = _carousel_row

	# Row 6: bottom buttons
	var gacha := Button.new()
	gacha.text = "병사 뽑기"
	LaneUI.button(gacha, "red", 26)
	gacha.position = Vector2(20, 908)
	gacha.size = Vector2(334, 92)
	gacha.pressed.connect(func(): gacha_pressed.emit())
	add_child(gacha)
	var gi := LaneUI.icon("icon_gem", Vector2(30, 34))
	gi.position = Vector2(30, 28)
	gacha.add_child(gi)
	var deck := Button.new()
	deck.text = "덱 편성"
	LaneUI.button(deck, "blue", 26)
	deck.position = Vector2(366, 908)
	deck.size = Vector2(334, 92)
	deck.pressed.connect(func(): deck_pressed.emit())
	add_child(deck)

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
	for child in _carousel_row.get_children():
		child.queue_free()
	var progress: Dictionary = LaneStages.load_progress()
	var power: int = LaneUnits.deck_power()
	var next_id: int = int(progress["unlocked"])
	var next_rec: int = LaneStages.recommended_power(next_id)
	power_label.text = "내 덱 전투력 %d  ·  STAGE %d 권장 %d" % [power, next_id, next_rec]
	power_label.add_theme_color_override("font_color", POWER_OK if power >= next_rec else POWER_LOW)
	var per: int = LaneStages.PER_CHAPTER
	for c in range(LaneStages.CHAPTERS.size()):
		_carousel_row.add_child(_chapter_board(c, progress, power, per))
		_update_tab(c, progress, per)
	# Jump to the chapter that holds the next unlocked stage, no animation on refresh
	var start_c: int = clampi((next_id - 1) / per, 0, LaneStages.CHAPTERS.size() - 1)
	call_deferred("_select_chapter", start_c, false)

func _update_tab(c: int, progress: Dictionary, per: int) -> void:
	var tab: Button = _tab_buttons[c]
	var stars_got := 0
	for i in range(per):
		var sid := c * per + i + 1
		stars_got += int(progress["stars"].get(str(sid), 0))
	var done: bool = stars_got >= per * 3
	# Short label: "1장" plus a star counter; done chapters prepend ★
	var head: String = LaneStages.CHAPTERS[c]["name"].split(" ")[0]
	tab.text = "%s\n★ %d/%d" % [head, stars_got, per * 3] if not done else "%s ★\n완료 %d/%d" % [head, stars_got, per * 3]
	# Highlight the picked tab (green) and dim the others (grey)
	LaneUI.button(tab, "green" if c == _chapter else "grey", 20)
	if done and c != _chapter:
		LaneUI.button(tab, "red", 20)  # done but not picked: red stays visible

func _select_chapter(c: int, animate: bool) -> void:
	_chapter = clampi(c, 0, LaneStages.CHAPTERS.size() - 1)
	# Refresh tabs' colours
	var progress: Dictionary = LaneStages.load_progress()
	var per: int = LaneStages.PER_CHAPTER
	for i in range(_tab_buttons.size()):
		_update_tab(i, progress, per)
	var tx: float = _chapter * _carousel.size.x
	if animate:
		var tw := create_tween()
		tw.tween_method(func(x): _carousel.scroll_horizontal = int(x), float(_carousel.scroll_horizontal), tx, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_carousel.scroll_horizontal = int(tx)

# One chapter board: themed inner panel + 2x3 grid of big stage cards (boss gets a red frame)
func _chapter_board(c: int, progress: Dictionary, power: int, per: int) -> Panel:
	var board := Panel.new()
	board.custom_minimum_size = Vector2(_carousel.size.x, _carousel.size.y)
	LaneUI.dress(board, "panel_wood")
	# Tinted inner panel: each chapter reads at a glance
	var inner := Panel.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.position = Vector2(14, 14)
	inner.size = Vector2(_carousel.size.x - 28, _carousel.size.y - 28)
	inner.add_theme_stylebox_override("panel", UIKit.box(CHAPTER_TINTS[c].darkened(0.25), CHAPTER_TINTS[c].lightened(0.15), 10, 2))
	board.add_child(inner)
	# Chapter name banner across the top of the inner panel
	var head := LaneUI.label(LaneStages.CHAPTERS[c]["name"], 28, LaneUI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	head.position = Vector2(0, 10)
	head.size = Vector2(inner.size.x, 36)
	inner.add_child(head)
	# 6 stage cards in a 2x3 grid, centred (3 columns x 2 rows). Boss (last) gets a red frame.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", int(CARD_GAP.x))
	grid.add_theme_constant_override("v_separation", int(CARD_GAP.y))
	var grid_w: float = CARD.x * 3 + CARD_GAP.x * 2
	var grid_h: float = CARD.y * 2 + CARD_GAP.y
	grid.position = Vector2((inner.size.x - grid_w) * 0.5, 56)
	grid.size = Vector2(grid_w, grid_h)
	inner.add_child(grid)
	var slice: Array = LaneStages.STAGES.slice(c * per, c * per + per)
	for s in slice:
		var sid: int = s["id"]
		grid.add_child(_stage_card(s, int(progress["stars"].get(str(sid), 0)), sid > int(progress["unlocked"]), power))
	return board

# One stage: a stone-framed card with the number on top, the monster portrait in the middle,
# three stars + recommended power at the bottom. Boss stages (6/12/18/24) show a red frame and
# a BOSS label. Locked stages are dim with a lock + a note.
func _stage_card(s: Dictionary, stars: int, locked: bool, power: int) -> Control:
	var sid: int = s["id"]
	var boss: bool = s["boss"] != ""
	var btn := TextureButton.new()
	btn.name = "Stage%d" % sid
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = CARD
	btn.size = CARD
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = s["name"]
	# Stone frame; boss gets a red tint. Also a solid dark backdrop so the pixel art reads clearly.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.09, 0.07, 0.14, 0.55) if not boss else Color(0.22, 0.05, 0.08, 0.72)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.position = Vector2(10, 10)
	backdrop.size = CARD - Vector2(20, 20)
	btn.add_child(backdrop)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = CARD
	frame.add_theme_stylebox_override("panel", LaneUI.box("card_frame", 4, Color(1.5, 0.5, 0.42) if boss else Color.WHITE))
	btn.add_child(frame)
	# Stage number up top (40 bold with outline)
	var num := LaneUI.label(str(sid), 40, LaneUI.GOLD if boss else LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	num.position = Vector2(0, 14)
	num.size = Vector2(CARD.x, 50)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(num)
	# Boss label (right under the number)
	if boss:
		var tag := LaneUI.label("☠ BOSS", 20, Color(1.0, 0.7, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
		tag.position = Vector2(0, 60)
		tag.size = Vector2(CARD.x, 26)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(tag)
	# Monster portrait, big (centred in the middle band)
	var icon_kind: String = ""
	if boss:
		icon_kind = LaneStages.BOSSES[s["boss"]]["kind"]
	elif s.has("pool") and not s["pool"].is_empty():
		icon_kind = s["pool"][0]
	if icon_kind == "":
		icon_kind = CHAPTER_ICON[(sid - 1) / LaneStages.PER_CHAPTER]
	var mon_tex: Texture2D = _load_tex("res://assets/art/lane/%s.png" % icon_kind)
	if mon_tex != null:
		var mon := TextureRect.new()
		mon.texture = mon_tex
		mon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mon.position = Vector2(16, 86 if boss else 70)
		mon.size = Vector2(CARD.x - 32, 110)
		btn.add_child(mon)
	# Boss name just under the portrait
	if boss:
		var bn := LaneUI.label(LaneStages.BOSSES[s["boss"]]["name"], 18, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		bn.position = Vector2(0, 200)
		bn.size = Vector2(CARD.x, 24)
		bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(bn)
	# Stars + recommended power at the bottom
	var st := LaneUI.stars(stars, 24)
	st.position = Vector2(0, CARD.y - 56)
	st.size = Vector2(CARD.x, 26)
	btn.add_child(st)
	if locked:
		btn.disabled = true
		btn.modulate = Color(0.42, 0.42, 0.5)
		num.visible = false
		var lock := LaneUI.icon("icon_lock", Vector2(56, 68))
		lock.position = Vector2((CARD.x - lock.size.x) * 0.5, (CARD.y - lock.size.y) * 0.5 - 10)
		lock.modulate = Color(2.4, 2.4, 2.4)
		btn.add_child(lock)
		var note := LaneUI.label("앞 스테이지를 깨면 열려요", 16, Color(0.9, 0.9, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
		note.position = Vector2(0, CARD.y - 32)
		note.size = Vector2(CARD.x, 24)
		note.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(note)
	else:
		btn.pressed.connect(func(): stage_selected.emit(sid))
		btn.mouse_entered.connect(func(): btn.modulate = Color(1.15, 1.15, 1.15))
		btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
		var rec: int = LaneStages.recommended_power(sid)
		var rl := LaneUI.label("권장 %d" % rec, 20, POWER_OK if power >= rec else POWER_LOW, HORIZONTAL_ALIGNMENT_CENTER)
		rl.name = "Rec"
		rl.position = Vector2(0, CARD.y - 30)
		rl.size = Vector2(CARD.x, 24)
		rl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(rl)
	st.modulate = Color(1, 1, 1, 0.35) if locked else Color.WHITE
	return btn

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null
