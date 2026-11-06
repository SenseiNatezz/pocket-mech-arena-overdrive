class_name VulcanBoss
extends WardenBoss
## "VULCAN, the Forge Titan" (Higgsfield sprite): boss of the Volcanic Forge (level 6). A colossal forge
## machine with a hammer arm, a magma-cannon arm and a furnace core.
##   Phase 1  hammer leap-slam (red landing circle -> shockwave + ring of fire bolts), magma lob (globs
##            onto red circles around you, each leaves a LavaPool), magma cannon volleys
##   Phase 2  + eruption (lava geysers burst out of the floor in a spreading pattern), summons Magma
##            Crawlers, slams fire two rings
##   Phase 3  + CORE BEAMS: the furnace opens and three fire beams sweep around it (thin red lines warn
##            first); the open core takes +50% damage. Slams leave lava behind; Anvils join the summons.
## Phases (66% / 33% HP), roar, death sequence, `defeated` and the HUD hookup come from WardenBoss.

const VULCAN_TEX := preload("res://assets/hq/enemies5/vulcan.png")
## (only 1.2x the v1 size - it was already the biggest boss)
const VULCAN_SCALE := 0.74
const CRAWLER := preload("res://enemies/magma_crawler.tscn")
const ANVIL := preload("res://enemies/anvil.tscn")
const SLAM_RADIUS := 190.0
const LEAP_TIME := 0.6
const BEAM_REACH := 720.0
const BEAM_WARN := 0.9
const BEAM_TIME := 2.8
## Arm tips in the sprite's own frame (art faces up), at VULCAN_SCALE.
const CANNON_TIP := Vector2(-154, -164)
const FIRE := Color(1.0, 0.45, 0.1)
const FIRE_HOT := Color(1.0, 0.9, 0.5)

var _land := Vector2.ZERO
var _from := Vector2.ZERO
var _beam_a := 0.0
var _beam_tick := 0.0
var _core_open := 0.0


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	if _state == &"beams" and _state_t < BEAM_TIME:
		amount *= 1.5
	super.take_damage(amount, from_pos, source)


func _cannon_tip() -> Vector2:
	return global_position + CANNON_TIP.rotated(_turret.angle() + PI / 2)


func _think(delta: float) -> void:
	var speed_mult := 1.0 + (phase - 1) * 0.2
	if _state != &"leap":
		_turret = _turret.slerp(dir_to_target(), 1.0 - exp(-4.0 * delta))
	facing = _turret
	_core_open = move_toward(_core_open, 1.0 if _state == &"beams" else 0.0, delta * 3.0)
	if _roar > 0.0:
		_roar -= delta
		return
	_state_t -= delta
	match _state:
		&"idle":
			var d := dist_to_target()
			if d > 340.0:
				steer_to(target.global_position, move_speed * speed_mult)
			elif d < 220.0:
				desired_velocity = -dir_to_target() * move_speed
			if _state_t <= 0.0:
				_pick_attack()
		&"crouch":
			desired_velocity = Vector2.ZERO
			if _state_t > 0.3:
				_land = target.global_position + target.velocity * 0.35
			if _state_t <= 0.0:
				_state = &"leap"
				_state_t = LEAP_TIME
				_from = global_position
				collision_layer = 0
				Sfx.play(&"dash", -2.0)
		&"leap":
			var v := (_land - _from) / LEAP_TIME
			desired_velocity = v
			velocity = v
			if _state_t <= 0.0:
				_slam()
		&"lob":
			var n := 3 + phase
			var lead := target.global_position + target.velocity * 0.5
			for i in n:
				var at := lead if i == 0 else lead + Vector2.from_angle(randf() * TAU) * randf_range(90.0, 260.0)
				var delay := 1.1 + i * 0.14
				Combat.artillery(at, 85.0, 18.0 * damage_mult, self, delay, "player", _cannon_tip())
				LavaPool.spawn(at, 56.0, 3.5, 12.0, self, delay)
			Combat.spark(_cannon_tip(), FIRE, 2.0)
			Sfx.play(&"missile", -2.0)
			_end_attack()
		&"cannon":
			desired_velocity = Vector2.ZERO
			_step_t -= delta
			if _step_t <= 0.0 and _step > 0:
				_step -= 1
				_step_t = 0.32 / speed_mult
				var aim := (target.global_position - _cannon_tip()).normalized()
				for i in 3:
					var b := Combat.fire(_cannon_tip(), aim.rotated((i - 1) * 0.16) * (400.0 + phase * 30.0), 12.0 * damage_mult,
						false, self, FIRE, 1.9, 2.2)
					b.rotation = aim.angle()
				Combat.spark(_cannon_tip(), FIRE_HOT, 1.4)
				Sfx.play(&"enemy_shoot", -3.0)
			if _step <= 0 and _step_t <= 0.0:
				_end_attack()
		&"eruption":
			desired_velocity = Vector2.ZERO
			var n := 6 + phase * 2
			for i in n:
				var ring := 140.0 + 70.0 * (i % 4)
				var at := target.global_position + Vector2.from_angle(TAU * i / n + randf_range(-0.2, 0.2)) * ring
				if i == 0:
					at = target.global_position + target.velocity * 0.6
				var delay := 0.8 + (i % 4) * 0.35
				Combat.artillery(at, 80.0, 18.0 * damage_mult, self, delay, "player")
				LavaPool.spawn(at, 60.0, 3.5, 12.0, self, delay)
			Combat.shockwave(global_position, 260.0, FIRE, 0.5)
			Combat.shake(0.4)
			Sfx.play(&"alarm", -6.0, 0.0)
			_state = &"idle"
			_state_t = 1.6
		&"summon":
			var kinds: Array[PackedScene] = [CRAWLER, CRAWLER]
			if phase >= 3:
				kinds.append(ANVIL)
			for s in kinds:
				var e: Enemy = s.instantiate()
				e.position = position + Vector2.from_angle(randf() * TAU) * 190.0
				e.damage_mult = damage_mult
				get_parent().add_child(e)
			Combat.shockwave(global_position, 240.0, FIRE, 0.4)
			Sfx.play(&"alarm", -10.0, 0.0)
			_end_attack()
		&"beams":
			desired_velocity = Vector2.ZERO
			if _state_t < BEAM_TIME:
				_beam_a += delta * (0.85 + 0.15 * phase)
				_beam_tick -= delta
				if _beam_tick <= 0.0 and _player_in_beam():
					_beam_tick = 0.4
					target.take_damage(14.0 * damage_mult, global_position, self)
					Combat.spark(target.global_position, FIRE_HOT, 1.2)
			if _state_t <= 0.0:
				_end_attack()


func _player_in_beam() -> bool:
	var off := target.global_position - global_position
	var d := off.length()
	if d > BEAM_REACH or d < 1.0:
		return false
	var hr: float = target.get("hit_radius") if target.get("hit_radius") != null else 20.0
	for i in 3:
		var a := _beam_a + TAU * i / 3.0
		if absf(angle_difference(off.angle(), a)) * d < 14.0 + hr:
			return true
	return false


func _slam() -> void:
	collision_layer = 256
	Combat.area_damage(global_position, SLAM_RADIUS, 30.0 * damage_mult, self, true, Vector2.ZERO, PI, 520.0)
	Combat.damage_destructibles(global_position, SLAM_RADIUS, 60.0)
	Combat.shockwave(global_position, SLAM_RADIUS * 1.5, FIRE, 0.5)
	Combat.shockwave(global_position, SLAM_RADIUS * 0.8, FIRE_HOT, 0.3)
	Combat.debris(global_position, 84.0, Color(0.3, 0.26, 0.26))
	Combat.shake(0.7)
	Sfx.play(&"slam", 0.0)
	var rings := 1 if phase == 1 else 2
	for r in rings:
		for i in 16:
			shoot(Vector2.from_angle(TAU * (i + 0.5 * r) / 16.0), 250.0 + r * 70.0, 10.0, FIRE, 1.3)
	if phase >= 3:
		for i in 3:
			LavaPool.spawn(global_position + Vector2.from_angle(TAU * i / 3.0 + randf()) * 150.0, 55.0, 4.0, 12.0, self)
	_state = &"idle"
	_state_t = 1.2


func _pick_attack() -> void:
	var options: Array[StringName] = [&"crouch", &"lob", &"cannon"]
	if phase >= 2:
		options.append(&"eruption")
		if get_tree().get_nodes_in_group("enemies").size() < 5:
			options.append(&"summon")
	if phase >= 3:
		options.append_array([&"beams", &"beams"])
	options.erase(_last_attack)
	begin_attack(options.pick_random())


## Starts attack `attack` (one of the _pick_attack options; tests call it directly).
func begin_attack(attack: StringName) -> void:
	_state = attack
	_last_attack = _state
	_turret = dir_to_target()
	match _state:
		&"crouch":
			_state_t = 0.95
			_land = target.global_position
			Sfx.play(&"charge", -6.0, 0.0)
		&"cannon":
			_step = 3 + phase
			_step_t = 0.35
		&"beams":
			_state_t = BEAM_TIME + BEAM_WARN
			_beam_a = dir_to_target().angle() + PI / 3.0
			_beam_tick = 0.0
			Sfx.play(&"charge", -4.0, 0.0)


func _draw() -> void:
	var shake := Vector2(randf_range(-4, 4), randf_range(-4, 4)) if _roar > 0.0 or _dying > 0.0 else Vector2.ZERO
	# Landing circle for the hammer slam.
	if _state == &"crouch" or _state == &"leap":
		var k := 1.0 - _state_t / (0.95 if _state == &"crouch" else LEAP_TIME)
		var at := _land - global_position
		draw_circle(at, SLAM_RADIUS, Color(1.0, 0.2, 0.1, 0.1 + 0.15 * k))
		draw_arc(at, SLAM_RADIUS, 0, TAU, 48, Color(1.0, 0.3, 0.15, 0.85), 4.0, true)
		draw_arc(at, SLAM_RADIUS * clampf(k, 0.0, 1.0), 0, TAU, 48, Color(1.0, 0.65, 0.3, 0.6), 2.5, true)
	# Core beams: thin warning lines first, then three sweeping fire beams.
	if _state == &"beams":
		for i in 3:
			var dir := Vector2.from_angle(_beam_a + TAU * i / 3.0)
			if _state_t > BEAM_TIME:
				draw_line(dir * 72.0, dir * BEAM_REACH, Color(1.0, 0.15, 0.1, 0.35 + 0.3 * sin(_t * 30.0)), 3.0)
			else:
				var w := 26.0 + 4.0 * sin(_t * 40.0 + i)
				draw_line(dir * 72.0, dir * BEAM_REACH, Color(0.25, 0.05, 0.02, 0.8), w + 8.0)
				draw_line(dir * 72.0, dir * BEAM_REACH, FIRE, w)
				draw_line(dir * 72.0, dir * BEAM_REACH, FIRE_HOT, w * 0.45)
				draw_line(dir * 72.0, dir * BEAM_REACH, Color.WHITE, w * 0.15)
	var lift := 0.0
	if _state == &"leap":
		lift = sin(clampf(1.0 - _state_t / LEAP_TIME, 0.0, 1.0) * PI)
	var rot := _turret.angle() + PI / 2
	var stomp := absf(sin(_t * 5.0)) * 0.02 if velocity.length() > 20.0 else 0.0
	var squash := 0.04 if _state == &"crouch" else 0.0
	var s := Vector2(VULCAN_SCALE + stomp + squash, VULCAN_SCALE + stomp - squash) * (1.0 + 0.22 * lift)
	var half := VULCAN_TEX.get_size() / 2
	draw_set_transform(shake + Vector2(14, 22) + Vector2(24, 36) * lift, rot, s * (1.0 - 0.2 * lift))
	draw_texture(VULCAN_TEX, -half, Color(0, 0, 0, 0.45 - 0.2 * lift))
	draw_set_transform(shake + Vector2(0, -60.0 * lift), rot, s)
	draw_texture(VULCAN_TEX, -half, tint(Color.WHITE))
	draw_set_transform(shake + Vector2(0, -60.0 * lift))
	# Furnace core: pulses faster each phase; blazes open during the beams.
	var pulse := 0.5 + 0.5 * sin(_t * (3.0 + phase * 2.0))
	var core := Vector2(0, 36).rotated(rot)
	draw_circle(core, 36.0 + 12.0 * pulse + 31.0 * _core_open, Color(FIRE, 0.16 + 0.1 * pulse + 0.25 * _core_open))
	draw_circle(core, 12.0 + 5.0 * pulse + 12.0 * _core_open, Color(FIRE_HOT, 0.5 + 0.4 * _core_open))
	draw_set_transform(Vector2.ZERO)
