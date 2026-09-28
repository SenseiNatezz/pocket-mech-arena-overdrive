extends Node2D
## Defense Shield visual: a shimmering hex bubble around the mech while it has shield charges, one
## small pip per charge, and a burst when a charge breaks (`pop()`).

const RADIUS := 50.0

var mech: Mech
var _t := 0.0
var _pop := 0.0


func _ready() -> void:
	z_index = 3
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


func pop() -> void:
	_pop = 1.0


func _process(delta: float) -> void:
	_t += delta
	_pop = move_toward(_pop, 0.0, delta * 3.5)
	queue_redraw()


func _draw() -> void:
	if mech == null or mech.dead:
		return
	var col := Color(0.45, 0.85, 1.0)
	if _pop > 0.0:
		draw_arc(Vector2.ZERO, RADIUS * (1.0 + (1.0 - _pop) * 0.8), 0.0, TAU, 40, Color(1, 1, 1, _pop * 0.9), 4.0, true)
	if mech.shield_charges <= 0:
		return
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(col, 0.07 + 0.04 * pulse))
	# Hexagon frame, slowly turning.
	var hex := PackedVector2Array()
	for i in 7:
		hex.append(Vector2.from_angle(_t * 0.6 + TAU * i / 6.0) * RADIUS)
	draw_polyline(hex, Color(col, 0.35 + 0.2 * pulse), 2.0, true)
	draw_arc(Vector2.ZERO, RADIUS + 3.0, 0.0, TAU, 40, Color(col, 0.18), 2.0, true)
	# Charge pips under the mech.
	for i in mech.shield_charges:
		var p := Vector2((i - (mech.shield_charges - 1) / 2.0) * 12.0, RADIUS + 10.0)
		draw_circle(p, 4.0, Color(col.lightened(0.4), 0.9))
