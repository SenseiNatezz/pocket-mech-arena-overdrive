class_name Chaser
extends Enemy
## "Scrap Hound": fast four-legged melee drone. Runs you down, crouches for a moment (telegraph),
## then lunges. Contact damage.

@export var lunge_speed := 620.0
@export var lunge_range := 170.0

var _windup := 0.0
var _lunge := 0.0
var _lunge_cd := 1.0
var _lunge_dir := Vector2.ZERO


func _think(delta: float) -> void:
	_lunge_cd -= delta
	if _lunge > 0.0:
		_lunge -= delta
		desired_velocity = _lunge_dir * lunge_speed
		velocity = desired_velocity
		return
	if _windup > 0.0:
		_windup -= delta
		desired_velocity = Vector2.ZERO
		facing = dir_to_target()
		if _windup <= 0.0:
			_lunge = 0.28
			_lunge_dir = dir_to_target()
			_lunge_cd = 1.6
			Sfx.play(&"dash", -12.0)
		return
	if dist_to_target() < lunge_range and _lunge_cd <= 0.0 and has_line_of_sight(target.global_position):
		_windup = 0.35
		return
	steer_to(target.global_position)
	if velocity.length() > 20.0:
		facing = velocity.normalized()


const TEX := preload("res://assets/hq/scrap_hound.png")
const SPRITE_SCALE := 0.5


func _draw() -> void:
	# HQ sprite (art faces up, so rotate by facing + 90 deg). Gait = small squash/stretch while running.
	var rot := facing.angle() + PI / 2
	var gait := sin(_t * 18.0) * 0.05 if velocity.length() > 30.0 else 0.0
	var crouch := Vector2(1.12, 0.82) if _windup > 0.0 else Vector2(1.0 - gait, 1.0 + gait)
	var s := crouch * SPRITE_SCALE
	var half := TEX.get_size() / 2
	draw_set_transform(Vector2(6, 9), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, tint(Color.WHITE))
	# Eye flare while winding up a lunge.
	if _windup > 0.0:
		draw_circle(Vector2(0, -53), 18.0, Color(1.0, 0.8, 0.2, 0.35))
		draw_circle(Vector2(0, -53), 8.0, Color(1.0, 0.95, 0.6, 0.9))
	draw_set_transform(Vector2.ZERO)
	if _windup > 0.0:
		draw_line(Vector2.ZERO, facing * lunge_range * 0.7, Color(1.0, 0.3, 0.2, 0.35), 3.0)
	draw_hp_bar(-hit_radius - 14)
