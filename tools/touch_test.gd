extends Node
## Touch controls test:
##   godot --path . -- --gun-range --touch --attach=res://tools/touch_test.gd --temp-save
## (add --portrait for the portrait layout). Checks the touch auto-aim (locks onto the nearest drone,
## the mech turns to it, the lock-on marker exists), the FIRE button (tap = fire with auto-aim, drag =
## aim by hand, back to centre = auto-aim again, release = stop), the floating move stick, and that the
## right-hand button arc fits on screen without buttons overlapping - in the FULL and SIMPLE layouts.
## Then AUTO-FIRE (fires at the lock with no finger on FIRE), the SIMPLE layout's smart HEAT button and
## its automatic Overdrive.

var _fails := 0
var _dealt := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Player bolts in flight.
func _count_bolts() -> int:
	var n := 0
	for b in Combat._pool:
		if b.active and b.player_owned:
			n += 1
	return n


## Touch events arrive in window pixels (the headless window is tiny), so map from the game's canvas.
func _win(pos: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * pos


func _touch(pos: Vector2, pressed: bool, index := 0) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _win(pos)
	e.pressed = pressed
	Input.parse_input_event(e)
	await _frames(2)


func _drag(pos: Vector2, index := 0) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _win(pos)
	Input.parse_input_event(e)
	await _frames(2)


func _run() -> void:
	await _frames(10)
	var scene := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	var tc := scene.get_node("TouchControls")
	var root := tc.get_node("Root") as Control
	var fire := root.get_node("FireStick") as Control
	Combat.damage_dealt.connect(func(a: float, src: Node, _t: Node) -> void:
		if src == mech:
			_dealt += a)
	_check("touch device + controls visible", Controls.device == Controls.Device.TOUCH and tc.visible)
	_check("lock-on marker added", root.get_node_or_null("AutoAimMarker") != null)
	# (the manual FIRE checks below need auto-fire off; it's tested on its own at the end)
	Game.auto_fire = false

	# Layout: every right-hand control on screen, none overlapping another - both layouts.
	var vp := root.get_viewport_rect().size
	for simple in [false, true]:
		Game.touch_simple = simple
		await _frames(3)
		var names := ["FireStick", "Boost", "AltFire", "Beam"] + (["Heat"] if simple else ["Nova", "Cone", "Repair", "Overdrive"])
		var on_screen := true
		var overlaps := 0
		for i in names.size():
			var a := (root.get_node(names[i]) as Control).get_global_rect()
			if not Rect2(Vector2.ZERO, vp).encloses(a):
				on_screen = false
			for j in range(i + 1, names.size()):
				var b := (root.get_node(names[j]) as Control).get_global_rect()
				var ra := minf(a.size.x, a.size.y) / 2
				var rb := minf(b.size.x, b.size.y) / 2
				if a.get_center().distance_to(b.get_center()) < ra + rb + 2.0:
					overlaps += 1
					print("  overlap: %s / %s" % [names[i], names[j]])
		var tag := "simple" if simple else "full"
		_check("%s: button arc fits the %s screen (%dx%d)" % [tag, "portrait" if Layout.portrait else "landscape", vp.x, vp.y], on_screen)
		_check("%s: no two touch buttons overlap (%d)" % [tag, overlaps], overlaps == 0)
		var hidden := ["Nova", "Cone", "Repair", "Overdrive"] if simple else ["Heat"]
		_check("%s: the other layout's buttons are hidden" % tag, hidden.all(func(n: String) -> bool:
			return not (root.get_node(n) as Control).visible))
		var move_home := (root.get_node("MoveStick") as Control).get_global_rect()
		_check("%s: move stick home clear of the button arc" % tag,
			not move_home.intersects((root.get_node("Heat" if simple else "Cone") as Control).get_global_rect()))

	# Auto-aim: stand in the top firing lane facing away; the mech turns to the nearest drone.
	var lane: Vector2 = scene.get_node("Dummies/Lane1").global_position
	mech.global_position = lane - Vector2(320, 0)
	mech.velocity = Vector2.ZERO
	(mech.get_node("Camera2D") as Camera2D).reset_smoothing()
	Controls.set_aim(Vector2.LEFT)
	await _frames(30)
	var nearest: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_visible_in_tree() and (nearest == null or mech.global_position.distance_to(e.global_position) < mech.global_position.distance_to(nearest.global_position)):
			nearest = e
	var t := Controls.auto_target
	_check("auto-aim locks the nearest drone (%s)" % (t.name if t else "none"), t != null and t == nearest)
	_check("mech aims at it", t != null and mech.aim_dir.dot((t.global_position - mech.global_position).normalized()) > 0.98)

	# FIRE: tap and hold fires at the locked target.
	var c := fire.get_global_rect().get_center()
	_dealt = 0.0
	await _touch(c, true)
	_check("FIRE press fires", Controls.touch_fire and Controls.is_firing())
	await _frames(70)
	_check("auto-aimed shots hit (%.0f dmg)" % _dealt, _dealt > 0.0)

	# Drag on FIRE to aim by hand (down-left, away from the drone), then back to the middle.
	await _drag(c + Vector2(-90, 50))
	await _frames(3)
	var want := Vector2(-90, 50).normalized()
	_check("drag aims by hand (touch_aim %s)" % Controls.touch_aim, Controls.touch_aim.dot(want) > 0.98 and Controls.auto_target == null)
	_check("mech follows the hand aim", mech.aim_dir.dot(want) > 0.98)
	_check("still firing while hand-aiming", Controls.is_firing())
	await _drag(c + Vector2(6, 4))
	await _frames(3)
	_check("back to the middle = auto-aim again", Controls.touch_aim == Vector2.ZERO and Controls.auto_target != null)
	await _touch(c, false)
	_check("release stops firing", not Controls.is_firing() and Controls.touch_aim == Vector2.ZERO)

	# Move stick alone (first finger): moves without shooting, even though the OS turns that first
	# finger into an emulated left click (= the fire_primary mouse binding).
	var start := Vector2(vp.x * 0.2, vp.y * 0.75)
	await _frames(90)  # earlier bolts burn out
	var shots := _count_bolts()
	await _touch(start, true, 0)
	await _drag(start + Vector2(0, -70), 0)
	await _frames(30)
	_check("move stick moves (%s)" % Controls.touch_move, Controls.touch_move.y < -0.5)
	_check("move stick alone doesn't fire (%d new bolts)" % (_count_bolts() - shots), not Controls.is_firing() and _count_bolts() == shots)
	_check("device stays touch", Controls.device == Controls.Device.TOUCH)
	# ...and FIRE with a second finger at the same time.
	await _touch(c, true, 1)
	await _frames(3)
	_check("move stick + FIRE together", Controls.touch_move.y < -0.5 and Controls.is_firing())
	await _touch(start, false, 0)
	await _touch(c, false, 1)
	_check("both released", Controls.touch_move == Vector2.ZERO and not Controls.is_firing())

	# AUTO-FIRE: no finger on FIRE, the mech fires at the locked drone by itself.
	Game.auto_fire = true
	mech.global_position = lane - Vector2(320, 0)
	mech.velocity = Vector2.ZERO
	await _frames(20)
	_dealt = 0.0
	_check("auto-fire fires at the lock", Controls.auto_target != null and Controls.is_firing() and not Controls.touch_fire)
	await _frames(70)
	_check("auto-fire shots hit (%.0f dmg)" % _dealt, _dealt > 0.0)
	Game.auto_fire = false
	await _frames(2)
	_check("auto-fire off = no fire", not Controls.is_firing())

	# SIMPLE layout: the HEAT button picks an ability (Cone with nothing close), Overdrive goes off by itself.
	Game.touch_simple = true
	mech.heat = mech.heat_max
	var heat_btn := root.get_node("Heat") as Control
	await _touch(heat_btn.get_global_rect().get_center(), true, 2)
	await _touch(heat_btn.get_global_rect().get_center(), false, 2)
	_check("HEAT button spends heat (%.0f left)" % mech.heat, mech.heat < mech.heat_max)
	mech.overdrive_meter = 100.0
	await _frames(5)
	_check("simple layout: overdrive triggers by itself", mech.overdrive_left > 0.0)

	print("TOUCH TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
