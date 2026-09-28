extends Control
## Round on-screen button that presses an Input Map action while touched (multi-touch safe).
## `indicator` draws live status on the button: boost cooldown ring, heat cost fill, repair
## charges, overdrive meter, or (for USE) only shows the button when something is in range.

enum Indicator { NONE, BOOST_COOLDOWN, HEAT_COST_NOVA, HEAT_COST_CONE, REPAIR_CHARGES, OVERDRIVE_METER, USE_CONTEXT, BEAM_COOLDOWN }

@export var action := &"boost"
@export var label := "BOOST"
@export var accent := Color(0.4, 0.8, 1.0)
@export var indicator := Indicator.NONE

var _touch := -1
var _flash := 0.0


func _ready() -> void:
	add_to_group("touch_button")
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _mech() -> Mech:
	return get_tree().get_first_node_in_group("player") as Mech


func _input(event: InputEvent) -> void:
	if Controls.ignore_real_input or not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var inside: bool = event.position.distance_to(get_global_rect().get_center()) < minf(size.x, size.y) * 0.5 + 10.0
		if event.pressed and _touch == -1 and inside:
			_touch = event.index
			_flash = 1.0
			Input.action_press(action)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _touch:
			_touch = -1
			Input.action_release(action)


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 4.0)
	if indicator == Indicator.USE_CONTEXT:
		var m := _mech()
		var in_range := m != null and m.focus_interactable != null
		if not in_range and _touch != -1:
			_touch = -1
			Input.action_release(action)
		visible = in_range
	queue_redraw()


func _notification(what: int) -> void:
	var gone := what == NOTIFICATION_EXIT_TREE or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree())
	if gone and _touch != -1:
		_touch = -1
		Input.action_release(action)


func _draw() -> void:
	var m := _mech()
	var c := size / 2
	var r := minf(size.x, size.y) / 2 - 3
	var is_ready := true
	var fill := 1.0
	var sub := ""
	if m:
		match indicator:
			Indicator.BOOST_COOLDOWN:
				fill = m.boost_ready_fraction()
				is_ready = fill >= 1.0
			Indicator.HEAT_COST_NOVA:
				fill = clampf(m.heat / m.nova_cost, 0.0, 1.0)
				is_ready = m.heat >= m.nova_cost
			Indicator.HEAT_COST_CONE:
				fill = clampf(m.heat / m.cone_cost, 0.0, 1.0)
				is_ready = m.heat >= m.cone_cost
			Indicator.REPAIR_CHARGES:
				is_ready = m.repair_charges > 0
				sub = "x%d" % m.repair_charges
			Indicator.BEAM_COOLDOWN:
				if m.beam:
					fill = m.beam.ready_fraction()
					is_ready = fill >= 1.0
			Indicator.OVERDRIVE_METER:
				fill = m.overdrive_meter / 100.0 if m.overdrive_left <= 0.0 else m.overdrive_left / m.overdrive_time
				is_ready = m.overdrive_meter >= 100.0 or m.overdrive_left > 0.0
	var pressed := _touch != -1
	if is_ready:
		draw_circle(c, r + 5, Color(accent, 0.18 + 0.2 * _flash))
	draw_circle(c, r, Color(accent.darkened(0.6), 0.85) if is_ready else Color(0.05, 0.08, 0.14, 0.7))
	if fill < 1.0:
		draw_arc(c, r - 4, -PI / 2, -PI / 2 + TAU * fill, 40, Color(accent, 0.9), 5.0, true)
	draw_arc(c, r, 0, TAU, 48, Color(accent.lightened(0.3), 0.95 if is_ready else 0.4), 2.5 if not pressed else 4.0, true)
	if pressed:
		draw_circle(c, r, Color(1, 1, 1, 0.25))
	var font := get_theme_default_font()
	var fs := 13 if label.length() > 6 else 15
	draw_string_outline(font, Vector2(0, c.y + 5), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, c.y + 5), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color(1, 1, 1, 1.0 if is_ready else 0.5))
	if sub != "":
		draw_string(font, Vector2(0, c.y + 22), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(accent.lightened(0.4), 0.9))
