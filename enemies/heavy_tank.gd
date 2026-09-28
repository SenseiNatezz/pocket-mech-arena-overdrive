class_name HeavyTank
extends Enemy
## "Heavy Tank" (Higgsfield sprite): slow siege robot on four tread pods with a twin heavy cannon and
## shoulder missile pods. It steers like a tank (turns its whole hull slowly, drives forward/reverse),
## shrugs off knockback and flattens cover, crates and barrels it drives into.
## ARMOR: an armor bar above its HP soaks damage first (2x or 3x the hits of its HP; 3x tanks are
## tinted steel-blue - see Enemy.set_armor).
##   Twin cannon   with line of sight at mid range: barrels glow + an aim line for 0.7 s, then two big
##                 slow shells, one per barrel
##   Missile pods  every few seconds lobs telegraphed artillery at where you're heading, even without
##                 line of sight (red circles ~1 s before impact)

const TEX := preload("res://assets/hq/enemies3/heavy_tank.png")
const SPRITE_SCALE := 0.62
## Barrel tips / missile pods in sprite space (sprite faces up), before scaling.
const MUZZLE_L := Vector2(-14, -124)
const MUZZLE_R := Vector2(14, -124)
const POD_L := Vector2(-85, -49)
const POD_R := Vector2(85, -49)
const CANNON := Color(1.0, 0.55, 0.2)
const AIM_TIME := 0.7

@export var preferred_range := Vector2(300, 620)
@export var turn_rate := 1.1
@export var cannon_damage := 16.0
@export var cannon_cooldown := 3.0
@export var missile_damage := 18.0
@export var missile_cooldown := 4.2

var _cannon_cd := 1.5
var _missile_cd := 2.5
var _aim := 0.0
var _recoil := 0.0
var _crush_t := 0.0
var _pod_flash := 0.0


func _ready() -> void:
	super._ready()
	# Armor: 2x or 3x (random, or chosen by the encounter zone - later waves roll 3x more often).
	set_armor(armor_tier if armor_tier > 0 else [2, 3].pick_random())
	facing = Vector2.UP


## Armor: barely moved by hits and explosions.
func knock(impulse: Vector2) -> void:
	_knock += impulse * 0.08


func _think(delta: float) -> void:
	var to_t := dir_to_target()
	var d := dist_to_target()
	var los := has_line_of_sight(target.global_position)
	# Tank steering: the hull turns toward where it wants to go, then drives along it.
	var goal_dir := to_t
	var drive := 0.0
	if not los or d > preferred_range.y:
		steer_to(target.global_position)
		goal_dir = desired_velocity.normalized() if desired_velocity.length() > 1.0 else to_t
		drive = 1.0
	elif d < preferred_range.x:
		drive = -0.7  # back away, still facing the player
	if _aim > 0.0:
		goal_dir = to_t
		drive = 0.0
	facing = Vector2.from_angle(rotate_toward(facing.angle(), goal_dir.angle(), turn_rate * delta))
	desired_velocity = facing * move_speed * drive * maxf(facing.dot(goal_dir), 0.0 if drive > 0.0 else 1.0)

	# Crush props in the way.
	_crush_t -= delta
	if _crush_t <= 0.0 and velocity.length() > 20.0:
		_crush_t = 0.25
		Combat.damage_destructibles(global_position + velocity.normalized() * hit_radius, 34.0, 40.0)

	# Twin cannon.
	_cannon_cd -= delta
	if _aim > 0.0:
		_aim -= delta
		if _aim <= 0.0:
			_fire_cannon()
	elif _cannon_cd <= 0.0 and los and d < 720.0 and facing.dot(to_t) > 0.8:
		_aim = AIM_TIME
		Sfx.play(&"charge", -14.0, 0.0)

	# Missile pods (indirect fire).
	_missile_cd -= delta
	if _missile_cd <= 0.0 and d < 950.0:
		_missile_cd = missile_cooldown
		_pod_flash = 1.0
		for i in 2:
			var lead := target.velocity * 0.7
			var spot := target.global_position + lead + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 80.0) * i
			var pod := POD_L if i == 0 else POD_R
			Combat.artillery(spot, 72.0, missile_damage * damage_mult, self, 1.0 + i * 0.25, "player", _to_world(pod))
		Sfx.play(&"missile", -6.0)


func _fire_cannon() -> void:
	_cannon_cd = cannon_cooldown
	_recoil = 1.0
	for m in [MUZZLE_L, MUZZLE_R]:
		var from := _to_world(m)
		var dir := (target.global_position - from).normalized()
		Combat.fire(from, dir * 520.0, cannon_damage * damage_mult, false, self, CANNON, 2.1, 2.5)
		Combat.spark(from, CANNON, 1.3)
	Combat.shake(0.2)
	Sfx.play(&"slam", -6.0)
	knock(-facing * 900.0)


func _to_world(sprite_pos: Vector2) -> Vector2:
	return global_position + (sprite_pos * SPRITE_SCALE).rotated(facing.angle() + PI / 2)


func _process(delta: float) -> void:
	_recoil = move_toward(_recoil, 0.0, delta * 4.0)
	_pod_flash = move_toward(_pod_flash, 0.0, delta * 3.0)


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var rumble := sin(_t * 30.0) * 0.006 if velocity.length() > 15.0 else 0.0
	var s := Vector2(SPRITE_SCALE + rumble, SPRITE_SCALE - rumble)
	var kick := Vector2(0, _recoil * 6.0).rotated(rot)
	draw_set_transform(Vector2(9, 13) + kick, rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.45))
	draw_set_transform(kick, rot, s)
	draw_texture(TEX, -half, tint(armor_tint()))
	# Barrels glow while aiming; pods flash when the missiles launch.
	if _aim > 0.0:
		var k := 1.0 - _aim / AIM_TIME
		for m in [MUZZLE_L, MUZZLE_R]:
			draw_circle(m, 10.0 + 12.0 * k, Color(CANNON, 0.3 + 0.4 * k))
			draw_circle(m, 6.0, Color(1.0, 0.9, 0.6, 0.9))
	if _pod_flash > 0.0:
		for p in [POD_L, POD_R]:
			draw_circle(p, 26.0 * _pod_flash + 6.0, Color(1.0, 0.5, 0.2, 0.6 * _pod_flash))
	draw_set_transform(Vector2.ZERO)
	if _aim > 0.0:
		var k := 1.0 - _aim / AIM_TIME
		for m in [MUZZLE_L, MUZZLE_R]:
			var from := to_local(_to_world(m))
			var to := to_local(target.global_position) if is_instance_valid(target) else from + facing * 600.0
			draw_line(from, to, Color(1.0, 0.35, 0.2, 0.25 + 0.5 * k), 1.5 + k)
	draw_hp_bar(-hit_radius - 44)
