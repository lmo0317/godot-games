class_name City
extends RefCounted
## The whole simulation: map, buildings, money, time. No nodes, so tests and the balance bot can run it
## headless. The game screen listens to the signals and draws the state.

signal notice(text: String, kind: String)       # kind: info, good, bad, event
signal built(cell: int)                         # a building finished construction
signal burned(cell: int)
signal rank_up(rank: int)
signal month_passed(income: int, expense: int)
signal year_end(year: int)
signal finished_run(score: int)

const N := Defs.MAP
const CELLS := N * N
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var seed_value := 0
var mode := "normal"            # normal or daily
var rng := RandomNumberGenerator.new()

# map state (one entry per cell, index = y * N + x)
var terrain := PackedByteArray()
var obj := PackedByteArray()        # 0 none, 1 road, 2.. facility id
var zone := PackedByteArray()       # Defs.Z
var level := PackedByteArray()      # 0 empty lot, 1..3 building level
var variant := PackedByteArray()    # shop type or house color
var build := PackedByteArray()      # weeks of construction left

var money := Defs.START_MONEY
var month := 0                  # months elapsed since the start
var week := 0
var rank := 0
var tax := 1
var event_key := ""
var event_left := 0
var policy_key := ""
var policy_left := 0
var finished := false
var final_score := -1
var entrance := 0

# derived each refresh()
var connected := PackedByteArray()      # road cell reaches the highway
var access_road := PackedInt32Array()   # nearest connected road for a building or lot, -1 if none
var power := PackedByteArray()
var water := PackedByteArray()
var service := PackedByteArray()        # bits: Defs.SERVICE_BIT
var land := PackedByteArray()           # land value 0..100
var pop := 0
var cjobs := 0
var ijobs := 0
var happiness := 60
var demand := [0.0, 0.0, 0.0, 0.0]      # indexed by Defs.Z
var landmarks := 0
var road_count := 0
var last_income := 0
var last_expense := 0
var growth_mult := 1.0


func new_game(seed_in: int, mode_in: String = "normal") -> void:
	seed_value = seed_in
	mode = mode_in
	rng.seed = seed_in
	money = Defs.START_MONEY
	month = 0
	week = 0
	rank = 0
	tax = 1
	event_key = ""
	event_left = 0
	policy_key = ""
	policy_left = 0
	finished = false
	final_score = -1
	_generate()
	refresh()


# ---------------------------------------------------------------- helpers
static func idx(x: int, y: int) -> int:
	return y * N + x


static func pos(i: int) -> Vector2i:
	return Vector2i(i % N, i / N)


static func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < N and y < N


func active_rect() -> Rect2i:
	var s := Defs.rank_size(rank)
	var o := (N - s) / 2
	return Rect2i(o, o, s, s)


func is_active(i: int) -> bool:
	return active_rect().has_point(pos(i))


func year() -> int:
	return month / 12 + 1


func month_of_year() -> int:
	return month % 12 + 1


func months_total() -> int:
	return Defs.YEARS * 12


func is_road(i: int) -> bool:
	return obj[i] == Defs.ROAD


func kind_of(i: int) -> String:
	## Name used by the info panel and the sprites ("" when empty or still being built).
	var o := obj[i]
	if o >= 2:
		return Defs.fac(o)["key"]
	var z := zone[i]
	var lv := level[i]
	if z == Defs.Z.NONE or lv == 0 or build[i] > 0:
		return ""
	match z:
		Defs.Z.R:
			return ["", "house", "rowhouse", "apartment"][lv]
		Defs.Z.C:
			return "dept" if lv == 3 else Defs.SHOPS[variant[i] % Defs.SHOPS.size()]
		Defs.Z.I:
			return ["", "workshop", "factory", "hightech"][lv]
	return ""


func working(i: int) -> bool:
	## A building gets people/jobs only with a road, power and water.
	return access_road[i] >= 0 and power[i] == 1 and water[i] == 1


func unlocked(fac_id: int) -> bool:
	return rank >= int(Defs.fac(fac_id).get("rank", 0))


func has_landmark(fac_id: int) -> bool:
	for i in CELLS:
		if obj[i] == fac_id:
			return true
	return false


# ---------------------------------------------------------------- map generation
func _generate() -> void:
	for attempt in 20:
		_generate_once()
		var r := active_rect()
		var wet := 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if terrain[idx(x, y)] == Defs.T.WATER:
					wet += 1
		if wet <= r.get_area() / 4:
			return


func _generate_once() -> void:
	terrain = PackedByteArray()
	terrain.resize(CELLS)
	obj = PackedByteArray()
	obj.resize(CELLS)
	zone = PackedByteArray()
	zone.resize(CELLS)
	level = PackedByteArray()
	level.resize(CELLS)
	variant = PackedByteArray()
	variant.resize(CELLS)
	build = PackedByteArray()
	build.resize(CELLS)
	# the whole map is one island (the sea is drawn around it), so no water on the land
	# forests: a few blobs plus scattered trees
	for k in rng.randi_range(5, 8):
		var cx := rng.randi_range(0, N - 1)
		var cy := rng.randi_range(0, N - 1)
		var r := rng.randf_range(1.5, 3.8)
		for y in range(cy - 4, cy + 5):
			for x in range(cx - 4, cx + 5):
				if inside(x, y) and Vector2(x - cx, y - cy).length() + rng.randf() * 1.2 < r and terrain[idx(x, y)] == Defs.T.GRASS:
					terrain[idx(x, y)] = Defs.T.FOREST
	for i in CELLS:
		if terrain[i] == Defs.T.GRASS and rng.randf() < 0.02:
			terrain[i] = Defs.T.FOREST
	# highway from the left edge (over a bridge from the mainland) into the starting square
	var hy := rng.randi_range(12, 19)
	var start := active_rect().position.x
	for x in range(0, start + 2):
		var i := idx(x, hy)
		if terrain[i] == Defs.T.FOREST:
			terrain[i] = Defs.T.GRASS
		obj[i] = Defs.ROAD
	entrance = idx(0, hy)


func _make_river(x0: int, _vertical: bool) -> void:
	var x := float(x0)
	var drift := rng.randf_range(-0.4, 0.4)
	var prev := int(round(x))
	for y in N:
		var w := 2 if rng.randf() < 0.85 else 3
		var cur := int(round(x))
		# cover the step from the row above so the river stays one connected strip
		_water_row(y, mini(prev, cur), maxi(prev, cur) + w - 1)
		prev = cur
		x += drift + rng.randf_range(-0.7, 0.7)
		x = clampf(x, 4.0, N - 6.0)
		if rng.randf() < 0.15:
			drift = rng.randf_range(-0.5, 0.5)


func _water_row(y: int, x0: int, x1: int) -> void:
	for xx in range(x0, x1 + 1):
		if inside(xx, y):
			terrain[idx(xx, y)] = Defs.T.WATER


func _stream(x_start: int, y_from: int, y_to: int, stop_at_water: bool = true) -> void:
	## One-cell stream from y_from toward y_to that stays 4-connected; stops at existing water.
	var x := float(x_start)
	var prev := x_start
	var step := 1 if y_to > y_from else -1
	var y := y_from
	while y != y_to + step:
		var cur := int(round(x))
		if stop_at_water and y != y_from and terrain[idx(cur, y)] == Defs.T.WATER and terrain[idx(prev, y)] == Defs.T.WATER:
			break
		_water_row(y, mini(prev, cur), maxi(prev, cur))
		prev = cur
		x = clampf(x + rng.randf_range(-0.8, 0.8), 3.0, N - 4.0)
		y += step


func _make_coast() -> void:
	var depth := rng.randi_range(7, 10)
	for x in N:
		depth = clampi(depth + rng.randi_range(-1, 1), 6, 11)
		for y in range(N - depth, N):
			terrain[idx(x, y)] = Defs.T.WATER
	# a stream into the sea
	_stream(rng.randi_range(10, 21), 0, N - 1)


func _make_lake() -> void:
	var cx := rng.randi_range(11, 20)
	var cy := rng.randi_range(11, 20)
	var r := rng.randf_range(2.2, 3.4)
	for y in range(cy - 5, cy + 6):
		for x in range(cx - 5, cx + 6):
			if inside(x, y) and Vector2(x - cx, (y - cy) * 1.2).length() + rng.randf() * 0.9 < r:
				terrain[idx(x, y)] = Defs.T.WATER
	# outflow to the top edge
	_stream(cx, cy, 0, false)


# ---------------------------------------------------------------- editing (each returns the cost, or -1)
func cell_state(i: int) -> Array:
	return [terrain[i], obj[i], zone[i], level[i], variant[i], build[i]]


func set_cell_state(i: int, s: Array) -> void:
	terrain[i] = s[0]
	obj[i] = s[1]
	zone[i] = s[2]
	level[i] = s[3]
	variant[i] = s[4]
	build[i] = s[5]


func road_cost(i: int) -> int:
	if not is_active(i) or obj[i] != 0 or zone[i] != Defs.Z.NONE:
		return -1
	match terrain[i]:
		Defs.T.WATER:
			return Defs.BRIDGE_COST
		Defs.T.FOREST:
			return Defs.ROAD_COST + Defs.CLEAR_COST
	return Defs.ROAD_COST


func place_road(i: int) -> int:
	var cost := road_cost(i)
	if cost < 0 or money < cost:
		return -1
	if terrain[i] == Defs.T.FOREST:
		terrain[i] = Defs.T.GRASS
	obj[i] = Defs.ROAD
	money -= cost
	return cost


func zone_cost(i: int, z: int) -> int:
	if not is_active(i) or obj[i] != 0 or terrain[i] == Defs.T.WATER:
		return -1
	if zone[i] == z:
		return -1
	if zone[i] != Defs.Z.NONE and level[i] > 0:
		return -1                    # a building stands here; bulldoze first
	return Defs.ZONE_COST + (Defs.CLEAR_COST if terrain[i] == Defs.T.FOREST else 0)


func place_zone(i: int, z: int) -> int:
	var cost := zone_cost(i, z)
	if cost < 0 or money < cost:
		return -1
	terrain[i] = Defs.T.GRASS
	zone[i] = z
	level[i] = 0
	variant[i] = 0
	build[i] = 0
	money -= cost
	return cost


func facility_cost(i: int, id: int) -> int:
	if not is_active(i) or obj[i] != 0 or terrain[i] == Defs.T.WATER or zone[i] != Defs.Z.NONE:
		return -1
	if not unlocked(id):
		return -1
	if Defs.is_landmark(id) and has_landmark(id):
		return -1
	return int(Defs.fac(id)["cost"]) + (Defs.CLEAR_COST if terrain[i] == Defs.T.FOREST else 0)


func place_facility(i: int, id: int) -> int:
	var cost := facility_cost(i, id)
	if cost < 0 or money < cost:
		return -1
	terrain[i] = Defs.T.GRASS
	obj[i] = id
	money -= cost
	return cost


func can_bulldoze(i: int) -> bool:
	if not is_active(i):
		return false
	return obj[i] != 0 or zone[i] != Defs.Z.NONE or terrain[i] == Defs.T.FOREST


func bulldoze(i: int) -> int:
	if not can_bulldoze(i):
		return -1
	if obj[i] == 0 and zone[i] == Defs.Z.NONE and terrain[i] == Defs.T.FOREST:
		if money < Defs.CLEAR_COST:
			return -1
		terrain[i] = Defs.T.GRASS
		money -= Defs.CLEAR_COST
		return Defs.CLEAR_COST
	obj[i] = 0
	zone[i] = Defs.Z.NONE
	level[i] = 0
	variant[i] = 0
	build[i] = 0
	return 0


# ---------------------------------------------------------------- derived state
func refresh() -> void:
	_compute_roads()
	_compute_coverage()
	_compute_land()
	_compute_stats()


func _compute_roads() -> void:
	connected = PackedByteArray()
	connected.resize(CELLS)
	road_count = 0
	for i in CELLS:
		if obj[i] == Defs.ROAD:
			road_count += 1
	if obj[entrance] == Defs.ROAD:
		var queue: Array[int] = [entrance]
		connected[entrance] = 1
		var head := 0
		while head < queue.size():
			var c := queue[head]
			head += 1
			var p := pos(c)
			for d in DIRS:
				var q: Vector2i = p + d
				if inside(q.x, q.y):
					var j := idx(q.x, q.y)
					if obj[j] == Defs.ROAD and connected[j] == 0:
						connected[j] = 1
						queue.append(j)
	access_road = PackedInt32Array()
	access_road.resize(CELLS)
	access_road.fill(-1)
	for i in CELLS:
		if (zone[i] == Defs.Z.NONE and obj[i] < 2):
			continue
		var p := pos(i)
		var best := -1
		var best_d := 99
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var x := p.x + dx
				var y := p.y + dy
				if inside(x, y) and connected[idx(x, y)] == 1:
					var d := absi(dx) + absi(dy)
					if d < best_d:
						best_d = d
						best = idx(x, y)
		access_road[i] = best


func _stamp(arr: PackedByteArray, center: int, radius: int, value: int, use_or: bool) -> void:
	var p := pos(center)
	var r2 := radius * radius + radius   # a slightly rounder circle
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy > r2:
				continue
			var x := p.x + dx
			var y := p.y + dy
			if not inside(x, y):
				continue
			var j := idx(x, y)
			if use_or:
				arr[j] = arr[j] | value
			else:
				arr[j] = value


func _compute_coverage() -> void:
	power = PackedByteArray()
	power.resize(CELLS)
	water = PackedByteArray()
	water.resize(CELLS)
	service = PackedByteArray()
	service.resize(CELLS)
	landmarks = 0
	for i in CELLS:
		var o := obj[i]
		if o < 2:
			continue
		var f := Defs.fac(o)
		if o == 2:
			_stamp(power, i, f["radius"], 1, false)
		elif o == 3:
			_stamp(water, i, f["radius"], 1, false)
		elif Defs.SERVICE_BIT.has(o):
			_stamp(service, i, f["radius"], Defs.SERVICE_BIT[o], true)
		if Defs.is_landmark(o):
			landmarks += 1


func _compute_land() -> void:
	var lv := PackedFloat32Array()
	lv.resize(CELLS)
	lv.fill(25.0)
	var green := 2.0 if policy_key == "green" else 1.0
	var bad := PackedByteArray()
	bad.resize(CELLS)
	for i in CELLS:
		var p := pos(i)
		var o := obj[i]
		if terrain[i] == Defs.T.WATER:
			_add_area(lv, p, 2, 10.0)
		elif terrain[i] == Defs.T.FOREST and o == 0 and zone[i] == Defs.Z.NONE:
			_add_area(lv, p, 1, 3.0 * green)
		match o:
			4:
				_add_area(lv, p, 2, 12.0 * green)
			5:
				_add_area(lv, p, 1, 4.0 * green)
			6:
				_add_area(lv, p, 3, 10.0)
			2:
				_add_area(lv, p, 3, -15.0)
		if Defs.is_landmark(o):
			_add_area(lv, p, 5, 15.0)
		if zone[i] == Defs.Z.I and level[i] > 0 and build[i] == 0:
			_add_area(lv, p, 3, -6.0 - 4.0 * level[i])
	land = PackedByteArray()
	land.resize(CELLS)
	var tax_lv: float = [5.0, 0.0, -8.0][tax]
	for i in CELLS:
		var v: float = lv[i] + tax_lv
		for bit in [1, 2, 4, 8]:
			if service[i] & bit:
				v += 6.0
		land[i] = clampi(int(v), 0, 100)


func _add_area(lv: PackedFloat32Array, p: Vector2i, r: int, amount: float) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := p.x + dx
			var y := p.y + dy
			if inside(x, y):
				lv[idx(x, y)] += amount


func capacity(i: int) -> int:
	var lv := level[i]
	if build[i] > 0:
		lv -= 1
	return Defs.CAP[zone[i]][maxi(lv, 0)]


func _compute_stats() -> void:
	pop = 0
	cjobs = 0
	ijobs = 0
	var happy_sum := 0.0
	for i in CELLS:
		if zone[i] == Defs.Z.NONE or level[i] == 0 or not working(i):
			continue
		var cap := capacity(i)
		match zone[i]:
			Defs.Z.R:
				pop += cap
				happy_sum += cap * cell_happiness(i)
			Defs.Z.C:
				cjobs += cap
			Defs.Z.I:
				ijobs += cap
	happiness = int(round(happy_sum / pop)) if pop > 0 else 60
	# demand: people come for jobs, shops and factories follow the people
	var jobs := cjobs + ijobs
	var r_target := jobs / 0.5 + 40.0 + 20.0 * rank
	var c_target := pop * 0.28 + landmarks * 12.0
	var i_target := pop * 0.32 * (1.0 - 0.08 * rank) + 10.0
	var d_r := (r_target - pop) / maxf(r_target, 40.0) * 1.5
	var d_c := (c_target - cjobs) / maxf(c_target, 8.0) * 1.5
	var d_i := (i_target - ijobs) / maxf(i_target, 8.0) * 1.5
	var t: float = Defs.TAX_DEMAND[tax]
	d_r += t
	d_c += t
	d_i += t
	if happiness < 45:
		d_r -= 0.2
	if event_key == "movein" or policy_key == "taxcut":
		d_r += 0.35
	if event_key == "tourists" or policy_key == "tourism":
		d_c += 0.35
	if event_key == "orders" or policy_key == "industry":
		d_i += 0.35
	demand = [0.0, clampf(d_r, -1.0, 1.0), clampf(d_c, -1.0, 1.0), clampf(d_i, -1.0, 1.0)]
	growth_mult = 1.5 if policy_key == "education" else 1.0


func cell_happiness(i: int) -> float:
	var h := 55.0
	for id in Defs.SERVICE_BIT:
		if not unlocked(id):
			continue
		h += 8.0 if service[i] & Defs.SERVICE_BIT[id] else -5.0
	h += (land[i] - 35) * 0.3
	h += [8.0, 0.0, -10.0][tax]
	if policy_key == "safety":
		h += 5.0
	return clampf(h, 0.0, 100.0)


# ---------------------------------------------------------------- time
func step_week() -> void:
	## One growth step. Every fourth step closes the month.
	if finished:
		return
	_grow()
	week += 1
	if week >= Defs.WEEKS:
		week = 0
		_end_month()
	refresh()


func _grow() -> void:
	var started := [0, 0, 0, 0]
	var limit := [0, 0, 0, 0]
	for z in [1, 2, 3]:
		limit[z] = maxi(1, int(demand[z] * 8.0)) if demand[z] > 0.0 else 0
	for i in CELLS:
		var z := zone[i]
		if z == Defs.Z.NONE or obj[i] != 0:
			continue
		if build[i] > 0:
			build[i] -= 1
			if build[i] == 0:
				built.emit(i)
			continue
		if not working(i):
			continue
		var d: float = demand[z]
		if level[i] == 0:
			if d <= 0.0 or started[z] >= limit[z]:
				continue
			var p := (0.06 + 0.3 * d) * (0.6 + land[i] / 150.0) * growth_mult
			if rng.randf() < p:
				started[z] += 1
				level[i] = 1
				build[i] = Defs.BUILD_WEEKS[1]
				variant[i] = rng.randi_range(0, Defs.SHOPS.size() - 1) if z == Defs.Z.C else rng.randi_range(0, 2)
		elif level[i] < 3:
			var next := level[i] + 1
			if d <= 0.05 or land[i] < Defs.LV_NEED[next]:
				continue
			if next == 3 and z != Defs.Z.C and not (service[i] & Defs.SERVICE_BIT[10]):
				continue
			if rng.randf() < 0.035 * growth_mult * (0.5 + d):
				level[i] = next
				build[i] = Defs.BUILD_WEEKS[next]


func _end_month() -> void:
	var rate: float = Defs.TAX_RATE[tax]
	var mult := 1.0
	if event_key == "boom":
		mult *= 1.25
	elif event_key == "recession":
		mult *= 0.8
	var shop_mult := 1.5 if event_key == "festival" else 1.0
	var income := (pop * 0.4 + cjobs * 0.7 * shop_mult + ijobs * 0.5) * rate * mult
	income += landmarks * 30.0 * (2.0 if policy_key == "tourism" else 1.0)
	var expense := road_count * Defs.ROAD_UPKEEP
	for i in CELLS:
		if obj[i] >= 2:
			expense += Defs.fac(obj[i])["upkeep"]
	last_income = int(round(income))
	last_expense = int(round(expense))
	money += last_income - last_expense
	month += 1
	month_passed.emit(last_income, last_expense)
	# timers
	if event_left > 0:
		event_left -= 1
		if event_left == 0:
			event_key = ""
	if policy_left > 0:
		policy_left -= 1
		if policy_left == 0:
			policy_key = ""
	_check_rank()
	if event_key == "" and month > 3 and rng.randf() < 0.09:
		_start_event()
	if month % 12 == 0:
		if month >= months_total():
			finished = true
			final_score = score()
			finished_run.emit(final_score)
		else:
			year_end.emit(month / 12)


func _start_event() -> void:
	var e: Dictionary = Defs.EVENTS[rng.randi_range(0, Defs.EVENTS.size() - 1)]
	match e["key"]:
		"grant":
			var amount := 300 + 100 * rank
			money += amount
			notice.emit(e["text"] % amount, "good")
		"fire":
			if policy_key == "safety":
				return
			var homes: Array[int] = []
			for i in CELLS:
				if zone[i] != Defs.Z.NONE and level[i] > 0 and build[i] == 0:
					homes.append(i)
			if homes.is_empty():
				return
			var c := homes[rng.randi_range(0, homes.size() - 1)]
			var label := Defs.kind_name(kind_of(c))
			if service[c] & Defs.SERVICE_BIT[8]:
				notice.emit("%s에 불이 났지만 소방서가 금방 껐어요" % label, "good")
			else:
				level[c] = 0
				variant[c] = 0
				burned.emit(c)
				notice.emit("%s에 불이 나 무너졌어요. 소방서가 있으면 막을 수 있어요" % label, "bad")
		_:
			event_key = e["key"]
			event_left = e["months"]
			notice.emit(e["text"], "bad" if event_key == "recession" else "event")


func rank_goals(r: int) -> Array:
	## [[label, current, needed], ...] for reaching rank r.
	if r >= Defs.RANKS.size():
		return []
	var need: Dictionary = Defs.RANKS[r]
	var out: Array = []
	if need.has("pop"):
		out.append(["인구", pop, need["pop"]])
	if need.has("happy"):
		out.append(["행복", happiness, need["happy"]])
	if need.has("landmarks"):
		out.append(["명소", landmarks, need["landmarks"]])
	return out


func _check_rank() -> void:
	while rank + 1 < Defs.RANKS.size():
		for g in rank_goals(rank + 1):
			if g[1] < g[2]:
				return
		rank += 1
		rank_up.emit(rank)


func choose_policy(key: String) -> void:
	if key == "subsidy":
		money += 1500
		return
	policy_key = key
	policy_left = 12
	refresh()


func policy_choices() -> Array:
	var keys: Array = []
	for p in Defs.POLICIES:
		keys.append(p)
	# deterministic per year so a reload shows the same cards
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 31 + month
	for k in range(keys.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp = keys[k]
		keys[k] = keys[j]
		keys[j] = tmp
	return keys.slice(0, 3)


func average_land() -> int:
	var total := 0
	var n := 0
	for i in CELLS:
		if zone[i] != Defs.Z.NONE and level[i] > 0:
			total += land[i]
			n += 1
	return total / n if n > 0 else 0


func score_parts() -> Array:
	return [
		["인구", pop, pop],
		["자금", money, maxi(money, 0) / 10],
		["명소", landmarks, landmarks * 500],
		["행복", happiness, happiness * 10],
		["평균 지가", average_land(), average_land() * 10],
		["마을 랭크", rank + 1, rank * 1000],
	]


func score() -> int:
	var s := 0
	for p in score_parts():
		s += p[2]
	return s


# ---------------------------------------------------------------- save
func to_dict() -> Dictionary:
	return {
		"v": 1, "seed": seed_value, "mode": mode, "rng": str(rng.state),
		"terrain": Marshalls.raw_to_base64(terrain), "obj": Marshalls.raw_to_base64(obj),
		"zone": Marshalls.raw_to_base64(zone), "level": Marshalls.raw_to_base64(level),
		"variant": Marshalls.raw_to_base64(variant), "build": Marshalls.raw_to_base64(build),
		"money": money, "month": month, "week": week, "rank": rank, "tax": tax,
		"event_key": event_key, "event_left": event_left, "policy_key": policy_key, "policy_left": policy_left,
		"finished": finished, "final_score": final_score, "entrance": entrance,
	}


func from_dict(d: Dictionary) -> bool:
	if int(d.get("v", 0)) != 1:
		return false
	seed_value = int(d["seed"])
	mode = str(d.get("mode", "normal"))
	rng.seed = seed_value
	rng.state = str(d["rng"]).to_int()
	terrain = Marshalls.base64_to_raw(d["terrain"])
	obj = Marshalls.base64_to_raw(d["obj"])
	zone = Marshalls.base64_to_raw(d["zone"])
	level = Marshalls.base64_to_raw(d["level"])
	variant = Marshalls.base64_to_raw(d["variant"])
	build = Marshalls.base64_to_raw(d["build"])
	if terrain.size() != CELLS or obj.size() != CELLS:
		return false
	money = int(d["money"])
	month = int(d["month"])
	week = int(d["week"])
	rank = int(d["rank"])
	tax = int(d["tax"])
	event_key = str(d["event_key"])
	event_left = int(d["event_left"])
	policy_key = str(d["policy_key"])
	policy_left = int(d["policy_left"])
	finished = bool(d["finished"])
	final_score = int(d["final_score"])
	entrance = int(d["entrance"])
	refresh()
	return true
