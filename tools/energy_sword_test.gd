extends Node
## Energy Sword test:  godot --headless --path . -- --gun-range --attach=res://tools/energy_sword_test.gd --temp-save
## Unlock rules (beating the Volcanic Forge boss, or 40 waves), the sword held in the mech's hand with
## its cel smear, and its own move set: PIERCING LUNGE, X-CUT (the X bursts), RISING MOON, then CRESCENT
## NOVA (spin + a fan of three crescent waves that pierce the drone cluster).

var _fails := 0


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


func _run() -> void:
	await _frames(10)
	# Unlocks.
	var saved_unlocked := Game.unlocked.duplicate()
	var saved_cleared := Game.cleared.duplicate()
	var saved_waves := Game.waves_beaten
	Game.unlocked = [&"blaster"]
	Game.cleared = []
	Game.waves_beaten = 39
	Game.check_unlocks()
	_check("locked at first (%s)" % Game.unlock_text(&"energy_sword"), not Game.is_unlocked(&"energy_sword"))
	Game.cleared = [5]
	var fresh := Game.check_unlocks()
	_check("beating the Volcanic Forge boss unlocks it (%s)" % str(fresh), Game.is_unlocked(&"energy_sword") and fresh.has("Energy Sword"))
	Game.unlocked = [&"blaster"]
	Game.cleared = []
	Game.waves_beaten = 40
	Game.check_unlocks()
	_check("40 waves unlock it too", Game.is_unlocked(&"energy_sword"))
	Game.unlocked = saved_unlocked
	Game.cleared = saved_cleared
	Game.waves_beaten = saved_waves

	# In hand (Weapon Range: every weapon usable).
	var gr := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	gr.select_weapon(&"energy_sword", false)
	await _frames(5)
	_check("Energy Sword equipped", mech.weapon == &"energy_sword" and MeleeKit.has_weapon(&"energy_sword"))
	var rig: Node2D = mech.melee.rig
	_check("the sword is in the mech's hand (rig showing its art, cel mode)", rig.visible and rig._tex != null \
		and rig._tex.resource_path.ends_with("energy_sword.png") and rig._cel)
	_check("hilt held at the fist", rig._grip[0].distance_to(mech.global_position) < 60.0)

	# Combo: line up the cluster drones and swing 4 times.
	var cluster: Array = gr.get_node("Dummies").get_children().filter(func(d: Node) -> bool: return d.name.begins_with("Cluster"))
	var c := Vector2.ZERO
	for d in cluster:
		c += d.global_position
	c /= cluster.size()
	mech.global_position = c + Vector2(-260, 0)
	mech.velocity = Vector2.ZERO
	Controls.touch_aim = Vector2.RIGHT
	await _frames(10)
	var before := {}
	for d in cluster:
		before[d] = d.hp
	var finishers := 0
	var crescents := 0
	var smeared := false
	var modes: Array[String] = []
	var lunge_fx := false
	var x_mark := false
	var twisted := false
	for i in 4:
		if mech.melee.swing(&"energy_sword", 1.0):
			finishers += 1
		modes.append(String(rig._sw.get("mode", "")))
		# Hits land when the blade arrives (a few frames after the press), so watch the whole swing.
		for k in 20:
			await _frames(1)
			var fx := Combat.world().get_children()
			crescents = maxi(crescents, fx.filter(func(n: Node) -> bool: return n is EnergySwordFx.Crescent).size())
			lunge_fx = lunge_fx or fx.any(func(n: Node) -> bool: return n is EnergySwordFx.LungeFlash)
			x_mark = x_mark or fx.any(func(n: Node) -> bool: return n is EnergySwordFx.XMark)
			smeared = smeared or rig._trail[0].size() >= 2
			twisted = twisted or absf(mech.swing_twist) > 0.15
	_check("every hit is a different move: %s" % str(modes), modes == ["thrust", "xcut", "moon", "spin"])
	_check("the lunge leaves its beam streak", lunge_fx)
	_check("the X-cut leaves an X that bursts", x_mark)
	_check("the 4th hit is the CRESCENT NOVA finisher (%d)" % finishers, finishers == 1)
	_check("it launches a fan of three crescent waves (%d)" % crescents, crescents >= 3)
	_check("swings leave the cel smear", smeared)
	_check("the torso twists with the swing", twisted)
	await _frames(30)
	_check("the twist settles back after the combo (%.2f)" % mech.swing_twist, absf(mech.swing_twist) < 0.05)
	await _frames(40)
	var hit := cluster.filter(func(d: Node) -> bool: return is_instance_valid(d) and d.hp < before[d]).size()
	_check("the crescent pierces the drone cluster (%d of %d hit)" % [hit, cluster.size()], hit >= 2)
	print("ENERGY SWORD TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
