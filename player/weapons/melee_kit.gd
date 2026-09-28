class_name MeleeKit
extends Node2D
## Melee primary weapons: Beam Saber, Dual Beam Sabers, Beam Katana, Beam Spear, Energy Axe, Beam Scythe
## and the Physical Greatsword. A child of the Mech; Mech._fire_primary() calls swing() at rate().
##
## Every weapon has a COMBO: swings that follow each other closely alternate sides, and the last hit of
## the combo is a FINISHER (dash slash, whirl, iaido dash-through, charge thrust, ground slam, reap,
## overhead cleave). Upgrades still apply: `mult` (Power Core + overdrive), Target Lock (auto-face the
## nearest enemy), Triple Shot (energy waves), Explosive Rounds, and energy blades cut enemy bullets.

const RIG := preload("res://player/weapons/melee_rig.gd")

## id -> stats.  style: "arc" sweep, "thrust" stab, "spin" full circle.  `energy` blades parry bullets.
## (The Beam Saber keeps the original Beam Sword numbers: 2.6 swings/s, 44 dmg, 150 px, 1.15 rad.)
const WEAPONS := {
	&"sword": {"rate": 2.6, "damage": 44.0, "reach": 150.0, "half": 1.15, "knock": 300.0, "combo": 3,
		"style": "arc", "finisher": "dash", "color": Color(1.0, 0.35, 0.8), "tex": "beam_saber", "energy": true},
	&"dual_sabers": {"rate": 5.5, "damage": 22.0, "reach": 130.0, "half": 1.0, "knock": 140.0, "combo": 5,
		"style": "arc", "finisher": "whirl", "color": Color(0.3, 1.0, 1.0), "tex": "beam_saber", "hue": 0.6,
		"energy": true},
	&"katana": {"rate": 2.1, "damage": 54.0, "reach": 215.0, "half": 1.45, "knock": 260.0, "combo": 3,
		"style": "arc", "finisher": "iaido", "color": Color(1.0, 0.22, 0.2), "tex": "katana", "energy": true},
	&"spear": {"rate": 2.4, "damage": 50.0, "reach": 270.0, "half": 0.3, "knock": 380.0, "combo": 3,
		"style": "thrust", "finisher": "charge", "color": Color(0.35, 0.65, 1.0), "tex": "spear", "energy": true},
	&"axe": {"rate": 1.1, "damage": 115.0, "reach": 165.0, "half": 1.05, "knock": 750.0, "combo": 3,
		"style": "arc", "finisher": "slam", "color": Color(1.0, 0.55, 0.15), "tex": "axe", "energy": true},
	&"scythe": {"rate": 1.5, "damage": 42.0, "reach": 195.0, "half": PI, "knock": 240.0, "combo": 3,
		"style": "spin", "finisher": "reap", "color": Color(0.55, 1.0, 0.2), "tex": "scythe", "energy": true},
	&"greatsword": {"rate": 0.95, "damage": 95.0, "reach": 205.0, "half": 1.3, "knock": 600.0, "combo": 3,
		"style": "arc", "finisher": "cleave", "color": Color(0.9, 0.93, 1.0), "tex": "greatsword", "energy": false},
}

var mech: Mech
var combo := 0
var _last_swing := -10.0
var _last_id := &""
var _side := 1.0
var _tex := {}
## The held weapon + swing / trail / impact visuals (player/weapons/melee_rig.gd).
var rig: Node2D


static func has_weapon(id: StringName) -> bool:
	return WEAPONS.has(id)


static func rate(id: StringName) -> float:
	return WEAPONS[id]["rate"]


func _ready() -> void:
	mech = get_parent() as Mech
	rig = RIG.new()
	rig.mech = mech
	add_child(rig)


func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/hq/weapons/%s.png" % name)
	return _tex[name]


## One attack. Returns true if it was the combo finisher.
func swing(id: StringName, mult: float) -> bool:
	var w: Dictionary = WEAPONS[id]
	var now := Time.get_ticks_msec() / 1000.0
	var chain_window: float = 1.0 / (w["rate"] * Upgrades.fire_rate_mult()) + 0.4
	combo = combo + 1 if id == _last_id and now - _last_swing <= chain_window else 0
	if combo >= w["combo"]:
		combo = 0
	_last_swing = now
	_last_id = id
	var finisher: bool = combo == w["combo"] - 1
	var reach: float = w["reach"]
	var locked := mech._assist_target(reach * 2.2)
	var dir := (locked.global_position - mech.global_position).normalized() if locked else mech.aim_dir
	_side = -_side
	var dmg: float = w["damage"] * mult
	var col: Color = w["color"]
	if mech.overdrive_left > 0.0:
		col = col.lerp(Color(1.0, 0.8, 0.3), 0.4)
	if finisher:
		_finisher(w, dir, dmg, col)
	else:
		_basic(w, dir, dmg, col)
	_energy_waves(w, dir, dmg, col)
	return finisher


# --- attacks ----------------------------------------------------------------------------------------

func _basic(w: Dictionary, dir: Vector2, dmg: float, col: Color) -> void:
	var reach: float = w["reach"]
	var p := mech.global_position
	match w["style"]:
		"thrust":
			_hit_line(p, p + dir * reach, 44.0, dmg, w["knock"], col, w)
			_blade(w, "thrust", dir, reach * 0.85, 0.2)
			mech.recoil(dir * 90.0)
		"spin":
			_hit_arc(p, dir, reach, PI, dmg, w["knock"], col, w)
			_blade(w, "spin", dir, reach * 0.95, 0.3)
		_:
			_hit_arc(p, dir, reach, w["half"], dmg, w["knock"], col, w)
			_blade(w, "arc", dir, reach * 0.95, 0.2 if w["rate"] > 2.0 else 0.3)
			mech.recoil(dir * (60.0 if w["rate"] > 4.0 else 100.0))
	_swing_sound(w, false)


func _finisher(w: Dictionary, dir: Vector2, dmg: float, col: Color) -> void:
	var reach: float = w["reach"]
	var p := mech.global_position
	match w["finisher"]:
		"dash":  # Beam Saber: dash slash through everything in the way.
			var dash := 170.0
			_dash(dir, dash)
			_hit_line(p, p + dir * (dash + reach * 0.7), 70.0, dmg * 1.6, w["knock"], col, w)
			_blade(w, "arc", dir, reach, 0.26)
		"whirl":  # Dual Sabers: both blades whirl around the mech.
			_hit_arc(p, dir, reach + 40.0, PI, dmg * 2.0, w["knock"] * 2.0, col, w)
			_blade(w, "spin", dir, reach, 0.3, 1.0, true)
		"iaido":  # Katana: a blinding dash-through cut.
			var dash := 240.0
			_dash(dir, dash)
			_hit_line(p, p + dir * (dash + 60.0), 64.0, dmg * 2.2, w["knock"], col, w)
			_blade(w, "arc", dir, reach, 0.3)
			var line: Node2D = LineFlash.new()
			line.from = p
			line.to = p + dir * (dash + 60.0)
			line.color = col
			Combat.world().add_child(line)
		"charge":  # Spear: charge forward and skewer a long line.
			var dash := 200.0
			_dash(dir, dash)
			_hit_line(p, p + dir * (dash + reach * 1.1), 50.0, dmg * 2.0, w["knock"] * 1.5, col, w)
			_blade(w, "thrust", dir, reach, 0.3)
		"slam":  # Axe: ground slam shockwave.
			var at := p + dir * 70.0
			_hit_arc(at, Vector2.ZERO, 200.0, PI, dmg * 1.5, w["knock"] * 1.3, col, w)
			_blade(w, "arc", dir, reach, 0.32)
			Combat.shockwave(at, 200.0, col, 0.4)
			Combat.burst(at, col, 500.0, 1.6)
			Combat.shake(0.5)
			Sfx.play(&"slam", -2.0)
		"reap":  # Scythe: double spin that drags enemies in.
			_hit_arc(p, dir, reach + 55.0, PI, dmg * 1.6, -w["knock"] * 1.5, col, w)
			_blade(w, "spin", dir, reach, 0.4, 2.0)
			Combat.shockwave(p, reach + 55.0, col, 0.35)
		"cleave":  # Greatsword: huge overhead cleave + impact shockwave.
			var at := p + dir * reach * 0.9
			_hit_arc(p, dir, reach * 1.3, 0.9, dmg * 2.2, w["knock"] * 1.3, col, w)
			_hit_arc(at, Vector2.ZERO, 180.0, PI, dmg * 0.8, w["knock"], col, w)
			_blade(w, "arc", dir, reach * 1.1, 0.34)
			Combat.shockwave(at, 180.0, Color(1.0, 0.7, 0.4), 0.4)
			Combat.burst(at, Color(1.0, 0.6, 0.3), 460.0, 1.5)
			Combat.shake(0.6)
			Sfx.play(&"slam", -1.0)
	_swing_sound(w, true)


## Triple Shot: extra piercing energy waves along the swing (energy blades and the greatsword alike).
func _energy_waves(w: Dictionary, dir: Vector2, dmg: float, col: Color) -> void:
	var waves := Upgrades.multishot_count()
	if waves <= 1:
		return
	for i in waves:
		var off := (i - (waves - 1) / 2.0) * 0.22
		var b := Combat.fire(mech.global_position + dir * 40.0, dir.rotated(off) * 820.0, dmg * 0.5, true, mech,
			col, 2.0, 0.5)
		mech._arm(b)
		b.pierce += 2


# --- hit helpers ------------------------------------------------------------------------------------

## Hits enemies in a circle / cone. Negative knock pulls toward `center`.
func _hit_arc(center: Vector2, dir: Vector2, reach: float, half: float, dmg: float, knock: float, col: Color,
		w: Dictionary) -> int:
	var cone := dir if half < PI else Vector2.ZERO
	var hits := 0
	for n in Combat.enemies_in_area(center, reach, cone, half):
		_hit(n, center, dmg, knock, col)
		hits += 1
	Combat.damage_destructibles(center, reach, dmg, cone, half)
	if w["energy"] and Combat.deflect_bullets(center, reach + 10.0, cone, half + 0.2) > 0:
		Sfx.play(&"shield", -12.0, 0.1)
	return hits


## Hits everything within `width` of the segment (dash cuts, thrusts).
func _hit_line(from: Vector2, to: Vector2, width: float, dmg: float, knock: float, col: Color, w: Dictionary) -> int:
	var mid := (from + to) / 2.0
	var half_len := from.distance_to(to) / 2.0
	var hits := 0
	for n in Combat.enemies_in_area(mid, half_len + width):
		var r: float = n.get("hit_radius") if n.get("hit_radius") != null else 20.0
		var pn: Vector2 = n.global_position
		if Geometry2D.get_closest_point_to_segment(pn, from, to).distance_to(pn) <= width + r:
			_hit(n, from, dmg, knock, col)
			hits += 1
	for n in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(n):
			var pn: Vector2 = n.global_position
			if Geometry2D.get_closest_point_to_segment(pn, from, to).distance_to(pn) <= width + 20.0:
				n.take_hit(dmg, from)
	if w["energy"]:
		Combat.deflect_bullets(mid, half_len + width)
	return hits


func _hit(n: Node, from: Vector2, dmg: float, knock: float, col: Color) -> void:
	n.take_damage(dmg, from, mech)
	if knock != 0.0 and n.has_method("knock") and is_instance_valid(n):
		n.knock((n.global_position - mech.global_position).normalized() * knock)
	Combat.spark(n.global_position, col, 1.2)
	if is_instance_valid(n):
		rig.impact(n.global_position, col, dmg >= 90.0)
	mech._maybe_explode(n.global_position, dmg)


## Short dash (reuses the mech's boost motion: afterimages + brief invulnerability).
func _dash(dir: Vector2, distance: float) -> void:
	mech._boost_dir = dir
	mech._boost_left = distance / mech.boost_speed
	mech._invuln = maxf(mech._invuln, mech._boost_left + 0.08)
	Sfx.play(&"dash", -8.0)


# --- visuals ------------------------------------------------------------------------------------------

## Plays the swing on the held weapon (see melee_rig.gd): pose, blade-tip trail, thrust streak.
func _blade(w: Dictionary, mode: String, dir: Vector2, length: float, life: float, turns := 1.0, twin := false) -> void:
	rig.swing(w, mode, dir, length, life, _side, turns, twin)


func _swing_sound(w: Dictionary, finisher: bool) -> void:
	if w["energy"]:
		Sfx.play(&"saber", -4.0 if finisher else -7.0, 0.12)
	else:
		Sfx.play(&"slam", -9.0, 0.15)
		Sfx.play(&"dash", -12.0, 0.1)
	Combat.shake(0.2 if finisher else 0.05 + 0.1 / w["rate"])


## Iaido finisher: the cut line lingers across the dash path, then snaps away.
class LineFlash extends Node2D:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var color := Color.WHITE
	var _t := 0.0

	func _ready() -> void:
		z_index = 5
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add

	func _process(delta: float) -> void:
		_t += delta
		if _t > 0.45:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / 0.45
		var w := (1.0 - k) * 14.0
		draw_line(from, to, Color(color, 0.4 * (1.0 - k)), w * 2.5)
		draw_line(from, to, Color(1, 1, 1, 1.0 - k), maxf(w * 0.4, 1.0))
