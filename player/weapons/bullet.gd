class_name Bullet
extends Area2D
## Pooled projectile used by the player and (later) enemies. Owned by the Combat autoload.
## Hits anything in the "damageable" group on the opposing side, and is stopped by walls/cover.

var active := false
var velocity := Vector2.ZERO
var damage := 10.0
var player_owned := true
var source: Node
var _life := 0.0
var _color := Color.WHITE

@onready var glow: Sprite2D = $Glow
@onready var core: Sprite2D = $Core


func _ready() -> void:
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
	_color = color
	# Player shots hit enemies (3); enemy shots hit the player (2). Both stop on walls (1) + cover (6).
	collision_layer = 8 if is_player else 16
	collision_mask = (4 if is_player else 2) | 1 | 32
	glow.modulate = Color(color, 0.85)
	scale = Vector2.ONE * size
	active = true
	show()
	set_deferred("monitoring", true)
	set_physics_process(true)


func deactivate() -> void:
	active = false
	hide()
	set_deferred("monitoring", false)
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		deactivate()


func _on_hit(area: Area2D) -> void:
	if not active:
		return
	var target: Node = area if area.is_in_group("damageable") else area.get_parent()
	if target and target.is_in_group("damageable") and target.is_in_group("player") != player_owned:
		target.take_damage(damage, global_position - velocity.normalized() * 20.0, source if is_instance_valid(source) else null)
		Combat.spark(global_position, _color)
		deactivate()
	elif area.collision_layer & 32:  # cover
		if area.has_method("take_hit"):
			area.take_hit(damage, global_position)
		Combat.spark(global_position, Color(1, 0.8, 0.5), 0.8)
		deactivate()


## Walls (tiles, barriers, doors) and cover bodies stop bullets. Character bodies are ignored here:
## they're hit through their hurtbox areas instead.
func _on_body(body: Node) -> void:
	if not active or body is CharacterBody2D:
		return
	if body.has_method("take_hit"):
		body.take_hit(damage, global_position - velocity.normalized() * 10.0)
	Combat.spark(global_position, Color(1, 0.8, 0.5), 0.7)
	deactivate()
