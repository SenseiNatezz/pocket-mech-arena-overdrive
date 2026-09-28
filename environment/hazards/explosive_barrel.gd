extends StaticBody2D
## Exploding barrel. Solid (blocks movement like cover), takes hits from anyone, and after a short
## fuse explodes, damaging the player AND enemies nearby and setting off other barrels (chains).

@export var max_hp := 24.0
@export var blast_radius := 140.0
@export var blast_damage := 45.0
## Painted maps: the barrel is already in the art, so only hit flashes / the lit fuse are drawn, and
## a scorch decal covers the painted barrel after it explodes.
@export var painted := false
## Optional per-map look: a top-down drum `texture` drawn `radius` * 2 px wide (collision radius too).
@export var texture: Texture2D
@export var radius := 18.0

const SCORCH := preload("res://assets/hq/scorch.png")
const TEX := preload("res://assets/hq/barrel.png")

var hp := 0.0
var hit_radius := 18.0
var _fuse := -1.0
var _flash := 0.0


func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 32
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	hit_radius = radius
	shape.shape = circle
	add_child(shape)
	hp = max_hp


func take_hit(amount: float, _from_pos: Vector2) -> void:
	if hp <= 0.0:
		return
	hp -= amount
	_flash = 1.0
	if hp <= 0.0:
		_fuse = 0.25  # short fuse so chains ripple instead of all popping on one frame


func _process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 5.0)
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse < 0.0:
			_explode()
			return
	queue_redraw()


func _explode() -> void:
	var pos := global_position
	remove_from_group("destructibles")
	queue_free()
	Combat.explode(pos, blast_radius, blast_damage, self, "all", Color(1.0, 0.5, 0.15), 520.0)
	Combat.burst(pos, Color(1.0, 0.8, 0.3), 520.0, 1.2)
	var scorch := Sprite2D.new()
	scorch.texture = SCORCH
	scorch.position = position
	scorch.rotation = randf() * TAU
	scorch.scale = Vector2.ONE * 0.55
	scorch.z_index = -6
	get_parent().add_child.call_deferred(scorch)


func _draw() -> void:
	var lit := _fuse >= 0.0
	if painted:
		# Only feedback on top of the painted barrel: hit flash + blinking fuse.
		if _flash > 0.0:
			draw_circle(Vector2.ZERO, 20, Color(1, 1, 1, _flash * 0.5))
		if lit and int(_fuse * 30.0) % 2 == 0:
			draw_circle(Vector2.ZERO, 22, Color(1.0, 0.85, 0.3, 0.7))
		return
	# HQ barrel sprite (~44 px); blinks bright while the fuse burns.
	var tint := Color.WHITE.lerp(Color(2, 2, 2), _flash * 0.5)
	if lit and int(_fuse * 30.0) % 2 == 0:
		tint = Color(2.0, 1.7, 0.8)
	var tex: Texture2D = texture if texture else TEX
	var k := (radius * 2.3 if texture else 44.0) / tex.get_height()
	var half := tex.get_size() / 2
	draw_set_transform(Vector2(4, 6), 0.0, Vector2.ONE * k)
	draw_texture(tex, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	draw_texture(tex, -half, tint)
	draw_set_transform(Vector2.ZERO)
