extends Node2D
## Ring drawn on the ground around the mech: fills as the boost recharges, flashes when ready,
## plus a small aim chevron so gamepad/touch players can see where they're aiming.

const RADIUS := 44.0

var _ready_flash := 0.0
var _was_ready := true


func _draw() -> void:
	var mech := get_parent() as Mech
	if mech == null or mech.dead:
		return
	var frac := mech.boost_ready_fraction()
	var is_ready := frac >= 1.0
	if is_ready and not _was_ready:
		_ready_flash = 1.0
	_was_ready = is_ready
	_ready_flash = move_toward(_ready_flash, 0.0, 0.08)
	# Ground ring: dim track + cooldown arc (cyan) or full ring when ready.
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(0.1, 0.2, 0.3, 0.45), 5.0, true)
	if is_ready:
		draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 48, Color(0.35, 0.85, 1.0, 0.55 + 0.45 * _ready_flash), 3.0 + 3.0 * _ready_flash, true)
	else:
		draw_arc(Vector2.ZERO, RADIUS, -PI / 2, -PI / 2 + TAU * frac, 48, Color(1.0, 0.7, 0.25, 0.9), 5.0, true)
	# Aim chevron on the ring.
	var d := mech.aim_dir
	var tip := d * (RADIUS + 16.0)
	var side := d.orthogonal() * 8.0
	draw_colored_polygon(PackedVector2Array([tip, d * (RADIUS + 4.0) + side, d * (RADIUS + 4.0) - side]),
		Color(1.0, 0.9, 0.5, 0.9) if mech.overdrive_left > 0.0 else Color(0.5, 0.9, 1.0, 0.9))
