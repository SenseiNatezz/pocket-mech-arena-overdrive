class_name Bullet
extends Area2D
## Pooled projectile used by the player and (later) enemies. Owned by the Combat autoload.
## Hits anything in the "damageable" group on the opposing side, and is stopped by walls/cover.

var active := false
var velocity := Vector2.ZERO
var damage := 10.0
var player_owned := true
var source: Node
## Upgrade traits (player shots; reset on every launch):
##   pierce     enemies it can pass through before stopping
##   homing     turn rate (rad/s) toward the nearest enemy ahead
##   explosive  chance (0-1) for a hit to set off a small blast
var pierce := 0
var homing := 0.0
var explosive := 0.0
## What fired it, when that matters on a hit (&"bit" = a Bit Drone shot: STORM BITS arcs from it).
var tag := &""
## Look: false = soft glow (enemy shots, Gatling, Railgun slugs); true = the Beam Rifle's hand-drawn
## bolt + hit burst (player/weapons/rifle_fx.gd). Set with set_rifle_style() after Combat.fire().
var rifle_style := false
## ENEMY SHOTS all share one reserved look so threats read at a glance on every map: a round hot-red orb
## with a dark rim and a white-hot centre. Player shots are long bolts in the pilot's energy colour, and
## no energy colour is this red. (The colour an enemy asks for is ignored.)
const ENEMY_SHOT := Color(1.0, 0.16, 0.3)
const ENEMY_GLOW := Vector2(0.62, 0.62)
const ENEMY_CORE := Vector2(0.24, 0.24)
var _life := 0.0
var _color := Color.WHITE
var _core_scale := Vector2.ONE
var _home_target: Node2D
var _home_t := 0.0
var _age := 0.0
var _frame := -1
## Rifle beams grow out of the barrel: how much of the beam has left it so far (px, unscaled).
var _reach := 0.0
var _glow_scale := Vector2.ONE

@onready var glow: Sprite2D = $Glow
@onready var core: Sprite2D = $Core


func _ready() -> void:
	_glow_scale = glow.scale
	_core_scale = core.scale
	monitorable = false
	area_entered.connect(_on_hit)
	body_entered.connect(_on_body)


func launch(pos: Vector2, vel: Vector2, dmg: float, is_player: bool, from: Node, color: Color, size: float,
		lifetime: float) -> void:
	global_position = pos
	velocity = vel
	rotation = vel.angle()
	damage = dmg
	player_owned = is_player
	source = from
	_life = lifetime
	_color = color if is_player else ENEMY_SHOT
	pierce = 0
	homing = 0.0
	explosive = 0.0
	tag = &""
	_home_target = null
	_home_t = 0.0
	# Player shots hit enemies (3); enemy shots hit the player (2). Both stop on walls (1) + cover (6).
	collision_layer = 8 if is_player else 16
	collision_mask = (4 if is_player else 2) | 1 | 32
	glow.modulate = Color(_color, 0.85)
	glow.scale = _glow_scale if is_player else ENEMY_GLOW
	glow.position = Vector2.ZERO
	core.scale = _core_scale if is_player else ENEMY_CORE
	core.visible = true
	rifle_style = false
	_age = 0.0
	_frame = -1
	_reach = 0.0
	queue_redraw()
	scale = Vector2.ONE * size
	active = true
	show()
	set_deferred("monitoring", true)
	set_physics_process(true)


## Beam Rifle look: the drawn, cel-animated beam lance with a soft glow stretched along it.
func set_rifle_style() -> void:
	rifle_style = true
	core.visible = false
	glow.modulate = Color(_color, 0.35)
	_update_rifle_glow()
	queue_redraw()


func _update_rifle_glow() -> void:
	var len := minf(_reach + 16.0, RifleFx.BOLT_LENGTH)
	glow.scale = Vector2(len / 64.0 * 1.2, 0.5)
	glow.position = Vector2(-len * 0.42, 0)


func _draw() -> void:
	if rifle_style and _frame >= 0:
		RifleFx.draw_bolt(self, _frame, _color, get_instance_id(), _reach)
	elif not player_owned:
		# Dark rim + red ring under the glow (children draw on top), so the orb reads on snow and sand too.
		draw_circle(Vector2.ZERO, 8.5, Color(0.12, 0.0, 0.04, 0.8))
		draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 20, ENEMY_SHOT, 2.5, true)


## Hit effect where this bolt lands (smaller on walls and cover).
func _hit_fx(col: Color, size := 1.0) -> void:
	if rifle_style:
		RifleFx.impact(global_position, velocity.normalized(), _color if col == _color else col.lerp(_color, 0.5),
			1.0 if size >= 1.0 else 0.75)
	else:
		Combat.spark(global_position, col, size)


func deactivate() -> void:
	active = false
	hide()
	set_deferred("monitoring", false)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	if rifle_style:
		_age += delta
		var grown := _reach < RifleFx.BOLT_LENGTH
		_reach += velocity.length() * delta / maxf(scale.x, 0.01)
		var f := int(_age * RifleFx.FPS)
		if f != _frame or grown:
			_frame = f
			_update_rifle_glow()
			queue_redraw()
	if homing > 0.0:
		_steer(delta)
	# Trace the path this frame against walls (layer 1) and solid props/cover (layer 6) with a ray:
	# reliable against static bodies and never tunnels through thin objects at high speed.
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters2D.create(from, to, 1 | 32)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position = hit.position
		_on_body(hit.collider)
		return
	global_position = to
	_life -= delta
	if _life <= 0.0:
		deactivate()


func _on_hit(area: Area2D) -> void:
	if not active:
		return
	var target: Node = area if area.is_in_group("damageable") else area.get_parent()
	if target and target.is_in_group("damageable") and target.is_in_group("player") != player_owned:
		var from_node := source if is_instance_valid(source) else null
		target.take_damage(damage, global_position - velocity.normalized() * 20.0, from_node)
		_hit_fx(_color)
		if tag == &"bit" and from_node and from_node.has_method("arc_from") and Upgrades.level_of(&"storm_bits") > 0:
			from_node.arc_from(target, damage, 1)
		if explosive > 0.0 and randf() < explosive:
			Combat.small_blast(global_position, 75.0, damage * 0.6, from_node)
		if pierce > 0:
			pierce -= 1
			damage *= 0.85
			if target == _home_target:
				_home_target = null
			return
		deactivate()
	elif area.collision_layer & 32:  # cover
		if area.has_method("take_hit"):
			area.take_hit(damage, global_position)
		_hit_fx(Color(1, 0.8, 0.5), 0.8)
		deactivate()


## Walls (tiles, barriers, doors) and cover bodies stop bullets. Character bodies are ignored here:
## they're hit through their hurtbox areas instead.
func _on_body(body: Node) -> void:
	if not active or body is CharacterBody2D:
		return
	# Solid bases of enemy structures (outpost turrets) forward the hit to their owner.
	if body.has_meta("owner_enemy"):
		var owner_enemy: Node = body.get_meta("owner_enemy")
		if player_owned and is_instance_valid(owner_enemy):
			owner_enemy.take_damage(damage, global_position - velocity.normalized() * 20.0, source if is_instance_valid(source) else null)
			_hit_fx(_color)
		deactivate()
		return
	if body.has_method("take_hit"):
		body.take_hit(damage, global_position - velocity.normalized() * 10.0)
	_hit_fx(Color(1, 0.8, 0.5), 0.7)
	deactivate()


## Target Lock: bend toward the nearest enemy ahead (re-picked a few times a second).
func _steer(delta: float) -> void:
	_home_t -= delta
	if _home_t <= 0.0 or (is_instance_valid(_home_target) and _home_target.get("dead") == true):
		_home_t = 0.12
		_home_target = Combat.nearest_enemy(global_position, 560.0, velocity, deg_to_rad(95.0))
	if not is_instance_valid(_home_target):
		return
	var want := (_home_target.global_position - global_position).angle()
	var a := rotate_toward(velocity.angle(), want, homing * delta)
	velocity = Vector2.from_angle(a) * velocity.length()
	rotation = a
