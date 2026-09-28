class_name Shooter
extends Enemy
## "Scrap Gunner" (Higgsfield sprite): armored twin-cannon walker. Keeps mid range, strafes, and fires
## 3-round bursts from alternating rotary cannons after a short glowing wind-up.

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
var _barrel := 1.0
var _recoil := 0.0

const TEX := preload("res://assets/hq/scrap_gunner.png")
const SPRITE_SCALE := 0.55
## Rotary cannon tips in sprite space (sprite faces up), before scaling.
const MUZZLE_L := Vector2(-46, -69)
const MUZZLE_R := Vector2(45, -69)


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
			_barrel = -_barrel
			_recoil = 1.0
			var m := _muzzle_world(_barrel)
			var dir := (target.global_position - m).normalized().rotated(randf_range(-0.04, 0.04))
			Combat.fire(m, dir * bullet_speed, bullet_damage * damage_mult, false, self, Color(1.0, 0.35, 0.25), 1.1, 2.5)
			Combat.spark(m, Color(1.0, 0.5, 0.25), 0.9)
			Sfx.play(&"enemy_shoot", -14.0)
	elif _charge > 0.0:
		_charge -= delta
		if _charge <= 0.0:
			_burst_left = 3
			_burst_t = 0.0
	elif _cd <= 0.0 and los and d < 650.0:
		_cd = burst_cooldown
		_charge = 0.45


func _muzzle_world(side: float) -> Vector2:
	var local := (MUZZLE_L if side < 0.0 else MUZZLE_R) * SPRITE_SCALE
	return global_position + local.rotated(facing.angle() + PI / 2)


func _process(delta: float) -> void:
	_recoil = move_toward(_recoil, 0.0, delta * 8.0)


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var step := sin(_t * 12.0) * 0.03 if velocity.length() > 20.0 else 0.0
	var s := Vector2(SPRITE_SCALE + step, SPRITE_SCALE - step)
	var half := TEX.get_size() / 2
	var kick := Vector2(0, _recoil * 4.0).rotated(rot)
	draw_set_transform(Vector2(6, 9) + kick, rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(kick, rot, s)
	draw_texture(TEX, -half, tint(Color.WHITE))
	# Wind-up: both rotary cannons glow before the burst.
	if _charge > 0.0:
		var k := 1.0 - _charge / 0.45
		for m in [MUZZLE_L, MUZZLE_R]:
			draw_circle(m, 14.0 + 14.0 * k, Color(1.0, 0.35, 0.2, 0.35 + 0.3 * k))
			draw_circle(m, 7.0, Color(1.0, 0.85, 0.6, 0.8))
	draw_set_transform(Vector2.ZERO)
	draw_hp_bar(-hit_radius - 30)
