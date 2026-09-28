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


func _physics_process(delta: float) -> void:
	if dead:
		return
	_t += delta
	_contact_cd -= delta
	_hp_bar_t -= delta
	_spawn_t -= delta
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Mech
	desired_velocity = Vector2.ZERO
	if target and not target.dead and _spawn_t <= 0.0:
		_think(delta)
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
	Combat.damage_number(global_position, amount, Color(1, 0.85, 0.6), self)
	if hp <= 0.0:
		die()


## Gives this enemy an armor layer: `tier` 2 or 3 (2x / 3x the hits of its HP to strip). Call after its
## max_hp is final (difficulty / wave scaling); armor matches max_hp in size.
func set_armor(tier: int) -> void:
	armor_tier = tier
	max_armor = max_hp
	armor = max_armor


## Body tint for armored enemies: triple armor reads as cold hardened steel.
func armor_tint() -> Color:
	return TRIPLE_ARMOR_TINT if armor_tier >= 3 and armor > 0.0 else Color.WHITE


func knock(impulse: Vector2) -> void:
	_knock += impulse * 0.6


func die() -> void:
	if dead:
		return
	dead = true
	Combat.explosion_fx(global_position, hit_radius * 3.2, Color(1.0, 0.5, 0.2))
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


## Tint helper: flash to white when hit.
func tint(c: Color) -> Color:
	return c.lerp(Color.WHITE, _flash * 0.7)
