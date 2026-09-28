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
## Heat and overdrive both build up from damage the mech deals.
## Level-up upgrades (autoload/upgrades.gd) are read live from Upgrades: stat multipliers, Triple Shot,
## Target Lock, Defense Shield, Orbit Blades, Salvage Repair...

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
var _shield_fx: Node2D

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
	_base_max_hp = max_hp
	max_hp = _base_max_hp + Upgrades.max_hp_bonus()
	hp = max_hp
	repair_charges = repair_charges_max
	shield_charges = Upgrades.shield_max()
	Combat.damage_dealt.connect(_on_damage_dealt)
	Combat.enemy_killed.connect(_on_enemy_killed)
	Upgrades.upgrade_applied.connect(_on_upgrade)
	var blades: Node2D = ORBIT_BLADES.new()
	blades.mech = self
	add_child(blades)
	_shield_fx = SHIELD_BUBBLE.new()
	_shield_fx.mech = self
	add_child(_shield_fx)
	stats_changed.emit.call_deferred()
	_safe_pos = global_position
	# Gundam Customization: armor paint (shader), energy (shots + muzzle), booster (thrusters).
	sprite.material = (sprite.material as ShaderMaterial).duplicate()
	Game.apply_armor(sprite.material)
	muzzle_flash.modulate = Game.energy_color()
	for t in thrusters:
		t.modulate = Game.booster_color().lightened(0.25)
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
	if weapon == &"gatling" and Input.is_action_pressed("fire_primary"):
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

	# Weapons.
	var od := overdrive_left > 0.0
	var dmg := Upgrades.damage_mult() * (1.5 if od else 1.0)
	if Input.is_action_pressed("fire_primary") and _fire_cd <= 0.0 and _boost_left <= 0.0 and not beam.is_busy():
		_fire_cd = 1.0 / (_weapon_rate() * Upgrades.fire_rate_mult() * (2.0 if od else 1.0))
		_fire_primary(dmg)
	if Input.is_action_pressed("fire_secondary") and _secondary_cd <= 0.0 and _boost_left <= 0.0 and not beam.is_busy():
		_secondary_cd = secondary_cooldown * (0.6 if od else 1.0)
		_fire_secondary(dmg)

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
	# Defense Shield: recharge one charge at a time.
	if shield_charges < Upgrades.shield_max():
		_shield_t -= delta
		if _shield_t <= 0.0:
			_shield_t = Upgrades.shield_recharge()
			shield_charges += 1
			Combat.shockwave(global_position, 60.0, Color(0.45, 0.85, 1.0), 0.3)
			stats_changed.emit()
	else:
		_shield_t = Upgrades.shield_recharge()
	if overdrive_left > 0.0:
		overdrive_left = maxf(overdrive_left - delta, 0.0)
		if overdrive_left == 0.0:
			stats_changed.emit()


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


func _weapon_rate() -> float:
	if MeleeKit.has_weapon(weapon):
		return MeleeKit.rate(weapon)
	match weapon:
		&"gatling": return GATLING_RATE
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


## Blaster / Gatling: Triple Shot fans extra bolts out to the sides (75% damage each).
func _fire_bolts(mult: float) -> void:
	var gatling := weapon == &"gatling"
	var base := _shot_dir().rotated(randf_range(-0.1, 0.1) if gatling else randf_range(-0.04, 0.04))
	var dmg := (GATLING_DAMAGE if gatling else bolt_damage) * mult
	var n := Upgrades.multishot_count()
	for i in n:
		var off := (i - (n - 1) / 2.0) * 0.16
		var b := Combat.fire(muzzle.global_position, base.rotated(off) * bolt_speed * (1.1 if gatling else 1.0),
			dmg * (1.0 if off == 0.0 else 0.75), true, self, _shot_color(), GATLING_BULLET_SIZE if gatling else 1.0)
		_arm(b)
	_muzzle_t = 0.05
	sprite.position = Vector2(0, 3 if gatling else 4)
	muzzle_flash.scale = Vector2.ONE * (GATLING_FLASH_SCALE * randf_range(0.85, 1.15) if gatling else DEFAULT_FLASH_SCALE)
	if gatling:
		held.kick(0.35)
		Combat.spark(muzzle.global_position + base * 14.0, _shot_color().lightened(0.4), 1.5)
	Sfx.play(&"shoot", -21.0 if gatling else -18.0, 0.12 if gatling else 0.06)


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
	Sfx.play(&"hit", -6.0, 0.05)
	Combat.shake(0.06)


func _try_boost(move: Vector2) -> void:
	if boost_cooldown_left > 0.0 or _boost_left > 0.0:
		return
	_boost_dir = move.normalized() if move.length() > 0.2 else aim_dir
	_boost_left = boost_time
	boost_cooldown_left = _boost_cd() * (0.6 if overdrive_left > 0.0 else 1.0)
	_invuln = boost_time + 0.08
	Sfx.play(&"dash", -6.0)
	stats_changed.emit()


func _heat_nova() -> void:
	if heat < nova_cost:
		_deny()
		return
	heat -= nova_cost
	Combat.area_damage(global_position, nova_radius, nova_damage * Upgrades.damage_mult(), self, false, Vector2.ZERO, PI, 520.0)
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
	Combat.area_damage(global_position, cone_range, cone_damage * Upgrades.damage_mult(), self, false, aim_dir, deg_to_rad(35.0), 320.0)
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
	Combat.damage_number(global_position, repair_amount, Color(0.5, 1.0, 0.6), self)
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
	var gain := Upgrades.heat_mult()
	heat = minf(heat + amount * heat_per_damage * gain, heat_max)
	if overdrive_left <= 0.0:
		overdrive_meter = minf(overdrive_meter + amount * overdrive_per_damage * gain, 100.0)
	stats_changed.emit()


## Salvage Repair: kills patch the armor up.
func _on_enemy_killed(_e: Node) -> void:
	var h := Upgrades.salvage_heal()
	if h > 0.0 and not dead and hp < max_hp:
		hp = minf(hp + h, max_hp)
		stats_changed.emit()


## A level-up pick was made: apply the one-off parts (the rest is read live from Upgrades).
func _on_upgrade(id: StringName) -> void:
	match id:
		&"armor":
			max_hp = _base_max_hp + Upgrades.max_hp_bonus()
			heal(25.0)
		&"shield":
			shield_charges = mini(shield_charges + 1, Upgrades.shield_max())
		&"field_repair":
			heal(40.0)
			add_repair_charge()
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
		_shield_t = Upgrades.shield_recharge()
		_invuln = 0.5
		_shield_fx.pop()
		Combat.shockwave(global_position, 80.0, Color(0.5, 0.9, 1.0), 0.3)
		Sfx.play(&"shield", -4.0, 0.0)
		stats_changed.emit()
		return
	_apply_damage(amount)
	_invuln = 0.4


func _apply_damage(amount: float) -> void:
	hp -= amount
	_flash = 1.0
	Combat.damage_number(global_position, amount, Color(1, 0.35, 0.3), self)
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
	# The sprite's painted rifle only shows with the Beam Rifle; every other weapon is drawn in the fist
	# (HeldWeapon for guns, the melee rig for blades) on the rifle-free frames.
	var frames: SpriteFrames = FRAMES_RIFLE if weapon == &"blaster" else FRAMES_NO_GUN
	if sprite.sprite_frames != frames:
		var f := sprite.frame
		var p := sprite.frame_progress
		sprite.sprite_frames = frames
		sprite.play(anim)
		sprite.set_frame_and_progress(f, p)
	if sprite.animation != anim:
		sprite.play(anim)
	held.sync(weapon, delta, Input.is_action_pressed("fire_primary"))
	for t in thrusters:
		t.amount_ratio = 1.0 if move.length() > 0.2 or _boost_left > 0.0 else 0.4
	sprite.position = sprite.position.lerp(Vector2.ZERO, 1.0 - exp(-30.0 * delta))
	_muzzle_t -= delta
	muzzle_flash.visible = _muzzle_t > 0.0
	if weapon != &"gatling":
		muzzle_flash.scale = Vector2.ONE * DEFAULT_FLASH_SCALE
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
	ghost.modulate = Color(Game.booster_color(), 0.5)
	get_parent().add_child(ghost)
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.2)
	tw.tween_callback(ghost.queue_free)


## Fraction of the boost cooldown that has recharged (1 = ready). Used by the ring + HUD.
func boost_ready_fraction() -> float:
	return 1.0 - boost_cooldown_left / maxf(_boost_cd(), 0.01)


## Boost cooldown after the Thrusters upgrade.
func _boost_cd() -> float:
	return boost_cooldown * Upgrades.boost_cd_mult()
