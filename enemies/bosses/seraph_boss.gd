class_name SeraphBoss
extends WardenBoss
## "Seraph" (Higgsfield sprite): angelic mech boss commanding six violet sword funnels (remote energy
## blades that orbit it and fly on their own).
##   Phase 1  funnel volleys (each funnel fires from orbit) + halo bullet spiral from the core
##   Phase 2  + funnel dives: funnels lock on (thin line) and stab straight through your position
##   Phase 3  + sword cage: all six ring you, then stab inward together; summons Lancers
## Phases (66% / 33% HP), roar, death sequence, `defeated` and the HUD hookup come from WardenBoss.

const SERAPH_TEX := preload("res://assets/hq/enemies2/seraph.png")
const FUNNEL_TEX := preload("res://assets/hq/enemies2/sword_funnel.png")
const SERAPH_SCALE := 0.58
const FUNNEL_SCALE := 0.6
const LANCER := preload("res://enemies/lancer.tscn")
const COUNT := 6
const ORBIT_RADIUS := 150.0
const CAGE_RADIUS := 270.0
const CAGE_TIME := 1.4

enum F { ORBIT, AIM, DIVE, RETURN, CAGE, STAB }

var _f_pos: Array[Vector2] = []
var _f_dir: Array[Vector2] = []
var _f_mode: Array[int] = []
var _f_t: Array[float] = []
var _f_goal: Array[Vector2] = []
var _f_hit: Array[bool] = []
var _orbit := 0.0
var _cage_center := Vector2.ZERO
var _cage_t := 0.0


func _ready() -> void:
	super._ready()
	for i in COUNT:
		_f_pos.append(global_position + _slot_offset(i))
		_f_dir.append(_slot_offset(i).normalized())
		_f_mode.append(F.ORBIT)
		_f_t.append(0.0)
		_f_goal.append(Vector2.ZERO)
		_f_hit.append(false)


func _slot_offset(i: int) -> Vector2:
	return Vector2.from_angle(_orbit + i * TAU / COUNT) * ORBIT_RADIUS


func die() -> void:
	if _dying > 0.0 or dead:
		return
	super.die()
	for p in _f_pos:
		Combat.explosion_fx(p, 70.0, accent)


func _think(delta: float) -> void:
	var speed_mult := 1.0 + (phase - 1) * 0.25
	_turret = _turret.slerp(dir_to_target(), 1.0 - exp(-(8.0 if _state != &"idle" else 4.0) * delta))
	facing = _turret
	if _roar > 0.0:
		_roar -= delta
		return
	_state_t -= delta
	match _state:
		&"idle":
			var d := dist_to_target()
			if d > 420.0:
				steer_to(target.global_position, move_speed * speed_mult)
			elif d < 280.0:
				desired_velocity = -dir_to_target() * move_speed
			else:
				desired_velocity = dir_to_target().orthogonal() * move_speed * 0.5 * signf(sin(_t * 0.5))
			if _state_t <= 0.0:
				_pick_attack()
		&"volley":
			_step_t -= delta
			if _step_t <= 0.0 and _step > 0:
				_step -= 1
				_step_t = 0.12 / speed_mult
				var i := _step % COUNT
				if _f_mode[i] == F.ORBIT:
					var dir := (target.global_position - _f_pos[i]).normalized()
					Combat.fire(_f_pos[i] + dir * 30.0, dir * (400.0 + phase * 30.0), 9.0 * damage_mult, false, self,
						accent.lightened(0.3), 1.1, 2.5)
					Combat.spark(_f_pos[i], accent, 0.8)
					Sfx.play(&"enemy_shoot", -12.0)
			if _step <= 0:
				_end_attack()
		&"halo":
			desired_velocity = Vector2.ZERO
			_spin += delta * (2.2 + phase * 0.4)
			_step_t -= delta
			if _step_t <= 0.0:
				_step_t = 0.09
				var arms := phase + 2
				for arm in arms:
					shoot(Vector2.from_angle(_spin + arm * TAU / arms), 280.0, 8.0, Color(0.9, 0.7, 1.0), 1.1)
			if _state_t <= 0.0:
				_end_attack()
		&"dive":
			_step_t -= delta
			if _step_t <= 0.0 and _step > 0:
				_step -= 1
				_step_t = 0.35 / speed_mult
				var i := _free_funnel()
				if i >= 0:
					_f_mode[i] = F.AIM
					_f_t[i] = 0.5
			if _step <= 0:
				_end_attack()
		&"cage":
			desired_velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_end_attack()
		&"summon":
			for i in 2:
				var e: Enemy = LANCER.instantiate()
				e.position = position + Vector2.from_angle(randf() * TAU) * 140.0
				e.damage_mult = damage_mult
				get_parent().add_child(e)
			Sfx.play(&"alarm", -10.0, 0.0)
			_end_attack()


func _free_funnel() -> int:
	var free: Array[int] = []
	for i in COUNT:
		if _f_mode[i] == F.ORBIT:
			free.append(i)
	return free.pick_random() if not free.is_empty() else -1


func _pick_attack() -> void:
	var options: Array[StringName] = [&"volley", &"halo"]
	if phase >= 2:
		options.append(&"dive")
	if phase >= 3:
		options.append(&"cage")
		if get_tree().get_nodes_in_group("enemies").size() < 5:
			options.append(&"summon")
	options.erase(_last_attack)
	_state = options.pick_random()
	_last_attack = _state
	# Every attack starts squared up to the player.
	_turret = dir_to_target()
	match _state:
		&"volley":
			_step = COUNT * 2
			_step_t = 0.2
		&"halo":
			_state_t = 2.2
			_step_t = 0.0
		&"dive":
			_step = 3 if phase == 2 else COUNT
			_step_t = 0.1
		&"cage":
			_state_t = CAGE_TIME + 1.0
			_cage_center = target.global_position
			_cage_t = CAGE_TIME
			for i in COUNT:
				_f_mode[i] = F.CAGE
				_f_hit[i] = false
			Sfx.play(&"charge", -6.0, 0.0)


# --- sword funnels ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if dead:
		return
	_orbit += delta * 0.9
	var player := target if is_instance_valid(target) and not target.dead else null
	if _cage_t > 0.0:
		_cage_t -= delta
		if _cage_t <= 0.0:
			for i in COUNT:
				if _f_mode[i] == F.CAGE:
					_f_mode[i] = F.STAB
					_f_goal[i] = _cage_center + (_cage_center - _f_pos[i]).normalized() * 110.0
			Sfx.play(&"saber", 0.0)
	for i in COUNT:
		var slot := global_position + _slot_offset(i)
		match _f_mode[i]:
			F.ORBIT:
				_f_pos[i] = _f_pos[i].lerp(slot, 1.0 - exp(-8.0 * delta))
				_f_dir[i] = _f_dir[i].slerp((_f_pos[i] - global_position).normalized(), 1.0 - exp(-8.0 * delta))
			F.AIM:
				_f_pos[i] = _f_pos[i].lerp(slot, 1.0 - exp(-4.0 * delta))
				if player:
					_f_dir[i] = _f_dir[i].slerp((player.global_position - _f_pos[i]).normalized(), 1.0 - exp(-14.0 * delta))
				_f_t[i] -= delta
				if _f_t[i] <= 0.0:
					_f_mode[i] = F.DIVE
					_f_hit[i] = false
					var reach: float = _f_pos[i].distance_to(player.global_position) + 260.0 if player else 600.0
					_f_goal[i] = _f_pos[i] + _f_dir[i] * reach
					Sfx.play(&"dash", -8.0)
			F.DIVE, F.STAB:
				var speed := 1300.0 if _f_mode[i] == F.DIVE else 1050.0
				_f_pos[i] = _f_pos[i].move_toward(_f_goal[i], speed * delta)
				_funnel_hit(i, player)
				if _f_pos[i].distance_to(_f_goal[i]) < 1.0:
					_f_mode[i] = F.RETURN
			F.RETURN:
				_f_pos[i] = _f_pos[i].move_toward(slot, 900.0 * delta)
				_f_dir[i] = _f_dir[i].slerp((slot - _f_pos[i]).normalized(), 1.0 - exp(-6.0 * delta))
				if _f_pos[i].distance_to(slot) < 24.0:
					_f_mode[i] = F.ORBIT
			F.CAGE:
				var ring := _cage_center + Vector2.from_angle(i * TAU / COUNT) * CAGE_RADIUS
				_f_pos[i] = _f_pos[i].lerp(ring, 1.0 - exp(-7.0 * delta))
				_f_dir[i] = _f_dir[i].slerp((_cage_center - _f_pos[i]).normalized(), 1.0 - exp(-10.0 * delta))
	queue_redraw()


func _funnel_hit(i: int, player: Mech) -> void:
	if _f_hit[i] or player == null:
		return
	if _f_pos[i].distance_to(player.global_position) < 38.0:
		_f_hit[i] = true
		player.take_damage(14.0 * damage_mult, _f_pos[i], self)
		Combat.spark(player.global_position, accent, 1.3)


func _draw() -> void:
	var shake := Vector2(randf_range(-4, 4), randf_range(-4, 4)) if _roar > 0.0 or _dying > 0.0 else Vector2.ZERO
	var rot := _turret.angle() + PI / 2
	var hover := sin(_t * 2.0) * 0.015
	var s := Vector2.ONE * (SERAPH_SCALE + hover)
	var half := SERAPH_TEX.get_size() / 2
	# Floats: a soft, offset shadow far below.
	draw_set_transform(shake + Vector2(24, 40), rot, s * 0.9)
	draw_texture(SERAPH_TEX, -half, Color(0, 0, 0, 0.3))
	draw_set_transform(shake, rot, s)
	draw_texture(SERAPH_TEX, -half, tint(Color.WHITE))
	draw_set_transform(shake)
	var pulse := 0.5 + 0.5 * sin(_t * (3.0 + phase * 2.5))
	draw_circle(Vector2.ZERO, 22 + pulse * 10, Color(accent, 0.2 + 0.12 * pulse))
	draw_circle(Vector2.ZERO, 8 + pulse * 3, Color(accent.lightened(0.6), 0.6))
	if _state == &"halo":
		draw_arc(Vector2.ZERO, 90.0, 0.0, TAU, 40, Color(accent, 0.35 + 0.2 * pulse), 4.0, true)
	draw_set_transform(Vector2.ZERO)
	if _dying > 0.0:
		return
	# Sword funnels (positions are global).
	var fhalf := FUNNEL_TEX.get_size() / 2
	for i in COUNT:
		var p := to_local(_f_pos[i])
		var mode := _f_mode[i]
		if mode == F.AIM:
			var k := 1.0 - _f_t[i] / 0.5
			draw_line(p, p + _f_dir[i] * 900.0, Color(accent, 0.15 + 0.5 * k), 2.0 + 2.0 * k)
		elif mode == F.CAGE and _cage_t < 0.8:
			var blink := 0.5 + 0.5 * signf(sin(_t * 40.0))
			draw_line(p, to_local(_cage_center), Color(1.0, 0.3, 0.6, 0.6 * blink), 3.0)
		elif mode == F.DIVE or mode == F.STAB:
			draw_line(p, p - _f_dir[i] * 90.0, Color(accent, 0.35), 14.0)
		draw_circle(p, 26.0, Color(accent, 0.18))
		draw_set_transform(p, _f_dir[i].angle() + PI / 2, Vector2.ONE * FUNNEL_SCALE)
		draw_texture(FUNNEL_TEX, -fhalf, Color.WHITE)
		draw_set_transform(Vector2.ZERO)
	if _cage_t > 0.0:
		var k := 1.0 - _cage_t / CAGE_TIME
		draw_arc(to_local(_cage_center), CAGE_RADIUS, 0.0, TAU, 64, Color(accent, 0.2 + 0.3 * k), 3.0, true)
		draw_circle(to_local(_cage_center), 60.0 * k, Color(1.0, 0.3, 0.6, 0.15 * k))
