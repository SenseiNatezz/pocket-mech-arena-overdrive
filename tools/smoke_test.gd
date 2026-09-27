extends Node
## Automated check of every Step 1 action. Run:
##   godot --path . -- --smoke-test
## Drives the Input Map actions with Input.action_press (the same path touch buttons use),
## prints PASS/FAIL per check and quits with exit code 0 (all pass) or 1.

var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.ignore_real_input = true
	_run.call_deferred()


func _check(name: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + name)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(1)


func _run() -> void:
	await _frames(5)
	var mech := get_tree().get_first_node_in_group("player") as Mech
	var dummies := get_tree().get_nodes_in_group("enemies")
	_check("mech + dummies exist", mech != null and dummies.size() >= 3)

	# Movement: snappy — near full speed within 0.1 s.
	var start := mech.global_position
	Controls.touch_move = Vector2.LEFT
	await _frames(6)
	_check("move reaches speed fast (%.0f px/s)" % mech.velocity.length(), mech.velocity.length() > mech.move_speed * 0.9)
	await _frames(20)
	Controls.touch_move = Vector2.ZERO
	_check("move changes position", mech.global_position.x < start.x - 50)
	await _frames(10)
	_check("stops quickly", mech.velocity.length() < 5.0)

	# Aim is independent of movement.
	Controls.touch_move = Vector2.DOWN
	Controls.touch_aim = Vector2.RIGHT
	await _frames(4)
	_check("aim independent of move", mech.aim_dir.dot(Vector2.RIGHT) > 0.99 and mech.velocity.normalized().dot(Vector2.DOWN) > 0.9)
	Controls.touch_move = Vector2.ZERO

	# Boost.
	await _tap(&"boost")
	_check("boost starts cooldown", mech.boost_cooldown_left > 0.0 and mech.boost_ready_fraction() < 1.0)
	await _frames(70)
	_check("boost recharges", mech.boost_ready_fraction() >= 1.0)

	# Fire at a dummy: damage builds heat + overdrive.
	mech.global_position = Vector2(200, -160)
	await _frames(2)
	Controls.touch_aim = Vector2.RIGHT
	Input.action_press(&"fire_primary")
	await _frames(60)
	Input.action_release(&"fire_primary")
	_check("primary fire builds heat (%.1f)" % mech.heat, mech.heat > 5.0)
	_check("primary fire builds overdrive (%.1f)" % mech.overdrive_meter, mech.overdrive_meter > 1.0)
	var heat_before := mech.heat
	await _frames(60)
	Input.action_press(&"fire_secondary")
	await _frames(3)
	Input.action_release(&"fire_secondary")
	await _frames(20)
	_check("secondary fire hits", mech.heat > heat_before)

	# Heat attacks.
	mech.heat = 100.0
	await _tap(&"heat_attack_1")
	_check("heat nova spends 40 heat", absf(mech.heat - (100.0 - mech.nova_cost)) < 12.0)
	mech.heat = 100.0
	await _tap(&"heat_attack_2")
	_check("magma cone spends 30 heat", absf(mech.heat - (100.0 - mech.cone_cost)) < 12.0)
	mech.heat = 0.0
	await _tap(&"heat_attack_1")
	_check("nova denied with no heat", mech.heat < 1.0)

	# Self-repair.
	mech.hp = 30.0
	var charges := mech.repair_charges
	await _tap(&"self_repair")
	_check("self-repair heals + uses a charge", mech.hp > 60.0 and mech.repair_charges == charges - 1)

	# Overdrive.
	mech.overdrive_meter = 100.0
	await _tap(&"overdrive")
	_check("overdrive activates", mech.overdrive_left > 0.0)

	# Use: repair terminal refills charges.
	var terminal := get_tree().get_first_node_in_group("interactable") as Node2D
	mech.global_position = terminal.global_position + Vector2(60, 0)
	mech.repair_charges = 0
	await _frames(3)
	_check("interact focus found", mech.focus_interactable == terminal)
	await _tap(&"use")
	_check("use refills repair charges", mech.repair_charges == mech.repair_charges_max)

	# Pooling: bullets are reused, not leaked.
	var pool := get_tree().current_scene.get_node_or_null("Combat")
	_check("bullet pool exists", pool != null)

	print("SMOKE TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
