class_name RivalMech
extends Enemy
## RIVAL PILOTS: another pilot in one of the Hangar's mechs (Game.CHASSIS), drawn with that mech's own
## two-layer art (legs + upper body with its Beam Rifle, like the player). Each Campaign arena sends its own
## rival in the middle wave (Game.ARENA_RIVALS, ScenicArena._maybe_rival) and Endless sends a random one
## every RIVAL_ENDLESS_EVERY waves; the wave waits until it's beaten. It fights like a pilot:
##   - keeps its favourite range from you and circles (switching sides now and then),
##   - fires 3-shot bursts of red beam darts, leading your movement a little,
##   - BOOST-DODGES sideways when your hits land (on a cooldown),
##   - and uses its mech's SIGNATURE move every few seconds (SPECIAL, telegraphed):
##       NIMBUS-07  FAN BURST    a 5-way spread
##       GRIFFIN    AFTERBURNER  a straight dash through you (danger lane first)
##       TUSKER     SIEGE MODE   plants, takes half damage, and lobs 3 shells where you stand
##       TEMPEST    SALVO        4 homing rockets off the shoulders
##       FROSTBLADE IAIDO        closes in fast and cuts a frost arc in front of it
##       SOLSTICE   SUN BARRIER  a shield that soaks 75% for 3 s, then bursts into a ring of shots
##       AURORA     PETAL SWARM  6 pink petal blades that curve in
##       RAVEN CLAW BLINK        vanishes and reappears behind you, firing (always hovers)
## Beating it pays a scrap bounty, more the first time, and that mech then costs 25% less in the Hangar
## (Game.rival_beaten). A scripted wipe (a boss going down) just ends it with no reward.
## A red ring under it, "RIVAL" + its name over its health bar (always shown) tell it apart from you.

const RED := Color(1.0, 0.28, 0.25)
const SPRITE_SCALE := 0.44  # (the player mech's sprite scale, player/mech.tscn)
const BASE_HP := 700.0
const SHOT_SPEED := 640.0
const SHOT_DAMAGE := 8.0
const DODGE_SPEED := 760.0
const DODGE_TIME := 0.22
const DODGE_CD := 2.4
## Per chassis: [preferred range px, special cooldown s, signature name]
const STYLE := {
	&"standard": [320.0, 6.0, "FAN BURST"], &"striker": [270.0, 6.5, "AFTERBURNER"],
	&"bulwark": [360.0, 8.0, "SIEGE MODE"], &"artillery": [420.0, 7.0, "SALVO"],
	&"duelist": [190.0, 6.0, "IAIDO"], &"guardian": [330.0, 9.0, "SUN BARRIER"],
	&"carrier": [360.0, 7.0, "PETAL SWARM"], &"phantom": [300.0, 6.5, "BLINK"],
}

## Set before it enters the tree. `practice` = a Weapon Range sparring partner: no bounty, no discount.
var chassis_id := &"standard"
var practice := false
var info: Dictionary = {}
var _legs: AnimatedSprite2D
var _torso: AnimatedSprite2D
var _fx: Node2D
var _hip := Vector2.ZERO
var _hover := false
var _aim := Vector2.DOWN
var _orbit := 1.0
var _orbit_t := 3.0
var _burst_left := 0
var _burst_t := 0.0
var _fire_cd := 1.6
var _dodge_cd := 1.0
var _dash_t := 0.0
var _dash_dir := Vector2.ZERO
var _dash_speed := 0.0
var _dash_hit := false
var _special_cd := 4.0
var _state := &"fight"
var _state_t := 0.0
var _lane_end := Vector2.ZERO
var _slash_t := 0.0
var _slash_dir := Vector2.DOWN
var _range := 320.0
var _shot_t := 0.0


func _init() -> void:
	max_hp = BASE_HP
	move_speed = 170.0
	acceleration = 1300.0
	contact_damage = 0.0
	hit_radius = 30.0


func _ready() -> void:
	info = Game.chassis_info(chassis_id)
	var s := float(info.get("scale", 1.0))
	hit_radius = 30.0 * s
	max_hp *= float(info.get("hp", 1.0))
	move_speed *= float(info.get("speed", 1.0))
	var st: Array = STYLE.get(chassis_id, STYLE[&"standard"])
	_range = float(st[0])
	_special_cd = randf_range(2.5, 4.0)
	_hover = Game.WALK_HOVERS.has(String(info.get("sheet", "")))
	super._ready()
	add_to_group("rivals")
	_spawn_t = 0.6
	_build_sprites(s)
	_fx = Node2D.new()
	_fx.z_index = 1
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_orbit = 1.0 if randf() < 0.5 else -1.0
	Combat.shockwave(global_position, 90.0, RED, 0.5)
	Sfx.play(&"boost", -4.0, 0.0)


## The chassis' own walking art (its hover art for RAVEN CLAW), whatever the player's WALK / FLY setting.
func _build_sprites(s: float) -> void:
	var was := Game.hover_mode
	Game.hover_mode = false
	var art := Game.chassis_walk_art(chassis_id)
	var torso_frames: SpriteFrames = Game.chassis_torso_frames(chassis_id, true) if art != "" else Game.chassis_frames(chassis_id, true)
	var legs_frames: SpriteFrames = Game.chassis_legs_frames(chassis_id) if art != "" else null
	Game.hover_mode = was
	var tint := Game.chassis_tint(chassis_id) * Color(0.95, 0.86, 0.86)  # a touch darker / redder than yours
	if legs_frames:
		_legs = AnimatedSprite2D.new()
		_legs.sprite_frames = legs_frames
		_legs.scale = Vector2.ONE * SPRITE_SCALE * s
		_legs.modulate = tint
		_legs.play(&"stand")
		add_child(_legs)
		_hip = Game.WALK_HIP * SPRITE_SCALE * s
	_torso = AnimatedSprite2D.new()
	_torso.sprite_frames = torso_frames
	_torso.scale = Vector2.ONE * SPRITE_SCALE * s
	_torso.modulate = tint
	_torso.play(&"idle")
	add_child(_torso)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	_animate(delta)
	_fx.queue_redraw()


# --- brain -----------------------------------------------------------------------------------------------

func _think(delta: float) -> void:
	_dodge_cd -= delta
	_fire_cd -= delta
	_special_cd -= delta
	_orbit_t -= delta
	_slash_t -= delta
	var to := target.global_position - global_position
	var want_aim := to.normalized()
	if _state == &"fight" or _state == &"siege":
		# Lead a moving pilot a little.
		var lead := target.global_position + target.velocity * clampf(to.length() / SHOT_SPEED, 0.0, 0.6) * 0.6
		want_aim = (lead - global_position).normalized()
	_aim = _aim.slerp(want_aim, 1.0 - exp(-9.0 * delta)).normalized()
	facing = _aim
	# A boost dash / dodge in progress overrides everything.
	if _dash_t > 0.0:
		_dash_t -= delta
		desired_velocity = _dash_dir * _dash_speed
		velocity = desired_velocity
		if _state == &"dash" and not _dash_hit and global_position.distance_to(target.global_position) < hit_radius + 34.0:
			_dash_hit = true
			target.take_damage(18.0 * damage_mult, global_position, self)
			Combat.shockwave(target.global_position, 70.0, Color(1.0, 0.5, 0.3), 0.3)
		if _dash_t <= 0.0:
			_dash_end()
		return
	match _state:
		&"fight":
			_fight(delta, to)
		&"windup":
			_state_t -= delta
			desired_velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_release()
		&"siege":
			_state_t -= delta
			desired_velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_state = &"fight"
		&"barrier":
			_state_t -= delta
			_fight(delta, to)
			if _state_t <= 0.0:
				_sun_burst()
				_state = &"fight"
		&"blink":
			_state_t -= delta
			desired_velocity = Vector2.ZERO
			if _state_t <= 0.0:
				_blink_arrive()


func _fight(delta: float, to: Vector2) -> void:
	# Circle at its favourite range, switching sides now and then.
	if _orbit_t <= 0.0:
		_orbit_t = randf_range(2.5, 4.5)
		_orbit = -_orbit
	var dist := to.length()
	var away := -to.normalized()
	var spot := target.global_position + away.rotated(_orbit * 0.55) * _range
	steer_to(spot, move_speed * (1.0 if absf(dist - _range) > 60.0 else 0.7))
	# Bursts of three.
	if _burst_left > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = 0.12
			_burst_left -= 1
			_fire_dart(_aim)
	elif _fire_cd <= 0.0 and dist < 760.0 and has_line_of_sight(target.global_position):
		_fire_cd = randf_range(1.5, 2.2)
		_burst_left = 3
		_burst_t = 0.0
	# Signature move.
	if _special_cd <= 0.0 and _state == &"fight" and dist < 720.0:
		_special_cd = float((STYLE.get(chassis_id, STYLE[&"standard"]) as Array)[1]) * randf_range(0.9, 1.15)
		_begin_special()


## A red beam dart from the rifle.
func _fire_dart(dir: Vector2, speed := SHOT_SPEED, dmg := SHOT_DAMAGE, col := RED) -> Bullet:
	var muzzle := global_position + dir * (hit_radius + 14.0) + dir.orthogonal() * 9.0
	var b := Combat.fire(muzzle, dir * speed, dmg * damage_mult, false, self, col, 1.1, 2.2)
	b._color = col
	b.set_dart_style()
	_shot_t = 0.15
	Sfx.play(&"enemy_shoot", -8.0, 0.15)
	return b


# --- signature moves -------------------------------------------------------------------------------------

func _begin_special() -> void:
	match chassis_id:
		&"striker", &"duelist":
			# Telegraphed dash: a danger lane first.
			_state = &"windup"
			_state_t = 0.6 if chassis_id == &"striker" else 0.45
			var d := global_position.distance_to(target.global_position)
			var reach := d + 120.0 if chassis_id == &"striker" else maxf(d - 70.0, 40.0)
			_lane_end = global_position + _aim * reach
			Sfx.play(&"alarm", -10.0, 0.1)
		&"bulwark":
			_state = &"siege"
			_state_t = 2.6
			Sfx.play(&"shield", -6.0, 0.0)
			for i in 3:
				var p := target.global_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 70.0) * float(i)
				get_tree().create_timer(0.35 + i * 0.5, false).timeout.connect(func() -> void:
					if not dead:
						Combat.artillery(p, 72.0, 16.0 * damage_mult, self, 1.0, "player", global_position))
		&"artillery":
			for i in 4:
				get_tree().create_timer(i * 0.14, false).timeout.connect(func() -> void:
					if dead:
						return
					var side := 1.0 if i % 2 == 0 else -1.0
					var dir := _aim.rotated(side * deg_to_rad(28.0 + 10.0 * i))
					var b := _fire_dart(dir, 300.0, 11.0, Color(1.0, 0.6, 0.2))
					b.homing = 2.2
					b._life = 3.2
					b.scale = Vector2.ONE * 1.35)
			Sfx.play(&"missile", -4.0, 0.0)
		&"guardian":
			_state = &"barrier"
			_state_t = 3.0
			Sfx.play(&"shield", -3.0, 0.0)
			Combat.shockwave(global_position, 110.0, Color(1.0, 0.85, 0.35), 0.45)
		&"carrier":
			for i in 6:
				var dir := Vector2.from_angle(_aim.angle() + TAU * i / 6.0)
				var b := _fire_dart(dir, 260.0, 7.0, Color(1.0, 0.5, 0.85))
				b.homing = 1.7
				b._life = 3.0
			Sfx.play(&"scatter", -6.0, 0.0)
		&"phantom":
			_state = &"blink"
			_state_t = 0.4
			Combat.shockwave(global_position, 80.0, Color(1.0, 0.2, 0.3), 0.3)
			Sfx.play(&"boost", -6.0, 0.0)
		_:
			for i in 5:
				_fire_dart(_aim.rotated(deg_to_rad(-24.0 + 12.0 * i)))


## End of a dash wind-up: go.
func _release() -> void:
	var to := _lane_end - global_position
	_dash_dir = to.normalized()
	_dash_speed = 1000.0
	_dash_t = to.length() / _dash_speed
	_dash_hit = false
	_state = &"dash"
	Sfx.play(&"dash", -3.0, 0.0)
	Combat.burst(global_position, Color(1.0, 0.55, 0.3), 260.0, 0.9)


func _dash_end() -> void:
	if _state == &"dash" and chassis_id == &"duelist":
		# IAIDO: the frost cut at the end of the dash.
		_slash_dir = _aim
		_slash_t = 0.3
		Combat.area_damage(global_position + _aim * 40.0, 120.0, 20.0 * damage_mult, self, true, _aim, deg_to_rad(70.0), 380.0)
		Combat.shockwave(global_position + _aim * 50.0, 90.0, Color(0.55, 0.9, 1.0), 0.3)
		Sfx.play(&"saber", -4.0, 0.0)
	_state = &"fight"


func _sun_burst() -> void:
	for i in 12:
		_fire_dart(Vector2.from_angle(TAU * i / 12.0 + _t), 420.0, 7.0, Color(1.0, 0.8, 0.3))
	Combat.shockwave(global_position, 140.0, Color(1.0, 0.85, 0.35), 0.4)


## BLINK: reappears behind the pilot (an open spot it can see), then fires at once.
func _blink_arrive() -> void:
	var back := -target.velocity.normalized() if target.velocity.length() > 40.0 else -_aim
	var spot := global_position
	for i in 8:
		var p := target.global_position + back.rotated(randf_range(-0.9, 0.9)) * randf_range(150.0, 210.0)
		var arena := get_tree().get_first_node_in_group("arena")
		if arena and arena.has_method("is_open") and not arena.is_open(p, 40.0):
			continue
		spot = p
		break
	Combat.shockwave(global_position, 60.0, Color(1.0, 0.2, 0.3), 0.25)
	global_position = spot
	velocity = Vector2.ZERO
	_aim = (target.global_position - global_position).normalized()
	Combat.shockwave(global_position, 90.0, Color(1.0, 0.2, 0.3), 0.3)
	_state = &"fight"
	_burst_left = 3
	_burst_t = 0.1


# --- damage ------------------------------------------------------------------------------------------------

func take_damage(amount: float, from_pos: Vector2, source: Node = null) -> void:
	if dead:
		return
	if _state == &"barrier":
		amount *= 0.25
		Combat.spark(global_position + (from_pos - global_position).normalized() * hit_radius * 1.3, Color(1.0, 0.85, 0.35), 0.7)
	elif _state == &"siege":
		amount *= 0.5
	super.take_damage(amount, from_pos, source)
	# A pilot under fire boosts out of it (sideways to the shots), on a cooldown.
	if not dead and _dodge_cd <= 0.0 and _dash_t <= 0.0 and _state == &"fight" and randf() < 0.45:
		_dodge_cd = DODGE_CD / sqrt(Game.diff("speed"))
		var across := (global_position - from_pos).normalized().orthogonal()
		_dash_dir = across * (1.0 if randf() < 0.5 else -1.0)
		_dash_speed = DODGE_SPEED
		_dash_t = DODGE_TIME
		_state = &"dodge"
		Combat.burst(global_position, Color(1.0, 0.5, 0.3), 180.0, 0.6)


func die() -> void:
	if dead:
		return
	if hp <= 0.0 and not practice:
		# Shot down: the bounty sprays out as scrap chips (Game.rival_beaten files it and remembers the win).
		var got := Game.rival_beaten(chassis_id)
		if got > 0.0:
			Game.drop_scrap(global_position, got, 16)
		Combat.explosion_fx(global_position, hit_radius * 5.0, Color(1.0, 0.45, 0.2))
		Combat.shake(0.5)
		Combat.hitstop(0.09)
	super.die()


func _has_ground_shadow() -> bool:
	return not _hover


# --- looks -------------------------------------------------------------------------------------------------

func _animate(delta: float) -> void:
	var moving := velocity.length() > 30.0
	_torso.rotation = _aim.angle() + PI / 2
	if _legs:
		var anim := &"stand"
		var want := _legs.rotation
		if _dash_t > 0.0:
			anim = &"slide"
			want = _dash_dir.angle() + PI / 2
		elif moving and not _hover:
			anim = &"walk"
			want = velocity.angle() + PI / 2
			if absf(angle_difference(want, _torso.rotation)) > deg_to_rad(110.0):
				want += PI  # (steps backwards rather than twisting all the way round)
			_legs.speed_scale = clampf(velocity.length() / maxf(move_speed, 1.0), 0.5, 1.2)
		elif _hover:
			want = _torso.rotation
		_legs.rotation = lerp_angle(_legs.rotation, want, 1.0 - exp(-12.0 * delta))
		if _legs.animation != anim:
			_legs.play(anim)
		_legs.position = _hip.rotated(_torso.rotation) - _hip.rotated(_legs.rotation)
		if _hover:
			_torso.position.y = sin(_t * 2.4) * 2.0
	var tanim := &"aim" if _shot_t > 0.0 or _burst_left > 0 else (&"walk" if moving and _legs and not _hover and _dash_t <= 0.0 else &"idle")
	_shot_t -= delta
	if not _torso.sprite_frames.has_animation(tanim):
		tanim = &"idle"
	if _torso.animation != tanim:
		_torso.play(tanim)
	if tanim == &"walk" and _legs and _legs.animation == &"walk":
		_torso.set_frame_and_progress(_legs.frame, _legs.frame_progress)
	var flash := Color(1, 1, 1).lerp(Color(2.0, 2.0, 2.0), _flash * 0.6)
	_torso.self_modulate = flash
	if _legs:
		_legs.self_modulate = flash
	if _state == &"blink":
		var a := clampf(_state_t / 0.4, 0.0, 1.0)
		_torso.modulate.a = a
		if _legs:
			_legs.modulate.a = a
	elif _torso.modulate.a < 1.0:
		_torso.modulate.a = 1.0
		if _legs:
			_legs.modulate.a = 1.0


## Under the sprites: the red rival ring, and the dash wind-up's danger lane.
func _draw() -> void:
	var r := hit_radius * 1.55
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(Vector2.ZERO, r, Color(RED, 0.08 + 0.05 * pulse))
	for i in 8:
		var a0 := _t * 0.8 + TAU * i / 8.0
		draw_arc(Vector2.ZERO, r, a0, a0 + TAU / 16.0, 6, Color(RED, 0.75), 2.5, true)
	if _state == &"windup":
		var k := 1.0 - clampf(_state_t / (0.6 if chassis_id == &"striker" else 0.45), 0.0, 1.0)
		DangerLane.draw(self, _aim * hit_radius, _lane_end - global_position, hit_radius * 0.9, k, _t,
			Color(0.55, 0.9, 1.0) if chassis_id == &"duelist" else Color(1.0, 0.45, 0.25))


## Over the sprites: shields, the frost cut, the name tag and the health bar.
func _draw_fx() -> void:
	var ci := _fx
	if _state == &"barrier":
		var k := clampf(_state_t / 3.0, 0.0, 1.0)
		ci.draw_circle(Vector2.ZERO, hit_radius * 1.9, Color(1.0, 0.85, 0.35, 0.12 + 0.06 * sin(_t * 12.0)))
		ci.draw_arc(Vector2.ZERO, hit_radius * 1.9, 0.0, TAU, 40, Color(1.0, 0.9, 0.5, 0.8), 3.0, true)
		ci.draw_arc(Vector2.ZERO, hit_radius * 2.15, -PI / 2.0, -PI / 2.0 + TAU * k, 40, Color(1.0, 0.9, 0.5, 0.6), 2.0, true)
	elif _state == &"siege":
		var a := _aim.angle()
		ci.draw_arc(Vector2.ZERO, hit_radius * 1.6, a - 0.9, a + 0.9, 20, Color(1.0, 0.8, 0.35, 0.85), 5.0, true)
	if _slash_t > 0.0:
		var a := _slash_dir.angle()
		var k := _slash_t / 0.3
		ci.draw_arc(_slash_dir * 30.0, 100.0, a - 1.1, a + 1.1, 24, Color(0.75, 0.95, 1.0, k), 9.0 * k + 2.0, true)
	# Name + health bar, always shown.
	var w := 92.0
	var y := -hit_radius * 1.9 - 10.0
	var font: Font = UiFont.BOLD
	var label := "RIVAL  %s" % String(info.get("name", "MECH"))
	ci.draw_string_outline(font, Vector2(-w, y - 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, w * 2.0, 13, 4, Color(0, 0, 0, 0.85))
	ci.draw_string(font, Vector2(-w, y - 6.0), label, HORIZONTAL_ALIGNMENT_CENTER, w * 2.0, 13, RED.lerp(Color.WHITE, 0.35))
	var bw := w * 1.1
	ci.draw_rect(Rect2(-bw / 2.0, y, bw, 6.0), Color(0, 0, 0, 0.7))
	ci.draw_rect(Rect2(-bw / 2.0, y, bw * clampf(hp / max_hp, 0.0, 1.0), 6.0), RED.lerp(Color.WHITE, _flash * 0.5))
