class_name LaneTierCard
extends Panel
# A soldier card background in its star tier's colour (docs/LANE_UNITS.md) with the stone frame from
# the UI kit, and effects that grow with the tier:
#   유니크+   a light band sweeps across now and then
#   레전더리+ small stars twinkle on the card
#   신화+     the card glows and pulses
#   전설      gold, with a glow and sparkles running through the rainbow
# Content (soldier, labels) is added by the caller; the effects sit on top of it. Mouse input passes
# through, so it can sit inside a button.

var tier: int = 0
var _frame: NinePatchRect
var _bg: StyleBoxFlat
var _fx: Control
var _shine: ColorRect
var _clock: float = 0.0
var _next_shine: float = 0.6
var _next_spark: float = 0.2

func _init(t: int = 0, sz: Vector2 = Vector2(120, 140)) -> void:
	tier = t
	size = sz
	custom_minimum_size = sz
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg = StyleBoxFlat.new()
	_bg.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", _bg)
	_frame = NinePatchRect.new()
	_frame.texture = LaneUI.tex("card_frame")
	_frame.patch_margin_left = 16
	_frame.patch_margin_right = 16
	_frame.patch_margin_top = 18
	_frame.patch_margin_bottom = 18
	_frame.draw_center = false
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	set_tier(t)

func _ready() -> void:
	# The effects layer goes on top of whatever the caller added
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	_shine = ColorRect.new()
	_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shine.color = Color(1, 1, 1, 0.32)
	_shine.size = Vector2(16, size.y * 1.8)
	_shine.rotation = 0.35
	_shine.position = Vector2(-60, -size.y * 0.3)
	_shine.visible = false
	_fx.add_child(_shine)

func set_tier(t: int) -> void:
	tier = clampi(t, 0, LaneUnits.MAX_TIER)
	var col: Color = LaneUnits.tier_color(tier)
	_bg.bg_color = col.darkened(0.5)
	_bg.shadow_size = 0
	_frame.modulate = col.lightened(0.35) if tier >= 1 else Color(1, 1, 1)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_clock += delta
	if tier >= 2:
		_next_shine -= delta
		if _next_shine <= 0.0:
			_next_shine = 2.6 - 0.3 * (tier - 2)
			_sweep()
	if tier >= 3 and _fx != null:
		_next_spark -= delta
		if _next_spark <= 0.0:
			_next_spark = 0.5 - 0.08 * (tier - 3)
			_sparkle()
	if tier >= 4:
		var col: Color = LaneUnits.tier_color(tier)
		if tier >= 5:
			# 전설 stays gold; only its glow runs through the rainbow (so it never looks like another tier)
			col = Color.from_hsv(fmod(_clock * 0.3, 1.0), 0.7, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(_clock * 4.0)
		_bg.shadow_color = Color(col, 0.45 + 0.35 * pulse)
		_bg.shadow_size = int(4 + 6 * pulse)

func _sweep() -> void:
	if _shine == null:
		return
	_shine.visible = true
	_shine.position = Vector2(-40, -size.y * 0.3)
	var tw := _shine.create_tween()
	tw.tween_property(_shine, "position:x", size.x + 40, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _shine.visible = false)

func _sparkle() -> void:
	var s := TextureRect.new()
	s.texture = LaneUI.tex("icon_star")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var k: float = randf_range(8, 14)
	s.size = Vector2(k, k)
	s.pivot_offset = s.size * 0.5
	s.position = Vector2(randf_range(6, size.x - 18), randf_range(6, size.y - 18))
	s.modulate = Color(1, 1, 1, 0) if tier < 5 else Color.from_hsv(randf(), 0.4, 1.0, 0.0)
	s.scale = Vector2(0.3, 0.3)
	_fx.add_child(s)
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "modulate:a", 1.0, 0.18)
	tw.tween_property(s, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(s, "rotation", 0.8, 0.6)
	tw.chain().tween_property(s, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(s.queue_free)

# A one-off burst for a merge or a big pull: white flash and stars flying out
func burst() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)
	var ft := flash.create_tween()
	ft.tween_property(flash, "modulate:a", 0.0, 0.45)
	ft.tween_callback(flash.queue_free)
	pivot_offset = size * 0.5
	scale = Vector2(1.18, 1.18)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
