extends Node
## Chassis test:  godot --headless --path . -- --gun-range --attach=res://tools/chassis_test.gd --temp-save
## Flies every Hangar chassis (Game.CHASSIS) in the Weapon Range, reloading the range for each one, and
## checks its stats, its art (own sheet or NIMBUS-07's tinted) and its signature trick:
## NIMBUS-07 4 cards, TEMPEST SALVO, ONIBI IAIDO, SOLSTICE BARRIER, CORVID drones, VESPER PHASE BLINK.

static var _running := false
var _fails := 0


func _ready() -> void:
	# The range reloads once per chassis; this node lives on the root so it survives (and any copy the
	# debug runner attaches to a reloaded range bows out).
	if _running:
		queue_free()
		return
	_running = true
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
	reparent(get_tree().root)
	await _frames(10)
	var saved: StringName = Game.chassis
	_check("8 chassis in the Hangar", Game.CHASSIS.size() == 8)
	for c: Dictionary in Game.CHASSIS:
		var id: StringName = c["id"]
		Game.chassis = id
		get_tree().reload_current_scene()
		await _frames(20)
		var mech := get_tree().get_first_node_in_group("player") as Mech
		if mech == null:
			_check("%s: mech spawned" % id, false)
			continue
		var tag := "%s (%s)" % [c["name"], id]
		_check("%s: flies this chassis" % tag, mech._chassis_id == id)
		var hp_ok := absf(mech.max_hp - mech._base_max_hp - Upgrades.max_hp_bonus()) < 0.01 \
			and mech._base_max_hp >= 100.0 * float(c["hp"]) - 0.01
		_check("%s: HP scaled by the frame (x%.2f -> %d)" % [tag, c["hp"], mech.max_hp], hp_ok)
		var own := not Game.chassis_placeholder(id)
		_check("%s: art (%s)" % [tag, "own sheet" if own else "NIMBUS-07 sheet, tinted"],
			mech._frames_gun != null and mech._frames_nogun != null
			and (mech.sprite.self_modulate == Color.WHITE) == own)
		if own and mech._frames_gun.resource_path.contains("/mechs/"):
			# A sheet from the mech pipeline ships its own per-frame fist table (held weapons stay pinned)
			# and Hangar portrait. NIMBUS-07's built-in sheet uses HeldWeapon's own tables instead.
			var dir := Game.MECH_SPRITES.get_base_dir() % String(c["sheet"])
			_check("%s: fists.tres + portrait.png" % tag,
				ResourceLoader.exists(dir + "/fists.tres") and ResourceLoader.exists(dir + "/portrait.png"))
		await _trick(id, tag, mech)
	Game.chassis = saved
	print("CHASSIS TEST OK (0 failed)" if _fails == 0 else "CHASSIS TEST FAILED (%d failed)" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Puts the mech right next to a Weapon Range target and returns that target.
func _near_target(mech: Mech) -> Node2D:
	var target: Node2D = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and not e.get("dead"):
			target = e
			break
	if target:
		mech.global_position = target.global_position + Vector2(-140, 0)
		mech.velocity = Vector2.ZERO
	return target


func _trick(id: StringName, tag: String, mech: Mech) -> void:
	match id:
		&"standard":
			_check("%s: ADAPTIVE CORE offers 4 cards" % tag, Upgrades.card_count() == 4)
		&"artillery":
			var target := _near_target(mech)
			_check("%s: a target in salvo range" % tag, target != null)
			mech._salvo_t = 0.0
			await _frames(3)
			_check("%s: SALVO fired and re-armed (%.1f s)" % [tag, mech._salvo_t], mech._salvo_t > Mech.SALVO_INTERVAL - 0.5)
		&"duelist":
			var gr := get_tree().current_scene
			gr.select_weapon(&"blaster", false)
			await _frames(3)
			_check("%s: guns hit for x0.8" % tag, is_equal_approx(mech._chassis_damage_mult(), Mech.IAIDO_GUNS))
			gr.select_weapon(&"sword", false)
			await _frames(3)
			_check("%s: melee hits for x1.3" % tag, is_equal_approx(mech._chassis_damage_mult(), Mech.IAIDO_MELEE))
			gr.select_weapon(&"blaster", false)
		&"guardian":
			_check("%s: starts with a BARRIER charge (no upgrade)" % tag, mech.shield_charges == 1)
			_check("%s: barrier recharges in %.1f s" % [tag, mech._shield_recharge()],
				is_equal_approx(mech._shield_recharge(), Mech.BARRIER_RECHARGE * Mech.BARRIER_FASTER))
			var target := _near_target(mech)
			var before: float = target.hp if target else 0.0
			mech._invuln = 0.0
			mech.take_damage(20.0, mech.global_position + Vector2.RIGHT, null)
			await _frames(4)
			_check("%s: the shield soaked the hit" % tag, mech.shield_charges == 0 and is_equal_approx(mech.hp, mech.max_hp))
			_check("%s: the break blasted the target (%.0f -> %.0f)" % [tag, before, target.hp if target else 0.0],
				target != null and target.hp < before)
		&"carrier":
			_check("%s: launches with 2 Bit Drones" % tag, Upgrades.drone_count() == 2)
		&"phantom":
			var moved := 0.0
			for dir: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
				mech.boost_cooldown_left = 0.0
				mech._boost_left = 0.0
				var from := mech.global_position
				mech._try_boost(dir)
				moved = maxf(moved, mech.global_position.distance_to(from))
				await _frames(2)
			_check("%s: PHASE BLINK jumps at once (%.0f px)" % [tag, moved], moved > 100.0)
			_check("%s: attacks after a blink are critical (x%.1f)" % [tag, mech._chassis_damage_mult()],
				is_equal_approx(mech._chassis_damage_mult(), Mech.BLINK_CRIT))
