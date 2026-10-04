class_name TutorialHint
extends Node2D
# First-game hint: a hand picks up a tray piece and drags a see-through copy onto the spot that
# completes a line, over and over, with one line of text. It never blocks input; MainGame removes
# it as soon as the player grabs a piece.

const HAND: Texture2D = preload("res://assets/sprites/tap_hand.png")
const FINGERTIP := Vector2(60, 8)   # inside tap_hand.png (128px)
const TEXT := "블록을 끌어다 한 줄을 채우면 사라져요"

var piece: BlockPiece
var target: Vector2
var _hand: Sprite2D
var _ghost: Node2D
var _loop: Tween

# piece: the tray piece to use, target: global centre of that piece once placed,
# text_pos: global centre for the hint text
func setup(p: BlockPiece, t: Vector2, text_pos: Vector2) -> void:
	piece = p
	target = t
	z_index = 130
	var label := UIKit.label(TEXT, UIKit.TYPE_SECTION)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.09, 0.9))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(640, 40)
	label.position = text_pos - label.size * 0.5
	label.modulate.a = 0.0
	add_child(label)
	label.create_tween().tween_property(label, "modulate:a", 1.0, 0.3)

	# See-through copy of the piece at board size, carried above the finger like a real drag
	_ghost = Node2D.new()
	for c in piece.cell_sprites:
		var s := Sprite2D.new()
		s.texture = c.texture
		s.position = c.position
		_ghost.add_child(s)
	_ghost.modulate = Color(1, 1, 1, 0)
	add_child(_ghost)

	_hand = Sprite2D.new()
	_hand.texture = HAND
	_hand.centered = false
	_hand.offset = -FINGERTIP
	_hand.modulate.a = 0.0
	add_child(_hand)

	var start: Vector2 = piece.global_position
	var lift := Vector2(0, BlockPiece.DRAG_OFFSET_Y)
	var finger_end: Vector2 = target - lift
	_loop = create_tween().set_loops()
	_loop.tween_callback(func():
		_hand.position = start
		_hand.scale = Vector2.ONE
		_ghost.position = start
		_ghost.scale = Vector2.ONE * piece.tray_scale)
	_loop.tween_property(_hand, "modulate:a", 1.0, 0.25)
	# Press: the hand dips and the piece lifts to full size above the finger
	_loop.tween_property(_hand, "scale", Vector2.ONE * 0.88, 0.15)
	_loop.parallel().tween_property(_ghost, "modulate:a", 0.75, 0.15)
	_loop.parallel().tween_property(_ghost, "position", start + lift, 0.2)
	_loop.parallel().tween_property(_ghost, "scale", Vector2.ONE, 0.2)
	_loop.tween_property(_hand, "position", finger_end, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_loop.parallel().tween_property(_ghost, "position", target, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Release and fade out
	_loop.tween_property(_hand, "scale", Vector2.ONE, 0.12)
	_loop.tween_interval(0.3)
	_loop.tween_property(_hand, "modulate:a", 0.0, 0.25)
	_loop.parallel().tween_property(_ghost, "modulate:a", 0.0, 0.25)
	_loop.tween_interval(0.35)

func dismiss() -> void:
	if _loop:
		_loop.kill()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
