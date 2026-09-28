class_name OutpostStructure
extends StaticBody2D
## A building/prop from the alien outpost set (hangar, dome bunker, radar tower, fuel silos, crystals,
## barricade wall) drawn from a 3/4-view sprite, with a collision FOOTPRINT only where it touches the
## ground so the mech can walk "behind" the upper part. The node origin is the footprint's bottom
## center, so y-sorting puts the mech in front of or behind the building correctly.
## Optional: `max_hp` > 0 makes it destructible; `explosive` makes it blow up (fuel silos).

@export var texture: Texture2D
## Drawn width in world pixels (height keeps the aspect ratio).
@export var width := 400.0
## Footprint as fractions of the drawn rect (x, y, w, h).
@export var footprint := Rect2(0.1, 0.4, 0.8, 0.55)
## Optional footprint polygon in TEXTURE pixels (overrides `footprint`), e.g. for diagonal walls.
@export var polygon := PackedVector2Array()
@export var flip := false
@export var max_hp := 0.0
@export var explosive := false

const CRATER := preload("res://assets/hq/outpost/crater.png")

var hp := 0.0
var hit_radius := 60.0
var _k := 1.0
var _draw_offset := Vector2.ZERO
var _flash := 0.0
var _fuse := -1.0


## Call before adding to the tree: `pos` is where the CENTER of the drawn sprite should be.
func place_visual_center(pos: Vector2) -> void:
	_setup_metrics()
	position = pos - (_draw_offset + texture.get_size() * _k / 2)


func _setup_metrics() -> void:
	_k = width / texture.get_width()
	var size := texture.get_size() * _k
	var fr := _fp_rect(size)
	_draw_offset = -Vector2(fr.get_center().x, fr.end.y)


func _fp_rect(size: Vector2) -> Rect2:
	var f := footprint
	if flip:
		f.position.x = 1.0 - f.position.x - f.size.x
	return Rect2(f.position * size, f.size * size)


func _ready() -> void:
	_setup_metrics()
	collision_layer = 32
	collision_mask = 0
	add_to_group("nav_obstacles")
	var size := texture.get_size() * _k
	if polygon.is_empty():
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		var fr := _fp_rect(size)
		box.size = fr.size
		shape.shape = box
		shape.position = fr.get_center() + _draw_offset
		add_child(shape)
		hit_radius = maxf(fr.size.x, fr.size.y) * 0.5
	else:
		var cp := CollisionPolygon2D.new()
		var pts := PackedVector2Array()
		for p in polygon:
			var q := p * _k
			if flip:
				q.x = size.x - q.x
			pts.append(q + _draw_offset)
		cp.polygon = pts
		add_child(cp)
		hit_radius = size.x * 0.3
	if max_hp > 0.0:
		hp = max_hp
		add_to_group("destructibles")


func take_hit(amount: float, _from_pos: Vector2) -> void:
	if max_hp <= 0.0 or hp <= 0.0:
		return
	hp -= amount
	_flash = 1.0
	queue_redraw()
	if hp <= 0.0:
		_fuse = 0.35 if explosive else 0.0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = move_toward(_flash, 0.0, delta * 5.0)
		queue_redraw()
	if _fuse >= 0.0:
		_fuse -= delta
		queue_redraw()
		if _fuse < 0.0:
			_destroy()


func _destroy() -> void:
	remove_from_group("destructibles")
	var size := texture.get_size() * _k
	var center := global_position + _draw_offset + size / 2
	if explosive:
		Combat.explode(center, 300.0, 70.0, self, "all", Color(1.0, 0.55, 0.15), 700.0)
		for i in 4:
			var off := Vector2.from_angle(randf() * TAU) * randf_range(60, 150)
			get_tree().create_timer(0.12 * (i + 1), false).timeout.connect(func() -> void:
				Combat.explosion_fx(center + off, randf_range(90, 150), Color(1.0, 0.6, 0.2)))
		Sfx.play(&"big_explode", -1.0)
		Combat.shake(0.8)
	else:
		Combat.explosion_fx(center, 160.0, Color(0.8, 0.8, 0.9))
	var scorch := Sprite2D.new()
	scorch.texture = CRATER
	scorch.global_position = global_position + Vector2(0, -size.y * 0.2)
	scorch.scale = Vector2.ONE * (size.x / CRATER.get_width()) * 0.9
	scorch.rotation = randf() * TAU
	scorch.z_index = -6
	get_parent().add_child.call_deferred(scorch)
	queue_free()


func _draw() -> void:
	if texture == null:
		return
	var size := texture.get_size() * _k
	var rect := Rect2(_draw_offset, size)
	# Soft contact shadow under the footprint.
	var fr := _fp_rect(size)
	draw_set_transform(fr.get_center() + _draw_offset + Vector2(10, 8), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, fr.size.x * 0.55, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var tint := Color.WHITE.lerp(Color(2.0, 2.0, 2.0), _flash * 0.4)
	if _fuse >= 0.0 and int(_fuse * 30.0) % 2 == 0:
		tint = Color(2.0, 1.6, 0.8)
	draw_texture_rect(texture, rect, false, tint, false) if not flip else \
		draw_texture_rect_region(texture, rect, Rect2(texture.get_width(), 0, -texture.get_width(), texture.get_height()), tint)
	if max_hp > 0.0 and hp < max_hp and hp > 0.0:
		var w := minf(size.x * 0.6, 160.0)
		var p := Vector2(-w / 2, _draw_offset.y - 12)
		draw_rect(Rect2(p, Vector2(w, 6)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(p, Vector2(w * hp / max_hp, 6)), Color(1.0, 0.55, 0.2))
