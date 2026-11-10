class_name Mech
extends CharacterBody2D
## The player's mech: twin-stick movement + independent aim, and every Input Map action:
##   fire_primary   - the equipped primary weapon (Game.weapon, chosen in the Armory), auto-fire while
##                    held: beam rifle, sniper beam (hitscan, pierces all), gatling cannon, rocket
##                    launcher (exploding rockets), or a melee weapon with combos + finishers
##                    (player/weapons/melee_kit.gd). The gatling + rockets are drawn in the gun hand.
##   fire_secondary - scatter blast (6 pellets), short cooldown
##   boost          - quick dash with i-frames, cooldown shown as a ring around the mech
##   heat_attack_1  - Heat Nova: shockwave around the mech (costs heat)
##   heat_attack_2  - Magma Cone: cone blast toward the aim (costs heat)
##   self_repair    - heal using a limited repair charge
##   overdrive      - when the meter is full: faster fire, more damage, more speed for a few seconds
##   use            - interact with the nearest interactable (repair stations, doors, terminals)
##   beam           - Beam Cannon: charge, then a sustained piercing beam (see weapons/beam_cannon.gd)
##   heat_smart     - touch SIMPLE layout's HEAT button: Nova when robots are close, otherwise Cone
## Heat and overdrive both build up from damage the mech deals.
## Level-up upgrades (autoload/upgrades.gd) are read live from Upgrades: stat multipliers, Triple Shot,
## Target Lock, Defense Shield, Orbit Blades, Salvage Repair, Bit Drones, Micro-Missiles, Arc Emitter,
## Cryo Rounds, Redline, Impulse Burst, Reactive Armor, Reactor Overcharge, Thermal Amplifier...
## CHASSIS tricks (Game.CHASSIS): Standard = 4 level-up cards (Upgrades.card_count), Striker = boost
## slices + kills recharge the boost, Bulwark = boost rams + SIEGE MODE (hold still to brace).

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

## Primary weapons other than the blaster (whose numbers are the fire_rate / bolt_* exports above).
const GATLING_RATE := 16.0
## ~128 DPS (vs the Beam Rifle's ~108) with a wide spread and slower movement while firing.
const GATLING_DAMAGE := 8.0
## Big, bright rounds + a large flash/spark at the barrel so the gatling reads as heavy.
const GATLING_BULLET_SIZE := 1.7
const GATLING_FLASH_SCALE := 1.6
const DEFAULT_FLASH_SCALE := 0.7
## Dual Beam Pistols: one in each fist firing in turn - very fast, low damage (~90 DPS vs the Beam Rifle's
## ~108), quick short-range darts, full speed while firing.
const PISTOL_RATE := 18.0
const PISTOL_DAMAGE := 5.0
const PISTOL_SPEED_MULT := 1.15
const PISTOL_LIFETIME := 0.6
const PISTOL_SPREAD := 0.06
## Rocket Launcher: slow heavy rockets that explode (splash); see player/weapons/rocket.gd.
const ROCKET_RATE := 1.5
const ROCKET_DAMAGE := 60.0
const ROCKET := preload("res://player/weapons/rocket.gd")
const SNIPER_RATE := 1.3
const SNIPER_DAMAGE := 80.0
const SNIPER_RANGE := 1700.0
const SNIPER_TRACE := preload("res://player/weapons/sniper_trace.gd")
## Mech sprite frames with / without the painted rifle (tools/make_nogun_sheet.gd builds the latter).
const FRAMES_RIFLE := preload("res://assets/sprites/gundam_frames.tres")
const FRAMES_NO_GUN := preload("res://assets/sprites/gundam_frames_nogun.tres")
const ORBIT_BLADES := preload("res://player/weapons/orbit_blades.gd")
const SHIELD_BUBBLE := preload("res://player/shield_bubble.gd")
const BIT_DRONES := preload("res://player/weapons/bit_drones.gd")
const ARC_FX := preload("res://player/weapons/arc_fx.gd")
const SIEGE_FX := preload("res://player/siege_fx.gd")
## Arc Emitter: how far lightning jumps, and the share of the hit it carries.
const ARC_RANGE := 180.0
const ARC_SHARE := 0.4
## Redline: below this HP fraction.
const REDLINE_HP := 0.4
## Bulwark SIEGE MODE: seconds standing still to brace, and the bonuses when fully braced.
const SIEGE_DELAY := 0.6
const SIEGE_DAMAGE := 1.3
const SIEGE_TAKEN := 0.7
## Striker: boost cooldown refunded per kill (seconds).
const STRIKER_KILL_REFUND := 0.3
## TEMPEST SALVO: seconds between volleys, rockets per volley, damage each, and the reach it looks for robots.
const SALVO_INTERVAL := 4.0
const SALVO_ROCKETS := 4
const SALVO_DAMAGE := 34.0
const SALVO_RANGE := 700.0
## FROSTBLADE IAIDO: melee / gun damage, overdrive gain on melee hits, HP per melee kill.
const IAIDO_MELEE := 1.3
const IAIDO_GUNS := 0.8
const IAIDO_OD := 1.5
const IAIDO_HEAL := 3.0
## SOLSTICE BARRIER: recharge time without the Defense Shield upgrade, recharge speed-up, blast on a break.
const BARRIER_RECHARGE := 10.0
const BARRIER_FASTER := 0.75
const BARRIER_BLAST := 40.0
## CORVID FEATHER SWARM: chance a kill fires feathers, and how many.
const FEATHER_CHANCE := 0.35
const FEATHERS := 2
## RAVEN CLAW PHASE BLINK: blink distance, and the critical window after a blink.
const BLINK_DIST := 230.0
const BLINK_CRIT_TIME := 1.5
const BLINK_CRIT := 2.0
## Touch SIMPLE layout: Self-repair kicks in below this HP fraction (with a kit to spare).
const AUTO_REPAIR_HP := 0.35

var hp := 100.0
var heat := 0.0
var overdrive_meter := 0.0
var overdrive_left := 0.0
var repair_charges := 3
var boost_cooldown_left := 0.0
var aim_dir := Vector2.RIGHT
## Extra torso turn (radians) while a melee swing drives the body (set by player/weapons/melee_rig.gd).
var swing_twist := 0.0
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
## Gatling rounds fired (every few puffs gun smoke).
var _gun_smoke := 0
var _afterimage_t := 0.0
var beam: BeamCannon
var melee: MeleeKit
## Big guns (Gatling Cannon, Rocket Launcher) drawn in the gun hand; see player/weapons/held_weapon.gd.
var held: HeldWeapon
var _safe_pos := Vector2.ZERO
var _falling := 0.0
var _fall_center := Vector2.ZERO
## Equipped primary weapon: &"blaster", &"sniper", &"sword" or &"gatling".
var weapon := &"blaster"
var shield_charges := 0
var _shield_t := 0.0
var _base_max_hp := 100.0
## Chassis (Game.CHASSIS entry) and its body scale; robots already hit by the current boost
## (Striker afterburner / Bulwark ram hit each robot once per boost); Last Stand (Hangar) used up.
var _chassis := {}
var _chassis_id := &"standard"
var _body_scale := 1.0
## This chassis's sprite frames (with / without the painted Beam Rifle), see Game.chassis_frames.
var _frames_gun: SpriteFrames
var _frames_nogun: SpriteFrames
## TEMPEST salvo timer; RAVEN CLAW crit window after a blink.
var _salvo_t := 1.5
var _crit_t := 0.0
var _boost_hits: Array[int] = []
var _last_stand_used := false
## Combos: Railgun shot counter; seconds since the mech last took damage (Nano Repair).
var _rail_count := 0
var _since_hit := 99.0
var _nano_fx := 0.0
var _shield_fx: Node2D
## Bulwark SIEGE MODE: 0 = mobile, 1 = fully braced (eases in after SIEGE_DELAY standing still).
var siege_k := 0.0
var _still_t := 0.0
## Upgrade timers: Micro-Missile Pod volley, Reactive Armor recharge; Arc Emitter re-entry guard.
var _missile_t := 1.0
var _reactive_cd := 0.0
var _arcing := false
## PARTS DOUBLE DASH (Twin Booster): spare boosts ready on top of the usual one, and how many it holds.
var _boost_spare := 0
var _boost_spares_max := 0
## Base values the Reactor Overcharge / Thermal Amplifier upgrades scale.
var _base_od_time := 8.0
var _base_nova_cost := 40.0
var _base_cone_cost := 30.0

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
	weapon = Game.weapon
	# Chassis (Hangar): HP / boost / damage-taken multipliers and size. Speed is in Upgrades.move_mult().
	_chassis = Game.chassis_info()
	_chassis_id = _chassis.get("id", &"standard")
	_frames_gun = Game.chassis_frames(_chassis_id, true)
	_frames_nogun = Game.chassis_frames(_chassis_id, false)
	_body_scale = float(_chassis["scale"])
	body.scale = Vector2.ONE * _body_scale
	hit_radius *= _body_scale
	boost_speed *= float(_chassis["boost_speed"])
	# Hangar: Reinforced Frame (+10 HP a level) and Spare Repair Kits.
	_base_max_hp = (max_hp * float(_chassis["hp"]) + 10.0 * Game.hangar_level(&"frame")) * (1.0 + Game.hangar_mk_bonus(&"frame"))
	max_hp = _base_max_hp + Upgrades.max_hp_bonus()
	hp = max_hp
	repair_charges_max += Game.hangar_level(&"kits")
	repair_charges = repair_charges_max
	shield_charges = _shield_max()
	Combat.damage_dealt.connect(_on_damage_dealt)
	Combat.enemy_killed.connect(_on_enemy_killed)
	Upgrades.upgrade_applied.connect(_on_upgrade)
	var blades: Node2D = ORBIT_BLADES.new()
	blades.mech = self
	add_child(blades)
	var drones: Node2D = BIT_DRONES.new()
	drones.mech = self
	add_child(drones)
	_shield_fx = SHIELD_BUBBLE.new()
	_shield_fx.mech = self
	add_child(_shield_fx)
	if _chassis.get("id") == &"bulwark":
		var siege: Node2D = SIEGE_FX.new()
		siege.mech = self
		add_child(siege)
	_base_od_time = overdrive_time
	_base_nova_cost = nova_cost
	_base_cone_cost = cone_cost
	_refresh_upgrade_stats()
	stats_changed.emit.call_deferred()
	_safe_pos = global_position
	# Gundam Customization: armor paint (shader), energy (shots + muzzle), booster (thrusters).
	sprite.material = (sprite.material as ShaderMaterial).duplicate()
	Game.apply_armor(sprite.material)
	# A chassis whose own design isn't rendered yet flies NIMBUS-07's art tinted in its colour.
	sprite.self_modulate = Game.chassis_tint(_chassis_id)
	muzzle_flash.modulate = Game.energy_color()
	for t in thrusters:
		t.modulate = Game.booster_color().lightened(0.25)
	_apply_parts()
	beam = BeamCannon.new()
	beam.mech = self
	add_child(beam)
	# Created up front so a melee weapon is already in hand at spawn (its rig hides for other weapons).
	melee = MeleeKit.new()
	add_child(melee)
	held = HeldWeapon.new()
	body.add_child(held)
	held.setup(self)


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
	if InputMap.has_action(&"heat_smart") and Input.is_action_just_pressed("heat_smart"):
		_smart_heat()
	if Input.is_action_just_pressed("self_repair"):
		_self_repair()
	if Input.is_action_just_pressed("overdrive"):
		_activate_overdrive()
	if Input.is_action_just_pressed("use") and focus_interactable:
		focus_interactable.interact(self)
	if Input.is_action_just_pressed("beam") and _boost_left <= 0.0:
		if not beam.try_fire(aim_dir):
			_deny()
	beam.damage_mult = Upgrades.damage_mult()
	beam.update(delta, aim_dir, muzzle.global_position, overdrive_left > 0.0)

	# Movement: snappy acceleration toward the stick direction; boost overrides it.
	var speed := move_speed * Upgrades.move_mult() * (1.2 if overdrive_left > 0.0 else 1.0) * beam.move_factor()
	if weapon == &"gatling" and Controls.is_firing():
		speed *= 0.8
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
	if _boost_left > 0.0:
		_boost_contact()
	else:
		_keep_off_bosses()

	_update_siege(delta, move)

	# Weapons.
	var od := overdrive_left > 0.0
	var redline := hp < max_hp * REDLINE_HP
	var dmg := Upgrades.damage_mult() * (1.5 if od else 1.0) * lerpf(1.0, SIEGE_DAMAGE, siege_k) \
		* (1.0 + (Upgrades.redline_damage() if redline else 0.0)) * _chassis_damage_mult()
	if Controls.is_firing() and _fire_cd <= 0.0 and _boost_left <= 0.0 and not beam.is_busy():
		_fire_cd = 1.0 / (_weapon_rate() * Upgrades.fire_rate_mult() * (2.0 if od else 1.0) * _overclock()
			* (1.0 + (Upgrades.redline_rate() if redline else 0.0)))
		_fire_primary(dmg * Game.mastery_damage_mult(weapon))
	if Input.is_action_pressed("fire_secondary") and _secondary_cd <= 0.0 and _boost_left <= 0.0 and not beam.is_busy():
		_secondary_cd = secondary_cooldown * (0.6 if od else 1.0)
		_fire_secondary(dmg)

	_update_interact_focus()
	_update_visuals(delta, move)
	_check_pits()


func _tick_timers(delta: float) -> void:
	boost_cooldown_left = maxf(boost_cooldown_left - delta, 0.0)
	# PARTS DOUBLE DASH: a finished cooldown tops up a spare boost first (and recharges on for the next).
	if boost_cooldown_left <= 0.0 and _boost_spare < _boost_spares_max:
		_boost_spare += 1
		boost_cooldown_left = _boost_cd() * (0.6 if overdrive_left > 0.0 else 1.0)
	_boost_left = maxf(_boost_left - delta, 0.0)
	_fire_cd -= delta
	_secondary_cd -= delta
	_repair_cd -= delta
	_invuln -= delta
	_since_hit += delta
	# NANO REPAIR combo: 2 HP/s after 3 s without taking damage.
	if Upgrades.level_of(&"nano_repair") > 0 and _since_hit > 3.0 and hp < max_hp:
		hp = minf(hp + 2.0 * Game.diff("heal") * delta, max_hp)
		_nano_fx -= delta
		if _nano_fx <= 0.0:
			_nano_fx = 0.6
			Combat.spark(global_position + Vector2(randf_range(-18, 18), randf_range(-18, 18)), Color(0.4, 1.0, 0.55), 0.6)
			stats_changed.emit()
	# Defense Shield: recharge one charge at a time.
	if shield_charges < _shield_max():
		_shield_t -= delta
		if _shield_t <= 0.0:
			_shield_t = _shield_recharge()
			shield_charges += 1
			Combat.shockwave(global_position, 60.0, Color(0.45, 0.85, 1.0), 0.3)
			stats_changed.emit()
	else:
		_shield_t = _shield_recharge()
	if overdrive_left > 0.0:
		overdrive_left = maxf(overdrive_left - delta, 0.0)
		if overdrive_left == 0.0:
			stats_changed.emit()
	_reactive_cd -= delta
	_crit_t = maxf(_crit_t - delta, 0.0)
	# TEMPEST SALVO: the shoulder pods fire whenever a robot is in reach and the volley is ready.
	if _chassis_id == &"artillery":
		_salvo_t -= delta
		if _salvo_t <= 0.0 and Combat.nearest_enemy(global_position, SALVO_RANGE):
			_salvo_t = SALVO_INTERVAL
			_fire_salvo()
	# MICRO-MISSILE POD: a volley of homing missiles whenever a robot is near.
	if Upgrades.level_of(&"missile_pod") > 0:
		_missile_t -= delta
		if _missile_t <= 0.0 and Combat.nearest_enemy(global_position, 620.0):
			_missile_t = Upgrades.missile_interval()
			_fire_missiles()
	# Touch SIMPLE layout: no Repair / Overdrive buttons, so those kick in on their own.
	if Controls.device == Controls.Device.TOUCH and Game.touch_simple and not dead:
		if overdrive_meter >= 100.0 and overdrive_left <= 0.0 and Combat.nearest_enemy(global_position, 560.0):
			_activate_overdrive()
		if hp < max_hp * AUTO_REPAIR_HP and repair_charges > 0 and _repair_cd <= 0.0:
			_self_repair()


# --- weapons -------------------------------------------------------------------------------------

## Where shots should converge: the first enemy / prop / wall on the aim line from the mech's centre,
## else the mouse cursor (or a point ahead for gamepad/touch). The rifle sits off to the side, so
## firing parallel to the aim would pass ~35 px beside small targets.
func _aim_point() -> Vector2:
	var reach := 1000.0
	var q := PhysicsRayQueryParameters2D.create(global_position, global_position + aim_dir * reach, 1 | 4 | 32)
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return hit.position
	if Controls.aim_distance > 0.0:
		return global_position + aim_dir * maxf(Controls.aim_distance, 90.0)
	return global_position + aim_dir * 420.0


func _shot_dir() -> Vector2:
	# Target Lock: snap onto the closest enemy near the aim line.
	var locked := _assist_target(1000.0)
	if locked:
		var to_enemy := locked.global_position - muzzle.global_position
		return to_enemy.normalized() if to_enemy.length() > 40.0 else aim_dir
	var to := _aim_point() - muzzle.global_position
	# Too close / behind the muzzle: just fire straight along the aim.
	if to.length() < 40.0 or to.dot(aim_dir) <= 0.0:
		return aim_dir
	return to.normalized()


## Target Lock upgrade: the enemy the aim snaps to (null without the upgrade / nothing in the cone).
func _assist_target(reach: float) -> Node2D:
	var deg := Upgrades.aim_assist_deg()
	if deg <= 0.0:
		return null
	return Combat.nearest_enemy(global_position, reach, aim_dir, deg_to_rad(deg))


## Attacks per second: the weapon's own rate, times the PARTS ARMS (guns and melee swings separately).
func _weapon_rate() -> float:
	return _base_weapon_rate() * Parts.mult("rate") * Parts.mult("melee_rate" if MeleeKit.has_weapon(weapon) else "fire_rate")


func _base_weapon_rate() -> float:
	if MeleeKit.has_weapon(weapon):
		return MeleeKit.rate(weapon)
	match weapon:
		&"gatling": return GATLING_RATE
		&"dual_pistols": return PISTOL_RATE
		&"rockets": return ROCKET_RATE
		&"sniper": return SNIPER_RATE
	return fire_rate


func _shot_color() -> Color:
	return Color(1.0, 0.8, 0.3) if overdrive_left > 0.0 else Game.energy_color()


func _fire_primary(mult: float) -> void:
	# Melee weapons (Beam Saber, Dual Sabers, Katana, Spear, Axe, Scythe, Greatsword): player/weapons/melee_kit.gd.
	if MeleeKit.has_weapon(weapon):
		if melee == null:
			melee = MeleeKit.new()
			add_child(melee)
		melee.swing(weapon, mult)
		return
	match weapon:
		&"sniper":
			_fire_sniper(mult)
		&"rockets":
			_fire_rockets(mult)
		_:
			_fire_bolts(mult)


## Blaster / Gatling / Dual Pistols: Triple Shot fans extra bolts out to the sides (75% damage each).
## Each draws its own shot (player/weapons/rifle_fx.gd): rifle beam bolts, gatling tracers, pistol darts.
func _fire_bolts(mult: float) -> void:
	var gatling := weapon == &"gatling"
	var pistols := weapon == &"dual_pistols"
	var spread := 0.1 if gatling else (PISTOL_SPREAD if pistols else 0.04)
	var base := _shot_dir().rotated(randf_range(-spread, spread))
	var dmg := (GATLING_DAMAGE if gatling else (PISTOL_DAMAGE if pistols else bolt_damage)) * mult
	var speed := bolt_speed * (1.1 if gatling else (PISTOL_SPEED_MULT if pistols else 1.0))
	var n := Upgrades.multishot_count()
	var seekers := Upgrades.level_of(&"seeker_swarm") > 0
	for i in n:
		var off := (i - (n - 1) / 2.0) * 0.16
		var seek := seekers and off != 0.0
		var col := Upgrades.COMBO_GOLD.lerp(_shot_color(), 0.4) if seek else _shot_color()
		var b := Combat.fire(muzzle.global_position, base.rotated(off * (2.8 if seek else 1.0)) * speed,
			dmg * (1.0 if off == 0.0 else 0.75), true, self, col,
			GATLING_BULLET_SIZE if gatling else (0.85 if pistols else 1.0), PISTOL_LIFETIME if pistols else 1.2)
		_arm(b)
		if gatling:
			b.set_tracer_style()
		elif pistols:
			b.set_dart_style()
		else:
			b.set_rifle_style()
		# SEEKER SWARM combo: side shots swing out wide, then hunt.
		if seek:
			b.homing = 11.0
	# RAILGUN combo: every 6th shot also fires a slug that pierces everything for 4x damage.
	if Upgrades.level_of(&"railgun") > 0:
		_rail_count += 1
		if _rail_count >= 6:
			_rail_count = 0
			var slug := Combat.fire(muzzle.global_position, base * 2200.0, dmg * 4.0, true, self, Color(0.85, 0.97, 1.0), 2.4, 0.9)
			slug.pierce = 99
			Combat.spark(muzzle.global_position + base * 20.0, Color(0.7, 0.95, 1.0), 2.0)
			Combat.shake(0.12)
			Sfx.play(&"beam_rifle", -8.0, 0.05)
	sprite.position = Vector2(0, 3 if gatling else (2 if pistols else 4))
	if gatling:
		_muzzle_t = 0.05
		muzzle_flash.scale = Vector2.ONE * GATLING_FLASH_SCALE * randf_range(0.85, 1.15)
		muzzle_flash.modulate = Color(1.0, 0.7, 0.3)
		held.kick(0.35)
		RifleFx.gat_muzzle(muzzle, base)
		_gun_smoke += 1
		if _gun_smoke % 4 == 0:
			SmokePuff.spawn(muzzle.global_position + base * 18.0, Color(0.62, 0.62, 0.66, 0.42), 11.0, 0.7,
				base * 50.0 + base.orthogonal() * randf_range(-25.0, 25.0))
		Combat.camera_kick(-base * 2.5)
		Combat.rumble(0.3, 0.12, 0.08)
		Sfx.play(&"gatling_shot", -12.0, 0.08)
	elif pistols:
		# The pistol that fired kicks, and the Muzzle hops to the other fist for the next shot.
		RifleFx.pistol_muzzle(muzzle, base, _shot_color())
		held.kick(1.0)
		Combat.rumble(0.14, 0.0, 0.04)
		Sfx.play(&"pistol_shot", -15.0, 0.1)
	else:
		# Beam Rifle: a drawn ignition at the barrel instead of the glow sprite.
		RifleFx.muzzle(muzzle, base, _shot_color())
		Combat.camera_kick(-base * 1.5)
		Combat.rumble(0.18, 0.05, 0.05)
		Sfx.play(&"beam_shot", -13.0, 0.06)


## Rocket Launcher: heavy rockets that explode on impact (splash hits everything nearby). Triple Shot =
## a small fan of rockets (side ones 75%), Target Lock = they home in (rocket.gd).
func _fire_rockets(mult: float) -> void:
	var base := _shot_dir()
	var n := Upgrades.multishot_count()
	for i in n:
		var off := (i - (n - 1) / 2.0) * 0.14
		var r: Node2D = ROCKET.new()
		r.setup(muzzle.global_position, base.rotated(off), ROCKET_DAMAGE * mult * (1.0 if off == 0.0 else 0.75), self)
		Combat.world().add_child(r)
	held.kick(1.0)
	_muzzle_t = 0.1
	sprite.position = Vector2(0, 6)
	recoil(-aim_dir * 90.0)
	Sfx.play(&"missile", -6.0, 0.08)
	Combat.shake(0.1)


## Upgrade traits every player projectile carries.
func _arm(b: Bullet) -> void:
	b.pierce = Upgrades.pierce()
	b.homing = Upgrades.homing()
	b.explosive = Upgrades.explosive_chance()


## Sniper Beam: instant beam to the first wall/obstacle that hits EVERY enemy on the line.
## Triple Shot = a narrow fan of beams (side beams deal 60%).
func _fire_sniper(mult: float) -> void:
	# The rifle sits off to the side, so the beam angles in to meet the aim line at full range: it then
	# stays within a few px of that line the whole way and skewers everything standing on it.
	var locked := _assist_target(SNIPER_RANGE)
	var aim_to := locked.global_position if locked else global_position + aim_dir * SNIPER_RANGE
	var base := (aim_to - muzzle.global_position).normalized()
	var n := Upgrades.multishot_count()
	for i in n:
		var off := (i - (n - 1) / 2.0) * 0.09
		_sniper_line(muzzle.global_position, base.rotated(off), SNIPER_DAMAGE * mult * (1.0 if off == 0.0 else 0.6))
	recoil(-aim_dir * 120.0)
	held.kick(0.8)
	_muzzle_t = 0.12
	sprite.position = Vector2(0, 7)
	Sfx.play(&"beam_rifle", -9.0, 0.08)
	Combat.shake(0.14)


func _sniper_line(from: Vector2, dir: Vector2, dmg: float) -> void:
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * SNIPER_RANGE, 1 | 32)
	q.exclude = [get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	var to: Vector2 = hit.position if not hit.is_empty() else from + dir * SNIPER_RANGE
	var hits := 0
	for n in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(n) or n == self or n.is_in_group("player") or n.get("dead") == true:
			continue
		var r: float = n.get("hit_radius") if n.get("hit_radius") != null else 20.0
		var p: Vector2 = n.global_position
		if Geometry2D.get_closest_point_to_segment(p, from, to).distance_to(p) <= r + 14.0:
			n.take_damage(dmg, from, self)
			if n.has_method("knock"):
				n.knock(dir * 220.0)
			Combat.spark(p, _shot_color(), 1.1)
			_maybe_explode(p, dmg)
			hits += 1
	for n in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(n):
			var p: Vector2 = n.global_position
			var r: float = n.get("hit_radius") if n.get("hit_radius") != null else 20.0
			if Geometry2D.get_closest_point_to_segment(p, from, to).distance_to(p) <= r + 10.0:
				n.take_hit(dmg, from)
	# Whatever solid thing stopped the beam (cover, turret base) takes the hit too.
	if not hit.is_empty():
		var c: Object = hit.collider
		if c.has_meta("owner_enemy") and is_instance_valid(c.get_meta("owner_enemy")):
			c.get_meta("owner_enemy").take_damage(dmg, from, self)
		elif c.has_method("take_hit") and not c.is_in_group("destructibles"):
			c.take_hit(dmg, to)
	var fx: Node2D = SNIPER_TRACE.new()
	fx.from = from
	fx.to = to
	fx.color = _shot_color()
	Combat.world().add_child(fx)
	Combat.spark(to, _shot_color(), 1.4)
	if hits >= 3:
		Combat.shockwave(from, 60.0, _shot_color(), 0.25)


## Explosive Rounds for hits that aren't bullets (sniper, sword).
func _maybe_explode(pos: Vector2, dmg: float) -> void:
	if randf() < Upgrades.explosive_chance():
		Combat.small_blast(pos, 75.0, dmg * 0.6, self)


func _fire_secondary(mult: float) -> void:
	var base := _shot_dir()
	for i in 6:
		var a := deg_to_rad(lerpf(-16.0, 16.0, i / 5.0)) + randf_range(-0.03, 0.03)
		Combat.fire(muzzle.global_position, base.rotated(a) * bolt_speed * randf_range(0.85, 1.0), pellet_damage * mult,
			true, self, Game.energy_color().lightened(0.3), 0.8, 0.45)
	_knockback -= aim_dir * 160.0
	_muzzle_t = 0.09
	Sfx.play(&"scatter", -6.0, 0.05)
	Combat.shake(0.06)


func _try_boost(move: Vector2) -> void:
	if _boost_left > 0.0 or (boost_cooldown_left > 0.0 and _boost_spare <= 0):
		return
	_boost_dir = move.normalized() if move.length() > 0.2 else aim_dir
	_boost_left = boost_time
	# PARTS DOUBLE DASH (Twin Booster): while the cooldown runs, a boost spends a spare instead.
	if boost_cooldown_left > 0.0:
		_boost_spare -= 1
	else:
		boost_cooldown_left = _boost_cd() * (0.6 if overdrive_left > 0.0 else 1.0)
	_invuln = boost_time + 0.08
	_boost_hits.clear()
	if _chassis_id == &"phantom":
		_blink()
	Sfx.play(&"boost", -6.0)
	# IMPULSE BURST: the boost kicks off a shockwave.
	var burst := Upgrades.boost_burst_damage()
	if burst > 0.0:
		var r := 120.0 + 20.0 * Upgrades.level_of(&"boost_burst")
		Combat.area_damage(global_position, r, burst * Upgrades.damage_mult(), self, false, Vector2.ZERO, PI, 420.0)
		Combat.shockwave(global_position, r, Upgrades.color(&"boost_burst"), 0.3)
		Combat.shockwave(global_position, r * 0.55, Color(1, 1, 1, 0.8), 0.2)
	stats_changed.emit()


## RAVEN CLAW PHASE BLINK: the boost jumps the mech up to BLINK_DIST at once (stopping at walls and never
## into a pit), leaves a trail of afterimages, and opens the critical window.
func _blink() -> void:
	var from := global_position
	var dist := BLINK_DIST
	while dist > 20.0:
		if not _over_pit(from + _boost_dir * dist) and not test_move(global_transform, _boost_dir * dist):
			break
		dist -= 30.0
	if dist > 20.0:
		global_position = from + _boost_dir * dist
	else:
		move_and_collide(_boost_dir * BLINK_DIST)
	for i in 5:
		var ghost_at := from.lerp(global_position, i / 5.0)
		_spawn_afterimage_at(ghost_at, Color(_chassis["color"], 0.55 - i * 0.07))
	_boost_left = 0.06
	_crit_t = BLINK_CRIT_TIME
	Combat.shockwave(from, 50.0, _chassis["color"], 0.2)
	Combat.shockwave(global_position, 60.0, _chassis["color"], 0.25)


func _over_pit(p: Vector2) -> bool:
	for pit: Node2D in get_tree().get_nodes_in_group("pits"):
		if Rect2(pit.global_position - pit.size / 2, pit.size).grow(20.0).has_point(p):
			return true
	return false


## Chassis damage on every attack: FROSTBLADE's IAIDO (melee up, guns down) and RAVEN CLAW's post-blink criticals.
func _chassis_damage_mult() -> float:
	var m := 1.0
	if _chassis_id == &"duelist":
		m = IAIDO_MELEE if Game.is_melee(weapon) else IAIDO_GUNS
	if _crit_t > 0.0:
		m *= BLINK_CRIT
	return m


## TEMPEST SALVO: heavy homing rockets out of both shoulder pods, every one exploding on impact.
func _fire_salvo() -> void:
	var col: Color = _chassis["color"]
	for i in SALVO_ROCKETS:
		var side := -1.0 if i % 2 == 0 else 1.0
		var dir := aim_dir.rotated(side * (0.5 + 0.25 * float(i >> 1)) + randf_range(-0.1, 0.1))
		var from := global_position + aim_dir.orthogonal() * side * 16.0 * _body_scale
		var b := Combat.fire(from, dir * 420.0, SALVO_DAMAGE * Upgrades.damage_mult(), true, self,
			Color(1.0, 0.45, 0.3), 1.15, 2.2)
		b.homing = 6.0
		b.explosive = 1.0
	Combat.shockwave(global_position, 40.0, col, 0.2)
	Sfx.play(&"missile", -8.0, 0.1)


## SOLSTICE BARRIER: one more Defense Shield charge, recharging faster (and even without the upgrade).
func _shield_max() -> int:
	return Upgrades.shield_max() + (1 if _chassis_id == &"guardian" else 0)


func _shield_recharge() -> float:
	if _chassis_id != &"guardian":
		return Upgrades.shield_recharge()
	var base := Upgrades.shield_recharge() if Upgrades.level_of(&"shield") > 0 else BARRIER_RECHARGE
	return base * BARRIER_FASTER


## Robots never block the mech (its mask is walls + scenery only), and a boss's art is far bigger than
## its body, so a melee mech used to walk right on top of VULCAN / Ronin / Shogun. Outside a boost the
## mech is now held at the boss's edge (its `keep_out`, else BOSS_EDGE x its hit radius); boosting
## (and melee dash steps) still pass through.
const BOSS_EDGE := 0.8


func _keep_off_bosses() -> void:
	for b in get_tree().get_nodes_in_group("boss"):
		var boss := b as Node2D
		if boss == null or not boss.is_inside_tree() or boss.get("dead") == true:
			continue
		var r = boss.get("hit_radius")
		var ko = boss.get("keep_out")
		var edge := float(ko) if ko != null and float(ko) > 0.0 else (float(r) if r != null else 60.0) * BOSS_EDGE
		var min_d := edge + hit_radius * 0.6
		var off := global_position - boss.global_position
		var d := off.length()
		if d >= min_d:
			continue
		var out := off / d if d > 0.5 else -aim_dir
		move_and_collide(out * (min_d - d))


## Chassis boost tricks: the Striker's AFTERBURNER slices every robot it boosts through; the Bulwark's
## SHOULDER RAM smashes them aside. Each robot is hit once per boost.
func _boost_contact() -> void:
	var id: StringName = _chassis.get("id", &"standard")
	if id != &"striker" and id != &"bulwark":
		return
	var col: Color = _chassis["color"]
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.dead or _boost_hits.has(e.get_instance_id()):
			continue
		if e.global_position.distance_to(global_position) > hit_radius + e.hit_radius + 18.0:
			continue
		_boost_hits.append(e.get_instance_id())
		if id == &"striker":
			e.take_damage(32.0 * Upgrades.damage_mult(), global_position, self)
			Combat.spark(e.global_position, col, 1.3)
			Combat.hitstop(0.04)
		else:
			e.take_damage(24.0 * Upgrades.damage_mult(), global_position, self)
			e.knock(_boost_dir * 1100.0)
			Combat.shockwave(e.global_position, 70.0, col, 0.25)
			Combat.shake(0.25)
			Combat.hitstop(0.06)
		Sfx.play(&"hit", -6.0, 0.1)


func _heat_nova() -> void:
	if heat < nova_cost:
		_deny()
		return
	heat -= nova_cost
	Combat.area_damage(global_position, nova_radius, nova_damage * Upgrades.damage_mult() * Upgrades.ability_damage_mult(),
		self, false, Vector2.ZERO, PI, 520.0)
	Combat.shockwave(global_position, nova_radius, Color(1.0, 0.5, 0.15))
	Combat.shockwave(global_position, nova_radius * 0.6, Color(1.0, 0.85, 0.4), 0.25)
	Sfx.play(&"nova", -2.0)
	Combat.shake(0.3)
	stats_changed.emit()


func _magma_cone() -> void:
	if heat < cone_cost:
		_deny()
		return
	heat -= cone_cost
	Combat.area_damage(global_position, cone_range, cone_damage * Upgrades.damage_mult() * Upgrades.ability_damage_mult(),
		self, false, aim_dir, deg_to_rad(35.0), 320.0)
	var cone := Node2D.new()
	cone.set_script(preload("res://player/weapons/cone_fx.gd"))
	cone.set("origin", global_position)
	cone.set("dir", aim_dir)
	cone.set("reach", cone_range)
	get_parent().add_child(cone)
	Sfx.play(&"cone", -4.0)
	Combat.shake(0.2)
	stats_changed.emit()


func _self_repair() -> void:
	if repair_charges <= 0 or hp >= max_hp or _repair_cd > 0.0:
		_deny()
		return
	repair_charges -= 1
	_repair_cd = 1.0
	var amount := repair_amount * Game.diff("heal") * (1.0 + Game.hangar_mk_bonus(&"kits"))
	hp = minf(hp + amount, max_hp)
	Combat.shockwave(global_position, 80.0, Color(0.4, 1.0, 0.5), 0.4)
	Combat.damage_number(global_position, amount, Color(0.5, 1.0, 0.6), self)
	Sfx.play(&"repair", -4.0)
	stats_changed.emit()


func _activate_overdrive() -> void:
	if overdrive_meter < 100.0 or overdrive_left > 0.0:
		_deny()
		return
	overdrive_meter = 0.0
	overdrive_left = overdrive_time
	Combat.shockwave(global_position, 140.0, Color(1.0, 0.85, 0.3), 0.45)
	Sfx.play(&"overdrive", -2.0, 0.0)
	Radio.say(&"overdrive")
	stats_changed.emit()


func _deny() -> void:
	Sfx.play(&"deny", -10.0, 0.0)


## Touch SIMPLE layout's HEAT button: Heat Nova when two or more robots (or a boss) are inside its
## radius, otherwise Magma Cone at the aim.
func _smart_heat() -> void:
	var close := Combat.enemies_in_area(global_position, nova_radius)
	var boss_close := close.any(func(n: Node) -> bool: return n.is_in_group("boss"))
	if heat >= nova_cost and (close.size() >= 2 or boss_close):
		_heat_nova()
	else:
		_magma_cone()


## MICRO-MISSILE POD volley: small homing missiles fanned out of the shoulders.
func _fire_missiles() -> void:
	var n := Upgrades.missile_count()
	for i in n:
		var dir := aim_dir.rotated(lerpf(-1.1, 1.1, (i + 0.5) / n) + randf_range(-0.15, 0.15))
		var b := Combat.fire(global_position + dir * 18.0, dir * 480.0, 18.0 * Upgrades.damage_mult(), true, self,
			Upgrades.color(&"missile_pod"), 0.85, 1.6)
		b.homing = 8.0
		b.explosive = 0.5
	Sfx.play(&"missile", -14.0, 0.1)


## Bulwark SIEGE MODE: braces after standing still a moment, unbraces the instant it moves or boosts.
func _update_siege(delta: float, move: Vector2) -> void:
	if _chassis.get("id") != &"bulwark":
		return
	if move.length() < 0.15 and _boost_left <= 0.0:
		_still_t += delta
	else:
		_still_t = 0.0
	var was := siege_k
	siege_k = move_toward(siege_k, 1.0 if _still_t >= SIEGE_DELAY else 0.0, delta * (4.0 if _still_t >= SIEGE_DELAY else 8.0))
	if was < 1.0 and siege_k >= 1.0:
		Combat.shockwave(global_position, 70.0, Color(1.0, 0.65, 0.3), 0.3)
		Sfx.play(&"slam", -16.0, 0.0)


## ARC EMITTER / STORM BITS: lightning jumps from `from` to up to `jumps` other robots nearby.
func arc_from(from: Variant, hit_damage: float, jumps: int) -> void:
	if _arcing or not is_instance_valid(from) or not (from is Node2D):
		return
	_arcing = true
	var start: Vector2 = (from as Node2D).global_position
	var hit: Array[Node] = [from]
	var col := Upgrades.color(&"chain")
	for i in jumps:
		var best: Node2D = null
		var best_d := ARC_RANGE
		for e in Combat.enemies_in_area(start, ARC_RANGE):
			if hit.has(e) or not (e is Node2D):
				continue
			var d := start.distance_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		var fx: Node2D = ARC_FX.new()
		fx.from = start
		fx.to = best.global_position
		fx.color = col
		Combat.world().add_child(fx)
		best.take_damage(hit_damage * ARC_SHARE, start, self)
		hit.append(best)
		start = best.global_position
	_arcing = false


## Stats that come from upgrades but live on the mech (so the HUD's bars and ticks follow them).
func _refresh_upgrade_stats() -> void:
	overdrive_time = _base_od_time + Upgrades.od_bonus_time()
	nova_cost = roundf(_base_nova_cost * Upgrades.ability_cost_mult())
	cone_cost = roundf(_base_cone_cost * Upgrades.ability_cost_mult())


## Heat + overdrive build from damage this mech deals. On-hit upgrades roll here too: ARC EMITTER
## (lightning to nearby robots) and CRYO ROUNDS (chill).
func _on_damage_dealt(amount: float, source: Node, target: Node) -> void:
	if source != self:
		return
	var gain := Upgrades.heat_mult()
	heat = minf(heat + amount * heat_per_damage * gain, heat_max)
	if overdrive_left <= 0.0:
		var iaido := IAIDO_OD if _chassis_id == &"duelist" and Game.is_melee(weapon) else 1.0
		overdrive_meter = minf(overdrive_meter + amount * overdrive_per_damage * gain * Upgrades.od_gain() * iaido, 100.0)
	if not _arcing and randf() < Upgrades.chain_chance():
		arc_from(target, amount, Upgrades.level_of(&"chain"))
	if randf() < Upgrades.cryo_chance() and target.has_method("chill"):
		target.chill(2.0)
	stats_changed.emit()


## Salvage Repair: kills patch the armor up. Striker AFTERBURNER: kills recharge the boost.
## SHATTER combo: chilled robots burst into a freezing blast.
func _on_enemy_killed(e: Node) -> void:
	var h := Upgrades.salvage_heal() * Game.diff("heal")
	if h > 0.0 and not dead and hp < max_hp:
		hp = minf(hp + h, max_hp)
		stats_changed.emit()
	if _chassis.get("id") == &"striker" and boost_cooldown_left > 0.0:
		boost_cooldown_left = maxf(boost_cooldown_left - STRIKER_KILL_REFUND, 0.0)
	# FROSTBLADE IAIDO: melee kills patch the armor; CORVID FEATHER SWARM: kills may loose homing feathers.
	if _chassis_id == &"duelist" and Game.is_melee(weapon) and not dead and hp < max_hp:
		hp = minf(hp + IAIDO_HEAL * Game.diff("heal"), max_hp)
		stats_changed.emit()
	if _chassis_id == &"carrier" and e is Node2D and not dead and randf() < FEATHER_CHANCE:
		_fire_feathers.call_deferred((e as Node2D).global_position)
	if Upgrades.level_of(&"shatter") > 0 and e is Enemy and (e as Enemy).chill_t > 0.0 and not dead:
		var at: Vector2 = (e as Enemy).global_position
		var dmg := 60.0 * Upgrades.damage_mult()
		(func() -> void:
			for n in Combat.enemies_in_area(at, 110.0):
				n.take_damage(dmg, at, self)
				if n.has_method("chill"):
					n.chill(2.0)
			Combat.shockwave(at, 110.0, Enemy.ICE, 0.3)
			Combat.burst(at, Enemy.ICE, 320.0, 1.1)
			Sfx.play(&"freeze", -10.0, 0.1)).call_deferred()


## CORVID FEATHER SWARM: homing feather blades from the backpack toward the robots near a kill.
func _fire_feathers(at: Vector2) -> void:
	if dead:
		return
	var col: Color = _chassis["color"]
	for i in FEATHERS:
		var target := Combat.nearest_enemy(at, 420.0) as Node2D
		var aim := (target.global_position - global_position).normalized() if target else aim_dir
		var dir := aim.rotated(randf_range(-0.6, 0.6))
		var b := Combat.fire(global_position - aim_dir * 10.0, dir * 520.0, 16.0 * Upgrades.damage_mult(), true, self,
			col, 0.8, 1.4)
		b.homing = 9.0
	Sfx.play(&"missile", -16.0, 0.15)


## SOLSTICE BARRIER: a breaking shield charge blasts the robots around the mech back.
func _barrier_blast() -> void:
	var col: Color = _chassis["color"]
	Combat.area_damage(global_position, 150.0, BARRIER_BLAST * Upgrades.damage_mult(), self, false, Vector2.ZERO, PI, 620.0)
	Combat.shockwave(global_position, 150.0, col, 0.35)
	Combat.shockwave(global_position, 90.0, Color(1, 1, 1, 0.8), 0.2)


## A level-up pick was made: apply the one-off parts (the rest is read live from Upgrades).
func _on_upgrade(id: StringName) -> void:
	match id:
		&"armor":
			max_hp = _base_max_hp + Upgrades.max_hp_bonus()
			heal(25.0)
		&"shield":
			shield_charges = mini(shield_charges + 1, _shield_max())
		&"field_repair":
			heal(40.0)
			add_repair_charge()
	_refresh_upgrade_stats()
	Combat.shockwave(global_position, 110.0, Upgrades.color(id), 0.4)
	stats_changed.emit()


## Brief invulnerability (e.g. right after the level-up menu closes).
func grant_invuln(t: float) -> void:
	_invuln = maxf(_invuln, t)


# --- damage ----------------------------------------------------------------------------------------

func take_damage(amount: float, _from_pos: Vector2, _source: Node = null) -> void:
	if dead or _invuln > 0.0 or _falling > 0.0:
		return
	# Defense Shield: a charge soaks the whole hit.
	if shield_charges > 0:
		shield_charges -= 1
		_shield_t = _shield_recharge()
		_invuln = 0.5
		_shield_fx.pop()
		if _chassis_id == &"guardian":
			_barrier_blast.call_deferred()
		Combat.shockwave(global_position, 80.0, Color(0.5, 0.9, 1.0), 0.3)
		Sfx.play(&"shield", -4.0, 0.0)
		stats_changed.emit()
		return
	_apply_damage(amount * float(_chassis.get("taken", 1.0)) * lerpf(1.0, SIEGE_TAKEN, siege_k))
	_invuln = maxf(_invuln, 0.4)
	# REACTIVE ARMOR: getting hit discharges a blast around the mech.
	if not dead and Upgrades.reactive_damage() > 0.0 and _reactive_cd <= 0.0:
		_reactive_cd = 1.0
		var dmg := Upgrades.reactive_damage() * Upgrades.damage_mult()
		(func() -> void:
			Combat.area_damage(global_position, 150.0, dmg, self, false, Vector2.ZERO, PI, 480.0)
			Combat.shockwave(global_position, 150.0, Upgrades.color(&"reactive"), 0.3)
			Combat.spark(global_position, Upgrades.color(&"reactive"), 2.0)).call_deferred()


## OVERCLOCK combo: fire rate rises with heat (up to +40% at full heat).
func _overclock() -> float:
	if Upgrades.level_of(&"overclock") <= 0:
		return 1.0
	return 1.0 + 0.4 * clampf(heat / heat_max, 0.0, 1.0)


func _apply_damage(amount: float) -> void:
	_since_hit = 0.0
	hp -= amount
	_flash = 1.0
	Combat.damage_number(global_position, amount, Color(1, 0.35, 0.3), self)
	Combat.shake(0.35)
	Combat.rumble(0.55, 0.35, 0.16)
	Sfx.play(&"hurt", -4.0)
	stats_changed.emit()
	# Hangar LAST STAND: once per arena, a fatal hit leaves 1 HP and a moment of invulnerability.
	if hp <= 0.0 and not _last_stand_used and Game.hangar_level(&"last_stand") > 0:
		_last_stand_used = true
		hp = maxf(1.0, max_hp * Game.hangar_mk_bonus(&"last_stand"))
		_invuln = 1.6
		Combat.shockwave(global_position, 220.0, Color(1.0, 0.85, 0.3), 0.5)
		Combat.slowmo(0.3, 0.8)
		Sfx.play(&"shield", 0.0, 0.0)
		Radio.say(&"last_stand", true)
		stats_changed.emit()
		return
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
	body.scale = Vector2.ONE * lerpf(1.0, 0.25, k) * _body_scale
	body.modulate.a = 1.0 - k
	body.rotation += delta * 6.0
	if _falling <= 0.0:
		_falling = 0.0
		body.scale = Vector2.ONE * _body_scale
		body.modulate.a = 1.0
		global_position = _safe_pos
		_apply_damage(PIT_DAMAGE)
		_invuln = 1.0
		if not dead:
			Combat.shockwave(global_position, 70.0, Color(0.4, 0.8, 1.0), 0.3)


func is_falling() -> bool:
	return _falling > 0.0


# --- pickups / stations ------------------------------------------------------------------------------

## Every repair source goes through here (scaled by the difficulty's "heal", e.g. Extreme 0.6).
func heal(amount: float) -> void:
	amount *= Game.diff("heal")
	hp = minf(hp + amount, max_hp)
	Combat.damage_number(global_position, amount, Color(0.5, 1.0, 0.6), self)
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


## Hits and explosions don't push the Gundam around (it holds its ground).
func knock(_impulse: Vector2) -> void:
	pass


## The Gundam's own weapon recoil (scatter shot, beam cannon) - not caused by taking damage.
func recoil(impulse: Vector2) -> void:
	if not Parts.has_perk(&"steady"):  # PARTS STEADY (Gunner Arms): no recoil
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
	# Torso turns to the aim independently of movement (sprite faces "up" at rotation 0), plus the twist
	# of a melee swing (the body winds up and turns through the cut).
	body.rotation = lerp_angle(body.rotation, aim_dir.angle() + PI / 2 + swing_twist, 1.0 - exp(-22.0 * delta))
	var anim := &"idle"
	if _boost_left > 0.0:
		anim = &"dash"
	elif move.length() > 0.2:
		var local := move.rotated(-body.rotation)
		anim = &"bank_left" if local.x < -0.55 else (&"bank_right" if local.x > 0.55 else &"boost")
	elif Controls.is_firing():
		anim = &"fire"
	# The sprite's painted rifle only shows with the Beam Rifle; every other weapon is drawn in the fist
	# (HeldWeapon for guns, the melee rig for blades) on the rifle-free frames.
	var frames: SpriteFrames = _frames_gun if weapon == &"blaster" else _frames_nogun
	if sprite.sprite_frames != frames:
		var f := sprite.frame
		var p := sprite.frame_progress
		sprite.sprite_frames = frames
		sprite.play(anim)
		sprite.set_frame_and_progress(f, p)
	if sprite.animation != anim:
		sprite.play(anim)
	held.sync(weapon, delta, Controls.is_firing())
	for t in thrusters:
		t.amount_ratio = 1.0 if move.length() > 0.2 or _boost_left > 0.0 else 0.4
	sprite.position = sprite.position.lerp(Vector2.ZERO, 1.0 - exp(-30.0 * delta))
	_muzzle_t -= delta
	muzzle_flash.visible = _muzzle_t > 0.0
	if weapon != &"gatling":
		muzzle_flash.scale = Vector2.ONE * DEFAULT_FLASH_SCALE
		muzzle_flash.modulate = Game.energy_color()
	if muzzle_flash.visible:
		muzzle_flash.rotation = randf() * TAU
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	(sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	aura.visible = overdrive_left > 0.0
	if aura.visible:
		aura.scale = Vector2.ONE * (2.3 + sin(Time.get_ticks_msec() * 0.02) * 0.15)
	ring.queue_redraw()


func _spawn_afterimage() -> void:
	_spawn_afterimage_at(sprite.global_position, Color(Game.booster_color(), 0.5))


func _spawn_afterimage_at(at: Vector2, col: Color) -> void:
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.global_position = at
	ghost.rotation = body.rotation
	ghost.scale = sprite.scale * _body_scale
	ghost.modulate = col
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.tween_callback(ghost.queue_free)


## Fraction of the boost cooldown that has recharged (1 = ready). Used by the ring + HUD.
func boost_ready_fraction() -> float:
	if _boost_spare > 0:  # (PARTS DOUBLE DASH: a spare boost is ready)
		return 1.0
	return 1.0 - boost_cooldown_left / maxf(_boost_cd(), 0.01)


## Boost cooldown after the Thrusters upgrade and the chassis.
func _boost_cd() -> float:
	return boost_cooldown * Upgrades.boost_cd_mult() * float(_chassis.get("boost_cd", 1.0)) * Game.twist_value("boost_cd")


## PARTS (autoload/parts.gd, Hangar > PARTS): what the mech takes from its parts once, at spawn - HP, dash,
## handling and DOUBLE DASH's spare boost - and the BACKPACK's thruster flames (colour + size). Speed, fire
## rate, damage, crit, heat and pickup radius are read live (Upgrades / _weapon_rate).
func _apply_parts() -> void:
	_base_max_hp *= Parts.mult("hp")
	max_hp = _base_max_hp + Upgrades.max_hp_bonus()
	hp = max_hp
	boost_speed *= Parts.mult("dash")
	acceleration *= Parts.mult("accel")
	_boost_spares_max = Parts.extra_boosts()
	_boost_spare = _boost_spares_max
	var f := Parts.flame()
	if not f.is_empty():
		for t in thrusters:
			t.modulate = Game.booster_color().lerp(f["color"], 0.65).lightened(0.25)
			t.scale = Vector2.ONE * float(f["scale"])
