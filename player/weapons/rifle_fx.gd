class_name RifleFx
extends Node2D
## Gun effects, drawn in code (all additive light, so they glow over any floor):
## BEAM RIFLE, Gundam style (the pilot's energy colour):
##   RifleFx.draw_bolt(ci, frame, color, seed, reach)   the shot: a thick beam with a soft bloom, a
##       coloured shell, a hot inner shell and a white-hot core; two energy strands twist around it
##       (tighter at the head), crackling arcs flicker off it and sparks trail behind; a bright flared head
##   RifleFx.muzzle(parent, dir, color)    ignition: white core flash, lens-flare star and a short jet of
##       light out of the barrel, then a shock ring opening out (follows the barrel)
##   RifleFx.impact(pos, dir, color, size) the hit: a white flash, a coloured ring with beam splash
##       spikes, hex shards flung out, spark streaks, and a small glow left behind for a moment
## GATLING CANNON (physical rounds, warm tracers whatever the energy colour):
##   RifleFx.draw_tracer(ci, frame, seed, reach)   a long white-hot tracer streak with an orange tail
##   RifleFx.gat_muzzle(parent, dir)       a muzzle-brake flash: a forward star plus side jets (three
##       shapes, picked at random so the stream flickers), with a gun-smoke puff every few rounds
##   RifleFx.gat_impact(pos, dir)          sparks spraying back off the target and a dust puff
## DUAL BEAM PISTOLS: RifleFx.draw_dart (a short quick beam), RifleFx.pistol_muzzle (a small flash).
## All shapes point along +x. Shapes step at FPS drawings a second, like cel animation.

enum Kind { MUZZLE, IMPACT, GAT_MUZZLE, GAT_IMPACT, PISTOL_MUZZLE }

const FPS := 24.0
const FRAMES := {Kind.MUZZLE: 6, Kind.IMPACT: 8, Kind.GAT_MUZZLE: 2, Kind.GAT_IMPACT: 4, Kind.PISTOL_MUZZLE: 3}
## Hits land ~9 times a second on one target, so bursts stay a little smaller than the drawings.
const IMPACT_SCALE := 0.85
## Beam length behind the tip (px, at bolt size 1), and its half-width.
const BOLT_LENGTH := 136.0
const BOLT_HALF_WIDTH := 7.0
## Gatling tracer length / half-width (screen px, whatever the round's hitbox size).
const TRACER_LENGTH := 74.0
const TRACER_HALF_WIDTH := 2.6
const TRACER := Color(1.0, 0.72, 0.28)
## Pistol beam darts.
const DART_LENGTH := 64.0
const DART_HALF_WIDTH := 4.2
const GLOW := preload("res://assets/fx/glow.tres")
## Shared additive material (bolts set it on their Bullet while drawn-styled).
static var _add: CanvasItemMaterial

var kind := Kind.IMPACT
var color := Color.WHITE
var size := 1.0
var variant := 0
var _t := 0.0
var _frame := -1
## Impact sparks: [position, velocity, length] in local space.
var _bits: Array = []
## Impact shards: [angle, speed, spin].
var _shards: Array = []


static func additive() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


## Beam ignition at the barrel; parented to `parent` (the muzzle) so it moves with the mech.
static func muzzle(parent: Node2D, dir: Vector2, col: Color) -> void:
	_attach(parent, dir, col, Kind.MUZZLE)


static func pistol_muzzle(parent: Node2D, dir: Vector2, col: Color) -> void:
	_attach(parent, dir, col, Kind.PISTOL_MUZZLE)


static func gat_muzzle(parent: Node2D, dir: Vector2) -> void:
	var fx := _attach(parent, dir, TRACER, Kind.GAT_MUZZLE)
	fx.variant = randi() % 3


static func _attach(parent: Node2D, dir: Vector2, col: Color, k: Kind) -> RifleFx:
	var fx := RifleFx.new()
	fx.kind = k
	fx.color = col
	fx.z_index = 2
	parent.add_child(fx)
	fx.global_rotation = dir.angle()
	return fx


static func impact(pos: Vector2, dir: Vector2, col: Color, burst_size := 1.0) -> void:
	var fx := RifleFx.new()
	fx.kind = Kind.IMPACT
	fx.color = col
	fx.size = burst_size
	fx.z_index = 5
	fx.global_position = pos
	fx.rotation = dir.angle()
	fx.scale = Vector2.ONE * burst_size * IMPACT_SCALE
	GroundFx.flash(pos, 70.0 * burst_size, col, 0.5, 0.22)
	# Sparks streak out, mostly back toward the shooter and to the sides.
	for i in 9:
		var a := PI + randf_range(-1.9, 1.9)
		fx._bits.append([Vector2.ZERO, Vector2.from_angle(a) * randf_range(280.0, 560.0), randf_range(8.0, 18.0)])
	for i in 5:
		fx._shards.append([randf() * TAU, randf_range(120.0, 220.0), randf_range(-12.0, 12.0)])
	Combat.world().add_child(fx)


static func gat_impact(pos: Vector2, dir: Vector2) -> void:
	var fx := RifleFx.new()
	fx.kind = Kind.GAT_IMPACT
	fx.color = TRACER
	fx.z_index = 5
	GroundFx.flash(pos, 44.0, TRACER, 0.35, 0.12)
	fx.global_position = pos
	fx.rotation = dir.angle()
	for i in 6:
		var a := PI + randf_range(-1.2, 1.2)
		fx._bits.append([Vector2.ZERO, Vector2.from_angle(a) * randf_range(320.0, 640.0), randf_range(6.0, 13.0)])
	Combat.world().add_child(fx)
	if randf() < 0.45:
		SmokePuff.spawn(pos - dir * 6.0, Color(0.55, 0.5, 0.45), 14.0, 0.45, -dir * 30.0)


func _ready() -> void:
	material = additive()


func _process(delta: float) -> void:
	_t += delta
	for b: Array in _bits:
		b[0] += b[1] * delta
		b[1] *= 1.0 - 7.0 * delta
	var f := int(_t * FPS)
	if f >= FRAMES[kind]:
		queue_free()
		return
	if f != _frame or not _bits.is_empty() or not _shards.is_empty():
		_frame = f
		queue_redraw()


func _draw() -> void:
	if _frame < 0:
		return
	match kind:
		Kind.MUZZLE:
			_draw_muzzle(_frame)
		Kind.IMPACT:
			_draw_impact(_frame)
		Kind.GAT_MUZZLE:
			_draw_gat_muzzle(_frame)
		Kind.GAT_IMPACT:
			_draw_gat_impact(_frame)
		Kind.PISTOL_MUZZLE:
			_draw_pistol_muzzle(_frame)


# --- shared shapes --------------------------------------------------------------------------------

## Four-point lens-flare star: arms `along` long on the x axis and `across` on the y axis.
static func _flare(ci: CanvasItem, p: Vector2, along: float, across: float, col: Color) -> void:
	var t := minf(along, across) * 0.16
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(along, 0), p + Vector2(t, t), p + Vector2(0, across),
		p + Vector2(-t, t), p + Vector2(-along, 0), p + Vector2(-t, -t), p + Vector2(0, -across), p + Vector2(t, -t)]), col)


## Soft round glow (the shared radial gradient texture) of radius `r`.
static func _glow(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(GLOW, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


## A beam layer: pointed at the head (+x), `w` half-wide, fading from `head` to `tail` colour over
## `l` px behind it.
static func _bolt_shape(ci: CanvasItem, l: float, w: float, head: Color, tail: Color) -> void:
	var mid := head.lerp(tail, 0.45)
	ci.draw_polygon(PackedVector2Array([Vector2(w * 1.7, 0), Vector2(w * 0.2, -w), Vector2(-l * 0.45, -w * 0.8),
		Vector2(-l, 0), Vector2(-l * 0.45, w * 0.8), Vector2(w * 0.2, w)]),
		PackedColorArray([head, head, mid, tail, mid, head]))


## Radial spikes (beam splash / starburst): `n` spikes between radius r0 and r1, half-width `w` at the base.
static func _spikes(ci: CanvasItem, n: int, r0: float, r1: float, w: float, col: Color, phase := 0.0) -> void:
	for i in n:
		var a := phase + TAU * i / n
		var d := Vector2.from_angle(a)
		var s := d.orthogonal() * w
		var len := r1 * (1.0 if i % 2 == 0 else 0.7)
		ci.draw_colored_polygon(PackedVector2Array([d * r0 + s, d * len, d * r0 - s]), col)


# --- the beam rifle bolt --------------------------------------------------------------------------

## Draws one frame of the rifle shot on `ci` (a Bullet using additive(); +x = forward, origin = the hit
## circle). `frame` steps at FPS; `reach` = how far the beam has come out of the barrel (it grows out of
## it instead of appearing at full length inside the mech).
static func draw_bolt(ci: CanvasItem, frame: int, col: Color, seed: int, reach := INF) -> void:
	var flick: float = [1.0, 0.88, 1.1, 0.94, 1.05, 0.9][frame % 6]
	var w := BOLT_HALF_WIDTH * flick
	var l := minf(BOLT_LENGTH, maxf(reach + 16.0, 24.0))
	var clear := Color(col, 0.0)
	var hot := col.lightened(0.55)
	if BlastFx.pale_floor:
		# Painted (not added) on pale ice: a dark rim and a deeper colour so the beam reads on white.
		_bolt_shape(ci, l * 1.02, w * 1.75, Color(col.darkened(0.55), 0.55), Color(col.darkened(0.55), 0.0))
		_bolt_shape(ci, l, w * 1.3, Color(col.darkened(0.08), 0.95), clear)
		_bolt_shape(ci, l * 0.86, w * 0.78, Color(hot, 1.0), Color(col, 0.0))
		_bolt_shape(ci, l * 0.72, w * 0.36, Color.WHITE, Color(1, 1, 1, 0))
	else:
		# Bloom, coloured shell, hot inner shell, white core.
		_bolt_shape(ci, l * 1.08, w * 3.0, Color(col, 0.22), clear)
		_bolt_shape(ci, l, w * 1.3, Color(col.lightened(0.12), 0.92), clear)
		_bolt_shape(ci, l * 0.86, w * 0.78, Color(hot, 1.0), Color(col, 0.0))
		_bolt_shape(ci, l * 0.72, w * 0.36, Color.WHITE, Color(1, 1, 1, 0))
	# Two energy strands twisting round the beam: tight near the head, opening out down the tail.
	var n := 18
	for s in 2:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for j in n + 1:
			var k := float(j) / n
			var x := -l * 0.95 * k
			var amp := w * (0.55 + 1.15 * k)
			pts.append(Vector2(x, sin(x * 0.085 + frame * 1.9 + s * PI) * amp))
			cols.append(Color(hot, 0.85 * (1.0 - k) * (1.0 - k * 0.3)))
		ci.draw_polyline_colors(pts, cols, 1.7, true)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + frame
	# Crackling arcs flickering off the beam.
	if rng.randf() < 0.65:
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var arc := PackedVector2Array()
		var x0 := -rng.randf_range(4.0, l * 0.4)
		for j in 5:
			arc.append(Vector2(x0 - j * rng.randf_range(6.0, 10.0), side * (w * 0.5 + rng.randf_range(0.0, w * 0.9) * (j % 2 + 0.3))))
		ci.draw_polyline(arc, Color(col.lightened(0.5), 0.5), 1.0, true)
	# Sparks shed behind the beam.
	for j in 4:
		var x := -fmod(frame * 11.0 + j * 31.0 + float(seed % 23), l * 0.95)
		var y := (rng.randf() * 2.0 - 1.0) * w * 1.6
		var a := 1.0 - absf(x) / l
		ci.draw_circle(Vector2(x, y), 1.4, Color(hot, 0.9 * a))
	# Bright flared head.
	_glow(ci, Vector2(4, 0), w * 4.4, Color(col.lightened(0.3), 0.8))
	_flare(ci, Vector2(4, 0), w * 2.8, w * 1.1, Color(1, 1, 1, 0.85))
	ci.draw_circle(Vector2(4, 0), w * 0.62, Color.WHITE)


## Gatling tracer, in screen px (the Bullet undoes its own scale first): a white-hot head and core, an
## orange shell and tail, a warm bloom.
static func draw_tracer(ci: CanvasItem, frame: int, _seed: int, reach := INF) -> void:
	var l := minf(TRACER_LENGTH, maxf(reach + 8.0, 14.0))
	var w: float = TRACER_HALF_WIDTH * float([1.0, 0.85, 1.12][frame % 3])
	var clear := Color(TRACER, 0.0)
	_bolt_shape(ci, l * 1.05, w * 3.2, Color(TRACER, 0.28), clear)
	_bolt_shape(ci, l, w * 1.2, Color(1.0, 0.82, 0.45, 0.95), Color(1.0, 0.4, 0.1, 0.0))
	_bolt_shape(ci, l * 0.6, w * 0.5, Color(1, 1, 0.92, 1.0), Color(1, 0.9, 0.6, 0.0))
	_glow(ci, Vector2(2, 0), w * 4.0, Color(1.0, 0.75, 0.35, 0.7))
	ci.draw_circle(Vector2(2, 0), w * 0.8, Color(1, 1, 0.95))


## Pistol beam dart: a short, quick beam bolt with a bright head (no strands).
static func draw_dart(ci: CanvasItem, frame: int, col: Color, _seed: int, reach := INF) -> void:
	var l := minf(DART_LENGTH, maxf(reach + 10.0, 16.0))
	var w: float = DART_HALF_WIDTH * float([1.0, 0.9, 1.08][frame % 3])
	var clear := Color(col, 0.0)
	_bolt_shape(ci, l * 1.1, w * 2.8, Color(col, 0.25), clear)
	_bolt_shape(ci, l, w * 1.2, Color(col.lightened(0.15), 0.95), clear)
	_bolt_shape(ci, l * 0.75, w * 0.42, Color.WHITE, Color(1, 1, 1, 0))
	_glow(ci, Vector2(3, 0), w * 3.6, Color(col.lightened(0.3), 0.75))
	_flare(ci, Vector2(3, 0), w * 2.4, w * 0.9, Color(1, 1, 1, 0.8))


# --- beam rifle: ignition -------------------------------------------------------------------------

func _draw_muzzle(f: int) -> void:
	var c := color
	var hot := c.lightened(0.5)
	match f:
		0:
			_glow(self, Vector2(8, 0), 48.0, Color(c, 0.95))
			# Jet of light leaving the barrel.
			draw_colored_polygon(PackedVector2Array([Vector2(0, -9), Vector2(46, 0), Vector2(0, 9)]), Color(hot, 0.9))
			_flare(self, Vector2(6, 0), 46.0, 22.0, Color(1, 1, 1, 1))
			draw_circle(Vector2(6, 0), 11.0, Color.WHITE)
		1:
			_glow(self, Vector2(10, 0), 40.0, Color(c, 0.75))
			draw_colored_polygon(PackedVector2Array([Vector2(4, -6), Vector2(36, 0), Vector2(4, 6)]), Color(hot, 0.7))
			_flare(self, Vector2(8, 0), 32.0, 14.0, Color(1, 1, 1, 0.9))
			_spikes(self, 4, 6.0, 22.0, 2.0, Color(hot, 0.8), PI / 4)
			draw_arc(Vector2(8, 0), 17.0, 0, TAU, 28, Color(hot, 0.95), 3.5, true)
		2:
			_glow(self, Vector2(10, 0), 28.0, Color(c, 0.5))
			draw_arc(Vector2(10, 0), 25.0, 0, TAU, 32, Color(hot, 0.75), 2.8, true)
			_flare(self, Vector2(10, 0), 16.0, 7.0, Color(1, 1, 1, 0.7))
		3:
			draw_arc(Vector2(12, 0), 32.0, 0, TAU, 32, Color(c, 0.45), 2.0, true)
			_glow(self, Vector2(10, 0), 14.0, Color(c, 0.35))
		_:
			draw_arc(Vector2(12, 0), 37.0 + f * 2.0, 0, TAU, 32, Color(c, 0.18), 1.2, true)


# --- beam rifle: hit ------------------------------------------------------------------------------

func _draw_impact(f: int) -> void:
	var c := color
	var hot := c.lightened(0.45)
	match f:
		0:
			_glow(self, Vector2.ZERO, 52.0, Color(c, 0.9))
			_flare(self, Vector2.ZERO, 40.0, 40.0, Color(1, 1, 1, 0.95))
			_spikes(self, 4, 4.0, 26.0, 3.0, Color(1, 1, 1, 0.7), PI / 4)
			draw_circle(Vector2.ZERO, 16.0, Color.WHITE)
		1:
			_glow(self, Vector2.ZERO, 46.0, Color(c, 0.65))
			draw_circle(Vector2.ZERO, 10.0, Color(1, 1, 1, 0.9))
			_spikes(self, 8, 12.0, 38.0, 3.5, Color(hot, 0.85), 0.2)
			draw_arc(Vector2.ZERO, 24.0, 0, TAU, 32, Color(hot, 1.0), 5.0, true)
		2:
			_glow(self, Vector2.ZERO, 36.0, Color(c, 0.4))
			_spikes(self, 8, 26.0, 46.0, 2.0, Color(hot, 0.5), 0.2)
			draw_arc(Vector2.ZERO, 34.0, 0, TAU, 36, Color(hot, 0.8), 3.4, true)
		3:
			draw_arc(Vector2.ZERO, 42.0, 0, TAU, 40, Color(c, 0.55), 2.2, true)
			_glow(self, Vector2.ZERO, 20.0, Color(c, 0.35))
		4:
			draw_arc(Vector2.ZERO, 48.0, 0, TAU, 40, Color(c, 0.28), 1.5, true)
			_glow(self, Vector2.ZERO, 16.0, Color(c, 0.28))
		_:
			# A little heat glow left where it hit.
			_glow(self, Vector2.ZERO, 13.0, Color(c, 0.26 * (1.0 - (f - 5) / 3.0)))
	# Hex shards flung out, spinning.
	if f >= 1 and f <= 4:
		for s: Array in _shards:
			var d: float = s[1] * _t
			var p := Vector2.from_angle(s[0]) * d
			var r: float = s[2] * _t
			var pts := PackedVector2Array()
			for k in 6:
				pts.append(p + Vector2.from_angle(r + k * TAU / 6.0) * 3.2)
			draw_colored_polygon(pts, Color(hot, 0.85 * (1.0 - f / 5.0)))
	_draw_sparks(Color.WHITE, c, 2.0)


func _draw_sparks(from_col: Color, to_col: Color, width: float) -> void:
	var fade := clampf(1.0 - _t / (FRAMES[kind] / FPS), 0.0, 1.0)
	for b: Array in _bits:
		var p: Vector2 = b[0]
		var v: Vector2 = b[1]
		if v.length() > 20.0:
			var tail: Vector2 = p - v.normalized() * float(b[2]) * (0.4 + fade)
			draw_line(tail, p, Color(from_col.lerp(to_col, 1.0 - fade), fade), width, true)


# --- gatling --------------------------------------------------------------------------------------

func _draw_gat_muzzle(f: int) -> void:
	var a := 1.0 if f == 0 else 0.55
	_glow(self, Vector2(10, 0), 30.0 if f == 0 else 20.0, Color(1.0, 0.6, 0.2, 0.85 * a))
	match variant:
		0:
			_flare(self, Vector2(10, 0), 34.0, 12.0, Color(1, 0.95, 0.75, a))
			_spikes(self, 6, 4.0, 18.0, 2.4, Color(1.0, 0.7, 0.3, 0.8 * a), 0.5)
		1:
			# Muzzle brake: side jets.
			draw_colored_polygon(PackedVector2Array([Vector2(4, -3), Vector2(30, 0), Vector2(4, 3)]), Color(1, 0.95, 0.8, a))
			for s in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(2, 0), Vector2(8, 16 * s), Vector2(12, 0)]), Color(1.0, 0.75, 0.35, 0.9 * a))
		_:
			_spikes(self, 5, 3.0, 26.0, 3.0, Color(1, 0.9, 0.6, a), randf() * TAU)
			draw_colored_polygon(PackedVector2Array([Vector2(4, -4), Vector2(24, 0), Vector2(4, 4)]), Color(1, 1, 0.9, a))
	draw_circle(Vector2(8, 0), 6.0 if f == 0 else 3.5, Color(1, 1, 0.95, a))


func _draw_gat_impact(f: int) -> void:
	if f <= 1:
		_glow(self, Vector2.ZERO, 22.0 if f == 0 else 14.0, Color(1.0, 0.65, 0.25, 0.85))
		draw_circle(Vector2.ZERO, 6.0 if f == 0 else 3.0, Color(1, 1, 0.9))
		_spikes(self, 6, 3.0, 14.0, 1.8, Color(1, 0.85, 0.5, 0.8), randf() * TAU)
	_draw_sparks(Color(1, 1, 0.85), Color(1.0, 0.45, 0.1), 1.6)


# --- dual pistols ---------------------------------------------------------------------------------

func _draw_pistol_muzzle(f: int) -> void:
	var c := color
	match f:
		0:
			_glow(self, Vector2(5, 0), 22.0, Color(c, 0.9))
			_flare(self, Vector2(5, 0), 20.0, 8.0, Color(1, 1, 1, 0.95))
			draw_circle(Vector2(5, 0), 5.0, Color.WHITE)
		1:
			_glow(self, Vector2(6, 0), 14.0, Color(c, 0.55))
			draw_arc(Vector2(6, 0), 9.0, 0, TAU, 20, Color(c.lightened(0.4), 0.8), 2.0, true)
		_:
			draw_arc(Vector2(7, 0), 13.0, 0, TAU, 20, Color(c, 0.3), 1.2, true)
