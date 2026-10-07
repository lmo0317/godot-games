class_name LaneStageSelect
extends ColorRect
# 블록 기사단 stage select (docs/LANE_STAGES.md): a chapter title over each row of 4 stages, each
# with its number, name and stars; boss stages get a red border, locked ones a lock.

signal stage_selected(stage_id: int)
signal closed

const BUTTON_SIZE: Vector2 = Vector2(128, 132)
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
	card.offset_left = -330
	card.offset_right = 330
	card.offset_top = -430
	card.offset_bottom = 430
	add_child(card)

	var title := UIKit.label("블록 기사단", UIKit.TYPE_MODAL_TITLE, UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 26
	title.offset_bottom = 78
	card.add_child(title)

	summary_label = UIKit.label("", UIKit.TYPE_BODY, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	summary_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	summary_label.offset_top = 80
	summary_label.offset_bottom = 108
	card.add_child(summary_label)

	rows = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	rows.position = Vector2((660 - (BUTTON_SIZE.x * 4 + 14 * 3)) * 0.5, 120)
	card.add_child(rows)

	var back := Button.new()
	back.text = "홈으로"
	UIKit.style_button(back, "secondary", 22, 18)
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.offset_left = -270
	back.offset_right = 270
	back.offset_top = -86
	back.offset_bottom = -28
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
	for c in range(LaneStages.CHAPTERS.size()):
		var head := UIKit.label(LaneStages.CHAPTERS[c]["name"], UIKit.TYPE_SECTION, UIKit.GOLD)
		head.custom_minimum_size = Vector2(0, 30)
		rows.add_child(head)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		rows.add_child(line)
		for s in LaneStages.STAGES.slice(c * 4, c * 4 + 4):
			var sid: int = s["id"]
			var stars: int = int(progress["stars"].get(str(sid), 0))
			total += stars
			line.add_child(_stage_button(s, stars, sid > int(progress["unlocked"])))
	summary_label.text = "모은 별 %d / %d" % [total, LaneStages.count() * 3]

func _stage_button(s: Dictionary, stars: int, locked: bool) -> Button:
	var sid: int = s["id"]
	var boss: bool = s["boss"] != ""
	var btn := Button.new()
	btn.custom_minimum_size = BUTTON_SIZE
	btn.name = "Stage%d" % sid
	btn.focus_mode = Control.FOCUS_NONE
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 2)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var muted: Color = Color(UIKit.MUTED, 0.92)
	stack.add_child(_centered(UIKit.label(str(sid), 30, muted if locked else UIKit.TEXT, HORIZONTAL_ALIGNMENT_CENTER)))
	if locked:
		btn.disabled = true
		UIKit.style_button(btn, "secondary", 22, 18)
		btn.add_theme_stylebox_override("disabled", UIKit.raised(UIKit.SURFACE_HI, Color(UIKit.BORDER, 0.72), Color(0.02, 0.03, 0.06), 18))
		var lock := TextureRect.new()
		lock.texture = LOCK_ICON
		lock.custom_minimum_size = Vector2(28, 28)
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cc := CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(lock)
		stack.add_child(cc)
		return btn
	var border: Color = BOSS_RED if boss else (Color(0.99, 0.82, 0.25, 0.9) if stars > 0 else Color(0.22, 0.74, 0.97, 0.9))
	UIKit.style_raised(btn, UIKit.SURFACE_HI, border, Color(0.02, 0.03, 0.06), 18)
	var name := UIKit.label(s["name"], 16, BOSS_RED if boss else UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	stack.add_child(_centered(name))
	stack.add_child(_centered(UIKit.label(LaneStages.star_text(stars), 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)))
	btn.pressed.connect(func(): stage_selected.emit(sid))
	return btn

func _centered(l: Label) -> Label:
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
