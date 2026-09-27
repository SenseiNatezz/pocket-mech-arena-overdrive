extends Camera2D
## Follows the mech with aim lead (looks ahead toward where you're aiming) and trauma-based screen
## shake (Combat.shake(strength), can be turned off in Settings). Limits are set by the arena.

## How far ahead of the mech the camera looks along the aim direction (pixels).
@export var lead_distance := 150.0
@export var lead_smoothing := 5.0
@export var max_shake_offset := 22.0
@export var max_shake_roll := 0.025
@export var shake_decay := 1.6

var trauma := 0.0
var _lead := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _nt := 0.0


func _ready() -> void:
	_noise.frequency = 2.5
	ignore_rotation = false
	Combat.shake_requested.connect(add_trauma)


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
	_lead = _lead.lerp(target, 1.0 - exp(-lead_smoothing * delta))
	trauma = maxf(trauma - shake_decay * delta, 0.0)
	_nt += delta * 60.0
	var s := trauma * trauma
	offset = _lead + Vector2(_noise.get_noise_2d(_nt, 0.0), _noise.get_noise_2d(0.0, _nt)) * max_shake_offset * s
	rotation = _noise.get_noise_2d(_nt, _nt) * max_shake_roll * s
