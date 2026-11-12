extends Camera2D
## Follows the mech with aim lead (looks ahead toward where you're aiming) and trauma-based screen
## shake (Combat.shake(strength), can be turned off in Settings). Limits are set by the arena.
## DYNAMIC CAMERA (Settings > Dynamic Camera, on by default) - the zoom follows the fight:
##   pulls out   as more robots close in (big ones and elites count double), while a boss is alive,
##               and a touch while boosting, so you can see what's coming
##   punches in  for a split second on big moments (Combat.camera_punch: boss kills, elite kills, heavy
##               finishers), then eases back
##   kicks       a few px against the firing direction for heavy guns (Combat.camera_kick)
##   focuses     on a point for a moment (Combat.camera_focus: a boss landing) - glides over, holds, returns
##   frames      a nearby boss: the view slides toward the middle of mech + boss and pulls out just enough to
##               fit both (BOSS_FRAME_*), and stays on the spot for a moment after the kill so the death
##               explosion is on screen (it used to sit half off the top edge in ranged fights)
## `zoom_override` (> 0) pins the zoom (capture tools).

## How far ahead of the mech the camera looks along the aim direction (pixels).
@export var lead_distance := 150.0
@export var lead_smoothing := 5.0
@export var max_shake_offset := 22.0
@export var max_shake_roll := 0.025
@export var shake_decay := 1.6

## Base zoom per device, so the mech and enemies aren't tiny: phones (under ~7.5" diagonal) most,
## tablets a little less, desktop / gamepad 1.1 (at 1.0 the mech was ~45 px tall in a 720p view; it was
## 1.25 until the user asked for a wider view).
## Settings > Camera Zoom multiplies it (Game.camera_zoom_mult: Far 0.8, Close 1.15).
## `--touch` on desktop previews the phone zoom.
const DESKTOP_ZOOM := 1.1
const PHONE_ZOOM := 1.22
const TABLET_ZOOM := 1.08
const PHONE_MAX_INCHES := 7.5
## Portrait: how far (world px) the view shifts down so the mech sits above the thumb controls.
const PORTRAIT_RAISE := 80.0
const PORTRAIT_DOWN_LEAD := 1.6  # x the normal look-ahead when aiming down on a portrait screen
## Dynamic camera: the most it pulls out (fraction of the zoom) for a crowd, for a boss, and in total.
const CROWD_OUT := 0.13
const BOSS_OUT := 0.1
const BOOST_OUT := 0.035
const MAX_OUT := 0.2
## Robots (weighted) within THREAT_RADIUS that count as a full crowd.
const CROWD_FULL := 12.0
const THREAT_RADIUS := 1000.0
## Boss framing: full strength within BOSS_FRAME_NEAR px, gone by BOSS_FRAME_FAR; how much of the way to the
## mech/boss midpoint the view slides; the most it may pull out to fit both; how long it holds after the kill.
const BOSS_FRAME_NEAR := 850.0
const BOSS_FRAME_FAR := 1300.0
const BOSS_FRAME_PULL := 0.75
const BOSS_FRAME_OUT := 0.24
const BOSS_FRAME_HOLD := 1.8

var trauma := 0.0
var zoom_override := 0.0
var _lead := Vector2.ZERO
var _noise := FastNoiseLite.new()
var _nt := 0.0
var _touch_zoom := PHONE_ZOOM
var _out := 0.0
var _out_want := 0.0
var _scan_t := 0.0
var _punch := 0.0
var _kick := Vector2.ZERO
var _focus_pos := Vector2.ZERO
var _focus_t := 0.0
var _focus_len := 0.0
var _focus_k := 0.0
var _boss_ref: WeakRef = null
var _boss_pos := Vector2.ZERO
var _boss_r := 80.0
var _boss_hold := 0.0


func _ready() -> void:
	_noise.frequency = 2.5
	ignore_rotation = false
	add_to_group("game_camera")
	Combat.shake_requested.connect(add_trauma)
	if Combat.has_signal("camera_punched"):
		Combat.camera_punched.connect(punch)
		Combat.camera_kicked.connect(kick)
		Combat.camera_focused.connect(focus)
	if OS.has_feature("mobile"):
		var px := Vector2(DisplayServer.screen_get_size())
		var dpi := maxf(float(DisplayServer.screen_get_dpi()), 1.0)
		_touch_zoom = PHONE_ZOOM if px.length() / dpi < PHONE_MAX_INCHES else TABLET_ZOOM
	zoom = Vector2.ONE * _base_zoom()


func _base_zoom() -> float:
	return (_touch_zoom if Controls.device == Controls.Device.TOUCH else DESKTOP_ZOOM) * Game.camera_zoom_mult()


func add_trauma(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## Zoom in by `amount` (0.06 = 6%) for a moment, easing back.
func punch(amount: float) -> void:
	if Game.get("dynamic_camera") == false:
		return
	_punch = maxf(_punch, amount)


## Push the view by `v` px (recoil), springing back.
func kick(v: Vector2) -> void:
	if Game.screen_shake:
		_kick += v


## Glide over to `world_pos`, hold it there, and come back, over `seconds`.
func focus(world_pos: Vector2, seconds: float) -> void:
	_focus_pos = world_pos
	_focus_len = maxf(seconds, 0.5)
	_focus_t = _focus_len


## How far the fight wants the camera pulled out (0..MAX_OUT).
func _scan_threat(mech: Mech) -> float:
	var n := 0.0
	var boss := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.dead:
			continue
		if e.is_in_group("boss"):
			boss = true
			_boss_ref = weakref(e)
			continue
		if e.global_position.distance_to(mech.global_position) < THREAT_RADIUS:
			n += 2.0 if (e.elite or e.hit_radius >= 40.0) else 1.0
	var out := clampf(n / CROWD_FULL, 0.0, 1.0) * CROWD_OUT + (BOSS_OUT if boss else 0.0)
	return out


## Boss framing for this frame: {lead: where the view should look (relative to the mech), w: how much
## (0..1), out: how far to pull out so mech and boss both fit}.
func _boss_frame(mech: Mech, delta: float) -> Dictionary:
	var b: Node2D = _boss_ref.get_ref() as Node2D if _boss_ref else null
	if b and b.is_inside_tree() and not b.get("dead"):
		_boss_pos = b.global_position
		var r = b.get("hit_radius")
		_boss_r = float(r) if r != null else 80.0
		_boss_hold = BOSS_FRAME_HOLD
	else:
		_boss_hold = maxf(_boss_hold - delta, 0.0)
	if _boss_hold <= 0.0:
		return {"lead": Vector2.ZERO, "w": 0.0, "out": 0.0}
	var rel := _boss_pos - mech.global_position
	var w := 1.0 - smoothstep(BOSS_FRAME_NEAR, BOSS_FRAME_FAR, rel.length())
	w *= minf(_boss_hold / 0.6, 1.0)  # ease off after the kill hold
	if w <= 0.0:
		return {"lead": Vector2.ZERO, "w": 0.0, "out": 0.0}
	# Fit both: the view must reach half the gap plus the boss's size (and a margin) each way.
	var need := Vector2(absf(rel.x), absf(rel.y)) * 0.5 + Vector2.ONE * (_boss_r + 70.0)
	var half_px := get_viewport_rect().size / 2.0
	var fit := minf(half_px.x / need.x, half_px.y / need.y)
	var out := clampf(1.0 - fit / _base_zoom(), 0.0, BOSS_FRAME_OUT) * w
	return {"lead": rel * 0.5, "w": w * BOSS_FRAME_PULL, "out": out}


func _process(delta: float) -> void:
	var mech := get_parent() as Mech
	var target := Vector2.ZERO
	var dynamic: bool = Game.get("dynamic_camera") != false
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
			# mech a little above centre, clear of the thumb controls along the bottom. Aiming DOWN looks
			# further ahead, so robots coming from below show above the buttons, not under them.
			var down := maxf(target.y, 0.0) * (PORTRAIT_DOWN_LEAD - 1.0)
			target = Vector2(target.x * 0.5, target.y + down + PORTRAIT_RAISE)
		if dynamic:
			_scan_t -= delta
			if _scan_t <= 0.0:
				_scan_t = 0.25
				_out_want = _scan_threat(mech)
	if not dynamic:
		_out_want = 0.0
	var frame_out := 0.0
	if mech and not mech.dead:
		var fr := _boss_frame(mech, delta)
		target = target.lerp(fr["lead"], fr["w"])
		frame_out = fr["out"] if dynamic else 0.0
	var boosting: bool = mech != null and mech.get("_boost_left") != null and float(mech.get("_boost_left")) > 0.0
	var want_out := maxf(minf(_out_want + (BOOST_OUT if boosting and dynamic else 0.0), MAX_OUT), frame_out)
	# Out a little faster than back in, so a sudden crowd is seen in time.
	_out = lerpf(_out, want_out, 1.0 - exp(-(1.8 if want_out > _out else 0.8) * delta))
	_punch = move_toward(_punch, 0.0, delta * 0.35)
	# Boss-landing focus: glide over (first 30%), hold, glide back (last 30%).
	if _focus_t > 0.0:
		_focus_t = maxf(_focus_t - delta, 0.0)
		var k := 1.0 - _focus_t / _focus_len
		_focus_k = smoothstep(0.0, 0.3, k) * (1.0 - smoothstep(0.7, 1.0, k))
		if mech:
			target = target.lerp(_focus_pos - mech.global_position, _focus_k)
	else:
		_focus_k = 0.0
	_lead = _lead.lerp(target, 1.0 - exp(-lead_smoothing * delta * (1.0 + 2.0 * _focus_k)))
	var z := _base_zoom() * (1.0 - _out) * (1.0 + _punch) * (1.0 - 0.08 * _focus_k)
	if zoom_override > 0.0:
		z = zoom_override
		zoom = Vector2.ONE * z
	else:
		zoom = zoom.lerp(Vector2.ONE * z, 1.0 - exp(-(9.0 if _punch > 0.001 else 4.0) * delta))
	_kick = _kick.lerp(Vector2.ZERO, 1.0 - exp(-14.0 * delta))
	trauma = maxf(trauma - shake_decay * delta, 0.0)
	_nt += delta * 60.0
	var s := trauma * trauma
	offset = _lead + _kick + Vector2(_noise.get_noise_2d(_nt, 0.0), _noise.get_noise_2d(0.0, _nt)) * max_shake_offset * s
	# Camera limits don't apply to `offset`, so keep the look-ahead from peeking past the map edge.
	var half := get_viewport_rect().size / zoom / 2.0
	var lo := Vector2(limit_left, limit_top) + half
	var hi := Vector2(limit_right, limit_bottom) - half
	if hi.x >= lo.x and hi.y >= lo.y:
		var center := get_screen_center_position() - offset
		var want := (center + offset).clamp(lo, hi)
		offset = want - center
	rotation = _noise.get_noise_2d(_nt, _nt) * max_shake_roll * s
