class_name HeldWeapon
extends Node2D
## What the Gundam holds in its right fist, kept ON that fist in every animation frame:
##   Sniper Beam, Gatling Cannon, Rocket Launcher  drawn here from their Higgsfield art (points up =
##       forward) while the sprite shows its rifle-free frames. The gun's pistol grip sits in the fist
##       (fist(): the fist of the sprite's current frame plus the sprite's recoil offset, so the gun moves
##       with the hand through the idle / boost / bank / dash / fire frames and the firing kick), and it is
##       drawn just BELOW the mech sprite so the fist closes over the handle. Muzzle / MuzzleFlash sit at
##       the barrel tip, so shots, aim convergence, flashes and the Beam Cannon come out of the big gun.
##       Each gun fires its own way: the Gatling's barrels spin up and spit brass casings out the side; the
##       Rocket Launcher kicks back hard and twists, and blasts smoke out of the back of the tube; the
##       Sniper jolts back and climbs, then ejects its casing as the bolt cycles.
##   Beam Rifle  painted into the sprite; Muzzle / MuzzleFlash follow its painted barrel tip (RIFLE_TIP).
##   Melee       held by player/weapons/melee_rig.gd, which pins the hilt to fist() as well; the Muzzle
##       (Beam Cannon, scatter shot) sits just in front of the fist.
## A child of the mech's Body, which turns to the aim.

## Middle of the right fist, and the painted Beam Rifle's barrel tip, per animation frame, in sprite-frame
## pixels (256 x 256 cells, the mech facing up). Measured from the painted rifle by tools/measure_fists.gd
## (run it again if assets/sprites/gundam_sheet.png changes). The left fist is the mirror image.
const FIST := {
	&"idle": [Vector2(179.8, 106.9), Vector2(179.8, 106.9), Vector2(179.8, 106.9), Vector2(179.8, 106.9), Vector2(179.8, 106.9), Vector2(180.0, 106.9), Vector2(179.9, 106.9), Vector2(180.0, 106.9)],
	&"boost": [Vector2(181.7, 90.6), Vector2(181.6, 90.6), Vector2(181.6, 90.6), Vector2(181.7, 90.6), Vector2(181.7, 90.7), Vector2(181.7, 90.7)],
	&"bank_left": [Vector2(178.6, 112.8), Vector2(178.7, 112.8), Vector2(178.7, 112.8), Vector2(178.6, 112.8), Vector2(178.6, 112.8), Vector2(178.6, 112.8)],
	&"bank_right": [Vector2(175.6, 104.0), Vector2(175.6, 104.0), Vector2(175.6, 104.0), Vector2(175.6, 104.0), Vector2(175.5, 103.9), Vector2(175.5, 103.9)],
	&"dash": [Vector2(179.8, 106.9), Vector2(178.0, 109.8), Vector2(181.7, 90.6), Vector2(178.7, 98.7), Vector2(179.9, 106.9), Vector2(179.8, 106.9)],
	&"fire": [Vector2(180.7, 106.0), Vector2(180.6, 107.0), Vector2(180.6, 106.0), Vector2(180.7, 106.0)],
	&"aim": [Vector2(179.8, 106.9), Vector2(180.4, 107.0), Vector2(180.8, 106.0), Vector2(180.7, 106.0), Vector2(180.7, 106.0), Vector2(180.7, 106.0)],
}
const RIFLE_TIP := {
	&"idle": [Vector2(197.4, 15.0), Vector2(197.5, 16.0), Vector2(197.5, 16.0), Vector2(197.5, 16.0), Vector2(197.4, 15.0), Vector2(197.0, 15.0), Vector2(197.2, 14.0), Vector2(197.0, 15.0)],
	&"boost": [Vector2(201.8, 36.0), Vector2(201.8, 37.0), Vector2(201.8, 37.0), Vector2(201.8, 36.0), Vector2(201.6, 35.0), Vector2(201.2, 36.0)],
	&"bank_left": [Vector2(206.0, 17.0), Vector2(206.0, 18.0), Vector2(206.0, 18.0), Vector2(206.0, 17.0), Vector2(205.5, 17.0), Vector2(205.5, 17.0)],
	&"bank_right": [Vector2(186.8, 17.0), Vector2(186.7, 18.0), Vector2(186.7, 18.0), Vector2(186.8, 17.0), Vector2(187.1, 16.0), Vector2(187.1, 16.0)],
	&"dash": [Vector2(197.4, 15.0), Vector2(198.7, 19.0), Vector2(201.8, 36.0), Vector2(201.3, 29.0), Vector2(197.2, 13.0), Vector2(197.4, 15.0)],
	&"fire": [Vector2(191.8, 0.0), Vector2(191.9, 0.0), Vector2(191.8, 0.0), Vector2(191.8, 0.0)],
	&"aim": [Vector2(197.4, 15.0), Vector2(193.7, 0.0), Vector2(191.4, 0.0), Vector2(191.6, 0.0), Vector2(191.8, 0.0), Vector2(191.8, 0.0)],
}
## The sprite is centred on its 256 x 256 cell.
const CELL_CENTER := Vector2(128, 128)

## id -> art, on-screen length, `hand` = the art pixel the fist closes on (the middle of the pistol grip;
## the Rocket Launcher's tube runs straight through the fist, its rear grip under it), `muzzle` = the art
## pixel at the barrel tip (measured from assets/hq/weapons/*.png, 256 px tall). The firing motion: `slide`
## = how far it slides back in the fist at full kick, `climb` = how far it twists outward (radians),
## `settle` = how fast it recovers (kick / s); `eject` / `eject_dir` = where spent casings leave (art px)
## and which way (Body space); `rear` = the tube's back end (the Rocket Launcher's backblast).
const GUNS := {
	&"gatling": {"tex": "gatling", "length": 108.0, "hand": Vector2(32, 228), "muzzle": Vector2(23, 2),
		"slide": 1.5, "climb": 0.0, "settle": 9.0, "eject": Vector2(44, 196), "eject_dir": Vector2(1.0, 0.45)},
	&"rockets": {"tex": "rocket_launcher", "length": 115.0, "hand": Vector2(37, 165), "muzzle": Vector2(37, 4),
		"slide": 4.0, "climb": 0.1, "settle": 5.0, "rear": Vector2(37, 254)},
	&"sniper": {"tex": "sniper", "length": 124.0, "hand": Vector2(12, 178), "muzzle": Vector2(13.5, 1),
		"slide": 4.0, "climb": 0.14, "settle": 4.5, "eject": Vector2(24, 160), "eject_dir": Vector2(1.0, 0.25)},
}
## Gatling barrel spin: full speed (rad/s), spin-up and spin-down rates.
const SPIN_MAX := 40.0
const SPIN_UP := 70.0
const SPIN_DOWN := 22.0
## Sniper: the casing comes out this long after the shot (the bolt cycling).
const BOLT_DELAY := 0.14
## Melee weapons: the Muzzle (Beam Cannon, scatter shot) sits this far in front of the fist.
const HAND_MUZZLE := 10.0
## The muzzle flash glow sits a little past the muzzle.
const FLASH_AHEAD := 5.0

var mech: Mech
var _id := &""
var _tex: Texture2D
var _kick := 0.0
var _rumble := 0.0
## Gatling barrels: spin angle and speed (they keep turning for a moment after you let go).
var _spin := 0.0
var _spin_v := 0.0
## Sniper: seconds until the casing ejects (-1 = none due).
var _bolt_t := -1.0
## Casings, backblast smoke and flashes (world space, under the mech).
var _fx: GunFx


func setup(m: Mech) -> void:
	mech = m
	# First child of the Body: drawn under the thrusters and the mech sprite, so the fist covers the grip.
	m.body.move_child(self, 0)
	_fx = GunFx.new()
	add_child(_fx)


## Middle of a fist on the mech sprite's current frame, in Body space (side 1 = the right fist, -1 = the
## left one), including the sprite's recoil offset.
static func fist(m: Mech, side := 1.0) -> Vector2:
	return frame_point(m, FIST, side)


## A point from a per-frame table (FIST / RIFLE_TIP) on the sprite's current frame, in Body space.
static func frame_point(m: Mech, table: Dictionary, side := 1.0) -> Vector2:
	var s := m.sprite
	var pts: Array = table.get(s.animation, table[&"idle"])
	var p: Vector2 = pts[clampi(s.frame, 0, pts.size() - 1)] - CELL_CENTER
	p.x *= side
	return s.position + p * s.scale


## Called every frame by the mech with its current weapon.
func sync(id: StringName, delta: float, firing: bool) -> void:
	if id != _id:
		_id = id
		_tex = load("res://assets/hq/weapons/%s.png" % GUNS[id]["tex"]) if GUNS.has(id) else null
		_bolt_t = -1.0
		_spin_v = 0.0
	visible = _tex != null
	_kick = move_toward(_kick, 0.0, delta * (float(GUNS[_id]["settle"]) if _tex else 9.0))
	var gatling_firing := firing and id == &"gatling"
	_rumble = _rumble + delta * 60.0 if gatling_firing else 0.0
	_spin_v = move_toward(_spin_v, SPIN_MAX if gatling_firing else 0.0, delta * (SPIN_UP if gatling_firing else SPIN_DOWN))
	_spin = wrapf(_spin + _spin_v * delta, 0.0, TAU)
	if _bolt_t >= 0.0:
		_bolt_t -= delta
		if _bolt_t < 0.0 and _tex != null:
			_eject_casing()
	# Shots, flashes and the Beam Cannon leave from the barrel that is in the hand this frame.
	var tip := _barrel_tip()
	mech.muzzle.position = tip
	mech.muzzle_flash.position = tip + Vector2(0, -FLASH_AHEAD)


## Recoil (1 = full rocket kick): the gun jolts back in the fist and twists, and each gun does its own thing.
func kick(amount := 1.0) -> void:
	_kick = maxf(_kick, amount)
	if _tex == null:
		return
	match _id:
		&"gatling":
			_eject_casing()
		&"rockets":
			_backblast()
		&"sniper":
			_bolt_t = BOLT_DELAY


## Redrawn every frame so the gun follows the sprite's frame changes as well as the recoil.
func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


## Body space: the big gun's barrel tip, the painted rifle's tip, or (melee) just in front of the fist.
func _barrel_tip() -> Vector2:
	if _tex != null:
		return _art_point(GUNS[_id]["muzzle"])
	if _id == &"blaster":
		return frame_point(mech, RIFLE_TIP)
	return fist(mech) + Vector2(0, -HAND_MUZZLE)


## Where the gun's grip is right now (Body space): in the fist, slid back a little by the recoil.
func _grip() -> Vector2:
	var shake := Vector2(sin(_rumble) * 0.8, cos(_rumble * 1.3) * 0.5) if _rumble > 0.0 else Vector2.ZERO
	return fist(mech) + Vector2(0, _kick * float(GUNS[_id]["slide"])) + shake


## The gun's twist right now: outward with the kick (the Gatling judders instead).
func _rot() -> float:
	var r: float = float(GUNS[_id]["climb"]) * _kick
	if _rumble > 0.0:
		r += sin(_rumble * 1.7) * 0.012
	return r


## A pixel of the gun art, in Body space, where it is drawn this frame.
func _art_point(art: Vector2) -> Vector2:
	return _grip() + ((art - GUNS[_id]["hand"]) * _scale()).rotated(_rot())


func _scale() -> float:
	return float(GUNS[_id]["length"]) / _tex.get_height()


## A spent casing flicks out of the gun's ejection port and tumbles away (world space).
func _eject_casing() -> void:
	var g: Dictionary = GUNS[_id]
	if not g.has("eject"):
		return
	var out: Vector2 = (g["eject_dir"] as Vector2).normalized().rotated(_rot() + randf_range(-0.3, 0.3))
	_fx.add([to_global(_art_point(g["eject"])), global_transform.basis_xform(out).normalized() * randf_range(110.0, 170.0),
		0.0, randf_range(0.4, 0.55), GunFx.CASING, randf() * TAU, randf_range(-24.0, 24.0), 1.0])


## Rocket Launcher: a flash and a cloud of smoke blasted out of the back of the tube.
func _backblast() -> void:
	var rear := to_global(_art_point(GUNS[_id]["rear"]))
	var back := global_transform.basis_xform(Vector2(0, 1).rotated(_rot())).normalized()
	_fx.add([rear + back * 4.0, back * 30.0, 0.0, 0.09, GunFx.FLASH, 0.0, 0.0, 16.0])
	for i in 7:
		_fx.add([rear, back.rotated(randf_range(-0.55, 0.55)) * randf_range(60.0, 170.0), 0.0, randf_range(0.45, 0.8),
			GunFx.SMOKE, 0.0, 0.0, randf_range(5.0, 8.0)])


func _draw() -> void:
	if _tex == null:
		return
	var g: Dictionary = GUNS[_id]
	var s := _scale()
	var grip := _grip()
	var rot := _rot()
	var hand: Vector2 = g["hand"]
	# The art is drawn with its grip pixel on the fist: a soft ground shadow, then the gun.
	draw_set_transform(grip + Vector2(3, 5), rot, Vector2(s, s))
	draw_texture(_tex, -hand, Color(0, 0, 0, 0.3))
	draw_set_transform(grip, rot, Vector2(s, s))
	draw_texture(_tex, -hand)
	# Gatling: glints sliding across the barrel cluster as it spins (art x 8-37, the barrels' length).
	if _id == &"gatling" and _spin_v > 1.0:
		var k := clampf(_spin_v / SPIN_MAX, 0.0, 1.0)
		for i in 6:
			var a := _spin + i * TAU / 6.0
			var face := sin(a)
			if face <= 0.0:
				continue
			var x := 22.5 + cos(a) * 13.0
			draw_line(Vector2(x, 6) - hand, Vector2(x, 96) - hand, Color(1.0, 0.95, 0.85, 0.32 * k * face), 2.5)
	draw_set_transform(Vector2.ZERO)


## Spent casings, backblast smoke and flashes: drawn in world space just under the mech, then gone.
## Each part: [position, velocity, age, life, kind, angle, spin, size].
class GunFx extends Node2D:
	const CASING := 0
	const SMOKE := 1
	const FLASH := 2
	var _parts: Array = []

	func _ready() -> void:
		top_level = true
		# Relative to the mech: one below it (over the floor, under the mech and the gun's thrusters).
		z_index = -1

	func add(part: Array) -> void:
		_parts.append(part)

	func _process(delta: float) -> void:
		if _parts.is_empty():
			return
		global_position = Vector2.ZERO
		for p: Array in _parts:
			p[2] += delta
			p[0] += p[1] * delta
			match int(p[4]):
				CASING:
					p[1] = p[1].move_toward(Vector2.ZERO, 380.0 * delta)
					p[5] += p[6] * delta
					p[6] = move_toward(p[6], 0.0, 40.0 * delta)
				SMOKE:
					p[1] = p[1] * exp(-3.0 * delta)
		_parts = _parts.filter(func(p: Array) -> bool: return p[2] < p[3])
		queue_redraw()

	func _draw() -> void:
		for p: Array in _parts:
			var k: float = p[2] / p[3]
			match int(p[4]):
				CASING:
					# A little brass tube, glinting as it tumbles; fades as it settles.
					var d := Vector2.from_angle(p[5])
					var col := Color(1.0, 0.78, 0.35, 1.0 - k * k).lerp(Color(1.0, 0.95, 0.75, 1.0 - k * k), 0.5 + 0.5 * sin(p[5] * 3.0))
					draw_line(p[0] - d * 2.2, p[0] + d * 2.2, col, 2.0)
				SMOKE:
					var r: float = lerpf(p[7], p[7] * 3.6, 1.0 - pow(1.0 - k, 2.0))
					var a := 0.42 * (1.0 - k)
					draw_circle(p[0], r, Color(0.72, 0.72, 0.76, a * 0.55))
					draw_circle(p[0], r * 0.62, Color(0.82, 0.82, 0.86, a))
				FLASH:
					draw_circle(p[0], p[7] * (1.0 - k * 0.5), Color(1.0, 0.82, 0.45, 0.9 * (1.0 - k)))
					draw_circle(p[0], p[7] * 0.5, Color(1.0, 1.0, 0.85, 1.0 - k))
