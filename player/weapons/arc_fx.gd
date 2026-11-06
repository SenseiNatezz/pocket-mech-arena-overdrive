extends Node2D
## Arc Emitter lightning: a jagged bolt between two points (global), flickering for a moment.

const LIFE := 0.18

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color(0.6, 0.8, 1.0)
var _t := 0.0
var _pts := PackedVector2Array()


func _ready() -> void:
	z_index = 6
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_jag()


func _jag() -> void:
	_pts.clear()
	var n := maxi(3, int(from.distance_to(to) / 22.0))
	var side := (to - from).normalized().orthogonal()
	for i in n + 1:
		var k := float(i) / n
		var off := 0.0 if i == 0 or i == n else randf_range(-12.0, 12.0)
		_pts.append(from.lerp(to, k) + side * off)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	if Engine.get_process_frames() % 2 == 0:
		_jag()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / LIFE
	draw_polyline(_pts, Color(color, 0.35 * a), 7.0, true)
	draw_polyline(_pts, Color(color.lightened(0.5), 0.95 * a), 2.0, true)
