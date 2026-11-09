extends Node2D
## Melee weapon held in the mech's hand (created by MeleeKit, drawn in world space).
##   HAND     the hilt never leaves the fist: every pose puts the weapon's grip (GRIP_AT) on the fist of
##            the sprite's current frame (HeldWeapon.fist(), carried by the Body: the walk / boost / bank /
##            dash frames, the torso turn and twist, the thrust lunge and the chassis size). The rig draws
##            BELOW the mech, so the fist closes over the handle. Swings get their motion from the blade
##            turning in the fist and the torso twisting into the cut (Mech.swing_twist; spins whirl the
##            whole mech round); thrusts lunge the body forward while the blade surges past its length.
##   REST     while a melee weapon is equipped the blade is always in hand, angled out to the front-right
##            of the aim (Dual Sabers: one blade per fist) and follows the aim smoothly.
##   SWING    swing() plays an attack from wherever the blade is, then it eases back to its rest pose.
##            Every weapon moves its own way (MeleeKit "anim" / "rest"):
##              arc     Beam Saber: snappy forehand / backhand slashes with a small step in.
##              flurry  Dual Sabers: the right hand cuts, then the left, then both cross in an X.
##              draw    Katana: held low behind; a lightning draw cut across the front and a long held
##                      follow-through; "iaido" keeps it low through the dash, then one blinding cut.
##              pierce2 / sweep   Spear (MeleeKit._spear_move): a TWIN STAB (two quick stabs, each with
##                      a piercing streak) and a SWEEP (swung wide like a staff, then twirled back);
##                      "charge" twirls it once, then braces the point through the whole dash.
##              cleave / axe_whirl / leap   Energy Axe (MeleeKit._axe_move): heaved over the shoulder into
##                      a diagonal CLEAVE that bites (and cracks) the ground, a WHIRLWIND spin, and the LEAP
##                      SLAM finisher (the mech springs up - the Body grows - and crashes down). Its head
##                      glows hot through the wind-ups and sheds embers ("hot").
##              chop    the Greatsword's cleave finisher: back over the shoulder, then over the top and
##                      down in front, foreshortened while raised (shorter, wider).
##              heavy   Greatsword: off the shoulder, an accelerating sweep whose weight carries the body
##                      round in a long follow-through.
##              spin    Scythe (held out to the front-right) / Dual Sabers' whirl: a wind-up, then the whole
##                      mech whirls round with the blade.
##            The Energy Sword has its own set (_cel_pose): "thrust" lunge, "xcut", "moon", "spin".
##            swing() returns when the blow lands (LAND), so MeleeKit hits as the blade gets there.
##   TRAIL    the blade tip leaves a continuous ribbon (Higgsfield trail textures in assets/hq/fx,
##            tinted with the weapon colour, additive) built from the blade's real recent positions,
##            sub-sampled so fast arcs stay smooth. Thrusts draw a piercing streak instead.
##   IMPACT   impact() flashes an X-cut burst on whatever was hit and briefly freezes the swing
##            (a hit-pause for the blade only, so game timing and tests are unaffected).
##   CEL      weapons with "cel" (the Energy Sword) swap the textured ribbon and X-cut sprite for the
##            hand-drawn cel smear and cross flash in player/weapons/energy_sword_fx.gd.
##   BEAM     weapons with "beam" (Beam Saber, Dual Beam Sabers) draw only the hilt from the art; the blade
##            is a Gundam-style beam (player/weapons/beam_blade.gdshader: white-hot needle core, saturated
##            halo, emitter flare, hum) that ignites out of the emitter when drawn.

const HUE_SHADER := preload("res://player/weapons/blade_hue.gdshader")
const BEAM_SHADER := preload("res://player/weapons/beam_blade.gdshader")
## Beam weapons: the top of the hilt (the emitter) as a fraction of the art height from the bottom, the
## ignition time, and the quad margin around the beam for its glow (px).
const BEAM_HILT := 0.315
const IGNITE_TIME := 0.07
const BEAM_MARGIN := 36.0
const TRAIL_ENERGY := preload("res://assets/hq/fx/slash_trail_energy.png")
const TRAIL_HEAVY := preload("res://assets/hq/fx/slash_trail_heavy.png")
const TRAIL_THRUST := preload("res://assets/hq/fx/slash_trail_thrust.png")
const IMPACT := preload("res://assets/hq/fx/slash_impact.png")
const GLOW := preload("res://assets/fx/glow.tres")

## Rest pose: blade angled this far to the right of the aim, drawn at this fraction of its length.
const REST_ANGLE := 0.45
const REST_SCALE := 0.8
## Thrust streaks start this far in front of the mech.
const ARM := 18.0
## Torso twist per radian of blade-off-aim while swinging (capped), so the body turns into the cut and
## carries the fist with it. Not for the Dual Sabers' crossing cuts (both fists stay square).
const TWIST := 0.35
const TWIST_MAX := 0.6
## Thrusts: how far the body lunges into the stab (the fist goes with it), and how much longer the blade
## surges at full extension.
const LUNGE := 10.0
const THRUST_SURGE := 0.25
## Thrust-type swings (no swept ribbon; a piercing streak instead).
const THRUSTS := ["thrust", "jab", "charge", "pierce2"]
## Thrusts with more than one stab: when each stab starts, as a fraction of the swing (each fires a streak).
const STABS := {"pierce2": [0.05, 0.31]}
## The Spear's TWIN STAB: its second stab lands here (the first at LAND).
const PIERCE2_SECOND := 0.4
## Heavier swings take longer than the attack's designed life (x), and may run up to MAX_DUR seconds
## (default 0.5): the Axe's big moves live on their wind-up.
const SLOW := {"chop": 1.15, "heavy": 1.1, "cleave": 1.25, "axe_whirl": 1.2, "leap": 1.45}
const MAX_DUR := {"cleave": 0.62, "axe_whirl": 0.6, "leap": 0.8}
## When the blow lands, as a fraction of the swing: as the blade sweeps through the target (the chops and
## heavy sweeps well into their swing, after the wind-up), so the hit-pause catches the blade on contact.
const LAND := {"arc": 0.18, "flurry": 0.18, "draw": 0.13, "thrust": 0.2, "jab": 0.2, "spin": 0.15, "chop": 0.55,
	"heavy": 0.42, "iaido": 0.6, "pierce2": 0.15, "sweep": 0.23, "cleave": 0.52, "axe_whirl": 0.42, "leap": 0.56}
## "hot" weapons (Energy Axe): the head's centre as a fraction of the art height from the bottom (heat glow and
## embers come off it), and its idle glow.
const HEAD_AT := 0.8
const IDLE_HEAT := 0.3
## Leap slam: how much bigger the mech gets at the top of the hop (seen from above = nearer the camera; its
## shadow stays on the ground) and how much it squashes on landing.
const HOP := 0.24
const SQUASH := 0.1
const TRAIL_LIFE := 0.12
const TRAIL_SUBSTEPS := 4
## Where along the blade the ribbon starts (fraction of blade length from the hilt).
const TRAIL_INNER := 0.28
## Impact flashes per swing, and how long the blade holds its finishing pose before easing back.
const MAX_FLASHES := 3
const HOLD := 0.22
## Where the fist closes on each weapon, as a fraction of its art height from the bottom (measured from
## assets/hq/weapons/*.png): swords at the top of the grip just under the guard / emitter, so the blade
## comes straight out of the fist (the rest of the grip and the pommel stick out behind the hand);
## long-hafted weapons a way up the shaft (the scythe near the end of its snath, for the reach).
const GRIP_AT := {"beam_saber": 0.2, "katana": 0.19, "spear": 0.28, "axe": 0.22, "scythe": 0.16, "greatsword": 0.23,
	"energy_sword": 0.13}
## Energy weapons' glowing part (TrailLayer._shape_glow), as a fraction of the art height from the bottom
## where it starts: the Katana's blade, the Spear's head, the Scythe's head and curved blade.
const GLOW_FROM := {"katana": 0.31, "spear": 0.64, "scythe": 0.7}
## Art whose handle isn't down the middle of the picture: the handle's centre, in art px from the left.
## (The Beam Scythe's shaft runs down its left side, x 37-42 of 126, with the blade curving off to the right.)
const GRIP_X := {"scythe": 39.5}
## Cel smears: recorded only during the strike, gone again quickly.
const CEL_TRAIL_LIFE := 0.12
## Energy Sword art: the bottom CEL_HILT of the picture is the hilt (drawn from the art); the blade
## above it is drawn in code (EnergySwordFx.draw_blade) so it ends in a real point.
const CEL_HILT := 0.25
## Sparks drifting off the Energy Sword while it's equipped (per second).
const MOTE_RATE := 16.0
## Energy Sword swings are animated like a held sword (see _cel_pose): the hilt stays in the fist and the
## torso twists with the blade (Mech.swing_twist). Phases as fractions of the swing: anticipation (wind
## back), STRIKE (fast; the only part that leaves a smear), follow-through hold, then recovery to rest.
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
## Width multiplier per blade (a chop's raised blade is foreshortened: shorter and wider).
var _wide := [1.0, 1.0]
# Active swing.
var _sw := {}
var _t := 0.0
var _dur := 0.2
var _start := [0.0, 0.0]
# Trail samples per blade: [time, grip, angle, ext].
var _trail := [[], []]
## Thrust streaks in flight: {from, dir, t, len, life, seed}.
var _streaks: Array = []
var _fx: Node2D
var _started := false
var _flashes := 0
var _hold := 0.0
## Where the fist holds the current weapon, as a fraction of its art height from the bottom (GRIP_AT), and
## across it in art px (GRIP_X; -1 = the middle of the art).
var _grip_at := 0.12
var _grip_x := -1.0
## Cel-drawn weapon (Energy Sword): cel smear + cross flash instead of the ribbon / X-cut sprite.
var _cel := false
## "hot" weapon (Energy Axe): head heat 0..1 (glow + embers), its target this frame, and the embers
## [position, velocity, age, life, size].
var _hot := false
var _heat := 0.0
var _heat_target := 0.0
var _embers: Array = []
var _ember_t := 0.0
## Leap slam: hop height 0..1 and landing squash 0..1 this frame (scale the Body), and whether the Body's
## scale is currently changed by the rig.
var _hop := 0.0
var _squash := 0.0
var _scaled := false
## Beam weapon (sabers): code-drawn beam (BeamLayer); 0..1 ignition progress, beam width scale.
var _beam := false
var _ignite := 0.0
var _beam_w := 1.0
var _beam_layer: Node2D
var _smear: Node2D
## Energy Sword sparks: [position, velocity, age, life, size].
var _motes: Array = []
var _mote_t := 0.0
## Energy Sword: in the fast strike part of a swing (smear recorded), and the torso twist being applied.
var _striking := false
var _twist := 0.0
var _twist_target := 0.0
## Twist kept through a non-cel swing's finishing hold; the thrust lunge (Body offset) this frame.
var _hold_twist := 0.0
var _lunge := Vector2.ZERO


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
	_beam_layer = BeamLayer.new()
	_beam_layer.rig = self
	add_child(_beam_layer)


## Plays one attack. `life` is the visual length the attack was designed for. Returns the seconds until the
## blow lands (LAND; 0 = at once). opts: "hand" (Dual Sabers: 0 right, 1 left, -1 both), "big" (finisher
## chop).
func swing(w: Dictionary, mode: String, dir: Vector2, length: float, life: float, side: float, turns := 1.0,
		twin := false, opts := {}) -> float:
	_setup(w)
	_length = length
	_sw = {"mode": mode, "dir": dir, "half": minf(w["half"], 1.5), "side": side, "turns": turns, "twin": twin,
		"hand": int(opts.get("hand", -1)), "big": bool(opts.get("big", false))}
	var interval := 1.0 / (float(w["rate"]) * Upgrades.fire_rate_mult())
	_dur = clampf(minf(life * 1.15 * float(SLOW.get(mode, 1.0)), interval * 0.95), 0.12, float(MAX_DUR.get(mode, 0.5)))
	_t = 0.0
	_start = [_angle[0], _angle[1]]
	_flashes = 0
	# (cel swings animate their own follow-through and recovery)
	_hold = 0.0 if w.get("cel", false) else HOLD
	# Thrusts fire a piercing streak as each stab starts (cel weapons draw their own, EnergySwordFx.lunge).
	_sw["stabs"] = STABS.get(mode, [0.0]) if mode in THRUSTS and not w.get("cel", false) else []
	_sw["next_stab"] = 0
	_sw["length"] = length
	return _dur * float(LAND.get(mode, 0.0))


## Seconds from the start of the current swing to `frac` of it (a second blow landing, a sound).
func land_time(frac: float) -> float:
	return _dur * frac


## Where a "hot" weapon's head is now (blade 0), in world space.
func head_pos(b := 0) -> Vector2:
	var size := _tex.get_size()
	var s: float = _length * float(_ext[b]) / (size.y * (1.0 - _grip_at))
	return _grip[b] + Vector2.from_angle(_angle[b]) * (HEAD_AT - _grip_at) * size.y * s


## Ground cracks where a heavy blow lands: dark fissures glowing `color` (fading), on the floor.
static func crack(pos: Vector2, radius: float, color: Color, lines := 7) -> void:
	var c := GroundCrack.new()
	c.position = pos
	c.radius = radius
	c.color = color
	c.lines = lines
	Combat.world().add_child(c)


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
	_beam_layer.visible = show and _beam
	if not show and is_instance_valid(mech):
		mech.swing_twist = 0.0
		mech.body.position = Vector2.ZERO
		_twist = 0.0
		if _scaled and not mech.dead and not mech.is_falling():
			mech.body.scale = Vector2.ONE * mech._body_scale
		_scaled = false
	if not show:
		_sw = {}
		_trail = [[], []]
		_streaks.clear()
		_embers.clear()
		_started = false
		_ignite = 0.0
		_heat = 0.0
		return
	if id != _id:
		_equip(id)
	# Beams ignite out of the emitter (tip first) whenever the weapon comes out.
	_ignite = minf(_ignite + delta / IGNITE_TIME, 1.0)
	_beam_layer.visible = _beam
	var blades := 2 if _twin() else 1
	# Hit-pause: the blade (and its trail) hold still for a moment - still in the fist.
	if _hitstop > 0.0:
		_hitstop -= delta
		_to_fists(blades)
		queue_redraw()
		_fx.queue_redraw()
		_smear.queue_redraw()
		_beam_layer.queue_redraw()
		return
	_time += delta
	_striking = false
	_twist_target = 0.0
	_lunge = Vector2.ZERO
	_wide[0] = 1.0
	_wide[1] = 1.0
	_hop = 0.0
	_squash = 0.0
	_heat_target = IDLE_HEAT if _hot else 0.0
	if not _sw.is_empty():
		_t += delta
		var k := clampf(_t / _dur, 0.0, 1.0)
		if _cel:
			_cel_pose(k)
		else:
			for b in blades:
				if _moves(b):
					_swing_pose(b, k)
				else:
					_rest_pose(b, delta)
		# Each stab of a thrust fires its piercing streak as it starts.
		var stabs: Array = _sw.get("stabs", [])
		var ns: int = _sw.get("next_stab", 0)
		if ns < stabs.size() and k >= float(stabs[ns]):
			_sw["next_stab"] = ns + 1
			var sd: Vector2 = _sw["dir"]
			_streaks.append({"from": mech.global_position + sd * ARM, "dir": sd, "t": 0.0,
				"len": float(_sw["length"]) * 1.25, "life": clampf(_dur * 1.4, 0.22, 0.4), "seed": randi()})
		if _t >= _dur:
			_sw = {}
			_hold_twist = _twist_target
	elif _hold > 0.0:
		# Hold the finishing pose (and the torso's turn) for a beat (combos chain on from here).
		_hold -= delta
		_twist_target = _hold_twist
	else:
		for b in blades:
			_rest_pose(b, delta)
	if not _started:
		_started = true
		for b in blades:
			_rest_pose(b, 1.0)
	# The torso twists into the swing and lunges into thrusts; whatever the pose, the hilt is in the fist.
	_twist = wrapf(lerp_angle(_twist, _twist_target, 1.0 - exp(-25.0 * delta)), -PI, PI)
	mech.swing_twist = _twist
	mech.body.position = mech.body.position.lerp(_lunge, 1.0 - exp(-30.0 * delta))
	# Leap slam: the Body grows as the mech springs up and squashes as it lands (the fist goes with it).
	if _hop > 0.0 or _squash > 0.0 or _scaled:
		mech.body.scale = Vector2.ONE * mech._body_scale * (1.0 + HOP * _hop - SQUASH * _squash)
		_scaled = _hop > 0.0 or _squash > 0.0
	_to_fists(blades)
	# Record the trail while the blade is moving through an attack (and let it fade after). Cel swings
	# only smear during the fast strike, never the wind-up or recovery.
	for b in blades:
		var tr: Array = _trail[b]
		if not _sw.is_empty() and _sw["mode"] not in THRUSTS and (not _cel or _striking):
			tr.append([_time, _grip[b], _angle[b], _ext[b]])
		while not tr.is_empty() and _time - tr[0][0] > (CEL_TRAIL_LIFE if _cel else TRAIL_LIFE):
			tr.pop_front()
	for s: Dictionary in _streaks:
		s["t"] += delta
	_streaks = _streaks.filter(func(s: Dictionary) -> bool: return s["t"] < s["life"])
	_update_motes(delta)
	_update_heat(delta)
	queue_redraw()
	_fx.queue_redraw()
	_smear.queue_redraw()
	_beam_layer.queue_redraw()


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


## "hot" weapons (Energy Axe): the head heats up through a wind-up and swing (the poses set _heat_target) and
## cools at rest to a low smoulder; embers stream off it, more the hotter it is, and drift up and fade.
func _update_heat(delta: float) -> void:
	if not _hot:
		_embers.clear()
		_heat = 0.0
		return
	_heat = move_toward(_heat, _heat_target, delta * (5.0 if _heat_target > _heat else 1.6))
	_ember_t -= delta
	var rate := 5.0 + 55.0 * _heat * _heat
	while _ember_t <= 0.0:
		_ember_t += 1.0 / rate
		var at := head_pos() + Vector2.from_angle(randf() * TAU) * randf_range(2.0, 16.0)
		var vel := Vector2.from_angle(randf() * TAU) * randf_range(10.0, 50.0 + 90.0 * _heat)
		_embers.append([at, vel, 0.0, randf_range(0.3, 0.7), randf_range(1.6, 3.4) * (0.7 + 0.5 * _heat)])
	for e: Array in _embers:
		e[0] += e[1] * delta
		e[1] *= 1.0 - 2.5 * delta
		e[2] += delta
	_embers = _embers.filter(func(e: Array) -> bool: return e[2] < e[3])


func _twin() -> bool:
	return MeleeKit.WEAPONS[_id].get("twin_rest", false) or _id == &"dual_sabers"


func _equip(id: StringName) -> void:
	_id = id
	var w: Dictionary = MeleeKit.WEAPONS[id]
	_tex = load("res://assets/hq/weapons/%s.png" % w["tex"])
	_grip_at = GRIP_AT.get(String(w["tex"]), 0.12)
	_grip_x = GRIP_X.get(String(w["tex"]), -1.0)
	_cel = w.get("cel", false)
	_beam = w.get("beam", false)
	_beam_w = float(w.get("beam_w", 1.0))
	_ignite = 0.0
	_hot = w.get("hot", false)
	_embers.clear()
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


## Puts each blade's hilt in its fist.
func _to_fists(blades: int) -> void:
	for b in blades:
		_grip[b] = _fist(b)


## The fist holding blade `b` this frame, in world space: the right fist (the left one for the Dual
## Sabers' off-hand blade) of the sprite's current frame, carried by the Body's turn, twist, lunge and scale.
func _fist(b: int) -> Vector2:
	return mech.body.to_global(HeldWeapon.fist(mech, 1.0 if b == 0 else -1.0))


## Rest: the weapon where it's held between attacks (MeleeKit "rest": out front, levelled, out to the side,
## low behind, on the shoulder; the off-hand blade mirrored), easing there.
func _rest_pose(b: int, delta: float) -> void:
	var sgn := 1.0 if b == 0 else -1.0
	var t := 1.0 - exp(-9.0 * delta)
	_angle[b] = lerp_angle(_angle[b], mech.aim_dir.angle() + _rest_angle() * sgn, t)
	_ext[b] = lerpf(_ext[b], _rest_ext(), t)


## Where the current weapon is held between attacks (radians to the right of the aim), and how much of it
## shows there.
func _rest_angle() -> float:
	return float(MeleeKit.WEAPONS[_id].get("rest", REST_ANGLE))


func _rest_ext() -> float:
	return float(MeleeKit.WEAPONS[_id].get("rest_ext", REST_SCALE))


## Whether blade `b` takes part in the current swing (the Dual Sabers' flurry: one hand at a time, or both).
func _moves(b: int) -> bool:
	var hand: int = _sw.get("hand", -1)
	return hand < 0 or hand == b


## Attack pose at progress k (0..1) of the current swing: the blade's angle, length and width, the torso
## twist and the lunge (the hilt stays in the fist, see _to_fists). Angles are worked out around the swing
## direction d ("rel" = radians to the mech's right of it).
func _swing_pose(b: int, k: float) -> void:
	var dir: Vector2 = _sw["dir"]
	var d := dir.angle()
	var side: float = _sw["side"]
	match _sw["mode"]:
		"thrust", "jab":
			# Draw back a touch, then lunge into the stab with the blade surging past its full length, and
			# ease back. Spear jabs: every other one spins the spear round in the fist on the way back.
			var push := 0.0
			if k < 0.12:
				push = lerpf(0.0, -0.3, k / 0.12)
			elif k < 0.42:
				push = lerpf(-0.3, 1.0, _ease_out((k - 0.12) / 0.3))
			else:
				push = lerpf(1.0, 0.0, smoothstep(0.42, 1.0, k))
			_angle[b] = d
			_ext[b] = 1.0 + THRUST_SURGE * maxf(push, 0.0)
			if _sw["mode"] == "jab" and side > 0.0 and k > 0.45:
				var u := _ease_in_out((k - 0.45) / 0.55)
				_angle[b] = d + TAU * u
				_ext[b] = lerpf(_ext[b], 0.8, sin(u * PI))
			_lunge = dir * push * LUNGE
		"charge":
			# Spear CHARGE: the spear whirls once round in the fist as the mech launches, then it's braced -
			# the point levelled at the target through the whole dash - and back.
			var push := 1.0
			if k < 0.1:
				push = lerpf(0.0, -0.4, k / 0.1)
			elif k < 0.2:
				push = lerpf(-0.4, 1.0, _ease_out((k - 0.1) / 0.1))
			elif k > 0.75:
				push = lerpf(1.0, 0.0, smoothstep(0.75, 1.0, k))
			var twirl := _ease_in_out(minf(k / 0.2, 1.0))
			_angle[b] = d + side * TAU * twirl
			_ext[b] = (1.0 + THRUST_SURGE * 1.3 * maxf(push, 0.0)) * (1.0 - 0.3 * sin(twirl * PI))
			_lunge = dir * push * LUNGE * 1.3
		"pierce2":
			# Spear TWIN STAB: draw back, stab, snap halfway back, stab again harder (both land: LAND and
			# PIERCE2_SECOND), then ease back. The point weaves across between the two stabs.
			var push := 0.0
			if k < 0.05:
				push = lerpf(0.0, -0.3, k / 0.05)
			elif k < 0.17:
				push = lerpf(-0.3, 1.0, _ease_out((k - 0.05) / 0.12))
			elif k < 0.31:
				push = lerpf(1.0, 0.1, _ease_in_out((k - 0.17) / 0.14))
			elif k < 0.42:
				push = lerpf(0.1, 1.15, _ease_out((k - 0.31) / 0.11))
			else:
				push = lerpf(1.15, 0.0, smoothstep(0.5, 1.0, k))
			_angle[b] = d + 0.08 * side * (1.0 - 2.0 * smoothstep(0.2, 0.33, k))
			_ext[b] = 1.0 + THRUST_SURGE * maxf(push, 0.0)
			_lunge = dir * push * LUNGE
			_twist_target = 0.12 * side * (1.0 - 2.0 * smoothstep(0.2, 0.33, k))
		"sweep":
			# Spear SWEEP: swung wide like a staff - out to one side, a fast flat sweep across the front at
			# full reach (the blow lands as it crosses), then it keeps its momentum and twirls round once in
			# the fist back to levelled.
			var ext := 1.05
			if k < 0.15:
				var u := _ease_in_out(k / 0.15)
				_angle[b] = lerp_angle(_start[b], d - 1.3 * side, u)
				ext = lerpf(_rest_ext(), 0.92, u)
				_twist_target = -0.35 * side * u
			elif k < 0.5:
				var e := _ease_out((k - 0.15) / 0.35)
				_angle[b] = d + lerpf(-1.3, 1.25, e) * side
				_twist_target = lerpf(-0.35, 0.45, e) * side
			else:
				var u := _ease_in_out((k - 0.5) / 0.5)
				_angle[b] = d + side * lerpf(1.25, TAU, u)
				ext = lerpf(1.05, _rest_ext(), u) * (1.0 - 0.3 * sin(u * PI))
				_twist_target = 0.45 * side * (1.0 - u)
			_ext[b] = ext
			_lunge = dir * 5.0 * sin(clampf((k - 0.1) / 0.5, 0.0, 1.0) * PI)
		"draw":
			# Katana: a lightning draw cut from wherever the blade is (low behind on the right at rest) across
			# the front to the far side, a long held follow-through (zanshin), then back low. It cuts away
			# from the side the blade is on, so chained cuts go back and forth across the front.
			var rel0 := angle_difference(d, _start[b])
			var to := -1.0 if rel0 > -0.2 else 1.0
			var rel := 1.45 * to
			if k < 0.08:
				rel = rel0 - 0.18 * to * (k / 0.08)
			elif k < 0.3:
				rel = lerpf(rel0 - 0.18 * to, 1.57 * to, _ease_out4((k - 0.08) / 0.22))
			else:
				rel = lerpf(1.57 * to, 1.45 * to, smoothstep(0.3, 0.6, k))
			_angle[b] = d + rel
			_ext[b] = lerpf(_rest_ext(), 1.08, smoothstep(0.04, 0.2, k)) - 0.08 * smoothstep(0.3, 0.6, k)
			_twist_target = clampf(rel * 0.5, -0.75, 0.75)
			_lunge = dir * 7.0 * sin(clampf((k - 0.08) / 0.45, 0.0, 1.0) * PI)
		"iaido":
			# Katana IAIDO: the blade stays low behind through the dash, then one blinding cut across the
			# front (the blow lands with it) and a long hold.
			var low := _rest_angle()
			var rel := low
			if k < 0.55:
				_angle[b] = lerp_angle(_start[b], d + low, smoothstep(0.0, 0.3, k))
				_ext[b] = 0.7
				_twist_target = 0.3
				return
			elif k < 0.68:
				rel = lerpf(low, -1.75, _ease_out4((k - 0.55) / 0.13))
			else:
				rel = lerpf(-1.75, -1.6, smoothstep(0.68, 0.9, k))
			_angle[b] = d + rel
			_ext[b] = 1.12
			_twist_target = clampf(rel * 0.5, -0.8, 0.8)
		"chop":
			# Axe / the slam and cleave finishers ("big"): an overhead chop. Wind-up: the blade goes back over
			# the right shoulder, raised (seen from above: shorter and wider) as the torso turns away; then
			# it comes over the top, accelerating, slams down in front (the blow lands here), bites, holds.
			var big: bool = _sw["big"]
			var back := 2.6
			var a := d
			var ext := 1.05
			var wide := 1.0
			var tw := -0.25
			var push := 1.0
			if k < 0.4:
				var u := _ease_in_out(k / 0.4)
				a = lerp_angle(_start[b], d + back, u)
				ext = lerpf(_rest_ext(), 0.62, u)
				wide = 1.0 + 0.25 * u
				tw = 0.32 * u
				push = -0.4 * u
			elif k < 0.55:
				var e := pow((k - 0.4) / 0.15, 2.0)
				a = d + back * (1.0 - e)
				ext = lerpf(0.62, 1.05, e) - 0.5 * sin(e * PI)
				wide = lerpf(1.25, 1.0, e) + 0.3 * sin(e * PI)
				tw = lerpf(0.32, -0.25, e)
				push = lerpf(-0.4, 1.0, e)
			else:
				var u := clampf((k - 0.55) / 0.45, 0.0, 1.0)
				a = d - 0.06 * sin(minf(u * 3.0, 1.0) * PI)
				ext = lerpf(1.05, 1.0, u)
				tw = lerpf(-0.25, -0.12, u)
				push = lerpf(1.0, 0.5, u)
			var heavy := 1.25 if big else 1.0
			_angle[b] = a
			_ext[b] = ext * (1.08 if big else 1.0)
			_wide[b] = wide
			_twist_target = tw * heavy
			_lunge = dir * push * LUNGE * heavy
		"cleave":
			# Axe CLEAVE: heaved up high over the right shoulder (seen from above: foreshortened, the head
			# heating up) and the torso coils away; a beat at the top; then a brutal diagonal cut over and
			# down across the front to the far side (the blow lands as it crosses), where the axe bites into
			# the ground and shudders; then it's wrenched free back toward the shoulder.
			var hi := 2.35
			var lo := -0.95
			var a := d
			var ext := 1.0
			var wide := 1.0
			var tw := 0.0
			var push := 0.0
			if k < 0.36:
				var u := _ease_in_out(k / 0.36)
				a = lerp_angle(_start[b], d + hi, u)
				ext = lerpf(_rest_ext(), 0.6, u)
				wide = 1.0 + 0.35 * u
				tw = 0.45 * u
				push = -0.45 * u
				_heat_target = 1.0
			elif k < 0.42:
				var u := (k - 0.36) / 0.06
				a = d + hi + 0.12 * sin(u * PI)
				ext = 0.6
				wide = 1.35
				tw = 0.45 + 0.08 * sin(u * PI)
				push = -0.45
				_heat_target = 1.0
			elif k < 0.54:
				var e := pow((k - 0.42) / 0.12, 1.8)
				a = d + lerpf(hi, lo, e)
				ext = lerpf(0.6, 1.1, e) - 0.25 * sin(e * PI)
				wide = lerpf(1.35, 1.0, e) + 0.2 * sin(e * PI)
				tw = lerpf(0.45, -0.5, e)
				push = lerpf(-0.45, 1.0, e)
				_heat_target = 1.0
			elif k < 0.76:
				var u := (k - 0.54) / 0.22
				a = d + lo + 0.05 * sin(u * 40.0) * (1.0 - u)
				ext = 1.06
				tw = -0.5
				push = 1.0 - 0.3 * u
				_heat_target = 0.75
			else:
				var u := _ease_in_out((k - 0.76) / 0.24)
				a = d + lerpf(lo, _rest_angle(), u)
				ext = lerpf(1.06, _rest_ext(), u)
				tw = lerpf(-0.5, 0.0, u)
				push = lerpf(0.7, 0.0, u)
			_angle[b] = a
			_ext[b] = ext
			_wide[b] = wide
			_twist_target = tw
			_lunge = dir * push * LUNGE
		"axe_whirl":
			# Axe WHIRLWIND: hauled out to one side, then the whole mech spins once and a bit with the axe
			# held out at full reach (the blow lands all round as it comes past), and staggers to a stop.
			var a0 := d + 1.3 * side
			var spin := TAU + 0.5
			var a := a0
			var ext := 1.0
			if k < 0.22:
				var u := _ease_in_out(k / 0.22)
				a = lerp_angle(_start[b], a0, u)
				ext = lerpf(_rest_ext(), 0.85, u)
				_heat_target = 1.0
			elif k < 0.78:
				var e := _ease_in_out((k - 0.22) / 0.56)
				a = a0 - side * spin * e
				ext = 1.12 + 0.08 * sin(e * PI)
				_heat_target = 1.0
			else:
				var u := _ease_out((k - 0.78) / 0.22)
				a = lerp_angle(a0 - side * spin, mech.aim_dir.angle() + _rest_angle(), u)
				ext = lerpf(1.12, _rest_ext(), u)
				_heat_target = 0.6
			_angle[b] = a
			_ext[b] = ext
			# The whole mech turns with the axe.
			if k < 0.8:
				_twist_target = angle_difference(mech.aim_dir.angle() + _rest_angle(), a)
			_lunge = dir * 3.0 * sin(clampf((k - 0.22) / 0.56, 0.0, 1.0) * PI)
		"leap":
			# Axe LEAP SLAM: the mech springs up (seen from above it grows; its shadow stays on the ground)
			# hauling the axe back over its head, hangs for a beat, then crashes down behind the axe, which
			# comes over the top into the ground in front (the blow lands there); a squash on landing, the
			# axe shudders in the ground, then it's wrenched out.
			var back := PI * 0.92
			var a := d
			var ext := 1.0
			var wide := 1.0
			var push := 0.0
			var tw := 0.0
			if k < 0.38:
				var u := _ease_out(k / 0.38)
				_hop = u
				a = lerp_angle(_start[b], d + back, _ease_in_out(k / 0.38))
				ext = lerpf(_rest_ext(), 0.42, u)
				wide = 1.0 + 0.45 * u
				push = -0.3 * u
				tw = 0.25 * u
				_heat_target = 1.0
			elif k < 0.47:
				_hop = 1.0
				a = d + back
				ext = 0.42
				wide = 1.45
				push = -0.3
				tw = 0.25
				_heat_target = 1.0
			elif k < 0.56:
				var e := pow((k - 0.47) / 0.09, 2.0)
				_hop = 1.0 - e
				a = d + back * (1.0 - e)
				ext = lerpf(0.42, 1.15, e)
				wide = lerpf(1.45, 1.0, e)
				push = lerpf(-0.3, 1.2, e)
				tw = lerpf(0.25, -0.1, e)
				_heat_target = 1.0
			elif k < 0.8:
				var u := (k - 0.56) / 0.24
				_squash = maxf(0.0, 1.0 - u * 3.0)
				a = d + 0.04 * sin(u * 30.0) * (1.0 - u)
				ext = 1.12
				push = 1.2 - 0.4 * u
				tw = -0.1
				_heat_target = 0.8
			else:
				var u := _ease_in_out((k - 0.8) / 0.2)
				a = d + lerpf(0.0, _rest_angle(), u)
				ext = lerpf(1.12, _rest_ext(), u)
				push = lerpf(0.8, 0.0, u)
			_angle[b] = a
			_ext[b] = ext
			_wide[b] = wide
			_twist_target = tw
			_lunge = dir * push * LUNGE * 1.4
		"heavy":
			# Greatsword: a momentum sweep. Off the shoulder into a wind-up on the side the blade is on, an
			# accelerating sweep across the front (the blow lands mid-sweep), and its weight carries the
			# body on round in a long follow-through. Chained sweeps come back the other way.
			var rel0 := angle_difference(d, _start[b])
			var s0 := 1.0 if rel0 >= -0.3 else -1.0
			var rel := -1.9 * s0
			var tw := -0.75 * s0
			var push := 0.3
			if k < 0.3:
				var u := _ease_in_out(k / 0.3)
				rel = angle_difference(d, lerp_angle(_start[b], d + 1.85 * s0, u))
				tw = 0.35 * s0 * u
				push = -0.35 * u
			elif k < 0.55:
				var e := _ease_in_out((k - 0.3) / 0.25)
				rel = lerpf(1.85 * s0, -1.45 * s0, e)
				tw = lerpf(0.35 * s0, -0.6 * s0, e)
				push = lerpf(-0.35, 0.8, e)
			elif k < 0.8:
				var e := _ease_out((k - 0.55) / 0.25)
				rel = lerpf(-1.45 * s0, -1.9 * s0, e)
				tw = lerpf(-0.6 * s0, -0.75 * s0, e)
				push = lerpf(0.8, 0.3, e)
			_angle[b] = d + rel
			_ext[b] = lerpf(_rest_ext(), 1.0, smoothstep(0.0, 0.3, k))
			_twist_target = tw
			_lunge = dir * push * LUNGE
		"flurry":
			# Dual Sabers: one hand cuts inward across the front while the other blade stays ready, or both
			# cross in an X (hand -1).
			if int(_sw["hand"]) < 0:
				_arc_pose(b, k, dir)
				return
			var sgn := 1.0 if b == 0 else -1.0
			var a := _arc(k, _start[b], d + 1.05 * sgn, d - 1.05 * sgn, -0.2 * sgn)
			_angle[b] = a
			_ext[b] = 1.0
			_twist_target = clampf(angle_difference(mech.aim_dir.angle(), a) * TWIST, -TWIST_MAX, TWIST_MAX)
			_lunge = dir * 4.0 * sin(clampf((k - 0.1) / 0.45, 0.0, 1.0) * PI)
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
			_ext[b] = 1.0 + 0.35 * sin(strike * PI)
		"spin":
			# Scythe / Dual Sabers' whirl: a short wind-up the other way, then the whole
			# mech whirls round with the blade, which surges out mid-whirl; the off-hand blade points opposite.
			var turns: float = _sw["turns"]
			var a: float = _start[0] - 0.6 * side * _ease_in_out(minf(k / 0.15, 1.0))
			if k >= 0.15:
				a = _start[0] - 0.6 * side + side * (TAU * turns + 0.6) * _ease_in_out((k - 0.15) / 0.85)
			_angle[b] = a if b == 0 else _angle[0] + PI
			_ext[b] = 1.0 + 0.15 * sin(clampf((k - 0.15) / 0.85, 0.0, 1.0) * PI)
			if b == 0:
				_twist_target = angle_difference(mech.aim_dir.angle() + _rest_angle(), _angle[0])
		_:
			_arc_pose(b, k, dir)


## The quick arc (Beam Saber slashes, the Dual Sabers' X): wind up to the start of the arc, strike through
## it, overshoot, settle, with a small step into the cut. The off-hand blade (Dual Sabers) mirrors across
## the aim, so the two cuts cross in an X; a single blade turns the torso into the cut.
func _arc_pose(b: int, k: float, dir: Vector2) -> void:
	var d := dir.angle()
	var side: float = _sw["side"]
	var half: float = _sw["half"]
	var a := _arc(k, _start[0], d - half * side, d + half * side, 0.2 * side)
	_angle[b] = a if b == 0 else 2.0 * d - a
	_ext[b] = 1.0
	if b == 0:
		_lunge = dir * 5.0 * sin(clampf((k - 0.1) / 0.45, 0.0, 1.0) * PI)
		if not _twin():
			_twist_target = clampf(angle_difference(mech.aim_dir.angle(), a) * TWIST, -TWIST_MAX, TWIST_MAX)


## Arc angle at progress k: a snap of wind-up from `from` to a0, an ease-out strike to a1 overshooting by
## `over`, and a settle back to a1.
static func _arc(k: float, from: float, a0: float, a1: float, over: float) -> float:
	if k < 0.1:
		return lerp_angle(from, a0, k / 0.1)
	if k < 0.55:
		return lerpf(a0, a1 + over, _ease_out((k - 0.1) / 0.45))
	return lerpf(a1 + over, a1, smoothstep(0.55, 0.85, k))


## Energy Sword swing pose at progress k: anticipation -> strike -> follow-through -> recovery, the blade
## turning in the fist and the torso twisting with it (thrusts lunge the body instead).
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
			_ext[0] = 1.0 + THRUST_SURGE * maxf(push, 0.0) / 0.55
			_lunge = dir * push / 0.55 * LUNGE
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
		_draw_blade(_grip[b], _angle[b], _length * _ext[b], _wide[b])


## `length` = how far the weapon reaches beyond the fist. The art is scaled so that part matches, and
## drawn so the fist (`grip`) sits on the handle (_grip_at up it, _grip_x across it), with the pommel /
## shaft end behind the hand. The rig draws BELOW the mech, so the mech's fist covers the handle it holds.
## Cel weapons (Energy Sword) draw only the hilt from the art; the blade is drawn in code with a real point.
func _draw_blade(grip: Vector2, angle: float, length: float, wide := 1.0) -> void:
	var size := _tex.get_size()
	var s := length / (size.y * (1.0 - _grip_at))
	var at := Vector2(-(_grip_x if _grip_x >= 0.0 else size.x / 2), -size.y * (1.0 - _grip_at))
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
	if _beam:
		# Beam weapons: only the hilt comes from the art (its painted blade is skipped); BeamLayer draws the beam.
		var bh := Rect2(Vector2(-size.x / 2, size.y * (_grip_at - BEAM_HILT)), Vector2(size.x, size.y * BEAM_HILT))
		var bsrc := Rect2(0, size.y * (1.0 - BEAM_HILT), size.x, size.y * BEAM_HILT)
		draw_set_transform(grip + Vector2(6, 9), angle + PI / 2, Vector2(s, s))
		draw_texture_rect_region(_tex, bh, bsrc, Color(0, 0, 0, 0.3))
		draw_set_transform(grip, angle + PI / 2, Vector2(s, s))
		draw_texture_rect_region(_tex, bh, bsrc)
		draw_set_transform(Vector2.ZERO)
		return
	# Soft ground shadow, then the weapon (art points up, handle at the bottom; `wide` widens it).
	draw_set_transform(grip + Vector2(6, 9), angle + PI / 2, Vector2(s * wide, s))
	draw_texture(_tex, at, Color(0, 0, 0, 0.3))
	draw_set_transform(grip, angle + PI / 2, Vector2(s * wide, s))
	draw_texture(_tex, at)
	draw_set_transform(Vector2.ZERO)


## Energy Sword blade half-width for a weapon drawn `length` long (thinner when held at rest).
func _cel_half_width(length: float) -> float:
	return clampf(length * 0.042, 4.5, 8.0)


## Beam weapons: the emitter (where the beam leaves the hilt), the direction, and the beam's length for
## blade `b` (growing out of the emitter while it ignites).
func _beam_blade(b: int) -> Array:
	var size := _tex.get_size()
	var length: float = _length * _ext[b]
	var s := length / (size.y * (1.0 - _grip_at))
	var d := Vector2.from_angle(_angle[b])
	var off := (BEAM_HILT - _grip_at) * size.y * s
	var grow := 1.0 - pow(1.0 - _ignite, 3.0)
	return [_grip[b] + d * off, d, maxf(length - off, 0.0) * grow]


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
			# Energy blades glow all the time, hugging their own shape (beams glow in BeamLayer; hot heads
			# glow below).
			elif r._energy and not r._beam and not r._hot:
				_shape_glow(r, b, col)
			_ribbon(r, r._trail[b], col)
		if r._hot:
			_draw_heat(r, col)
		for s: Dictionary in r._streaks:
			_draw_streak(s, col)

	## Energy weapons' glow: only the energy part of the art (GLOW_FROM up to the tip) is drawn again in the
	## weapon colour, additively, nudged out in a ring of directions - a soft halo that follows the blade's
	## own outline (no straight bar over the shaft), breathing slowly.
	func _shape_glow(r: Node2D, b: int, col: Color) -> void:
		var tex: Texture2D = r._tex
		var size := tex.get_size()
		var from: float = float(GLOW_FROM.get(String(MeleeKit.WEAPONS[r._id]["tex"]), 0.3))
		var length: float = r._length * float(r._ext[b])
		var s: float = length / (size.y * (1.0 - r._grip_at))
		var gx: float = r._grip_x if r._grip_x >= 0.0 else size.x / 2.0
		var src := Rect2(0, 0, size.x, size.y * (1.0 - from))
		var dst := Rect2(-gx, -size.y * (1.0 - r._grip_at), size.x, size.y * (1.0 - from))
		var pulse := 0.85 + 0.15 * sin(r._time * 5.0)
		draw_set_transform(r._grip[b], r._angle[b] + PI / 2, Vector2(s * float(r._wide[b]), s))
		for ring in [[2.5, 0.08], [5.5, 0.045]]:
			for k in 8:
				var o := Vector2.from_angle(TAU * k / 8.0) * (float(ring[0]) / s)
				draw_texture_rect_region(tex, Rect2(dst.position + o, dst.size), src, Color(col, float(ring[1]) * pulse))
		draw_texture_rect_region(tex, dst, src, Color(col.lightened(0.35), 0.16 * pulse))
		draw_set_transform(Vector2.ZERO)

	## "hot" weapons: the head glows (white-hot core, coloured bloom, breathing) by its heat, and the embers.
	func _draw_heat(r: Node2D, col: Color) -> void:
		var h: float = r._heat
		var p: Vector2 = r.head_pos()
		var pulse := 0.85 + 0.15 * sin(r._time * 11.0)
		var rad := (22.0 + 26.0 * h) * pulse
		draw_texture_rect(GLOW, Rect2(p - Vector2(rad, rad) * 1.6, Vector2(rad, rad) * 3.2), false, Color(col, 0.18 + 0.4 * h))
		draw_texture_rect(GLOW, Rect2(p - Vector2(rad, rad) * 0.7, Vector2(rad, rad) * 1.4), false,
			Color(col.lerp(Color(1, 0.95, 0.75), h), 0.25 + 0.55 * h))
		for e: Array in r._embers:
			var k: float = e[2] / e[3]
			var sz: float = e[4] * (1.0 - k * 0.6)
			var q: Vector2 = e[0]
			var c := Color(1.0, 0.9, 0.55).lerp(col, minf(k * 1.6, 1.0))
			c.a = 0.95 * (1.0 - k)
			draw_colored_polygon(PackedVector2Array([q + Vector2(sz, 0), q + Vector2(0, sz), q - Vector2(sz, 0),
				q - Vector2(0, sz)]), c)

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

	## A thrust's piercing streak: a needle of light shooting out along the stab (coloured glow, white-hot
	## core, sharp point), speed lines racing past it, and a shock ring + star flash where the point stops.
	func _draw_streak(s: Dictionary, col: Color) -> void:
		var k: float = s["t"] / s["life"]
		var grow := clampf(k / 0.25, 0.0, 1.0)
		var fade := 1.0 - clampf((k - 0.3) / 0.7, 0.0, 1.0)
		var d: Vector2 = s["dir"]
		var n := d.orthogonal()
		var from: Vector2 = s["from"]
		var length: float = s["len"]
		var to: Vector2 = from + d * length * (0.35 + 0.65 * _ease(grow))
		var mid: Vector2 = from.lerp(to, 0.8)
		for layer in [[9.0, Color(col, 0.45 * fade)], [4.5, Color(col.lightened(0.4), 0.8 * fade)],
				[1.8, Color(1, 1, 1, fade)]]:
			var w: float = layer[0] * (0.6 + 0.4 * fade)
			draw_colored_polygon(PackedVector2Array([from - n * w * 0.35, mid - n * w, to, mid + n * w,
				from + n * w * 0.35]), layer[1])
		# Speed lines racing along beside it.
		var rng := RandomNumberGenerator.new()
		rng.seed = int(s["seed"])
		for i in 4:
			var off := rng.randf_range(10.0, 22.0) * (1.0 if i % 2 == 0 else -1.0)
			var a := rng.randf_range(0.1, 0.45) + 0.35 * k
			var b := a + rng.randf_range(0.25, 0.4)
			draw_line(from + d * length * a + n * off, from + d * length * minf(b, 1.0) + n * off,
				Color(col.lightened(0.5), 0.55 * fade), 1.4, true)
		# Where the point stops: a flattened shock ring round the spear line, and a star flash.
		if k < 0.6:
			var u := k / 0.6
			draw_set_transform(to, d.angle(), Vector2(0.4, 1.0))
			draw_arc(Vector2.ZERO, 8.0 + 22.0 * u, 0.0, TAU, 28, Color(col.lightened(0.3), 0.8 * (1.0 - u)), 2.5, true)
			draw_set_transform(Vector2.ZERO)
			var st := 14.0 * (1.0 - u)
			# (skipped once it has shrunk to a dot: a collapsed polygon can't be triangulated)
			if st > 0.6:
				draw_colored_polygon(PackedVector2Array([to + d * st * 1.6, to + n * st * 0.22, to - d * st * 0.5,
					to - n * st * 0.22]), Color(1, 1, 1, 0.9 * (1.0 - u)))
				draw_colored_polygon(PackedVector2Array([to + n * st, to + d * st * 0.22, to - n * st,
					to - d * st * 0.22]), Color(1, 1, 1, 0.9 * (1.0 - u)))

	static func _ease(x: float) -> float:
		return 1.0 - pow(1.0 - x, 3.0)


## Beam weapons' blades (additive, above the mech): one quad per blade around the beam, shaded by
## player/weapons/beam_blade.gdshader. UV = world px (x from the emitter along the beam, y across it over the
## width scale); COLOR = beam colour, alpha = beam length / 512.
class BeamLayer extends Node2D:
	var rig: Node2D

	func _ready() -> void:
		top_level = true
		z_index = 2
		var m := ShaderMaterial.new()
		m.shader = BEAM_SHADER
		material = m

	func _draw() -> void:
		var r = rig
		if r._tex == null or not r._beam:
			return
		var col: Color = r._color
		var ws: float = r._beam_w
		for b in (2 if r._twin() else 1):
			var bb: Array = r._beam_blade(b)
			var base: Vector2 = bb[0]
			var d: Vector2 = bb[1]
			var len: float = minf(bb[2], 500.0)
			if len < 2.0:
				continue
			var m := BEAM_MARGIN
			var n := d.orthogonal() * m * ws
			var back := base - d * m
			var front := base + d * (len + m)
			var c := Color(col.r, col.g, col.b, len / 512.0)
			draw_polygon(PackedVector2Array([back - n, front - n, front + n, back + n]),
				PackedColorArray([c, c, c, c]),
				PackedVector2Array([Vector2(-m, -m), Vector2(len + m, -m), Vector2(len + m, m), Vector2(-m, m)]))


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


## Where a heavy axe blow lands: dark fissures radiating out of a scorch, glowing hot in the weapon colour
## (the glow cools in about a second, the cracks fade after ~2.5 s). On the floor, under robots and mech.
class GroundCrack extends Node2D:
	const LIFE := 2.6
	var color := Color(1.0, 0.55, 0.15)
	var radius := 120.0
	var lines := 7
	var cracks: Array = []
	var t := 0.0
	var _glow: Node2D

	func _ready() -> void:
		z_index = -6
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in lines:
			var ang := TAU * i / lines + rng.randf_range(-0.3, 0.3)
			var reach := radius * rng.randf_range(0.5, 1.0)
			var pts := PackedVector2Array([Vector2.from_angle(ang) * radius * 0.12])
			var r := radius * 0.12
			while r < reach:
				r = minf(r + rng.randf_range(radius * 0.08, radius * 0.16), reach)
				ang += rng.randf_range(-0.32, 0.32)
				pts.append(Vector2.from_angle(ang) * r)
			cracks.append(pts)
			# Some fissures fork.
			if pts.size() > 3 and rng.randf() < 0.55:
				var j := rng.randi_range(1, pts.size() - 2)
				var fork := PackedVector2Array([pts[j]])
				var fa := pts[j].angle() + rng.randf_range(0.4, 0.8) * (1.0 if rng.randf() < 0.5 else -1.0)
				var fr := pts[j].length()
				for m in rng.randi_range(2, 3):
					fr += rng.randf_range(radius * 0.07, radius * 0.13)
					fa += rng.randf_range(-0.3, 0.3)
					fork.append(Vector2.from_angle(fa) * fr)
				cracks.append(fork)
		_glow = CrackGlow.new()
		_glow.crack = self
		add_child(_glow)

	func _process(delta: float) -> void:
		t += delta
		if t >= LIFE:
			queue_free()
			return
		queue_redraw()
		_glow.queue_redraw()

	func _draw() -> void:
		var fade := 1.0 - smoothstep(LIFE * 0.55, LIFE, t)
		draw_circle(Vector2.ZERO, radius * 0.3, Color(0.06, 0.03, 0.02, 0.42 * fade))
		draw_circle(Vector2.ZERO, radius * 0.18, Color(0.04, 0.02, 0.01, 0.5 * fade))
		for pts: PackedVector2Array in cracks:
			_taper(self, pts, 5.0, 1.2, Color(0.05, 0.03, 0.02, 0.8 * fade))

	## A fissure: segment by segment, from `w0` wide at its start to `w1` at its end.
	static func _taper(ci: CanvasItem, pts: PackedVector2Array, w0: float, w1: float, c: Color) -> void:
		var n := pts.size() - 1
		for i in n:
			ci.draw_line(pts[i], pts[i + 1], c, lerpf(w0, w1, float(i) / maxf(n - 1, 1)), true)


## GroundCrack's hot glow (additive): the fissures glow white-yellow then the weapon colour, cooling off.
class CrackGlow extends Node2D:
	var crack: Node2D

	func _ready() -> void:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _draw() -> void:
		var hot := 1.0 - smoothstep(0.0, 1.2, crack.t)
		if hot <= 0.0:
			return
		var col: Color = crack.color
		draw_texture_rect(GLOW, Rect2(Vector2(-1, -1) * crack.radius * 0.5, Vector2.ONE * crack.radius), false,
			Color(col, 0.5 * hot))
		for pts: PackedVector2Array in crack.cracks:
			GroundCrack._taper(self, pts, 4.0, 1.0, Color(col, 0.75 * hot))
			GroundCrack._taper(self, pts, 1.6, 0.5, Color(1.0, 0.92, 0.65, hot))
