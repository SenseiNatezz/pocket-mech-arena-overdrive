class_name AegisGuardian
extends Enemy
## "Aegis Guardian" (Higgsfield sprite): heavy knight mech with a cyan energy shield and a plasma mace.
## The shield soaks everything that hits it from the front (up to `shield_max` damage, overflow goes
## through), then shatters for `shield_down_time` seconds. It turns slowly, so boost around and hit it
## from the side or back. Up close it winds up a mace slam (orange ring telegraph); at range it throws
## slow shield-pulse orbs.

const TEX := preload("res://assets/hq/enemies2/aegis_guardian.png")
const SPRITE_SCALE := 0.62
const SHIELD := Color(0.3, 0.9, 1.0)
const MACE := Color(1.0, 0.55, 0.15)
## Half-angle of the blocking arc (rad, ~70 deg).
const BLOCK_ARC := 1.22
## Fraction of the sprite's height (from the top) that is the shield.
const SHIELD_BAND := 0.2
const SLAM_RADIUS := 105.0

@export var shield_max := 140.0
@export var shield_down_time := 5.0
@export var turn_rate := 1.5
@export var slam_damage := 24.0

enum State { WALK, WINDUP, RECOVER }

var shield_hp := 0.0
var _shield_down := 0.0
var _shield_flash := 0.0
var _state := State.WALK
var _st := 0.0
var _slam_cd := 0.5
var _orb_cd := 2.5
var _slam_at := Vector2.ZERO
var _slam_fx := 0.0


func _ready() -> void:
	super._ready()
	shield_hp = shield_max


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	if not dead and shield_hp > 0.0:
		var off := from_pos - global_position
		if off.length() > 4.0 and absf(facing.angle_to(off)) < BLOCK_ARC:
			var soaked := minf(amount, shield_hp)
			shield_hp -= soaked
			_shield_flash = 1.0
			Combat.spark(global_position + off.normalized() * hit_radius * 1.5, SHIELD, 0.9)
			Sfx.play(&"hit", -16.0, 0.3)
			if shield_hp <= 0.0:
				_break_shield()
			amount -= soaked
			if amount <= 0.0:
				return
	super.take_damage(amount, from_pos, source)


func _break_shield() -> void:
	shield_hp = 0.0
	_shield_down = shield_down_time
	Combat.shockwave(global_position + facing * hit_radius, 110.0, SHIELD, 0.35)
	Combat.burst(global_position + facing * hit_radius, SHIELD, 420.0, 1.2)
	Sfx.play(&"freeze", -4.0)


func _think(delta: float) -> void:
	_st -= delta
	_slam_cd -= delta
	_orb_cd -= delta
	var to_t := dir_to_target()
	var d := dist_to_target()
	match _state:
		State.WALK:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), turn_rate * delta))
			if d > 115.0:
				steer_to(target.global_position)
			if _slam_cd <= 0.0 and d < 160.0:
				_state = State.WINDUP
				_st = 0.7
				_slam_at = global_position + to_t * 80.0
				Sfx.play(&"charge", -12.0, 0.1)
			elif _orb_cd <= 0.0 and d > 260.0 and d < 700.0 and has_line_of_sight(target.global_position):
				_orb_cd = 3.2
				for i in 3:
					shoot(facing.rotated((i - 1) * 0.28), 240.0, 10.0, SHIELD, 1.7)
				Sfx.play(&"enemy_shoot", -8.0)
		State.WINDUP:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), turn_rate * 0.5 * delta))
			if _st <= 0.0:
				_slam()
				_state = State.RECOVER
				_st = 0.6
		State.RECOVER:
			if _st <= 0.0:
				_state = State.WALK
				_slam_cd = 1.4


func _slam() -> void:
	_slam_fx = 1.0
	if target.global_position.distance_to(_slam_at) < SLAM_RADIUS + 18.0:
		target.take_damage(slam_damage * damage_mult, _slam_at, self)
	Combat.damage_destructibles(_slam_at, SLAM_RADIUS, 30.0)
	Combat.shockwave(_slam_at, SLAM_RADIUS, MACE, 0.35)
	Combat.burst(_slam_at, MACE, 380.0, 1.2)
	Combat.shake(0.3)
	Sfx.play(&"slam", -3.0)


func _process(delta: float) -> void:
	_shield_flash = move_toward(_shield_flash, 0.0, delta * 5.0)
	_slam_fx = move_toward(_slam_fx, 0.0, delta * 3.0)
	if _shield_down > 0.0 and not dead:
		_shield_down -= delta
		if _shield_down <= 0.0:
			shield_hp = shield_max
			Combat.shockwave(global_position + facing * hit_radius, 90.0, SHIELD, 0.3)
			Sfx.play(&"shield", -8.0)


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var size := TEX.get_size()
	var half := size / 2
	var stomp := absf(sin(_t * 7.0)) * 0.02 if velocity.length() > 20.0 else 0.0
	var s := Vector2.ONE * (SPRITE_SCALE + stomp)
	draw_set_transform(Vector2(8, 12), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.42))
	draw_set_transform(Vector2.ZERO, rot, s)
	var body := tint(Color.WHITE)
	if _state == State.WINDUP:
		body = body.lerp(Color(1.5, 1.0, 0.6), 0.35 + 0.35 * sin(_t * 30.0))
	draw_texture(TEX, -half, body)
	var band := Rect2(0, 0, size.x, size.y * SHIELD_BAND)
	if shield_hp <= 0.0:
		# Shield shattered: the emitter goes dark (flickers back on just before it returns).
		var flick := 0.35 if _shield_down < 0.8 and sin(_t * 50.0) > 0.0 else 0.8
		draw_texture_rect_region(TEX, Rect2(-half, band.size), band, Color(0.05, 0.08, 0.12, flick))
	elif _shield_flash > 0.0:
		draw_texture_rect_region(TEX, Rect2(-half, band.size), band, Color(0.8, 1.5, 1.8, 0.6 * _shield_flash))
	draw_set_transform(Vector2.ZERO)
	# Blocking arc: a faint energy barrier in front that flares when it soaks a hit.
	if shield_hp > 0.0:
		var a := facing.angle()
		var strength := shield_hp / shield_max
		draw_arc(Vector2.ZERO, hit_radius * 2.3, a - BLOCK_ARC * 0.8, a + BLOCK_ARC * 0.8, 20,
			Color(SHIELD, 0.12 + 0.1 * strength + 0.45 * _shield_flash), 6.0 + 6.0 * _shield_flash, true)
	if _state == State.WINDUP:
		var k := 1.0 - _st / 0.7
		var at := to_local(_slam_at)
		draw_circle(at, SLAM_RADIUS, Color(MACE, 0.08 + 0.14 * k))
		draw_arc(at, SLAM_RADIUS, 0.0, TAU, 40, Color(MACE, 0.5 + 0.4 * k), 3.0, true)
		draw_arc(at, SLAM_RADIUS * k, 0.0, TAU, 40, Color(1.0, 0.8, 0.5, 0.6), 2.0, true)
	if _slam_fx > 0.0:
		draw_circle(to_local(_slam_at), 40.0 * _slam_fx + 10.0, Color(1.0, 0.75, 0.4, 0.5 * _slam_fx))
	draw_hp_bar(-hit_radius - 40)
