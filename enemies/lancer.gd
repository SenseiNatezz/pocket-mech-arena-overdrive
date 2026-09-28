class_name Lancer
extends Enemy
## "Lancer" (Higgsfield sprite): spider-legged sniper mech carrying a long rail lance. Skitters around
## at long range, then paints the player with a green targeting laser (tracks, then LOCKS and blinks
## red) and fires a piercing rail shot along that line. Walls and cover block the shot, and moving off
## the line once it locks dodges it.

const TEX := preload("res://assets/hq/enemies2/lancer.png")
const SPRITE_SCALE := 0.62
## The art's body sits below the texture centre; shift it so the body is on the node origin.
const ART_OFFSET := Vector2(0, -25)
## Lance tip in sprite space (sprite faces up), before scaling.
const TIP := Vector2(0, -140)
const RAIL := Color(0.45, 1.0, 0.35)
const LOCK := Color(1.0, 0.3, 0.25)
const RAIL_LENGTH := 1500.0

@export var preferred_range := Vector2(380, 620)
@export var aim_time := 1.0
@export var lock_time := 0.4
@export var rail_damage := 24.0
@export var rail_cooldown := 2.8

enum State { MOVE, AIM, LOCK }

var _state := State.MOVE
var _st := 0.0
var _cd := 1.6
var _strafe := 1.0
var _strafe_t := 0.0
var _sight_to := Vector2.ZERO
var _rail_from := Vector2.ZERO
var _rail_to := Vector2.ZERO
var _rail_fx := 0.0


func _think(delta: float) -> void:
	_cd -= delta
	_st -= delta
	var d := dist_to_target()
	var los := has_line_of_sight(target.global_position)
	match _state:
		State.MOVE:
			facing = facing.slerp(dir_to_target(), 1.0 - exp(-6.0 * delta))
			_strafe_t -= delta
			if _strafe_t <= 0.0:
				_strafe_t = randf_range(0.8, 1.6)
				_strafe = -_strafe
			if not los or d > preferred_range.y:
				steer_to(target.global_position)
			elif d < preferred_range.x:
				desired_velocity = -facing * move_speed
			else:
				desired_velocity = facing.orthogonal() * _strafe * move_speed * 0.8
			if _cd <= 0.0 and los and d < 800.0:
				_state = State.AIM
				_st = aim_time
				Sfx.play(&"charge", -12.0, 0.0)
		State.AIM:
			facing = facing.slerp(dir_to_target(), 1.0 - exp(-9.0 * delta))
			_update_sight()
			if _st <= 0.0:
				_state = State.LOCK
				_st = lock_time
				Sfx.play(&"select", -6.0, 0.0)
		State.LOCK:
			_update_sight()
			if _st <= 0.0:
				_fire_rail()
				_state = State.MOVE
				_cd = rail_cooldown


func _tip_world() -> Vector2:
	return global_position + (TIP * SPRITE_SCALE).rotated(facing.angle() + PI / 2)


## Where the laser sight (and the rail) ends: the first wall or cover along the lance.
func _update_sight() -> void:
	var from := _tip_world()
	var q := PhysicsRayQueryParameters2D.create(from, from + facing * RAIL_LENGTH, 1 | 32)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	_sight_to = hit.position if not hit.is_empty() else from + facing * RAIL_LENGTH


func _fire_rail() -> void:
	_rail_from = _tip_world()
	_rail_to = _sight_to
	_rail_fx = 1.0
	var p := target.global_position
	if Geometry2D.get_closest_point_to_segment(p, _rail_from, _rail_to).distance_to(p) < 30.0:
		target.take_damage(rail_damage * damage_mult, _rail_from, self)
		Combat.spark(p, RAIL, 1.4)
	Combat.damage_destructibles(_rail_to, 40.0, 20.0)
	Combat.spark(_rail_to, RAIL, 1.2)
	Combat.spark(_rail_from, Color(0.8, 1.0, 0.7), 1.0)
	knock(-facing * 260.0)
	Sfx.play(&"beam_rifle", -4.0)


func _process(delta: float) -> void:
	_rail_fx = move_toward(_rail_fx, 0.0, delta * 4.0)


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	# Skittering legs: a quick squash while moving.
	var skitter := sin(_t * 22.0) * 0.035 if velocity.length() > 30.0 else 0.0
	var s := Vector2(SPRITE_SCALE - skitter, SPRITE_SCALE + skitter)
	draw_set_transform(Vector2(6, 10), rot, s)
	draw_texture(TEX, -half + ART_OFFSET, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half + ART_OFFSET, tint(Color.WHITE))
	draw_set_transform(Vector2.ZERO)
	var tip := to_local(_tip_world())
	if _state == State.AIM:
		var k := 1.0 - _st / aim_time
		draw_line(tip, to_local(_sight_to), Color(RAIL, 0.2 + 0.35 * k), 1.5 + k)
		draw_circle(tip, 5.0 + 5.0 * k, Color(RAIL, 0.6))
	elif _state == State.LOCK:
		var blink := 0.55 + 0.45 * signf(sin(_t * 45.0))
		draw_line(tip, to_local(_sight_to), Color(LOCK, 0.25 * blink), 16.0)
		draw_line(tip, to_local(_sight_to), Color(LOCK, blink), 3.0)
		draw_circle(tip, 12.0, Color(RAIL, 0.8))
	if _rail_fx > 0.0:
		var a := to_local(_rail_from)
		var b := to_local(_rail_to)
		draw_line(a, b, Color(RAIL, 0.35 * _rail_fx), 26.0 * _rail_fx)
		draw_line(a, b, Color(RAIL, 0.9 * _rail_fx), 8.0 * _rail_fx)
		draw_line(a, b, Color(1, 1, 1, _rail_fx), 3.0 * _rail_fx)
		draw_circle(b, 24.0 * _rail_fx, Color(RAIL, 0.6 * _rail_fx))
	draw_hp_bar(-hit_radius - 34)
