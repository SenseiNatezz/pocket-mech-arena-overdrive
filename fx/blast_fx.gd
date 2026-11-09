class_name BlastFx
extends Node2D
## Explosion pieces, drawn in code (Combat.explosion_fx and robot deaths use them):
##   BlastFx.fireball(pos, r)          a white flash that blooms into a lumpy fireball (several glowing
##                                     lobes swelling and cooling yellow -> orange -> deep red), with
##                                     burning bits arcing out (additive light)
##   BlastFx.smoke(pos, r, n)          a dark smoke column: `n` puffs drifting out and up (SmokePuff)
##   BlastFx.scorch(pos, r, burning)   a scorch mark on the floor (dark blotch + soot streaks, under the
##                                     robots) that fades after a few seconds; `burning` adds small flames
##                                     flickering on it for a while
##   BlastFx.robot_death(pos, r, big)  the extras for a destroyed robot (see there); big ones also go
##                                     off in a short chain of secondary blasts

const GLOW := preload("res://assets/fx/glow.tres")
const LIFE := 0.6
## Set by the arena on very bright floors (Frozen Outpost ice): scorch marks become cool grey soot, since
## black blotches on white ice read as ink splats.
static var pale_floor := false

var radius := 40.0
var _t := 0.0
var _lobes: Array = []   # [offset dir, distance k, size k, delay]
var _bits: Array = []    # [pos, vel]


static func fireball(pos: Vector2, r: float) -> void:
	var f := BlastFx.new()
	f.radius = r
	f.global_position = pos
	f.z_index = 6
	for i in 7:
		f._lobes.append([Vector2.from_angle(randf() * TAU), randf_range(0.15, 0.6), randf_range(0.55, 1.0), randf_range(0.0, 0.08)])
	for i in 6:
		f._bits.append([Vector2.ZERO, Vector2.from_angle(randf() * TAU) * randf_range(180.0, 380.0) * (0.6 + r / 120.0)])
	Combat.world().add_child(f)


static func smoke(pos: Vector2, r: float, n: int) -> void:
	for i in n:
		var d := Vector2.from_angle(randf() * TAU)
		SmokePuff.spawn(pos + d * r * randf_range(0.0, 0.4), Color(0.16, 0.15, 0.15, randf_range(0.45, 0.6)),
			r * randf_range(0.7, 1.15), randf_range(1.1, 1.9), d * randf_range(20.0, 60.0) + Vector2(0, -randf_range(20.0, 45.0)), 4)


static func scorch(pos: Vector2, r: float, burning := false) -> void:
	var s := Scorch.new()
	s.radius = r
	s.burning = burning
	s.global_position = pos
	Combat.world().add_child(s)


## The extras on top of Combat.explosion_fx for a destroyed robot: a scorch mark (burning for big ones),
## and for big robots / elites a heavier smoke column, a chain of secondary blasts, a deep boom with
## metal debris, a quick camera punch-in and a rumble.
static func robot_death(pos: Vector2, r: float, big: bool) -> void:
	scorch(pos, r * 1.25, big)
	if big:
		smoke(pos, r * 0.9, 4)
		Sfx.play(&"death_boom", -4.0, 0.08)
		Combat.camera_punch(0.05)
		Combat.rumble(0.5, 0.8, 0.3)
		# A short chain of secondary blasts around the wreck.
		var tree := Combat.get_tree()
		for i in 3:
			var at := pos + Vector2.from_angle(randf() * TAU) * r * randf_range(0.5, 1.0)
			tree.create_timer(0.12 + i * 0.13, false).timeout.connect(func() -> void:
				fireball(at, r * randf_range(0.55, 0.75))
				Combat.spark(at, Color(1.0, 0.7, 0.3), r / 30.0)
				Sfx.play(&"explode", -12.0, 0.2))


func _ready() -> void:
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	for b: Array in _bits:
		b[0] += b[1] * delta
		b[1] *= exp(-4.0 * delta)
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	# Opening flash.
	if _t < 0.08:
		var a := 1.0 - _t / 0.08
		draw_texture_rect(GLOW, Rect2(Vector2.ONE * -radius * 1.6, Vector2.ONE * radius * 3.2), false, Color(1, 0.95, 0.8, a))
		draw_circle(Vector2.ZERO, radius * 0.45 * (0.6 + a * 0.4), Color(1, 1, 0.95, a))
	# Lobes swelling and cooling.
	for l: Array in _lobes:
		var lt := clampf((_t - float(l[3])) / (LIFE - float(l[3])), 0.0, 1.0)
		if lt <= 0.0:
			continue
		var grow := 1.0 - pow(1.0 - lt, 2.5)
		var p: Vector2 = (l[0] as Vector2) * radius * float(l[1]) * (0.5 + grow)
		var rr: float = radius * float(l[2]) * (0.35 + 0.75 * grow)
		var col := Color(1.0, 0.92, 0.55).lerp(Color(1.0, 0.45, 0.1), smoothstep(0.0, 0.45, lt)) \
			.lerp(Color(0.55, 0.08, 0.02), smoothstep(0.45, 1.0, lt))
		draw_texture_rect(GLOW, Rect2(p - Vector2(rr, rr), Vector2(rr, rr) * 2.0), false, Color(col, 0.95 * (1.0 - lt * lt)))
	# Burning bits.
	for b: Array in _bits:
		var v: Vector2 = b[1]
		if v.length() > 15.0:
			var p: Vector2 = b[0]
			draw_line(p - v.normalized() * 9.0, p, Color(1.0, 0.7, 0.3, 1.0 - k), 2.2, true)
			draw_circle(p, 2.0, Color(1.0, 0.9, 0.6, 1.0 - k))


## Scorch mark on the floor (drawn under the robots), with optional small flames for a few seconds.
class Scorch:
	extends Node2D
	const LIFE := 7.0
	const FADE := 2.0
	const BURN := 3.2
	var radius := 40.0
	var burning := false
	var _t := 0.0
	var _streaks: Array = []
	var _flames: Array = []
	var _fire: Node2D

	func _ready() -> void:
		z_as_relative = false
		z_index = -7
		rotation = randf() * TAU
		for i in 11:
			_streaks.append([randf() * TAU, randf_range(0.75, 1.2), randf_range(1.0, 2.2)])
		if burning:
			for i in 4:
				_flames.append([Vector2.from_angle(randf() * TAU) * radius * randf_range(0.0, 0.55), randf() * 10.0, randf_range(0.7, 1.2)])
			_fire = FireLayer.new()
			_fire.scorch = self
			add_child(_fire)

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()
		if _fire:
			_fire.queue_redraw()

	func _draw() -> void:
		var a := clampf((LIFE - _t) / FADE, 0.0, 1.0) * minf(_t / 0.1, 1.0)
		var pale := BlastFx.pale_floor
		var outer := Color(0.2, 0.25, 0.33, 0.34) if pale else Color(0, 0, 0, 0.55)
		var inner := Color(0.16, 0.17, 0.2, 0.32) if pale else Color(0.05, 0.03, 0.02, 0.5)
		var soot := Color(0.18, 0.2, 0.26, 0.14) if pale else Color(0.04, 0.03, 0.03, 0.2)
		draw_texture_rect(BlastFx.GLOW, Rect2(Vector2.ONE * -radius * 1.3, Vector2.ONE * radius * 2.6), false, Color(outer, outer.a * a))
		draw_texture_rect(BlastFx.GLOW, Rect2(Vector2.ONE * -radius * 0.7, Vector2.ONE * radius * 1.4), false, Color(inner, inner.a * a))
		for s: Array in _streaks:
			var d := Vector2.from_angle(s[0])
			draw_line(d * radius * 0.45, d * radius * float(s[1]), Color(soot, soot.a * a), float(s[2]), true)
		# Embers still glowing in the char for a moment.
		var glow := clampf(1.0 - _t / 2.5, 0.0, 1.0)
		if glow > 0.0:
			draw_texture_rect(BlastFx.GLOW, Rect2(Vector2.ONE * -radius * 0.5, Vector2.ONE * radius), false, Color(1.0, 0.35, 0.08, 0.35 * glow))

	## Flames on the scorch: additive, flickering tongues of fire that die down.
	class FireLayer:
		extends Node2D
		var scorch: Node2D

		func _ready() -> void:
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			material = add
			z_as_relative = false
			z_index = 3

		func _draw() -> void:
			var t: float = scorch._t
			var life := clampf(1.0 - t / Scorch.BURN, 0.0, 1.0)
			if life <= 0.0:
				return
			# Undo the scorch's random rotation so flames rise up the screen.
			draw_set_transform(Vector2.ZERO, -scorch.rotation)
			for f: Array in scorch._flames:
				var p: Vector2 = (f[0] as Vector2).rotated(scorch.rotation)
				var ph: float = t * 9.0 + float(f[1])
				var h: float = (14.0 + 6.0 * sin(ph)) * float(f[2]) * (0.4 + 0.6 * life)
				var w: float = 6.0 * float(f[2]) * (0.5 + 0.5 * life)
				var sway := sin(ph * 0.7) * 3.0
				draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(sway, -h), p + Vector2(w, 0)]),
					Color(1.0, 0.45, 0.1, 0.75 * life))
				draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.5, 0), p + Vector2(sway * 0.6, -h * 0.6), p + Vector2(w * 0.5, 0)]),
					Color(1.0, 0.85, 0.45, 0.85 * life))
				draw_texture_rect(BlastFx.GLOW, Rect2(p - Vector2(w * 2.0, w * 2.4), Vector2(w * 4.0, w * 3.6)), false, Color(1.0, 0.4, 0.1, 0.3 * life))
			draw_set_transform(Vector2.ZERO)
