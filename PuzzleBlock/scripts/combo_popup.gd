class_name ComboPopup
extends Node2D
# Clear feedback in the style of Block Blast: glossy lettering pre-drawn by
# tools/generate_combo_text.py. A tilted praise word, "Combo" with a gold number and the
# points pop in one after another over a burst of light rays and sparkles.

const HOLD: float = 0.85
const RISE: float = 50.0
const MAX_WIDTH: float = 600.0
const DIR := "res://assets/sprites/combo/"
const RAYS: Texture2D = preload("res://assets/sprites/combo/rays.png")
const SPARKLE: Texture2D = preload("res://assets/sprites/sparkle.png")
const COMBO_WORD: Texture2D = preload("res://assets/sprites/combo/combo_word.png")
const PRAISE_COUNT: int = 5

static var _cache: Dictionary = {}

var half_width: float = 0.0

static func _tex(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load(DIR + name + ".png")
	return _cache[name]

# tier: 0 none, 1..5 Good!..Unbelievable!  combo: streak (shown from 2)  tint: rays colour
func setup(tier: int, combo: int, gain: int, tint: Color) -> void:
	z_index = 120
	var rows: Array = []   # [node, height, kind]
	if tier > 0:
		var p := _row([_tex("praise_%d" % clampi(tier, 1, PRAISE_COUNT))], 0.0)
		p.set_meta("boost", 1.15)
		rows.append([p, 84.0, "praise"])
	if combo >= 2:
		var digits: Array = [COMBO_WORD]
		for ch in str(combo):
			digits.append(_tex("gold_" + ch))
		rows.append([_row(digits, -30.0, 2.0), 128.0, "combo"])
	var score_tex: Array = [_tex("score_plus")]
	for ch in str(gain):
		score_tex.append(_tex("score_" + ch))
	rows.append([_row(score_tex, -15.0), 54.0, "score"])

	var widest := 0.0
	var total_h := 0.0
	for r in rows:
		widest = maxf(widest, r[0].get_meta("w") * float(r[0].get_meta("boost", 1.0)))
		total_h += r[1]
	var fit: float = minf(1.0, MAX_WIDTH / maxf(widest, 1.0))
	half_width = widest * fit * 0.5

	# Light rays and sparkles behind the words
	var rays := Sprite2D.new()
	rays.texture = RAYS
	rays.modulate = Color(tint, 0.0)
	rays.scale = Vector2.ONE * 0.3
	rays.material = _additive()
	add_child(rays)
	var ray_size: float = clampf(0.75 + 0.1 * tier + 0.03 * combo, 0.8, 1.35)
	var rt := rays.create_tween().set_parallel(true)
	rt.tween_property(rays, "scale", Vector2.ONE * ray_size, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	rt.tween_property(rays, "modulate:a", 0.9, 0.15)
	rt.tween_property(rays, "rotation", 0.6, HOLD + 0.8)
	_sparkles(8 + tier * 4 + mini(combo, 10), tint)

	var y := -total_h * 0.5
	for i in range(rows.size()):
		var node: Node2D = rows[i][0]
		var h: float = rows[i][1]
		var kind: String = rows[i][2]
		var target := Vector2.ONE * fit * float(node.get_meta("boost", 1.0))
		node.position = Vector2(0, y + h * 0.5)
		node.scale = Vector2.ZERO
		add_child(node)
		y += h
		var delay := i * 0.09
		var tw := node.create_tween().set_parallel(true)
		if kind == "praise":
			# Tilted like a sticker, nudged to the right of the combo line
			node.position.x += 34.0 * fit
			node.rotation = deg_to_rad(-22.0)
			tw.tween_property(node, "rotation", deg_to_rad(-7.0), 0.35).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(node, "scale", target * 1.12, 0.2).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(node, "scale", target, 0.12).set_trans(Tween.TRANS_SINE)
		if kind == "combo":
			# The number punches in a beat after the word
			var num: Node2D = node.get_meta("tail")
			num.scale = Vector2.ZERO
			var nt := num.create_tween()
			nt.tween_interval(delay + 0.12)
			nt.tween_property(num, "scale", Vector2.ONE * 1.35, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			nt.tween_property(num, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)

	var out := create_tween()
	out.tween_interval(HOLD + rows.size() * 0.09)
	out.tween_property(self, "position:y", -RISE, 0.35).as_relative().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	out.parallel().tween_property(self, "modulate:a", 0.0, 0.35)
	out.tween_callback(queue_free)

# Lays textures side by side, centred. overlap < 0 tucks the thick outlines together.
# With tail_gap the first texture is a word and the rest (the number) is its own node.
func _row(textures: Array, overlap: float, tail_gap: float = INF) -> Node2D:
	var row := Node2D.new()
	var widths: Array = []
	var total := 0.0
	for i in range(textures.size()):
		var w: float = textures[i].get_width()
		widths.append(w)
		total += w
		if i > 0:
			total += tail_gap if (i == 1 and tail_gap != INF) else overlap
	var tail: Node2D = null
	if tail_gap != INF:
		tail = Node2D.new()
		row.add_child(tail)
	var x := -total * 0.5
	var tail_x := 0.0
	for i in range(textures.size()):
		if i > 0:
			x += tail_gap if (i == 1 and tail_gap != INF) else overlap
		var s := Sprite2D.new()
		s.texture = textures[i]
		s.position = Vector2(x + widths[i] * 0.5, 0)
		if tail != null and i >= 1:
			if i == 1:
				tail_x = x
			tail.add_child(s)
		else:
			row.add_child(s)
		x += widths[i]
	if tail != null:
		# Pivot the number around its own centre
		var mid: float = (tail_x + x) * 0.5
		tail.position = Vector2(mid, 0)
		for c in tail.get_children():
			c.position.x -= mid
		row.move_child(tail, -1)
		row.set_meta("tail", tail)
	row.set_meta("w", total)
	return row

func _sparkles(amount: int, tint: Color) -> void:
	var p := CPUParticles2D.new()
	p.texture = SPARKLE
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.9
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 40.0
	p.spread = 180.0
	p.gravity = Vector2(0, 160)
	p.initial_velocity_min = 160.0
	p.initial_velocity_max = 360.0
	p.damping_min = 120.0
	p.damping_max = 220.0
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.material = _additive()
	var g := Gradient.new()
	g.set_color(0, Color.WHITE)
	g.set_color(1, Color(tint.lightened(0.3), 0.0))
	g.add_point(0.6, tint.lightened(0.5))
	p.color_ramp = g
	add_child(p)
	p.emitting = true

func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
