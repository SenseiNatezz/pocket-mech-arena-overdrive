extends StaticBody2D
## Destructible cover: concrete barricade that blocks movement and bullets from both sides, cracks
## as it takes damage and crumbles after enough hits. `size` in pixels (e.g. 64x40 or 128x40).

@export var size := Vector2(64, 40)
@export var max_hp := 160.0

var hp := 0.0
var hit_radius := 26.0
var _flash := 0.0
var _cracks: Array[PackedVector2Array] = []


func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 32
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	hp = max_hp
	hit_radius = size.length() * 0.4
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	for i in 4:
		var pts := PackedVector2Array()
		var p := Vector2(rng.randf_range(-size.x / 2 + 6, size.x / 2 - 6), rng.randf_range(-size.y / 2, 0))
		for s in 5:
			pts.append(p)
			p += Vector2(rng.randf_range(-7, 7), rng.randf_range(2, 8))
		_cracks.append(pts)


func take_hit(amount: float, from_pos: Vector2) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 1.0
	Combat.burst(global_position + (from_pos - global_position).limit_length(size.x * 0.4), Color(0.55, 0.55, 0.58), 120.0, 0.6)
	if hp <= 0.0:
		remove_from_group("destructibles")
		Combat.burst(global_position, Color(0.6, 0.6, 0.62), 320.0, 1.6)
		Combat.burst(global_position, Color(0.4, 0.4, 0.43), 220.0, 2.2)
		Combat.shockwave(global_position, 60.0, Color(0.8, 0.8, 0.8, 0.6), 0.3)
		Sfx.play(&"slam", -10.0)
		Combat.shake(0.1)
		queue_free()
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = move_toward(_flash, 0.0, delta * 6.0)
		queue_redraw()


func _draw() -> void:
	var r := Rect2(-size / 2, size)
	var damage := 1.0 - hp / max_hp
	var top := Color(0.52, 0.53, 0.56).lerp(Color.WHITE, _flash * 0.5)
	var face := Color(0.34, 0.35, 0.38)
	# Shadow, front face (3/4 view) and top.
	draw_rect(Rect2(r.position + Vector2(6, 10), r.size), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.55), Vector2(r.size.x, r.size.y * 0.45 + 6)), face)
	draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * 0.6)), top)
	draw_line(r.position, r.position + Vector2(r.size.x, 0), top.lightened(0.3), 2.0)
	# Hazard stripes on the face.
	var x := r.position.x + 4
	while x < r.end.x - 8:
		draw_line(Vector2(x, r.end.y + 2), Vector2(x + 8, r.position.y + r.size.y * 0.6), Color(0.95, 0.7, 0.15, 0.8), 3.0)
		x += 16
	var shown := mini(int(ceil(damage * _cracks.size())), _cracks.size())
	for i in shown:
		draw_polyline(_cracks[i], Color(0.1, 0.1, 0.12), 2.0)
