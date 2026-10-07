class_name LaneResult
extends Control
# 블록 기사단 stage result, in the pixel-art UI (LaneUI): a ribbon with "STAGE n 클리어!" or "실패",
# the stars popping in one by one, the gems earned, and one way on: back to the base to spend gems
# and fix the deck before the next stage.

signal back_pressed

var title: Control
var stars_box: HBoxContainer
var gems_label: Label
var info: Label
var tip: Label
var back: Button
var board: Panel

func _ready() -> void:
	visible = false
	z_index = 140
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.05, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	board = Panel.new()
	LaneUI.dress(board, "panel_wood")
	board.position = Vector2(60, 330)
	board.size = Vector2(600, 520)
	board.pivot_offset = board.size * 0.5
	add_child(board)
	title = LaneUI.ribbon("", 480, 32)
	title.position = Vector2(120, 290)
	add_child(title)

	stars_box = HBoxContainer.new()
	stars_box.add_theme_constant_override("separation", 18)
	stars_box.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_box.position = Vector2(0, 90)
	stars_box.size = Vector2(600, 84)
	board.add_child(stars_box)

	var reward := HBoxContainer.new()
	reward.alignment = BoxContainer.ALIGNMENT_CENTER
	reward.add_theme_constant_override("separation", 12)
	reward.position = Vector2(0, 196)
	reward.size = Vector2(600, 56)
	board.add_child(reward)
	reward.add_child(LaneUI.icon("icon_gem", Vector2(40, 46)))
	gems_label = LaneUI.label("", 40, LaneUI.GOLD)
	gems_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward.add_child(gems_label)

	info = LaneUI.label("", 22, LaneUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	info.position = Vector2(30, 262)
	info.size = Vector2(540, 34)
	board.add_child(info)

	var paper := Panel.new()
	LaneUI.dress(paper, "panel_paper")
	paper.position = Vector2(40, 306)
	paper.size = Vector2(520, 84)
	board.add_child(paper)
	tip = LaneUI.label("", 19, LaneUI.INK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tip.position = Vector2(14, 12)
	tip.size = Vector2(492, 60)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	paper.add_child(tip)

	back = Button.new()
	back.text = "본부로 돌아가기"
	LaneUI.button(back, "green", 26)
	back.position = Vector2(60, 410)
	back.size = Vector2(480, 84)
	back.pressed.connect(func():
		SoundManager.play_click()
		visible = false
		back_pressed.emit())
	board.add_child(back)

# Shows the result of a stage
func show_result(stage_id: int, won: bool, stars: int, gems: int, castle_ratio: float, reason: String) -> void:
	title.get_child(0).text = ("STAGE %d 클리어!" if won else "STAGE %d 실패") % stage_id
	for c in stars_box.get_children():
		c.queue_free()
	for i in range(3):
		var st := LaneUI.icon("icon_star" if won and i < stars else "icon_star_empty", Vector2(72, 72))
		st.pivot_offset = Vector2(36, 36)
		st.scale = Vector2.ZERO
		stars_box.add_child(st)
		var tw := st.create_tween()
		tw.tween_interval(0.25 + 0.22 * i)
		tw.tween_property(st, "scale", Vector2.ONE * 1.25, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(st, "scale", Vector2.ONE, 0.08)
		if won and i < stars:
			tw.tween_callback(func(): SoundManager.play_battle("b_summon", -6.0))
	gems_label.text = "+%d" % gems
	if won:
		info.text = "남은 성 체력 %d%%" % roundi(castle_ratio * 100.0)
		tip.text = "본부에서 보석으로 병사를 뽑고\n덱을 정비한 뒤 다음 스테이지로!"
	else:
		info.text = "놓을 수 있는 블록이 없어요" if reason == "stuck" else "성이 무너졌어요"
		tip.text = "요새를 깎은 만큼 보석을 받았어요\n병사를 뽑고 합성해서 다시 도전!"
	visible = true
	board.scale = Vector2(0.85, 0.85)
	modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.2)
	tw.tween_property(board, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
