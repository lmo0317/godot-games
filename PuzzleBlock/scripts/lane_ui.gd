class_name LaneUI
extends RefCounted
# Pixel-art fantasy UI for the 블록 기사단 screens (docs/ART_GUIDE.md, "블록 기사단 UI"): 9-slice
# styleboxes from the Codex UI kit in assets/art/ui/ (saved at x2 by tools/import_lane_ui.py, so
# the margins below are in those pixels), buttons, icons, the title ribbon and the gem bar.

const DIR: String = "res://assets/art/ui/"
const TEXT: Color = Color(1.0, 0.97, 0.9)
const INK: Color = Color(0.16, 0.1, 0.06)      # dark brown text on parchment
const OUTLINE: Color = Color(0.1, 0.06, 0.04)
const GOLD: Color = Color(1.0, 0.84, 0.32)
# 9-slice margins per piece: [left, top, right, bottom]
const MARGINS: Dictionary = {
	"panel_wood": [20, 20, 20, 20], "panel_paper": [12, 12, 12, 12], "card_frame": [16, 18, 16, 18],
	"btn_green": [12, 8, 12, 10], "btn_blue": [12, 8, 12, 10], "btn_red": [12, 8, 12, 10], "btn_grey": [12, 8, 12, 10],
}

static func tex(name: String) -> Texture2D:
	return load(DIR + name + ".png")

static func box(name: String, pad: int = -1, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex(name)
	var m: Array = MARGINS.get(name, [8, 8, 8, 8])
	sb.texture_margin_left = m[0]
	sb.texture_margin_top = m[1]
	sb.texture_margin_right = m[2]
	sb.texture_margin_bottom = m[3]
	var p: int = pad if pad >= 0 else m[0]
	sb.content_margin_left = p
	sb.content_margin_right = p
	sb.content_margin_top = p
	sb.content_margin_bottom = p
	sb.modulate_color = tint
	return sb

# A panel (Panel or PanelContainer) dressed as wood, parchment or a stone card frame
static func dress(c: Control, name: String = "panel_wood", tint: Color = Color.WHITE) -> void:
	c.add_theme_stylebox_override("panel", box(name, -1, tint))
	c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# Pixel button: green / blue / red, grey when disabled; light text with a dark outline
static func button(btn: BaseButton, color: String = "blue", font_size: int = 22) -> void:
	var name := "btn_" + color
	btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	btn.add_theme_stylebox_override("normal", box(name, 10))
	btn.add_theme_stylebox_override("hover", box(name, 10, Color(1.12, 1.12, 1.12)))
	btn.add_theme_stylebox_override("pressed", box(name, 10, Color(0.82, 0.82, 0.82)))
	btn.add_theme_stylebox_override("hover_pressed", box(name, 10, Color(0.82, 0.82, 0.82)))
	btn.add_theme_stylebox_override("disabled", box("btn_grey", 10))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if btn is Button:
		btn.add_theme_font_override("font", UIKit.FONT)
		btn.add_theme_font_size_override("font_size", font_size)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			btn.add_theme_color_override(key, TEXT)
		btn.add_theme_color_override("font_disabled_color", Color(0.85, 0.85, 0.85))
		btn.add_theme_color_override("font_outline_color", OUTLINE)
		btn.add_theme_constant_override("outline_size", 6)

static func label(text: String, size: int, col: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, outline: bool = true) -> Label:
	var l := UIKit.label(text, size, col, align)
	if outline:
		l.add_theme_constant_override("outline_size", 6)
		l.add_theme_color_override("font_outline_color", OUTLINE)
	return l

static func icon(name: String, sz: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(name)
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = sz
	t.size = sz
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

# Red title ribbon with a label; the folded ends keep their size and the middle stretches
static func ribbon(text: String, width: float, font_size: int = 30) -> Control:
	var r := NinePatchRect.new()
	r.texture = tex("ribbon")
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.patch_margin_left = 44
	r.patch_margin_right = 44
	r.patch_margin_top = 12
	r.patch_margin_bottom = 14
	r.size = Vector2(width, 64)
	r.custom_minimum_size = r.size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(text, font_size, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(0, 6)
	l.size = Vector2(width, 40)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	r.add_child(l)
	return r

# Three stars, filled up to n
static func stars(n: int, sz: float = 22.0) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(3):
		h.add_child(icon("icon_star" if i < n else "icon_star_empty", Vector2(sz, sz)))
	return h

# The currency bar shown on top of the 블록 기사단 screens: gems (and stars when given)
static func gem_bar(width: float) -> Panel:
	var bar := Panel.new()
	dress(bar, "panel_wood")
	bar.size = Vector2(width, 64)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gem := icon("icon_gem", Vector2(30, 34))
	gem.position = Vector2(20, 15)
	bar.add_child(gem)
	var gl := label("0", 28, GOLD)
	gl.name = "Gems"
	gl.position = Vector2(58, 10)
	gl.size = Vector2(200, 44)
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(gl)
	var star := icon("icon_star", Vector2(30, 30))
	star.position = Vector2(width - 160, 17)
	bar.add_child(star)
	var sl := label("", 24, TEXT)
	sl.name = "Stars"
	sl.position = Vector2(width - 124, 10)
	sl.size = Vector2(110, 44)
	sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(sl)
	return bar

static func set_gem_bar(bar: Panel) -> void:
	bar.get_node("Gems").text = str(LaneUnits.load_army()["gems"])
	bar.get_node("Stars").text = "%d/%d" % [LaneStages.total_stars(), LaneStages.count() * 3]

# Full-screen backdrop for the base screens: the battlefield, darkened
static func backdrop(parent: Control) -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://assets/art/lane/lane.png")
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.04, 0.08, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)
