class_name ScoreCounter
extends Control
# Big score at the top of the game screen, drawn with the glossy digits from
# tools/generate_combo_text.py. It rolls up to the new score: small gains tick quickly,
# combos roll longer with a bigger punch, a perfect clear rolls longest with a gold glow.

const DIR := "res://assets/sprites/combo/"
const RAYS: Texture2D = preload("res://assets/sprites/combo/rays.png")
const OVERLAP: float = 24.0
const DIGIT_H: float = 90.0
const MAX_WIDTH: float = 520.0

var target: int = 0
var shown: float = 0.0:
	set(v):
		shown = v
		_render(int(round(v)))

var _digits: Dictionary = {}
var _row: Control
var _glow: Sprite2D
var _roll: Tween
var _punch: Tween
var _text: String = ""
var _fit: float = 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for d in "0123456789":
		_digits[d] = load(DIR + "big_%s.png" % d)
	_digits[","] = load(DIR + "big_comma.png")
	_glow = Sprite2D.new()
	_glow.texture = RAYS
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = m
	_glow.modulate = Color(1, 1, 1, 0)
	add_child(_glow)
	_row = Control.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	resized.connect(_layout)
	_render(0)

# Jump straight to a value (new game, loading)
func reset(value: int) -> void:
	if _roll:
		_roll.kill()
	target = value
	shown = value

# Roll up to value. kind: "place" (a few points), "clear", "combo" or "perfect"
func roll_to(value: int, kind: String = "place") -> void:
	target = value
	if _roll:
		_roll.kill()
	var dur: float = {"place": 0.18, "clear": 0.35, "combo": 0.7, "perfect": 1.2}.get(kind, 0.3)
	_roll = create_tween()
	_roll.tween_property(self, "shown", float(value), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var strength: float = {"place": 1.06, "clear": 1.14, "combo": 1.28, "perfect": 1.42}.get(kind, 1.1)
	_bump(strength, dur, kind)

func _bump(strength: float, dur: float, kind: String) -> void:
	if _punch:
		_punch.kill()
	_row.pivot_offset = _row.size * 0.5
	_row.scale = Vector2.ONE * _fit * strength
	_punch = create_tween().set_parallel(true)
	_punch.tween_property(_row, "scale", Vector2.ONE * _fit, 0.25 + dur * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if kind == "combo" or kind == "perfect":
		var gold: bool = kind == "perfect"
		_row.modulate = Color(1.3, 1.15, 0.6) if gold else Color(1.15, 1.1, 0.8)
		_punch.tween_property(_row, "modulate", Color.WHITE, dur + 0.2)
		_glow.modulate = Color(1.0, 0.82, 0.3, 0.95) if gold else Color(0.55, 0.8, 1.0, 0.7)
		_glow.scale = Vector2.ONE * (0.45 if gold else 0.32)
		_glow.rotation = 0.0
		_punch.tween_property(_glow, "scale", Vector2.ONE * (0.75 if gold else 0.5), dur + 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_punch.tween_property(_glow, "rotation", 0.5, dur + 0.4)
		_punch.tween_property(_glow, "modulate:a", 0.0, 0.4).set_delay(dur)

func _render(value: int) -> void:
	var t := UIKit.format_number(value)
	if t == _text or _row == null:
		return
	_text = t
	# Reuse the TextureRects; only the textures change while rolling
	while _row.get_child_count() < t.length():
		var r := TextureRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.stretch_mode = TextureRect.STRETCH_KEEP
		_row.add_child(r)
	for i in range(_row.get_child_count()):
		var r: TextureRect = _row.get_child(i)
		r.visible = i < t.length()
		if r.visible:
			r.texture = _digits[t[i]]
	_layout()

func _layout() -> void:
	if _row == null:
		return
	var x := 0.0
	var count := _text.length()
	for i in range(count):
		var r: TextureRect = _row.get_child(i)
		var tex: Texture2D = r.texture
		var w: float = tex.get_width()
		var h: float = tex.get_height()
		var comma: bool = _text[i] == ","
		if i > 0:
			x -= OVERLAP + (10.0 if comma or _text[i - 1] == "," else 0.0)
		r.size = Vector2(w, h)
		# Comma sits on the baseline and dips a little below it
		r.position = Vector2(x, DIGIT_H - h * 0.72 if comma else (DIGIT_H - h) * 0.5)
		x += w
	_row.size = Vector2(x, DIGIT_H)
	_fit = minf(1.0, MAX_WIDTH / maxf(x, 1.0))
	_row.position = (size - _row.size) * 0.5
	if _punch == null or not _punch.is_running():
		_row.scale = Vector2.ONE * _fit
	_row.pivot_offset = _row.size * 0.5
	_glow.position = size * 0.5
