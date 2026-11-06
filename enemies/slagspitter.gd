class_name Slagspitter
extends Enemy
## "Slagspitter" (Higgsfield sprite, Volcanic Forge): four-legged artillery walker with a furnace tank.
## Keeps its distance and side-steps; every few seconds its snout glows (telegraph) and it lobs molten
## globs in high arcs onto red circles around you. Each glob bursts and leaves a LavaPool.
## Weak spot: the furnace tank on its back takes double damage from behind, and it blows up when the
## Slagspitter dies (hurting you AND nearby robots).

const TEX := preload("res://assets/hq/enemies5/slagspitter.png")
const SPRITE_SCALE := 0.6
const KEEP_MIN := 340.0
const KEEP_MAX := 560.0
const AIM_TIME := 0.7
const GLOB_DELAY := 1.15
const BACK_ARC := 0.9
const SNOUT := 74.0
const SLAG := Color(1.0, 0.5, 0.12)

@export var glob_damage := 14.0
@export var globs := 3

var _aim := 0.0
var _fire_cd := 2.0
var _strafe := 1.0
var _strafe_t := 2.0


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	var off := from_pos - global_position
	if not dead and off.length() > 4.0 and absf((-facing).angle_to(off)) < BACK_ARC:
		amount *= 2.0
		Combat.spark(global_position - facing * hit_radius, Color(1.0, 0.7, 0.3), 0.9)
	super.take_damage(amount, from_pos, source)


func die() -> void:
	if dead:
		return
	var p := global_position
	super.die()
	Combat.explode(p, 120.0, 16.0 * damage_mult, self, "all", SLAG, 300.0)
	LavaPool.spawn(p, 60.0, 3.5, 10.0, null)


func _think(delta: float) -> void:
	var to_t := dir_to_target()
	var d := dist_to_target()
	facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 3.0 * delta))
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.5, 3.0)
		_strafe = -_strafe
	if _aim > 0.0:
		_aim -= delta
		if _aim <= 0.0:
			_lob()
		return
	if d > KEEP_MAX or not has_line_of_sight(target.global_position):
		steer_to(target.global_position)
	elif d < KEEP_MIN:
		desired_velocity = -to_t * move_speed
	else:
		desired_velocity = to_t.orthogonal() * move_speed * 0.6 * _strafe
	_fire_cd -= delta
	if _fire_cd <= 0.0 and d < KEEP_MAX + 150.0:
		_aim = AIM_TIME
		Sfx.play(&"charge", -12.0, 0.1)


func _lob() -> void:
	_fire_cd = randf_range(2.6, 3.4)
	var muzzle := global_position + facing * SNOUT
	var lead := target.global_position + target.velocity * 0.6
	for i in globs:
		var at := lead if i == 0 else lead + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 190.0)
		var delay := GLOB_DELAY + i * 0.15
		Combat.artillery(at, 70.0, glob_damage * damage_mult, self, delay, "player", muzzle)
		LavaPool.spawn(at, 48.0, 3.0, 10.0, self, delay)
	Combat.spark(muzzle, SLAG, 1.4)
	Sfx.play(&"missile", -8.0, 0.1)


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var bob := absf(sin(_t * 7.0)) * 0.02 if velocity.length() > 20.0 else 0.0
	var s := Vector2.ONE * (SPRITE_SCALE + bob)
	draw_set_transform(Vector2(8, 12), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.42))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, tint(Color.WHITE))
	draw_set_transform(Vector2.ZERO)
	# Furnace glow on the back; the snout charges up before a lob.
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(-facing * 8.0, 20.0 + 5.0 * pulse, Color(SLAG, 0.12 + 0.1 * pulse))
	if _aim > 0.0:
		var k := 1.0 - _aim / AIM_TIME
		draw_circle(facing * SNOUT, 8.0 + 16.0 * k, Color(SLAG.lightened(0.3), 0.35 + 0.45 * k))
	draw_hp_bar(-hit_radius - 40)
