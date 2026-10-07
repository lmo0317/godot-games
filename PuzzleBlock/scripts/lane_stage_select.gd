class_name LaneStageSelect
extends Control
# 블록 기사단 base (docs/LANE_STAGES.md, docs/LANE_UNITS.md), in the pixel-art UI (LaneUI): the gem
# bar on top, the title ribbon, a wooden board per chapter with 6 stage medallions (number, stars;
# boss stages get the horned medallion, locked ones are dark with a lock), then the gacha, deck and
# home buttons. Every stage ends back here.

signal stage_selected(stage_id: int)
signal gacha_pressed
signal deck_pressed
signal closed

const MEDAL: Vector2 = Vector2(80, 80)

var rows: VBoxContainer
var gem_bar: Panel

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

	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	rows.position = Vector2(20, 166)
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
	var per: int = LaneStages.PER_CHAPTER
	for c in range(LaneStages.CHAPTERS.size()):
		var board := Panel.new()
		LaneUI.dress(board, "panel_wood")
		board.custom_minimum_size = Vector2(680, 196)
		rows.add_child(board)
		var head := LaneUI.label(LaneStages.CHAPTERS[c]["name"], 22, LaneUI.GOLD)
		head.position = Vector2(26, 14)
		head.size = Vector2(300, 30)
		board.add_child(head)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 22)
		line.position = Vector2(26, 46)
		board.add_child(line)
		for s in LaneStages.STAGES.slice(c * per, c * per + per):
			var sid: int = s["id"]
			line.add_child(_stage_node(s, int(progress["stars"].get(str(sid), 0)), sid > int(progress["unlocked"])))

# A stage medallion with its number, stars underneath and the name on hover
func _stage_node(s: Dictionary, stars: int, locked: bool) -> Control:
	var sid: int = s["id"]
	var boss: bool = s["boss"] != ""
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size = Vector2(MEDAL.x, 0)
	var btn := TextureButton.new()
	btn.name = "Stage%d" % sid
	btn.texture_normal = LaneUI.tex("medal_boss" if boss else "medal")
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size = MEDAL
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.focus_mode = Control.FOCUS_NONE
	btn.tooltip_text = s["name"]
	box.add_child(btn)
	var num := LaneUI.label(str(sid), 30, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	num.size = MEDAL
	num.position = Vector2(0, 8 if boss else 0)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(num)
	if locked:
		btn.disabled = true
		btn.modulate = Color(0.38, 0.38, 0.42)
		num.visible = false
		var lock := LaneUI.icon("icon_lock", Vector2(26, 34))
		lock.position = (MEDAL - lock.size) * 0.5 + Vector2(0, 4 if boss else 0)
		lock.modulate = Color(2.4, 2.4, 2.4)
		btn.add_child(lock)
	else:
		btn.pressed.connect(func(): stage_selected.emit(sid))
		btn.mouse_entered.connect(func(): btn.modulate = Color(1.15, 1.15, 1.15))
		btn.mouse_exited.connect(func(): btn.modulate = Color.WHITE)
	var st := LaneUI.stars(stars, 20)
	st.modulate = Color(1, 1, 1, 0.35) if locked else Color.WHITE
	box.add_child(st)
	return box
