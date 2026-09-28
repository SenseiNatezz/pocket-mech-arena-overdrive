class_name Widow
extends Enemy
## "Widow" (Higgsfield sprite, Endless mode): spider mine-layer. Keeps its distance, skitters from spot
## to spot around you and drops a proximity mine every few seconds (up to MAX_MINES at once). A mine
## arms after a moment, blinks fast when you step close, then blows. Mines can be shot (or caught in
## any blast) to clear them, and they fizzle out on their own after a while.

const TEX := preload("res://assets/hq/enemies4/widow.png")
const SPRITE_SCALE := 0.62
const ACID := Color(0.6, 1.0, 0.15)
const MAX_MINES := 4

@export var mine_damage := 22.0

var mines_laid := 0
var _mines: Array[Node2D] = []
var _mine_cd := 1.5
var _spot := Vector2.INF
var _spot_t := 0.0
var _lay := 0.0


func _think(delta: float) -> void:
	_mine_cd -= delta
	_spot_t -= delta
	_lay = move_toward(_lay, 0.0, delta * 3.0)
	var to_t := dir_to_target()
	var d := dist_to_target()
	# Pick a new spot on a ring 260-420 px around the player every so often (or when it gets close).
	if _spot == Vector2.INF or _spot_t <= 0.0 or global_position.distance_to(_spot) < 30.0 or d < 180.0:
		_spot_t = randf_range(1.6, 2.6)
		var a := (global_position - target.global_position).angle() + randf_range(-1.3, 1.3)
		_spot = target.global_position + Vector2.from_angle(a) * randf_range(260.0, 420.0)
	steer_to(_spot)
	facing = velocity.normalized() if velocity.length() > 30.0 else to_t
	# (mines free themselves when they blow, get shot or fizzle)
	for i in range(_mines.size() - 1, -1, -1):
		if not is_instance_valid(_mines[i]):
			_mines.remove_at(i)
	if _mine_cd <= 0.0 and _mines.size() < MAX_MINES:
		_mine_cd = randf_range(2.6, 3.6)
		_drop_mine()


func _drop_mine() -> void:
	var m := Mine.new()
	m.damage = mine_damage * damage_mult
	m.source = self
	m.global_position = global_position - facing * hit_radius
	Combat.world().add_child(m)
	_mines.append(m)
	mines_laid += 1
	_lay = 1.0
	Sfx.play(&"select", -14.0, 0.2)


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var moving := velocity.length() > 30.0
	var gait := sin(_t * 24.0) * 0.04 if moving else 0.0
	var s := Vector2(SPRITE_SCALE * (1.0 + gait), SPRITE_SCALE * (1.0 - gait))
	draw_set_transform(Vector2(6, 9), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, tint(Color.WHITE))
	draw_set_transform(Vector2.ZERO)
	if _lay > 0.0:
		draw_circle(-facing * hit_radius, 10.0 * _lay + 4.0, Color(ACID, 0.4 * _lay))
	draw_hp_bar(-hit_radius - 22)


## Proximity mine (shootable): arms after ARM_TIME, blinks for FUSE seconds once the player is within
## TRIGGER px, then explodes (hurts the player). Fizzles after LIFETIME.
class Mine:
	extends Area2D
	const ARM_TIME := 0.9
	const TRIGGER := 80.0
	const FUSE := 0.45
	const RADIUS := 95.0
	const LIFETIME := 16.0
	var damage := 20.0
	var source: Node = null
	var hit_radius := 14.0
	var _t := 0.0
	var _fuse := -1.0
	var _gone := false

	func _ready() -> void:
		add_to_group("damageable")
		collision_layer = 4  # player shots hit it like an enemy
		collision_mask = 0
		monitoring = false
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = hit_radius
		cs.shape = c
		add_child(cs)
		z_index = -1

	func _process(delta: float) -> void:
		_t += delta
		if _t > LIFETIME:
			_fizzle()
			return
		if _fuse >= 0.0:
			_fuse -= delta
			if _fuse <= 0.0:
				_blow()
				return
		elif _t > ARM_TIME:
			var p := get_tree().get_first_node_in_group("player") as Node2D
			if p and global_position.distance_to(p.global_position) < TRIGGER:
				_fuse = FUSE
				Sfx.play(&"alarm", -14.0, 0.1)
		queue_redraw()

	func take_damage(_amount: float, _from: Vector2, _src: Node = null) -> void:
		# Shot or caught in a blast: pops harmlessly (a small flash, no damage).
		if _gone:
			return
		_gone = true
		Combat.spark(global_position, Color(0.6, 1.0, 0.15), 1.2)
		Combat.shockwave(global_position, 40.0, Color(0.6, 1.0, 0.15), 0.25)
		Sfx.play(&"hit", -10.0, 0.2)
		queue_free()

	func _blow() -> void:
		if _gone:
			return
		_gone = true
		Combat.explode(global_position, RADIUS, damage, source if is_instance_valid(source) else null, "player", Color(0.6, 1.0, 0.2), 300.0)
		queue_free()

	func _fizzle() -> void:
		_gone = true
		Combat.spark(global_position, Color(0.5, 0.6, 0.5), 0.6)
		queue_free()

	func _draw() -> void:
		var armed := _t > ARM_TIME
		var blink := 0.5 + 0.5 * sin(_t * (40.0 if _fuse >= 0.0 else 5.0))
		if _fuse >= 0.0:
			draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.3, 0.2, 0.1 + 0.12 * blink))
			draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, Color(1.0, 0.4, 0.2, 0.7), 2.0, true)
		draw_circle(Vector2(2, 3), 12.0, Color(0, 0, 0, 0.4))
		draw_circle(Vector2.ZERO, 12.0, Color(0.08, 0.1, 0.08))
		draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(0.6, 1.0, 0.15, 0.7), 2.0, true)
		for i in 4:
			var a := TAU * i / 4.0 + PI / 4.0
			draw_line(Vector2.from_angle(a) * 12.0, Vector2.from_angle(a) * 17.0, Color(0.2, 0.25, 0.2), 3.0)
		var core := Color(1.0, 0.25, 0.2) if _fuse >= 0.0 else Color(0.6, 1.0, 0.15)
		draw_circle(Vector2.ZERO, 5.0, Color(core, (0.35 + 0.65 * blink) if armed else 0.25))
