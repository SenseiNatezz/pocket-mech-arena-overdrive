extends Node
## Controls (autoload): merges keyboard/mouse, gamepad and touch into one twin-stick interface.
##
##   get_move()           -> Vector2 (-1..1)  WASD / arrows / left stick / left touch joystick
##   get_aim(from_world)  -> Vector2 (unit)   mouse position / right stick / dragged touch FIRE button /
##                                            touch auto-aim
##
## Buttons are plain Input Map actions (fire_primary, boost, heat_attack_1, ...). On-screen touch
## buttons press those same actions via Input.action_press(), so gameplay code never needs to know
## which device is in use.
##
## Touch AUTO-AIM: on a touch screen, while the FIRE button isn't being dragged to aim by hand, the
## mech aims at the nearest enemy on screen (`auto_target`, kept until it dies, leaves the screen or a
## much closer one shows up), otherwise where it's moving. `-- --auto-aim` turns it on for any device.
## Touch AUTO-FIRE (Settings, on by default): the mech also fires on its own at that target.
##
## REBINDING (Settings > Controls, ui/controls_page.gd): each keyboard/mouse action in REBINDABLE has one
## primary key/button that can be changed. Arrow keys (movement) and gamepad buttons stay as they are.
## Game saves the bindings (bindings_to_save / load_bindings).

enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

signal device_changed(device: Device)
## A key binding changed (prompts that name keys refresh).
signal bindings_changed

## [action, label] in the order the Controls page lists them.
const REBINDABLE := [
	[&"move_up", "Move up"], [&"move_down", "Move down"], [&"move_left", "Move left"], [&"move_right", "Move right"],
	[&"fire_primary", "Fire"], [&"fire_secondary", "Scatter shot"], [&"boost", "Boost"], [&"beam", "Beam cannon"],
	[&"heat_attack_1", "Heat Nova"], [&"heat_attack_2", "Magma Cone"], [&"self_repair", "Self-repair"],
	[&"overdrive", "Overdrive"], [&"use", "Use"], [&"pause", "Pause"],
]

## Right-stick / touch aim below this magnitude keeps the previous aim direction.
const AIM_DEADZONE := 0.3
## Touch auto-aim reach (world px), and how much closer another enemy must be to take over the lock.
const AUTO_AIM_RANGE := 760.0
const AUTO_AIM_SWITCH := 0.6

var device := Device.KEYBOARD_MOUSE
## Written by the on-screen controls (ui/virtual_joystick.gd, ui/fire_stick.gd).
var touch_move := Vector2.ZERO
var touch_aim := Vector2.ZERO
var touch_active := false
## Debug: when true, real input is ignored (used by automated tests / capture runs).
var ignore_real_input := false
## Distance from the mech to the mouse cursor / auto-aim target (0 = unknown). Used so shots
## converge on what you point at.
var aim_distance := 0.0
## Touch auto-aim: the enemy being aimed at (null = none in range). ui/auto_aim_marker.gd marks it.
var auto_target: Node2D
## Debug / tests: auto-aim on any device.
var force_auto_aim := OS.get_cmdline_user_args().has("--auto-aim")
## Held by the on-screen FIRE button (ui/fire_stick.gd). Read through is_firing().
var touch_fire := false

var _last_aim := Vector2.RIGHT
## A left click emulated from the first finger on a touch screen is being held (see is_firing()).
var _touch_click := false
## Each rebindable action's keyboard/mouse events from the project's Input Map (Reset to defaults).
var _default_events := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	touch_active = DisplayServer.is_touchscreen_available() or OS.get_cmdline_user_args().has("--touch")
	if OS.get_cmdline_user_args().has("--touch") or OS.has_feature("mobile"):
		device = Device.TOUCH
	for r: Array in REBINDABLE:
		_default_events[r[0]] = InputMap.action_get_events(r[0])


func _input(event: InputEvent) -> void:
	if ignore_real_input:
		return
	# Mouse events emulated from touches (pointing/emulate_mouse_from_touch, which menu taps need) aren't
	# a device switch, and their left click mustn't count as the fire button.
	if event.device == InputEvent.DEVICE_ID_EMULATION and (event is InputEventMouseButton or event is InputEventMouseMotion):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_touch_click = event.pressed
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


## Primary fire held: the on-screen FIRE button, or the fire_primary action (mouse / trigger / tests),
## except a left click that a finger on the touch screen emulated (otherwise touching the move stick
## would shoot).
func is_firing() -> bool:
	return touch_fire or auto_firing() or (Input.is_action_pressed("fire_primary") and not _touch_click)


## Touch AUTO-FIRE: firing on its own while the auto-aim has a target (melee weapons wait until it's
## within reach, so they don't swing at robots across the screen).
func auto_firing() -> bool:
	if device != Device.TOUCH or not Game.auto_fire or touch_aim.length() > AIM_DEADZONE:
		return false
	if not _aimable(auto_target, Vector2.ZERO, Rect2(), INF):
		return false
	var mech := get_tree().get_first_node_in_group("player") as Node2D
	if mech and MeleeKit.has_weapon(Game.weapon):
		var reach: float = MeleeKit.WEAPONS[Game.weapon]["reach"]
		return mech.global_position.distance_to(auto_target.global_position) < reach * 1.6
	return true


func uses_auto_aim() -> bool:
	return device == Device.TOUCH or force_auto_aim


## Aim direction from `from_world` (the mech's global position). Unit vector; never zero.
func get_aim(from_world: Vector2, viewport: Viewport) -> Vector2:
	aim_distance = 0.0
	if touch_aim.length() > AIM_DEADZONE:
		auto_target = null
		_last_aim = touch_aim.normalized()
		return _last_aim
	if uses_auto_aim():
		auto_target = _pick_auto_target(from_world, viewport)
		if auto_target:
			var to := auto_target.global_position - from_world
			if to.length() > 1.0:
				_last_aim = to.normalized()
				aim_distance = to.length()
		elif touch_move.length() > 0.5:
			_last_aim = touch_move.normalized()
		return _last_aim
	auto_target = null
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
			aim_distance = to_mouse.length()
	elif device == Device.GAMEPAD:
		# No right-stick input: aim where you're moving (twin-stick convention).
		var move := get_move()
		if move.length() > 0.5:
			_last_aim = move.normalized()
	return _last_aim


## Nearest living enemy on screen within AUTO_AIM_RANGE. The current target is kept while it stays
## valid, unless another one is a lot closer.
func _pick_auto_target(from: Vector2, viewport: Viewport) -> Node2D:
	var view := Rect2()
	if viewport:
		var inv := viewport.get_canvas_transform().affine_inverse()
		view = (inv * Rect2(Vector2.ZERO, viewport.get_visible_rect().size)).grow(-24.0)
	var keep: Node2D = auto_target if _aimable(auto_target, from, view, AUTO_AIM_RANGE * 1.15) else null
	var best: Node2D = null
	var best_d := AUTO_AIM_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and _aimable(e, from, view, best_d):
			best_d = from.distance_to(e.global_position)
			best = e
	if keep and (best == null or best_d > from.distance_to(keep.global_position) * AUTO_AIM_SWITCH):
		return keep
	return best


func _aimable(e: Node2D, from: Vector2, view: Rect2, max_d: float) -> bool:
	if not is_instance_valid(e) or e.is_queued_for_deletion() or e.get("dead") == true or not e.is_visible_in_tree():
		return false
	if view.size != Vector2.ZERO and not view.has_point(e.global_position):
		return false
	return from.distance_to(e.global_position) < max_d


## Test / touch hook: set the aim direction directly.
func set_aim(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		_last_aim = dir.normalized()


# --- key rebinding -------------------------------------------------------------------------------------

static func _is_kbm(e: InputEvent) -> bool:
	return e is InputEventKey or e is InputEventMouseButton


## The action's primary keyboard/mouse event (the one the Controls page shows and rebinds), or null.
func primary_event(action: StringName) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if _is_kbm(e):
			return e
	return null


## Short name for an action's key: "W", "Space", "Shift", "LMB", "Mouse 4"...
func key_name(action: StringName) -> String:
	return event_name(primary_event(action))


static func event_name(e: InputEvent) -> String:
	if e is InputEventMouseButton:
		match (e as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
		return "Mouse %d" % (e as InputEventMouseButton).button_index
	if e is InputEventKey:
		var k := e as InputEventKey
		var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		# Show the key the player's own layout prints there (AZERTY Z for QWERTY W, ...).
		var shown := code
		if k.physical_keycode != KEY_NONE and DisplayServer.get_name() != "headless":
			shown = DisplayServer.keyboard_get_keycode_from_physical(code)
		return OS.get_keycode_string(shown if shown != KEY_NONE else code)
	return "-"


## Makes `e` (a key or mouse button) the action's primary binding. If another rebindable action already
## used it, that action takes over this one's old binding (a swap), so nothing is left unbound.
func rebind(action: StringName, e: InputEvent) -> void:
	var old := primary_event(action)
	for r: Array in REBINDABLE:
		var other: StringName = r[0]
		var theirs := primary_event(other)
		if other != action and theirs and _same(theirs, e):
			_set_primary(other, old)
	_set_primary(action, e)
	bindings_changed.emit()


func _same(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		return (a as InputEventKey).physical_keycode == (b as InputEventKey).physical_keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	return false


func _set_primary(action: StringName, e: InputEvent) -> void:
	var events := InputMap.action_get_events(action)
	var i := 0
	while i < events.size() and not _is_kbm(events[i]):
		i += 1
	InputMap.action_erase_events(action)
	if e:
		if i < events.size():
			events[i] = e
		else:
			events.insert(0, e)
	elif i < events.size():
		events.remove_at(i)
	for ev in events:
		InputMap.action_add_event(action, ev)


func reset_bindings() -> void:
	for action: StringName in _default_events:
		InputMap.action_erase_events(action)
		for e: InputEvent in _default_events[action]:
			InputMap.action_add_event(action, e)
	bindings_changed.emit()


## Only the actions whose primary binding differs from the default: {action: "key:CODE" / "mouse:BUTTON"}.
func bindings_to_save() -> Dictionary:
	var out := {}
	for action: StringName in _default_events:
		var now := primary_event(action)
		var was: InputEvent = null
		for e: InputEvent in _default_events[action]:
			if _is_kbm(e):
				was = e
				break
		if now and not (was and _same(now, was)):
			if now is InputEventKey:
				out[String(action)] = "key:%d" % (now as InputEventKey).physical_keycode
			else:
				out[String(action)] = "mouse:%d" % (now as InputEventMouseButton).button_index
	return out


func load_bindings(saved: Dictionary) -> void:
	for k in saved:
		var action := StringName(k)
		var parts := str(saved[k]).split(":")
		if not _default_events.has(action) or parts.size() != 2:
			continue
		var e: InputEvent
		if parts[0] == "key":
			var key := InputEventKey.new()
			key.physical_keycode = int(parts[1]) as Key
			e = key
		else:
			var mb := InputEventMouseButton.new()
			mb.button_index = int(parts[1]) as MouseButton
			mb.pressed = true
			e = mb
		_set_primary(action, e)
	bindings_changed.emit()
