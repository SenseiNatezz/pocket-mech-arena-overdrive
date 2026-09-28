extends Node
## Gun Range test:  godot --path . -- --gun-range --gun-range-test --temp-save
## Every weapon can be selected (bar, hotkeys, Tab) and hits the target drones; every enemy type
## spawns and fights; CLEAR removes them; the mech can't die; nothing is recorded or saved.

var _fails := 0
var _dealt := 0.0


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
		if Upgrades.pending > 0 or Upgrades.choosing:
			Upgrades.pending = 0
			for m in get_tree().root.find_children("*", "", true, false):
				if m.has_method("is_open") and m.has_method("pick") and m.is_open():
					m.close()
			get_tree().paused = false


func _key(code: Key, shift := false) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.shift_pressed = shift
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await _frames(1)


func _run() -> void:
	await _frames(5)
	var gr := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	var equipped_before: StringName = Game.range_restore
	var waves_before := Game.waves_beaten
	var unlocked_before := Game.unlocked.size()
	_check("gun range loaded with the weapon bar", gr.has_method("select_weapon") and gr.panel._slots.size() == Game.WEAPONS.size())
	Combat.damage_dealt.connect(func(a: float, src: Node, _t: Node) -> void:
		if src == mech:
			_dealt += a)

	# Every weapon: select it, aim at the lane of drones and fire for a moment.
	for w in Game.WEAPONS:
		var id: StringName = w["id"]
		gr.select_weapon(id)
		_check("%s selected" % w["name"], mech.weapon == id and Game.weapon == id)
		var melee: bool = w.get("melee", false)
		# In the top firing lane, facing its target drone (Lane1).
		var lane: Vector2 = gr.get_node("Dummies/Lane1").global_position
		mech.global_position = lane - Vector2(120 if melee else 300, 0)
		mech.velocity = Vector2.ZERO
		Controls.touch_aim = Vector2.RIGHT
		await _frames(6)
		# Destroyed drones take 2.5 s to respawn: wait until the lane is back up.
		for t in 240:
			if gr.get_node("Dummies").get_children().all(func(d: Node) -> bool: return d.hp > 0.0):
				break
			await _frames(1)
		_dealt = 0.0
		Input.action_press(&"fire_primary")
		await _frames(100)
		Input.action_release(&"fire_primary")
		await _frames(10)
		_check("%s hits the drones (%.0f dmg)" % [w["name"], _dealt], _dealt > 0.0)

	# Hotkeys + Tab.
	await _key(KEY_3)
	_check("key 3 selects the 3rd weapon", mech.weapon == Game.WEAPONS[2]["id"])
	await _key(KEY_0)
	_check("key 0 selects the 10th weapon", mech.weapon == Game.WEAPONS[9]["id"])
	await _key(KEY_MINUS)
	_check("key - selects the 11th weapon", mech.weapon == Game.WEAPONS[10]["id"])
	await _key(KEY_TAB)
	_check("Tab wraps to the 1st weapon", mech.weapon == Game.WEAPONS[0]["id"])
	await _key(KEY_TAB, true)
	_check("Shift+Tab goes back", mech.weapon == Game.WEAPONS[Game.WEAPONS.size() - 1]["id"])

	# Big guns in hand: the gatling/rocket art shows and the muzzle moves to its barrel, then resets.
	var rifle_muzzle := Vector2(34, -48)
	for id: StringName in [&"gatling", &"rockets"]:
		gr.select_weapon(id)
		await _frames(3)
		_check("%s is drawn in the gun hand (muzzle %s)" % [id, mech.muzzle.position],
			mech.held.visible and mech.muzzle.position.y < rifle_muzzle.y - 30.0)
	gr.select_weapon(&"blaster")
	await _frames(3)
	_check("switching back restores the rifle muzzle", not mech.held.visible and mech.muzzle.position == rifle_muzzle)

	# Rocket splash: one rocket into the drone cluster also damages the drones next to the one it hits.
	gr.select_weapon(&"rockets")
	for t in 240:
		if gr.get_node("Dummies").get_children().all(func(d: Node) -> bool: return d.hp > 0.0):
			break
		await _frames(1)
	var cluster: Array = gr.get_node("Dummies").get_children().filter(func(d: Node) -> bool: return d.name.begins_with("Cluster"))
	var before := {}
	for d in cluster:
		before[d] = d.hp
	var center := Vector2.ZERO
	for d in cluster:
		center += d.global_position
	center /= cluster.size()
	mech.global_position = center + Vector2(420, 0)
	mech.velocity = Vector2.ZERO
	Controls.touch_aim = Vector2.LEFT
	await _frames(10)
	mech._fire_cd = 0.0
	mech._fire_primary(1.0)
	await _frames(40)
	var hit_n := cluster.filter(func(d: Node) -> bool: return d.hp < before[d]).size()
	_check("a rocket's explosion splashes past its target (%d drones hit)" % hit_n, hit_n >= 2)

	# Enemies on demand.
	mech.global_position = Vector2.ZERO
	for k in gr.ENEMY_KINDS:
		gr.spawn_enemy(k[0])
	await _frames(90)
	_check("every enemy type spawns (%d)" % gr._spawned.size(), gr._spawned.size() == gr.ENEMY_KINDS.size())
	await _frames(240)
	_check("mech can't be destroyed", not mech.dead and mech.hp == mech.max_hp)
	var one: Enemy = gr._spawned[0]
	one.die()
	await _frames(5)
	var mines_before := get_tree().get_nodes_in_group("damageable").filter(func(n: Node) -> bool: return n is Widow.Mine).size()
	gr.clear_enemies()
	await _frames(5)
	var left := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			left += 1
	var mines := 0
	for n in get_tree().get_nodes_in_group("damageable"):
		if n is Widow.Mine:
			mines += 1
	_check("CLEAR removes spawned enemies (%d left)" % left, left == 0)
	_check("CLEAR also removes Widow mines (%d laid, %d left)" % [mines_before, mines], mines == 0)

	# Bosses: each one spawns with the HUD health bar; a new one replaces the old; phases work.
	var hud := gr.get_node("HUD")
	for k in gr.BOSS_KINDS:
		gr.spawn_boss(k[0])
		await _frames(40)
		var bosses := get_tree().get_nodes_in_group("boss").filter(func(b: Node) -> bool: return not b.is_queued_for_deletion())
		var b: Enemy = gr._boss
		_check("%s spawns as the only boss with the HUD bar (%d)" % [k[1], bosses.size()],
			bosses.size() == 1 and is_instance_valid(b) and hud.boss == b and b.max_hp == gr.BOSS_HP)
	var boss: Enemy = gr._boss
	await _frames(120)
	boss.take_damage(boss.max_hp * 0.36, boss.global_position, mech)
	await _frames(90)
	boss.take_damage(boss.max_hp * 0.36, boss.global_position, mech)
	_check("range boss reaches phase 3", boss.get("phase") == 3)
	await _frames(240)
	gr.clear_enemies()
	await _frames(5)
	var rest := get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return e is Enemy)
	_check("CLEAR removes the boss and its summons (%d left)" % rest.size(), rest.is_empty())

	# Nothing recorded; the equipped weapon is what gets saved.
	_check("no waves recorded (%d -> %d)" % [waves_before, Game.waves_beaten], Game.waves_beaten == waves_before)
	_check("no unlocks granted", Game.unlocked.size() == unlocked_before)
	_check("equipped weapon kept for saving (%s)" % equipped_before, equipped_before != &"" and Game.range_restore == equipped_before)
	print("GUN RANGE TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
