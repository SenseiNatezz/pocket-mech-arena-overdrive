extends Area2D
## Training target drone (Higgsfield sprite) for the Test Range / Gun Range. Takes damage, shows
## numbers, feeds the player's heat/overdrive meters, and respawns a couple of seconds after being
## destroyed. Hovers in place (knockback pushes it, then it drifts home).

const TEX := preload("res://assets/hq/enemies3/target_drone.png")
const SPRITE_SCALE := 0.58

@export var max_hp := 400.0
@export var respawn_time := 2.5

var hp := 0.0
var hit_radius := 30.0
var _flash := 0.0
var _knock := Vector2.ZERO
var _home := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	add_to_group("damageable")
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = hit_radius
	shape.shape = circle
	add_child(shape)
	hp = max_hp
	_home = global_position


func take_damage(amount: float, _from_pos: Vector2, source: Node = null) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 1.0
	Combat.damage_number(global_position, amount, Color(1, 0.85, 0.6), self)
	Combat.report_damage(amount, source, self)
	if hp <= 0.0:
		_destroyed()


func knock(impulse: Vector2) -> void:
	_knock += impulse * 0.4


func _destroyed() -> void:
	Combat.shockwave(global_position, 90.0, Color(1.0, 0.6, 0.2))
	for i in 6:
		Combat.spark(global_position + Vector2.from_angle(randf() * TAU) * randf_range(0, 30), Color(1, 0.6, 0.2), 1.4)
	Sfx.play(&"explode", -6.0)
	visible = false
	set_deferred("monitorable", false)
	get_tree().create_timer(respawn_time, false).timeout.connect(func() -> void:
		hp = max_hp
		global_position = _home
		visible = true
		set_deferred("monitorable", true)
		Combat.shockwave(global_position, 60.0, Color(0.5, 0.9, 1.0)))


func _process(delta: float) -> void:
	_t += delta
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	global_position += _knock * delta
	_knock = _knock.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
	global_position = global_position.lerp(_home, 1.0 - exp(-2.0 * delta))
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 2.4) * 3.0
	var half := TEX.get_size() / 2
	draw_set_transform(Vector2(8, 16), 0.0, Vector2.ONE * SPRITE_SCALE * 0.9)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, bob), sin(_t * 0.8) * 0.08, Vector2.ONE * SPRITE_SCALE)
	draw_texture(TEX, -half, Color.WHITE.lerp(Color(1.6, 1.3, 1.3), _flash))
	draw_set_transform(Vector2.ZERO)
	draw_arc(Vector2(0, bob), 42, -PI / 2, -PI / 2 + TAU * hp / max_hp, 32, Color(0.4, 1.0, 0.5, 0.8), 4.0, true)
