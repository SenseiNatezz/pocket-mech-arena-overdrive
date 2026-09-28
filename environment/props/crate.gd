extends StaticBody2D
## Breakable supply crate. Blocks movement/bullets like light cover; drops a pickup when destroyed.
## Optional per-map look: `texture` (drawn `draw_size` px wide, collision `box`). With `hits_to_break`
## > 0 it breaks after that many hits instead of by damage (heavy hits count double); it darkens and
## wobbles a little more with each hit.

const PICKUP := preload("res://environment/props/pickup.gd")
const TEX := preload("res://assets/hq/crate.png")
## A hit this strong counts as two in hits mode.
const HEAVY_HIT := 40.0

@export var max_hp := 24.0
## Chance to drop something (health / heat / repair charge / overdrive).
@export var drop_chance := 0.85
@export var texture: Texture2D
@export var box := Vector2(40, 40)
@export var draw_size := 48.0
@export var hits_to_break := 0

var hp := 0.0
var hit_radius := 22.0
var _flash := 0.0
var _wobble := 0.0


func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 32
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = box
	shape.shape = rect
	add_child(shape)
	if hits_to_break > 0:
		max_hp = hits_to_break
	hp = max_hp
	hit_radius = box.length() * 0.5 if texture else 22.0


func take_hit(amount: float, from_pos: Vector2) -> void:
	if hp <= 0.0:
		return
	hp -= amount if hits_to_break <= 0 else (2.0 if amount >= HEAVY_HIT else 1.0)
	_flash = 1.0
	_wobble = 1.0
	Combat.burst(global_position + (from_pos - global_position).limit_length(box.x * 0.4), Color(0.7, 0.6, 0.5), 110.0, 0.5)
	queue_redraw()
	if hp <= 0.0:
		remove_from_group("destructibles")
		Combat.burst(global_position, Color(0.65, 0.45, 0.25), 300.0, 1.5)
		Combat.burst(global_position, Color(0.9, 0.95, 1.0), 220.0, 1.0)
		Sfx.play(&"hit", -6.0)
		if randf() < drop_chance:
			var p: Node2D = PICKUP.new()
			p.kind = [&"health", &"health", &"heat", &"repair", &"overdrive"].pick_random()
			p.position = position
			get_parent().add_child.call_deferred(p)
		queue_free()


func _process(delta: float) -> void:
	if _flash > 0.0 or _wobble > 0.0:
		_flash = move_toward(_flash, 0.0, delta * 6.0)
		_wobble = move_toward(_wobble, 0.0, delta * 5.0)
		queue_redraw()


func _draw() -> void:
	# Sprite (~draw_size px), flashes white when hit and darkens as it takes damage.
	var tex: Texture2D = texture if texture else TEX
	var k := draw_size / maxf(tex.get_width(), tex.get_height())
	var half := tex.get_size() / 2
	var damage := 1.0 - clampf(hp / max_hp, 0.0, 1.0)
	var shake := Vector2(sin(_wobble * 40.0), cos(_wobble * 33.0)) * _wobble * 3.0
	draw_set_transform(Vector2(4, 6) + shake, 0.0, Vector2.ONE * k)
	draw_texture(tex, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(shake, 0.0, Vector2.ONE * k)
	draw_texture(tex, -half, Color.WHITE.darkened(damage * 0.45).lerp(Color(2, 2, 2), _flash * 0.5))
	draw_set_transform(Vector2.ZERO)
