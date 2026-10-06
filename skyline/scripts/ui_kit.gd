class_name UIKit
extends RefCounted
## UI palette and builders in the painted base-builder look: chunky buttons with a dark rim, a glossy
## top and a lip (nine-patch pictures from tools/generate_ui.py in assets/ui), white text with a thick
## dark outline, see-through dark status bars.

const BG := Color(0.13, 0.19, 0.27)
const WINDOW := Color(0.2, 0.31, 0.44)
const WINDOW_HI := Color(0.3, 0.44, 0.58)
const BORDER := Color(0.93, 0.95, 1.0)
const TEXT := Color(1.0, 1.0, 1.0)
const MUTED := Color(0.78, 0.85, 0.94)
const GOLD := Color(1.0, 0.86, 0.3)
const GREEN := Color(0.55, 0.92, 0.4)
const RED := Color(1.0, 0.45, 0.42)
const ACCENT := Color(0.98, 0.6, 0.2)
const RIM := Color(0.106, 0.094, 0.149)        # dark outline of frames and text

const FONT: Font = preload("res://assets/fonts/font.ttf")
const UI_DIR := "res://assets/ui/%s.png"
const CORNER := 24                             # nine-patch margin of the frame pictures
const BUTTON_COLOR := {"primary": "orange", "secondary": "blue", "selected": "yellow", "danger": "red", "ok": "green"}


static func frame(name: String, margin: int = CORNER) -> StyleBoxTexture:
	## Nine-patch box from one of the pictures in assets/ui.
	var sb := StyleBoxTexture.new()
	sb.texture = load(UI_DIR % name)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	return sb


static func box(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 10, border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


static func window(_radius: int = 12) -> StyleBox:
	## Popup and shop window: slate blue with a thick dark rim.
	return frame("window")


static func hud() -> StyleBox:
	## See-through dark bar behind the status numbers.
	return frame("hud")


static func bubble() -> StyleBox:
	## The advisor's cream message box.
	return frame("bubble")


static func style_frames(btn: Button, color: String) -> void:
	var up := frame("btn_" + color)
	var down := frame("btn_%s_down" % color)
	down.content_margin_top += 3
	down.content_margin_bottom -= 3
	btn.add_theme_stylebox_override("normal", up)
	btn.add_theme_stylebox_override("hover", up)
	btn.add_theme_stylebox_override("pressed", down)
	btn.add_theme_stylebox_override("hover_pressed", down)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", frame("btn_gray"))


static func style_raised(btn: Button, _fill: Color, _line: Color, _lip: Color, _radius: int) -> void:
	## Kept for old callers: a green button.
	style_frames(btn, "green")


## kind: primary (orange), secondary (blue), selected (yellow), danger (red), ok (green), ghost (text only)
static func style_button(btn: Button, kind: String = "secondary", font_size: int = 22, _radius: int = 10) -> void:
	if kind == "ghost":
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			btn.add_theme_stylebox_override(st, box(Color(1, 1, 1, 0.0 if st == "normal" else 0.08)))
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	else:
		style_frames(btn, BUTTON_COLOR.get(kind, "blue"))
	btn.add_theme_font_override("font", FONT)
	btn.add_theme_font_size_override("font_size", font_size)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(key, TEXT if kind != "ghost" else MUTED)
	btn.add_theme_color_override("font_disabled_color", Color(0.9, 0.9, 0.92))
	btn.add_theme_color_override("font_outline_color", RIM)
	btn.add_theme_constant_override("outline_size", 0 if kind == "ghost" else maxi(4, font_size / 4))


static func label(text: String, size: int, color: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", RIM)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func outlined(l: Label, size: int = 6) -> Label:
	l.add_theme_constant_override("outline_size", size)
	return l


static func format_number(n: int) -> String:
	var s := str(absi(n))
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return ("-" if n < 0 else "") + res


static func money(n: int) -> String:
	return ("-$" if n < 0 else "$") + format_number(absi(n))
