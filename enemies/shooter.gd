class_name Shooter
extends Enemy
## "Sentry Drone": hovering gunner. Keeps mid range, strafes, and fires 3-round bursts after a short
## glowing wind-up.

@export var preferred_range := Vector2(260, 440)
@export var burst_cooldown := 1.9
@export var bullet_speed := 440.0
@export var bullet_damage := 8.0

var _cd := 1.2
var _charge := 0.0
var _burst_left := 0
var _burst_t := 0.0
var _strafe := 1.0
var _strafe_t := 0.0


func _think(delta: float) -> void:
	facing = dir_to_target()
	var d := dist_to_target()
	var los := has_line_of_sight(target.global_position)
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.2, 2.4)
		_strafe = -_strafe
	if not los or d > preferred_range.y:
		steer_to(target.global_position)
	elif d < preferred_range.x:
		desired_velocity = -facing * move_speed
	else:
		desired_velocity = facing.orthogonal() * _strafe * move_speed * 0.7
	if _charge > 0.0:
		desired_velocity *= 0.3
	# Attack.
	_cd -= delta
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = 0.11
			_burst_left -= 1
			shoot(facing.rotated(randf_range(-0.05, 0.05)), bullet_speed, bullet_damage)
			Sfx.play(&"enemy_shoot", -14.0)
	elif _charge > 0.0:
		_charge -= delta
		if _charge <= 0.0:
			_burst_left = 3
			_burst_t = 0.0
	elif _cd <= 0.0 and los and d < 650.0:
		_cd = burst_cooldown
		_charge = 0.45


func _draw() -> void:
	var hover := sin(_t * 4.0) * 3.0
	draw_circle(Vector2(0, 14), hit_radius * 0.8, Color(0, 0, 0, 0.28))
	var body := tint(Color(0.3, 0.42, 0.46))
	var hexa := PackedVector2Array()
	for i in 6:
		hexa.append(Vector2.from_angle(i * TAU / 6.0) * hit_radius + Vector2(0, hover - 6))
	draw_colored_polygon(hexa, body)
	draw_polyline(hexa + PackedVector2Array([hexa[0]]), body.darkened(0.45), 2.0)
	# Turret toward the player.
	var c := Vector2(0, hover - 6)
	draw_line(c, c + facing * (hit_radius + 10), Color(0.15, 0.15, 0.18), 7.0)
	draw_circle(c, 10, body.lightened(0.2))
	var glow := Color(1.0, 0.3, 0.55)
	if _charge > 0.0:
		draw_circle(c + facing * (hit_radius + 10), 6 + (0.45 - _charge) * 16, Color(glow, 0.5))
	draw_circle(c, 5, glow)
	# Side thrusters.
	for side in [-1, 1]:
		draw_circle(c + Vector2(side * hit_radius * 0.8, 6), 4, Color(0.4, 0.8, 1.0, 0.6 + 0.3 * sin(_t * 20.0)))
	draw_hp_bar(-hit_radius - 22)
