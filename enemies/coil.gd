class_name Coil
extends Enemy
## "Coil" (Higgsfield sprite, Endless mode): serpent striker. Slithers toward you in S-curves (hard to
## lead with shots), coils up for a beat when it's close (it squashes, its joints flare magenta and a
## lunge line shows), then strikes in a fast straight lunge. It's slow to recover afterwards: that's
## the moment to punish it.

const TEX := preload("res://assets/hq/enemies4/coil.png")
const SPRITE_SCALE := 0.62
const MAGENTA := Color(1.0, 0.35, 0.9)
const WINDUP := 0.5

@export var lunge_speed := 900.0
@export var lunge_range := 280.0
@export var strike_damage := 16.0

var _windup := 0.0
var _lunge := 0.0
var _recover := 0.0
var _cd := 1.0
var _dir := Vector2.ZERO
var _hit_done := false


func _think(delta: float) -> void:
	_cd -= delta
	if _lunge > 0.0:
		_lunge -= delta
		desired_velocity = _dir * lunge_speed
		velocity = desired_velocity
		facing = _dir
		if not _hit_done and dist_to_target() < hit_radius + 36.0:
			_hit_done = true
			target.take_damage(strike_damage * damage_mult, global_position, self)
			Combat.spark(target.global_position, MAGENTA, 1.2)
		if _lunge <= 0.0 or is_on_wall():
			_lunge = 0.0
			_recover = 0.75
		return
	if _recover > 0.0:
		_recover -= delta
		return
	if _windup > 0.0:
		_windup -= delta
		facing = dir_to_target()
		if _windup <= 0.0:
			_lunge = 0.32
			_dir = facing
			_hit_done = false
			_cd = 2.2
			Sfx.play(&"dash", -10.0, 0.15)
		return
	if dist_to_target() < lunge_range and _cd <= 0.0 and has_line_of_sight(target.global_position):
		_windup = WINDUP
		Sfx.play(&"charge", -14.0, 0.2)
		return
	# Slither: head for the player, weaving side to side.
	steer_to(target.global_position)
	var fwd := desired_velocity.normalized()
	desired_velocity = (fwd + fwd.orthogonal() * sin(_t * 5.0) * 0.8).normalized() * move_speed
	if velocity.length() > 20.0:
		facing = velocity.normalized()


func _draw() -> void:
	var sway := sin(_t * 5.0) * 0.22 if _windup <= 0.0 and _lunge <= 0.0 and _recover <= 0.0 else 0.0
	var rot := facing.angle() + PI / 2 + sway
	var half := TEX.get_size() / 2
	var s := Vector2.ONE * SPRITE_SCALE
	if _windup > 0.0:
		s *= Vector2(1.2, 0.78)
	elif _lunge > 0.0:
		s *= Vector2(0.88, 1.15)
	draw_set_transform(Vector2(6, 9), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, rot, s)
	var body := tint(Color.WHITE)
	if _windup > 0.0:
		body = body.lerp(Color(1.6, 0.8, 1.6), 0.3 + 0.3 * sin(_t * 35.0))
	elif _recover > 0.0:
		body = body.darkened(0.25)
	draw_texture(TEX, -half, body)
	draw_set_transform(Vector2.ZERO)
	if _windup > 0.0:
		var k := 1.0 - _windup / WINDUP
		draw_line(facing * 30.0, facing * lunge_speed * 0.32, Color(MAGENTA, 0.2 + 0.4 * k), 4.0 + 6.0 * k)
	draw_hp_bar(-hit_radius - 30)
