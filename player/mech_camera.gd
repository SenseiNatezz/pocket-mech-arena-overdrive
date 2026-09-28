extends Camera2D
## Follows the mech with aim lead (looks ahead toward where you're aiming) and trauma-based screen
## shake (Combat.shake(strength), can be turned off in Settings). Limits are set by the arena.

## How far ahead of the mech the camera looks along the aim direction (pixels).
@export var lead_distance := 150.0
@export var lead_smoothing := 5.0
@export var max_shake_offset := 22.0
@export var max_shake_roll := 0.025
@export var shake_decay := 1.6

## Touch screens zoom in so the mech and enemies aren't tiny: phones (under ~7.5" diagonal) a lot,
## tablets a little. Desktop / gamepad play stays at 1.0. `--touch` on desktop previews the phone zoom.
const PHONE_ZOOM := 1.3
const TABLET_ZOOM := 1.15
const PHONE_MAX_INCHES := 7.5
## Portrait: how far (world px) the view shifts down so the mech sits above the thumb controls.
const PORTRAIT_RAISE := 80.0

var trauma := 0.0
var _lead := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _nt := 0.0
var _touch_zoom := PHONE_ZOOM


func _ready() -> void:
	_noise.frequency = 2.5
	ignore_rotation = false
	Combat.shake_requested.connect(add_trauma)
	if OS.has_feature("mobile"):
		var px := Vector2(DisplayServer.screen_get_size())
		var dpi := maxf(float(DisplayServer.screen_get_dpi()), 1.0)
		_touch_zoom = PHONE_ZOOM if px.length() / dpi < PHONE_MAX_INCHES else TABLET_ZOOM
	zoom = Vector2.ONE * _wanted_zoom()


func _wanted_zoom() -> float:
	return _touch_zoom if Controls.device == Controls.Device.TOUCH else 1.0


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


func _process(delta: float) -> void:
	var mech := get_parent() as Mech
	var target := Vector2.ZERO
	if mech and not mech.dead:
		var strength := 1.0
		if Controls.device == Controls.Device.KEYBOARD_MOUSE:
			# Lead grows with how far the cursor is from the mech on screen.
			var screen_mech := mech.get_global_transform_with_canvas().origin
			var d := get_viewport().get_mouse_position().distance_to(screen_mech)
			strength = clampf(d / (get_viewport_rect().size.y * 0.45), 0.0, 1.0)
		target = mech.aim_dir * lead_distance * strength
		if Layout.portrait:
			# Narrow screen: half the sideways lead (it would push the mech to the edge), and frame the
			# mech a little above centre, clear of the thumb controls along the bottom.
			target = Vector2(target.x * 0.5, target.y + PORTRAIT_RAISE)
	_lead = _lead.lerp(target, 1.0 - exp(-lead_smoothing * delta))
	zoom = zoom.lerp(Vector2.ONE * _wanted_zoom(), 1.0 - exp(-4.0 * delta))
	trauma = maxf(trauma - shake_decay * delta, 0.0)
	_nt += delta * 60.0
	var s := trauma * trauma
	offset = _lead + Vector2(_noise.get_noise_2d(_nt, 0.0), _noise.get_noise_2d(0.0, _nt)) * max_shake_offset * s
	# Camera limits don't apply to `offset`, so keep the look-ahead from peeking past the map edge.
	var half := get_viewport_rect().size / zoom / 2.0
	var lo := Vector2(limit_left, limit_top) + half
	var hi := Vector2(limit_right, limit_bottom) - half
	if hi.x >= lo.x and hi.y >= lo.y:
		var center := get_screen_center_position() - offset
		var want := (center + offset).clamp(lo, hi)
		offset = want - center
	rotation = _noise.get_noise_2d(_nt, _nt) * max_shake_roll * s
