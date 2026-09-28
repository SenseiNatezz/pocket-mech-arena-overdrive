extends StaticBody2D
## Destructible cover: concrete barricade that blocks movement and bullets from both sides, cracks
## as it takes damage and crumbles after enough hits. `size` in pixels (e.g. 64x40 or 128x40).
## Optional per-map look: `texture` (stretched to `size`, drawn a little taller). With `hits_to_break`
## > 0 it crumbles after that many hits instead of by damage (heavy hits count double).

const TEX := preload("res://assets/hq/barricade.png")

@export var size := Vector2(64, 40)
@export var max_hp := 72.0
@export var texture: Texture2D
@export var hits_to_break := 0
## A hit this strong counts as two in hits mode.
const HEAVY_HIT := 40.0

var hp := 0.0
var hit_radius := 26.0
var _flash := 0.0
var _cracks: Array[PackedVector2Array] = []


func _ready() -> void:
	add_to_group("destructibles")
	collision_layer = 32
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	if hits_to_break > 0:
		max_hp = hits_to_break
	hp = max_hp
	hit_radius = size.length() * 0.4
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	for i in 4:
		var pts := PackedVector2Array()
		var p := Vector2(rng.randf_range(-size.x / 2 + 6, size.x / 2 - 6), rng.randf_range(-size.y / 2, 0))
		for s in 5:
			pts.append(p)
			p += Vector2(rng.randf_range(-7, 7), rng.randf_range(2, 8))
		_cracks.append(pts)


func take_hit(amount: float, from_pos: Vector2) -> void:
	if hp <= 0.0:
		return
	hp -= amount if hits_to_break <= 0 else (2.0 if amount >= HEAVY_HIT else 1.0)
	_flash = 1.0
	Combat.burst(global_position + (from_pos - global_position).limit_length(size.x * 0.4), Color(0.55, 0.55, 0.58), 120.0, 0.6)
	if hp <= 0.0:
		remove_from_group("destructibles")
		Combat.burst(global_position, Color(0.6, 0.6, 0.62), 320.0, 1.6)
		Combat.burst(global_position, Color(0.4, 0.4, 0.43), 220.0, 2.2)
		Combat.shockwave(global_position, 60.0, Color(0.8, 0.8, 0.8, 0.6), 0.3)
		Sfx.play(&"slam", -10.0)
		Combat.shake(0.1)
		queue_free()
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = move_toward(_flash, 0.0, delta * 6.0)
		queue_redraw()


func _draw() -> void:
	# HQ barricade sprite fitted to the block's width; it darkens and cracks as it takes damage.
	var damage := 1.0 - hp / max_hp
	var tex: Texture2D = texture if texture else TEX
	# Top-down textures fill their footprint; the old side-view barricade is drawn a little taller.
	var k := minf(size.x / tex.get_width(), size.y * (1.15 if texture else 1.4) / tex.get_height())
	var half := tex.get_size() / 2
	draw_set_transform(Vector2(5, 8), 0.0, Vector2.ONE * k)
	draw_texture(tex, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * k)
	draw_texture(tex, -half, Color.WHITE.darkened(damage * 0.45).lerp(Color.WHITE, _flash * 0.6))
	draw_set_transform(Vector2.ZERO)
	var shown := mini(int(ceil(damage * _cracks.size())), _cracks.size())
	for i in shown:
		draw_polyline(_cracks[i], Color(0.08, 0.08, 0.1, 0.9), 2.0)
