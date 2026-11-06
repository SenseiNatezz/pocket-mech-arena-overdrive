extends Node2D
## Telegraphed artillery strike: a red warning circle fills up for `delay` seconds (about 1 s), then
## the shell lands and explodes. Spawned through Combat.artillery() by heavy tanks, the boss and the
## arena bombardment hazard. Optionally draws the shell arcing in from `from`.
## `lightning` (Endless CRYSTAL STORM twist): tinted `tint`, and the strike lands as a jagged bolt from
## the sky instead of an explosion colour of its own.

var radius := 70.0
var damage := 20.0
var source: Node
var delay := 1.0
var hurts := "player"
var from := Vector2.INF
var tint := Color(1.0, 0.15, 0.05)
var lightning := false
var _t := 0.0


func setup(pos: Vector2, r: float, dmg: float, src: Node, d: float, who: String, origin: Vector2) -> void:
	global_position = pos
	radius = r
	damage = dmg
	source = src
	delay = maxf(d, 0.2)
	hurts = who
	from = origin
	z_index = -8  # under characters (the Combat container itself is +5)


func _process(delta: float) -> void:
	_t += delta
	if _t >= delay:
		Combat.explode(global_position, radius, damage, source if is_instance_valid(source) else null, hurts,
			tint.lightened(0.3) if lightning else Color(1.0, 0.4, 0.2), 300.0)
		if lightning:
			var bolt := LightningBolt.new()
			bolt.global_position = global_position
			bolt.color = tint
			get_parent().add_child(bolt)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / delay
	var pulse := 0.5 + 0.5 * sin(_t * 26.0)
	draw_circle(Vector2.ZERO, radius, Color(tint, 0.10 + 0.08 * pulse))
	draw_circle(Vector2.ZERO, radius * k, Color(tint, 0.22))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(tint.lightened(0.05), 0.9), 3.0, true)
	draw_arc(Vector2.ZERO, radius * k, 0, TAU, 40, Color(tint.lightened(0.45), 0.8), 2.0, true)
	for i in 4:
		var a := i * PI / 2 + _t * 1.5
		draw_line(Vector2.from_angle(a) * radius * 0.25, Vector2.from_angle(a) * radius * 0.55, Color(tint.lightened(0.15), 0.8), 3.0)
	if from != Vector2.INF:
		# Shell arcing in (drawn in this node's local space).
		var start := from - global_position
		var p := start.lerp(Vector2.ZERO, k)
		var height := sin(k * PI) * (180.0 + start.length() * 0.25)
		var shell := p - Vector2(0, height)
		draw_circle(p, 6.0 * (0.4 + 0.6 * k), Color(0, 0, 0, 0.35))
		draw_circle(shell, 9.0, Color(1.0, 0.45, 0.15, 0.35))
		draw_circle(shell, 5.0, Color(1.0, 0.85, 0.5))


## A jagged lightning bolt from high above down to the strike point (re-rolled each frame), fading fast.
class LightningBolt:
	extends Node2D
	var color := Color(0.75, 0.45, 1.0)
	var _t := 0.0
	const LIFE := 0.35

	func _ready() -> void:
		z_index = 8
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _process(delta: float) -> void:
		_t += delta
		if _t >= LIFE:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var fade := 1.0 - _t / LIFE
		var pts := PackedVector2Array()
		var top := Vector2(randf_range(-60.0, 60.0), -520.0)
		for i in 13:
			var k := i / 12.0
			pts.append(top.lerp(Vector2.ZERO, k) + Vector2(randf_range(-22.0, 22.0) * (1.0 - k * 0.8), 0.0))
		pts[pts.size() - 1] = Vector2.ZERO
		draw_polyline(pts, Color(color, 0.45 * fade), 12.0, true)
		draw_polyline(pts, Color(color.lightened(0.4), 0.9 * fade), 4.0, true)
		draw_polyline(pts, Color(1, 1, 1, fade), 1.5, true)
		draw_circle(Vector2.ZERO, 30.0 * fade + 10.0, Color(color, 0.4 * fade))
