class_name EnergySwordFx
extends RefCounted
## Energy Sword effects, drawn like 2D cel animation (flat colour layers with a dark ink edge):
##   draw_blade   the plasma blade itself (the hilt is the Higgsfield art): flared at the guard, straight
##                edges, an angled taper to a sharp point; ink rim, pink, pale pink, white-hot core, with a
##                stepped flicker
##   draw_glow    while equipped (additive): a breathing pointed halo, energy crackling along the blade,
##                and a twinkle at the tip
##   CelSmear     the slash smear: a crescent that follows the real blade tip (melee_rig's trail samples),
##                thick and white-hot where the blade is now, tapering to a thin pink tail, plus speed lines
##   CrossFlash   hit flash: a white pop, then a crossed slash flash with a ring, then a fading ring
##                (shapes step at 24 drawings a second)
##   Crescent     the CRESCENT NOVA finisher's flying wave: a big crescent that pierces every enemy in
##                its path (each once), cuts enemy bullets and breaks cover, then fades out
## (the sword itself is the Higgsfield art in assets/hq/weapons/energy_sword.png, held by melee_rig.gd)

const INK := Color(0.18, 0.02, 0.12, 0.85)
const WHITE := Color(1, 1, 1, 1)
const FPS := 24.0


## Sword outline from the guard (`base`) along `d` for `length`: half-width `hw`, a flare at the guard,
## straight edges, and a taper over the last TIP_FRAC to a sharp point.
const TIP_FRAC := 0.2


static func lance(base: Vector2, d: Vector2, length: float, hw: float) -> PackedVector2Array:
	var n := d.orthogonal()
	var shoulder := length * (1.0 - TIP_FRAC)
	return PackedVector2Array([
		base - d * 2.0 + n * hw * 1.25, base + d * length * 0.07 + n * hw * 0.82, base + d * shoulder + n * hw,
		base + d * length,
		base + d * shoulder - n * hw, base + d * length * 0.07 - n * hw * 0.82, base - d * 2.0 - n * hw * 1.25])


## The blade (normal blend): ink rim, pink body, pale band, white-hot core; flickers in steps.
static func draw_blade(ci: CanvasItem, base: Vector2, d: Vector2, length: float, hw: float, time: float, col: Color) -> void:
	if length < 24.0:
		return
	var frame := int(time * FPS)
	var w := hw * ([1.0, 0.9, 1.07, 0.95][frame % 4] as float)
	ci.draw_colored_polygon(lance(base - d * 1.5, d, length + 5.0, w + 2.4), INK)
	ci.draw_colored_polygon(lance(base, d, length, w), col)
	ci.draw_colored_polygon(lance(base + d * 2.0, d, length - 5.0, w * 0.55), col.lightened(0.6))
	ci.draw_colored_polygon(lance(base + d * 4.0, d, length - 12.0, w * 0.24), WHITE)


## While equipped (additive layer): breathing halo, crackles along the blade, a twinkle at the tip.
static func draw_glow(ci: CanvasItem, base: Vector2, d: Vector2, length: float, hw: float, time: float, col: Color) -> void:
	if length < 24.0:
		return
	var pulse := 0.5 + 0.5 * sin(time * 5.0)
	ci.draw_colored_polygon(lance(base - d * 6.0, d, length + 16.0, hw * (2.1 + 0.4 * pulse)), Color(col, 0.10 + 0.08 * pulse))
	ci.draw_colored_polygon(lance(base - d * 3.0, d, length + 8.0, hw * (1.4 + 0.2 * pulse)), Color(col, 0.18 + 0.12 * pulse))
	var n := d.orthogonal()
	var step := int(time * 12.0)
	var rng := RandomNumberGenerator.new()
	for arc in 2:
		rng.seed = step * 13 + arc * 7
		if rng.randf() < 0.25:
			continue
		var pts := PackedVector2Array()
		var a0 := rng.randf_range(0.05, 0.35)
		var a1 := minf(a0 + rng.randf_range(0.35, 0.6), 0.85)
		var k := a0
		while k <= a1:
			pts.append(base + d * length * k + n * hw * rng.randf_range(-1.7, 1.7))
			k += rng.randf_range(0.06, 0.11)
		if pts.size() >= 2:
			ci.draw_polyline(pts, Color(col.lightened(0.6), 0.85), 1.6)
	# Tip twinkle every second or so.
	var tw := fmod(time, 1.3)
	if tw < 0.22:
		var s := (1.0 - tw / 0.25) * 9.0
		var tip := base + d * (length + 2.0)
		ci.draw_colored_polygon(PackedVector2Array([tip + d * s * 1.6, tip + n * s * 0.25, tip - d * s * 0.6,
			tip - n * s * 0.25]), Color(1, 1, 1, 0.9))
		ci.draw_colored_polygon(PackedVector2Array([tip + n * s, tip + d * s * 0.25, tip - n * s,
			tip - d * s * 0.25]), Color(1, 1, 1, 0.9))


static func cross_flash(pos: Vector2, color: Color, heavy: bool) -> void:
	var f := CrossFlash.new()
	f.position = pos
	f.color = color
	f.size = 1.1 if heavy else 0.75
	f.rotation = randf_range(-0.4, 0.4)
	Combat.world().add_child(f)


## PIERCING LUNGE: a long pointed beam streak that shoots out along the stab, then thins and fades.
static func lunge(from: Vector2, dir: Vector2, length: float, color: Color) -> void:
	var l := LungeFlash.new()
	l.position = from
	l.rotation = dir.angle()
	l.length = length
	l.color = color
	Combat.world().add_child(l)


## X-CUT: the two cuts linger as a glowing X, then burst for a second hit around `pos`.
static func x_mark(source: Node2D, pos: Vector2, dir: Vector2, size: float, damage: float, color: Color) -> void:
	var x := XMark.new()
	x.position = pos
	x.rotation = dir.angle()
	x.size = size
	x.damage = damage
	x.color = color
	x.source = source
	Combat.world().add_child(x)


static func crescent(source: Node2D, pos: Vector2, dir: Vector2, damage: float, color: Color) -> void:
	var c := Crescent.new()
	c.position = pos
	c.dir = dir
	c.damage = damage
	c.color = color
	c.source = source
	Combat.world().add_child(c)


## Slash smear drawn from the rig's blade samples ([time, grip, angle, ext], oldest first).
class CelSmear extends Node2D:
	const LIFE := 0.12
	## Thickest part of the crescent, as a fraction of the blade length.
	const THICK := 0.16
	var rig: Node2D

	func _ready() -> void:
		top_level = true
		z_index = 3

	func _draw() -> void:
		var r = rig
		if r == null or r._tex == null or not r._cel:
			return
		var tr: Array = r._trail[0]
		if tr.size() < 2:
			return
		var now: float = r._time
		var col: Color = r._color
		# Sub-sample between the recorded poses (angle interpolated) so fast arcs stay round.
		var ss := []
		for i in tr.size() - 1:
			for k in 4:
				var f := k / 4.0
				ss.append([lerpf(tr[i][0], tr[i + 1][0], f), (tr[i][1] as Vector2).lerp(tr[i + 1][1], f),
					lerp_angle(tr[i][2], tr[i + 1][2], f), lerpf(tr[i][3], tr[i + 1][3], f)])
		ss.append(tr[tr.size() - 1])
		# Per sample: a thin crescent just inside the tip path, thickest in the middle and tapered at both
		# ends (the head keeps a little width while it's still attached to the moving blade).
		var grip := []
		var dirs := []
		var outer_r := []
		var inner_r := []
		var fade := []
		var n := ss.size()
		for i in n:
			var s: Array = ss[i]
			var age := clampf((now - float(s[0])) / LIFE, 0.0, 1.0)
			var blen: float = r._length * float(s[3])
			var u := i / float(maxi(n - 1, 1))
			var thick := maxf(sin(PI * u), 0.35 * u) * THICK * (1.0 - 0.5 * age)
			grip.append(s[1])
			dirs.append(Vector2.from_angle(s[2]))
			outer_r.append(blen * 1.02)
			inner_r.append(blen * (1.02 - thick))
			fade.append(1.0 - age)
		# Layers: ink rim, body, then the white-hot leading edge along the outside.
		for layer in [[Color(INK, 0.55), 1.022, 0.0, -0.12], [col, 1.0, 0.0, 0.0], [col.lightened(0.6), 0.996, 0.3, 0.0],
				[WHITE, 0.992, 0.6, 0.0]]:
			var c: Color = layer[0]
			for i in ss.size() - 1:
				var alpha: float = minf(fade[i], fade[i + 1])
				if alpha <= 0.02:
					continue
				var a := _band(grip[i], dirs[i], outer_r[i], inner_r[i], layer)
				var b := _band(grip[i + 1], dirs[i + 1], outer_r[i + 1], inner_r[i + 1], layer)
				var poly := PackedVector2Array([a[0], b[0], b[1], a[1]])
				if Geometry2D.triangulate_polygon(poly).is_empty():
					continue
				draw_colored_polygon(poly, Color(c, c.a * (0.5 + 0.5 * alpha)))
		# Speed lines just outside the newest part of the arc.
		var head: Array = tr[tr.size() - 1]
		var tail: Array = tr[maxi(tr.size() - 4, 0)]
		var turn := angle_difference(float(tail[2]), float(head[2]))
		if absf(turn) > 0.05:
			for i in 3:
				var rr: float = r._length * float(head[3]) * (1.12 + 0.07 * i)
				var a0: float = head[2] - turn * (0.2 + 0.25 * i)
				var a1: float = a0 - turn * 0.6
				draw_line(head[1] + Vector2.from_angle(a0) * rr, head[1] + Vector2.from_angle(a1) * rr,
					Color(col.lightened(0.6), 0.75), 2.0)

	## [outer, inner] points of one sample for a layer [color, outer scale, inner -> outer fraction,
	## extra inner offset (fraction of the band)].
	func _band(g: Vector2, d: Vector2, ro: float, ri: float, layer: Array) -> Array:
		var o: float = ro * float(layer[1])
		var band := ro - ri
		var i: float = ri + band * float(layer[2]) + band * float(layer[3])
		return [g + d * o, g + d * minf(i, o)]


class CrossFlash extends Node2D:
	var color := Color.WHITE
	var size := 1.0
	var _t := 0.0

	func _ready() -> void:
		z_index = 6

	func _process(delta: float) -> void:
		_t += delta
		if _t > 8.0 / FPS:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var f := int(_t * FPS)
		var k := size
		if f == 0:
			draw_circle(Vector2.ZERO, 17.0 * k, INK)
			draw_circle(Vector2.ZERO, 14.0 * k, WHITE)
		elif f <= 3:
			for a in [0.6, -0.6]:
				var dd := Vector2.from_angle(a)
				var nn := dd.orthogonal() * (8.0 - f) * k
				var ln := (40.0 + f * 11.0) * k
				draw_colored_polygon(PackedVector2Array([-dd * (ln + 6.0), nn * 1.6, dd * (ln + 6.0), -nn * 1.6]), INK)
				draw_colored_polygon(PackedVector2Array([-dd * ln, nn, dd * ln, -nn]), color.lightened(0.6))
			draw_arc(Vector2.ZERO, (18.0 + f * 9.0) * k, 0, TAU, 28, Color(color.lightened(0.5), 0.9 - f * 0.2), 4.0)
		else:
			draw_arc(Vector2.ZERO, (46.0 + f * 5.0) * k, 0, TAU, 32, Color(color, 0.7 - (f - 4) * 0.15), 3.0)


## Piercing Lunge streak (+x = the stab direction).
class LungeFlash extends Node2D:
	const LIFE := 0.24
	var length := 200.0
	var color := Color(1.0, 0.3, 0.8)
	var _t := 0.0

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / LIFE
		var grow := minf(k / 0.25, 1.0)
		var thin := 1.0 - clampf((k - 0.3) / 0.7, 0.0, 1.0)
		var l := length * (0.45 + 0.55 * grow)
		var hw := 7.0 * thin + 1.0
		var frame := int(_t * FPS)
		var wob := [1.0, 0.85, 1.1, 0.95][frame % 4] as float
		draw_colored_polygon(EnergySwordFx.lance(Vector2.ZERO, Vector2.RIGHT, l + 8.0, (hw + 3.0) * wob), Color(INK, 0.8 * thin))
		draw_colored_polygon(EnergySwordFx.lance(Vector2(2, 0), Vector2.RIGHT, l, hw * wob), Color(color, thin))
		draw_colored_polygon(EnergySwordFx.lance(Vector2(6, 0), Vector2.RIGHT, l - 10.0, hw * 0.35 * wob), Color(WHITE, thin))
		# Speed lines along the stab and a star at the point.
		for i in 4:
			var y := lerpf(-hw * 2.6, hw * 2.6, i / 3.0)
			var x0 := l * (0.25 + 0.12 * (i % 2))
			draw_line(Vector2(x0, y), Vector2(x0 + l * 0.45, y), Color(color.lightened(0.6), 0.7 * thin), 2.0)
		if k < 0.6:
			var s := 12.0 * (1.0 - k / 0.6)
			var tip := Vector2(l + 4.0, 0)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(s * 1.5, 0), tip + Vector2(0, s * 0.3), tip - Vector2(s * 0.5, 0),
				tip - Vector2(0, s * 0.3)]), WHITE)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(0, s), tip + Vector2(s * 0.3, 0), tip - Vector2(0, s),
				tip - Vector2(s * 0.3, 0)]), WHITE)


## X-Cut mark: two crossing cel slashes hang in the air, flicker, then burst (damage once).
class XMark extends Node2D:
	const HOLD := 0.28
	const LIFE := 0.5
	var size := 90.0
	var damage := 30.0
	var color := Color(1.0, 0.3, 0.8)
	var source: Node2D
	var _t := 0.0
	var _burst := false

	func _ready() -> void:
		z_index = 4

	func _physics_process(delta: float) -> void:
		_t += delta
		if not _burst and _t >= HOLD:
			_burst = true
			for n in Combat.enemies_in_area(global_position, size * 0.8):
				n.take_damage(damage, global_position, source if is_instance_valid(source) else null)
				if n.has_method("knock") and is_instance_valid(n):
					n.knock((n.global_position - global_position).normalized() * 260.0)
				if is_instance_valid(n):
					EnergySwordFx.cross_flash(n.global_position, color, false)
				if is_instance_valid(source) and source.has_method("_maybe_explode"):
					source._maybe_explode(n.global_position, damage)
			Combat.damage_destructibles(global_position, size * 0.8, damage)
			Combat.deflect_bullets(global_position, size * 0.9)
			Combat.shake(0.12)
			Sfx.play(&"shield", -8.0, 0.1)
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		if not _burst:
			# The X: two long pointed slashes crossing, flickering in steps.
			var frame := int(_t * FPS)
			var grow := minf(_t / 0.04, 1.0)
			var w := 5.0 * ([1.0, 0.8, 1.15, 0.9][frame % 4] as float) * grow + 1.0
			for a in [0.78, -0.78]:
				var d := Vector2.from_angle(a)
				var base := -d * size
				draw_colored_polygon(EnergySwordFx.lance(base - d * 4.0, d, size * 2.0 + 8.0, w + 3.0 * grow), INK)
				draw_colored_polygon(EnergySwordFx.lance(base, d, size * 2.0, w), color)
				draw_colored_polygon(EnergySwordFx.lance(base + d * 6.0, d, size * 2.0 - 12.0, w * 0.35), WHITE)
			return
		# Burst: the X snaps outward into a ring of rays, then fades.
		var k := (_t - HOLD) / (LIFE - HOLD)
		var r := size * (0.4 + 0.9 * k)
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(INK, 0.6 * (1.0 - k)), 7.0 * (1.0 - k) + 1.0)
		draw_arc(Vector2.ZERO, r, 0, TAU, 32, Color(color.lightened(0.4), 1.0 - k), 4.0 * (1.0 - k) + 1.0)
		for i in 8:
			var d := Vector2.from_angle(i * TAU / 8.0 + 0.39)
			draw_line(d * r * 0.55, d * r * 1.15, Color(WHITE, 0.9 * (1.0 - k)), 2.5)


## CRESCENT NOVA wave.
class Crescent extends Node2D:
	const SPEED := 900.0
	const LIFE := 0.55
	const RADIUS := 56.0
	var dir := Vector2.RIGHT
	var damage := 50.0
	var color := Color(1.0, 0.3, 0.8)
	var source: Node2D
	var _t := 0.0
	var _hit := {}

	func _ready() -> void:
		z_index = 4
		rotation = dir.angle()

	func _physics_process(delta: float) -> void:
		_t += delta
		position += dir * SPEED * delta
		# The wave's cutting edge: a band in front of its centre.
		var edge := global_position + dir * 20.0
		for n in Combat.enemies_in_area(edge, RADIUS, dir, 1.3):
			if _hit.has(n.get_instance_id()):
				continue
			_hit[n.get_instance_id()] = true
			n.take_damage(damage, global_position, source if is_instance_valid(source) else null)
			if n.has_method("knock") and is_instance_valid(n):
				n.knock(dir * 420.0)
			if is_instance_valid(n):
				EnergySwordFx.cross_flash(n.global_position, color, false)
			if is_instance_valid(source) and source.has_method("_maybe_explode"):
				source._maybe_explode(n.global_position, damage)
		Combat.damage_destructibles(edge, RADIUS, damage, dir, 1.3)
		Combat.deflect_bullets(edge, RADIUS + 10.0, dir, 1.4)
		if _t >= LIFE:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / LIFE
		var fade := 1.0 - k * k
		var grow := 0.7 + 0.5 * minf(k * 3.0, 1.0)
		var r := RADIUS * grow
		# Crescent: outer arc in front, inner arc pulled back -> thick middle, pointed horns.
		var outer := PackedVector2Array()
		var inner := PackedVector2Array()
		for i in 15:
			var a := lerpf(-1.25, 1.25, i / 14.0)
			outer.append(Vector2.from_angle(a) * r)
			inner.append(Vector2.from_angle(a) * r * 0.62 + Vector2(-r * 0.12, 0) * (1.0 - absf(a) / 1.25))
		var frame := int(_t * FPS)
		var wob := [1.0, 0.94, 1.05, 0.97][frame % 4] as float
		for layer in [[INK, 1.08, 0.92], [color, 1.0, 1.0], [color.lightened(0.55), 0.97, 1.12], [WHITE, 0.95, 1.22]]:
			var poly := PackedVector2Array()
			for p in outer:
				poly.append(p * float(layer[1]) * wob)
			for j in range(inner.size() - 1, -1, -1):
				poly.append(inner[j] * float(layer[2]))
			var c: Color = layer[0]
			draw_colored_polygon(poly, Color(c, c.a * fade))
		# Speed lines trailing behind.
		for i in 4:
			var y := lerpf(-r * 0.7, r * 0.7, i / 3.0)
			draw_line(Vector2(-r * 0.3, y), Vector2(-r * 0.3 - 40.0 - 20.0 * (i % 2), y), Color(color.lightened(0.6), 0.7 * fade), 2.0)
