class_name VoidSkimmer
extends Enemy
## "Void Skimmer" (Higgsfield sprite, Orbital Dry Dock): an arrowhead assault craft with a blink drive.
## It hovers at mid range plinking at you, then BLINKS: a violet ring opens where it will reappear (beside
## or behind you), it vanishes, comes out of the ring and fires a quick three-shot burst. Watch the ring.

const TEX := preload("res://assets/hq/enemies6/void_skimmer.png")
const SPRITE_SCALE := 0.38
const VIOLET := Color(0.8, 0.35, 1.0)
const HOVER_R := 360.0
const BLINK_WARN := 0.55
const BLINK_DIST := 250.0

@export var shot_damage := 6.0

enum State { HOVER, BLINK, BURST }

var _state := State.HOVER
var _st := 1.8
var _dest := Vector2.ZERO
var _shots := 0
var _shot_t := 0.0
var _spin := 1.0
var _fade := 1.0


func _ready() -> void:
	super._ready()
	_st = randf_range(1.4, 2.4)
	_spin = [-1.0, 1.0].pick_random()


func _think(delta: float) -> void:
	_st -= delta
	var d := dist_to_target()
	var to_t := dir_to_target()
	match _state:
		State.HOVER:
			_fade = move_toward(_fade, 1.0, delta * 4.0)
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 6.0 * delta))
			if not has_line_of_sight(target.global_position):
				steer_to(target.global_position)
			else:
				var radial := to_t * clampf((d - HOVER_R) / 150.0, -1.0, 1.0)
				desired_velocity = (to_t.orthogonal() * _spin * 0.6 + radial).normalized() * move_speed
			_shot_t -= delta
			if _shot_t <= 0.0 and has_line_of_sight(target.global_position):
				_shot_t = 1.1
				shoot(to_t, 360.0, shot_damage * 0.6, VIOLET, 1.0)
			if _st <= 0.0:
				var dest := _pick_dest()
				if dest != Vector2.INF:
					_dest = dest
					_state = State.BLINK
					_st = BLINK_WARN
					Sfx.play(&"charge", -14.0, 0.5)
				else:
					_st = 0.6
		State.BLINK:
			desired_velocity = Vector2.ZERO
			_fade = _st / BLINK_WARN
			if _st <= 0.0:
				Combat.shockwave(global_position, 60.0, VIOLET, 0.25)
				global_position = _dest
				Combat.shockwave(_dest, 80.0, VIOLET, 0.3)
				Sfx.play(&"dash", -10.0, 0.4)
				_fade = 1.0
				_state = State.BURST
				_shots = 3
				_shot_t = 0.18
				facing = dir_to_target()
		State.BURST:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 10.0 * delta))
			_shot_t -= delta
			if _shot_t <= 0.0 and _shots > 0:
				_shots -= 1
				_shot_t = 0.13
				shoot(facing, 470.0, shot_damage, VIOLET, 1.1)
				Sfx.play(&"enemy_shoot", -10.0, 0.2)
			if _shots <= 0 and _shot_t <= 0.0:
				_state = State.HOVER
				_st = randf_range(2.6, 3.4)


## A spot BLINK_DIST from the mech (to its side or behind) that it can see and nothing blocks; INF if none.
func _pick_dest() -> Vector2:
	var tp := target.global_position
	var base := (global_position - tp).angle()
	var space := get_world_2d().direct_space_state
	for k in 6:
		var a := base + PI * 0.5 * _spin + randf_range(-0.6, 0.6) + (PI if k >= 3 else 0.0)
		var p := tp + Vector2.from_angle(a) * BLINK_DIST
		var q := PhysicsRayQueryParameters2D.create(tp, p + (p - tp).normalized() * hit_radius, 1 | 32)
		if space.intersect_ray(q).is_empty():
			return p
	return Vector2.INF


func _draw() -> void:
	if _state == State.BLINK:
		var at := _dest - global_position
		var k := 1.0 - _st / BLINK_WARN
		draw_circle(at, 34.0 * k, Color(VIOLET, 0.25))
		draw_arc(at, 40.0, 0, TAU, 28, Color(VIOLET, 0.9), 2.5, true)
		draw_arc(at, 40.0 + 30.0 * (1.0 - k), 0, TAU, 28, Color(VIOLET, 0.5 * k), 2.0, true)
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	draw_set_transform(Vector2(12, 20), rot, Vector2.ONE * SPRITE_SCALE * 0.95)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.3 * _fade))
	draw_set_transform(Vector2.ZERO, rot, Vector2.ONE * SPRITE_SCALE * (0.6 + 0.4 * _fade))
	draw_texture(TEX, -half, tint(Color(1, 1, 1, _fade)))
	draw_set_transform(Vector2.ZERO)
	draw_hp_bar(-hit_radius - 22)
