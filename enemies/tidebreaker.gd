class_name Tidebreaker
extends Enemy
## "Tidebreaker" (Higgsfield sprite, Endless mini-boss): giant armored crab walker (2x armor, like the
## heavy tanks). Scuttles toward you with its pincers forward.
##   Pincer snap  up close: claws glow + a cone shows for 0.45 s, then a crushing snap in front of it
##   Charge       at range: plants its legs and shows a charge lane for 0.8 s, then barrels along it,
##                smashing crates and cover; a hit knocks you back hard
##   Stun         if the charge slams into a wall it's STUNNED for 2 s and takes 1.5x damage, so bait
##                its charge into walls

const TEX := preload("res://assets/hq/enemies4/tidebreaker.png")
const SPRITE_SCALE := 0.62
const CORAL := Color(1.0, 0.5, 0.3)
const SNAP_RANGE := 150.0
const SNAP_HALF := 0.75
const SNAP_WINDUP := 0.45
const AIM_TIME := 0.8
const CHARGE_SPEED := 720.0
const CHARGE_TIME := 0.9
const STUN_TIME := 2.0

@export var snap_damage := 20.0
@export var charge_damage := 26.0

enum State { WALK, SNAP, AIM, CHARGE, STUNNED, RECOVER }

var _state := State.WALK
var _st := 0.0
var _snap_cd := 1.0
var _charge_cd := 3.0
var _dir := Vector2.ZERO
var _hit_done := false
var _snap_fx := 0.0


func _ready() -> void:
	super._ready()
	set_armor(armor_tier if armor_tier > 0 else 2)
	facing = Vector2.DOWN


## Heavy: barely moved by hits and explosions.
func knock(impulse: Vector2) -> void:
	super.knock(impulse * 0.15)


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	if _state == State.STUNNED:
		amount *= 1.5
	super.take_damage(amount, from_pos, source)


func _think(delta: float) -> void:
	_st -= delta
	_snap_cd -= delta
	_charge_cd -= delta
	_snap_fx = move_toward(_snap_fx, 0.0, delta * 3.0)
	var to_t := dir_to_target()
	var d := dist_to_target()
	match _state:
		State.WALK:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 2.2 * delta))
			steer_to(target.global_position)
			if _snap_cd <= 0.0 and d < SNAP_RANGE + 30.0:
				_state = State.SNAP
				_st = SNAP_WINDUP
				Sfx.play(&"charge", -12.0, 0.1)
			elif _charge_cd <= 0.0 and d > 260.0 and d < 650.0 and has_line_of_sight(target.global_position):
				_state = State.AIM
				_st = AIM_TIME
				Sfx.play(&"alarm", -10.0)
		State.SNAP:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 1.2 * delta))
			if _st <= 0.0:
				_snap()
				_state = State.RECOVER
				_st = 0.5
		State.AIM:
			# Tracks you while aiming, then locks the lane for the last 0.25 s.
			if _st > 0.25:
				facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 3.0 * delta))
			_dir = facing
			if _st <= 0.0:
				_state = State.CHARGE
				_st = CHARGE_TIME
				_hit_done = false
				Sfx.play(&"dash", -6.0)
		State.CHARGE:
			desired_velocity = _dir * CHARGE_SPEED
			velocity = desired_velocity
			Combat.damage_destructibles(global_position + _dir * hit_radius, 70.0, 80.0)
			if not _hit_done and d < hit_radius + 30.0:
				_hit_done = true
				target.take_damage(charge_damage * damage_mult, global_position, self)
				target._knockback += _dir * 900.0
				Combat.shake(0.4)
			if is_on_wall() and _st < CHARGE_TIME - 0.1:
				_state = State.STUNNED
				_st = STUN_TIME
				velocity = Vector2.ZERO
				Combat.shockwave(global_position + _dir * hit_radius, 120.0, CORAL, 0.35)
				Combat.burst(global_position + _dir * hit_radius, Color(0.8, 0.8, 0.85), 380.0, 1.3)
				Combat.shake(0.45)
				Sfx.play(&"slam", -3.0)
			elif _st <= 0.0:
				_state = State.RECOVER
				_st = 0.6
		State.STUNNED:
			if _st <= 0.0:
				_state = State.RECOVER
				_st = 0.3
		State.RECOVER:
			if _st <= 0.0:
				if _charge_cd <= 0.0:
					_charge_cd = randf_range(4.0, 5.5)
				_snap_cd = maxf(_snap_cd, 1.2)
				_state = State.WALK


func _snap() -> void:
	_snap_fx = 1.0
	var off := target.global_position - global_position
	if off.length() < SNAP_RANGE + 20.0 and absf(facing.angle_to(off)) < SNAP_HALF:
		target.take_damage(snap_damage * damage_mult, global_position, self)
	Combat.damage_destructibles(global_position, SNAP_RANGE, 40.0, facing, SNAP_HALF)
	Combat.burst(global_position + facing * SNAP_RANGE * 0.6, CORAL, 360.0, 1.1)
	Combat.shake(0.25)
	Sfx.play(&"slam", -8.0, 0.2)


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var gait := sin(_t * 14.0) * 0.025 if velocity.length() > 20.0 else 0.0
	var s := Vector2(SPRITE_SCALE * (1.0 + gait), SPRITE_SCALE * (1.0 - gait))
	var jitter := Vector2(randf_range(-2, 2), randf_range(-2, 2)) if _state == State.STUNNED else Vector2.ZERO
	draw_set_transform(Vector2(10, 14) + jitter, rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.45))
	draw_set_transform(jitter, rot, s)
	var body := tint(armor_tint())
	if _state == State.SNAP or _state == State.AIM:
		body = body.lerp(Color(1.5, 1.0, 0.7), 0.3 + 0.3 * sin(_t * 30.0))
	elif _state == State.STUNNED:
		body = body.darkened(0.3)
	draw_texture(TEX, -half, body)
	draw_set_transform(Vector2.ZERO)
	var a := facing.angle()
	match _state:
		State.SNAP:
			var k := 1.0 - _st / SNAP_WINDUP
			draw_arc(Vector2.ZERO, SNAP_RANGE, a - SNAP_HALF, a + SNAP_HALF, 20, Color(CORAL, 0.35 + 0.5 * k), 3.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2.from_angle(a - SNAP_HALF) * SNAP_RANGE,
				Vector2.from_angle(a) * SNAP_RANGE, Vector2.from_angle(a + SNAP_HALF) * SNAP_RANGE]), Color(CORAL, 0.08 + 0.12 * k))
		State.AIM:
			var k := 1.0 - _st / AIM_TIME
			var w := hit_radius * 1.6
			var len := CHARGE_SPEED * CHARGE_TIME
			var side := _dir.orthogonal() * w / 2.0
			draw_colored_polygon(PackedVector2Array([side, _dir * len + side, _dir * len - side, -side]), Color(1.0, 0.3, 0.2, 0.08 + 0.14 * k))
			draw_line(side, _dir * len + side, Color(1.0, 0.35, 0.25, 0.5), 2.0)
			draw_line(-side, _dir * len - side, Color(1.0, 0.35, 0.25, 0.5), 2.0)
		State.STUNNED:
			for i in 3:
				var p := Vector2.from_angle(_t * 4.0 + TAU * i / 3.0) * 34.0 + Vector2(0, -hit_radius - 10)
				draw_circle(p, 5.0, Color(1.0, 0.95, 0.5, 0.9))
	if _snap_fx > 0.0:
		draw_circle(facing * SNAP_RANGE * 0.6, 30.0 * _snap_fx + 8.0, Color(1.0, 0.7, 0.5, 0.45 * _snap_fx))
	draw_hp_bar(-hit_radius - 56)
