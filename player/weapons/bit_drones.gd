extends Node2D
## Bit Drones upgrade: small remote gun-bits that hover behind the mech's shoulders and take turns
## firing at the nearest robot in range (Upgrades.drone_count / drone_interval).
## STORM BITS combo (Bit Drones + Arc Emitter): every drone hit also arcs lightning to another robot
## (Mech.arc_from).

const RANGE := 540.0
const DAMAGE := 11.0
const SHOT_SPEED := 900.0
## Hover spots behind the mech (local to its aim), one per drone.
const SLOTS := [Vector2(-38, -54), Vector2(-38, 54), Vector2(-72, 0)]

var mech: Mech
var _pos: Array[Vector2] = []
var _t := 0.0
var _next := 0
var _cd := 0.0
var _flash := [0.0, 0.0, 0.0]


func _ready() -> void:
	z_index = 4
	top_level = true


func _physics_process(delta: float) -> void:
	var n := Upgrades.drone_count()
	visible = n > 0 and not mech.dead
	if not visible:
		_pos.clear()
		return
	_t += delta
	var rot := mech.aim_dir.angle()
	for i in n:
		var want := mech.global_position + (SLOTS[i] as Vector2).rotated(rot) \
			+ Vector2(0, sin(_t * 3.0 + i * 2.1) * 5.0)
		if i >= _pos.size():
			_pos.append(mech.global_position)
		_pos[i] = _pos[i].lerp(want, 1.0 - exp(-10.0 * delta))
		_flash[i] = maxf(_flash[i] - delta * 5.0, 0.0)
	_cd -= delta
	if _cd <= 0.0:
		# The drones fire in turn, so with more of them the volleys come faster.
		_cd = Upgrades.drone_interval() / n
		_next = (_next + 1) % n
		var from := _pos[_next]
		var target := Combat.nearest_enemy(from, RANGE)
		if target:
			var dir := (target.global_position - from).normalized()
			var b := Combat.fire(from + dir * 10.0, dir * SHOT_SPEED, DAMAGE * Upgrades.damage_mult(), true, mech,
				Game.energy_color().lightened(0.35), 0.7, 0.9)
			b.tag = &"bit"
			_flash[_next] = 1.0
			Sfx.play(&"shoot", -24.0, 0.15)
	queue_redraw()


func _draw() -> void:
	var col := Game.energy_color()
	var rot := mech.aim_dir.angle()
	for i in _pos.size():
		var p := _pos[i]
		var f: float = _flash[i]
		draw_circle(p, 19.0 + f * 6.0, Color(col, 0.16 + 0.25 * f))
		# A small armored bit: a dark kite with a glowing eye, pointing where the mech aims.
		var fwd := Vector2.from_angle(rot)
		var side := fwd.orthogonal()
		var kite := PackedVector2Array([p + fwd * 17.0, p + side * 9.0, p - fwd * 10.0, p - side * 9.0])
		draw_colored_polygon(kite, Color(0.2, 0.25, 0.34))
		draw_polyline(PackedVector2Array([kite[0], kite[1], kite[2], kite[3], kite[0]]), Color(col.lightened(0.2), 1.0), 2.0, true)
		draw_line(p - fwd * 10.0, p - fwd * 16.0, Color(col, 0.6 + 0.4 * f), 3.0)
		draw_circle(p + fwd * 4.0, 3.5 + f * 2.0, col.lightened(0.6))
