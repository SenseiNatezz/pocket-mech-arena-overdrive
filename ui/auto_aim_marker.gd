extends Control
## Touch auto-aim lock-on marker: four corner brackets that snap in around Controls.auto_target and
## slowly turn. Lives under the touch controls, so it only shows when they do.

const SIZE := 44.0
const COLOR := Color(1.0, 0.35, 0.3)

var _target: Node2D
var _snap := 0.0
var _spin := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	var t: Node2D = Controls.auto_target if Controls.uses_auto_aim() else null
	if t != _target:
		_target = t
		_snap = 1.0
	_snap = move_toward(_snap, 0.0, delta * 7.0)
	_spin = fmod(_spin + delta * 1.2, TAU)
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_target):
		return
	var p := get_viewport().get_canvas_transform() * _target.global_position
	var r := SIZE * (1.0 + 0.9 * _snap)
	var col := Color(COLOR, 0.9 - 0.5 * _snap)
	draw_set_transform(p, _spin, Vector2.ONE)
	for i in 4:
		var a := i * PI / 2
		var corner := Vector2.from_angle(a + PI / 4) * r
		var along1 := Vector2.from_angle(a + PI / 4 + PI * 0.75) * 14.0
		var along2 := Vector2.from_angle(a + PI / 4 - PI * 0.75) * 14.0
		draw_polyline(PackedVector2Array([corner + along1, corner, corner + along2]), Color(0, 0, 0, 0.5), 6.0, true)
		draw_polyline(PackedVector2Array([corner + along1, corner, corner + along2]), col, 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(p, 3.5, col)
