extends Node2D
## Rocket Launcher projectile (Higgsfield sprite). Leaves the tube slowly, accelerates, trails smoke,
## homes in with Target Lock, and explodes on the first enemy, wall or piece of cover it touches (or at
## max range): full damage to what it hit + SPLASH (60%) to everything within SPLASH_RADIUS, and it
## breaks props. Damage is reported as the mech's, so heat / overdrive / Salvage still build.

const TEX := preload("res://assets/hq/weapons/rocket.png")
const SPRITE_SCALE := 0.55
const SPLASH_RADIUS := 120.0
const SPLASH := 0.6
const START_SPEED := 320.0
const MAX_SPEED := 1080.0
const ACCEL := 2600.0
const FIRE := Color(1.0, 0.55, 0.2)

var velocity := Vector2.RIGHT
var damage := 50.0
var source: Node
var homing := 0.0
var _speed := START_SPEED
var _life := 1.7
var _t := 0.0
var _trail: Array[Vector2] = []
var _target: Node2D
var _home_t := 0.0


func setup(pos: Vector2, dir: Vector2, dmg: float, from: Node) -> void:
	global_position = pos
	velocity = dir.normalized()
	rotation = dir.angle()
	damage = dmg
	source = from
	homing = Upgrades.homing()


func _ready() -> void:
	z_index = 5


func _physics_process(delta: float) -> void:
	_t += delta
	_speed = minf(_speed + ACCEL * delta, MAX_SPEED)
	if homing > 0.0:
		_steer(delta)
	var step := velocity * _speed * delta
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1 | 32)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position
		var c: Object = hit.collider
		var from := source if is_instance_valid(source) else null
		if c.has_meta("owner_enemy") and is_instance_valid(c.get_meta("owner_enemy")):
			c.get_meta("owner_enemy").take_damage(damage, global_position, from)
		elif c.has_method("take_hit"):
			c.take_hit(damage, global_position)
		_explode(null)
		return
	global_position += step
	rotation = velocity.angle()
	if Engine.get_physics_frames() % 2 == 0:
		_trail.push_front(global_position - velocity * 20.0)
		if _trail.size() > 12:
			_trail.pop_back()
	var touching := Combat.enemies_in_area(global_position, 16.0)
	if not touching.is_empty():
		_explode(touching[0])
		return
	_life -= delta
	if _life <= 0.0:
		_explode(null)
		return
	queue_redraw()


## Target Lock: bend toward the nearest enemy ahead (re-picked a few times a second).
func _steer(delta: float) -> void:
	_home_t -= delta
	if _home_t <= 0.0 or (is_instance_valid(_target) and _target.get("dead") == true):
		_home_t = 0.12
		_target = Combat.nearest_enemy(global_position, 560.0, velocity, deg_to_rad(95.0))
	if is_instance_valid(_target):
		var want := (_target.global_position - global_position).angle()
		velocity = Vector2.from_angle(rotate_toward(velocity.angle(), want, homing * delta))


func _explode(direct: Node) -> void:
	var from := source if is_instance_valid(source) else null
	var at := global_position
	if direct:
		direct.take_damage(damage, at - velocity * 20.0, from)
	for n in Combat.enemies_in_area(at, SPLASH_RADIUS):
		if n == direct:
			continue
		n.take_damage(damage * SPLASH, at, from)
		if n.has_method("knock"):
			n.knock((n.global_position - at).normalized() * 260.0)
	Combat.damage_destructibles(at, SPLASH_RADIUS, damage * SPLASH)
	# Lighter than a full explosion: these can go off several times a second.
	Combat.shockwave(at, SPLASH_RADIUS, FIRE, 0.3)
	Combat.spark(at, Color(1.0, 0.8, 0.4), 2.2)
	Combat.burst(at, FIRE, SPLASH_RADIUS * 3.0, 1.2)
	Sfx.play(&"explode", -11.0, 0.15)
	Combat.shake(0.1)
	queue_free()


func _draw() -> void:
	# Smoke trail (older puffs bigger and fainter), then the flame, then the rocket.
	for i in _trail.size():
		var k := i / float(maxi(_trail.size() - 1, 1))
		draw_circle(to_local(_trail[i]), 4.0 + 9.0 * k, Color(0.75, 0.75, 0.78, 0.35 * (1.0 - k)))
	var flicker := 0.8 + 0.2 * sin(_t * 60.0)
	draw_circle(Vector2(-24, 0), 9.0 * flicker, Color(FIRE, 0.5))
	draw_circle(Vector2(-22, 0), 4.5 * flicker, Color(1.0, 0.95, 0.7, 0.9))
	var half := TEX.get_size() / 2
	draw_set_transform(Vector2.ZERO, PI / 2, Vector2.ONE * SPRITE_SCALE)
	draw_texture(TEX, -half)
	draw_set_transform(Vector2.ZERO)
