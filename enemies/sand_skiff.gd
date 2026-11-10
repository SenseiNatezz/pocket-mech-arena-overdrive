class_name SandSkiff
extends Enemy
## "Sand Skiff" (Higgsfield sprite, Titan Graveyard): a fast desert raider on a hover-skiff. It circles
## you at range firing twin bursts from its turret, and every few seconds lines up a RAM: a danger lane
## shows the line, then it boosts straight down it, kicking up a sand wake. Step out of the lane.

const TEX := preload("res://assets/hq/enemies6/sand_skiff.png")
const SPRITE_SCALE := 0.36
const TURQ := Color(0.3, 1.0, 0.85)
const SAND := Color(0.95, 0.76, 0.46)
const ORBIT_R := 330.0
const AIM_TIME := 0.6
const RAM_SPEED := 760.0
const RAM_TIME := 0.55
const RAM_LEN := RAM_SPEED * RAM_TIME

@export var ram_damage := 12.0
@export var shot_damage := 6.0

enum State { ORBIT, AIM, RAM, COOL }

var _state := State.ORBIT
var _st := 0.0
var _ram_cd := 3.0
var _shot_t := 1.0
var _spin := 1.0
var _ram_dir := Vector2.RIGHT
var _hit := false
var _wake_t := 0.0


func _ready() -> void:
	super._ready()
	_spin = [-1.0, 1.0].pick_random()
	_ram_cd = randf_range(2.5, 4.0)


func _think(delta: float) -> void:
	_st -= delta
	_ram_cd -= delta
	var to_t := dir_to_target()
	var d := dist_to_target()
	match _state:
		State.ORBIT:
			if not has_line_of_sight(target.global_position):
				steer_to(target.global_position)
			else:
				var tangent := to_t.orthogonal() * _spin
				var radial := to_t * clampf((d - ORBIT_R) / 120.0, -1.0, 1.0)
				desired_velocity = (tangent + radial).normalized() * move_speed
			if get_slide_collision_count() > 0:
				_spin = -_spin
			if velocity.length() > 30.0:
				facing = Vector2.from_angle(rotate_toward(facing.angle(), velocity.angle(), 7.0 * delta))
			_shot_t -= delta
			if _shot_t <= 0.0 and d < 620.0 and has_line_of_sight(target.global_position):
				_shot_t = 1.5
				var lead := (target.global_position + target.velocity * 0.25 - global_position).normalized()
				for i in 2:
					shoot(lead.rotated((i - 0.5) * 0.08), 430.0, shot_damage)
				Sfx.play(&"enemy_shoot", -9.0, 0.15)
			if _ram_cd <= 0.0 and d < 640.0 and has_line_of_sight(target.global_position):
				_state = State.AIM
				_st = AIM_TIME
				Sfx.play(&"charge", -12.0, 0.2)
		State.AIM:
			desired_velocity = -to_t * 40.0
			_ram_dir = (target.global_position + target.velocity * 0.2 - global_position).normalized()
			facing = Vector2.from_angle(rotate_toward(facing.angle(), _ram_dir.angle(), 12.0 * delta))
			if _st <= 0.0:
				_ram_dir = facing
				_state = State.RAM
				_st = RAM_TIME
				_hit = false
				Sfx.play(&"dash", -6.0, 0.15)
		State.RAM:
			desired_velocity = _ram_dir * RAM_SPEED
			velocity = desired_velocity
			_wake_t -= delta
			if _wake_t <= 0.0:
				_wake_t = 0.04
				Combat.spark(global_position - _ram_dir * 30.0, SAND, 1.0)
			if not _hit and d < hit_radius + 34.0:
				_hit = true
				target.take_damage(ram_damage * damage_mult, global_position, self)
				Combat.spark(target.global_position, SAND, 1.4)
			if _st <= 0.0 or get_slide_collision_count() > 0:
				_state = State.COOL
				_st = 0.5
		State.COOL:
			if _st <= 0.0:
				_state = State.ORBIT
				_ram_cd = randf_range(3.5, 5.0)


func _draw() -> void:
	if _state == State.AIM:
		var k := 1.0 - _st / AIM_TIME
		DangerLane.draw(self, facing * (hit_radius + 6.0), facing * RAM_LEN, hit_radius + 6.0, k, _t, Color(1.0, 0.45, 0.2))
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var bob := sin(_t * 6.0) * 2.0
	draw_set_transform(Vector2(10, 16), rot, Vector2.ONE * SPRITE_SCALE)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2(0, bob), rot, Vector2.ONE * SPRITE_SCALE)
	draw_texture(TEX, -half, tint(Color.WHITE))
	draw_set_transform(Vector2.ZERO)
	# Thruster glow (hotter on a ram).
	var hot := 1.0 if _state == State.RAM else 0.0
	for side: float in [-1.0, 1.0]:
		var p := (facing * -18.0 + facing.orthogonal() * side * 46.0) + Vector2(0, bob)
		draw_circle(p, 9.0 + 6.0 * hot, Color(TURQ, 0.35 + 0.35 * hot))
	draw_hp_bar(-hit_radius - 22)
