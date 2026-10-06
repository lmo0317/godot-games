class_name MapView
extends Node2D
## Draws the city in isometric view, painted base-builder look (one map tile = a 64x32 diamond); the
## parent node scales and moves it (camera). Buildings are low and stand on a yard tile, so they do
## not hide each other.
## Three layers, back to front:
##   this node      ground: sea around the island, grass, roads, lots and yards, coverage tint, cliffs
##   Buildings      sprites from the back row to the front row
##   Overlays       fires, warnings, broken roads, previews, selection
## Sprites come from assets/sprites/px (tools/paint_art.py, tools/generate_ground.py) and are stored
## at 2x detail: drawn at half size, so at the normal 2x zoom one sprite pixel is one screen pixel.

const TW := 64
const TH := 32
const HW := 32                  # TW / 2
const HH := 16                  # TH / 2
const DETAIL := 2.0
const FOOT := 0.8               # buildings stand on 80% of the tile; the rest is their yard
const EDGE_H := 12.0            # height of the rock cliff under the front edges of the island
const SEA_RING := 5             # sea tiles drawn around the island (beyond them the clear color is sea)
const ZONE_KEY := ["", "r", "c", "i"]
const ZONE_EMBLEM := ["", "ui_res", "ui_com", "ui_ind"]
const PLAIN := ["tree", "park", "fountain", "stadium"]     # facilities that bring their own ground
const LOCKED := Color(0.5, 0.52, 0.6)
const WARN := {"road": "warn_road", "power": "warn_power", "water": "warn_water"}

var city: City
var time := 0.0
var preview := {}               # cell -> true (ok) / false (not allowed)
var ghost := ""                 # sprite drawn on the hovered cell for facilities
var ghost_cell := -1
var ghost_radius := 0
var ghost_square := false       # power and water reach a square, the services a round area
var ghost_roads := {}           # cells drawn as road while a road is being placed
var handle_cell := -1           # green arrows around this cell: drag here
var hide_cell := -1             # a building lifted for moving is not drawn in place
var fade_trees := false         # while editing, forests are see-through so the ground shows
var preview_ok := Color(0.4, 1.0, 0.5, 0.45)
var overlay := ""               # "", "power", "water", "svc:<bit>" or "land"
var selected := -1
var fires := {}                 # cell -> seconds left
var has_warnings := false

var buildings: Node2D
var overlays: Node2D


class Layer:
	extends Node2D
	var paint: Callable

	func _draw() -> void:
		paint.call(self)


func _ready() -> void:
	Atlas.load_once()
	texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE   # the camera node picks smooth or crisp
	buildings = Layer.new()
	buildings.paint = _draw_buildings
	add_child(buildings)
	overlays = Layer.new()
	overlays.paint = _draw_overlays
	add_child(overlays)


func _process(delta: float) -> void:
	var before := int(time * 2.0)
	time += delta
	for c in fires.keys():
		fires[c] -= delta
		if fires[c] <= 0.0:
			fires.erase(c)
	# water ripples swap twice a second; warnings bob and broken roads pulse every frame
	if int(time * 2.0) != before:
		queue_redraw()
	elif not fires.is_empty() or has_warnings or handle_cell >= 0:
		overlays.queue_redraw()


# ---------------------------------------------------------------- geometry
static func grid_to_local(g: Vector2) -> Vector2:
	## Grid position (cell centers at whole numbers) -> map pixels.
	return Vector2((g.x - g.y) * HW, (g.x + g.y) * HH)


func cell_center(i: int) -> Vector2:
	return grid_to_local(Vector2(City.pos(i)))


func cell_at(local: Vector2) -> int:
	var u := local.x / HW
	var v := local.y / HH
	var gx := roundi((u + v) * 0.5)
	var gy := roundi((v - u) * 0.5)
	if not City.inside(gx, gy):
		return -1
	return City.idx(gx, gy)


func diamond(i: int) -> PackedVector2Array:
	var c := cell_center(i)
	return PackedVector2Array([c + Vector2(0, -HH), c + Vector2(HW, 0), c + Vector2(0, HH), c + Vector2(-HW, 0)])


func active_bounds() -> Rect2:
	## Screen-aligned box around the playable diamond, in map pixels.
	var a := city.active_rect()
	var top := grid_to_local(Vector2(a.position) - Vector2(0.5, 0.5))
	var right := grid_to_local(Vector2(a.end.x, a.position.y) - Vector2(0.5, 0.5))
	var bottom := grid_to_local(Vector2(a.end) - Vector2(0.5, 0.5))
	var left := grid_to_local(Vector2(a.position.x, a.end.y) - Vector2(0.5, 0.5))
	return Rect2(Vector2(left.x, top.y), Vector2(right.x - left.x, bottom.y - top.y))


# ---------------------------------------------------------------- drawing helpers
func _tile(ci: CanvasItem, name: String, i: int, modulate: Color = Color.WHITE) -> void:
	var t := Art.tex(name)
	if t != null:
		ci.draw_texture_rect(t, Rect2(cell_center(i) - Vector2(HW, HH), Vector2(TW, TH)), false, modulate)


func _sprite_rect(t: Texture2D, i: int) -> Rect2:
	## Bottom of the picture on the front corner of the building's footprint (FOOT of the tile).
	var size := t.get_size() / DETAIL
	var c := cell_center(i)
	return Rect2(Vector2(roundf(c.x - size.x * 0.5), roundf(c.y + HH * FOOT - size.y)), size)


func _spr(ci: CanvasItem, name: String, i: int, modulate: Color = Color.WHITE) -> void:
	var t := Art.tex(name)
	if t != null:
		ci.draw_texture_rect(t, _sprite_rect(t, i), false, modulate)


func sprite_top(i: int) -> float:
	var s := sprite_for(i)
	var t := Art.tex(s) if s != "" else null
	return _sprite_rect(t, i).position.y if t != null else cell_center(i).y - TH


func _road_mask(p: Vector2i) -> int:
	var m := 0
	var bits := [1, 2, 4, 8]
	for k in 4:
		var q: Vector2i = p + City.DIRS[k]
		if City.inside(q.x, q.y):
			var j := City.idx(q.x, q.y)
			if city.obj[j] == Defs.ROAD or ghost_roads.has(j):
				m |= bits[k]
		elif k == 3:
			m |= 8          # the highway runs off the map edge
	return m


func _shore_mask(p: Vector2i) -> int:
	var m := 0
	var bits := [1, 2, 4, 8]
	for k in 4:
		var q: Vector2i = p + City.DIRS[k]
		if City.inside(q.x, q.y) and city.terrain[City.idx(q.x, q.y)] != Defs.T.WATER:
			m |= bits[k]
	return m


func sprite_for(i: int) -> String:
	var o := city.obj[i]
	if o >= 2:
		return Defs.fac(o)["key"]
	var z := city.zone[i]
	if z != Defs.Z.NONE and city.level[i] > 0:
		if city.build[i] > 0:
			return "scaffold_" + ZONE_KEY[z]
		var lv := city.level[i]
		var v := city.variant[i]
		match z:
			Defs.Z.R:
				if lv == 1:
					return ["house_a", "house_b", "house_c"][v % 3]
				return _variant("rowhouse" if lv == 2 else "apartment", v)
			Defs.Z.C:
				if lv == 3:
					return _variant("dept", v)
				var shop: String = Defs.SHOPS[v % Defs.SHOPS.size()]
				return shop if lv == 1 else shop + "_2"
			Defs.Z.I:
				return _variant(["", "workshop", "factory", "hightech"][lv], v)
	if city.terrain[i] == Defs.T.FOREST:
		return "forest"
	return ""


func _variant(base: String, v: int) -> String:
	var names := [base]
	for suffix in ["_b", "_c"]:
		if Art.has(base + suffix):
			names.append(base + suffix)
	return names[v % names.size()]


# ---------------------------------------------------------------- layer 1: ground
func _draw() -> void:
	if city == null:
		return
	var frame := int(time * 2.0) % 2
	_draw_sea(frame)
	for i in City.CELLS:
		var p := City.pos(i)
		var tint := Color.WHITE if city.is_active(i) else LOCKED
		var o := city.obj[i]
		if city.terrain[i] == Defs.T.WATER:
			_tile(self, "water%d_%d" % [_shore_mask(p), frame], i, tint)
		else:
			_tile(self, "grass%d" % ((p.x + p.y) % 2), i, tint)     # light / dark checker
		if o == Defs.ROAD or ghost_roads.has(i):
			var see := tint if o == Defs.ROAD else Color(1, 1, 1, 0.8)
			_tile(self, ("bridge%d" if city.terrain[i] == Defs.T.WATER else "road%d") % _road_mask(p), i, see)
		elif city.zone[i] != Defs.Z.NONE:
			# zoned land keeps its yard under the building, like a plot in a town game
			_tile(self, "lot_" + ZONE_KEY[city.zone[i]], i)
			if city.level[i] == 0:
				_emblem(i, city.zone[i])
		elif o >= 2 and not (Defs.fac(o)["key"] in PLAIN):
			_tile(self, "lot_c", i, tint)
	_draw_map_edge()
	if overlay != "":
		_draw_overlay()
	buildings.queue_redraw()
	overlays.queue_redraw()


func _emblem(i: int, z: int) -> void:
	## Faint house / shop / factory picture: "this is a residential / commercial / industrial plot".
	var emblem := Art.tex(ZONE_EMBLEM[z])
	if emblem != null:
		var size := emblem.get_size() / DETAIL
		draw_texture_rect(emblem, Rect2((cell_center(i) - size * 0.5 - Vector2(0, 2)).round(), size), false, Color(1, 1, 1, 0.5))


func _draw_sea(frame: int) -> void:
	## The sea around the island: beach and foam on the tiles touching land, then open water.
	## The highway reaches the island over a long bridge from the left.
	var n := City.N
	var bits := [1, 2, 4, 8]
	for gy in range(-SEA_RING, n + SEA_RING):
		for gx in range(-SEA_RING, n + SEA_RING):
			if City.inside(gx, gy):
				continue
			var m := 0
			for k in 4:
				var q: Vector2i = Vector2i(gx, gy) + City.DIRS[k]
				if City.inside(q.x, q.y) and city.terrain[City.idx(q.x, q.y)] != Defs.T.WATER:
					m |= bits[k]
			var t := Art.tex("water%d_%d" % [m, frame])
			if t != null:
				draw_texture_rect(t, Rect2(grid_to_local(Vector2(gx, gy)) - Vector2(HW, HH), Vector2(TW, TH)), false)
	var hy := City.pos(city.entrance).y
	var deck := Art.tex("bridge10")
	for gx in range(-SEA_RING, 0):
		draw_texture_rect(deck, Rect2(grid_to_local(Vector2(gx, hy)) - Vector2(HW, HH), Vector2(TW, TH)), false)


func _draw_map_edge() -> void:
	## Rock cliffs under the two front edges of the island, with foam where they meet the sea.
	var n := City.N
	for k in n:
		for side in 2:
			var i := City.idx(n - 1, k) if side == 0 else City.idx(k, n - 1)
			var c := cell_center(i)
			var a := c + (Vector2(HW, 0) if side == 0 else Vector2(-HW, 0))
			var b := c + Vector2(0, HH)
			var lit := 1.0 if side == 0 else 0.82          # the right-facing side gets more light
			var top := Color(0.78, 0.68, 0.55) * lit
			var low := Color(0.5, 0.42, 0.36) * lit
			if not city.is_active(i):
				top = top * LOCKED
				low = low * LOCKED
			top.a = 1.0
			low.a = 1.0
			var down := Vector2(0, EDGE_H)
			draw_polygon(PackedVector2Array([a, b, b + down, a + down]), PackedColorArray([top, top, low, low]))
			# a few darker cracks so it reads as rock
			var mid := (a + b) * 0.5
			draw_line(mid + Vector2(0, 3), mid + Vector2(0, EDGE_H - 2), Color(low, 0.6), 1.0)
			draw_line(a + down, b + down, Color(1, 1, 1, 0.85), 1.5)          # foam at the foot


func _draw_overlay() -> void:
	var arr: PackedByteArray
	var bit := 1
	var col := Color(1, 1, 1)
	if overlay == "power":
		arr = city.power
		col = Color(1.0, 0.85, 0.2)
	elif overlay == "water":
		arr = city.water
		col = Color(0.3, 0.7, 1.0)
	elif overlay.begins_with("svc:"):
		arr = city.service
		bit = int(overlay.substr(4))
		col = Color(0.5, 1.0, 0.6)
	elif overlay == "land":
		for i in City.CELLS:
			if city.is_active(i):
				var v := city.land[i] / 100.0
				draw_colored_polygon(diamond(i), Color(1.0 - v, v, 0.2, 0.35))
		return
	else:
		return
	for i in City.CELLS:
		if city.is_active(i) and (arr[i] & bit):
			draw_colored_polygon(diamond(i), Color(col, 0.3))


# ---------------------------------------------------------------- layer 2: buildings (back to front)
func _draw_buildings(ci: CanvasItem) -> void:
	if city == null:
		return
	var n := City.N
	for s in 2 * n - 1:
		for x in range(maxi(0, s - n + 1), mini(s, n - 1) + 1):
			var i := City.idx(x, s - x)
			var name := sprite_for(i) if i != hide_cell else ""
			if name != "":
				var tint := Color.WHITE if city.is_active(i) else LOCKED
				if fade_trees and name == "forest":
					tint.a = 0.35
				_spr(ci, name, i, tint)
	if ghost_cell >= 0 and ghost != "":
		_spr(ci, ghost, ghost_cell, Color(1, 1, 1, 0.85))


# ---------------------------------------------------------------- layer 3: overlays
func _draw_overlays(ci: CanvasItem) -> void:
	if city == null:
		return
	for c in fires:
		var r := Atlas.region("fire%d" % (int(time * 8.0) % 2))
		var at := cell_center(c) + Vector2(-r.size.x, HH * FOOT - r.size.y * 2)
		ci.draw_texture_rect_region(Atlas.texture, Rect2(at, r.size * 2), r)
	_draw_warnings(ci)
	_draw_active_outline(ci)
	_draw_preview(ci)
	if selected >= 0:
		var d := diamond(selected)
		d.append(d[0])
		ci.draw_polyline(d, Color(1, 0.95, 0.4), 2.0)


func warning_of(i: int) -> String:
	## What a zoned cell is missing first: "road", "power", "water" or "".
	if city.zone[i] == Defs.Z.NONE:
		return ""
	if city.access_road[i] < 0:
		return "road"
	if city.power[i] == 0:
		return "power"
	if city.water[i] == 0:
		return "water"
	return ""


func _draw_warnings(ci: CanvasItem) -> void:
	var any := false
	# roads that do not reach the highway pulse red
	var pulse := 0.3 + 0.2 * sin(time * 5.0)
	for i in City.CELLS:
		if city.obj[i] == Defs.ROAD and city.connected[i] == 0 and city.is_active(i):
			ci.draw_colored_polygon(diamond(i), Color(1.0, 0.15, 0.1, pulse))
			any = true
	if any or city.road_count < 14:
		_draw_highway_arrow(ci)
		any = true
	var bob := roundf(sin(time * 4.0) * 1.5)
	for i in City.CELLS:
		var w := warning_of(i)
		if w == "":
			continue
		any = true
		var t := Art.tex(WARN[w])
		if t == null:
			continue
		var size := t.get_size() / DETAIL
		var built := city.level[i] > 0 and city.build[i] == 0
		var top := sprite_top(i) - size.y + 4 if built else cell_center(i).y - size.y + 4
		ci.draw_texture_rect(t, Rect2(Vector2(roundf(cell_center(i).x - size.x * 0.5), top + bob), size), false)
	has_warnings = any


func _draw_highway_arrow(ci: CanvasItem) -> void:
	## Bobbing arrow over the end of the highway: build roads from here.
	# the highway is built up to one cell inside the starting square (City._generate_once)
	var p := Vector2i((City.N - Defs.rank_size(0)) / 2 + 1, City.pos(city.entrance).y)
	var c := cell_center(City.idx(p.x, p.y)) + Vector2(0, -14.0 + roundf(sin(time * 5.0) * 2.0))
	var pts := PackedVector2Array([c + Vector2(-5, -10), c + Vector2(5, -10), c + Vector2(5, -4), c + Vector2(10, -4), c + Vector2(0, 6), c + Vector2(-10, -4), c + Vector2(-5, -4)])
	ci.draw_colored_polygon(pts, Color(1.0, 0.85, 0.2))
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(0.17, 0.14, 0.21), 1.0)


func _draw_active_outline(ci: CanvasItem) -> void:
	var a := city.active_rect()
	var pts := PackedVector2Array([
		grid_to_local(Vector2(a.position) - Vector2(0.5, 0.5)),
		grid_to_local(Vector2(a.end.x, a.position.y) - Vector2(0.5, 0.5)),
		grid_to_local(Vector2(a.end) - Vector2(0.5, 0.5)),
		grid_to_local(Vector2(a.position.x, a.end.y) - Vector2(0.5, 0.5)),
	])
	pts.append(pts[0])
	ci.draw_polyline(pts, Color(1, 1, 1, 0.45), 1.0)


func _draw_preview(ci: CanvasItem) -> void:
	for c in preview:
		ci.draw_colored_polygon(diamond(c), preview_ok if preview[c] else Color(1.0, 0.3, 0.3, 0.45))
	if ghost_cell >= 0 and ghost_radius > 0 and ghost_square:
		# a square on the grid is a diamond on screen
		var g := Vector2(City.pos(ghost_cell))
		var r := ghost_radius + 0.5
		var pts := PackedVector2Array([grid_to_local(g + Vector2(-r, -r)), grid_to_local(g + Vector2(r, -r)),
			grid_to_local(g + Vector2(r, r)), grid_to_local(g + Vector2(-r, r))])
		pts.append(pts[0])
		ci.draw_polyline(pts, Color(1, 1, 1, 0.9), 2.0)
	elif ghost_cell >= 0 and ghost_radius > 0:
		# a circle on the grid is an ellipse on screen
		var r := (ghost_radius + 0.5) * HW * sqrt(2.0)
		ci.draw_set_transform(cell_center(ghost_cell), 0.0, Vector2(1.0, float(TH) / TW))
		ci.draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(1, 1, 1, 0.85), 2.0)
		ci.draw_set_transform(Vector2.ZERO)
	if handle_cell >= 0:
		_draw_arrows(ci, handle_cell)


const ARROW_DIRS := [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]


func _arrow_frame(i: int, d: Vector2) -> Array:
	## [base point, outward direction] of the arrow past one tile edge.
	var edge_mid := cell_center(i) + Vector2(d.x * HW * 0.5, d.y * HH * 0.5)
	var n := Vector2(d.x, d.y * 0.8).normalized()
	return [edge_mid + n * 9.0, n]


func arrow_centers(i: int) -> Array:
	## Map positions of the four arrows (for touch tests).
	var out: Array = []
	for d in ARROW_DIRS:
		var f := _arrow_frame(i, d)
		out.append(f[0] + f[1] * 3.0)
	return out


func _draw_arrows(ci: CanvasItem, i: int) -> void:
	## Four green arrows just outside the tile edges, pointing diagonally away (up-left, up-right,
	## down-left, down-right) like base-builder games: "drag me".
	var bob := roundf(sin(time * 6.0) * 1.5)
	var shape := [Vector2(10, 0), Vector2(3, 7), Vector2(3, 3), Vector2(-4, 3), Vector2(-4, -3), Vector2(3, -3), Vector2(3, -7)]
	for d in ARROW_DIRS:
		var f := _arrow_frame(i, d)
		var n: Vector2 = f[1]
		var base: Vector2 = f[0] + n * bob
		var side := Vector2(-n.y, n.x)
		var pts := PackedVector2Array()
		for q in shape:
			pts.append(base + n * q.x + side * q.y)
		ci.draw_colored_polygon(pts, Color(0.45, 0.95, 0.3))
		pts.append(pts[0])
		ci.draw_polyline(pts, Color(0.08, 0.3, 0.05), 1.0)
