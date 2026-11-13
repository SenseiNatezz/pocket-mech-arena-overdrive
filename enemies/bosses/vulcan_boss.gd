class_name VulcanBoss
extends WardenBoss
## "VULCAN, the Forge Titan" (Higgsfield sprite): boss of the Volcanic Forge (level 6). A colossal forge
## machine with a hammer arm, a magma-cannon arm and a furnace core.
##   Phase 1  hammer leap-slam (red landing circle -> shockwave + ring of fire bolts), magma lob (globs
##            onto red circles around you, each leaves a LavaPool), magma cannon volleys
##   Phase 2  + eruption (lava geysers burst out of the floor in a spreading pattern), summons Magma
##            Crawlers, slams fire two rings
##   Phase 3  + CORE BEAMS: the furnace charges (heat pulled into the core, danger lanes show where the
##            beams will start), then blasts three fire beams that sweep around it (fx/fire_beam.gdshader:
##            white-hot core, turbulent flame body, speed lines, pressure rings), with a release flash +
##            shockwave, floor light, and fire bursts + burning scorch marks where they hit walls or cover.
##            Walls and solid cover stop the beams (and their damage). The open core takes +50% damage.
##            Slams leave lava behind; Anvils join the summons.
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
const FIRE_BEAM := preload("res://fx/fire_beam.gdshader")
const FIRE_BEAM_UNDER := preload("res://fx/fire_beam_under.gdshader")
const GLOW := preload("res://assets/fx/glow.tres")
## Furnace core, in the sprite's own frame (art faces up).
const CORE := Vector2(0, 36)
## Drawn radius of a core beam (its quad is 1.8x this each side, for the flames).
const BEAM_RADIUS := 36.0
## Half-width of a core beam that hurts (plus the target's own hit radius).
const BEAM_HIT := 16.0
## Where the drawn beam starts, out from the core (it starts under the body; the core blaze covers the join).
const BEAM_START := 40.0
## Seconds for a blast to shoot out to full length, and to thin out at the end.
const BEAM_SHOOT := 0.16
const BEAM_FADE := 0.35

var _land := Vector2.ZERO
var _from := Vector2.ZERO
var _beam_a := 0.0
var _beam_tick := 0.0
var _core_open := 0.0
## Per beam: its length from the core (px) and whether it ends on a wall / cover.
var _beam_len: Array[float] = [BEAM_REACH, BEAM_REACH, BEAM_REACH]
var _beam_wall: Array[bool] = [false, false, false]
var _beam_fired := false
var _beam_fx_t := 0.0
var _beam_fx_n := 0
var _beam_drawn := false
## Beam layers, in draw order: floor light (additive, behind the body); per beam a dark smoke band
## (fx/fire_beam_under.gdshader) then the blast itself (fx/fire_beam.gdshader, additive), both behind the
## body - _beam_nodes / _beam_mats hold the 3 smoke bands then the 3 blasts; and the core blaze / charge
## streaks over the body (additive).
var _beam_glow: Node2D
var _beam_nodes: Array[Node2D] = []
var _beam_mats: Array[ShaderMaterial] = []
var _beam_top: Node2D


func _ready() -> void:
	super._ready()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam_glow = Node2D.new()
	_beam_glow.show_behind_parent = true
	_beam_glow.material = add
	_beam_glow.draw.connect(_draw_beam_glow)
	add_child(_beam_glow)
	for j in 6:
		var n := Node2D.new()
		n.show_behind_parent = true
		var m := ShaderMaterial.new()
		m.shader = FIRE_BEAM_UNDER if j < 3 else FIRE_BEAM
		m.set_shader_parameter("seed", 3.1 + (j % 3) * 13.7)
		n.material = m
		n.draw.connect(_draw_beam.bind(j))
		add_child(n)
		_beam_nodes.append(n)
		_beam_mats.append(m)
	_beam_top = Node2D.new()
	_beam_top.material = add
	_beam_top.draw.connect(_draw_beam_top)
	add_child(_beam_top)


func _process(_delta: float) -> void:
	var live := _beams_live()
	if live or _beam_drawn:
		_beam_drawn = live
		_beam_glow.queue_redraw()
		_beam_top.queue_redraw()
		for n in _beam_nodes:
			n.queue_redraw()


func _beams_live() -> bool:
	return _state == &"beams" and _dying <= 0.0 and not dead


## The furnace core, in this node's local space.
func _core_local() -> Vector2:
	return CORE.rotated(_turret.angle() + PI / 2)


func _beam_dir(i: int) -> Vector2:
	return Vector2.from_angle(_beam_a + TAU * i / 3.0)


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
				if not _beam_fired:
					_beam_fired = true
					_release_blast()
				_beam_a += delta * (0.85 + 0.15 * phase)
				_trace_beams()
				_beam_impacts(delta)
				_beam_tick -= delta
				if _beam_tick <= 0.0 and _player_in_beam():
					_beam_tick = 0.4
					target.take_damage(14.0 * damage_mult, global_position, self)
					Combat.spark(target.global_position, FIRE_HOT, 1.2)
			else:
				_trace_beams()
			if _state_t <= 0.0:
				_end_attack()


func _player_in_beam() -> bool:
	var core := global_position + _core_local()
	var off := target.global_position - core
	var d := off.length()
	if d < 1.0:
		return false
	var hr: float = target.get("hit_radius") if target.get("hit_radius") != null else 20.0
	var reach := clampf((BEAM_TIME - _state_t) / BEAM_SHOOT, 0.0, 1.0)
	for i in 3:
		if d > _beam_len[i] * reach + hr:
			continue
		if absf(angle_difference(off.angle(), _beam_a + TAU * i / 3.0)) * d < BEAM_HIT + hr:
			return true
	return false


## Each beam runs from the core until the first wall (layer 1) or solid cover (layer 6), up to BEAM_REACH.
func _trace_beams() -> void:
	var space := get_world_2d().direct_space_state
	var core := global_position + _core_local()
	for i in 3:
		var dir := _beam_dir(i)
		var q := PhysicsRayQueryParameters2D.create(core + dir * BEAM_START, core + dir * BEAM_REACH, 1 | 32)
		var hit := space.intersect_ray(q)
		_beam_wall[i] = not hit.is_empty()
		_beam_len[i] = core.distance_to(hit.position) if _beam_wall[i] else BEAM_REACH


## The moment the furnace lets go: a white flash and shockwave off the core, a shake, a deep boom.
func _release_blast() -> void:
	var core := global_position + _core_local()
	Combat.shockwave(core, 340.0, FIRE_HOT, 0.45)
	Combat.shockwave(core, 170.0, Color(1, 1, 1, 0.9), 0.22)
	Combat.shake(0.7)
	Combat.rumble(0.4, 0.8, 0.4)
	Sfx.play(&"big_explode", -7.0)
	Sfx.play(&"laser", -3.0, 0.0)
	for i in 3:
		Combat.burst(core + _beam_dir(i) * 70.0, FIRE_HOT, 460.0, 1.5)


## While the beams burn: fire bursts, sparks and burning scorch marks where they hit, embers along them.
func _beam_impacts(delta: float) -> void:
	_beam_fx_t -= delta
	if _beam_fx_t > 0.0:
		return
	_beam_fx_t = 0.06
	_beam_fx_n += 1
	var core := global_position + _core_local()
	for i in 3:
		var dir := _beam_dir(i)
		var end := core + dir * _beam_len[i]
		if _beam_wall[i]:
			Combat.spark(end - dir * 8.0, FIRE_HOT, 2.4)
			if _beam_fx_n % 2 == i % 2:
				Combat.burst(end - dir * 12.0, FIRE, 380.0, 1.4)
			if _beam_fx_n % 4 == i:
				BlastFx.fireball(end - dir * 18.0 + dir.orthogonal() * randf_range(-16.0, 16.0), randf_range(34.0, 48.0))
			if _beam_fx_n % 3 == i:
				BlastFx.scorch(end - dir * 26.0, 32.0, _beam_fx_n % 6 == i)
			if _beam_fx_n % 9 == i * 3:
				BlastFx.smoke(end - dir * 30.0, 26.0, 1)
		else:
			Combat.spark(end - dir * randf_range(30.0, 90.0), FIRE, 1.3)
		Combat.spark(core + dir * randf_range(BEAM_START + 60.0, maxf(_beam_len[i] - 40.0, BEAM_START + 80.0)),
			FIRE_HOT, randf_range(0.6, 1.0))


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
	if phase >= 4:  # OVERDRIVE (WardenBoss): the core beams come round even more often
		options.append(&"beams")
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
			_beam_fired = false
			_beam_fx_t = 0.0
			_trace_beams()
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
	# Core beams, while the furnace charges: danger lanes where the three beams will start (the beams
	# themselves are the child layers, see _draw_beam*).
	if _beams_live() and _state_t > BEAM_TIME:
		var k := clampf(1.0 - (_state_t - BEAM_TIME) / BEAM_WARN, 0.0, 1.0)
		var core := _core_local()
		for i in 3:
			var dir := _beam_dir(i)
			DangerLane.draw(self, core + dir * 90.0, core + dir * _beam_len[i], BEAM_HIT + 12.0, k, _t,
				Color(1.0, 0.32, 0.12))
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
	note_body(VULCAN_TEX, shake + Vector2(0, -60.0 * lift), rot, s, tint(Color.WHITE))
	draw_set_transform(shake + Vector2(0, -60.0 * lift))
	# Furnace core: pulses faster each phase; blazes open during the beams.
	var pulse := 0.5 + 0.5 * sin(_t * (3.0 + phase * 2.0))
	var core := Vector2(0, 36).rotated(rot)
	draw_circle(core, 36.0 + 12.0 * pulse + 31.0 * _core_open, Color(FIRE, 0.16 + 0.1 * pulse + 0.25 * _core_open))
	draw_circle(core, 12.0 + 5.0 * pulse + 12.0 * _core_open, Color(FIRE_HOT, 0.5 + 0.4 * _core_open))
	draw_set_transform(Vector2.ZERO)


## Seconds since the beams fired (negative while charging), and how far the charge is (0..1).
func _beam_fire_t() -> float:
	return BEAM_TIME - _state_t


func _beam_charge() -> float:
	return clampf(1.0 - (_state_t - BEAM_TIME) / BEAM_WARN, 0.0, 1.0)


## How strong the blast is right now: 1 while it burns, fading in its last instant.
func _beam_strength() -> float:
	return 1.0 - smoothstep(BEAM_TIME - 0.08, BEAM_TIME, _beam_fire_t())


## One beam layer `j` (0-2 smoke bands, 3-5 blasts), a textured rect so the shader gets UVs running
## core -> end and across.
func _draw_beam(j: int) -> void:
	if not _beams_live() or _beam_fire_t() < 0.0:
		return
	var i := j % 3
	var fe := _beam_fire_t()
	var node := _beam_nodes[j]
	var mat := _beam_mats[j]
	var dir := _beam_dir(i)
	var length := _beam_len[i] - BEAM_START + (14.0 if _beam_wall[i] else 0.0)
	var h := BEAM_RADIUS * 1.8 * 2.0
	mat.set_shader_parameter("length_px", length)
	mat.set_shader_parameter("t", _t)
	mat.set_shader_parameter("reach", clampf(fe / BEAM_SHOOT, 0.0, 1.0))
	mat.set_shader_parameter("flare", 1.0 - smoothstep(0.0, 0.3, fe))
	mat.set_shader_parameter("thin", 1.0 - 0.9 * smoothstep(BEAM_TIME - BEAM_FADE, BEAM_TIME, fe))
	mat.set_shader_parameter("intensity", _beam_strength())
	node.draw_set_transform(_core_local() + dir * BEAM_START, dir.angle())
	node.draw_texture_rect(BeamCannon.white_tex(), Rect2(0, -h / 2.0, length, h), false)
	node.draw_set_transform(Vector2.ZERO)


## Floor light under the beams and the boss (behind the body, additive).
func _draw_beam_glow() -> void:
	if not _beams_live():
		return
	var core := _core_local()
	var fe := _beam_fire_t()
	if fe < 0.0:
		var k := _beam_charge()
		_beam_glow.draw_texture_rect(GLOW, Rect2(core - Vector2.ONE * (110.0 + 120.0 * k), Vector2.ONE * (220.0 + 240.0 * k)),
			false, Color(FIRE, 0.12 + 0.3 * k * k))
		return
	var a := _beam_strength() * (1.0 - 0.6 * smoothstep(BEAM_TIME - BEAM_FADE, BEAM_TIME, fe))
	var flick := 0.9 + 0.1 * sin(_t * 47.0)
	var reach := clampf(fe / BEAM_SHOOT, 0.0, 1.0)
	_beam_glow.draw_texture_rect(GLOW, Rect2(core - Vector2.ONE * 260.0, Vector2.ONE * 520.0), false, Color(FIRE, 0.45 * a * flick))
	for i in 3:
		var dir := _beam_dir(i)
		var length := _beam_len[i] * reach
		# A long soft ellipse of light along the beam: it lights the floor either side.
		_beam_glow.draw_set_transform(core + dir * length * 0.5, dir.angle())
		_beam_glow.draw_texture_rect(GLOW, Rect2(-length * 0.6, -95.0, length * 1.2, 190.0), false, Color(FIRE, 0.42 * a * flick))
		_beam_glow.draw_set_transform(Vector2.ZERO)
		if _beam_wall[i] and reach >= 1.0:
			var end := core + dir * _beam_len[i]
			var boil := 0.85 + 0.15 * sin(_t * 61.0 + i * 2.0)
			_beam_glow.draw_texture_rect(GLOW, Rect2(end - Vector2.ONE * 120.0 * boil, Vector2.ONE * 240.0 * boil), false,
				Color(FIRE, 0.6 * a))


## Over the body (additive): heat pulled into the core while it charges; then the core blaze, the beams
## leaving it, the release flash, and the fireballs boiling where the beams hit walls.
func _draw_beam_top() -> void:
	if not _beams_live():
		return
	var core := _core_local()
	var fe := _beam_fire_t()
	if fe < 0.0:
		var k := _beam_charge()
		# Streaks of heat rushing into the core, faster and brighter as the charge builds.
		for j in 18:
			var ph := fmod(_t * (1.3 + 1.6 * k) + j * 0.389, 1.0)
			var d := Vector2.from_angle(j * 2.39996 + 0.7)
			var r := lerpf(190.0, 26.0, ph)
			var p := core + d * r
			_beam_top.draw_line(p, p - d * (10.0 + 26.0 * k), Color(FIRE_HOT, (0.25 + 0.65 * k) * sin(ph * PI)), 2.5, true)
		for j in 2:
			var ph := fmod(_t * 1.8 + j * 0.5, 1.0)
			_beam_top.draw_arc(core, lerpf(170.0, 34.0, ph), 0.0, TAU, 40, Color(FIRE, (0.2 + 0.5 * k) * ph), 3.0, true)
		var s := 40.0 + 70.0 * k * k
		_beam_top.draw_texture_rect(GLOW, Rect2(core - Vector2.ONE * s, Vector2.ONE * s * 2.0), false,
			Color(FIRE_HOT, 0.35 + 0.55 * k))
		_beam_top.draw_circle(core, 6.0 + 12.0 * k * (0.85 + 0.15 * sin(_t * 70.0)), Color(1, 1, 1, 0.5 + 0.5 * k))
		return
	var a := _beam_strength()
	var thin := 1.0 - 0.85 * smoothstep(BEAM_TIME - BEAM_FADE, BEAM_TIME, fe)
	var flick := 0.85 + 0.15 * sin(_t * 73.0)
	# The release flash.
	var flash := 1.0 - smoothstep(0.0, 0.28, fe)
	if flash > 0.0:
		_beam_top.draw_texture_rect(GLOW, Rect2(core - Vector2.ONE * 300.0, Vector2.ONE * 600.0), false, Color(1, 0.95, 0.8, 0.9 * flash))
	# The core blaze, and each beam leaving it (a stretched flare running out over the body).
	_beam_top.draw_texture_rect(GLOW, Rect2(core - Vector2.ONE * 110.0 * flick, Vector2.ONE * 220.0 * flick), false,
		Color(FIRE_HOT, 0.75 * a))
	for i in 3:
		var dir := _beam_dir(i)
		_beam_top.draw_set_transform(core + dir * 62.0, dir.angle())
		_beam_top.draw_texture_rect(GLOW, Rect2(-78.0, -30.0 * thin, 156.0, 60.0 * thin), false, Color(1.0, 0.9, 0.6, 0.85 * a))
		_beam_top.draw_set_transform(Vector2.ZERO)
		if _beam_wall[i] and fe >= BEAM_SHOOT:
			var end := core + dir * _beam_len[i]
			var boil := 0.8 + 0.2 * sin(_t * 53.0 + i * 1.7)
			_beam_top.draw_texture_rect(GLOW, Rect2(end - Vector2.ONE * 70.0 * boil, Vector2.ONE * 140.0 * boil), false,
				Color(FIRE_HOT, 0.85 * a))
			_beam_top.draw_circle(end - dir * 6.0, (12.0 + 6.0 * boil) * thin, Color(1, 1, 1, 0.8 * a))
	_beam_top.draw_circle(core, (16.0 + 4.0 * flick) * thin, Color(1, 1, 1, 0.9 * a))
