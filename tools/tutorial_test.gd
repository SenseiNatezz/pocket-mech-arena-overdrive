extends Node
## Plays the whole tutorial with real inputs (the same Input actions / sticks a player uses). Run:
##   godot --path . -- --tutorial --tutorial-test --temp-save
## Checks every step starts, completes from the right action, the prompts follow the device, the mech
## can't be destroyed, and finishing marks the tutorial done. Exit code 0 = all passed.

var _fails := 0
var tut: Node
var mech: Mech


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.ignore_real_input = true
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return cond.call()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)
	await _frames(2)


## Waits for step `id` to begin, runs `play` until the tutorial moves past it.
func _step(id: StringName, play: Callable, timeout := 20.0) -> void:
	var started := await _wait_until(func() -> bool: return tut.step_id() == id, 8.0)
	if not started:
		_check("step %s starts (stuck on %s)" % [id, tut.step_id()], false)
		return
	var t := 0.0
	while tut.step_id() == id and t < timeout:
		await play.call()
		t += 0.25
	_check("step %s completed" % id, tut.step_id() != id)


## Aim at + attack the nearest live target (drone or enemy) for a moment.
func _attack() -> void:
	var best: Node2D = null
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Node2D and n.visible and n.get("hp") > 0.0 and n.get("dead") != true:
			if best == null or n.global_position.distance_to(mech.global_position) < best.global_position.distance_to(mech.global_position):
				best = n
	if best:
		Controls.touch_aim = (best.global_position - mech.global_position).normalized()
		var d := best.global_position.distance_to(mech.global_position)
		Controls.touch_move = (best.global_position - mech.global_position).normalized() if d > 380.0 else Vector2.ZERO
	Input.action_press(&"fire_primary")
	await _frames(15)
	Input.action_release(&"fire_primary")
	Controls.touch_move = Vector2.ZERO


func _run() -> void:
	await _frames(10)
	tut = get_tree().current_scene
	mech = get_tree().get_first_node_in_group("player") as Mech
	_check("tutorial scene + mech loaded", tut != null and tut.name == "Tutorial" and mech != null)
	await _wait_until(func() -> bool: return tut.step == 0, 3.0)
	_check("panel shows step 1", tut.panel._card.visible and "1 /" in tut.panel._count.text)
	# Prompts follow the device.
	Controls.device = Controls.Device.KEYBOARD_MOUSE
	var kb: String = tut.step_text()
	Controls.device = Controls.Device.TOUCH
	var touch: String = tut.step_text()
	Controls.device = Controls.Device.GAMEPAD
	var pad: String = tut.step_text()
	_check("prompts per device (%s | %s | %s)" % [kb, pad, touch], "W A S D" in kb and "LEFT STICK" in pad and "thumb stick" in touch)
	Controls.device = Controls.Device.KEYBOARD_MOUSE

	await _step(&"move", func() -> void:
		Controls.touch_move = Vector2.RIGHT if int(Time.get_ticks_msec() / 800) % 2 == 0 else Vector2.LEFT
		await _frames(15))
	Controls.touch_move = Vector2.ZERO
	await _step(&"attack", _attack)
	await _step(&"boost", func() -> void:
		await _tap(&"boost")
		await _frames(70))
	await _step(&"scatter", func() -> void: await _tap(&"fire_secondary"))
	await _step(&"heat", func() -> void:
		await _tap(&"heat_attack_1")
		await _frames(10)
		await _tap(&"heat_attack_2")
		await _frames(10))
	await _step(&"beam", func() -> void:
		await _tap(&"beam")
		await _frames(50))
	mech._invuln = 0.0
	await _step(&"fight", _attack, 40.0)
	_check("mech can't be destroyed in training", not mech.dead and mech.hp >= tut.MIN_HP)
	await _step(&"level", func() -> void: await _frames(15))
	_check("level-up upgrade picked", Upgrades.level >= 2 and not Upgrades.stacks.is_empty())
	await _step(&"repair", func() -> void:
		await _tap(&"self_repair")
		await _frames(10))
	await _step(&"overdrive", func() -> void: await _tap(&"overdrive"))

	_check("training complete screen", await _wait_until(func() -> bool: return tut.finished and tut.panel._finish != null, 5.0))
	_check("tutorial marked done (saved)", Game.tutorial_done)
	_check("no waves or unlocks recorded", Game.waves_beaten == 0 and Game.endless_best == 0)

	print("TUTORIAL TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
