extends SceneTree
## Debug: does a moving Area2D (like a bullet) detect a StaticBody2D (like cover)?

var area: Area2D
var hits := 0


func _init() -> void:
	var root_node := Node2D.new()
	root.add_child(root_node)
	var body := StaticBody2D.new()
	body.collision_layer = 32
	body.collision_mask = 8 if OS.get_cmdline_user_args().has("--mask") else 0
	var bs := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(150, 48)
	bs.shape = box
	body.add_child(bs)
	body.position = Vector2(500, 300)
	root_node.add_child(body)
	for variant in ["plain", "pooled"]:
		area = Area2D.new()
		area.collision_layer = 8
		area.collision_mask = 37
		area.monitorable = false
		var s := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 7.0
		s.shape = c
		area.add_child(s)
		area.position = Vector2(200, 300)
		root_node.add_child(area)
		hits = 0
		area.body_entered.connect(func(_b: Node) -> void: hits += 1)
		if variant == "pooled":
			area.set_deferred("monitoring", false)
			for f in 3:
				await physics_frame
			area.set_deferred("monitoring", true)
		for f in 40:
			area.global_position += Vector2(18, 0)
			await physics_frame
		print(variant, ": body_entered hits = ", hits, " overlaps now = ", area.get_overlapping_bodies().size())
		area.queue_free()
		await physics_frame
	quit()
