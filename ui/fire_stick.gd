extends Control
## Big round FIRE button for touch screens (bottom-right, the ability buttons sit in an arc around it).
##   tap / hold        fires (Controls.touch_fire); the mech auto-aims at the nearest enemy on screen
##                     (Controls auto-aim, the target gets a lock-on marker)
##   drag off-centre   aims by hand in the drag direction while still firing (twin-stick style);
##                     slide back to the middle to hand aiming back to auto-aim
## The button shows the equipped weapon's art.

## Drag distance (px) that counts as a full push, and the fraction of it where hand-aiming starts.
const DRAG_RADIUS := 120.0
const AIM_START := 0.35

var _touch := -1
var _drag := Vector2.ZERO
var _pulse := 0.0
var _icon: Texture2D
var _icon_id := &""


func _ready() -> void:
	add_to_group("touch_button")
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _radius() -> float:
	return minf(size.x, size.y) / 2.0 - 4.0


func _input(event: InputEvent) -> void:
	if Controls.ignore_real_input or not is_visible_in_tree():
		return
	var c := get_global_rect().get_center()
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and event.position.distance_to(c) < _radius() + 14.0:
			_touch = event.index
			_drag = Vector2.ZERO
			_pulse = 1.0
			Controls.touch_aim = Vector2.ZERO
			Controls.touch_fire = true
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		_drag = (event.position - c).limit_length(DRAG_RADIUS)
		var v := _drag / DRAG_RADIUS
		Controls.touch_aim = v.normalized() if v.length() > AIM_START else Vector2.ZERO


func _release() -> void:
	_touch = -1
	_drag = Vector2.ZERO
	Controls.touch_aim = Vector2.ZERO
	Controls.touch_fire = false


func _notification(what: int) -> void:
	var gone := what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree())
	if gone and _touch != -1:
		_release()


func _process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 3.0)
	if Game.weapon != _icon_id:
		_icon_id = Game.weapon
		var path := "res://assets/hq/weapons/%s.png" % String(Game.weapon_info(Game.weapon).get("icon", "beam_rifle"))
		_icon = load(path) if ResourceLoader.exists(path) else null
	queue_redraw()


func _draw() -> void:
	var c := size / 2
	var r := _radius()
	var held := _touch != -1
	var hand_aim := held and _drag.length() > DRAG_RADIUS * AIM_START
	var accent := Game.energy_color()
	# Drag range (only while held) + the hand-aim direction.
	if held:
		draw_circle(c, DRAG_RADIUS + 18.0, Color(0.03, 0.05, 0.1, 0.22))
		draw_arc(c, DRAG_RADIUS + 18.0, 0, TAU, 64, Color(accent, 0.35), 2.0, true)
		draw_arc(c, (DRAG_RADIUS + 18.0) * AIM_START, 0, TAU, 40, Color(1, 1, 1, 0.18), 1.5, true)
	if hand_aim:
		var d := _drag.normalized()
		draw_line(c + d * (r + 6.0), c + d * (DRAG_RADIUS + 18.0), Color(accent.lightened(0.3), 0.9), 4.0, true)
	# The button: glow, dark body, accent rim, the weapon, a crosshair ring.
	var grow := 1.0 + 0.08 * _pulse
	draw_circle(c, r * grow + 8.0, Color(accent, 0.16 + (0.22 if held else 0.0)))
	draw_circle(c, r * grow, Color(0.06, 0.04, 0.1, 0.5))
	draw_circle(c, r * grow * 0.86, Color(accent.darkened(0.55), 0.55 if held else 0.38))
	draw_arc(c, r * grow, 0, TAU, 72, Color(accent.lightened(0.35), 1.0 if held else 0.8), 4.0 if held else 3.0, true)
	if _icon:
		var s := r * 1.15
		draw_set_transform(c, deg_to_rad(45.0), Vector2.ONE)
		var k := s / maxf(_icon.get_width(), _icon.get_height())
		var sz := Vector2(_icon.get_width(), _icon.get_height()) * k
		draw_texture_rect(_icon, Rect2(-sz / 2, sz), false, Color(1, 1, 1, 0.95 if held else 0.85))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for i in 4:
		var a := i * PI / 2 + PI / 4
		var dir := Vector2.from_angle(a)
		draw_line(c + dir * r * 0.62, c + dir * r * 0.78, Color(1, 1, 1, 0.5), 2.5, true)
	if hand_aim:
		draw_circle(c + _drag.limit_length(r * 0.55), 14.0, Color(1, 1, 1, 0.75))
	var font := get_theme_default_font()
	var label := "AIM" if hand_aim else "FIRE"
	var y := c.y + r * 0.72
	draw_string_outline(font, Vector2(0, y), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 4, Color(0, 0, 0, 0.85))
	draw_string(font, Vector2(0, y), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(1, 1, 1, 0.95))
