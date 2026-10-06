class_name CityBot
extends RefCounted
## A simple player for tests and balance runs: lays a road grid every 4 cells out from the highway,
## zones the cells next to the roads by demand, and adds power, water, services, parks, trees and
## landmarks when they are needed and affordable.

var city: City
var plan: Array[int] = []       # road cells to build, nearest to the entrance first
var planned := {}               # same cells as a set; nothing else is built on them
var spent := 0


func _init(c: City) -> void:
	city = c
	var e := City.pos(c.entrance)
	for y in City.N:
		for x in City.N:
			if (x - e.x) % 4 == 0 or (y - e.y) % 4 == 0:
				plan.append(City.idx(x, y))
	plan.sort_custom(func(a, b): return _dist(a, e) < _dist(b, e))
	for i in plan:
		planned[i] = true


func _dist(i: int, e: Vector2i) -> int:
	var p := City.pos(i)
	return absi(p.x - e.x) + absi(p.y - e.y)


func play_month() -> void:
	## Called once per game month before the weeks run.
	_roads()
	_utilities()
	_zones()
	_services()
	_extras()
	city.refresh()


func _try(cost: int) -> bool:
	if cost < 0:
		return false
	spent += cost
	return true


func _roads() -> void:
	var budget := 12 if city.money > 400 else 0
	for i in plan:
		if budget <= 0 or city.money < 200:
			break
		if city.obj[i] == Defs.ROAD or not city.is_active(i):
			continue
		# only extend from a connected road so every road is useful
		var p := City.pos(i)
		var touches := false
		for d in City.DIRS:
			var q: Vector2i = p + d
			if City.inside(q.x, q.y) and city.connected[City.idx(q.x, q.y)] == 1:
				touches = true
		if not touches:
			continue
		if city.terrain[i] == Defs.T.WATER and city.money < 1500:
			continue
		if _try(city.place_road(i)):
			city.connected[i] = 1
			budget -= 1


func _zones() -> void:
	var order := [Defs.Z.R, Defs.Z.C, Defs.Z.I]
	order.sort_custom(func(a, b): return city.demand[a] > city.demand[b])
	var budget := 24
	for z in order:
		if city.demand[z] <= -0.1:
			continue
		var empty_lots := 0
		for i in City.CELLS:
			if city.zone[i] == z and city.level[i] == 0:
				empty_lots += 1
		if empty_lots > 6:
			continue
		for i in City.CELLS:
			if budget <= 0 or city.money < 150:
				return
			if planned.has(i) or city.zone[i] != Defs.Z.NONE or city.obj[i] != 0 or not _next_to_road(i):
				continue
			if _try(city.place_zone(i, z)):
				budget -= 1
				empty_lots += 1
				if empty_lots > 10:
					break


func _next_to_road(i: int) -> bool:
	var p := City.pos(i)
	for d in City.DIRS:
		var q: Vector2i = p + d
		if City.inside(q.x, q.y) and city.connected[City.idx(q.x, q.y)] == 1:
			return true
	return false


func _free_spot_near(target: Vector2i) -> int:
	## Nearest active cell that is not a road, lot or facility and not next to a road (block middles).
	var best := -1
	var best_d := 1 << 20
	for i in City.CELLS:
		if planned.has(i) or not city.is_active(i) or city.obj[i] != 0 or city.zone[i] != Defs.Z.NONE or city.terrain[i] == Defs.T.WATER:
			continue
		var p := City.pos(i)
		var d := (p - target).length_squared()
		if _next_to_road(i):
			d += 30
		if d < best_d:
			best_d = d
			best = i
	return best


func _uncovered_center(arr: PackedByteArray, bit: int = 1) -> Vector2i:
	var sum := Vector2i.ZERO
	var n := 0
	for i in City.CELLS:
		if city.zone[i] != Defs.Z.NONE and (arr[i] & bit) == 0:
			sum += City.pos(i)
			n += 1
	if n == 0:
		return Vector2i(-1, -1)
	return sum / n


func _utilities() -> void:
	for id in [2, 3]:
		var arr: PackedByteArray = city.power if id == 2 else city.water
		var spot := -1
		if _count(id) == 0:
			spot = _free_spot_near(City.pos(city.entrance) + Vector2i(10, 0))
		else:
			spot = _best_cover_spot(arr, 1, int(Defs.fac(id)["radius"]), true)
		if spot >= 0 and _try(city.place_facility(spot, id)):
			city.refresh()


func _count(id: int) -> int:
	var n := 0
	for i in City.CELLS:
		if city.obj[i] == id:
			n += 1
	return n


func _services() -> void:
	for id in [8, 7, 10, 9]:
		if not city.unlocked(id) or city.money < 900:
			continue
		var spot := _best_cover_spot(city.service, Defs.SERVICE_BIT[id], int(Defs.fac(id)["radius"]))
		if spot >= 0 and _try(city.place_facility(spot, id)):
			city.refresh()


func _best_cover_spot(arr: PackedByteArray, bit: int, radius: int, square := false) -> int:
	## Free cell whose area (square for power and water, else round) covers the most zoned cells
	## that lack this service (at least 6).
	var best := -1
	var best_n := 5
	for i in City.CELLS:
		if planned.has(i) or not city.is_active(i) or city.obj[i] != 0 or city.zone[i] != Defs.Z.NONE or city.terrain[i] == Defs.T.WATER:
			continue
		var p := City.pos(i)
		var n := 0
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if (not square and dx * dx + dy * dy > radius * radius + radius) or not City.inside(p.x + dx, p.y + dy):
					continue
				var j := City.idx(p.x + dx, p.y + dy)
				if city.zone[j] != Defs.Z.NONE and (arr[j] & bit) == 0:
					n += 1
		if n > best_n:
			best_n = n
			best = i
	return best


func _extras() -> void:
	# parks and trees in block middles, a fountain now and then, landmarks when rich
	if city.money > 600:
		for i in City.CELLS:
			if city.zone[i] == Defs.Z.R and city.level[i] >= 1 and city.land[i] < 45:
				var spot := _free_spot_near(City.pos(i))
				if spot >= 0 and (City.pos(spot) - City.pos(i)).length() <= 2.0:
					var id := 4 if city.rng.randf() < 0.6 else 5
					if id == 4 and city.unlocked(6) and city.rng.randf() < 0.25:
						id = 6
					if _try(city.place_facility(spot, id)):
						city.refresh()
						break
	for id in [11, 12, 13]:
		if city.unlocked(id) and not city.has_landmark(id) and city.money > int(Defs.fac(id)["cost"]) + 800:
			var spot := _free_spot_near(City.pos(city.entrance) + Vector2i(8, 0))
			if spot >= 0:
				_try(city.place_facility(spot, id))


func run(years: int = Defs.YEARS) -> void:
	city.year_end.connect(func(_y): city.choose_policy(city.policy_choices()[0]["key"]))
	for m in years * 12:
		if city.finished:
			break
		play_month()
		for w in Defs.WEEKS:
			city.step_week()
