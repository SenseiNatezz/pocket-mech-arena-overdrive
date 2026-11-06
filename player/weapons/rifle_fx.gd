class_name RifleFx
extends Node2D
## Beam Rifle effects in the style of 2D mecha anime: flat colour layers with a dark outline, shapes
## that change in steps (24 drawings a second, like cel animation) instead of smoothly.
##   RifleFx.draw_bolt(ci, frame, color, seed)   the shot: a long beam lance (white-hot core, coloured
##                                               band, tapering tail, energy crackle, speed lines)
##   RifleFx.muzzle(parent, dir, color)          beam ignition at the barrel: a jagged cone of light
##                                               fanning forward, a flash and a ring (follows the barrel)
##   RifleFx.impact(pos, dir, color, size)       manga-style hit: white flash + radiating lines, a
##                                               yellow star inside an orange spiky star, smoke puffs,
##                                               sparks and shards
## All shapes point along +x (the bolt's / burst's direction). Original drawings, written in code.

enum Kind { MUZZLE, IMPACT }

const FPS := 24.0
const MUZZLE_FRAMES := 5
const IMPACT_FRAMES := 8
## Hits land ~9 times a second on one target, so bursts stay a little smaller than the drawings.
const IMPACT_SCALE := 0.85
## Beam length behind the tip (px, at bolt size 1). The tip sits just ahead of the hit circle.
const BOLT_LENGTH := 118.0
const BOLT_HALF_WIDTH := 7.0
const FIRE_ORANGE := Color(1.0, 0.45, 0.1)
const FIRE_YELLOW := Color(1.0, 0.92, 0.45)
const SMOKE := Color(0.62, 0.58, 0.62)

var kind := Kind.IMPACT
var color := Color.WHITE
var size := 1.0
var _t := 0.0
var _frame := -1
## Impact shards / sparks: [position, velocity, spin, size, is_spark] in local space.
var _bits: Array = []


## Beam ignition at the barrel; parented to `parent` (the muzzle) so it moves with the mech.
static func muzzle(parent: Node2D, dir: Vector2, col: Color) -> void:
	var fx := RifleFx.new()
	fx.kind = Kind.MUZZLE
	fx.color = col
	fx.z_index = 2
	parent.add_child(fx)
	fx.global_rotation = dir.angle()


static func impact(pos: Vector2, dir: Vector2, col: Color, burst_size := 1.0) -> void:
	var fx := RifleFx.new()
	fx.kind = Kind.IMPACT
	fx.color = col
	fx.size = burst_size
	fx.z_index = 5
	fx.global_position = pos
	fx.rotation = dir.angle()
	fx.scale = Vector2.ONE * burst_size * IMPACT_SCALE
	# Shards tumble back toward the shooter; sparks streak out all around.
	for i in 4:
		var a := PI + randf_range(-1.2, 1.2)
		fx._bits.append([Vector2.ZERO, Vector2.from_angle(a) * randf_range(160.0, 300.0), randf_range(-14.0, 14.0), randf_range(3.5, 6.0), false])
	for i in 6:
		var a := randf() * TAU
		fx._bits.append([Vector2.ZERO, Vector2.from_angle(a) * randf_range(320.0, 560.0), 0.0, randf_range(8.0, 16.0), true])
	Combat.world().add_child(fx)


func _process(delta: float) -> void:
	_t += delta
	for b: Array in _bits:
		b[0] += b[1] * delta
		b[1] *= 1.0 - 7.0 * delta
	var f := int(_t * FPS)
	if f >= (MUZZLE_FRAMES if kind == Kind.MUZZLE else IMPACT_FRAMES):
		queue_free()
		return
	if f != _frame or not _bits.is_empty():
		_frame = f
		queue_redraw()


func _draw() -> void:
	if _frame < 0:
		return
	if kind == Kind.MUZZLE:
		_draw_muzzle(_frame)
	else:
		_draw_impact(_frame)


# --- shared shapes --------------------------------------------------------------------------------

static func _scaled(pts: PackedVector2Array, k: Vector2, shift := Vector2.ZERO) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k + shift)
	return out


## Four-point twinkle star.
static func _star(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var t := r * 0.28
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(r, 0), p + Vector2(t, t), p + Vector2(0, r),
		p + Vector2(-t, t), p + Vector2(-r, 0), p + Vector2(-t, -t), p + Vector2(0, -r), p + Vector2(t, -t)]), col)


## Jagged star: `n` spikes, tips at r_long (+- jitter), valleys at r_short.
static func _spikes(n: int, r_long: float, r_short: float, rng: RandomNumberGenerator, jitter := 0.25, turn := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := turn + i * PI / n
		var r := r_long * (1.0 + rng.randf_range(-jitter, jitter)) if i % 2 == 0 else r_short
		pts.append(Vector2.from_angle(a) * r)
	return pts


## Outlined flat shape: dark rim (the shape grown by `rim`), then the fill.
static func _inked(ci: CanvasItem, pts: PackedVector2Array, fill: Color, ink: Color, rim := 1.18) -> void:
	ci.draw_colored_polygon(_scaled(pts, Vector2.ONE * rim), ink)
	ci.draw_colored_polygon(pts, fill)


# --- the bolt -------------------------------------------------------------------------------------

## Draws one frame of the rifle shot on `ci` (a Bullet; +x = forward, origin = the hit circle).
## `frame` steps at FPS; `seed` keeps each bolt's crackle its own; `reach` = how far the beam has come
## out of the barrel (it grows out of it instead of appearing at full length inside the mech).
static func draw_bolt(ci: CanvasItem, frame: int, col: Color, seed: int, reach := INF) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed * 31 + frame)
	var w := BOLT_HALF_WIDTH * ([1.0, 0.82, 1.15, 0.92][frame % 4] as float)
	var l := minf(BOLT_LENGTH * ([1.0, 1.06, 0.95, 1.03][frame % 4] as float), maxf(reach + 16.0, 24.0))
	var ink := Color(col.darkened(0.65), 0.9)
	# Speed lines streaming off the beam.
	for i in 4:
		var y := rng.randf_range(-w * 2.2, w * 2.2)
		var x0 := -l * rng.randf_range(0.25, 0.7)
		ci.draw_line(Vector2(x0, y), Vector2(x0 - rng.randf_range(24.0, 54.0), y), Color(col.lightened(0.35), 0.5), 1.5)
	# The lance: sharp tip, fat head, long taper to the tail.
	var lance := PackedVector2Array([Vector2(16, 0), Vector2(4, -w), Vector2(-l * 0.3, -w * 0.82),
		Vector2(-l * 0.72, -w * 0.42), Vector2(-l, 0), Vector2(-l * 0.72, w * 0.42), Vector2(-l * 0.3, w * 0.82), Vector2(4, w)])
	ci.draw_colored_polygon(_scaled(lance, Vector2(1.03, 1.45), Vector2(2, 0)), ink)
	ci.draw_colored_polygon(lance, col)
	ci.draw_colored_polygon(_scaled(lance, Vector2(0.92, 0.6), Vector2(3, 0)), col.lightened(0.55))
	ci.draw_colored_polygon(_scaled(lance, Vector2(0.7, 0.26), Vector2(5, 0)), Color.WHITE)
	# Bright head.
	ci.draw_circle(Vector2(2, 0), w * 0.75, Color.WHITE)
	# Energy crackle zig-zagging along the body on most drawings.
	if frame % 3 != 1:
		var pts := PackedVector2Array()
		var x := 0.0
		while x > -l * 0.8:
			pts.append(Vector2(x, rng.randf_range(-w * 1.1, w * 1.1)))
			x -= rng.randf_range(10.0, 18.0)
		ci.draw_polyline(pts, Color(1, 1, 1, 0.8), 1.5)
	if frame % 2 == 0:
		_star(ci, Vector2(-rng.randf_range(10.0, l * 0.6), rng.randf_range(-w * 1.8, w * 1.8)), rng.randf_range(4.0, 7.0), Color(1, 1, 1, 0.9))


# --- muzzle: beam ignition ------------------------------------------------------------------------

## Fan-shaped flare from the barrel: `reach` long, `spread` radians wide, jagged rim.
func _cone(reach: float, spread: float, rng: RandomNumberGenerator, n := 7) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(-4, -3), Vector2(-4, 3)])
	for i in n + 1:
		var a := spread * (float(i) / n - 0.5)
		var r := reach * (1.0 if i % 2 == 0 else rng.randf_range(0.55, 0.75))
		pts.append(Vector2.from_angle(-a) * r)
	return pts


func _draw_muzzle(f: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_instance_id() * 3 + f)
	var ink := Color(color.darkened(0.65), 0.85)
	match f:
		0:
			_inked(self, _cone(34.0, 0.9, rng), color.lightened(0.45), ink, 1.15)
			draw_circle(Vector2.ZERO, 11.0, ink)
			draw_circle(Vector2.ZERO, 9.0, Color.WHITE)
		1:
			_inked(self, _cone(52.0, 0.75, rng), color, ink, 1.12)
			draw_colored_polygon(_scaled(_cone(36.0, 0.5, rng, 5), Vector2.ONE), Color.WHITE)
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 24, ink, 5.0)
			draw_arc(Vector2.ZERO, 14.0, 0, TAU, 24, color.lightened(0.5), 2.5)
		2:
			# The cone breaks into three spikes.
			for a in [-0.28, 0.0, 0.28]:
				var d := Vector2.from_angle(a + rng.randf_range(-0.06, 0.06))
				var n := d.orthogonal() * 3.5
				var tip := d * rng.randf_range(44.0, 60.0)
				_inked(self, PackedVector2Array([n, tip, -n]), color.lightened(0.4), ink, 1.25)
			draw_arc(Vector2.ZERO, 21.0, 0, TAU, 28, Color(color.lightened(0.4), 0.8), 2.5)
		3:
			draw_arc(Vector2.ZERO, 26.0, 0, TAU, 28, Color(color, 0.5), 1.5)
			_star(self, Vector2(rng.randf_range(24.0, 40.0), rng.randf_range(-10.0, 10.0)), 5.0, Color.WHITE)
			_star(self, Vector2(rng.randf_range(14.0, 30.0), rng.randf_range(-12.0, 12.0)), 3.5, color.lightened(0.5))
		_:
			_star(self, Vector2(rng.randf_range(30.0, 46.0), rng.randf_range(-8.0, 8.0)), 3.0, Color(1, 1, 1, 0.7))


# --- impact: manga explosion ----------------------------------------------------------------------

func _draw_impact(f: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(get_instance_id() * 7 + f)
	var ink := Color(0.12, 0.05, 0.08, 0.85)
	var outer := FIRE_ORANGE
	match f:
		0:
			# Flash with radiating impact lines.
			for i in 10:
				var d := Vector2.from_angle(i * TAU / 10 + rng.randf_range(-0.15, 0.15))
				draw_line(d * 16.0, d * rng.randf_range(34.0, 48.0), Color(1, 1, 1, 0.85), 2.0)
			draw_circle(Vector2.ZERO, 17.0, ink)
			draw_circle(Vector2.ZERO, 14.0, Color.WHITE)
		1:
			_inked(self, _spikes(11, 36.0, 20.0, rng), outer, ink, 1.14)
			draw_colored_polygon(_spikes(9, 25.0, 14.0, rng, 0.2, 0.3), FIRE_YELLOW)
			draw_circle(Vector2.ZERO, 10.0, Color.WHITE)
		2:
			_inked(self, _spikes(12, 44.0, 26.0, rng, 0.3), outer, ink, 1.12)
			draw_colored_polygon(_spikes(10, 32.0, 18.0, rng, 0.25, 0.2), FIRE_YELLOW)
			draw_circle(Vector2.ZERO, 12.0, Color(1, 1, 1, 0.9))
		3:
			# The star collapses into a ring of fire puffs.
			for i in 7:
				var p := Vector2.from_angle(i * TAU / 7 + 0.2) * 30.0
				draw_circle(p, 13.0, ink)
				draw_circle(p, 11.0, outer)
			draw_colored_polygon(_spikes(8, 24.0, 14.0, rng, 0.2), FIRE_YELLOW)
		4, 5:
			# Puffs cool from fire to smoke and drift out; the shot's colour rings the blast.
			var k := f - 4
			for i in 7:
				var p := Vector2.from_angle(i * TAU / 7 + 0.2 + k * 0.15) * (36.0 + k * 6.0)
				var r := 11.0 - k * 3.0
				draw_circle(p, r + 2.0, Color(ink, 0.6 - k * 0.2))
				draw_circle(p, r, FIRE_YELLOW.lerp(SMOKE, 0.5 + k * 0.4) if i % 2 == 0 else outer.lerp(SMOKE, 0.35 + k * 0.4))
			draw_arc(Vector2.ZERO, 44.0 + k * 8.0, 0, TAU, 36, Color(color.lightened(0.3), 0.8 - k * 0.35), 3.0 - k)
		6:
			for i in 5:
				var p := Vector2.from_angle(i * TAU / 5 + 0.5) * 50.0
				draw_circle(p, 4.5, Color(SMOKE, 0.5))
			_star(self, Vector2.from_angle(rng.randf() * TAU) * 30.0, 5.0, Color(1, 1, 1, 0.7))
		_:
			pass
	# Shards (outlined triangles) and sparks (streaks along their motion).
	var fade := clampf(1.0 - _t / (IMPACT_FRAMES / FPS), 0.0, 1.0)
	for b: Array in _bits:
		var p: Vector2 = b[0]
		if b[4]:
			var v: Vector2 = b[1]
			if v.length() > 20.0:
				var streak: float = b[3]
				var tail: Vector2 = p - v.normalized() * streak * (0.4 + fade)
				draw_line(tail, p, Color(FIRE_YELLOW, fade), 2.0)
			continue
		var sz: float = b[3] * (0.5 + 0.5 * fade)
		var a: float = b[2] * _t
		var tri := PackedVector2Array([p + Vector2.from_angle(a) * sz, p + Vector2.from_angle(a + 2.3) * sz * 0.7,
			p + Vector2.from_angle(a + 4.0) * sz * 0.8])
		draw_colored_polygon(tri, Color(ink, fade))
		draw_colored_polygon(_scaled(tri, Vector2.ONE * 0.6, p * 0.4), Color(outer.lightened(0.3), fade))
