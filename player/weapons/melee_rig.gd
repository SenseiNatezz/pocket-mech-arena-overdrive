extends Node2D
## Melee weapon held in the mech's hand (created by MeleeKit, drawn in world space).
##   REST     while a melee weapon is equipped the blade is always in hand, angled out to the front-right
##            of the aim (Dual Sabers: one blade per hand) and follows the aim smoothly.
##   SWING    swing() plays an attack from wherever the blade is: a quick wind-up to the start of the
##            arc, a fast ease-out strike, a small overshoot and a settle, then it eases back to rest.
##            Styles: "arc" sweeps (twin = a crossing X), "thrust" stabs out and draws back, "spin" whirls;
##            the Energy Sword adds "xcut" (two crossing diagonal cuts) and "moon" (a huge surging arc).
##   TRAIL    the blade tip leaves a continuous ribbon (Higgsfield trail textures in assets/hq/fx,
##            tinted with the weapon colour, additive) built from the blade's real recent positions,
##            sub-sampled so fast arcs stay smooth. Thrusts draw a piercing streak instead.
##   IMPACT   impact() flashes an X-cut burst on whatever was hit and briefly freezes the swing
##            (a hit-pause for the blade only, so game timing and tests are unaffected).
##   CEL      weapons with "cel" (the Energy Sword) swap the textured ribbon and X-cut sprite for the
##            hand-drawn cel smear and cross flash in player/weapons/energy_sword_fx.gd.

const HUE_SHADER := preload("res://player/weapons/blade_hue.gdshader")
const TRAIL_ENERGY := preload("res://assets/hq/fx/slash_trail_energy.png")
const TRAIL_HEAVY := preload("res://assets/hq/fx/slash_trail_heavy.png")
const TRAIL_THRUST := preload("res://assets/hq/fx/slash_trail_thrust.png")
const IMPACT := preload("res://assets/hq/fx/slash_impact.png")

## Hilt position at rest in Body space (the sprite faces up; +x = the mech's right hand).
const HAND := Vector2(22, -24)
## Rest pose: blade angled this far to the right of the aim, drawn at this fraction of its length.
const REST_ANGLE := 0.45
const REST_SCALE := 0.8
## Swing pivot -> hilt distance (the arm).
const ARM := 18.0
const TRAIL_LIFE := 0.12
const TRAIL_SUBSTEPS := 4
## Where along the blade the ribbon starts (fraction of blade length from the hilt).
const TRAIL_INNER := 0.28
## Impact flashes per swing, and how long the blade holds its finishing pose before easing back.
const MAX_FLASHES := 3
const HOLD := 0.22
## Middle of each weapon's handle / grip area, as a fraction of its art height from the bottom
## (measured from assets/hq/weapons/*.png). Long-hafted weapons are held a way up the shaft.
const GRIP_AT := {"beam_saber": 0.15, "katana": 0.12, "spear": 0.28, "axe": 0.22, "scythe": 0.3, "greatsword": 0.14,
	"energy_sword": 0.13}
## Cel smears: recorded only during the strike, gone again quickly.
const CEL_TRAIL_LIFE := 0.12
## Energy Sword art: the bottom CEL_HILT of the picture is the hilt (drawn from the art); the blade
## above it is drawn in code (EnergySwordFx.draw_blade) so it ends in a real point.
const CEL_HILT := 0.25
## Sparks drifting off the Energy Sword while it's equipped (per second).
const MOTE_RATE := 16.0
## Energy Sword swings are animated like a held sword (see _cel_pose): the hand travels on an arc around
## the right shoulder (CEL_SHOULDER in Body space, arm length CEL_ARM) and the torso twists with the
## blade (Mech.swing_twist). Phases as fractions of the swing: anticipation (wind back), STRIKE (fast;
## the only part that leaves a smear), follow-through hold, then recovery to the rest pose.
const CEL_SHOULDER := Vector2(12, -2)
const CEL_ARM := 26.0
const CEL_ANTIC := 0.22
const CEL_STRIKE_END := 0.5
const CEL_FOLLOW_END := 0.78
## Torso twist per radian of blade-off-aim (spins follow the blade all the way round).
const CEL_TWIST := 0.45

var mech: Mech
var _id := &""
var _tex: Texture2D
var _length := 150.0
var _color := Color.WHITE
var _energy := true
var _time := 0.0
var _hitstop := 0.0
# Current pose (world space); index 1 = the off-hand blade (twin).
var _angle := [0.0, PI]
var _grip := [Vector2.ZERO, Vector2.ZERO]
var _ext := [REST_SCALE, REST_SCALE]
# Active swing.
var _sw := {}
var _t := 0.0
var _dur := 0.2
var _start := [0.0, 0.0]
# Trail samples per blade: [time, grip, angle, ext].
var _trail := [[], []]
var _streak := {}
var _fx: Node2D
var _started := false
var _flashes := 0
var _hold := 0.0
## Where the fist holds the current weapon, as a fraction of its art height from the bottom (GRIP_AT).
var _grip_at := 0.12
## Cel-drawn weapon (Energy Sword): cel smear + cross flash instead of the ribbon / X-cut sprite.
var _cel := false
var _smear: Node2D
## Energy Sword sparks: [position, velocity, age, life, size].
var _motes: Array = []
var _mote_t := 0.0
## Energy Sword: in the fast strike part of a swing (smear recorded), and the torso twist being applied.
var _striking := false
var _twist := 0.0
var _twist_target := 0.0


func _ready() -> void:
	top_level = true
	# Relative to the mech (z 2): one below it, so the mech's fist is drawn over the handle it holds.
	z_index = -1
	_fx = TrailLayer.new()
	_fx.rig = self
	add_child(_fx)
	_smear = EnergySwordFx.CelSmear.new()
	_smear.rig = self
	add_child(_smear)


## Plays one attack. `life` is the visual length the attack was designed for.
func swing(w: Dictionary, mode: String, dir: Vector2, length: float, life: float, side: float, turns := 1.0,
		twin := false) -> void:
	_setup(w)
	_length = length
	_sw = {"mode": mode, "dir": dir, "half": minf(w["half"], 1.5), "side": side, "turns": turns, "twin": twin}
	var interval := 1.0 / (float(w["rate"]) * Upgrades.fire_rate_mult())
	_dur = clampf(minf(life * 1.15, interval * 0.95), 0.12, 0.45)
	_t = 0.0
	_start = [_angle[0], _angle[1]]
	_flashes = 0
	# (cel swings animate their own follow-through and recovery)
	_hold = 0.0 if w.get("cel", false) else HOLD
	# (cel weapons draw their own lunge streak, EnergySwordFx.lunge)
	if mode == "thrust" and not w.get("cel", false):
		_streak = {"from": mech.global_position + dir * ARM, "dir": dir, "t": 0.0, "len": length * 1.25,
			"life": clampf(_dur * 1.4, 0.22, 0.4)}


## Hit feedback: an X-cut flash on the target and a short freeze of the swing.
func impact(pos: Vector2, color: Color, heavy: bool) -> void:
	_hitstop = maxf(_hitstop, 0.07 if heavy else 0.045)
	# A few flashes per swing read as impact; more just turns into a white blob.
	_flashes += 1
	if _flashes > MAX_FLASHES:
		return
	if _cel:
		EnergySwordFx.cross_flash(pos, color, heavy)
		return
	var f := ImpactFlash.new()
	f.position = pos
	f.color = color
	f.size = 130.0 if heavy else 90.0
	f.rotation = randf() * TAU
	Combat.world().add_child(f)


func _setup(w: Dictionary) -> void:
	_color = w["color"]
	_energy = w["energy"]
	if mech.overdrive_left > 0.0:
		_color = _color.lerp(Color(1.0, 0.8, 0.3), 0.4)


func _process(delta: float) -> void:
	global_position = Vector2.ZERO
	var id: StringName = mech.weapon if is_instance_valid(mech) else &""
	var show := MeleeKit.has_weapon(id) and not mech.dead and not mech.is_falling()
	visible = show
	_fx.visible = show
	_smear.visible = show
	if not show and is_instance_valid(mech):
		mech.swing_twist = 0.0
		_twist = 0.0
	if not show:
		_sw = {}
		_trail = [[], []]
		_streak = {}
		_started = false
		return
	if id != _id:
		_equip(id)
	# Hit-pause: the blade (and its trail) hold still for a moment.
	if _hitstop > 0.0:
		_hitstop -= delta
		queue_redraw()
		_fx.queue_redraw()
		_smear.queue_redraw()
		return
	_time += delta
	var blades := 2 if _twin() else 1
	_striking = false
	_twist_target = 0.0
	if not _sw.is_empty():
		_t += delta
		var k := clampf(_t / _dur, 0.0, 1.0)
		if _cel:
			_cel_pose(k)
		else:
			for b in blades:
				_swing_pose(b, k)
		if _t >= _dur:
			_sw = {}
	elif _hold > 0.0:
		# Hold the finishing pose for a beat (combos chain on from here).
		_hold -= delta
	else:
		for b in blades:
			_rest_pose(b, delta)
	if not _started:
		_started = true
		for b in blades:
			_rest_pose(b, 1.0)
	# Energy Sword: the torso twists with the swing.
	_twist = wrapf(lerp_angle(_twist, _twist_target, 1.0 - exp(-25.0 * delta)), -PI, PI) if _cel else 0.0
	mech.swing_twist = _twist
	# Record the trail while the blade is moving through an attack (and let it fade after). Cel swings
	# only smear during the fast strike, never the wind-up or recovery.
	for b in blades:
		var tr: Array = _trail[b]
		if not _sw.is_empty() and _sw["mode"] != "thrust" and (not _cel or _striking):
			tr.append([_time, _grip[b], _angle[b], _ext[b]])
		while not tr.is_empty() and _time - tr[0][0] > (CEL_TRAIL_LIFE if _cel else TRAIL_LIFE):
			tr.pop_front()
	if not _streak.is_empty():
		_streak["t"] += delta
		if _streak["t"] >= _streak["life"]:
			_streak = {}
	_update_motes(delta)
	queue_redraw()
	_fx.queue_redraw()
	_smear.queue_redraw()


## Energy Sword: sparks peel off the blade edges and drift away, fading.
func _update_motes(delta: float) -> void:
	if not _cel:
		_motes.clear()
		return
	_mote_t -= delta
	while _mote_t <= 0.0:
		_mote_t += 1.0 / MOTE_RATE
		var cb := _cel_blade(0)
		var d: Vector2 = cb[1]
		var side := 1.0 if randf() < 0.5 else -1.0
		var at: Vector2 = cb[0] + d * cb[2] * randf_range(0.15, 0.95) + d.orthogonal() * cb[3] * side
		var vel := d.orthogonal() * side * randf_range(15.0, 45.0) + d * randf_range(5.0, 30.0)
		_motes.append([at, vel, 0.0, randf_range(0.45, 0.85), randf_range(2.5, 4.5)])
	for m: Array in _motes:
		m[0] += m[1] * delta
		m[2] += delta
	_motes = _motes.filter(func(m: Array) -> bool: return m[2] < m[3])


func _twin() -> bool:
	return MeleeKit.WEAPONS[_id].get("twin_rest", false) or _id == &"dual_sabers"


func _equip(id: StringName) -> void:
	_id = id
	var w: Dictionary = MeleeKit.WEAPONS[id]
	_tex = load("res://assets/hq/weapons/%s.png" % w["tex"])
	_grip_at = GRIP_AT.get(String(w["tex"]), 0.12)
	_cel = w.get("cel", false)
	_length = w["reach"] * 0.95
	_setup(w)
	if w.get("hue", 0.0) != 0.0:
		var m := ShaderMaterial.new()
		m.shader = HUE_SHADER
		m.set_shader_parameter("hue_shift", w["hue"])
		material = m
	else:
		material = null
	_trail = [[], []]
	_started = false


## Rest: hilt in the hand, blade out to the front-right (the off-hand blade mirrored), easing there.
func _rest_pose(b: int, delta: float) -> void:
	var body_rot: float = mech.body.rotation
	var aim := mech.aim_dir.angle()
	var sgn := 1.0 if b == 0 else -1.0
	var want_angle := aim + REST_ANGLE * sgn
	var want_grip: Vector2 = mech.global_position + Vector2(HAND.x * sgn, HAND.y).rotated(body_rot)
	if _cel:
		# Same shoulder + arm model as the swings, so a swing starts exactly where the rest pose is.
		want_grip = _shoulder() + Vector2.from_angle(want_angle) * CEL_ARM
	var t := 1.0 - exp(-9.0 * delta)
	_angle[b] = lerp_angle(_angle[b], want_angle, t)
	_grip[b] = _grip[b].lerp(want_grip, t) if delta < 1.0 else want_grip
	_ext[b] = lerpf(_ext[b], REST_SCALE, t)


## Attack pose at progress k (0..1) of the current swing.
func _swing_pose(b: int, k: float) -> void:
	var dir: Vector2 = _sw["dir"]
	var d := dir.angle()
	var side: float = _sw["side"]
	var p := mech.global_position
	match _sw["mode"]:
		"thrust":
			# Draw back a touch, then punch out past full reach and ease back.
			var ext := 0.0
			if k < 0.12:
				ext = lerpf(0.0, -0.18, k / 0.12)
			elif k < 0.42:
				ext = lerpf(-0.18, 0.55, _ease_out((k - 0.12) / 0.3))
			else:
				ext = lerpf(0.55, 0.1, smoothstep(0.42, 1.0, k))
			_angle[b] = d
			_grip[b] = p + dir * (ARM + ext * _length * 0.6)
			_ext[b] = 1.0
		"xcut":
			# Energy Sword X-CUT: two fast diagonal cuts, one after the other, crossing in front.
			var hx := 0.95
			var a := 0.0
			if k < 0.08:
				a = lerp_angle(_start[0], d - hx * side, k / 0.08)
			elif k < 0.5:
				a = lerpf(d - hx * side, d + hx * 0.75 * side, _ease_out((k - 0.08) / 0.42))
			else:
				a = lerpf(d + hx * side, d - hx * 0.75 * side, _ease_out((k - 0.5) / 0.5))
			_angle[b] = a
			_grip[b] = p + dir * 14.0 + Vector2.from_angle(a) * ARM
			_ext[b] = 1.0
		"moon":
			# Energy Sword RISING MOON: one huge sweep from behind the shoulder round to the far side; the
			# blade surges longer through the middle of the arc.
			var a0 := d - 2.0 * side
			var a1 := d + 1.35 * side
			var a := a1
			var strike := clampf((k - 0.12) / 0.48, 0.0, 1.0)
			if k < 0.12:
				a = lerp_angle(_start[0], a0, k / 0.12)
			elif k < 0.6:
				a = lerpf(a0, a1 + 0.15 * side, _ease_out(strike))
			else:
				a = lerpf(a1 + 0.15 * side, a1, smoothstep(0.6, 0.9, k))
			_angle[b] = a
			_grip[b] = p + dir * 4.0 + Vector2.from_angle(a) * ARM
			_ext[b] = 1.0 + 0.35 * sin(strike * PI)
		"spin":
			# The off-hand blade (Dual Sabers) whirls opposite the main one.
			var turns: float = _sw["turns"]
			_angle[b] = _start[0] + side * TAU * turns * _ease_in_out(k) if b == 0 else _angle[0] + PI
			_grip[b] = p + Vector2.from_angle(_angle[b]) * ARM
			_ext[b] = 1.0
		_:
			# Arc: wind up to the start of the arc, strike through it, overshoot, settle.
			var half: float = _sw["half"]
			var a0 := d - half * side
			var a1 := d + half * side
			var over := 0.2 * side
			var a := a1
			if k < 0.1:
				a = lerp_angle(_start[0], a0, k / 0.1)
			elif k < 0.55:
				a = lerpf(a0, a1 + over, _ease_out((k - 0.1) / 0.45))
			else:
				a = lerpf(a1 + over, a1, smoothstep(0.55, 0.85, k))
			# The off-hand blade (Dual Sabers) mirrors across the aim: the two cuts cross in an X.
			_angle[b] = a if b == 0 else 2.0 * d - a
			_grip[b] = p + dir * 8.0 + Vector2.from_angle(_angle[b]) * ARM
			_ext[b] = 1.0


## The sword shoulder in world space (follows the torso, so the hand moves with the body's twist).
func _shoulder() -> Vector2:
	return mech.global_position + CEL_SHOULDER.rotated(mech.body.rotation)


## Energy Sword swing pose at progress k: anticipation -> strike -> follow-through -> recovery, the
## hand on an arc around the shoulder and the torso twisting with the blade.
func _cel_pose(k: float) -> void:
	var dir: Vector2 = _sw["dir"]
	var d := dir.angle()
	var side: float = _sw["side"]
	var aim := mech.aim_dir.angle()
	var rest_a := aim + REST_ANGLE
	var a := d
	var ext := 1.0
	match _sw["mode"]:
		"thrust":
			# Draw the arm back, stab out past the hand, hold, ease back.
			var push := 0.0
			if k < 0.25:
				push = lerpf(0.0, -0.3, _ease_in_out(k / 0.25))
				_twist_target = -0.3 * side
			elif k < 0.45:
				push = lerpf(-0.3, 0.55, _ease_out((k - 0.25) / 0.2))
				_twist_target = 0.12 * side
			elif k < 0.75:
				push = 0.55
				_twist_target = 0.12 * side
			else:
				push = lerpf(0.55, 0.0, _ease_in_out((k - 0.75) / 0.25))
			_angle[0] = lerp_angle(_start[0], d, minf(k / 0.2, 1.0))
			_grip[0] = _shoulder() + Vector2.from_angle(_angle[0]) * (CEL_ARM + push * _length * 0.4)
			_ext[0] = 1.0
			return
		"spin":
			var a0 := d - 0.5 * side
			if k < 0.15:
				a = lerp_angle(_start[0], a0, _ease_in_out(k / 0.15))
			elif k < 0.75:
				a = a0 + side * TAU * _ease_in_out((k - 0.15) / 0.6)
				_striking = true
			else:
				a = lerp_angle(a0, rest_a, _ease_in_out((k - 0.75) / 0.25))
			_angle[0] = a
			_grip[0] = _shoulder() + Vector2.from_angle(a) * CEL_ARM
			_ext[0] = 1.0
			# The whole mech turns with the blade.
			_twist_target = angle_difference(aim, a) if k < 0.75 else 0.0
			return
		"xcut":
			# Two cuts: a quick wind-up, strike one, flip the wrist, strike two, hold, recover.
			if k < 0.12:
				a = lerp_angle(_start[0], d - 1.1 * side, _ease_in_out(k / 0.12))
			elif k < 0.34:
				a = lerpf(d - 1.1 * side, d + 0.8 * side, _ease_out4((k - 0.12) / 0.22))
				_striking = true
			elif k < 0.42:
				a = lerpf(d + 0.8 * side, d + 1.05 * side, _ease_in_out((k - 0.34) / 0.08))
			elif k < 0.64:
				a = lerpf(d + 1.05 * side, d - 0.8 * side, _ease_out4((k - 0.42) / 0.22))
				_striking = true
			elif k < 0.82:
				a = d - 0.8 * side
			else:
				a = lerp_angle(d - 0.8 * side, rest_a, _ease_in_out((k - 0.82) / 0.18))
		_:
			# "arc" / "moon": wind back past the start of the cut, a fast strike that carries 0.3 rad past
			# the end (follow-through), hold, then ease back to rest. The moon is wider and its blade surges.
			var half := 1.5 if _sw["mode"] == "moon" else 1.15
			var a_w := d - (half + 0.3) * side
			var a_f := d + (half + 0.3) * side
			if k < CEL_ANTIC:
				a = lerp_angle(_start[0], a_w, _ease_in_out(k / CEL_ANTIC))
			elif k < CEL_STRIKE_END:
				var u := (k - CEL_ANTIC) / (CEL_STRIKE_END - CEL_ANTIC)
				a = lerpf(a_w, a_f, _ease_out4(u))
				_striking = true
				if _sw["mode"] == "moon":
					ext = 1.0 + 0.12 * sin(u * PI)
			elif k < CEL_FOLLOW_END:
				a = a_f + 0.05 * side * (k - CEL_STRIKE_END) / (CEL_FOLLOW_END - CEL_STRIKE_END)
			else:
				a = lerp_angle(a_f + 0.05 * side, rest_a, _ease_in_out((k - CEL_FOLLOW_END) / (1.0 - CEL_FOLLOW_END)))
	_angle[0] = a
	_grip[0] = _shoulder() + Vector2.from_angle(a) * CEL_ARM
	_ext[0] = ext
	_twist_target = clampf(angle_difference(aim, a) * CEL_TWIST, -0.75, 0.75)


static func _ease_out4(x: float) -> float:
	var y := 1.0 - clampf(x, 0.0, 1.0)
	return 1.0 - y * y * y * y


static func _ease_out(x: float) -> float:
	var y := 1.0 - clampf(x, 0.0, 1.0)
	return 1.0 - y * y * y


static func _ease_in_out(x: float) -> float:
	return smoothstep(0.0, 1.0, x)


func _draw() -> void:
	if _tex == null:
		return
	if _cel:
		# Energy Sword aura: a soft pink glow pooled under the mech, breathing with the blade.
		var pulse := 0.5 + 0.5 * sin(_time * 5.0)
		var at: Vector2 = mech.global_position
		draw_circle(at, 44.0 + 6.0 * pulse, Color(_color, 0.07 + 0.05 * pulse))
		draw_circle(at, 30.0 + 4.0 * pulse, Color(_color, 0.08 + 0.05 * pulse))
		draw_arc(at, 46.0 + 7.0 * pulse, 0, TAU, 40, Color(_color.lightened(0.3), 0.25 + 0.15 * pulse), 2.0, true)
	for b in (2 if _twin() else 1):
		_draw_blade(_grip[b], _angle[b], _length * _ext[b])


## `length` = how far the weapon reaches beyond the fist. The art is scaled so that part matches, and
## drawn so the fist (`grip`) sits on the middle of the handle (_grip_at), with the pommel / shaft end
## behind the hand. The rig draws BELOW the mech, so the mech's fist covers the handle it holds.
## Cel weapons (Energy Sword) draw only the hilt from the art; the blade is drawn in code with a real point.
func _draw_blade(grip: Vector2, angle: float, length: float) -> void:
	var size := _tex.get_size()
	var s := length / (size.y * (1.0 - _grip_at))
	var at := Vector2(-size.x / 2, -size.y * (1.0 - _grip_at))
	if _cel:
		var hilt := Rect2(Vector2(-size.x / 2, size.y * (_grip_at - CEL_HILT)), Vector2(size.x, size.y * CEL_HILT))
		var src := Rect2(0, size.y * (1.0 - CEL_HILT), size.x, size.y * CEL_HILT)
		var d := Vector2.from_angle(angle)
		var base := grip + d * (CEL_HILT - _grip_at) * size.y * s
		var blade_len := length - (CEL_HILT - _grip_at) * size.y * s
		var hw := _cel_half_width(length)
		draw_colored_polygon(EnergySwordFx.lance(base + Vector2(6, 9), d, blade_len, hw), Color(0, 0, 0, 0.18))
		draw_set_transform(grip + Vector2(6, 9), angle + PI / 2, Vector2(s, s))
		draw_texture_rect_region(_tex, hilt, src, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO)
		EnergySwordFx.draw_blade(self, base, d, blade_len, hw, _time, _color)
		draw_set_transform(grip, angle + PI / 2, Vector2(s, s))
		draw_texture_rect_region(_tex, hilt, src)
		draw_set_transform(Vector2.ZERO)
		return
	# Soft ground shadow, then the weapon (art points up, handle at the bottom).
	draw_set_transform(grip + Vector2(6, 9), angle + PI / 2, Vector2(s, s))
	draw_texture(_tex, at, Color(0, 0, 0, 0.3))
	draw_set_transform(grip, angle + PI / 2, Vector2(s, s))
	draw_texture(_tex, at)
	draw_set_transform(Vector2.ZERO)


## Energy Sword blade half-width for a weapon drawn `length` long (thinner when held at rest).
func _cel_half_width(length: float) -> float:
	return clampf(length * 0.042, 4.5, 8.0)


## Blade base (guard) and length for blade `b` (cel weapons), for the glow layer.
func _cel_blade(b: int) -> Array:
	var size := _tex.get_size()
	var length: float = _length * _ext[b]
	var s := length / (size.y * (1.0 - _grip_at))
	var d := Vector2.from_angle(_angle[b])
	var off := (CEL_HILT - _grip_at) * size.y * s
	return [_grip[b] + d * off, d, length - off, _cel_half_width(length)]


## Additive layer: blade glow, the swing ribbon and thrust streaks.
class TrailLayer extends Node2D:
	var rig: Node2D

	func _ready() -> void:
		top_level = true
		z_index = 2
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _draw() -> void:
		var r = rig
		if r._tex == null:
			return
		var col: Color = r._color
		for b in (2 if r._twin() else 1):
			if r._cel:
				# Energy Sword: breathing pointed halo, crackles, tip twinkle, drifting sparks.
				var cb: Array = r._cel_blade(b)
				EnergySwordFx.draw_glow(self, cb[0], cb[1], cb[2], cb[3], r._time, col)
				for m: Array in r._motes:
					var k: float = m[2] / m[3]
					var sz: float = m[4] * (1.0 - k)
					if sz < 0.8:
						continue
					var p: Vector2 = m[0]
					draw_colored_polygon(PackedVector2Array([p + Vector2(sz, 0), p + Vector2(0, sz * 0.35), p - Vector2(sz, 0),
						p - Vector2(0, sz * 0.35)]), Color(col.lightened(0.5), 0.9 * (1.0 - k)))
					draw_colored_polygon(PackedVector2Array([p + Vector2(0, sz), p + Vector2(sz * 0.35, 0), p - Vector2(0, sz),
						p - Vector2(sz * 0.35, 0)]), Color(col.lightened(0.5), 0.9 * (1.0 - k)))
			# Energy blades glow faintly all the time.
			elif r._energy:
				var tip: Vector2 = r._grip[b] + Vector2.from_angle(r._angle[b]) * r._length * r._ext[b]
				var base: Vector2 = r._grip[b] + Vector2.from_angle(r._angle[b]) * r._length * r._ext[b] * 0.25
				draw_line(base, tip, Color(col, 0.22), 16.0, true)
				draw_line(base, tip, Color(col.lightened(0.5), 0.35), 5.0, true)
			_ribbon(r, r._trail[b], col)
		if not r._streak.is_empty():
			_draw_streak(r, col)

	func _ribbon(r: Node2D, tr: Array, col: Color) -> void:
		# Cel weapons draw their own smear (EnergySwordFx.CelSmear).
		if tr.size() < 2 or r._cel:
			return
		var tex: Texture2D = TRAIL_ENERGY if r._energy else TRAIL_HEAVY
		var now: float = r._time
		var life: float = TRAIL_LIFE
		# Sub-sample between recorded poses (angle interpolated) so fast arcs stay round.
		var pts := []
		for i in tr.size() - 1:
			var s0: Array = tr[i]
			var s1: Array = tr[i + 1]
			for k in TRAIL_SUBSTEPS:
				var f := k / float(TRAIL_SUBSTEPS)
				pts.append([lerpf(s0[0], s1[0], f), s0[1].lerp(s1[1], f), lerp_angle(s0[2], s1[2], f),
					lerpf(s0[3], s1[3], f)])
		pts.append(tr[tr.size() - 1])
		for i in pts.size() - 1:
			var q := []
			var uv := []
			var cs := []
			for j in [i, i + 1]:
				var s: Array = pts[j]
				var age := clampf((now - s[0]) / life, 0.0, 1.0)
				var dirv := Vector2.from_angle(s[2])
				var blen: float = r._length * s[3]
				var inner: Vector2 = s[1] + dirv * blen * TRAIL_INNER
				var outer: Vector2 = s[1] + dirv * blen * 1.04
				var u := 1.0 - age
				var a := (1.0 - age) * (1.0 - age)
				q.append_array([inner, outer])
				uv.append_array([Vector2(u, 0.0), Vector2(u, 1.0)])
				cs.append_array([Color(col, a * 0.9), Color(col.lightened(0.35), a)])
			# quad: inner0, outer0, outer1, inner1
			var poly := PackedVector2Array([q[0], q[1], q[3], q[2]])
			var puv := PackedVector2Array([uv[0], uv[1], uv[3], uv[2]])
			var pc := PackedColorArray([cs[0], cs[1], cs[3], cs[2]])
			if Geometry2D.triangulate_polygon(poly).is_empty():
				continue
			draw_polygon(poly, pc, puv, tex)

	func _draw_streak(r: Node2D, col: Color) -> void:
		var s: Dictionary = r._streak
		var k: float = s["t"] / s["life"]
		var grow := clampf(k / 0.3, 0.0, 1.0)
		var fade := 1.0 - clampf((k - 0.35) / 0.65, 0.0, 1.0)
		var d: Vector2 = s["dir"]
		var from: Vector2 = s["from"]
		var to: Vector2 = from + d * s["len"] * (0.4 + 0.6 * _ease(grow))
		# The texture's core line sits at v=0.86 (it's cropped for the sweep ribbons), so centre that
		# band on the thrust line: a wide coloured glow, then a narrower white-hot core on top.
		var uv := PackedVector2Array([Vector2(0, 0.72), Vector2(1, 0.72), Vector2(1, 1.0), Vector2(0, 1.0)])
		for layer in [[58.0, Color(col, fade)], [24.0, Color(1, 1, 1, fade * 0.9)]]:
			var n: Vector2 = d.orthogonal() * float(layer[0])
			var poly := PackedVector2Array([from - n, to - n, to + n, from + n])
			var c: Color = layer[1]
			draw_polygon(poly, PackedColorArray([c, c, c, c]), uv, TRAIL_THRUST)

	static func _ease(x: float) -> float:
		return 1.0 - pow(1.0 - x, 3.0)


## X-cut hit flash: pops in fast, then shrinks and fades.
class ImpactFlash extends Sprite2D:

	var color := Color.WHITE
	var size := 120.0
	var _t := 0.0

	func _ready() -> void:
		texture = IMPACT
		z_index = 6
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		modulate = Color(color.lightened(0.2), 0.85)

	func _process(delta: float) -> void:
		_t += delta
		var k := _t / 0.18
		if k >= 1.0:
			queue_free()
			return
		var pop := 0.55 + 0.45 * minf(k / 0.2, 1.0) - 0.25 * maxf(k - 0.4, 0.0)
		scale = Vector2.ONE * (size / 512.0) * 2.0 * pop
		modulate.a = 0.85 * (1.0 - k * k)
