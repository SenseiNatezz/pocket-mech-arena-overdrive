extends Node2D
## Bit Drones upgrade: small assistant drones - ducted quadcopters with a twin-barrel gun pod - that hover
## behind the mech's shoulders, turn to face the nearest robot in range and take turns firing at it
## (Upgrades.drone_count / drone_interval).
## STORM BITS combo (Bit Drones + Arc Emitter): every drone hit also arcs lightning to another robot
## (Mech.arc_from).
## Look (drawn in code, top-down, +x = the way the drone faces): four rotors in thin guard rings on an X
## frame, spinning blades with a motion-blur disc; a white armour shell with the Halo Forge's gold
## chevron, a dark glass sensor dome and an energy-coloured camera lens at the nose between the two gun
## barrels; red / green navigation lights blinking on the rear arms (port / starboard); a soft shadow on
## the ground below, which bobs with the hover. Firing: muzzle flashes, the body kicks back, the lens flares.

const RANGE := 540.0
const DAMAGE := 11.0
const SHOT_SPEED := 980.0
## Hover spots behind the mech (local to its aim), one per drone.
const SLOTS := [Vector2(-40, -58), Vector2(-40, 58), Vector2(-76, 0)]
## On-screen size of a drone (its local drawing is ~48 px across at 1.0).
const SCALE := 1.15
const ROTOR_R := 15.5
const DISC_R := 8.6
const GLOW := preload("res://assets/fx/glow.tres")
const WHITE := Color(0.93, 0.94, 0.96)
const GOLD := Color(1.0, 0.78, 0.28)
const METAL := Color(0.2, 0.22, 0.26)
## Light comes from the top-left of the screen (like the mech sprites).
const LIGHT := Vector2(-0.6, -0.8)

var mech: Mech
var _pos: Array[Vector2] = []
var _vel: Array[Vector2] = []
var _head: Array[float] = []
var _t := 0.0
var _next := 0
var _cd := 0.0
var _flash := [0.0, 0.0, 0.0]
var _kick := [0.0, 0.0, 0.0]


func _ready() -> void:
	z_index = 4
	top_level = true


func _physics_process(delta: float) -> void:
	var n := Upgrades.drone_count()
	visible = n > 0 and not mech.dead
	if not visible:
		_pos.clear()
		_vel.clear()
		_head.clear()
		return
	_t += delta
	var rot := mech.aim_dir.angle()
	for i in n:
		var want := mech.global_position + (SLOTS[i] as Vector2).rotated(rot) \
			+ Vector2(sin(_t * 1.3 + i * 2.0) * 4.0, sin(_t * 3.0 + i * 2.1) * 5.0)
		if i >= _pos.size():
			_pos.append(mech.global_position)
			_vel.append(Vector2.ZERO)
			_head.append(rot)
		var before := _pos[i]
		_pos[i] = _pos[i].lerp(want, 1.0 - exp(-10.0 * delta))
		_vel[i] = _vel[i].lerp((_pos[i] - before) / maxf(delta, 0.001), 1.0 - exp(-8.0 * delta))
		# Face the nearest robot in range (it's about to shoot it), otherwise where the mech aims.
		var face := rot
		var tgt := Combat.nearest_enemy(_pos[i], RANGE)
		if tgt:
			face = (tgt.global_position - _pos[i]).angle()
		_head[i] = rotate_toward(_head[i], face, 9.0 * delta)
		_flash[i] = maxf(_flash[i] - delta * 6.0, 0.0)
		_kick[i] = maxf(_kick[i] - delta * 9.0, 0.0)
	_cd -= delta
	if _cd <= 0.0:
		# The drones fire in turn, so with more of them the volleys come faster.
		_cd = Upgrades.drone_interval() / n
		_next = (_next + 1) % n
		var from := _pos[_next]
		var target := Combat.nearest_enemy(from, RANGE)
		if target:
			var dir := (target.global_position - from).normalized()
			# Alternate barrels.
			var side := Vector2.from_angle(_head[_next]).orthogonal() * (3.5 if int(_t * 10.0) % 2 == 0 else -3.5)
			var b := Combat.fire(from + dir * 17.0 + side, dir * SHOT_SPEED, DAMAGE * Upgrades.damage_mult(), true, mech,
				Game.energy_color().lightened(0.25), 0.5, 0.9)
			b.set_rifle_style()
			b.tag = &"bit"
			_flash[_next] = 1.0
			_kick[_next] = 1.0
			Sfx.play(&"drone_shot", -20.0, 0.12)
	queue_redraw()


func _draw() -> void:
	var col := Game.energy_color()
	for i in _pos.size():
		_draw_drone(i, col)


func _draw_drone(i: int, col: Color) -> void:
	var h: float = _head[i]
	var f: float = _flash[i]
	var bob := sin(_t * 3.0 + i * 2.1)
	var p: Vector2 = _pos[i] - Vector2.from_angle(h) * 3.0 * float(_kick[i])
	# Ground shadow: down-right of the drone, smaller and softer the higher it bobs.
	var sh := p + Vector2(10, 22) + Vector2(1, 1) * bob * 1.5
	draw_set_transform(sh, h, Vector2.ONE * SCALE * (0.92 - bob * 0.03))
	draw_texture_rect(GLOW, Rect2(-30, -30, 60, 60), false, Color(0, 0, 0, 0.34))
	draw_colored_polygon(_hull(1.0), Color(0, 0, 0, 0.16))
	# Banking: lean into the drift (a slight squash across the direction of travel).
	var drift: Vector2 = _vel[i].rotated(-h) / 400.0
	var lean := Vector2(1.0 - clampf(absf(drift.x), 0.0, 0.08), 1.0 - clampf(absf(drift.y), 0.0, 0.1))
	draw_set_transform(p, h, lean * SCALE)
	# Under-glow from the lift fans, in the energy colour.
	draw_texture_rect(GLOW, Rect2(-26, -26, 52, 52), false, Color(col, 0.16 + 0.22 * f))
	# Frame: four arms out to the rotors.
	for k in 4:
		var a := PI / 4 + k * PI / 2
		var tip := Vector2.from_angle(a) * ROTOR_R
		draw_line(Vector2.ZERO, tip, METAL, 4.6)
		draw_line(Vector2.ZERO, tip, METAL.lightened(0.28), 1.4)
	# Rotors: guard ring, blurred disc, two blades, motor hub.
	for k in 4:
		var a := PI / 4 + k * PI / 2
		var c := Vector2.from_angle(a) * ROTOR_R
		draw_circle(c, DISC_R, Color(0.75, 0.82, 0.92, 0.14))
		var spin := _t * (52.0 + k * 3.0) * (1.0 if k % 2 == 0 else -1.0)
		for b in 2:
			var ba := spin + b * PI
			# Blur trail behind each blade, then the blade itself.
			draw_arc(c, DISC_R * 0.7, ba - 0.9 * (1.0 if k % 2 == 0 else -1.0), ba, 6, Color(0.85, 0.9, 1.0, 0.18), DISC_R * 0.55)
			draw_line(c, c + Vector2.from_angle(ba) * (DISC_R - 0.8), Color(0.12, 0.13, 0.16, 0.85), 1.8)
		draw_arc(c, DISC_R + 0.6, 0, TAU, 20, METAL.lightened(0.15), 1.6, true)
		draw_arc(c, DISC_R + 0.6, a - 2.4, a - 1.0, 8, Color(1, 1, 1, 0.35), 1.0, true)
		draw_circle(c, 2.6, METAL.darkened(0.3))
		draw_circle(c - Vector2(0.7, 0.7).rotated(-h), 1.1, Color(0.65, 0.7, 0.78))
	# Gun pod: twin barrels under the nose.
	for s in [-1.0, 1.0]:
		draw_line(Vector2(5, 3.6 * s), Vector2(17.5, 3.6 * s), METAL.darkened(0.35), 2.6)
		draw_line(Vector2(6, 3.6 * s - 0.6), Vector2(17.0, 3.6 * s - 0.6), METAL.lightened(0.35), 0.8)
		draw_rect(Rect2(15.5, 3.6 * s - 1.8, 2.6, 3.6), METAL.lightened(0.1))
	# Armour shell, lit from the top-left of the screen.
	var hull := _hull(1.0)
	var cols := PackedColorArray()
	var lit := LIGHT.rotated(-h)
	for v in hull:
		var k := clampf(0.5 + 0.5 * v.normalized().dot(lit), 0.0, 1.0)
		cols.append(WHITE.darkened(0.42).lerp(WHITE.lightened(0.4), k))
	draw_polygon(hull, cols)
	draw_polyline(_closed(hull), Color(0.32, 0.36, 0.44, 0.9), 1.0, true)
	# Gold chevron along the spine, panel line, rear vent.
	draw_colored_polygon(PackedVector2Array([Vector2(9.5, 0), Vector2(3.0, 5.0), Vector2(0.5, 5.0), Vector2(6.0, 0),
		Vector2(0.5, -5.0), Vector2(3.0, -5.0)]), GOLD)
	draw_line(Vector2(-4.5, -5.5), Vector2(-4.5, 5.5), Color(0.4, 0.44, 0.52, 0.8), 0.8)
	draw_rect(Rect2(-10.5, -2.5, 2.2, 5.0), METAL)
	# Sensor dome (dark glass + highlight).
	draw_circle(Vector2(-1.5, 0), 3.6, Color(0.08, 0.1, 0.16))
	draw_circle(Vector2(-1.5, 0) + Vector2(-1.1, -1.1).rotated(-h), 1.2, Color(0.75, 0.85, 1.0, 0.8))
	# Camera lens at the nose in the energy colour (flares when it fires).
	draw_texture_rect(GLOW, Rect2(Vector2(11, 0) - Vector2.ONE * (5.0 + 6.0 * f), Vector2.ONE * (10.0 + 12.0 * f)), false,
		Color(col, 0.7))
	draw_circle(Vector2(11, 0), 1.9, col.lightened(0.55))
	# Navigation lights on the rear arms: port red, starboard green, blinking.
	var blink := fmod(_t + i * 0.37, 1.1) < 0.18
	var nav := 0.9 if blink else 0.35
	var port := Vector2.from_angle(PI * 1.25) * (ROTOR_R - DISC_R - 1.5)
	var star := Vector2.from_angle(PI * 0.75) * (ROTOR_R - DISC_R - 1.5)
	draw_circle(port, 1.4, Color(1.0, 0.25, 0.2, nav))
	draw_circle(star, 1.4, Color(0.3, 1.0, 0.4, nav))
	if blink:
		draw_texture_rect(GLOW, Rect2(port - Vector2(4, 4), Vector2(8, 8)), false, Color(1.0, 0.3, 0.2, 0.5))
		draw_texture_rect(GLOW, Rect2(star - Vector2(4, 4), Vector2(8, 8)), false, Color(0.3, 1.0, 0.4, 0.5))
	# Muzzle flashes at both barrel tips.
	if f > 0.05:
		for s in [-1.0, 1.0]:
			var m := Vector2(19.0, 3.6 * s)
			draw_texture_rect(GLOW, Rect2(m - Vector2.ONE * 9.0 * f, Vector2.ONE * 18.0 * f), false, Color(col, 0.9 * f))
			draw_colored_polygon(PackedVector2Array([m + Vector2(9.0 * f, 0), m + Vector2(0, 2.2 * f), m + Vector2(-1.5, 0),
				m + Vector2(0, -2.2 * f)]), Color(1, 1, 1, f))
	draw_set_transform(Vector2.ZERO)


## The armour shell outline (local, +x forward), grown by `k`.
func _hull(k: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(12, 0), Vector2(8, 6.5), Vector2(-3, 8.2), Vector2(-9.5, 6), Vector2(-12, 0),
		Vector2(-9.5, -6), Vector2(-3, -8.2), Vector2(8, -6.5)])
	for j in pts.size():
		pts[j] *= k
	return pts


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out
