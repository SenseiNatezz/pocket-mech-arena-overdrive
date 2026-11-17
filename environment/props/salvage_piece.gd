extends Node2D
## SALVAGE PIECE (autoload/salvage.gd): a chunk of a destroyed robot - an arm, a leg, a sensor head or a
## thruster pack, painted in that robot's colour with a ring in its slot colour. It bounces out of the wreck (a
## melee kill TEARS it off: it flies out harder with a flash), lies there glowing, and after WAIT seconds it comes
## to the mech by itself (no pickup chore). Touching it bolts it on (Salvage.collect). All drawn in code.

const COLLECT_RANGE := 44.0
const WAIT := 3.5
const SIZE := 1.45

## The PIECES entry (+ "from").
var piece := {}
var tint := Color(0.7, 0.45, 0.3)
## Ripped off by a melee kill: a harder pop and a flash.
var torn := false
var _t := 0.0
var _pop := Vector2.ZERO
var _z := 0.0
var _vz := 360.0
var _speed := 0.0
var _spin := 0.0
var _done := false


func _ready() -> void:
	add_to_group("salvage_pieces")
	z_index = 1
	var power := 1.6 if torn else 1.0
	_pop = Vector2.from_angle(randf() * TAU) * randf_range(90.0, 160.0) * power
	_vz *= power
	_spin = randf_range(-9.0, 9.0) * power
	if torn:
		Combat.spark(global_position, _ring(), 1.6)
		Combat.shockwave(global_position, 60.0, _ring(), 0.25)
		Sfx.play(&"slam", -12.0, 0.15)


func _ring() -> Color:
	return Salvage.SLOT_COLORS.get(piece.get("slot", &"arms"), Color.WHITE)


func _process(delta: float) -> void:
	_t += delta
	# Bounce out of the wreck.
	position += _pop * delta
	_pop = _pop.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
	if _z > 0.0 or _vz > 0.0:
		_vz -= 1500.0 * delta
		_z = maxf(_z + _vz * delta, 0.0)
		if _z <= 0.0:
			_vz = -_vz * 0.35 if absf(_vz) > 120.0 else 0.0
		rotation += _spin * delta
	else:
		rotation = lerp_angle(rotation, 0.0, 1.0 - exp(-6.0 * delta))
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech and not mech.dead and _t > 0.3:
		var d := global_position.distance_to(mech.global_position)
		if d < COLLECT_RANGE + mech.hit_radius * 0.5:
			_collect(mech)
			return
		if _t > WAIT:
			_speed = minf(_speed + delta * 1600.0, 1300.0)
			global_position = global_position.move_toward(mech.global_position, _speed * delta)
	queue_redraw()


func _collect(mech: Mech) -> void:
	if _done:
		return
	_done = true
	Salvage.collect(piece)
	Combat.shockwave(mech.global_position, 70.0, _ring(), 0.3)
	Combat.spark(mech.global_position, _ring(), 1.2)
	Sfx.play(&"pickup", -6.0, 0.05)
	queue_free()


func _draw() -> void:
	var col := _ring()
	var lift := Vector2(0, -_z * 0.25 - (sin(_t * 4.0) * 2.0 if _z <= 0.0 else 0.0))
	# Shadow + slot-coloured glow ring on the floor.
	draw_set_transform(Vector2.ZERO, -rotation, Vector2.ONE)
	draw_circle(Vector2(0, 9), 13.0, Color(0, 0, 0, 0.3))
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_arc(Vector2(0, 6), 20.0 + pulse * 3.0, 0, TAU, 28, Color(col, 0.35 + 0.3 * pulse), 2.0, true)
	draw_set_transform(lift.rotated(-rotation), 0.0, Vector2.ONE * SIZE)
	var dark := tint.darkened(0.55)
	var lit := tint.lightened(0.25)
	match piece.get("slot", &"arms"):
		&"arms":
			# A forearm: plated tube + a three-finger fist / barrel end, torn wires at the stump.
			draw_rect(Rect2(-14, -5, 20, 10), tint)
			draw_rect(Rect2(-14, -5, 20, 3), lit)
			draw_rect(Rect2(6, -7, 9, 14), dark)
			for i in 3:
				draw_rect(Rect2(15, -6 + i * 4.5, 4, 3), tint)
			draw_line(Vector2(-14, -2), Vector2(-19, -5), Color(1, 0.8, 0.2), 1.5)
			draw_line(Vector2(-14, 2), Vector2(-19, 4), Color(1, 0.4, 0.2), 1.5)
		&"legs":
			# A leg: thigh, knee joint, shin and a foot.
			draw_rect(Rect2(-5, -15, 10, 12), tint)
			draw_circle(Vector2(0, -2), 5.0, dark)
			draw_rect(Rect2(-4, 1, 8, 11), lit)
			draw_rect(Rect2(-8, 11, 16, 5), dark)
			draw_line(Vector2(-3, -15), Vector2(-6, -20), Color(1, 0.8, 0.2), 1.5)
		&"head":
			# A sensor head: helmet, visor and an antenna.
			draw_circle(Vector2.ZERO, 10.0, tint)
			draw_rect(Rect2(-10, -1, 20, 9), dark)
			draw_rect(Rect2(-7, -3, 14, 4), col.lightened(0.3))
			draw_line(Vector2(4, -9), Vector2(9, -18), lit, 2.0)
		_:
			# A thruster pack: box with two nozzles.
			draw_rect(Rect2(-11, -10, 22, 16), tint)
			draw_rect(Rect2(-11, -10, 22, 4), lit)
			draw_rect(Rect2(-9, 6, 7, 6), dark)
			draw_rect(Rect2(2, 6, 7, 6), dark)
			draw_circle(Vector2(-5.5, 13), 2.5, Color(col, 0.8))
			draw_circle(Vector2(5.5, 13), 2.5, Color(col, 0.8))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
