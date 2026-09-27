extends StaticBody2D
## Breakable supply crate. Blocks movement/bullets like light cover; drops a pickup when destroyed.

const PICKUP := preload("res://environment/props/pickup.gd")

@export var max_hp := 30.0
## Chance to drop something (health / heat / repair charge / overdrive).
@export var drop_chance := 0.85

var hp := 0.0
var hit_radius := 22.0
var _flash := 0.0


func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 32
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(40, 40)
	shape.shape = box
	add_child(shape)
	hp = max_hp


func take_hit(amount: float, _from_pos: Vector2) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 1.0
	queue_redraw()
	if hp <= 0.0:
		remove_from_group("destructibles")
		Combat.burst(global_position, Color(0.65, 0.45, 0.25), 300.0, 1.5)
		Sfx.play(&"hit", -6.0)
		if randf() < drop_chance:
			var p: Node2D = PICKUP.new()
			p.kind = [&"health", &"health", &"heat", &"repair", &"overdrive"].pick_random()
			p.position = position
			get_parent().add_child.call_deferred(p)
		queue_free()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = move_toward(_flash, 0.0, delta * 6.0)
		queue_redraw()


func _draw() -> void:
	var wood := Color(0.55, 0.38, 0.2).lerp(Color.WHITE, _flash * 0.5)
	draw_rect(Rect2(-18, -14, 42, 40), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(-20, -8, 40, 28), wood.darkened(0.35))
	draw_rect(Rect2(-20, -20, 40, 24), wood)
	draw_rect(Rect2(-20, -20, 40, 24), wood.darkened(0.5), false, 2.0)
	draw_line(Vector2(-20, -20), Vector2(20, 4), wood.darkened(0.4), 3.0)
	draw_line(Vector2(-20, 4), Vector2(20, -20), wood.darkened(0.4), 3.0)
	draw_rect(Rect2(-6, -12, 12, 8), Color(0.3, 0.9, 1.0, 0.8))
