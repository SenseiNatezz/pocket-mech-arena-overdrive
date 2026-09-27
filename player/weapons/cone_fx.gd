extends Node2D
## Magma Cone visual: a flat, flickering fan of fire that sweeps out and fades.

const LIFE := 0.35
const HALF_ANGLE := 0.61  # ~35 degrees

var origin := Vector2.ZERO
var dir := Vector2.RIGHT
var reach := 270.0
var _t := 0.0


func _ready() -> void:
	z_index = 4
	global_position = origin


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var r := reach * ease(minf(k * 1.8, 1.0), 0.4)
	var fade := 1.0 - k
	for layer in [[1.0, Color(1.0, 0.3, 0.05, 0.45)], [0.75, Color(1.0, 0.55, 0.1, 0.6)], [0.45, Color(1.0, 0.9, 0.5, 0.8)]]:
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			var a := dir.angle() - HALF_ANGLE + HALF_ANGLE * 2.0 * i / 12.0
			pts.append(Vector2.from_angle(a) * r * layer[0] * randf_range(0.9, 1.05))
		var c: Color = layer[1]
		draw_colored_polygon(pts, Color(c, c.a * fade))
