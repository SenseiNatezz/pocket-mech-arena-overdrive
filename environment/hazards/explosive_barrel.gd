extends StaticBody2D
## Exploding barrel. Solid (blocks movement like cover), takes hits from anyone, and after a short
## fuse explodes, damaging the player AND enemies nearby and setting off other barrels (chains).

@export var max_hp := 30.0
@export var blast_radius := 140.0
@export var blast_damage := 45.0

var hp := 0.0
var hit_radius := 18.0
var _fuse := -1.0
var _flash := 0.0


func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 32
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	add_child(shape)
	hp = max_hp


func take_hit(amount: float, _from_pos: Vector2) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 1.0
	if hp <= 0.0:
		_fuse = 0.25  # short fuse so chains ripple instead of all popping on one frame


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse < 0.0:
			_explode()
			return
	queue_redraw()


func _explode() -> void:
	var pos := global_position
	remove_from_group("destructibles")
	queue_free()
	Combat.explode(pos, blast_radius, blast_damage, self, "all", Color(1.0, 0.5, 0.15), 520.0)
	Combat.burst(pos, Color(1.0, 0.8, 0.3), 520.0, 1.2)


func _draw() -> void:
	var lit := _fuse >= 0.0
	var body := Color(0.78, 0.2, 0.12).lerp(Color.WHITE, _flash * 0.6)
	if lit and int(_fuse * 30.0) % 2 == 0:
		body = Color(1.0, 0.85, 0.4)
	draw_circle(Vector2(4, 6), 19, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, 18, body.darkened(0.35))
	draw_circle(Vector2(-1, -1), 15, body)
	draw_arc(Vector2.ZERO, 11, 0, TAU, 24, body.darkened(0.45), 2.0, true)
	# Hazard symbol.
	draw_colored_polygon(PackedVector2Array([Vector2(0, -8), Vector2(7, 5), Vector2(-7, 5)]), Color(1.0, 0.85, 0.15))
	draw_line(Vector2(0, -3), Vector2(0, 1), Color(0.1, 0.1, 0.1), 2.0)
	draw_circle(Vector2(0, 3.2), 1.0, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(-7, -7), 3, Color(1, 1, 1, 0.25))
