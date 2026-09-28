class_name WardenBoss
extends Enemy
## "Warden": boss of each arena's boss room. Heavy quad-legged siege walker with three phases:
##   Phase 1  bullet fans + telegraphed artillery barrage
##   Phase 2  + spiral bullet storm, + charging ram (red line telegraph)
##   Phase 3  + bullet rings, + summons Scrap Hounds, faster attacks
## Phase changes at 66% / 33% HP (brief invulnerable roar that clears enemy bullets).

signal phase_changed(phase: int)
signal defeated

const CHASER := preload("res://enemies/chaser.tscn")
const TEX := preload("res://assets/hq/warden.png")
const SPRITE_SCALE := 0.56

@export var boss_name := "WARDEN"
@export var accent := Color(1.0, 0.25, 0.2)

var phase := 1
var _state := &"idle"
var _state_t := 1.5
var _step := 0
var _step_t := 0.0
var _charge_dir := Vector2.ZERO
var _roar := 0.0
var _turret := Vector2.DOWN
var _spin := 0.0
var _last_attack := &""
var _dying := 0.0


func _ready() -> void:
	super._ready()
	add_to_group("boss")


func _physics_process(delta: float) -> void:
	if _dying > 0.0:
		_dying -= delta
		_t += delta
		if Engine.get_physics_frames() % 6 == 0:
			Combat.explosion_fx(global_position + Vector2(randf_range(-70, 70), randf_range(-60, 60)), randf_range(50, 110),
				[Color(1, 0.5, 0.2), accent, Color(1, 0.85, 0.4)].pick_random())
		if _dying <= 0.0:
			Combat.explosion_fx(global_position, 320.0, Color(1.0, 0.7, 0.3))
			Sfx.play(&"big_explode", 0.0)
			Combat.shake(1.0)
			defeated.emit()
			died.emit(self)
			queue_free()
		queue_redraw()
		return
	super._physics_process(delta)


func knock(impulse: Vector2) -> void:
	_knock += impulse * 0.08


func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	if _roar > 0.0 or _dying > 0.0:
		return
	super.take_damage(amount, from_pos, source)
	var frac := hp / max_hp
	if phase == 1 and frac <= 0.66 or phase == 2 and frac <= 0.33:
		phase += 1
		_roar = 1.2
		_state = &"idle"
		_state_t = 1.4
		Combat.clear_enemy_bullets()
		Combat.shockwave(global_position, 300.0, accent, 0.6)
		Combat.shake(0.6)
		Sfx.play(&"alarm", -4.0, 0.0)
		phase_changed.emit(phase)


func die() -> void:
	if _dying > 0.0 or dead:
		return
	hp = 0.0
	dead = true
	_dying = 2.2
	Combat.clear_enemy_bullets()
	Combat.report_kill(self)
	collision_layer = 0
	$Hurtbox.collision_layer = 0


func _think(delta: float) -> void:
	var speed_mult := 1.0 + (phase - 1) * 0.25
	_turret = _turret.slerp(dir_to_target(), 1.0 - exp(-5.0 * delta))
	facing = _turret
	if _roar > 0.0:
		_roar -= delta
		return
	_state_t -= delta
	match _state:
		&"idle":
			var d := dist_to_target()
			if d > 330.0:
				steer_to(target.global_position, move_speed * speed_mult)
			elif d < 200.0:
				desired_velocity = -dir_to_target() * move_speed
			if _state_t <= 0.0:
				_pick_attack()
		&"fan":
			_step_t -= delta
			if _step_t <= 0.0 and _step > 0:
				_step -= 1
				_step_t = 0.28 / speed_mult
				var n := 9 + phase * 2
				for i in n:
					var a := lerpf(-0.75, 0.75, i / float(n - 1))
					shoot(_turret.rotated(a), 380.0 + phase * 30.0, 10.0, accent.lightened(0.2), 1.3)
				Sfx.play(&"enemy_shoot", -6.0)
			if _step <= 0:
				_end_attack()
		&"artillery":
			var count := 4 + phase
			for i in count:
				var off := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(90, 260)
				Combat.artillery(target.global_position + target.velocity * 0.5 + off, 80.0, 20.0 * damage_mult, self,
					1.0 + i * 0.12, "player", global_position + Vector2(0, -40))
			Sfx.play(&"missile", -2.0)
			_end_attack()
		&"spiral":
			desired_velocity = Vector2.ZERO
			_spin += delta * (2.6 + phase * 0.4)
			_step_t -= delta
			if _step_t <= 0.0:
				_step_t = 0.08
				for arm in phase:
					var a := _spin + arm * TAU / phase
					shoot(Vector2.from_angle(a), 300.0, 8.0, Color(1.0, 0.45, 0.8), 1.1)
			if _state_t <= 0.0:
				_end_attack()
		&"charge_windup":
			desired_velocity = Vector2.ZERO
			_charge_dir = dir_to_target()
			if _state_t <= 0.0:
				_state = &"charge"
				_state_t = 0.55
				Sfx.play(&"dash", -2.0)
		&"charge":
			desired_velocity = _charge_dir * 950.0
			velocity = desired_velocity
			if get_slide_collision_count() > 0 and _state_t < 0.45:
				Combat.shockwave(global_position, 160.0, Color(1, 0.8, 0.5), 0.35)
				Combat.shake(0.5)
				Sfx.play(&"slam", -2.0)
				_state = &"idle"
				_state_t = 1.0
			elif _state_t <= 0.0:
				_end_attack()
		&"ring":
			_step_t -= delta
			if _step_t <= 0.0 and _step > 0:
				_step -= 1
				_step_t = 0.35
				var n := 24
				for i in n:
					shoot(Vector2.from_angle(TAU * (i + 0.5 * (_step % 2)) / n), 260.0, 9.0, Color(1.0, 0.8, 0.3), 1.2)
				Sfx.play(&"enemy_shoot", -4.0)
			if _step <= 0:
				_end_attack()
		&"summon":
			for i in 2:
				var e: Enemy = CHASER.instantiate()
				e.position = position + Vector2.from_angle(randf() * TAU) * 110.0
				e.damage_mult = damage_mult
				get_parent().add_child(e)
			Sfx.play(&"alarm", -10.0, 0.0)
			_end_attack()


func _pick_attack() -> void:
	var options: Array[StringName] = [&"fan", &"artillery"]
	if phase >= 2:
		options.append_array([&"spiral", &"charge_windup"])
	if phase >= 3:
		options.append(&"ring")
		if get_tree().get_nodes_in_group("enemies").size() < 5:
			options.append(&"summon")
	options.erase(_last_attack)
	_state = options.pick_random()
	_last_attack = _state
	# Every attack starts squared up to the player.
	_turret = dir_to_target()
	match _state:
		&"fan":
			_step = 3
			_step_t = 0.3
		&"spiral":
			_state_t = 2.2
			_step_t = 0.0
		&"charge_windup":
			_state_t = 0.75
		&"ring":
			_step = 3
			_step_t = 0.2


func _end_attack() -> void:
	_state = &"idle"
	_state_t = randf_range(0.9, 1.5) / (1.0 + (phase - 1) * 0.3)


func _draw() -> void:
	var shake := Vector2(randf_range(-4, 4), randf_range(-4, 4)) if _roar > 0.0 or _dying > 0.0 else Vector2.ZERO
	# HQ sprite: the whole walker turns to face its target (art faces up), with a heavy stomping bob.
	var rot := _turret.angle() + PI / 2
	var stomp := absf(sin(_t * 6.0)) * 0.025 if velocity.length() > 20.0 else 0.0
	var s := Vector2.ONE * (SPRITE_SCALE + stomp)
	var half := TEX.get_size() / 2
	# Red is the art's native accent; other accents (Mk-II) tint the whole machine.
	var body_tint := Color.WHITE if accent.r > 0.9 and accent.g < 0.4 else Color.WHITE.lerp(accent, 0.45)
	draw_set_transform(shake + Vector2(10, 16), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.45))
	draw_set_transform(shake, rot, s)
	draw_texture(TEX, -half, tint(body_tint))
	draw_set_transform(shake)
	# Reactor core glow (pulses faster each phase).
	var pulse := 0.5 + 0.5 * sin(_t * (3.0 + phase * 2.5))
	draw_circle(Vector2.ZERO, 26 + pulse * 10, Color(accent, 0.18 + 0.12 * pulse))
	draw_circle(Vector2.ZERO, 9 + pulse * 3, Color(accent.lightened(0.5), 0.55))
	draw_set_transform(Vector2.ZERO)
	if _state == &"charge_windup":
		draw_line(Vector2.ZERO, _charge_dir * 600.0, Color(1.0, 0.15, 0.1, 0.25 + 0.3 * sin(_t * 30.0)), 40.0)
		draw_line(Vector2.ZERO, _charge_dir * 600.0, Color(1.0, 0.3, 0.2, 0.9), 2.0)
