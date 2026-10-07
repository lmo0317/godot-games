class_name LaneStageSelect
extends ColorRect
# 블록 기사단 base (docs/LANE_STAGES.md, docs/LANE_UNITS.md): gems and stars on top, a chapter title
# over each row of 6 stages (number, name, stars; boss stages red, locked ones a lock), then the
# gacha and deck buttons.

signal stage_selected(stage_id: int)
signal gacha_pressed
signal deck_pressed
signal closed

const BUTTON_SIZE: Vector2 = Vector2(94, 104)
const GAP: int = 10
const LOCK_ICON: Texture2D = preload("res://assets/sprites/lock_icon.png")
const BOSS_RED: Color = Color(1.0, 0.45, 0.4)

var rows: VBoxContainer
var summary_label: Label

func _ready() -> void:
	visible = false
	z_index = 150
	color = Color(UIKit.BG, 0.99)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var card := Panel.new()
	UIKit.style_modal(card)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -340
	card.offset_right = 340
	card.offset_top = -560
	card.offset_bottom = 560
	add_child(card)

	var title := UIKit.label("블록 기사단", UIKit.TYPE_MODAL_TITLE, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 22
	title.offset_bottom = 74
	card.add_child(title)

	summary_label = UIKit.label("", UIKit.TYPE_BODY, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	summary_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	summary_label.offset_top = 76
	summary_label.offset_bottom = 104
	card.add_child(summary_label)

	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	rows.position = Vector2((680 - (BUTTON_SIZE.x * 6 + GAP * 5)) * 0.5, 112)
	card.add_child(rows)

	var gacha := Button.new()
	gacha.text = "병사 뽑기"
	UIKit.style_button(gacha, "primary", 24, 18)
	gacha.position = Vector2(40, 1120 - 168)
	gacha.size = Vector2(290, 70)
	gacha.pressed.connect(func(): gacha_pressed.emit())
	card.add_child(gacha)
	var deck := Button.new()
	deck.text = "덱 편성"
	UIKit.style_button(deck, "primary", 24, 18)
	deck.position = Vector2(350, 1120 - 168)
	deck.size = Vector2(290, 70)
	deck.pressed.connect(func(): deck_pressed.emit())
	card.add_child(deck)

	var back := Button.new()
	back.text = "홈으로"
	UIKit.style_button(back, "secondary", 22, 18)
	back.position = Vector2(40, 1120 - 86)
	back.size = Vector2(600, 58)
	back.pressed.connect(close)
	card.add_child(back)

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

func refresh() -> void:
	for child in rows.get_children():
		child.queue_free()
	var progress: Dictionary = LaneStages.load_progress()
	var total := 0
	var per: int = LaneStages.PER_CHAPTER
	for c in range(LaneStages.CHAPTERS.size()):
		var head := UIKit.label(LaneStages.CHAPTERS[c]["name"], UIKit.TYPE_SECTION, UIKit.GOLD)
		head.custom_minimum_size = Vector2(0, 30)
		rows.add_child(head)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", GAP)
		rows.add_child(line)
		for s in LaneStages.STAGES.slice(c * per, c * per + per):
			var sid: int = s["id"]
			var stars: int = int(progress["stars"].get(str(sid), 0))
			total += stars
			line.add_child(_stage_button(s, stars, sid > int(progress["unlocked"])))
	summary_label.text = "보석 %d   ·   모은 별 %d / %d" % [LaneUnits.load_army()["gems"], total, LaneStages.count() * 3]

func _stage_button(s: Dictionary, stars: int, locked: bool) -> Button:
	var sid: int = s["id"]
	var boss: bool = s["boss"] != ""
	var btn := Button.new()
	btn.custom_minimum_size = BUTTON_SIZE
	btn.name = "Stage%d" % sid
	btn.focus_mode = Control.FOCUS_NONE
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 1)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var muted: Color = Color(UIKit.MUTED, 0.92)
	stack.add_child(_centered(UIKit.label(str(sid), 26, muted if locked else UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)))
	if locked:
		btn.disabled = true
		UIKit.style_button(btn, "secondary", 22, 16)
		btn.add_theme_stylebox_override("disabled", UIKit.raised(UIKit.SURFACE_HI, Color(UIKit.BORDER, 0.72), Color(0.02, 0.03, 0.06), 16))
		var lock := TextureRect.new()
		lock.texture = LOCK_ICON
		lock.custom_minimum_size = Vector2(26, 26)
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cc := CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(lock)
		stack.add_child(cc)
		return btn
	var border: Color = BOSS_RED if boss else (Color(0.99, 0.82, 0.25, 0.9) if stars > 0 else Color(0.22, 0.74, 0.97, 0.9))
	UIKit.style_raised(btn, UIKit.SURFACE_HI, border, Color(0.02, 0.03, 0.06), 16)
	var name := UIKit.label(s["name"], 14, BOSS_RED if boss else UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.custom_minimum_size = Vector2(BUTTON_SIZE.x - 8, 0)
	stack.add_child(_centered(name))
	stack.add_child(_centered(UIKit.label(LaneStages.star_text(stars), 17, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)))
	btn.pressed.connect(func(): stage_selected.emit(sid))
	return btn

func _centered(l: Label) -> Label:
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
