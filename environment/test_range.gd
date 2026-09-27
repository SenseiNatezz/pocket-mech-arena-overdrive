extends Node2D
## Test range: a walled, gridded floor with training dummies, a repair station and one of each
## hazard/prop, for trying every control without waves of enemies. Reached from the main menu.

@export var arena_size := Vector2(2400, 1400)

const WALL := 40.0

@onready var mech: Mech = $Mech


func _ready() -> void:
	var floor_node := Node2D.new()
	floor_node.z_index = -10
	floor_node.draw.connect(_draw_floor.bind(floor_node))
	add_child(floor_node)
	_build_walls()
	var P := "res://environment/props/"
	var H := "res://environment/hazards/"
	_prop(P + "cover_block.gd", Vector2(300, 260), StaticBody2D, {"size": Vector2(120, 40)})
	_prop(P + "cover_block.gd", Vector2(-420, 120), StaticBody2D)
	_prop(P + "crate.gd", Vector2(-640, 300), StaticBody2D)
	_prop(P + "crate.gd", Vector2(-700, 360), StaticBody2D)
	_prop(H + "explosive_barrel.gd", Vector2(760, 200), StaticBody2D)
	_prop(H + "explosive_barrel.gd", Vector2(800, 250), StaticBody2D)
	_prop(H + "explosive_barrel.gd", Vector2(740, 290), StaticBody2D)
	_prop(H + "electric_panel.gd", Vector2(-300, -420), Area2D, {"size": Vector2(192, 128)})
	_prop(P + "pit.gd", Vector2(0, 480), StaticBody2D, {"size": Vector2(256, 128)})


func _prop(path: String, pos: Vector2, base: Variant, props := {}) -> void:
	var n: Node2D = base.new()
	n.set_script(load(path))
	n.position = pos
	for k: String in props:
		n.set(k, props[k])
	add_child(n)


func _build_walls() -> void:
	var half := arena_size / 2
	var rects := [
		Rect2(-half.x - WALL, -half.y - WALL, arena_size.x + WALL * 2, WALL),
		Rect2(-half.x - WALL, half.y, arena_size.x + WALL * 2, WALL),
		Rect2(-half.x - WALL, -half.y, WALL, arena_size.y),
		Rect2(half.x, -half.y, WALL, arena_size.y),
	]
	for r: Rect2 in rects:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = r.size
		shape.shape = box
		body.position = r.get_center()
		body.add_child(shape)
		add_child(body)
	var cam := mech.get_node("Camera2D") as Camera2D
	cam.limit_left = int(-half.x - WALL - 200)
	cam.limit_top = int(-half.y - WALL - 200)
	cam.limit_right = int(half.x + WALL + 200)
	cam.limit_bottom = int(half.y + WALL + 200)


func _draw_floor(c: Node2D) -> void:
	var half := arena_size / 2
	var floor_rect := Rect2(-half, arena_size)
	# Floor, leaving a hole for the pit so the city below shows through.
	var hole := Rect2(Vector2(-128, 416), Vector2(256, 128))
	for part: Rect2 in [Rect2(floor_rect.position, Vector2(arena_size.x, hole.position.y - floor_rect.position.y)),
			Rect2(Vector2(floor_rect.position.x, hole.end.y), Vector2(arena_size.x, floor_rect.end.y - hole.end.y)),
			Rect2(Vector2(floor_rect.position.x, hole.position.y), Vector2(hole.position.x - floor_rect.position.x, hole.size.y)),
			Rect2(Vector2(hole.end.x, hole.position.y), Vector2(floor_rect.end.x - hole.end.x, hole.size.y))]:
		c.draw_rect(part, Color(0.17, 0.19, 0.23))
	var step := 80.0
	var x := -half.x
	while x <= half.x:
		c.draw_line(Vector2(x, -half.y), Vector2(x, half.y), Color(1, 1, 1, 0.05 if int(x) % 400 else 0.12), 2.0)
		x += step
	var y := -half.y
	while y <= half.y:
		c.draw_line(Vector2(-half.x, y), Vector2(half.x, y), Color(1, 1, 1, 0.05 if int(y) % 400 else 0.12), 2.0)
		y += step
	c.draw_rect(floor_rect, Color(1.0, 0.75, 0.2, 0.6), false, 4.0)
