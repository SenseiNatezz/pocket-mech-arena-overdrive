extends StaticBody2D
## Heavy blast door to the boss arena. Locked (solid) until the encounter zone is cleared, then
## slides open; closes again behind the player when the boss fight starts. `size` in pixels.

@export var size := Vector2(256, 128)
## Painted boss arena: the gateway is in the art, so no dark backdrop behind the doors.
@export var painted := false

var is_open := false
var locked_text := "LOCKED"
var _shape: CollisionShape2D
var _open_k := 0.0
var _t := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	_shape.shape = box
	add_child(_shape)
	z_index = -3


func open() -> void:
	if is_open:
		return
	is_open = true
	_shape.set_deferred("disabled", true)
	Sfx.play(&"charge", -4.0)
	Combat.shake(0.25)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_shape.set_deferred("disabled", false)
	Sfx.play(&"slam", -2.0)
	Combat.shake(0.35)


func _process(delta: float) -> void:
	_t += delta
	_open_k = move_toward(_open_k, 1.0 if is_open else 0.0, delta * 1.4)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size / 2, size)
	if not painted:
		draw_rect(r, Color(0.05, 0.05, 0.07))
	var half := r.size.x / 2 * (1.0 - _open_k)
	var steel := Color(0.36, 0.38, 0.43)
	for side in [-1, 1]:
		var x0: float = r.position.x if side == -1 else r.end.x - half
		var panel := Rect2(Vector2(x0, r.position.y), Vector2(half, r.size.y))
		if half < 1.0:
			continue
		draw_rect(panel, steel)
		draw_rect(panel, steel.darkened(0.4), false, 3.0)
		# Hazard chevrons on the leading edge.
		var edge: float = panel.end.x if side == -1 else panel.position.x
		var yy := panel.position.y
		while yy < panel.end.y:
			var pts := PackedVector2Array([Vector2(edge, yy), Vector2(edge - 18 * side, yy + 8), Vector2(edge - 18 * side, yy + 16), Vector2(edge, yy + 8)])
			draw_colored_polygon(pts, Color(0.95, 0.72, 0.12))
			yy += 20
		draw_rect(Rect2(panel.position + Vector2(10, 10), Vector2(maxf(panel.size.x - 36, 0), 12)), steel.lightened(0.15))
	# Status light.
	var light := Color(0.3, 1.0, 0.5) if is_open else Color(1.0, 0.25, 0.2)
	draw_circle(Vector2(0, r.position.y - 10), 7, Color(light, 0.5 + 0.5 * sin(_t * 5.0)))
