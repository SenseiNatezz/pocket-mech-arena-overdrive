extends Node
## Controls (autoload): merges keyboard/mouse, gamepad and touch into one twin-stick interface.
##
##   get_move()           -> Vector2 (-1..1)  WASD / arrows / left stick / left touch joystick
##   get_aim(from_world)  -> Vector2 (unit)   mouse position / right stick / right touch joystick
##
## Buttons are plain Input Map actions (fire_primary, boost, heat_attack_1, ...). On-screen touch
## buttons press those same actions via Input.action_press(), so gameplay code never needs to know
## which device is in use.

enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

signal device_changed(device: Device)

## Right-stick / touch aim below this magnitude keeps the previous aim direction.
const AIM_DEADZONE := 0.3

var device := Device.KEYBOARD_MOUSE
## Written by the on-screen joysticks (ui/virtual_joystick.gd).
var touch_move := Vector2.ZERO
var touch_aim := Vector2.ZERO
var touch_active := false
## Debug: when true, real input is ignored (used by automated tests / capture runs).
var ignore_real_input := false

var _last_aim := Vector2.RIGHT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_active = DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")
	if OS.get_cmdline_user_args().has("--touch") or OS.has_feature("mobile"):
		device = Device.TOUCH


func _input(event: InputEvent) -> void:
	if ignore_real_input:
		return
	var new_device := device
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		new_device = Device.TOUCH
		touch_active = true
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.35):
		new_device = Device.GAMEPAD
	elif event is InputEventKey or event is InputEventMouseButton or \
			(event is InputEventMouseMotion and event.relative.length() > 2.0):
		new_device = Device.KEYBOARD_MOUSE
	if new_device != device:
		device = new_device
		device_changed.emit(device)


func get_move() -> Vector2:
	if touch_move != Vector2.ZERO:
		return touch_move.limit_length(1.0)
	if ignore_real_input:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Aim direction from `from_world` (the mech's global position). Unit vector; never zero.
func get_aim(from_world: Vector2, viewport: Viewport) -> Vector2:
	if touch_aim.length() > AIM_DEADZONE:
		_last_aim = touch_aim.normalized()
		return _last_aim
	if ignore_real_input:
		return _last_aim
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > AIM_DEADZONE:
		_last_aim = stick.normalized()
	elif device == Device.KEYBOARD_MOUSE and viewport:
		var mouse_world := viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
		var to_mouse := mouse_world - from_world
		if to_mouse.length() > 8.0:
			_last_aim = to_mouse.normalized()
	elif device == Device.GAMEPAD:
		# No right-stick input: aim where you're moving (twin-stick convention).
		var move := get_move()
		if move.length() > 0.5:
			_last_aim = move.normalized()
	return _last_aim


## Test / touch hook: set the aim direction directly.
func set_aim(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		_last_aim = dir.normalized()
