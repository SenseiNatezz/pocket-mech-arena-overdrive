class_name Heliostat
extends Enemy
## "Heliostat" (Higgsfield sprite, Titan Graveyard): a four-legged sniper with a mirror dish on its back.
## It keeps its distance, plants its legs, and focuses sunlight: a thin gold aim line tracks you and grows
## brighter, LOCKS (turns white and stops following - sidestep now), then the dish fires a SUN LANCE, an
## instant beam out to the first wall. Cover blocks it.

const TEX := preload("res://assets/hq/enemies6/heliostat.png")
const SPRITE_SCALE := 0.46
const GOLD := Color(1.0, 0.85, 0.35)
const TURQ := Color(0.3, 1.0, 0.85)
const KEEP_MIN := 430.0
const KEEP_MAX := 760.0
const CHARGE := 1.3
const LOCK := 0.35
const FLASH := 0.25
const REACH := 1400.0
const LANCE_HIT := 14.0

@export var lance_damage := 14.0

enum State { WALK, CHARGE, LOCK, FIRE }

var _state := State.WALK
var _st := 0.0
var _cd := 2.0
var _aim := Vector2.DOWN
var _end := Vector2.ZERO


func _ready() -> void:
	super._ready()
	_cd = randf_range(1.5, 3.0)


func _muzzle() -> Vector2:
	return global_position + _aim * (hit_radius + 10.0)


func _think(delta: float) -> void:
	_st -= delta
	_cd -= delta
	var d := dist_to_target()
	var los := has_line_of_sight(target.global_position)
	match _state:
		State.WALK:
			if not los or d > KEEP_MAX:
				steer_to(target.global_position)
			elif d < KEEP_MIN:
				desired_velocity = -dir_to_target() * move_speed
			_aim = Vector2.from_angle(rotate_toward(_aim.angle(), dir_to_target().angle(), 4.0 * delta))
			facing = _aim
			if _cd <= 0.0 and los and d < REACH * 0.8:
				_state = State.CHARGE
				_st = CHARGE
				Sfx.play(&"charge", -10.0, 0.0)
		State.CHARGE:
			_aim = Vector2.from_angle(rotate_toward(_aim.angle(), dir_to_target().angle(), 2.6 * delta))
			facing = _aim
			_trace()
			if _st <= 0.0:
				_state = State.LOCK
				_st = LOCK
		State.LOCK:
			_trace()
			if _st <= 0.0:
				_fire()
		State.FIRE:
			if _st <= 0.0:
				_state = State.WALK
				_cd = randf_range(3.4, 4.4)


func _trace() -> void:
	var q := PhysicsRayQueryParameters2D.create(_muzzle(), _muzzle() + _aim * REACH, 1 | 32)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	_end = hit.position if not hit.is_empty() else _muzzle() + _aim * REACH


func _fire() -> void:
	_trace()
	_state = State.FIRE
	_st = FLASH
	var a := _muzzle()
	var p := Geometry2D.get_closest_point_to_segment(target.global_position, a, _end)
	var hr: float = target.get("hit_radius") if target.get("hit_radius") != null else 20.0
	if p.distance_to(target.global_position) < LANCE_HIT + hr:
		target.take_damage(lance_damage * damage_mult, global_position, self)
		Combat.spark(target.global_position, GOLD, 1.5)
	Combat.spark(_end, GOLD, 1.6)
	Combat.spark(a, Color(1, 1, 0.9), 1.2)
	Sfx.play(&"laser", -8.0, 0.1)


func _draw() -> void:
	var a := _muzzle() - global_position
	var e := _end - global_position
	if _state == State.CHARGE:
		var k := 1.0 - _st / CHARGE
		draw_line(a, e, Color(GOLD, 0.15 + 0.45 * k), 1.0 + 2.0 * k, true)
	elif _state == State.LOCK:
		var blink := 0.6 + 0.4 * sin(_t * 40.0)
		draw_line(a, e, Color(1, 1, 1, 0.9 * blink), 3.0, true)
		draw_line(a, e, Color(1.0, 0.4, 0.2, 0.35), 9.0, true)
	elif _state == State.FIRE:
		var k := _st / FLASH
		draw_line(a, e, Color(GOLD, 0.5 * k), 26.0 * k + 4.0, true)
		draw_line(a, e, Color(1, 1, 0.92, k), 8.0 * k + 2.0, true)
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var step := absf(sin(_t * 9.0)) * 0.02 if velocity.length() > 20.0 else 0.0
	var s := Vector2(SPRITE_SCALE + step, SPRITE_SCALE - step)
	draw_set_transform(Vector2(6, 10), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, tint(Color.WHITE))
	draw_set_transform(Vector2.ZERO)
	if _state == State.CHARGE or _state == State.LOCK:
		var k := 1.0 if _state == State.LOCK else 1.0 - _st / CHARGE
		draw_circle(a, 6.0 + 10.0 * k, Color(GOLD, 0.35 + 0.4 * k))
	draw_hp_bar(-hit_radius - 26)
