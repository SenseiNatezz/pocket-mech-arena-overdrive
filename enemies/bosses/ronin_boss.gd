class_name RoninBoss
extends WardenBoss
## "Ronin" (Higgsfield sprite): samurai mech boss wielding a double-bladed energy naginata.
##   Phase 1  energy crescent waves + dash-slash through the player (red line telegraph)
##   Phase 2  + whirlwind (spins after you with the naginata, sheds bullets), dashes chain 2x and
##            leave crescents behind, wider crescent fans
##   Phase 3  + crescent storm (rings of waves), summons Blade Strikers, 3-dash chains
## Phases (66% / 33% HP), roar, death sequence, `defeated` and the HUD hookup come from WardenBoss.

const RONIN_TEX := preload("res://assets/hq/enemies2/ronin.png")
const RONIN_SCALE := 0.6
const STRIKER := preload("res://enemies/blade_striker.tscn")
const DASH_SPEED := 1150.0
const DASH_TIME := 0.4

var _dashes := 0
var _hit_done := false
var _slash_fx := 0.0
var _trail: Array[Vector2] = []


func _think(delta: float) -> void:
	var speed_mult := 1.0 + (phase - 1) * 0.25
	if _state != &"dash" and _state != &"spin":
		_turret = _turret.slerp(dir_to_target(), 1.0 - exp(-6.0 * delta))
	facing = _turret
	if _roar > 0.0:
		_roar -= delta
		return
	_state_t -= delta
	match _state:
		&"idle":
			var d := dist_to_target()
			if d > 300.0:
				steer_to(target.global_position, move_speed * speed_mult)
			elif d < 180.0:
				desired_velocity = -dir_to_target() * move_speed
			else:
				desired_velocity = dir_to_target().orthogonal() * move_speed * 0.6 * signf(sin(_t * 0.7))
			if _state_t <= 0.0:
				_pick_attack()
		&"waves":
			desired_velocity = Vector2.ZERO
			_step_t -= delta
			if _step_t <= 0.0 and _step > 0:
				_step -= 1
				_step_t = 0.5 / speed_mult
				_slash_fx = 1.0
				var n := 2 * phase - 1
				for i in n:
					var dir := _turret.rotated((i - (n - 1) / 2.0) * 0.32)
					EnergyWave.spawn(global_position + dir * 70.0, dir * (400.0 + phase * 30.0), 16.0 * damage_mult, accent, 50.0, self)
				Sfx.play(&"saber", -3.0)
			if _step <= 0 and _step_t <= 0.0:
				_end_attack()
		&"dash_windup":
			desired_velocity = Vector2.ZERO
			if _state_t > 0.15:
				_charge_dir = dir_to_target()
				_turret = _charge_dir
			if _state_t <= 0.0:
				_state = &"dash"
				_state_t = DASH_TIME
				_hit_done = false
				_trail.clear()
				Sfx.play(&"dash", -2.0)
				Sfx.play(&"saber", -2.0)
		&"dash":
			desired_velocity = _charge_dir * DASH_SPEED
			velocity = desired_velocity
			_trail.push_front(global_position)
			if _trail.size() > 7:
				_trail.pop_back()
			if not _hit_done and dist_to_target() < hit_radius + 60.0:
				_hit_done = true
				_slash_fx = 1.0
				target.take_damage(26.0 * damage_mult, global_position, self)
				Combat.spark(target.global_position, accent, 1.6)
			var hit_wall := get_slide_collision_count() > 0 and _state_t < DASH_TIME - 0.08
			if hit_wall:
				Combat.shockwave(global_position, 150.0, accent, 0.35)
				Combat.shake(0.45)
				Sfx.play(&"slam", -3.0)
			if _state_t <= 0.0 or hit_wall:
				_slash_fx = 1.0
				if phase >= 2:
					for side in [-1.0, 1.0]:
						var dir: Vector2 = _charge_dir.orthogonal() * side
						EnergyWave.spawn(global_position + dir * 60.0, dir * 360.0, 14.0 * damage_mult, accent, 44.0, self)
				_dashes -= 1
				if _dashes > 0:
					_state = &"dash_windup"
					_state_t = 0.4
				else:
					_end_attack()
		&"spin":
			_spin += delta * 15.0
			steer_to(target.global_position, move_speed * 1.4 * speed_mult)
			_step_t -= delta
			if _step_t <= 0.0:
				_step_t = 0.3
				if dist_to_target() < hit_radius + 90.0:
					target.take_damage(12.0 * damage_mult, global_position, self)
					Combat.spark(target.global_position, accent, 1.0)
				Combat.damage_destructibles(global_position, hit_radius + 90.0, 20.0)
				Sfx.play(&"saber", -12.0, 0.2)
				if phase >= 3:
					for i in 8:
						shoot(Vector2.from_angle(_spin + i * TAU / 8.0), 280.0, 8.0, accent.lightened(0.3), 1.1)
			if _state_t <= 0.0:
				_turret = dir_to_target()
				_end_attack()
		&"storm":
			desired_velocity = Vector2.ZERO
			_step_t -= delta
			if _step_t <= 0.0 and _step > 0:
				_step -= 1
				_step_t = 0.7
				_slash_fx = 1.0
				var n := 10
				for i in n:
					var dir := Vector2.from_angle(TAU * (i + 0.5 * (_step % 2)) / n)
					EnergyWave.spawn(global_position + dir * 70.0, dir * 330.0, 14.0 * damage_mult, accent, 42.0, self)
				Combat.shockwave(global_position, 180.0, accent, 0.4)
				Sfx.play(&"saber", 0.0)
			if _step <= 0 and _step_t <= 0.0:
				_end_attack()
		&"summon":
			for i in 2:
				var e: Enemy = STRIKER.instantiate()
				e.position = position + Vector2.from_angle(randf() * TAU) * 120.0
				e.damage_mult = damage_mult
				get_parent().add_child(e)
			Sfx.play(&"alarm", -10.0, 0.0)
			_end_attack()


func _pick_attack() -> void:
	var options: Array[StringName] = [&"waves", &"dash_windup"]
	if phase >= 2:
		options.append(&"spin")
	if phase >= 3:
		options.append(&"storm")
		if get_tree().get_nodes_in_group("enemies").size() < 5:
			options.append(&"summon")
	options.erase(_last_attack)
	_state = options.pick_random()
	_last_attack = _state
	match _state:
		&"waves":
			_step = 3
			_step_t = 0.35
		&"dash_windup":
			_state_t = 0.7
			_dashes = phase
		&"spin":
			_state_t = 2.4
			_step_t = 0.0
			Sfx.play(&"charge", -8.0, 0.0)
		&"storm":
			_step = 2
			_step_t = 0.5


func _process(delta: float) -> void:
	_slash_fx = move_toward(_slash_fx, 0.0, delta * 3.0)
	if _state != &"dash" and not _trail.is_empty() and Engine.get_process_frames() % 2 == 0:
		_trail.pop_back()


func _draw() -> void:
	var shake := Vector2(randf_range(-4, 4), randf_range(-4, 4)) if _roar > 0.0 or _dying > 0.0 else Vector2.ZERO
	var rot := _turret.angle() + PI / 2
	if _state == &"spin":
		rot = _spin
	var step := absf(sin(_t * 7.0)) * 0.02 if velocity.length() > 20.0 and _state == &"idle" else 0.0
	var s := Vector2.ONE * (RONIN_SCALE + step)
	var half := RONIN_TEX.get_size() / 2
	for i in _trail.size():
		draw_set_transform(to_local(_trail[i]) + shake, rot, s)
		draw_texture(RONIN_TEX, -half, Color(accent, 0.3 * (1.0 - i / float(_trail.size()))))
	draw_set_transform(shake + Vector2(10, 16), rot, s)
	draw_texture(RONIN_TEX, -half, Color(0, 0, 0, 0.45))
	draw_set_transform(shake, rot, s)
	var body := tint(Color.WHITE)
	if _state == &"dash_windup":
		body = body.lerp(Color(1.6, 1.1, 0.8), 0.4 + 0.4 * sin(_t * 30.0))
	draw_texture(RONIN_TEX, -half, body)
	draw_set_transform(shake)
	# Whirlwind: a blurred ring of blade light around the spinning naginata.
	if _state == &"spin":
		var r := RONIN_TEX.get_size().x * RONIN_SCALE * 0.5
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(accent, 0.18), 30.0, true)
		for k in 2:
			var a := _spin + k * PI
			draw_arc(Vector2.ZERO, r, a - 1.2, a, 16, Color(accent.lightened(0.4), 0.7), 6.0, true)
	if _slash_fx > 0.0:
		var a := _turret.angle()
		draw_arc(Vector2.ZERO, 120.0, a - 1.5, a + 1.5, 24, Color(accent, 0.45 * _slash_fx), 22.0 * _slash_fx, true)
		draw_arc(Vector2.ZERO, 126.0, a - 1.3, a + 1.3, 24, Color(1, 0.95, 0.85, 0.9 * _slash_fx), 4.0, true)
	draw_set_transform(Vector2.ZERO)
	if _state == &"dash_windup":
		var reach := _charge_dir * DASH_SPEED * DASH_TIME
		draw_line(Vector2.ZERO, reach, Color(1.0, 0.15, 0.1, 0.22 + 0.3 * sin(_t * 30.0)), 90.0)
		draw_line(Vector2.ZERO, reach, Color(1.0, 0.35, 0.2, 0.9), 2.0)
