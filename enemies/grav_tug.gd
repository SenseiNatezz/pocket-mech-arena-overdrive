class_name GravTug
extends Enemy
## "Grav Tug" (Higgsfield sprite, Orbital Dry Dock): a heavy dock tug with two grabber claws and a
## gravity emitter. When it has a clear line to you it locks on (a flickering violet line), then fires a
## TRACTOR BEAM that drags you toward its claws (Mech.pull - boosting breaks free, so does breaking line
## of sight). Up close the claws CLAMP: a short wind-up, then a heavy crushing hit.

const TEX := preload("res://assets/hq/enemies6/grav_tug.png")
const SPRITE_SCALE := 0.5
const VIOLET := Color(0.8, 0.35, 1.0)
const BEAM_RANGE := 500.0
const LOCK_TIME := 0.55
const BEAM_TIME := 2.4
const PULL := 175.0
const CLAMP_RANGE := 120.0
const CLAMP_WINDUP := 0.4

@export var clamp_damage := 18.0
@export var beam_dps := 6.0

enum State { WALK, LOCK, BEAM, CLAMP, RECOVER }

var _state := State.WALK
var _st := 0.0
var _beam_cd := 2.0
var _clamp_cd := 0.0
var _tick := 0.0


func _ready() -> void:
	super._ready()
	_beam_cd = randf_range(1.5, 2.5)


func _emitter() -> Vector2:
	return global_position + facing * (hit_radius * 0.9)


func _think(delta: float) -> void:
	_st -= delta
	_beam_cd -= delta
	_clamp_cd -= delta
	var d := dist_to_target()
	var los := has_line_of_sight(target.global_position)
	facing = Vector2.from_angle(rotate_toward(facing.angle(), dir_to_target().angle(), (2.0 if _state == State.BEAM else 4.0) * delta))
	if _state != State.CLAMP and _state != State.RECOVER and _clamp_cd <= 0.0 and d < CLAMP_RANGE:
		_state = State.CLAMP
		_st = CLAMP_WINDUP
		Sfx.play(&"charge", -10.0, 0.1)
	match _state:
		State.WALK:
			steer_to(target.global_position)
			if _beam_cd <= 0.0 and los and d < BEAM_RANGE and d > CLAMP_RANGE + 40.0:
				_state = State.LOCK
				_st = LOCK_TIME
				Sfx.play(&"charge", -12.0, 0.4)
		State.LOCK:
			desired_velocity = Vector2.ZERO
			if not los:
				_end_beam()
			elif _st <= 0.0:
				_state = State.BEAM
				_st = BEAM_TIME
				_tick = 0.0
				Sfx.play(&"laser", -12.0, 0.4)
		State.BEAM:
			desired_velocity = dir_to_target() * move_speed * 0.25
			if not los or d > BEAM_RANGE * 1.25 or _st <= 0.0:
				_end_beam()
			else:
				target.pull((global_position - target.global_position).normalized() * PULL)
				_tick -= delta
				if _tick <= 0.0:
					_tick = 0.5
					target.take_damage(beam_dps * 0.5 * damage_mult, global_position, self)
		State.CLAMP:
			desired_velocity = Vector2.ZERO
			if _st <= 0.0:
				var claw := global_position + facing * (hit_radius + 20.0)
				Combat.area_damage(claw, 70.0, clamp_damage * damage_mult, self, true, Vector2.ZERO, PI, 260.0)
				Combat.shockwave(claw, 90.0, VIOLET, 0.3)
				Combat.shake(0.2)
				Sfx.play(&"slam", -8.0, 0.15)
				_state = State.RECOVER
				_st = 0.7
				_clamp_cd = 1.8
		State.RECOVER:
			if _st <= 0.0:
				_state = State.WALK


func _end_beam() -> void:
	_state = State.WALK
	_beam_cd = randf_range(3.0, 4.2)


func _draw() -> void:
	var em := _emitter() - global_position
	var tp := target.global_position - global_position if is_instance_valid(target) else em
	if _state == State.LOCK:
		var flick := 0.4 + 0.6 * float(int(_t * 24.0) % 2)
		draw_line(em, tp, Color(VIOLET, 0.25 + 0.35 * flick), 2.0, true)
	elif _state == State.BEAM:
		var w := 14.0 + 3.0 * sin(_t * 30.0)
		draw_line(em, tp, Color(VIOLET, 0.25), w * 2.0, true)
		draw_line(em, tp, Color(0.95, 0.75, 1.0, 0.7), w * 0.5, true)
		# Rings sliding down the beam toward the tug.
		for i in 5:
			var f := 1.0 - fmod(_t * 1.6 + i * 0.2, 1.0)
			var p := em.lerp(tp, f)
			draw_arc(p, 10.0 + 8.0 * f, 0, TAU, 16, Color(VIOLET, 0.6 * f), 2.0, true)
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var squeeze := 0.05 * (1.0 - _st / CLAMP_WINDUP) if _state == State.CLAMP else 0.0
	var s := Vector2(SPRITE_SCALE - squeeze, SPRITE_SCALE + squeeze * 0.5)
	draw_set_transform(Vector2(8, 14), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, tint(Color.WHITE))
	draw_set_transform(Vector2.ZERO)
	if _state == State.LOCK or _state == State.BEAM:
		draw_circle(em, 10.0 + 4.0 * sin(_t * 20.0), Color(VIOLET, 0.6))
	draw_hp_bar(-hit_radius - 26)
