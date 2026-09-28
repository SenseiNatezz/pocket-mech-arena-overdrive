class_name EnergyWave
extends Node2D
## Energy crescent thrown by sword-wielding robots (Ronin's naginata slashes): a glowing arc that flies
## straight, hurts the player once on contact and breaks on walls. Wider and slower than bullets, so
## it's dodged by boosting sideways rather than weaving.

var velocity := Vector2.ZERO
var damage := 16.0
var color := Color(1.0, 0.45, 0.15)
## Half-width of the crescent (px).
var radius := 48.0
var source: Node
var _life := 3.2
var _t := 0.0
var _hit := false
var _fade := 0.0


## Spawns a crescent in the combat world layer.
static func spawn(pos: Vector2, vel: Vector2, dmg: float, col: Color, half_width := 48.0, from: Node = null) -> EnergyWave:
	var w := EnergyWave.new()
	w.position = pos
	w.rotation = vel.angle()
	w.velocity = vel
	w.damage = dmg
	w.color = col
	w.radius = half_width
	w.source = from
	Combat.world().add_child(w)
	return w


func _ready() -> void:
	add_to_group("enemy_waves")
	z_index = 5


func _physics_process(delta: float) -> void:
	_t += delta
	if _fade > 0.0:
		_fade -= delta
		if _fade <= 0.0:
			queue_free()
		queue_redraw()
		return
	var to := global_position + velocity * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, to, 1)
	if not get_world_2d().direct_space_state.intersect_ray(q).is_empty():
		Combat.spark(global_position, color, 1.2)
		Combat.burst(global_position, color, 260.0, 0.8)
		_fade = 0.15
		return
	global_position = to
	_life -= delta
	if _life <= 0.0:
		_fade = 0.2
	if not _hit:
		var p := get_tree().get_first_node_in_group("player") as Mech
		if p and not p.dead:
			var local := to_local(p.global_position)
			if local.x > -30.0 and local.x < 26.0 and absf(local.y) < radius + 14.0:
				_hit = true
				p.take_damage(damage, global_position, source if is_instance_valid(source) else null)
				Combat.spark(p.global_position, color, 1.3)
	queue_redraw()


## Crescent bulging forward (+x): a wide soft glow, the coloured blade and a white-hot core edge.
func _draw() -> void:
	var a := 1.0 if _fade <= 0.0 else _fade / 0.2
	var flicker := 0.85 + 0.15 * sin(_t * 40.0)
	var r := radius * 1.25
	var c := Vector2(-r * 0.78, 0)
	var span := asin(clampf(radius / r, 0.0, 1.0))
	draw_arc(c, r, -span, span, 24, Color(color, 0.22 * a), 30.0, true)
	draw_arc(c, r, -span, span, 24, Color(color, 0.7 * a * flicker), 12.0, true)
	draw_arc(c + Vector2(3, 0), r, -span * 0.92, span * 0.92, 24, Color(1, 0.95, 0.85, 0.95 * a), 4.0, true)
	# Short motion streaks behind the blade.
	for i in 3:
		var y := (i - 1) * radius * 0.55
		draw_line(Vector2(-10, y), Vector2(-46 - i * 6, y), Color(color, 0.25 * a), 3.0)
