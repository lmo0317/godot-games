class_name CellBlast
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var particles: CPUParticles2D = $CPUParticles2D

# fling_dir/power > 0: the block bursts outward from the clear, tumbling and growing
# as if thrown toward the camera (bigger clears and combos throw harder)
func start_blast(block_texture: Texture2D, fling_dir: Vector2 = Vector2.ZERO, power: float = 0.0) -> void:
	if not is_node_ready():
		await ready

	sprite.texture = block_texture
	# Flash white
	sprite.modulate = Color(2.5, 2.5, 2.5, 1.0)

	particles.emitting = true
	if power > 0.0:
		_fling(fling_dir, power)
		return

	var tw = create_tween().set_parallel(true)
	# Pulse up then shrink down
	tw.tween_property(sprite, "scale", Vector2.ONE * 1.25, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(sprite, "scale", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.3)

	var cleanup = create_tween()
	cleanup.tween_interval(0.5)
	cleanup.tween_callback(queue_free)

func _fling(dir: Vector2, power: float) -> void:
	z_index = 5
	if dir.length_squared() < 0.01:
		dir = Vector2.from_angle(randf() * TAU)
	dir = dir.normalized().rotated(randf_range(-0.35, 0.35))
	var dist: float = randf_range(140.0, 230.0) * power
	var target: Vector2 = position + dir * dist + Vector2(0, randf_range(-40.0, 20.0))
	var life: float = randf_range(0.5, 0.65)
	var grow: float = randf_range(1.25, 1.55) + 0.15 * (power - 1.0)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(sprite, "modulate", Color(1.15, 1.15, 1.15, 1.0), 0.1)
	tw.tween_property(self, "position", target, life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", Vector2.ONE * grow, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "rotation", randf_range(-1.0, 1.0) * PI * 0.6, life)
	tw.tween_property(sprite, "modulate:a", 0.0, life * 0.45).set_delay(life * 0.55)
	tw.chain().tween_callback(queue_free)
