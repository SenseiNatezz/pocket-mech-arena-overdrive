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
	# Ground ring: dim track + cooldown arc (amber) or full ring when ready, in the chassis colour and
	# scaled with the frame (Hangar chassis: Striker teal, Bulwark orange, with notches on the ring).
	var ch: Dictionary = Game.chassis_info()
	var R: float = RADIUS * float(ch["scale"])
	var ready_col: Color = Color(0.35, 0.85, 1.0) if ch["id"] == &"standard" else ch["color"]
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 48, Color(0.1, 0.2, 0.3, 0.45), 5.0, true)
	if is_ready:
		draw_arc(Vector2.ZERO, R, 0.0, TAU, 48, Color(ready_col, 0.55 + 0.45 * _ready_flash), 3.0 + 3.0 * _ready_flash, true)
	else:
		draw_arc(Vector2.ZERO, R, -PI / 2, -PI / 2 + TAU * frac, 48, Color(1.0, 0.7, 0.25, 0.9), 5.0, true)
	if ch["id"] != &"standard":
		for i in 4:
			var a := TAU * i / 4.0 + PI / 4.0
			draw_line(Vector2.from_angle(a) * (R - 6.0), Vector2.from_angle(a) * (R + 6.0), Color(ready_col, 0.9), 4.0)
	# Aim chevron on the ring.
	var d := mech.aim_dir
	var tip := d * (R + 16.0)
	var side := d.orthogonal() * 8.0
	draw_colored_polygon(PackedVector2Array([tip, d * (R + 4.0) + side, d * (R + 4.0) - side]),
		Color(1.0, 0.9, 0.5, 0.9) if mech.overdrive_left > 0.0 else Color(0.5, 0.9, 1.0, 0.9))
