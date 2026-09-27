extends Control
## Floating twin-stick joystick for touch screens.
##   side = LEFT  -> writes Controls.touch_move
##   side = RIGHT -> writes Controls.touch_aim and holds fire_primary while pushed past FIRE_THRESHOLD
## The stick appears where your thumb lands inside its half of the screen (not on a touch button)
## and rests at its home position otherwise.

enum Side { LEFT, RIGHT }

@export var side := Side.LEFT
@export var radius := 80.0

const DEADZONE := 0.12
const FIRE_THRESHOLD := 0.35

var _touch := -1
var _origin := Vector2.ZERO  # in this control's local space
var _knob := Vector2.ZERO
var _firing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_origin = size / 2


func _input(event: InputEvent) -> void:
	if Controls.ignore_real_input or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and _touch == -1 and _in_zone(event.position) and not _on_button(event.position):
			_touch = event.index
			_origin = event.position - global_position
			_update(event.position)
		elif not event.pressed and event.index == _touch:
			_release()
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(event.position)


## Left or right ~45% of the screen, lower 85%.
func _in_zone(pos: Vector2) -> bool:
	var vp := get_viewport_rect().size
	if pos.y < vp.y * 0.15:
		return false
	return pos.x < vp.x * 0.45 if side == Side.LEFT else pos.x > vp.x * 0.55


func _on_button(pos: Vector2) -> bool:
	for b: Control in get_tree().get_nodes_in_group("touch_button"):
		if b.is_visible_in_tree() and b.get_global_rect().grow(8).has_point(pos):
			return true
	return false


func _update(pos: Vector2) -> void:
	_knob = (pos - global_position - _origin).limit_length(radius)
	var v := _knob / radius
	if v.length() < DEADZONE:
		v = Vector2.ZERO
	if side == Side.LEFT:
		Controls.touch_move = v
	else:
		Controls.touch_aim = v
		var should_fire := v.length() > FIRE_THRESHOLD
		if should_fire != _firing:
			_firing = should_fire
			if _firing:
				Input.action_press("fire_primary")
			else:
				Input.action_release("fire_primary")
	queue_redraw()


func _release() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	_origin = size / 2
	if side == Side.LEFT:
		Controls.touch_move = Vector2.ZERO
	else:
		Controls.touch_aim = Vector2.ZERO
		if _firing:
			_firing = false
			Input.action_release("fire_primary")
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		if _touch != -1:
			_release()


func _draw() -> void:
	var active := _touch != -1
	var accent := Color(0.4, 0.8, 1.0) if side == Side.LEFT else Color(1.0, 0.55, 0.3)
	draw_circle(_origin, radius + 12, Color(0.03, 0.06, 0.12, 0.35 if active else 0.2))
	draw_arc(_origin, radius + 12, 0, TAU, 56, Color(accent, 0.6 if active else 0.3), 3.0, true)
	if side == Side.RIGHT:
		# Fire threshold ring.
		draw_arc(_origin, radius * FIRE_THRESHOLD, 0, TAU, 32, Color(accent, 0.25), 2.0, true)
	draw_circle(_origin + _knob, 34, Color(accent.lightened(0.3), 0.5 if active else 0.3))
	draw_arc(_origin + _knob, 34, 0, TAU, 40, Color(1, 1, 1, 0.55), 2.0, true)
	var font := get_theme_default_font()
	var label := "MOVE" if side == Side.LEFT else "AIM + FIRE"
	draw_string(font, _origin + Vector2(-60, radius + 34), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1, 0.45))
