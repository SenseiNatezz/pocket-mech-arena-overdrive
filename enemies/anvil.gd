class_name Anvil
extends Enemy
## "Anvil" (Higgsfield sprite, Volcanic Forge): a heavy forge-hammer bruiser.
##   leap-slam  at mid range it crouches (a red landing circle marks where it will come down), jumps,
##              and slams: area damage + knockback, a shockwave and a ring of fire bolts
##   swing      up close it winds up and sweeps the hammer through the space in front of it
## After a slam it's stuck for a moment with its hammer in the ground: it takes +50% damage then.

const TEX := preload("res://assets/hq/enemies5/anvil.png")
const SPRITE_SCALE := 0.62
const LEAP_MIN := 200.0
const LEAP_MAX := 460.0
const CROUCH := 0.8
const LEAP_TIME := 0.55
const SLAM_RADIUS := 140.0
const SWING_RANGE := 130.0
const HOT := Color(1.0, 0.45, 0.12)

@export var slam_damage := 22.0
@export var swing_damage := 16.0

enum State { WALK, CROUCH, LEAP, STUCK, SWING_WINDUP, SWING }

var _state := State.WALK
var _st := 0.0
var _leap_cd := 1.5
var _from := Vector2.ZERO
var _land := Vector2.ZERO
var _swing_fx := 0.0


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	if _state == State.STUCK:
		amount *= 1.5
	elif _state == State.LEAP:
		return  # in the air
	super.take_damage(amount, from_pos, source)


func _think(delta: float) -> void:
	_st -= delta
	_leap_cd -= delta
	_swing_fx = move_toward(_swing_fx, 0.0, delta * 4.0)
	var to_t := dir_to_target()
	var d := dist_to_target()
	match _state:
		State.WALK:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 3.0 * delta))
			steer_to(target.global_position)
			if d < SWING_RANGE:
				_state = State.SWING_WINDUP
				_st = 0.45
			elif _leap_cd <= 0.0 and d > LEAP_MIN and d < LEAP_MAX and has_line_of_sight(target.global_position):
				_state = State.CROUCH
				_st = CROUCH
				_land = target.global_position + target.velocity * 0.35
				Sfx.play(&"charge", -10.0, 0.0)
		State.CROUCH:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), (_land - global_position).angle(), 5.0 * delta))
			if _st <= 0.0:
				_state = State.LEAP
				_st = LEAP_TIME
				_from = global_position
				collision_layer = 0
				Sfx.play(&"dash", -6.0)
		State.LEAP:
			var v := (_land - _from) / LEAP_TIME
			desired_velocity = v
			velocity = v
			if _st <= 0.0:
				_slam()
		State.STUCK:
			if _st <= 0.0:
				_state = State.WALK
				_leap_cd = 2.4
		State.SWING_WINDUP:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 6.0 * delta))
			if _st <= 0.0:
				_state = State.SWING
				_st = 0.35
				_swing_fx = 1.0
				Combat.area_damage(global_position + facing * 50.0, SWING_RANGE, swing_damage * damage_mult, self, true,
					facing, 1.1, 300.0)
				Combat.damage_destructibles(global_position + facing * 50.0, SWING_RANGE, 30.0, facing, 1.1)
				Sfx.play(&"slam", -8.0, 0.1)
		State.SWING:
			if _st <= 0.0:
				_state = State.WALK
				_leap_cd = maxf(_leap_cd, 0.8)


func _slam() -> void:
	collision_layer = 256
	_state = State.STUCK
	_st = 1.0
	Combat.area_damage(global_position, SLAM_RADIUS, slam_damage * damage_mult, self, true, Vector2.ZERO, PI, 420.0)
	Combat.damage_destructibles(global_position, SLAM_RADIUS, 40.0)
	Combat.shockwave(global_position, SLAM_RADIUS * 1.4, HOT, 0.45)
	Combat.debris(global_position, 40.0, Color(0.35, 0.3, 0.3))
	Combat.shake(0.35)
	Sfx.play(&"slam", -2.0)
	for i in 8:
		shoot(Vector2.from_angle(TAU * i / 8.0 + 0.2), 260.0, 9.0, HOT, 1.2)


func _draw() -> void:
	# Landing marker while crouching / in the air.
	if _state == State.CROUCH or _state == State.LEAP:
		var k := 1.0 - _st / (CROUCH if _state == State.CROUCH else LEAP_TIME)
		var at := _land - global_position
		draw_circle(at, SLAM_RADIUS, Color(1.0, 0.2, 0.1, 0.1 + 0.12 * k))
		draw_arc(at, SLAM_RADIUS, 0, TAU, 40, Color(1.0, 0.3, 0.15, 0.8), 3.0, true)
		draw_arc(at, SLAM_RADIUS * (k if _state == State.CROUCH else 1.0), 0, TAU, 40, Color(1.0, 0.6, 0.3, 0.6), 2.0, true)
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var lift := 0.0
	if _state == State.LEAP:
		lift = sin(clampf(1.0 - _st / LEAP_TIME, 0.0, 1.0) * PI)
	var squash := 0.06 if _state == State.CROUCH else 0.0
	var s := Vector2(SPRITE_SCALE + squash, SPRITE_SCALE - squash) * (1.0 + 0.28 * lift)
	draw_set_transform(Vector2(8, 12) + Vector2(14, 22) * lift, rot, s * (1.0 - 0.25 * lift))
	draw_texture(TEX, -half, Color(0, 0, 0, 0.42 - 0.2 * lift))
	draw_set_transform(Vector2(0, -40.0 * lift), rot, s)
	var body := tint(Color.WHITE)
	if _state == State.STUCK:
		body = body.lerp(Color(0.75, 0.75, 0.8), 0.3)
	draw_texture(TEX, -half, body)
	draw_set_transform(Vector2.ZERO)
	if _swing_fx > 0.0:
		var a := facing.angle()
		draw_arc(Vector2.ZERO, SWING_RANGE * 0.85, a - 1.0, a + 1.0, 20, Color(HOT.lightened(0.3), 0.7 * _swing_fx), 10.0 * _swing_fx, true)
	if _state == State.STUCK:
		# Hammer cooling in the ground: a glowing crater ring under it.
		draw_arc(Vector2.ZERO, hit_radius + 18.0, 0, TAU, 32, Color(HOT, 0.4 * _st), 4.0, true)
	draw_hp_bar(-hit_radius - 40)
