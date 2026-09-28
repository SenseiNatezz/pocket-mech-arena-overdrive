class_name OutpostTurret
extends Enemy
## Twin-cannon defense turret from the alien outpost set (user's Higgsfield asset). Stationary; stays
## dormant until the encounter starts (`active`), then fires 3-round bursts at the Gundam when it has
## line of sight. Destructible; leaves a scorched crater.

const TEX := preload("res://assets/hq/outpost/turret.png")
const CRATER := preload("res://assets/hq/outpost/crater.png")
const DRAW_W := 220.0
## Footprint as fractions of the drawn sprite (the armored base).
const FOOT := Rect2(0.1, 0.35, 0.8, 0.6)

@export var burst_cooldown := 2.4
@export var bullet_speed := 430.0
@export var bullet_damage := 7.0
@export var fire_range := 720.0

var active := false
var _cd := 1.5
var _burst := 0
var _burst_t := 0.0
var _k := 1.0
var _draw_offset := Vector2.ZERO


func _ready() -> void:
	_k = DRAW_W / TEX.get_width()
	var size := TEX.get_size() * _k
	var fr := Rect2(FOOT.position * size, FOOT.size * size)
	_draw_offset = -fr.get_center()
	super._ready()
	collision_mask = 0  # stationary: never pushed around (and not by its own base)
	add_to_group("turrets")
	# Solid base: blocks the Gundam and bullets; bullets that hit it damage the turret.
	var base := StaticBody2D.new()
	base.collision_layer = 32
	base.collision_mask = 0
	base.set_meta("owner_enemy", self)
	base.add_to_group("nav_obstacles")
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = fr.size * 0.9
	shape.shape = box
	base.add_child(shape)
	add_child(base)


func knock(_impulse: Vector2) -> void:
	pass


func _think(delta: float) -> void:
	if not active:
		return
	facing = dir_to_target()
	_cd -= delta
	if _burst > 0:
		_burst_t -= delta
		if _burst_t <= 0.0:
			_burst_t = 0.13
			_burst -= 1
			var muzzle := global_position + Vector2(0, -DRAW_W * 0.32)
			var dir := (target.global_position - muzzle).normalized().rotated(randf_range(-0.04, 0.04))
			Combat.fire(muzzle + dir * 30.0, dir * bullet_speed, bullet_damage * damage_mult, false, self,
				Color(1.0, 0.3, 0.3), 1.2, 2.2)
			Combat.spark(muzzle, Color(1.0, 0.4, 0.3), 1.2)
			Sfx.play(&"enemy_shoot", -12.0)
	elif _cd <= 0.0 and dist_to_target() < fire_range and has_line_of_sight(target.global_position):
		_cd = burst_cooldown
		_burst = 3


func die() -> void:
	if dead:
		return
	var scorch := Sprite2D.new()
	scorch.texture = CRATER
	scorch.global_position = global_position
	scorch.scale = Vector2.ONE * 0.6
	scorch.rotation = randf() * TAU
	scorch.z_index = -6
	get_parent().add_child.call_deferred(scorch)
	Combat.explosion_fx(global_position, 180.0, Color(1.0, 0.45, 0.2))
	super.die()


func _draw() -> void:
	var size := TEX.get_size() * _k
	draw_set_transform(Vector2(10, 8), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, size.x * 0.42, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	draw_texture_rect(TEX, Rect2(_draw_offset, size), false, tint(Color.WHITE))
	# Red targeting light pulses when active.
	if active:
		var eye := Vector2(0, -DRAW_W * 0.42)
		draw_circle(eye, 10.0 + 4.0 * sin(_t * 8.0), Color(1.0, 0.2, 0.15, 0.35))
	draw_hp_bar(_draw_offset.y - 10)
