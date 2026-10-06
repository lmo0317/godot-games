class_name FxLayer
extends Node2D
## Screen-space effects over the map: floating coin/number pops and star bursts. Positions are kept
## in map pixels and converted through the camera every frame, so they stick to the map.

var world: Node2D
var items: Array = []       # {at: Vector2 (map px), text, color, t, life, kind}
var font: Font


func _ready() -> void:
	font = UIKit.FONT
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func pop_text(at: Vector2, text: String, color: Color, coin: bool = false) -> void:
	if items.size() > 60:
		return
	items.append({"at": at, "text": text, "color": color, "t": 0.0, "life": 1.1, "kind": "coin" if coin else "text"})


func burst(at: Vector2, color: Color, size: float = 1.0) -> void:
	items.append({"at": at, "color": color, "t": 0.0, "life": 0.9, "kind": "burst", "size": size})


func _process(delta: float) -> void:
	for it in items:
		it["t"] += delta
	items = items.filter(func(it): return it["t"] < it["life"])
	queue_redraw()


func _draw() -> void:
	if world == null:
		return
	var xf := world.get_transform()
	var zoom := world.scale.x
	for it in items:
		var p: Vector2 = xf * it["at"]
		var k: float = it["t"] / it["life"]
		var alpha := 1.0 - maxf(0.0, k - 0.6) / 0.4
		match it["kind"]:
			"burst":
				var r: float = (6.0 + 22.0 * k) * zoom * 0.4 * it["size"]
				for a in 10:
					var ang := TAU * a / 10.0 + k
					var q := p + Vector2(cos(ang), sin(ang)) * r
					draw_rect(Rect2(q - Vector2(3, 3), Vector2(6, 6)), Color(it["color"], alpha))
				draw_arc(p, r * 0.8, 0, TAU, 32, Color(1, 1, 1, alpha * 0.7), 3.0)
			_:
				var rise := 34.0 * k + 8.0
				var at := p + Vector2(0, -rise - 8.0 * zoom)
				if it["kind"] == "coin":
					var hd := Art.tex("coin")
					if hd != null:
						draw_texture_rect(hd, Rect2((at - Vector2(26, 20)).round(), hd.get_size()), false, Color(1, 1, 1, alpha))
					else:
						var region := Atlas.region("coin")
						var s := region.size * 3.0
						draw_texture_rect_region(Atlas.texture, Rect2(at - Vector2(s.x + 2, s.y * 0.75), s), region, Color(1, 1, 1, alpha))
				var text: String = it["text"]
				var col: Color = it["color"]
				draw_string_outline(font, at + Vector2(-4, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Color(0.1, 0.08, 0.12, alpha))
				draw_string(font, at + Vector2(-4, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(col, alpha))
