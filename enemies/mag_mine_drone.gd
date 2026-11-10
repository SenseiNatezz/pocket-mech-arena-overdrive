class_name MagMineDrone
extends Enemy
## "Mag Mine Drone" (Higgsfield sprite, Orbital Dry Dock): a small floating mine-layer. It hangs back,
## drifts sideways across your path and seeds the deck with magnetic mines (enemies/mag_mine.gd: they
## arm, then blow when you come close). It also snaps off a slow shot now and then. Kill it before the
## deck fills up.

const TEX := preload("res://assets/hq/enemies6/mag_mine_drone.png")
const SPRITE_SCALE := 0.34
const VIOLET := Color(0.8, 0.35, 1.0)
const KEEP_MIN := 260.0
const KEEP_MAX := 460.0
const DROP_EVERY := 2.4
const MAX_MINES := 4

@export var mine_damage := 15.0

var _drop_t := 1.2
var _shot_t := 2.0
var _drift := 1.0
var _mines: Array[MagMine] = []


func _ready() -> void:
	super._ready()
	_drift = [-1.0, 1.0].pick_random()
	_drop_t = randf_range(0.8, 1.8)


func _think(delta: float) -> void:
	var d := dist_to_target()
	var to_t := dir_to_target()
	facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 3.0 * delta))
	if not has_line_of_sight(target.global_position) or d > KEEP_MAX:
		steer_to(target.global_position)
	else:
		var radial := to_t * (1.0 if d > KEEP_MAX - 60.0 else (-1.0 if d < KEEP_MIN else 0.0))
		desired_velocity = (to_t.orthogonal() * _drift + radial).normalized() * move_speed
	if get_slide_collision_count() > 0:
		_drift = -_drift
	_drop_t -= delta
	if _drop_t <= 0.0:
		_drop_t = DROP_EVERY
		var live: Array[MagMine] = []
		for m in _mines:
			if is_instance_valid(m):
				live.append(m)
		_mines = live
		if _mines.size() < MAX_MINES:
			_mines.append(MagMine.drop(global_position, mine_damage * damage_mult, self))
			Sfx.play(&"select", -14.0, 0.2)
	_shot_t -= delta
	if _shot_t <= 0.0 and d < 600.0 and has_line_of_sight(target.global_position):
		_shot_t = randf_range(2.2, 3.0)
		shoot(to_t, 300.0, 7.0, VIOLET, 1.2)
		Sfx.play(&"enemy_shoot", -12.0, 0.2)


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var bob := sin(_t * 4.0) * 3.0
	draw_set_transform(Vector2(12, 22), rot, Vector2.ONE * SPRITE_SCALE * 0.9)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, bob), rot, Vector2.ONE * SPRITE_SCALE)
	draw_texture(TEX, -half, tint(Color.WHITE))
	draw_set_transform(Vector2.ZERO)
	var pulse := 0.5 + 0.5 * sin(_t * 6.0)
	draw_circle(Vector2(0, bob), 8.0 + 4.0 * pulse, Color(VIOLET, 0.25 + 0.2 * pulse))
	draw_hp_bar(-hit_radius - 20)
