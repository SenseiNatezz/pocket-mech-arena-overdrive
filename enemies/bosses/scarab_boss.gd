class_name ScarabBoss
extends WardenBoss
## "SCARAB, the Dune Colossus" (Higgsfield sprite): boss of the Titan Graveyard (level 7). A colossal
## scarab-shaped war machine with drill mandibles and a turquoise sun-disk reactor on its shell.
##   Phase 1  MANDIBLE CHARGE (a danger lane, then it drills straight down it - a wall stops it with a
##            slam), SHARD VOLLEYS (fans of sand shards), BURROW (dives under the sand: it can't be hit
##            down there, tunnels after you, a big ring opens under you, then it erupts with rings of shards)
##   Phase 2  + SOLAR FLARE (the sun disk charges, five danger lanes fan out at you, then five sun lances
##            fire down them - cover blocks them), calls Dune Burrowers
##   Phase 3  + the eruption throws two shard rings and leaves a SAND VORTEX spiral; Sand Skiffs join
## Phases (66% / 33% HP), OVERDRIVE (20%), roar, death and the HUD hookup come from WardenBoss.

const SCARAB_TEX := preload("res://assets/hq/enemies6/scarab.png")
const SCARAB_SCALE := 0.7
const BURROWER := preload("res://enemies/dune_burrower.tscn")
const SKIFF := preload("res://enemies/sand_skiff.tscn")
const SAND := Color(0.95, 0.76, 0.46)
const SAND_DARK := Color(0.62, 0.42, 0.22)
const TURQ := Color(0.3, 1.0, 0.85)
const GOLD := Color(1.0, 0.85, 0.35)
const CHARGE_WARN := 0.85
const CHARGE_SPEED := 820.0
const CHARGE_LEN := 720.0
const ERUPT_R := 190.0
const ERUPT_WARN := 0.95
const FLARE_WARN := 1.0
const FLARE_FIRE := 0.35
const FLARE_REACH := 1300.0
const FLARE_HIT := 16.0
## Sun disk (reactor crest) in the sprite's own frame (art faces up).
const DISK := Vector2(0, -10)
## BURROW look: a lumpy sand mound in the Titan Graveyard's own orange sand, lit from the top-left, with the
## drill mandibles chomping out of its front, the reactor glowing through cracks, pebbles thrown aside, and
## a ploughed trench left behind that fades out (TRAIL_LIFE s).
const MOUND_BODY := Color(0.84, 0.54, 0.3)
const MOUND_LIGHT := Color(0.98, 0.76, 0.5)
const MOUND_DARK := Color(0.4, 0.22, 0.1)
const MANDIBLE := Color(0.24, 0.18, 0.13)
const TRAIL_LIFE := 2.4
const TRAIL_STEP := 16.0

var _charge_v := Vector2.ZERO
var _charge_hit := false
var _buried := false
var _sink := 0.0
var _mark := Vector2.ZERO
var _flare_dirs: Array[Vector2] = []
var _flare_ends: Array[Vector2] = []
var _puff_t := 0.0
## The trench: [global position, time it was dug (_t)].
var _trail: Array = []


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	if _buried:
		return
	super.take_damage(amount, from_pos, source)


func _set_buried(b: bool) -> void:
	_buried = b
	collision_layer = 0 if b else 256
	$Hurtbox.collision_layer = 0 if b else 4


func _disk() -> Vector2:
	return global_position + DISK.rotated(_turret.angle() + PI / 2)


func _think(delta: float) -> void:
	var speed_mult := 1.0 + (phase - 1) * 0.2
	if _state != &"charge" and _state != &"tunnel":
		_turret = _turret.slerp(dir_to_target(), 1.0 - exp(-4.0 * delta))
	facing = _turret
	if not _buried:
		_sink = move_toward(_sink, 0.0, delta * 3.0)
	else:
		if _trail.is_empty() or global_position.distance_to(_trail[-1][0]) > TRAIL_STEP:
			_trail.append([global_position, _t])
	while not _trail.is_empty() and _t - float(_trail[0][1]) > TRAIL_LIFE:
		_trail.pop_front()
	if _roar > 0.0:
		_roar -= delta
		return
	_state_t -= delta
	match _state:
		&"idle":
			var d := dist_to_target()
			if d > 360.0:
				steer_to(target.global_position, move_speed * speed_mult)
			elif d < 230.0:
				desired_velocity = -dir_to_target() * move_speed
			if _state_t <= 0.0:
				_pick_attack()
		&"charge_warn":
			desired_velocity = Vector2.ZERO
			if _state_t > 0.3:
				_charge_v = dir_to_target()
			_turret = _charge_v
			if _state_t <= 0.0:
				_state = &"charge"
				_state_t = CHARGE_LEN / CHARGE_SPEED
				_charge_hit = false
				Sfx.play(&"dash", -2.0)
		&"charge":
			desired_velocity = _charge_v * CHARGE_SPEED * speed_mult
			velocity = desired_velocity
			_puff_t -= delta
			if _puff_t <= 0.0:
				_puff_t = 0.05
				Combat.spark(global_position - _charge_v * 60.0, SAND, 1.6)
			if not _charge_hit and dist_to_target() < hit_radius + 30.0:
				_charge_hit = true
				target.take_damage(24.0 * damage_mult, global_position, self)
				Combat.shockwave(target.global_position, 120.0, SAND, 0.3)
			if get_slide_collision_count() > 0 and _state_t < CHARGE_LEN / CHARGE_SPEED - 0.1:
				Combat.shockwave(global_position, 240.0, SAND, 0.4)
				Combat.debris(global_position, 60.0, SAND_DARK)
				Combat.shake(0.5)
				Sfx.play(&"slam", -2.0)
				for i in 10:
					shoot(Vector2.from_angle(TAU * i / 10.0), 240.0, 9.0, SAND, 1.2)
				_state = &"idle"
				_state_t = 1.1
			elif _state_t <= 0.0:
				_end_attack()
		&"shards":
			_step_t -= delta
			if _step_t <= 0.0 and _step > 0:
				_step -= 1
				_step_t = 0.36 / speed_mult
				var n := 7 + phase
				var aim := dir_to_target().rotated(randf_range(-0.12, 0.12))
				for i in n:
					shoot(aim.rotated(lerpf(-0.5, 0.5, i / float(n - 1))), 330.0 + phase * 25.0, 8.0, SAND, 1.3)
				Sfx.play(&"enemy_shoot", -5.0)
			if _step <= 0 and _step_t <= 0.0:
				_end_attack()
		&"dive":
			desired_velocity = Vector2.ZERO
			_sink = 1.0 - clampf(_state_t / 0.6, 0.0, 1.0)
			if _state_t <= 0.0:
				_set_buried(true)
				_sink = 1.0
				_state = &"tunnel"
				_state_t = 1.7
				Combat.burst(global_position, SAND, 360.0, 2.0)
		&"tunnel":
			steer_to(target.global_position, 300.0 * speed_mult)
			if velocity.length() > 20.0:
				_turret = velocity.normalized()
			_puff_t -= delta
			if _puff_t <= 0.0:
				_puff_t = 0.07
				Combat.spark(global_position + _turret * 60.0 + Vector2(randf_range(-40, 40), randf_range(-40, 40)), MOUND_LIGHT, 1.2)
			if _state_t <= 0.0 or dist_to_target() < 80.0:
				_state = &"erupt_warn"
				_state_t = ERUPT_WARN
				_mark = target.global_position + target.velocity * 0.25
				Sfx.play(&"alarm", -8.0, 0.0)
		&"erupt_warn":
			desired_velocity = (_mark - global_position).limit_length(420.0)
			if _state_t <= 0.0:
				_erupt()
		&"flare_warn":
			desired_velocity = Vector2.ZERO
			if _state_t > 0.35:
				_aim_flare()
			_trace_flare()
			if _state_t <= 0.0:
				_fire_flare()
		&"flare":
			desired_velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_end_attack()
		&"vortex":
			desired_velocity = Vector2.ZERO
			_spin += delta * 2.4
			_step_t -= delta
			if _step_t <= 0.0:
				_step_t = 0.1
				for arm in 3:
					shoot(Vector2.from_angle(_spin + arm * TAU / 3.0), 250.0, 8.0, SAND, 1.1)
			if _state_t <= 0.0:
				_end_attack()
		&"summon":
			var kinds: Array[PackedScene] = [BURROWER, BURROWER]
			if phase >= 3:
				kinds.append(SKIFF)
			for s in kinds:
				var e: Enemy = s.instantiate()
				e.position = position + Vector2.from_angle(randf() * TAU) * 220.0
				e.damage_mult = damage_mult
				get_parent().add_child(e)
			Combat.shockwave(global_position, 260.0, SAND, 0.4)
			Sfx.play(&"alarm", -10.0, 0.0)
			_end_attack()


func _erupt() -> void:
	if has_line_of_sight(_mark):
		global_position = _mark
	_set_buried(false)
	Combat.area_damage(global_position, ERUPT_R, 25.0 * damage_mult, self, true, Vector2.ZERO, PI, 480.0)
	Combat.damage_destructibles(global_position, ERUPT_R, 60.0)
	Combat.shockwave(global_position, ERUPT_R * 1.5, SAND, 0.5)
	Combat.shockwave(global_position, ERUPT_R * 0.8, TURQ, 0.3)
	Combat.burst(global_position, SAND, 600.0, 2.4)
	Combat.debris(global_position, 84.0, SAND_DARK)
	Combat.shake(0.7)
	Combat.rumble(0.4, 0.8, 0.3)
	Sfx.play(&"slam", 0.0)
	var rings := 1 if phase < 3 else 2
	for r in rings:
		for i in 16:
			shoot(Vector2.from_angle(TAU * (i + 0.5 * r) / 16.0), 230.0 + r * 70.0, 10.0, SAND, 1.3)
	if phase >= 3:
		_state = &"vortex"
		_state_t = 2.2
		_step_t = 0.4
	else:
		_state = &"idle"
		_state_t = 1.3


func _aim_flare() -> void:
	var base := (target.global_position - _disk()).angle()
	_flare_dirs.clear()
	var n := 5
	for i in n:
		_flare_dirs.append(Vector2.from_angle(base + lerpf(-0.55, 0.55, i / float(n - 1))))


func _trace_flare() -> void:
	var space := get_world_2d().direct_space_state
	var from := _disk()
	_flare_ends.clear()
	for dir in _flare_dirs:
		var q := PhysicsRayQueryParameters2D.create(from + dir * 60.0, from + dir * FLARE_REACH, 1 | 32)
		var hit := space.intersect_ray(q)
		_flare_ends.append(hit.position if not hit.is_empty() else from + dir * FLARE_REACH)


func _fire_flare() -> void:
	_trace_flare()
	_state = &"flare"
	_state_t = FLARE_FIRE
	var from := _disk()
	var hr: float = target.get("hit_radius") if target.get("hit_radius") != null else 20.0
	for i in _flare_dirs.size():
		var p := Geometry2D.get_closest_point_to_segment(target.global_position, from, _flare_ends[i])
		if p.distance_to(target.global_position) < FLARE_HIT + hr:
			target.take_damage(18.0 * damage_mult, global_position, self)
			Combat.spark(target.global_position, GOLD, 1.6)
			break
	for e in _flare_ends:
		Combat.spark(e, GOLD, 1.8)
	Combat.shockwave(from, 200.0, GOLD, 0.3)
	Combat.shake(0.4)
	Sfx.play(&"laser", -3.0, 0.0)


func _pick_attack() -> void:
	var options: Array[StringName] = [&"charge_warn", &"shards", &"dive"]
	if phase >= 2:
		options.append_array([&"flare_warn", &"flare_warn"])
		if get_tree().get_nodes_in_group("enemies").size() < 5:
			options.append(&"summon")
	if phase >= 4:
		options.append(&"dive")
	options.erase(_last_attack)
	begin_attack(options.pick_random())


## Starts attack `attack` (one of the _pick_attack options; tests call it directly).
func begin_attack(attack: StringName) -> void:
	_state = attack
	_last_attack = _state
	_turret = dir_to_target()
	match _state:
		&"charge_warn":
			_state_t = CHARGE_WARN
			_charge_v = dir_to_target()
			Sfx.play(&"charge", -6.0, 0.0)
		&"shards":
			_step = 3 + phase
			_step_t = 0.3
		&"dive":
			_state_t = 0.6
			Sfx.play(&"charge", -6.0, 0.0)
		&"flare_warn":
			_state_t = FLARE_WARN
			_aim_flare()
			_trace_flare()
			Sfx.play(&"charge", -4.0, 0.0)


func _draw() -> void:
	var shake := Vector2(randf_range(-4, 4), randf_range(-4, 4)) if _roar > 0.0 or _dying > 0.0 else Vector2.ZERO
	if _state == &"charge_warn":
		DangerLane.draw(self, _charge_v * hit_radius * 0.7, _charge_v * CHARGE_LEN, hit_radius * 0.6,
			clampf(1.0 - _state_t / CHARGE_WARN, 0.0, 1.0), _t, Color(1.0, 0.4, 0.15))
	if _state == &"erupt_warn":
		var at := _mark - global_position
		var k := clampf(1.0 - _state_t / ERUPT_WARN, 0.0, 1.0)
		draw_circle(at, ERUPT_R, Color(SAND_DARK, 0.18 + 0.2 * k))
		draw_arc(at, ERUPT_R, 0, TAU, 56, Color(1.0, 0.4, 0.15, 0.9), 4.0, true)
		draw_arc(at, ERUPT_R * k, 0, TAU, 56, Color(SAND, 0.8), 3.0, true)
	if _state == &"flare_warn" and _flare_ends.size() == _flare_dirs.size():
		var k := clampf(1.0 - _state_t / FLARE_WARN, 0.0, 1.0)
		var from := _disk() - global_position
		for i in _flare_dirs.size():
			DangerLane.draw(self, from + _flare_dirs[i] * 80.0, _flare_ends[i] - global_position, FLARE_HIT + 10.0, k, _t, Color(1.0, 0.7, 0.2))
	if _state == &"flare" and _flare_ends.size() == _flare_dirs.size():
		var k := _state_t / FLARE_FIRE
		var from := _disk() - global_position
		for e in _flare_ends:
			draw_line(from, e - global_position, Color(GOLD, 0.45 * k), 40.0 * k + 6.0, true)
			draw_line(from, e - global_position, Color(1, 1, 0.92, k), 12.0 * k + 3.0, true)
	_draw_trench()
	if _buried:
		if _limbs:
			_limbs.clear()
		_draw_mound(1.0, true)
		return
	if _sink > 0.0:
		_draw_mound(_sink, false)  # (diving: the mound heaves up round it as it sinks)
	var rot := _turret.angle() + PI / 2
	var crawl := absf(sin(_t * 7.0)) * 0.015 if velocity.length() > 20.0 else 0.0
	var s := Vector2(SCARAB_SCALE + crawl, SCARAB_SCALE - crawl) * (1.0 - 0.3 * _sink)
	var half := SCARAB_TEX.get_size() / 2
	draw_set_transform(shake + Vector2(14, 22), rot, s)
	draw_texture(SCARAB_TEX, -half, Color(0, 0, 0, 0.45 * (1.0 - _sink)))
	draw_set_transform(shake, rot, s)
	draw_texture(SCARAB_TEX, -half, tint(Color(1, 1, 1, 1.0 - 0.5 * _sink)))
	note_body(SCARAB_TEX, shake, rot, s, tint(Color(1, 1, 1, (1.0 - 0.5 * _sink) * (1.0 - _sink))))
	draw_set_transform(shake)
	# Sun disk: pulses faster each phase; blazes while a flare charges.
	var pulse := 0.5 + 0.5 * sin(_t * (3.0 + phase * 2.0))
	var charge := clampf(1.0 - _state_t / FLARE_WARN, 0.0, 1.0) if _state == &"flare_warn" else 0.0
	var disk := DISK.rotated(rot)
	draw_circle(disk, 34.0 + 10.0 * pulse + 30.0 * charge, Color(TURQ, 0.14 + 0.1 * pulse + 0.25 * charge))
	draw_circle(disk, 12.0 + 4.0 * pulse + 10.0 * charge, Color(GOLD.lerp(Color.WHITE, charge), 0.5 + 0.4 * charge))
	draw_set_transform(Vector2.ZERO)


## The ploughed trench behind the mound: a dark furrow between two lit ridges, fading with age (drawn as
## polylines so the segments don't stack into stripes).
func _draw_trench() -> void:
	if _trail.size() < 2:
		return
	var mid := PackedVector2Array()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var cols_dark := PackedColorArray()
	var cols_light := PackedColorArray()
	var cols_side := PackedColorArray()
	for i in _trail.size():
		var p: Vector2 = _trail[i][0] - global_position
		var q: Vector2 = _trail[mini(i + 1, _trail.size() - 1)][0] - global_position
		var o: Vector2 = _trail[maxi(i - 1, 0)][0] - global_position
		var side := (q - o).orthogonal().normalized()
		var k := clampf(1.0 - (_t - float(_trail[i][1])) / TRAIL_LIFE, 0.0, 1.0)
		mid.append(p)
		left.append(p - side * 24.0)
		right.append(p + side * 24.0)
		cols_dark.append(Color(MOUND_DARK, 0.42 * k))
		cols_light.append(Color(MOUND_LIGHT, 0.6 * k))
		cols_side.append(Color(MOUND_BODY.darkened(0.2), 0.55 * k))
	draw_polyline_colors(mid, cols_dark, 30.0, true)
	draw_polyline_colors(left, cols_light, 9.0, true)
	draw_polyline_colors(right, cols_side, 9.0, true)


## A point on the mound's lumpy outline (angle `a` from the travel direction), in the boss's frame.
func _mound_point(a: float, rx: float, ry: float, dir: Vector2, seed := 0.0) -> Vector2:
	var r := 1.0 + 0.08 * sin(3.0 * a + _t * 7.0 + seed) + 0.05 * sin(5.0 * a - _t * 11.0 + seed * 2.0)
	var x := cos(a) * rx * r * (1.2 if cos(a) > 0.0 else 1.0)
	var y := sin(a) * ry * r
	return dir * x + dir.orthogonal() * y


func _mound_poly(rx: float, ry: float, dir: Vector2, off: Vector2, seed := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 32:
		pts.append(_mound_point(TAU * i / 32.0, rx, ry, dir, seed) + off)
	return pts


## The sand mound. `k` 0..1 grows it (dive); `full` adds the mandibles, cracks and thrown pebbles.
func _draw_mound(k: float, full: bool) -> void:
	var dir := _turret.normalized() if _turret.length() > 0.1 else Vector2.RIGHT
	var rx := 76.0 * k
	var ry := 58.0 * k
	if rx < 2.0:
		return
	var side := dir.orthogonal()
	# Churned sand round it and its shadow (bottom-right).
	draw_colored_polygon(_mound_poly(rx * 1.35, ry * 1.35, dir, Vector2.ZERO, 1.3), Color(MOUND_DARK, 0.16 * k))
	draw_colored_polygon(_mound_poly(rx * 1.04, ry * 1.04, dir, Vector2(12, 16)), Color(MOUND_DARK, 0.45 * k))
	# Drill mandibles chomping out of the front (under the sand's lip).
	if full:
		var bite := 0.5 + 0.5 * sin(_t * 16.0)
		for m: float in [-1.0, 1.0]:
			# A curved pincer: out from the lip, sweeping forward and hooking in to the tip.
			var inner := dir * (rx * 0.85) + side * m * 12.0
			var outer := dir * (rx * 0.78) + side * m * 40.0
			var bend := dir * (rx * 1.45) + side * m * (44.0 + 10.0 * bite)
			var tip := dir * (rx * 2.0) + side * m * (2.0 + 22.0 * bite)
			var hook := dir * (rx * 1.4) + side * m * (16.0 + 12.0 * bite)
			draw_colored_polygon(PackedVector2Array([inner, outer, bend, tip, hook]), MANDIBLE)
			draw_polyline(PackedVector2Array([outer, bend, tip]), Color(GOLD, 0.9), 3.0, true)
			draw_polyline(PackedVector2Array([inner, hook, tip]), Color(MANDIBLE.lightened(0.3), 0.9), 2.0, true)
			for tooth in 3:
				var at := hook.lerp(tip, 0.2 + tooth * 0.25)
				draw_line(at, at - side * m * 7.0, Color(GOLD, 0.7), 2.0, true)
	# The heaving sand: stacked lumps, darker at the base, lit towards the top-left.
	for layer in 7:
		var f := layer / 6.0
		var col := MOUND_BODY.darkened(0.14).lerp(MOUND_BODY, minf(f * 2.0, 1.0)).lerp(MOUND_LIGHT, maxf(f * 1.4 - 0.4, 0.0))
		draw_colored_polygon(_mound_poly(rx * (1.0 - 0.72 * f), ry * (1.0 - 0.76 * f), dir, Vector2(-20, -20) * f, layer * 0.9), Color(col, k))
	if not full:
		return
	# A split along the crest with the reactor's turquoise glowing through it.
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	var crack := PackedVector2Array()
	for s in 7:
		var f := lerpf(-0.75, 0.75, s / 6.0)
		crack.append(dir * (rx * f) + side * (6.0 * sin(s * 2.3 + _t * 3.0)) + Vector2(-6, -6))
	draw_polyline(crack, Color(TURQ, 0.18 + 0.12 * pulse), 14.0, true)
	draw_polyline(crack, Color(MOUND_DARK, 0.85), 4.0, true)
	draw_polyline(crack, Color(TURQ.lightened(0.3), 0.55 + 0.35 * pulse), 1.6, true)
	# Pebbles and sand thrown off to both sides of the bow.
	for i in 14:
		var ph := fposmod(_t * 1.7 + i * 0.137, 1.0)
		var m := -1.0 if i % 2 == 0 else 1.0
		var at := dir * (rx * (0.9 - 1.3 * ph)) + side * m * (ry * 0.9 + 70.0 * ph) + Vector2(0, -26.0 * sin(PI * ph))
		draw_circle(at + Vector2(3, 4), 2.0 + (i % 3), Color(MOUND_DARK, 0.35 * (1.0 - ph)))
		draw_circle(at, 2.0 + (i % 3), Color(MOUND_BODY.lerp(MOUND_DARK, 0.35), 1.0 - ph))
