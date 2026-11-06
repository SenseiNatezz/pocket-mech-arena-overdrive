extends Node
## Preview capture for the Energy Sword (loops until closed):
##   godot --path . -- --gun-range --attach=res://tools/sword_demo.gd --temp-save
## In the Weapon Range: the sword idles (equipped glow, crackles, sparks) for a moment, then runs its
## combo into the drone cluster (3 slashes + CRESCENT NOVA), and repeats.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	Controls.ignore_real_input = true
	for i in 30:
		await get_tree().physics_frame
	var gr := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	gr.select_weapon(&"energy_sword", false)
	var cluster: Array = gr.get_node("Dummies").get_children().filter(func(d: Node) -> bool: return d.name.begins_with("Cluster"))
	var c := Vector2.ZERO
	for d in cluster:
		c += d.global_position
	c /= cluster.size()
	while is_inside_tree():
		mech.global_position = c + Vector2(-230, 0)
		mech.velocity = Vector2.ZERO
		(mech.get_node("Camera2D") as Camera2D).reset_smoothing()
		Controls.touch_aim = Vector2(1, -0.25).normalized()
		for i in 120:
			await get_tree().physics_frame
		Controls.touch_aim = Vector2.RIGHT
		Input.action_press("fire_primary")
		for i in 170:
			await get_tree().physics_frame
		Input.action_release("fire_primary")
		for i in 60:
			await get_tree().physics_frame
