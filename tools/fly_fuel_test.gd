extends Node
## FLIGHT FUEL test (player/mech.gd: FLY_SPEED, fly_fuel, fly_locked):
##   godot --headless --path . -- --gun-range --temp-save --attach=res://tools/fly_fuel_test.gd
## NIMBUS-07 walks, takes off (faster), burns the tank dry, is forced down and can't take off until the tank is
## full again; then lands early and takes off again on a part-filled tank. -> "FLY FUEL TEST OK (0 failed)"

static var _running := false
var _fails := 0


func _ready() -> void:
	if _running:
		queue_free()
		return
	_running = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * Engine.physics_ticks_per_second))


func _toggle() -> void:
	Input.action_press(&"hover_toggle")
	await _frames(1)
	Input.action_release(&"hover_toggle")
	await _frames(2)


func _top_speed(mech: Mech, dir: Vector2) -> float:
	mech.global_position = _home
	Controls.touch_move = dir
	await _frames(50)
	var v := mech.velocity.length()
	Controls.touch_move = Vector2.ZERO
	await _frames(20)
	mech.global_position = _home
	return v


var _home := Vector2.ZERO


func _run() -> void:
	reparent(get_tree().root)
	Controls.ignore_real_input = true
	await _frames(10)
	var mech := get_tree().get_first_node_in_group("player") as Mech
	_home = mech.global_position
	_check("NIMBUS-07 can switch, so it flies on fuel", mech.fuel_on)
	_check("starts on foot with a full tank", not mech._hover and mech.fly_fuel >= 1.0)

	var walk := await _top_speed(mech, Vector2.RIGHT)
	await _toggle()
	_check("takes off", mech._hover)
	var fly := await _top_speed(mech, Vector2.LEFT)
	_check("flying is faster (%.0f vs %.0f walking)" % [fly, walk], fly > walk * 1.25)
	_check("flying burns fuel (%.2f left)" % mech.fly_fuel, mech.fly_fuel < 0.9)

	# Burn the rest of the tank.
	var empty := [false]
	mech.fuel_empty.connect(func() -> void: empty[0] = true)
	await _seconds(Mech.FLY_FUEL_TIME)
	_check("ran dry: forced to land", not mech._hover and empty[0])
	_check("grounded until refilled", mech.fly_locked and not mech.can_take_off())
	await _toggle()
	_check("can't take off on an empty tank", not mech._hover)
	await _seconds(Mech.FLY_REFILL_TIME * 0.6)
	await _toggle()
	_check("still can't take off half full after running dry (%.2f)" % mech.fly_fuel, not mech._hover and mech.fly_locked)
	await _seconds(Mech.FLY_REFILL_TIME * 0.5 + Mech.FLY_REFILL_DELAY)
	_check("tank full again (%.2f), unlocked" % mech.fly_fuel, mech.fly_fuel >= 1.0 and not mech.fly_locked)
	await _toggle()
	_check("takes off again", mech._hover)

	# Land early: refills from where it was and can take off again without waiting for a full tank.
	await _seconds(2.0)
	await _toggle()
	_check("lands on demand with fuel left (%.2f)" % mech.fly_fuel, not mech._hover and not mech.fly_locked)
	await _seconds(0.6)
	var before := mech.fly_fuel
	await _seconds(0.5)
	_check("refills on the ground (%.2f -> %.2f)" % [before, mech.fly_fuel], mech.fly_fuel > before)
	await _toggle()
	_check("takes off again on a part-filled tank", mech._hover)

	print("FLY FUEL TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1
