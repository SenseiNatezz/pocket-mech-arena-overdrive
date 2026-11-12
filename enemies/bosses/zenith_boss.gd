class_name ZenithBoss
extends WardenBoss
## "ZENITH, the Orbital Dreadnought" (Higgsfield sprite): boss of the Orbital Dry Dock (level 8). A
## cross-hulled dreadnought with four cannon pods on docking arms and a violet reactor eye.
##   Phase 1  BROADSIDE (all four pods fire spreads in turn), ORBITAL STRIKE (targeting circles rain
##            down around you)
##   Phase 2  + GRAVITY WELL (it drags you in - Mech.pull, boosting breaks free - while a spiral of
##            shots wheels out of it), LAUNCH (Void Skimmers / a Mag Mine Drone out of the hull)
##   Phase 3  + MAIN GUN: the prow charges along a danger lane that slowly tracks you, then fires a
##            heavy beam out to the first wall for a second and a half (cover blocks it)
## Phases (66% / 33% HP), OVERDRIVE (20%), roar, death and the HUD hookup come from WardenBoss.

const ZENITH_TEX := preload("res://assets/hq/enemies6/zenith.png")
const ZENITH_SCALE := 0.72
const SKIMMER := preload("res://enemies/void_skimmer.tscn")
const DRONE := preload("res://enemies/mag_mine_drone.tscn")
const VIOLET := Color(0.8, 0.35, 1.0)
const MAGENTA := Color(1.0, 0.35, 0.75)
## The four cannon pods and the prow, in the sprite's own frame at ZENITH_SCALE (art faces up).
const PODS: Array[Vector2] = [Vector2(-120, -40), Vector2(120, -40), Vector2(-110, 90), Vector2(110, 90)]
const PROW := Vector2(0, -170)
const WELL_TIME := 3.0
const WELL_PULL := 150.0
const GUN_WARN := 1.1
const GUN_TIME := 1.5
const GUN_REACH := 1500.0
const GUN_HIT := 26.0
const GUN_TURN := 0.5

var _gun_dir := Vector2.DOWN
var _gun_end := Vector2.ZERO
var _gun_tick := 0.0
var _pod := 0


func _local(p: Vector2) -> Vector2:
	return p.rotated(_turret.angle() + PI / 2)


func _think(delta: float) -> void:
	var speed_mult := 1.0 + (phase - 1) * 0.2
	if _state != &"gun":
		_turret = _turret.slerp(dir_to_target(), 1.0 - exp(-3.5 * delta))
	facing = _turret
	if _roar > 0.0:
		_roar -= delta
		return
	_state_t -= delta
	match _state:
		&"idle":
			var d := dist_to_target()
			if d > 460.0:
				steer_to(target.global_position, move_speed * speed_mult)
			elif d < 300.0:
				desired_velocity = -dir_to_target() * move_speed
			else:
				desired_velocity = dir_to_target().orthogonal() * move_speed * 0.5
			if _state_t <= 0.0:
				_pick_attack()
		&"broadside":
			desired_velocity = Vector2.ZERO
			_step_t -= delta
			if _step_t <= 0.0 and _step > 0:
				_step -= 1
				_step_t = 0.22 / speed_mult
				var p := global_position + _local(PODS[_pod % 4])
				_pod += 1
				var aim := (target.global_position - p).normalized()
				for i in 3:
					var b := Combat.fire(p, aim.rotated((i - 1) * 0.14) * (380.0 + phase * 25.0), 11.0 * damage_mult,
						false, self, MAGENTA, 1.4, 2.4)
					b.rotation = aim.angle()
				Combat.spark(p, VIOLET, 1.2)
				Sfx.play(&"enemy_shoot", -5.0)
			if _step <= 0 and _step_t <= 0.0:
				_end_attack()
		&"strike":
			var n := 4 + phase * 2
			for i in n:
				var at := target.global_position + target.velocity * 0.5
				if i > 0:
					at += Vector2.from_angle(TAU * i / n + randf_range(-0.3, 0.3)) * randf_range(110.0, 300.0)
				Combat.artillery(at, 85.0, 19.0 * damage_mult, self, 1.15 + (i % 3) * 0.2, "player")
			Combat.shockwave(global_position, 200.0, VIOLET, 0.35)
			Sfx.play(&"alarm", -6.0, 0.0)
			_end_attack()
		&"well":
			desired_velocity = Vector2.ZERO
			if dist_to_target() > 60.0:
				target.pull((global_position - target.global_position).normalized() * WELL_PULL)
			_spin += delta * (2.0 + phase * 0.3)
			_step_t -= delta
			if _step_t <= 0.0:
				_step_t = 0.09
				for arm in 2 + (1 if phase >= 3 else 0):
					shoot(Vector2.from_angle(_spin + arm * TAU / (2 + (1 if phase >= 3 else 0))), 260.0, 8.0, VIOLET, 1.1)
			if _state_t <= 0.0:
				_end_attack()
		&"launch":
			var kinds: Array[PackedScene] = [SKIMMER, SKIMMER]
			if randf() >= 0.6:
				kinds[0] = DRONE
			for s in kinds:
				var e: Enemy = s.instantiate()
				e.position = position + Vector2.from_angle(randf() * TAU) * 200.0
				e.damage_mult = damage_mult
				get_parent().add_child(e)
			Combat.shockwave(global_position, 240.0, VIOLET, 0.4)
			Sfx.play(&"alarm", -10.0, 0.0)
			_end_attack()
		&"gun_warn":
			desired_velocity = Vector2.ZERO
			if _state_t > 0.3:
				_gun_dir = Vector2.from_angle(rotate_toward(_gun_dir.angle(), (target.global_position - _prow()).angle(), 2.2 * delta))
			_turret = _gun_dir
			_trace_gun()
			if _state_t <= 0.0:
				_state = &"gun"
				_state_t = GUN_TIME
				_gun_tick = 0.0
				Combat.shockwave(_prow(), 260.0, VIOLET, 0.4)
				Combat.shake(0.6)
				Combat.rumble(0.4, 0.8, 0.4)
				Sfx.play(&"big_explode", -8.0)
				Sfx.play(&"laser", -2.0, 0.0)
		&"gun":
			desired_velocity = Vector2.ZERO
			_gun_dir = Vector2.from_angle(rotate_toward(_gun_dir.angle(), (target.global_position - _prow()).angle(), GUN_TURN * delta))
			_turret = _gun_dir
			_trace_gun()
			_gun_tick -= delta
			if _gun_tick <= 0.0:
				_gun_tick = 0.25
				var p := Geometry2D.get_closest_point_to_segment(target.global_position, _prow(), _gun_end)
				var hr: float = target.get("hit_radius") if target.get("hit_radius") != null else 20.0
				if p.distance_to(target.global_position) < GUN_HIT + hr:
					target.take_damage(10.0 * damage_mult, global_position, self)
					Combat.spark(target.global_position, VIOLET, 1.4)
				Combat.spark(_gun_end, MAGENTA, 2.0)
			if _state_t <= 0.0:
				_end_attack()


func _prow() -> Vector2:
	return global_position + _local(PROW)


func _trace_gun() -> void:
	var from := _prow()
	var q := PhysicsRayQueryParameters2D.create(from, from + _gun_dir * GUN_REACH, 1 | 32)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	_gun_end = hit.position if not hit.is_empty() else from + _gun_dir * GUN_REACH


func _pick_attack() -> void:
	var options: Array[StringName] = [&"broadside", &"strike"]
	if phase >= 2:
		options.append(&"well")
		if get_tree().get_nodes_in_group("enemies").size() < 5:
			options.append(&"launch")
	if phase >= 3:
		options.append_array([&"gun_warn", &"gun_warn"])
	if phase >= 4:
		options.append(&"gun_warn")
	options.erase(_last_attack)
	begin_attack(options.pick_random())


## Starts attack `attack` (one of the _pick_attack options; tests call it directly).
func begin_attack(attack: StringName) -> void:
	_state = attack
	_last_attack = _state
	_turret = dir_to_target()
	match _state:
		&"broadside":
			_step = 6 + phase * 2
			_step_t = 0.3
		&"well":
			_state_t = WELL_TIME
			_step_t = 0.4
			Sfx.play(&"charge", -6.0, 0.0)
		&"gun_warn":
			_state_t = GUN_WARN
			_gun_dir = dir_to_target()
			_trace_gun()
			Sfx.play(&"charge", -4.0, 0.0)


func _draw() -> void:
	var shake := Vector2(randf_range(-4, 4), randf_range(-4, 4)) if _roar > 0.0 or _dying > 0.0 else Vector2.ZERO
	if _state == &"well":
		# Rings collapsing into the hull.
		for i in 4:
			var f := 1.0 - fmod(_t * 0.9 + i * 0.25, 1.0)
			draw_arc(Vector2.ZERO, 120.0 + 420.0 * f, 0, TAU, 64, Color(VIOLET, 0.35 * (1.0 - f)), 3.0, true)
	if _state == &"gun_warn":
		var k := clampf(1.0 - _state_t / GUN_WARN, 0.0, 1.0)
		DangerLane.draw(self, _prow() - global_position, _gun_end - global_position, GUN_HIT + 12.0, k, _t, Color(1.0, 0.3, 0.6))
	var rot := _turret.angle() + PI / 2
	var hover := sin(_t * 1.6) * 4.0
	var s := Vector2.ONE * ZENITH_SCALE
	var half := ZENITH_TEX.get_size() / 2
	draw_set_transform(shake + Vector2(26, 44), rot, s * 0.94)
	draw_texture(ZENITH_TEX, -half, Color(0, 0, 0, 0.35))
	draw_set_transform(shake + Vector2(0, hover), rot, s)
	draw_texture(ZENITH_TEX, -half, tint(Color.WHITE))
	draw_set_transform(shake + Vector2(0, hover))
	var pulse := 0.5 + 0.5 * sin(_t * (2.5 + phase * 2.0))
	draw_circle(Vector2.ZERO, 34.0 + 12.0 * pulse, Color(VIOLET, 0.16 + 0.12 * pulse))
	draw_circle(Vector2.ZERO, 12.0 + 4.0 * pulse, Color(MAGENTA.lightened(0.4), 0.6))
	draw_set_transform(Vector2.ZERO)
	if _state == &"gun":
		var from := _prow() - global_position
		var to := _gun_end - global_position
		var flick := 0.85 + 0.15 * sin(_t * 60.0)
		draw_line(from, to, Color(VIOLET, 0.3), GUN_HIT * 3.0 * flick, true)
		draw_line(from, to, Color(MAGENTA, 0.7), GUN_HIT * 1.3 * flick, true)
		draw_line(from, to, Color(1, 0.92, 1, 0.95), GUN_HIT * 0.45, true)
		draw_circle(to, 30.0 * flick, Color(MAGENTA, 0.6))
		draw_circle(from, 26.0 * flick, Color(1, 0.9, 1, 0.8))
	elif _state == &"gun_warn":
		var k := clampf(1.0 - _state_t / GUN_WARN, 0.0, 1.0)
		draw_circle(_prow() - global_position, 10.0 + 24.0 * k, Color(MAGENTA, 0.3 + 0.5 * k))



func _has_ground_shadow() -> bool:
	return false  # (flies / floats)
