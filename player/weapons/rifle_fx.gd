class_name RifleFx
extends Node2D
## Beam Rifle effects, Gundam style: light, not ink. Everything is drawn additively, so the beam glows over
## any floor, and in the pilot's energy colour (pink by default, the classic Gundam beam):
##   RifleFx.draw_bolt(ci, frame, color, seed)   the shot: a thick glowing beam bolt - pointed white-hot
##                                               core, a saturated shell, a soft bloom, a short tail that
##                                               fades out behind it, and a bright head
##   RifleFx.muzzle(parent, dir, color)          the barrel flash: a white core flash and a four-point
##                                               lens-flare star, then a ring opening out (follows the barrel)
##   RifleFx.impact(pos, dir, color, size)       the hit: a white flash that opens into a coloured ring,
##                                               spark streaks spraying off
## All shapes point along +x (the bolt's / burst's direction). Original drawings, written in code. Shapes
## step at FPS drawings a second, like cel animation.

enum Kind { MUZZLE, IMPACT }

const FPS := 24.0
const MUZZLE_FRAMES := 5
const IMPACT_FRAMES := 6
## Hits land ~9 times a second on one target, so bursts stay a little smaller than the drawings.
const IMPACT_SCALE := 0.85
## Beam length behind the tip (px, at bolt size 1), and its half-width. The tip sits just ahead of the hit
## circle.
const BOLT_LENGTH := 92.0
const BOLT_HALF_WIDTH := 6.5
const GLOW := preload("res://assets/fx/glow.tres")
## Shared additive material (bolts set it on their Bullet while rifle-styled).
static var _add: CanvasItemMaterial

var kind := Kind.IMPACT
var color := Color.WHITE
var size := 1.0
var _t := 0.0
var _frame := -1
## Impact sparks: [position, velocity, length] in local space.
var _bits: Array = []


static func additive() -> CanvasItemMaterial:
	if _add == null:
		_add = CanvasItemMaterial.new()
		_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _add


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
	# Sparks streak out, mostly back toward the shooter and to the sides.
	for i in 7:
		var a := PI + randf_range(-1.9, 1.9)
		fx._bits.append([Vector2.ZERO, Vector2.from_angle(a) * randf_range(260.0, 520.0), randf_range(8.0, 16.0)])
	Combat.world().add_child(fx)


func _ready() -> void:
	material = additive()


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

## Four-point lens-flare star: arms `along` long on the x axis and `across` on the y axis.
static func _flare(ci: CanvasItem, p: Vector2, along: float, across: float, col: Color) -> void:
	var t := minf(along, across) * 0.16
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(along, 0), p + Vector2(t, t), p + Vector2(0, across),
		p + Vector2(-t, t), p + Vector2(-along, 0), p + Vector2(-t, -t), p + Vector2(0, -across), p + Vector2(t, -t)]), col)


## Soft round glow (the shared radial gradient texture) of radius `r`.
static func _glow(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(GLOW, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


## A beam bolt layer: pointed at the head (+x), `w` half-wide, fading from `head` to `tail` colour over
## `l` px behind it.
static func _bolt_shape(ci: CanvasItem, l: float, w: float, head: Color, tail: Color) -> void:
	var mid := head.lerp(tail, 0.45)
	ci.draw_polygon(PackedVector2Array([Vector2(w * 1.7, 0), Vector2(w * 0.2, -w), Vector2(-l * 0.45, -w * 0.8),
		Vector2(-l, 0), Vector2(-l * 0.45, w * 0.8), Vector2(w * 0.2, w)]),
		PackedColorArray([head, head, mid, tail, mid, head]))


# --- the bolt -------------------------------------------------------------------------------------

## Draws one frame of the rifle shot on `ci` (a Bullet using additive(); +x = forward, origin = the hit
## circle). `frame` steps at FPS (a faint width flicker); `reach` = how far the beam has come out of the
## barrel (it grows out of it instead of appearing at full length inside the mech).
static func draw_bolt(ci: CanvasItem, frame: int, col: Color, _seed: int, reach := INF) -> void:
	var flick: float = [1.0, 0.9, 1.08, 0.95][frame % 4]
	var w := BOLT_HALF_WIDTH * flick
	var l := minf(BOLT_LENGTH, maxf(reach + 16.0, 24.0))
	var clear := Color(col, 0.0)
	# Soft bloom, the coloured shell, then the white-hot core.
	_bolt_shape(ci, l * 1.1, w * 2.4, Color(col, 0.35), clear)
	_bolt_shape(ci, l, w, Color(col.lightened(0.2), 0.95), clear)
	_bolt_shape(ci, l * 0.8, w * 0.42, Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	# Bright head.
	_glow(ci, Vector2(3, 0), w * 3.4, Color(col.lightened(0.3), 0.75))
	ci.draw_circle(Vector2(3, 0), w * 0.6, Color.WHITE)


# --- muzzle: beam ignition ------------------------------------------------------------------------

func _draw_muzzle(f: int) -> void:
	var c := color
	match f:
		0:
			_glow(self, Vector2(6, 0), 34.0, Color(c, 0.9))
			_flare(self, Vector2(6, 0), 34.0, 18.0, Color(1, 1, 1, 1))
			draw_circle(Vector2(6, 0), 9.0, Color.WHITE)
		1:
			_glow(self, Vector2(8, 0), 30.0, Color(c, 0.7))
			_flare(self, Vector2(8, 0), 26.0, 12.0, Color(1, 1, 1, 0.9))
			draw_arc(Vector2(8, 0), 15.0, 0, TAU, 28, Color(c.lightened(0.4), 0.95), 3.0, true)
		2:
			_glow(self, Vector2(10, 0), 22.0, Color(c, 0.45))
			draw_arc(Vector2(10, 0), 22.0, 0, TAU, 32, Color(c.lightened(0.3), 0.7), 2.5, true)
			_flare(self, Vector2(10, 0), 14.0, 6.0, Color(1, 1, 1, 0.7))
		3:
			draw_arc(Vector2(12, 0), 28.0, 0, TAU, 32, Color(c, 0.4), 1.8, true)
		_:
			draw_arc(Vector2(12, 0), 32.0, 0, TAU, 32, Color(c, 0.18), 1.2, true)


# --- impact: beam hit -----------------------------------------------------------------------------

func _draw_impact(f: int) -> void:
	var c := color
	match f:
		0:
			_glow(self, Vector2.ZERO, 40.0, Color(c, 0.85))
			_flare(self, Vector2.ZERO, 30.0, 30.0, Color(1, 1, 1, 0.95))
			draw_circle(Vector2.ZERO, 14.0, Color.WHITE)
		1:
			_glow(self, Vector2.ZERO, 36.0, Color(c, 0.6))
			draw_circle(Vector2.ZERO, 8.0, Color(1, 1, 1, 0.9))
			draw_arc(Vector2.ZERO, 22.0, 0, TAU, 32, Color(c.lightened(0.45), 1.0), 4.5, true)
		2:
			_glow(self, Vector2.ZERO, 30.0, Color(c, 0.35))
			draw_arc(Vector2.ZERO, 32.0, 0, TAU, 36, Color(c.lightened(0.3), 0.8), 3.0, true)
		3:
			draw_arc(Vector2.ZERO, 40.0, 0, TAU, 40, Color(c, 0.5), 2.0, true)
		_:
			draw_arc(Vector2.ZERO, 46.0, 0, TAU, 40, Color(c, 0.22), 1.4, true)
	# Spark streaks along their motion, cooling from white to the beam colour.
	var fade := clampf(1.0 - _t / (IMPACT_FRAMES / FPS), 0.0, 1.0)
	for b: Array in _bits:
		var p: Vector2 = b[0]
		var v: Vector2 = b[1]
		if v.length() > 20.0:
			var tail: Vector2 = p - v.normalized() * float(b[2]) * (0.4 + fade)
			draw_line(tail, p, Color(Color.WHITE.lerp(c, 1.0 - fade), fade), 2.0, true)
