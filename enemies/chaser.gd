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


func _draw() -> void:
	var rot := facing.angle()
	var crouch := 0.85 if _windup > 0.0 else 1.0
	draw_circle(Vector2(4, 8), hit_radius, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, rot, Vector2(crouch, 1.0))
	var body := tint(Color(0.62, 0.24, 0.16))
	var step := sin(_t * 18.0) * 6.0 if velocity.length() > 30.0 else 0.0
	for side in [-1, 1]:
		draw_line(Vector2(8, 6 * side), Vector2(18 + step * side, 20 * side), Color(0.2, 0.2, 0.23), 4.0)
		draw_line(Vector2(-8, 6 * side), Vector2(-18 - step * side, 20 * side), Color(0.2, 0.2, 0.23), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(24, 0), Vector2(8, -13), Vector2(-16, -11), Vector2(-22, 0),
		Vector2(-16, 11), Vector2(8, 13)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(16, 0), Vector2(4, -7), Vector2(-10, -6), Vector2(-10, 6), Vector2(4, 7)]),
		body.lightened(0.2))
	for i in 3:
		draw_line(Vector2(-4 - i * 6, -9), Vector2(-8 - i * 6, -16), Color(0.75, 0.75, 0.8), 2.0)
	var eye := Color(1.0, 0.85, 0.2) if _windup > 0.0 else Color(1.0, 0.4, 0.1)
	draw_circle(Vector2(18, 0), 4.5, eye)
	draw_circle(Vector2(18, 0), 9.0, Color(eye, 0.25))
	draw_set_transform(Vector2.ZERO)
	if _windup > 0.0:
		draw_line(Vector2.ZERO, facing * lunge_range * 0.7, Color(1.0, 0.3, 0.2, 0.35), 3.0)
	draw_hp_bar(-hit_radius - 14)
