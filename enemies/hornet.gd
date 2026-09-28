class_name Hornet
extends Enemy
## "Hornet" (Higgsfield sprite, Endless mode): small quad-rotor attack drone. Circles you at mid range
## and fires quick two-shot stinger bursts (its eye glows red and an aim line shows just before).
## Fragile, but it comes in numbers. (It still collides like a ground unit: the painted arenas warp
## anything found inside an obstacle or off the floor back to a spawn point.)

const TEX := preload("res://assets/hq/enemies4/hornet.png")
const SPRITE_SCALE := 0.62
const STING := Color(1.0, 0.3, 0.25)
const ORBIT := 250.0
## Rotor fan centres as fractions of the sprite (x, y from the top-left).
const FANS := [Vector2(0.2, 0.22), Vector2(0.8, 0.22), Vector2(0.2, 0.72), Vector2(0.8, 0.72)]

var _orbit_dir := 1.0
var _burst_cd := 1.5
var _aim := 0.0
var _shots := 0
var _shot_t := 0.0


func _ready() -> void:
	super._ready()
	_orbit_dir = [-1.0, 1.0].pick_random()
	_burst_cd = randf_range(1.0, 2.5)


func _think(delta: float) -> void:
	_burst_cd -= delta
	var to_t := dir_to_target()
	var d := dist_to_target()
	var sees := has_line_of_sight(target.global_position)
	facing = to_t
	# Circle the player: tangent + a pull toward the orbit radius.
	if d > 560.0 or not sees:
		steer_to(target.global_position)
	else:
		var radial := to_t * clampf((d - ORBIT) / 120.0, -1.0, 1.0)
		desired_velocity = (to_t.orthogonal() * _orbit_dir + radial).normalized() * move_speed
		if is_on_wall():
			_orbit_dir = -_orbit_dir
	if _aim > 0.0:
		_aim -= delta
		if _aim <= 0.0:
			_shots = 2
			_shot_t = 0.0
	if _shots > 0:
		_shot_t -= delta
		if _shot_t <= 0.0:
			_shots -= 1
			_shot_t = 0.12
			shoot(to_t, 520.0, 7.0, STING, 0.9)
			Sfx.play(&"enemy_shoot", -14.0, 0.2)
	elif _burst_cd <= 0.0 and _aim <= 0.0 and d < 560.0 and sees:
		_burst_cd = randf_range(1.8, 2.6)
		_aim = 0.4


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var size := TEX.get_size()
	var half := size / 2
	var s := Vector2.ONE * (SPRITE_SCALE + sin(_t * 6.0) * 0.02)
	# Flying: the shadow sits further away and smaller.
	draw_set_transform(Vector2(16, 24), rot, s * 0.85)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, tint(Color.WHITE))
	# Rotor shimmer over the four fans.
	for i in FANS.size():
		var c: Vector2 = -half + size * FANS[i]
		var a := _t * 30.0 * (1.0 if i % 2 == 0 else -1.0)
		draw_arc(c, size.x * 0.15, a, a + 2.2, 10, Color(0.8, 0.9, 1.0, 0.35), 3.0, true)
		draw_arc(c, size.x * 0.15, a + PI, a + PI + 2.2, 10, Color(0.8, 0.9, 1.0, 0.35), 3.0, true)
	draw_set_transform(Vector2.ZERO)
	if _aim > 0.0:
		var k := 1.0 - _aim / 0.4
		draw_circle(facing * 10.0, 7.0 + 6.0 * k, Color(STING, 0.3 + 0.4 * k))
		draw_line(facing * 20.0, facing * 190.0, Color(STING, 0.15 + 0.3 * k), 2.0)
	draw_hp_bar(-hit_radius - 16)
