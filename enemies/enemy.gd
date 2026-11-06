class_name Enemy
extends CharacterBody2D
## Base class for all enemies: health, hit flash, knockback, pathfinding (NavigationAgent2D over the
## arena's baked navmesh, direct steering when there's line of sight), contact damage and death FX.
## Subclasses override `_think(delta)` to set `desired_velocity` / `facing`, and `_draw()` for art.
##
## Collision: body on layer 9 "enemy_bodies" (collides with walls, cover, pits and other enemies);
## a child Hurtbox area on layer 3 "enemies" is what player bullets hit.

signal died(enemy: Enemy)

@export var max_hp := 60.0
@export var move_speed := 160.0
@export var acceleration := 1400.0
@export var contact_damage := 10.0
@export var hit_radius := 22.0
## Multiplied into max_hp / damage by encounter zones for later waves and harder arenas.
@export var damage_mult := 1.0

var hp := 0.0
var target: Mech
var desired_velocity := Vector2.ZERO
var facing := Vector2.DOWN
var dead := false
var _flash := 0.0
var _knock := Vector2.ZERO
var _contact_cd := 0.0
var _hp_bar_t := 0.0
var _t := 0.0
var _spawn_t := 0.5
var _agent: NavigationAgent2D
var _repath_t := 0.0
## Armor layer (tank-type enemies, see set_armor): soaks damage before HP.
var armor := 0.0
var max_armor := 0.0
var armor_tier := 0
const ARMOR_NUMBER := Color(0.7, 0.85, 1.0)
const TRIPLE_ARMOR_TINT := Color(0.55, 0.8, 1.5)
## Bastion ward (enemies/bastion.gd): while `ward_t` > 0 this enemy takes WARD_MULT damage. A Bastion
## keeps refreshing it on allies in range, so the ward drops soon after the Bastion dies.
const WARD_MULT := 0.5
var ward_t := 0.0
## ELITE (Extreme difficulty, see make_elite): tougher, faster, harder-hitting, gold aura, more XP.
const ELITE_GOLD := Color(1.0, 0.8, 0.25)
var elite := false
## Tank-type armor size as a fraction of max HP (encounter zones give early waves less; see set_armor).
var armor_fraction := 1.0
## CRYO ROUNDS upgrade: seconds left chilled (slowed, icy tint). Bosses shrug most of it off.
var chill_t := 0.0
const CHILL_SLOW := 0.6
const CHILL_SLOW_BOSS := 0.85
const ICE := Color(0.6, 0.9, 1.0)
## CRITICAL TARGETING: crit numbers are gold.
const CRIT_NUMBER := Color(1.0, 0.92, 0.3)


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemies")
	collision_layer = 256
	collision_mask = 1 | 32 | 64 | 256
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	hp = max_hp
	var body_shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = hit_radius * 0.8
	body_shape.shape = c
	add_child(body_shape)
	var hurt := Area2D.new()
	hurt.name = "Hurtbox"
	hurt.collision_layer = 4
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape2D.new()
	var hc := CircleShape2D.new()
	hc.radius = hit_radius
	hs.shape = hc
	hurt.add_child(hs)
	add_child(hurt)
	_agent = NavigationAgent2D.new()
	_agent.path_desired_distance = 28.0
	_agent.target_desired_distance = 28.0
	_agent.radius = hit_radius
	add_child(_agent)
	_t = randf() * 10.0
	Combat.shockwave(global_position, hit_radius * 3.0, Color(1.0, 0.3, 0.4), 0.4)
	if elite:
		var aura := EliteAura.new()
		aura.radius = hit_radius
		add_child(aura)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_contact_cd -= delta
	_hp_bar_t -= delta
	_spawn_t -= delta
	ward_t -= delta
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Mech
	desired_velocity = Vector2.ZERO
	if target and not target.dead and _spawn_t <= 0.0:
		_think(delta)
	if chill_t > 0.0:
		chill_t -= delta
		desired_velocity *= CHILL_SLOW_BOSS if is_in_group("boss") else CHILL_SLOW
	velocity = velocity.move_toward(desired_velocity, acceleration * delta) + _knock
	_knock = _knock.lerp(Vector2.ZERO, 1.0 - exp(-10.0 * delta))
	move_and_slide()
	velocity -= _knock
	if target and not target.dead and contact_damage > 0.0 and _contact_cd <= 0.0 \
			and global_position.distance_to(target.global_position) < hit_radius + 24.0:
		_contact_cd = 0.8
		target.take_damage(contact_damage * damage_mult, global_position, self)
	queue_redraw()


## Override: decide movement (`desired_velocity`), `facing`, and attacks.
func _think(_delta: float) -> void:
	pass


# --- helpers for subclasses --------------------------------------------------------------------------

func dist_to_target() -> float:
	return global_position.distance_to(target.global_position)


func dir_to_target() -> Vector2:
	return (target.global_position - global_position).normalized()


func has_line_of_sight(to: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, to, 1 | 32)
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


## Steer toward a point: straight line when visible, navmesh path otherwise.
func steer_to(point: Vector2, speed := -1.0) -> void:
	if speed < 0.0:
		speed = move_speed
	var dir: Vector2
	if has_line_of_sight(point):
		dir = (point - global_position).normalized()
	else:
		_repath_t -= get_physics_process_delta_time()
		if _repath_t <= 0.0 or _agent.target_position.distance_to(point) > 96.0:
			_repath_t = 0.3
			_agent.target_position = point
		dir = (_agent.get_next_path_position() - global_position).normalized()
	desired_velocity = dir * speed


func shoot(dir: Vector2, speed: float, damage: float, color := Color(1.0, 0.35, 0.55), size := 1.1) -> void:
	Combat.fire(global_position + dir * (hit_radius + 6.0), dir * speed, damage * damage_mult, false, self, color, size, 2.5)


# --- damage ------------------------------------------------------------------------------------------

func take_damage(amount: float, _from_pos: Vector2, source: Node = null) -> void:
	if dead:
		return
	_flash = 1.0
	_hp_bar_t = 2.0
	if ward_t > 0.0:
		amount *= WARD_MULT
		Combat.spark(global_position, Color(0.3, 1.0, 0.6), 0.6)
	# CRITICAL TARGETING: the player's hits sometimes land double (EXECUTIONER: and finish off the weak).
	var crit := false
	if source != null and is_instance_valid(source) and source.is_in_group("player") and randf() < Upgrades.crit_chance():
		crit = true
		amount *= 2.0
		if Upgrades.level_of(&"executioner") > 0 and not is_in_group("boss") and hp - amount < max_hp * 0.25:
			amount = maxf(amount, hp + armor * armor_tier)
			Combat.shockwave(global_position, hit_radius * 2.0, CRIT_NUMBER, 0.25)
		Combat.spark(global_position, CRIT_NUMBER, 1.2)
	Combat.report_damage(amount, source, self)
	# Armor soaks hits first: each point of armor absorbs `armor_tier` points of damage, so stripping
	# it takes 2x / 3x the hits of the same amount of HP. Leftover damage carries into HP.
	if armor > 0.0:
		var absorbed := minf(armor, amount / armor_tier)
		armor -= absorbed
		amount -= absorbed * armor_tier
		Combat.damage_number(global_position, absorbed * armor_tier, ARMOR_NUMBER, self)
		if armor <= 0.0:
			Combat.burst(global_position, Color(0.75, 0.8, 0.9), 320.0, 1.4)
			Combat.shockwave(global_position, hit_radius * 2.2, Color(0.7, 0.85, 1.0), 0.3)
			Sfx.play(&"shield", -4.0, 0.0)
		if amount <= 0.001:
			return
	hp -= amount
	Combat.damage_number(global_position, amount, CRIT_NUMBER if crit else Color(1, 0.85, 0.6), self)
	if hp <= 0.0:
		die()


## CRYO ROUNDS: slowed and frosted for `seconds`.
func chill(seconds: float) -> void:
	if dead:
		return
	if chill_t <= 0.0:
		Combat.spark(global_position, ICE, hit_radius / 18.0)
	chill_t = maxf(chill_t, seconds)


## Gives this enemy an armor layer: `tier` 2 or 3 (2x / 3x the hits of its HP to strip). Call after its
## max_hp is final (difficulty / wave scaling); armor is `armor_fraction` of max_hp in size.
func set_armor(tier: int) -> void:
	armor_tier = tier
	max_armor = max_hp * armor_fraction
	armor = max_armor


## Makes this an ELITE (call before it enters the tree, after difficulty / wave scaling): x2 HP,
## +15% speed, +30% damage, a pulsing gold aura, and it's worth 2.5x XP (Upgrades.xp_value).
func make_elite() -> void:
	elite = true
	max_hp *= 2.0
	move_speed *= 1.15
	damage_mult *= 1.3


## Body tint for armored enemies: triple armor reads as cold hardened steel.
func armor_tint() -> Color:
	return TRIPLE_ARMOR_TINT if armor_tier >= 3 and armor > 0.0 else Color.WHITE


func knock(impulse: Vector2) -> void:
	_knock += impulse * 0.6


## Coloured plates in each robot's debris (the rest is gunmetal + embers).
const DEBRIS_TINTS := {
	&"Chaser": Color(0.7, 0.35, 0.2), &"Shooter": Color(0.75, 0.3, 0.25), &"HeavyTank": Color(0.85, 0.45, 0.15),
	&"BladeStriker": Color(0.7, 0.15, 0.2), &"AegisGuardian": Color(0.55, 0.5, 0.25), &"Lancer": Color(0.85, 0.88, 0.9),
	&"Hornet": Color(0.2, 0.4, 0.95), &"Coil": Color(0.8, 0.8, 0.85), &"Widow": Color(0.15, 0.15, 0.15),
	&"Cinder": Color(0.3, 0.3, 0.32), &"Bastion": Color(0.15, 0.6, 0.35), &"Tidebreaker": Color(0.15, 0.25, 0.6),
	&"MagmaCrawler": Color(1.0, 0.4, 0.1), &"Anvil": Color(0.45, 0.45, 0.5), &"Slagspitter": Color(0.95, 0.7, 0.2),
}


func die() -> void:
	if dead:
		return
	dead = true
	Combat.explosion_fx(global_position, hit_radius * 3.2, Color(1.0, 0.5, 0.2))
	# Hit feel: metal debris for everyone; a split-second freeze for big robots and elites.
	var tint: Color = ELITE_GOLD if elite else DEBRIS_TINTS.get(get_script().get_global_name(), Color(0.7, 0.45, 0.3))
	Combat.debris(global_position, hit_radius, tint)
	if hit_radius >= 40.0 or elite:
		Combat.hitstop(0.07 if hit_radius >= 55.0 else 0.05)
	Combat.report_kill(self)
	died.emit(self)
	queue_free()


## Shared HP bar (shown briefly after taking damage).
## Armored enemies always show their bars: armor (steel blue, with a pip per tier) above HP.
func draw_hp_bar(y: float) -> void:
	var armored := max_armor > 0.0
	if not armored and (_hp_bar_t <= 0.0 or hp >= max_hp):
		return
	var w := hit_radius * 2.2
	draw_rect(Rect2(-w / 2, y, w, 5), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0.0, 1.0), 5), Color(1.0, 0.35, 0.3))
	if armored:
		var ay := y - 8.0
		var col := Color(0.55, 0.8, 1.0) if armor_tier >= 3 else Color(0.78, 0.82, 0.9)
		draw_rect(Rect2(-w / 2 - 1, ay - 1, w + 2, 7), Color(0, 0, 0, 0.7))
		if armor > 0.0:
			draw_rect(Rect2(-w / 2, ay, w * clampf(armor / max_armor, 0.0, 1.0), 5), col.lerp(Color.WHITE, _flash * 0.5))
		# Tier pips (2 or 3) at the bar's left end.
		for i in armor_tier:
			draw_rect(Rect2(-w / 2 - 6 - i * 5, ay, 3, 5), col)


## Tint helper: flash to white when hit (frosted blue while chilled).
func tint(c: Color) -> Color:
	if chill_t > 0.0:
		c = c * ICE.lerp(Color.WHITE, 0.2)
	return c.lerp(Color.WHITE, _flash * 0.7)


## Elite marker: a pulsing gold ring under the robot, gold sparks rising off it, and a small crown of
## chevrons above its health bar (drawn as a child so every enemy type gets it for free).
class EliteAura:
	extends Node2D
	var radius := 24.0
	var _t := 0.0

	func _ready() -> void:
		z_index = -1
		_t = randf() * 5.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		var g := Enemy.ELITE_GOLD
		var r := radius * 1.55
		draw_circle(Vector2.ZERO, r, Color(g, 0.1 + 0.08 * pulse))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(g, 0.55 + 0.35 * pulse), 3.0, true)
		draw_arc(Vector2.ZERO, r + 6.0, _t * 1.5, _t * 1.5 + 2.0, 16, Color(g, 0.6), 2.0, true)
		draw_arc(Vector2.ZERO, r + 6.0, _t * 1.5 + PI, _t * 1.5 + PI + 2.0, 16, Color(g, 0.6), 2.0, true)
		for i in 6:
			var k := fmod(_t * 0.6 + i / 6.0, 1.0)
			var p := Vector2(sin(i * 2.4 + _t) * r * 0.7, r * 0.3 - k * r * 1.6)
			draw_circle(p, 2.5 * (1.0 - k) + 1.0, Color(1.0, 0.9, 0.5, 0.8 * (1.0 - k)))
		# Crown of chevrons above the robot.
		var top := Vector2(0, -r - 16.0)
		for i in 3:
			var x := (i - 1) * 10.0
			var h := 7.0 if i == 1 else 5.0
			draw_colored_polygon(PackedVector2Array([top + Vector2(x - 4, 0), top + Vector2(x, -h), top + Vector2(x + 4, 0)]),
				Color(g, 0.9))
