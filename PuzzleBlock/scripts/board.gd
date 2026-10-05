class_name Board
extends Node2D

signal lines_cleared(line_count: int, cell_count: int, combo_bonus_pos: Vector2)

const GRID_SIZE: int = 8
const CELL_SIZE: float = 76.0
const CELL_GAP: float = 2.0
const CELL_SPACING: float = 78.0 # CELL_SIZE + CELL_GAP

const BOARD_WIDTH: float = GRID_SIZE * CELL_SPACING - CELL_GAP # 622.0
const BOARD_HEIGHT: float = BOARD_WIDTH
# Revive bomb clears the center 4x4 (up to 16 cells), topping up to 12 when that finds fewer than 8
const REVIVE_MAX_CELLS: int = 16

var cell_blast_scene: PackedScene = preload("res://scenes/cell_blast.tscn")
var slot_texture: Texture2D = preload("res://assets/sprites/cell_slot.png")
var ghost_texture: Texture2D = preload("res://assets/sprites/cell_ghost.png")

# 8x8 Grid state: stores String color name or null
var grid_state: Array = []
# 8x8 Sprite references: stores Sprite2D or null
var placed_sprites: Array = []
# 8x8 Ghost preview sprites
var ghost_sprites: Array = []
# 8x8 Line clear highlight shimmer sprites
var highlight_sprites: Array = []

var highlights_container: Node2D = null

# Adventure gem cells (Vector2i -> true); the gem visual is a child of the block sprite
var gem_cells: Dictionary = {}

# Replay log support: grid origin of the last placement and cells removed by the last revive
var last_origin: Vector2i = Vector2i.ZERO
var last_revive_cells: Array[int] = []

@onready var slots_container: Node2D = $Slots
@onready var ghosts_container: Node2D = $Ghosts
@onready var pieces_container: Node2D = $Pieces
@onready var effects_container: Node2D = $Effects
# Combo streak before this clear (set by MainGame): cleared blocks fly out harder with it
var clear_combo: int = 0

func _ready() -> void:
	if not has_node("Highlights"):
		highlights_container = Node2D.new()
		highlights_container.name = "Highlights"
		highlights_container.z_index = 8
		add_child(highlights_container)
	else:
		highlights_container = get_node("Highlights")
	_init_grid()

func _init_grid() -> void:
	grid_state.clear()
	placed_sprites.clear()
	ghost_sprites.clear()
	highlight_sprites.clear()
	
	for x in range(GRID_SIZE):
		var col_state = []
		var col_placed = []
		var col_ghost = []
		var col_highlight = []
		for y in range(GRID_SIZE):
			col_state.append(null)
			col_placed.append(null)
			
			var cell_pos = get_cell_position(x, y)
			
			# 1. Slot background sprite
			var slot_sp = Sprite2D.new()
			slot_sp.texture = slot_texture
			slot_sp.position = cell_pos
			slots_container.add_child(slot_sp)
			
			# 2. Ghost preview sprite
			var ghost_sp = Sprite2D.new()
			ghost_sp.texture = ghost_texture
			ghost_sp.position = cell_pos
			ghost_sp.visible = false
			ghosts_container.add_child(ghost_sp)
			col_ghost.append(ghost_sp)
			
			# 3. Line Clear Highlight Shimmer sprite
			var hl_sp = Sprite2D.new()
			hl_sp.texture = ghost_texture
			hl_sp.position = cell_pos
			hl_sp.visible = false
			highlights_container.add_child(hl_sp)
			col_highlight.append(hl_sp)
			
		grid_state.append(col_state)
		placed_sprites.append(col_placed)
		ghost_sprites.append(col_ghost)
		highlight_sprites.append(col_highlight)

func get_cell_position(grid_x: int, grid_y: int) -> Vector2:
	return Vector2(
		grid_x * CELL_SPACING + 38.0,
		grid_y * CELL_SPACING + 38.0
	)

# Magnet: the ghost (and the drop) goes to the nearest free spot up to this far (in cells) from
# where the piece is held. The held piece itself keeps following the finger.
const SNAP_RADIUS: float = 0.9

func get_target_placement(shape_data: Dictionary, piece: BlockPiece) -> Dictionary:
	return find_placement(shape_data, piece.global_position)

# Nearest spot within SNAP_RADIUS where the shape fits, for a piece centered at global_center
func find_placement(shape_data: Dictionary, global_center: Vector2) -> Dictionary:
	var cells: Array = shape_data["cells"]
	var bounds: Rect2i = BlockData.get_bounds(cells)
	var half_w = (bounds.size.x * CELL_SPACING - CELL_GAP) * 0.5
	var half_h = (bounds.size.y * CELL_SPACING - CELL_GAP) * 0.5

	var local := to_local(global_center)
	var fx: float = (local.x - half_w) / CELL_SPACING
	var fy: float = (local.y - half_h) / CELL_SPACING

	var best: Dictionary = {"valid": false}
	var best_d: float = SNAP_RADIUS * SNAP_RADIUS + 0.0001
	for gy in range(floori(fy - SNAP_RADIUS), ceili(fy + SNAP_RADIUS) + 1):
		for gx in range(floori(fx - SNAP_RADIUS), ceili(fx + SNAP_RADIUS) + 1):
			var d: float = (gx - fx) * (gx - fx) + (gy - fy) * (gy - fy)
			if d >= best_d:
				continue
			var coords := _fit_coords(cells, bounds, gx, gy)
			if coords.is_empty():
				continue
			best_d = d
			best = {"valid": true, "coords": coords, "origin": Vector2i(gx, gy)}
	return best

# Board cells the shape covers with its bounding box's top-left at (base_gx, base_gy); empty if it doesn't fit
func _fit_coords(cells: Array, bounds: Rect2i, base_gx: int, base_gy: int) -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for c in cells:
		var gx = base_gx + (c.x - bounds.position.x)
		var gy = base_gy + (c.y - bounds.position.y)
		if gx < 0 or gx >= GRID_SIZE or gy < 0 or gy >= GRID_SIZE:
			return []
		if grid_state[gx][gy] != null:
			return []
		coords.append(Vector2i(gx, gy))
	return coords

func update_ghost_preview(shape_data: Dictionary, piece: BlockPiece) -> bool:
	hide_ghost_preview()
	if not SettingsManager.ghost_piece_enabled:
		return false

	var placement = get_target_placement(shape_data, piece)
	if placement["valid"]:
		var coords: Array[Vector2i] = placement["coords"]
		var col_name: String = shape_data["color"]
		var tint = _get_color_tint(col_name)
		tint.a = 0.85
		for coord in coords:
			var sp: Sprite2D = ghost_sprites[coord.x][coord.y]
			sp.visible = true
			sp.modulate = tint
		_update_line_clear_preview(coords)
		return true
	return false

func _update_line_clear_preview(coords: Array[Vector2i]) -> void:
	var preview_coords = {}
	for c in coords:
		preview_coords[c] = true
		
	var will_clear_rows: Array[int] = []
	var will_clear_cols: Array[int] = []
	
	for y in range(GRID_SIZE):
		var full = true
		for x in range(GRID_SIZE):
			if grid_state[x][y] == null and not preview_coords.has(Vector2i(x, y)):
				full = false
				break
		if full:
			will_clear_rows.append(y)
			
	for x in range(GRID_SIZE):
		var full = true
		for y in range(GRID_SIZE):
			if grid_state[x][y] == null and not preview_coords.has(Vector2i(x, y)):
				full = false
				break
		if full:
			will_clear_cols.append(x)
			
	if will_clear_rows.is_empty() and will_clear_cols.is_empty():
		return
		
	var glow_cells: Dictionary = {}
	for y in will_clear_rows:
		for x in range(GRID_SIZE):
			glow_cells[Vector2i(x, y)] = true
	for x in will_clear_cols:
		for y in range(GRID_SIZE):
			glow_cells[Vector2i(x, y)] = true
			
	for coord in glow_cells.keys():
		var sp: Sprite2D = highlight_sprites[coord.x][coord.y]
		sp.visible = true
		sp.modulate = Color(1.8, 1.6, 0.4, 0.78) # Shining golden shimmer preview
		if placed_sprites[coord.x][coord.y] != null:
			placed_sprites[coord.x][coord.y].scale = Vector2.ONE * 1.08

func hide_ghost_preview() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			ghost_sprites[x][y].visible = false
			if highlight_sprites.size() > x and highlight_sprites[x].size() > y:
				highlight_sprites[x][y].visible = false
			if placed_sprites.size() > x and placed_sprites[x].size() > y and placed_sprites[x][y] != null:
				placed_sprites[x][y].scale = Vector2.ONE

func place_piece(shape_data: Dictionary, piece: BlockPiece) -> bool:
	var placement = get_target_placement(shape_data, piece)
	if not placement["valid"]:
		return false
	last_origin = placement["origin"]
	
	hide_ghost_preview()
	
	var coords: Array[Vector2i] = placement["coords"]
	var col_name: String = shape_data["color"]
	var tex: Texture2D = BlockSkins.texture(col_name)
	
	for coord in coords:
		var x = coord.x
		var y = coord.y
		grid_state[x][y] = col_name
		
		var sp = Sprite2D.new()
		sp.texture = tex
		sp.position = get_cell_position(x, y)
		pieces_container.add_child(sp)
		placed_sprites[x][y] = sp
		
		# Juicy squash & stretch elastic drop bounce
		sp.scale = Vector2(0.5, 0.5)
		var tw = create_tween()
		tw.tween_property(sp, "scale", Vector2(1.18, 0.86), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sp, "scale", Vector2(0.94, 1.06), 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(sp, "scale", Vector2.ONE, 0.06).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	SoundManager.play_place()
	return true

func check_and_clear_lines() -> Dictionary:
	var full_rows: Array[int] = []
	var full_cols: Array[int] = []
	
	# Check rows
	for y in range(GRID_SIZE):
		var row_full = true
		for x in range(GRID_SIZE):
			if grid_state[x][y] == null:
				row_full = false
				break
		if row_full:
			full_rows.append(y)
			
	# Check columns
	for x in range(GRID_SIZE):
		var col_full = true
		for y in range(GRID_SIZE):
			if grid_state[x][y] == null:
				col_full = false
				break
		if col_full:
			full_cols.append(x)
	
	var total_lines = full_rows.size() + full_cols.size()
	if total_lines == 0:
		return {"lines": 0, "cells": 0, "center": Vector2.ZERO, "perfect": false, "gems": 0}
	
	# Collect unique cells to clear
	var cells_to_clear: Dictionary = {}
	for y in full_rows:
		for x in range(GRID_SIZE):
			cells_to_clear[Vector2i(x, y)] = true
	for x in full_cols:
		for y in range(GRID_SIZE):
			cells_to_clear[Vector2i(x, y)] = true
			
	var avg_pos = Vector2.ZERO
	for coord in cells_to_clear.keys():
		var cell_world_pos = to_global(get_cell_position(coord.x, coord.y))
		avg_pos += cell_world_pos
	avg_pos /= max(1, cells_to_clear.size())
	
	# Domino sequential wave clear
	var sorted_cells: Array = cells_to_clear.keys()
	sorted_cells.sort_custom(func(a, b):
		var pa = to_global(get_cell_position(a.x, a.y))
		var pb = to_global(get_cell_position(b.x, b.y))
		return pa.distance_squared_to(avg_pos) < pb.distance_squared_to(avg_pos)
	)
	
	var gems_collected: int = 0
	var local_center: Vector2 = to_local(avg_pos)
	var fling_power: float = minf(0.8 + 0.15 * (total_lines - 1) + 0.08 * clear_combo, 1.7)
	for idx in range(sorted_cells.size()):
		var coord: Vector2i = sorted_cells[idx]
		var x = coord.x
		var y = coord.y
		if gem_cells.erase(coord):
			gems_collected += 1
		var col_name = grid_state[x][y]
		var block_tex: Texture2D = BlockSkins.texture(col_name if col_name else "blue")
		
		var sp = placed_sprites[x][y]
		placed_sprites[x][y] = null
		grid_state[x][y] = null
		
		var delay = idx * 0.016 # 16ms sequential cascade
		if delay > 0.0:
			var tw = create_tween()
			tw.tween_interval(delay)
			tw.tween_callback(func():
				if sp != null and is_instance_valid(sp):
					sp.queue_free()
				var blast: CellBlast = cell_blast_scene.instantiate()
				blast.position = get_cell_position(x, y)
				effects_container.add_child(blast)
				blast.start_blast(block_tex, blast.position - local_center, fling_power)
			)
		else:
			if sp != null and is_instance_valid(sp):
				sp.queue_free()
			var blast: CellBlast = cell_blast_scene.instantiate()
			blast.position = get_cell_position(x, y)
			effects_container.add_child(blast)
			blast.start_blast(block_tex, blast.position - local_center, fling_power)
	
	lines_cleared.emit(total_lines, cells_to_clear.size(), avg_pos)
	return {
		"lines": total_lines,
		"cells": cells_to_clear.size(),
		"center": avg_pos,
		# Perfect clear: the whole board is empty after this clear
		"perfect": get_occupied_count() == 0,
		"gems": gems_collected
	}

func execute_revive_bomb() -> int:
	hide_ghost_preview()
	last_revive_cells.clear()
	var cleared_cells = 0
	
	# Primary target: center 4x4 area (x: 2..5, y: 2..5)
	var target_coords: Array[Vector2i] = []
	for x in range(2, 6):
		for y in range(2, 6):
			target_coords.append(Vector2i(x, y))
			
	var all_occupied: Array[Vector2i] = []
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid_state[x][y] != null:
				all_occupied.append(Vector2i(x, y))
				
	for coord in target_coords:
		if grid_state[coord.x][coord.y] != null:
			cleared_cells += 1
			_blast_single_cell(coord.x, coord.y)
			
	# If fewer than 8 cleared, blast additional occupied cells across board
	if cleared_cells < 8:
		all_occupied.shuffle()
		for coord in all_occupied:
			if grid_state[coord.x][coord.y] != null:
				cleared_cells += 1
				_blast_single_cell(coord.x, coord.y)
				if cleared_cells >= 12:
					break
					
	return cleared_cells

func _blast_single_cell(x: int, y: int) -> void:
	last_revive_cells.append(x + y * GRID_SIZE)
	gem_cells.erase(Vector2i(x, y))
	var col_name = grid_state[x][y]
	var block_tex: Texture2D = BlockSkins.texture(col_name if col_name else "yellow")
	
	if placed_sprites[x][y] != null and is_instance_valid(placed_sprites[x][y]):
		placed_sprites[x][y].queue_free()
		placed_sprites[x][y] = null
	grid_state[x][y] = null
	
	var blast: CellBlast = cell_blast_scene.instantiate()
	blast.position = get_cell_position(x, y)
	effects_container.add_child(blast)
	blast.start_blast(block_tex)

func can_fit_shape(shape_data: Dictionary) -> bool:
	var cells: Array = shape_data["cells"]
	var bounds: Rect2i = BlockData.get_bounds(cells)
	
	var max_base_x = GRID_SIZE - bounds.size.x
	var max_base_y = GRID_SIZE - bounds.size.y
	
	for base_x in range(max_base_x + 1):
		for base_y in range(max_base_y + 1):
			var fits = true
			for c in cells:
				var gx = base_x + (c.x - bounds.position.x)
				var gy = base_y + (c.y - bounds.position.y)
				if grid_state[gx][gy] != null:
					fits = false
					break
			if fits:
				return true
				
	return false
	
func load_layout(rows: Array) -> void:
	# Adventure start board: lowercase color code = block, uppercase = block with a gem
	reset_board()
	for y in range(mini(rows.size(), GRID_SIZE)):
		var row: String = rows[y]
		for x in range(mini(row.length(), GRID_SIZE)):
			var ch: String = row[x]
			var code: String = ch.to_lower()
			if not AdventureData.COLOR_CODES.has(code):
				continue
			var col_name: String = AdventureData.COLOR_CODES[code]
			grid_state[x][y] = col_name
			var sp = Sprite2D.new()
			sp.texture = BlockSkins.texture(col_name)
			sp.position = get_cell_position(x, y)
			pieces_container.add_child(sp)
			placed_sprites[x][y] = sp
			if ch != code:
				_add_gem(x, y)

func _add_gem(x: int, y: int) -> void:
	gem_cells[Vector2i(x, y)] = true
	var gem := Polygon2D.new()
	gem.polygon = PackedVector2Array([Vector2(0, -22), Vector2(18, -5), Vector2(0, 22), Vector2(-18, -5)])
	gem.color = Color(0.86, 0.97, 1.0)
	var shine := Polygon2D.new()
	shine.polygon = PackedVector2Array([Vector2(0, -22), Vector2(18, -5), Vector2(0, -5), Vector2(-18, -5)])
	shine.color = Color(1, 1, 1, 0.85)
	gem.add_child(shine)
	var outline := Line2D.new()
	outline.points = gem.polygon
	outline.closed = true
	outline.width = 3.0
	outline.default_color = Color(0.08, 0.12, 0.25)
	gem.add_child(outline)
	placed_sprites[x][y].add_child(gem)
	var tw = gem.create_tween().set_loops()
	tw.tween_property(gem, "scale", Vector2.ONE * 1.12, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(gem, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)

func refresh_skin() -> void:
	# Re-texture placed blocks after the skin setting changes
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if placed_sprites[x][y] != null and grid_state[x][y] != null:
				placed_sprites[x][y].texture = BlockSkins.texture(grid_state[x][y])

func place_start_pattern(placements: Array) -> float:
	# Classic start board: pieces drop in one after another. Grid state is set at once;
	# returns how long the animation runs so the first set can wait for it.
	const STEP: float = 0.14
	const DROP: float = 0.32
	for i in range(placements.size()):
		var p: Dictionary = placements[i]
		var col_name: String = p["shape"]["color"]
		for o in BlockData.get_offsets(p["shape"]):
			var x: int = p["x"] + o.x
			var y: int = p["y"] + o.y
			grid_state[x][y] = col_name
			var sp := Sprite2D.new()
			sp.texture = BlockSkins.texture(col_name)
			var target: Vector2 = get_cell_position(x, y)
			sp.position = target - Vector2(0, 150)
			sp.modulate.a = 0.0
			pieces_container.add_child(sp)
			placed_sprites[x][y] = sp
			var tw := sp.create_tween().set_parallel(true)
			tw.tween_property(sp, "position", target, DROP).set_delay(i * STEP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(sp, "modulate:a", 1.0, 0.12).set_delay(i * STEP)
		# One landing sound per piece, rising in pitch
		var land := create_tween()
		land.tween_interval(i * STEP + DROP * 0.6)
		land.tween_callback(SoundManager.play.bind("place", 0.9 + 0.08 * i, -2.0))
	return placements.size() * STEP + DROP

func get_gem_count() -> int:
	return gem_cells.size()

func get_occupancy_snapshot() -> PackedByteArray:
	# Flat 8x8 occupancy (index = x + y * GRID_SIZE), 1 = occupied
	var grid := PackedByteArray()
	grid.resize(GRID_SIZE * GRID_SIZE)
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid_state[x][y] != null:
				grid[x + y * GRID_SIZE] = 1
	return grid

func get_fill_ratio() -> float:
	var occupied: int = 0
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid_state[x][y] != null:
				occupied += 1
	return float(occupied) / float(GRID_SIZE * GRID_SIZE)

func get_occupied_count() -> int:
	var occupied: int = 0
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid_state[x][y] != null:
				occupied += 1
	return occupied

func get_fitting_shapes(candidate_shapes: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for shape in candidate_shapes:
		if can_fit_shape(shape):
			results.append(shape)
	return results

func find_clearing_shapes(candidate_shapes: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var row_counts: Array[int] = []
	var col_counts: Array[int] = []
	row_counts.resize(GRID_SIZE)
	col_counts.resize(GRID_SIZE)
	for i in range(GRID_SIZE):
		row_counts[i] = 0
		col_counts[i] = 0
		
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid_state[x][y] != null:
				col_counts[x] += 1
				row_counts[y] += 1
				
	for shape in candidate_shapes:
		var cells: Array = shape["cells"]
		var bounds: Rect2i = BlockData.get_bounds(cells)
		var max_base_x = GRID_SIZE - bounds.size.x
		var max_base_y = GRID_SIZE - bounds.size.y
		var can_clear = false
		
		for base_x in range(max_base_x + 1):
			if can_clear:
				break
			for base_y in range(max_base_y + 1):
				var fits = true
				for c in cells:
					var gx = base_x + (c.x - bounds.position.x)
					var gy = base_y + (c.y - bounds.position.y)
					if grid_state[gx][gy] != null:
						fits = false
						break
				if fits:
					var added_rows = {}
					var added_cols = {}
					for c in cells:
						var gx = base_x + (c.x - bounds.position.x)
						var gy = base_y + (c.y - bounds.position.y)
						added_rows[gy] = added_rows.get(gy, 0) + 1
						added_cols[gx] = added_cols.get(gx, 0) + 1
						
					for gy in added_rows:
						if row_counts[gy] + added_rows[gy] == GRID_SIZE:
							can_clear = true
							break
					if not can_clear:
						for gx in added_cols:
							if col_counts[gx] + added_cols[gx] == GRID_SIZE:
								can_clear = true
								break
				if can_clear:
					break
					
		if can_clear:
			results.append(shape)
			
	return results

func get_shape_affinity(shape_data: Dictionary) -> float:
	# Returns a score reflecting how "needed" and well-fitting this shape is on the current board.
	# Returns -1.0 if it cannot fit anywhere.
	var cells: Array = shape_data["cells"]
	var bounds: Rect2i = BlockData.get_bounds(cells)
	var max_base_x = GRID_SIZE - bounds.size.x
	var max_base_y = GRID_SIZE - bounds.size.y
	
	if max_base_x < 0 or max_base_y < 0:
		return -1.0
	
	var row_counts: Array[int] = []
	var col_counts: Array[int] = []
	row_counts.resize(GRID_SIZE)
	col_counts.resize(GRID_SIZE)
	for i in range(GRID_SIZE):
		row_counts[i] = 0
		col_counts[i] = 0
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if grid_state[x][y] != null:
				col_counts[x] += 1
				row_counts[y] += 1
				
	var max_affinity: float = -1.0
	
	for base_x in range(max_base_x + 1):
		for base_y in range(max_base_y + 1):
			var fits = true
			for c in cells:
				var gx = base_x + (c.x - bounds.position.x)
				var gy = base_y + (c.y - bounds.position.y)
				if grid_state[gx][gy] != null:
					fits = false
					break
			if fits:
				var current_pos_score: float = 5.0 # Base score for being placeable
				var lines_cleared_here: int = 0
				var near_line_bonus: float = 0.0
				
				var added_rows: Dictionary = {}
				var added_cols: Dictionary = {}
				for c in cells:
					var gx = base_x + (c.x - bounds.position.x)
					var gy = base_y + (c.y - bounds.position.y)
					added_rows[gy] = added_rows.get(gy, 0) + 1
					added_cols[gx] = added_cols.get(gx, 0) + 1
					
				for gy in added_rows:
					var total_in_row = row_counts[gy] + added_rows[gy]
					if total_in_row == GRID_SIZE:
						lines_cleared_here += 1
					elif total_in_row == GRID_SIZE - 1:
						near_line_bonus += 28.0 # Contributes to a 7/8 row!
					elif total_in_row == GRID_SIZE - 2:
						near_line_bonus += 14.0 # Contributes to a 6/8 row!
						
				for gx in added_cols:
					var total_in_col = col_counts[gx] + added_cols[gx]
					if total_in_col == GRID_SIZE:
						lines_cleared_here += 1
					elif total_in_col == GRID_SIZE - 1:
						near_line_bonus += 28.0 # Contributes to a 7/8 col!
					elif total_in_col == GRID_SIZE - 2:
						near_line_bonus += 14.0 # Contributes to a 6/8 col!
						
				if lines_cleared_here > 0:
					current_pos_score += lines_cleared_here * 125.0
				current_pos_score += near_line_bonus
				
				if current_pos_score > max_affinity:
					max_affinity = current_pos_score
					
	return max_affinity

func reset_board() -> void:
	gem_cells.clear()
	hide_ghost_preview()
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			grid_state[x][y] = null
			if placed_sprites[x][y] != null:
				placed_sprites[x][y].queue_free()
				placed_sprites[x][y] = null

func _get_color_tint(color_name: String) -> Color:
	match color_name:
		"blue": return Color(0.22, 0.74, 0.97)
		"orange": return Color(0.98, 0.57, 0.24)
		"green": return Color(0.20, 0.83, 0.60)
		"purple": return Color(0.75, 0.52, 0.99)
		"yellow": return Color(0.99, 0.88, 0.28)
		"red": return Color(0.97, 0.44, 0.44)
		"cyan": return Color(0.13, 0.83, 0.93)
		"pink": return Color(0.96, 0.45, 0.71)
		_: return Color.WHITE
