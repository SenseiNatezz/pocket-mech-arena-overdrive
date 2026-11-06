extends Node2D
## VX-9 Bulwark SIEGE MODE marker: anchor clamps and a slowly turning ring under the mech while it's
## braced (Mech.siege_k: 0 = mobile, 1 = fully braced).

var mech: Mech
var _t := 0.0


func _ready() -> void:
	z_index = -1


func _process(delta: float) -> void:
	_t += delta
	visible = mech.siege_k > 0.01 and not mech.dead
	if visible:
		queue_redraw()


func _draw() -> void:
	var k := mech.siege_k
	var col: Color = Color(1.0, 0.65, 0.3)
	var r := 46.0 * mech.body.scale.x
	draw_circle(Vector2.ZERO, r, Color(col, 0.08 * k))
	draw_arc(Vector2.ZERO, r, _t * 0.8, _t * 0.8 + TAU * 0.8 * k, 40, Color(col, 0.7 * k), 3.0, true)
	# Four anchor clamps that slide out as the mech braces.
	for i in 4:
		var d := Vector2.from_angle(PI / 4 + i * PI / 2)
		var p := d * (r * 0.55 + r * 0.45 * k)
		var s := d.orthogonal() * 6.0
		draw_colored_polygon(PackedVector2Array([p + s, p + d * 10.0, p - s, p - d * 4.0]), Color(col.lightened(0.2), k))
