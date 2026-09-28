class_name Bastion
extends Enemy
## "Bastion" (Higgsfield sprite, Endless mode): shield commander. Hangs back behind the other robots and
## projects a hard-light ward onto every ally within WARD_RANGE (green tether + bubble): warded robots
## take half damage (Enemy.ward_t). Its own big shield blocks most of anything that hits it from the
## front, so flank it or use area attacks. Take it out first and the ward drops. When it has a clear
## shot it fires slow triple bolts. Bosses are never warded.

const TEX := preload("res://assets/hq/enemies4/bastion.png")
const SPRITE_SCALE := 0.62
const WARD := Color(0.3, 1.0, 0.6)
const WARD_RANGE := 320.0
## Frontal shield: hits within BLOCK_ARC of its facing only do (1 - FRONT_BLOCK) damage.
const FRONT_BLOCK := 0.75
const BLOCK_ARC := 1.1

var _warded: Array[Enemy] = []
var _ward_t := 0.0
var _bolt_cd := 2.0
var _block_flash := 0.0
var _strafe := 1.0


func _ready() -> void:
	super._ready()
	_strafe = [-1.0, 1.0].pick_random()


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	var off := from_pos - global_position
	if not dead and off.length() > 4.0 and absf(facing.angle_to(off)) < BLOCK_ARC:
		amount *= 1.0 - FRONT_BLOCK
		_block_flash = 1.0
		Combat.spark(global_position + off.normalized() * hit_radius * 1.4, WARD, 0.8)
		Sfx.play(&"hit", -16.0, 0.3)
	super.take_damage(amount, from_pos, source)


func _think(delta: float) -> void:
	_ward_t -= delta
	_bolt_cd -= delta
	_block_flash = move_toward(_block_flash, 0.0, delta * 4.0)
	var to_t := dir_to_target()
	var d := dist_to_target()
	facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 1.8 * delta))
	# Keep 380-480 px away: back off when rushed, close in when far, otherwise edge sideways.
	if d < 340.0:
		steer_to(global_position - to_t * 200.0)
	elif d > 480.0:
		steer_to(target.global_position)
	else:
		desired_velocity = to_t.orthogonal() * _strafe * move_speed * 0.5
		if is_on_wall():
			_strafe = -_strafe
	if _ward_t <= 0.0:
		_ward_t = 0.25
		_warded.clear()
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and e != self and not e.dead and not (e is WardenBoss) \
					and global_position.distance_to(e.global_position) < WARD_RANGE:
				e.ward_t = 0.5
				_warded.append(e)
	if _bolt_cd <= 0.0 and d < 700.0 and has_line_of_sight(target.global_position):
		_bolt_cd = 3.0
		for i in 3:
			shoot(to_t.rotated((i - 1) * 0.22), 240.0, 9.0, WARD, 1.5)
		Sfx.play(&"enemy_shoot", -8.0)


func _draw() -> void:
	# Ward tethers + bubbles on the allies it protects (under its own sprite).
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	for e in _warded:
		if not is_instance_valid(e) or e.dead:
			continue
		var p := to_local(e.global_position)
		draw_line(Vector2.ZERO, p, Color(WARD, 0.15 + 0.15 * pulse), 2.0, true)
		draw_arc(p, e.hit_radius * 1.6, 0.0, TAU, 28, Color(WARD, 0.35 + 0.25 * pulse), 2.5, true)
		draw_circle(p, e.hit_radius * 1.6, Color(WARD, 0.05))
	draw_arc(Vector2.ZERO, WARD_RANGE, 0.0, TAU, 64, Color(WARD, 0.06 + 0.04 * pulse), 2.0, true)
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var s := Vector2.ONE * SPRITE_SCALE
	draw_set_transform(Vector2(8, 12), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.42))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, tint(Color.WHITE))
	draw_set_transform(Vector2.ZERO)
	var a := facing.angle()
	draw_arc(Vector2.ZERO, hit_radius * 2.0, a - BLOCK_ARC * 0.8, a + BLOCK_ARC * 0.8, 20,
		Color(WARD, 0.15 + 0.5 * _block_flash), 5.0 + 6.0 * _block_flash, true)
	draw_hp_bar(-hit_radius - 62)
