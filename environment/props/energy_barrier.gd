extends StaticBody2D
## Energy barrier that seals an encounter zone. Solid (walls layer) while active, fades out when
## deactivated. `size` in pixels.

@export var size := Vector2(256, 64)
@export var active := false:
	set(v):
		active = v
		if is_node_ready():
			_apply()

var _shape: CollisionShape2D
var _t := 0.0
var _alpha := 0.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	_shape.shape = box
	add_child(_shape)
	_apply()


func _apply() -> void:
	_shape.set_deferred("disabled", not active)
	if active:
		Sfx.play(&"shield", -8.0)


func _process(delta: float) -> void:
	_t += delta
	_alpha = move_toward(_alpha, 1.0 if active else 0.0, delta * 4.0)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(-size / 2, size)
	# Emitter posts at both ends are always visible.
	for x in [r.position.x, r.end.x]:
		draw_rect(Rect2(x - 8, r.position.y - 4, 16, r.size.y + 8), Color(0.25, 0.27, 0.32))
		draw_rect(Rect2(x - 4, r.position.y, 8, r.size.y), Color(1.0, 0.3, 0.3) if active else Color(0.3, 0.9, 0.5))
	if _alpha <= 0.01:
		return
	var c := Color(1.0, 0.25, 0.35)
	draw_rect(r, Color(c, 0.18 * _alpha))
	var y := r.position.y + fmod(_t * 40.0, 8.0)
	while y < r.end.y:
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(c, 0.35 * _alpha), 2.0)
		y += 8.0
	for i in 3:
		var yy := r.position.y + r.size.y * (0.2 + 0.3 * i) + sin(_t * 6.0 + i) * 4.0
		draw_line(Vector2(r.position.x, yy), Vector2(r.end.x, yy), Color(1.0, 0.7, 0.75, 0.6 * _alpha), 2.0)
	draw_rect(r, Color(c, 0.8 * _alpha), false, 2.0)
