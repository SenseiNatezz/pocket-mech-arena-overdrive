class_name Mech
extends CharacterBody2D
## The player's mech: twin-stick movement + independent aim, and every Input Map action:
##   fire_primary   - rapid blaster, auto-fire while held
##   fire_secondary - scatter blast (6 pellets), short cooldown
##   boost          - quick dash with i-frames, cooldown shown as a ring around the mech
##   heat_attack_1  - Heat Nova: shockwave around the mech (costs heat)
##   heat_attack_2  - Magma Cone: cone blast toward the aim (costs heat)
##   self_repair    - heal using a limited repair charge
##   overdrive      - when the meter is full: faster fire, more damage, more speed for a few seconds
##   use            - interact with the nearest interactable (repair stations, doors, terminals)
## Heat and overdrive both build up from damage the mech deals.

signal stats_changed
signal died

@export_group("Movement")
@export var move_speed := 340.0
## How fast the mech reaches full speed / stops (higher = snappier).
@export var acceleration := 4200.0
@export var boost_speed := 1150.0
@export var boost_time := 0.18
@export var boost_cooldown := 0.9

@export_group("Weapons")
@export var fire_rate := 9.0
@export var bolt_damage := 12.0
@export var bolt_speed := 1100.0
@export var secondary_cooldown := 0.9
@export var pellet_damage := 14.0

@export_group("Heat")
@export var heat_max := 100.0
## Heat gained per point of damage dealt.
@export var heat_per_damage := 0.22
@export var nova_cost := 40.0
@export var nova_radius := 175.0
@export var nova_damage := 60.0
@export var cone_cost := 30.0
@export var cone_range := 270.0
@export var cone_damage := 45.0

@export_group("Survival")
@export var max_hp := 100.0
@export var repair_charges_max := 3
@export var repair_amount := 40.0

@export_group("Overdrive")
@export var overdrive_per_damage := 0.1
@export var overdrive_time := 8.0

const INTERACT_RANGE := 110.0

var hp := 100.0
var heat := 0.0
var overdrive_meter := 0.0
var overdrive_left := 0.0
var repair_charges := 3
var boost_cooldown_left := 0.0
var aim_dir := Vector2.RIGHT
var dead := false
## Set by hazards/pits later; the interactable currently in range (or null).
var focus_interactable: Node

var hit_radius := 26.0
var _boost_left := 0.0
var _boost_dir := Vector2.RIGHT
var _fire_cd := 0.0
var _secondary_cd := 0.0
var _repair_cd := 0.0
var _invuln := 0.0
var _knockback := Vector2.ZERO
var _flash := 0.0
var _muzzle_t := 0.0
var _afterimage_t := 0.0
var _safe_pos := Vector2.ZERO
var _falling := 0.0
var _fall_center := Vector2.ZERO

## HP lost when falling into a pit.
const PIT_DAMAGE := 15.0
const FALL_TIME := 0.55

@onready var body: Node2D = $Body
@onready var sprite: AnimatedSprite2D = $Body/Sprite
@onready var muzzle: Marker2D = $Body/Muzzle
@onready var muzzle_flash: Sprite2D = $Body/MuzzleFlash
@onready var thrusters: Array[GPUParticles2D] = [$Body/ThrusterL, $Body/ThrusterR]
@onready var ring: Node2D = $BoostRing
@onready var aura: Sprite2D = $OverdriveAura
@onready var prompt: Label = $Prompt


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	hp = max_hp
	repair_charges = repair_charges_max
	Combat.damage_dealt.connect(_on_damage_dealt)
	stats_changed.emit.call_deferred()
	_safe_pos = global_position


func _physics_process(delta: float) -> void:
	if dead:
		return
	if _falling > 0.0:
		_update_fall(delta)
		return
	_tick_timers(delta)
	var move := Controls.get_move()
	aim_dir = Controls.get_aim(global_position, get_viewport())

	if Input.is_action_just_pressed("boost"):
		_try_boost(move)
	if Input.is_action_just_pressed("heat_attack_1"):
		_heat_nova()
	if Input.is_action_just_pressed("heat_attack_2"):
		_magma_cone()
	if Input.is_action_just_pressed("self_repair"):
		_self_repair()
	if Input.is_action_just_pressed("overdrive"):
		_activate_overdrive()
	if Input.is_action_just_pressed("use") and focus_interactable:
		focus_interactable.interact(self)

	# Movement: snappy acceleration toward the stick direction; boost overrides it.
	var speed := move_speed * (1.2 if overdrive_left > 0.0 else 1.0)
	if _boost_left > 0.0:
		velocity = _boost_dir * boost_speed
		_afterimage_t -= delta
		if _afterimage_t <= 0.0:
			_afterimage_t = 0.025
			_spawn_afterimage()
	else:
		velocity = velocity.move_toward(move * speed, acceleration * delta)
	velocity += _knockback
	_knockback = _knockback.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * delta))
	move_and_slide()

	# Weapons.
	var od := overdrive_left > 0.0
	if Input.is_action_pressed("fire_primary") and _fire_cd <= 0.0 and _boost_left <= 0.0:
		_fire_cd = 1.0 / (fire_rate * (2.0 if od else 1.0))
		_fire_primary(1.5 if od else 1.0)
	if Input.is_action_pressed("fire_secondary") and _secondary_cd <= 0.0 and _boost_left <= 0.0:
		_secondary_cd = secondary_cooldown * (0.6 if od else 1.0)
		_fire_secondary(1.5 if od else 1.0)

	_update_interact_focus()
	_update_visuals(delta, move)
	_check_pits()


func _tick_timers(delta: float) -> void:
	boost_cooldown_left = maxf(boost_cooldown_left - delta, 0.0)
	_boost_left = maxf(_boost_left - delta, 0.0)
	_fire_cd -= delta
	_secondary_cd -= delta
	_repair_cd -= delta
	_invuln -= delta
	if overdrive_left > 0.0:
		overdrive_left = maxf(overdrive_left - delta, 0.0)
		if overdrive_left == 0.0:
			stats_changed.emit()


# --- weapons -------------------------------------------------------------------------------------

func _fire_primary(mult: float) -> void:
	var spread := randf_range(-0.04, 0.04)
	var dir := aim_dir.rotated(spread)
	var color := Color(1.0, 0.8, 0.3) if overdrive_left > 0.0 else Color(0.4, 0.8, 1.0)
	Combat.fire(muzzle.global_position, dir * bolt_speed, bolt_damage * mult, true, self, color)
	_muzzle_t = 0.05
	sprite.position = Vector2(0, 4)
	Sfx.play(&"shoot", -18.0)


func _fire_secondary(mult: float) -> void:
	for i in 6:
		var a := deg_to_rad(lerpf(-16.0, 16.0, i / 5.0)) + randf_range(-0.03, 0.03)
		Combat.fire(muzzle.global_position, aim_dir.rotated(a) * bolt_speed * randf_range(0.85, 1.0), pellet_damage * mult,
			true, self, Color(0.6, 1.0, 0.9), 0.8, 0.45)
	_knockback -= aim_dir * 160.0
	_muzzle_t = 0.09
	Sfx.play(&"hit", -6.0, 0.05)
	Combat.shake(0.06)


func _try_boost(move: Vector2) -> void:
	if boost_cooldown_left > 0.0 or _boost_left > 0.0:
		return
	_boost_dir = move.normalized() if move.length() > 0.2 else aim_dir
	_boost_left = boost_time
	boost_cooldown_left = boost_cooldown * (0.6 if overdrive_left > 0.0 else 1.0)
	_invuln = boost_time + 0.08
	Sfx.play(&"dash", -6.0)
	stats_changed.emit()


func _heat_nova() -> void:
	if heat < nova_cost:
		_deny()
		return
	heat -= nova_cost
	Combat.area_damage(global_position, nova_radius, nova_damage, self, false, Vector2.ZERO, PI, 520.0)
	Combat.shockwave(global_position, nova_radius, Color(1.0, 0.5, 0.15))
	Combat.shockwave(global_position, nova_radius * 0.6, Color(1.0, 0.85, 0.4), 0.25)
	Sfx.play(&"slam", -2.0)
	Combat.shake(0.3)
	stats_changed.emit()


func _magma_cone() -> void:
	if heat < cone_cost:
		_deny()
		return
	heat -= cone_cost
	Combat.area_damage(global_position, cone_range, cone_damage, self, false, aim_dir, deg_to_rad(35.0), 320.0)
	var cone := Node2D.new()
	cone.set_script(preload("res://player/weapons/cone_fx.gd"))
	cone.set("origin", global_position)
	cone.set("dir", aim_dir)
	cone.set("reach", cone_range)
	get_parent().add_child(cone)
	Sfx.play(&"explode", -4.0)
	Combat.shake(0.2)
	stats_changed.emit()


func _self_repair() -> void:
	if repair_charges <= 0 or hp >= max_hp or _repair_cd > 0.0:
		_deny()
		return
	repair_charges -= 1
	_repair_cd = 1.0
	hp = minf(hp + repair_amount, max_hp)
	Combat.shockwave(global_position, 80.0, Color(0.4, 1.0, 0.5), 0.4)
	Combat.damage_number(global_position, repair_amount, Color(0.5, 1.0, 0.6))
	Sfx.play(&"shield", -4.0)
	stats_changed.emit()


func _activate_overdrive() -> void:
	if overdrive_meter < 100.0 or overdrive_left > 0.0:
		_deny()
		return
	overdrive_meter = 0.0
	overdrive_left = overdrive_time
	Combat.shockwave(global_position, 140.0, Color(1.0, 0.85, 0.3), 0.45)
	Sfx.play(&"levelup", -2.0, 0.0)
	stats_changed.emit()


func _deny() -> void:
	Sfx.play(&"select", -14.0, 0.0)


## Heat + overdrive build from damage this mech deals.
func _on_damage_dealt(amount: float, source: Node, _target: Node) -> void:
	if source != self:
		return
	heat = minf(heat + amount * heat_per_damage, heat_max)
	if overdrive_left <= 0.0:
		overdrive_meter = minf(overdrive_meter + amount * overdrive_per_damage, 100.0)
	stats_changed.emit()


# --- damage ----------------------------------------------------------------------------------------

func take_damage(amount: float, from_pos: Vector2, _source: Node = null) -> void:
	if dead or _invuln > 0.0 or _falling > 0.0:
		return
	_apply_damage(amount)
	_invuln = 0.4
	knock((global_position - from_pos).normalized() * 380.0)


func _apply_damage(amount: float) -> void:
	hp -= amount
	_flash = 1.0
	Combat.damage_number(global_position, amount, Color(1, 0.35, 0.3))
	Combat.shake(0.35)
	Sfx.play(&"hurt", -4.0)
	stats_changed.emit()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		velocity = Vector2.ZERO
		Combat.explosion_fx(global_position, 160.0, Color(0.4, 0.8, 1.0))
		Sfx.play(&"big_explode", -2.0)
		Combat.shake(0.9)
		hide()
		died.emit()


# --- pits ------------------------------------------------------------------------------------------

## Pits are axis-aligned rects (group "pits", `size` in px). The mech falls when its center is over
## one (with a small lip), and remembers the last spot that was well clear of every pit.
func _check_pits() -> void:
	if _boost_left > 0.0:
		return
	var safe := true
	for pit: Node2D in get_tree().get_nodes_in_group("pits"):
		var r := Rect2(pit.global_position - pit.size / 2, pit.size)
		if r.grow(-10.0).has_point(global_position):
			_falling = FALL_TIME
			_fall_center = pit.global_position
			velocity = Vector2.ZERO
			_knockback = Vector2.ZERO
			Sfx.play(&"dash", -8.0, 0.0)
			return
		if r.grow(46.0).has_point(global_position):
			safe = false
	if safe:
		_safe_pos = global_position


func _update_fall(delta: float) -> void:
	_falling -= delta
	var k := 1.0 - _falling / FALL_TIME
	global_position = global_position.lerp(_fall_center, delta * 3.0)
	body.scale = Vector2.ONE * lerpf(1.0, 0.25, k)
	body.modulate.a = 1.0 - k
	body.rotation += delta * 6.0
	if _falling <= 0.0:
		_falling = 0.0
		body.scale = Vector2.ONE
		body.modulate.a = 1.0
		global_position = _safe_pos
		_apply_damage(PIT_DAMAGE)
		_invuln = 1.0
		if not dead:
			Combat.shockwave(global_position, 70.0, Color(0.4, 0.8, 1.0), 0.3)


func is_falling() -> bool:
	return _falling > 0.0


# --- pickups / stations ------------------------------------------------------------------------------

func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
	Combat.damage_number(global_position, amount, Color(0.5, 1.0, 0.6))
	stats_changed.emit()


func add_heat(amount: float) -> void:
	heat = minf(heat + amount, heat_max)
	stats_changed.emit()


func add_repair_charge() -> void:
	repair_charges = mini(repair_charges + 1, repair_charges_max)
	stats_changed.emit()


func add_overdrive(amount: float) -> void:
	if overdrive_left <= 0.0:
		overdrive_meter = minf(overdrive_meter + amount, 100.0)
	stats_changed.emit()


func knock(impulse: Vector2) -> void:
	_knockback += impulse


# --- interaction ---------------------------------------------------------------------------------

func _update_interact_focus() -> void:
	var best: Node = null
	var best_d := INTERACT_RANGE
	for n in get_tree().get_nodes_in_group("interactable"):
		var d: float = global_position.distance_to(n.global_position)
		if d < best_d and (not n.has_method("can_interact") or n.can_interact(self)):
			best_d = d
			best = n
	if best != focus_interactable:
		focus_interactable = best
		stats_changed.emit()
	prompt.visible = best != null
	if best:
		var key: String = {Controls.Device.KEYBOARD_MOUSE: "R", Controls.Device.GAMEPAD: "A", Controls.Device.TOUCH: "USE"}[Controls.device]
		prompt.text = "[%s] %s" % [key, best.get("prompt_text")]


# --- visuals -------------------------------------------------------------------------------------

func _update_visuals(delta: float, move: Vector2) -> void:
	# Torso turns to the aim independently of movement (sprite faces "up" at rotation 0).
	body.rotation = lerp_angle(body.rotation, aim_dir.angle() + PI / 2, 1.0 - exp(-22.0 * delta))
	var anim := &"idle"
	if _boost_left > 0.0:
		anim = &"dash"
	elif move.length() > 0.2:
		var local := move.rotated(-body.rotation)
		anim = &"bank_left" if local.x < -0.55 else (&"bank_right" if local.x > 0.55 else &"boost")
	elif Input.is_action_pressed("fire_primary"):
		anim = &"fire"
	if sprite.animation != anim:
		sprite.play(anim)
	for t in thrusters:
		t.amount_ratio = 1.0 if move.length() > 0.2 or _boost_left > 0.0 else 0.4
	sprite.position = sprite.position.lerp(Vector2.ZERO, 1.0 - exp(-30.0 * delta))
	_muzzle_t -= delta
	muzzle_flash.visible = _muzzle_t > 0.0
	if muzzle_flash.visible:
		muzzle_flash.rotation = randf() * TAU
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	(sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	aura.visible = overdrive_left > 0.0
	if aura.visible:
		aura.scale = Vector2.ONE * (2.3 + sin(Time.get_ticks_msec() * 0.02) * 0.15)
	ring.queue_redraw()


func _spawn_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = sprite.global_position
	ghost.rotation = body.rotation
	ghost.scale = sprite.scale
	ghost.modulate = Color(0.4, 0.8, 1.0, 0.5)
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.tween_callback(ghost.queue_free)


## Fraction of the boost cooldown that has recharged (1 = ready). Used by the ring + HUD.
func boost_ready_fraction() -> float:
	return 1.0 - boost_cooldown_left / maxf(boost_cooldown, 0.01)
