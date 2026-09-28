extends Node
## Preview capture for the Beam Cannon:  godot --path . -- --arena=1 --beam-demo --write-movie ...
## Lines up enemies and props in the Frozen Outpost, then fires the beam twice (one sweep).

var arena: Node
var mech: Mech


func _ready() -> void:
	Controls.ignore_real_input = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _spawn(kind: String, pos: Vector2) -> void:
	var e: Enemy = load("res://enemies/%s.tscn" % kind).instantiate()
	e.position = pos
	e.max_hp = 90.0
	arena.world.add_child(e)


func _run() -> void:
	await _frames(2)
	arena = get_tree().current_scene
	mech = get_tree().get_first_node_in_group("player") as Mech
	arena.zone.is_cleared = true  # no waves in the demo
	mech._invuln = 1e9
	mech.global_position = arena.map_to_world(Vector2(1250, 1520))
	Controls.touch_aim = Vector2.RIGHT
	var base := mech.global_position
	for i in 4:
		_spawn(["chaser", "shooter", "chaser", "shooter"][i], base + Vector2(330 + i * 170, -40 + (i % 2) * 70))
	var cover: StaticBody2D = StaticBody2D.new()
	cover.set_script(load("res://environment/props/cover_block.gd"))
	cover.set("size", Vector2(90, 48))
	cover.position = base + Vector2(1050, 0)
	arena.world.add_child(cover)
	await _frames(40)
	await _tap(&"beam")
	# Sweep slightly up and down while it fires.
	for f in 90:
		var a := sin(f / 90.0 * TAU) * 0.18
		Controls.touch_aim = Vector2.RIGHT.rotated(a)
		await get_tree().physics_frame
	await _frames(20)
	# Second shot at a new group (cooldown skipped for the demo).
	for i in 3:
		_spawn("chaser", base + Vector2(-80 + i * 110, -420 - i * 40))
	Controls.touch_aim = Vector2(0.1, -1).normalized()
	await _frames(25)
	mech.beam.state = BeamCannon.State.READY
	mech.beam.cooldown_left = 0.0
	await _tap(&"beam")
	await _frames(120)
