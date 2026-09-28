extends StaticBody2D
## Boost-only pit: a hole in the platform showing the city far below. Enemies can't enter it (their
## bodies collide with layer 7 "pits"); the player walks right in unless boosting across - the mech
## detects pits with its feet sensor, loses HP and respawns at the last safe edge.
## `size` in pixels. The arena leaves the floor tiles empty under it so the skyline shows through.

@export var size := Vector2(128, 128)
## Off for painted maps, where the hole is already part of the art.
@export var draw_visual := true

var _t := 0.0


func _ready() -> void:
	add_to_group("pits")
	add_to_group("nav_obstacles")
	collision_layer = 64
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size - Vector2(8, 8)
	shape.shape = box
	add_child(shape)
	z_index = -9


func _process(delta: float) -> void:
	_t += delta
	if draw_visual:
		queue_redraw()


func _draw() -> void:
	if not draw_visual:
		return
	var r := Rect2(-size / 2, size)
	# Depth: dark gradient on the inner north wall (3/4 view) + side shading.
	for i in 10:
		draw_rect(Rect2(r.position + Vector2(0, i * 3), Vector2(r.size.x, 3)), Color(0, 0, 0, 0.6 - i * 0.055))
	draw_rect(Rect2(r.position, Vector2(6, r.size.y)), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(r.end - Vector2(6, r.size.y), Vector2(6, r.size.y)), Color(0, 0, 0, 0.35))
	# Broken slab edge with hazard trim.
	draw_rect(r, Color(0.95, 0.72, 0.12, 0.85), false, 4.0)
	var pulse := 0.4 + 0.3 * sin(_t * 4.0)
	draw_rect(r.grow(-5), Color(1.0, 0.3, 0.2, pulse * 0.6), false, 2.0)
