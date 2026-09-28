class_name Cinder
extends Enemy
## "Cinder" (Higgsfield sprite, Endless mode): flamethrower brute. Slow and tough. Walks you down; within
## FLAME_RANGE its pilot light flares (telegraph), then it sprays a cone of blue fire for FLAME_TIME
## seconds, turning slowly while it burns (strafe out of the cone). Weak spot: the fuel tanks on its
## back take double damage from behind, and when it dies they explode, hurting you AND nearby robots.

const TEX := preload("res://assets/hq/enemies4/cinder.png")
const SPRITE_SCALE := 0.62
const FLAME := Color(0.4, 0.7, 1.0)
const FLAME_RANGE := 250.0
const FLAME_HALF := 0.38
const FLAME_TIME := 1.6
const WINDUP := 0.55
## Distance from the centre to the nozzle.
const NOZZLE := 72.0
## Hits from within this angle of straight behind hit the fuel tanks (x2).
const BACK_ARC := 0.9

@export var flame_dps := 26.0
@export var tank_blast_damage := 22.0

enum State { WALK, WINDUP, FLAME, COOL }

var _state := State.WALK
var _st := 0.0
var _tick := 0.0
var _flame_cd := 1.0


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	var off := from_pos - global_position
	if not dead and off.length() > 4.0 and absf((-facing).angle_to(off)) < BACK_ARC:
		amount *= 2.0
		Combat.spark(global_position - facing * hit_radius, Color(1.0, 0.7, 0.3), 0.9)
	super.take_damage(amount, from_pos, source)


func die() -> void:
	if dead:
		return
	var p := global_position
	super.die()
	# Fuel tanks go up: hurts everything close, robots included.
	Combat.explode(p, 150.0, tank_blast_damage * damage_mult, self, "all", FLAME, 320.0)


func _think(delta: float) -> void:
	_st -= delta
	_flame_cd -= delta
	var to_t := dir_to_target()
	var d := dist_to_target()
	match _state:
		State.WALK:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 2.5 * delta))
			if d > FLAME_RANGE * 0.6:
				steer_to(target.global_position)
			if _flame_cd <= 0.0 and d < FLAME_RANGE + 30.0 and has_line_of_sight(target.global_position):
				_state = State.WINDUP
				_st = WINDUP
				Sfx.play(&"charge", -12.0, 0.1)
		State.WINDUP:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 2.0 * delta))
			if _st <= 0.0:
				_state = State.FLAME
				_st = FLAME_TIME
				_tick = 0.0
				Sfx.play(&"laser", -12.0, 0.1)
		State.FLAME:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 0.9 * delta))
			desired_velocity = facing * 25.0
			_tick -= delta
			if _tick <= 0.0:
				# (the mech has a short hit-invulnerability, so ticks match it)
				_tick = 0.4
				Combat.area_damage(global_position + facing * 30.0, FLAME_RANGE, flame_dps * 0.4 * damage_mult,
					self, true, facing, FLAME_HALF)
			if _st <= 0.0:
				_state = State.COOL
				_st = 0.9
		State.COOL:
			if _st <= 0.0:
				_state = State.WALK
				_flame_cd = 1.2


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var stomp := absf(sin(_t * 6.0)) * 0.02 if velocity.length() > 20.0 else 0.0
	var s := Vector2.ONE * (SPRITE_SCALE + stomp)
	draw_set_transform(Vector2(8, 12), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.42))
	draw_set_transform(Vector2.ZERO, rot, s)
	var body := tint(Color.WHITE)
	if _state == State.COOL:
		body = body.lerp(Color(1.4, 0.8, 0.5), 0.25)
	draw_texture(TEX, -half, body)
	draw_set_transform(Vector2.ZERO)
	var nozzle := facing * NOZZLE
	if _state == State.WINDUP:
		var k := 1.0 - _st / WINDUP
		draw_circle(nozzle, 8.0 + 14.0 * k, Color(FLAME, 0.3 + 0.4 * k))
		var a := facing.angle()
		draw_arc(Vector2.ZERO, FLAME_RANGE, a - FLAME_HALF, a + FLAME_HALF, 16, Color(FLAME, 0.15 + 0.35 * k), 2.0, true)
		draw_line(Vector2.ZERO, Vector2.from_angle(a - FLAME_HALF) * FLAME_RANGE, Color(FLAME, 0.1 + 0.2 * k), 2.0)
		draw_line(Vector2.ZERO, Vector2.from_angle(a + FLAME_HALF) * FLAME_RANGE, Color(FLAME, 0.1 + 0.2 * k), 2.0)
	elif _state == State.FLAME:
		# Fire: puffs streaming out along the cone, white-hot at the nozzle, fading blue.
		for i in 30:
			var k := fmod(_t * 2.6 + i * 0.137, 1.0)
			var spread := sin(i * 12.9898) * FLAME_HALF * (0.3 + 0.7 * k)
			var p := nozzle + Vector2.from_angle(facing.angle() + spread) * (FLAME_RANGE - NOZZLE * 0.5) * k
			var col := Color(0.85, 0.95, 1.0).lerp(Color(0.15, 0.35, 1.0), minf(k * 1.6, 1.0))
			# (dark-edged blue body + white-hot core, so it reads on snow and ice too)
			draw_circle(p, 8.0 + 28.0 * k, Color(col.darkened(0.3), 0.6 * (1.0 - k)))
			draw_circle(p, 3.0 + 12.0 * (1.0 - k), Color(1, 1, 1, 0.55 * (1.0 - k)))
	draw_hp_bar(-hit_radius - 44)
