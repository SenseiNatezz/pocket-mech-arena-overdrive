extends Node2D
## Melee weapon held in the mech's hand (created by MeleeKit, drawn in world space).
##   REST     while a melee weapon is equipped the blade is always in hand, angled out to the front-right
##            of the aim (Dual Sabers: one blade per hand) and follows the aim smoothly.
##   SWING    swing() plays an attack from wherever the blade is: a quick wind-up to the start of the
##            arc, a fast ease-out strike, a small overshoot and a settle, then it eases back to rest.
##            Styles: "arc" sweeps (twin = a crossing X), "thrust" stabs out and draws back, "spin" whirls.
##   TRAIL    the blade tip leaves a continuous ribbon (Higgsfield trail textures in assets/hq/fx,
##            tinted with the weapon colour, additive) built from the blade's real recent positions,
##            sub-sampled so fast arcs stay smooth. Thrusts draw a piercing streak instead.
##   IMPACT   impact() flashes an X-cut burst on whatever was hit and briefly freezes the swing
##            (a hit-pause for the blade only, so game timing and tests are unaffected).

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
const GRIP_AT := {"beam_saber": 0.15, "katana": 0.12, "spear": 0.28, "axe": 0.22, "scythe": 0.3, "greatsword": 0.14}

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


func _ready() -> void:
	top_level = true
	# Relative to the mech (z 2): one below it, so the mech's fist is drawn over the handle it holds.
	z_index = -1
	_fx = TrailLayer.new()
	_fx.rig = self
	add_child(_fx)


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
	_hold = HOLD
	if mode == "thrust":
		_streak = {"from": mech.global_position + dir * ARM, "dir": dir, "t": 0.0, "len": length * 1.25,
			"life": clampf(_dur * 1.4, 0.22, 0.4)}


## Hit feedback: an X-cut flash on the target and a short freeze of the swing.
func impact(pos: Vector2, color: Color, heavy: bool) -> void:
	_hitstop = maxf(_hitstop, 0.07 if heavy else 0.045)
	# A few flashes per swing read as impact; more just turns into a white blob.
	_flashes += 1
	if _flashes > MAX_FLASHES:
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
		return
	_time += delta
	var blades := 2 if _twin() else 1
	if not _sw.is_empty():
		_t += delta
		var k := clampf(_t / _dur, 0.0, 1.0)
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
	# Record the trail while the blade is moving through an attack (and let it fade after).
	for b in blades:
		var tr: Array = _trail[b]
		if not _sw.is_empty() and _sw["mode"] != "thrust":
			tr.append([_time, _grip[b], _angle[b], _ext[b]])
		while not tr.is_empty() and _time - tr[0][0] > TRAIL_LIFE:
			tr.pop_front()
	if not _streak.is_empty():
		_streak["t"] += delta
		if _streak["t"] >= _streak["life"]:
			_streak = {}
	queue_redraw()
	_fx.queue_redraw()


func _twin() -> bool:
	return MeleeKit.WEAPONS[_id].get("twin_rest", false) or _id == &"dual_sabers"


func _equip(id: StringName) -> void:
	_id = id
	var w: Dictionary = MeleeKit.WEAPONS[id]
	_tex = load("res://assets/hq/weapons/%s.png" % w["tex"])
	_grip_at = GRIP_AT.get(String(w["tex"]), 0.12)
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


static func _ease_out(x: float) -> float:
	var y := 1.0 - clampf(x, 0.0, 1.0)
	return 1.0 - y * y * y


static func _ease_in_out(x: float) -> float:
	return smoothstep(0.0, 1.0, x)


func _draw() -> void:
	if _tex == null:
		return
	for b in (2 if _twin() else 1):
		_draw_blade(_grip[b], _angle[b], _length * _ext[b])


## `length` = how far the weapon reaches beyond the fist. The art is scaled so that part matches, and
## drawn so the fist (`grip`) sits on the middle of the handle (_grip_at), with the pommel / shaft end
## behind the hand. The rig draws BELOW the mech, so the mech's fist covers the handle it holds.
func _draw_blade(grip: Vector2, angle: float, length: float) -> void:
	var size := _tex.get_size()
	var s := length / (size.y * (1.0 - _grip_at))
	var at := Vector2(-size.x / 2, -size.y * (1.0 - _grip_at))
	# Soft ground shadow, then the weapon (art points up, handle at the bottom).
	draw_set_transform(grip + Vector2(6, 9), angle + PI / 2, Vector2(s, s))
	draw_texture(_tex, at, Color(0, 0, 0, 0.3))
	draw_set_transform(grip, angle + PI / 2, Vector2(s, s))
	draw_texture(_tex, at)
	draw_set_transform(Vector2.ZERO)


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
			# Energy blades glow faintly all the time.
			if r._energy:
				var tip: Vector2 = r._grip[b] + Vector2.from_angle(r._angle[b]) * r._length * r._ext[b]
				var base: Vector2 = r._grip[b] + Vector2.from_angle(r._angle[b]) * r._length * r._ext[b] * 0.25
				draw_line(base, tip, Color(col, 0.22), 16.0, true)
				draw_line(base, tip, Color(col.lightened(0.5), 0.35), 5.0, true)
			_ribbon(r, r._trail[b], col)
		if not r._streak.is_empty():
			_draw_streak(r, col)

	func _ribbon(r: Node2D, tr: Array, col: Color) -> void:
		if tr.size() < 2:
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
