extends Node
## Endless mode flow test. Run:
##   godot --path . -- --endless --endless-test --temp-save --no-intro
## Plays 6 waves by wiping each one out (the mech is invulnerable): waves keep coming and grow, enemies
## get tougher, wave 5 is a boss wave, level-ups happen (auto-picked), the best wave is saved and
## unlocks the Sniper Beam, and dying shows the Endless results. Exit code 0 = all passed.

var _fails := 0
var arena: Node
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


func _enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.dead:
			out.append(e)
	return out


func _run() -> void:
	await _frames(10)
	arena = get_tree().current_scene
	mech = get_tree().get_first_node_in_group("player") as Mech
	mech._invuln = 1e9
	_check("endless mode starts on an open map", Game.is_endless() and arena is ScenicArena and arena.zone.endless)
	_check("arena is labelled as Endless", str(arena.arena_name).begins_with("Endless"))
	_check("fight starts", await _wait_until(func() -> bool: return arena.zone.is_running, 6.0))

	var sizes := {}
	var chaser_hp := {}
	var boss_seen := false
	var boss_hp := 0.0
	for w in range(1, 7):
		var started := await _wait_until(func() -> bool: return arena.zone.wave >= w, 25.0)
		if not started:
			_check("wave %d starts" % w, false)
			break
		# Let the whole wave warp in (and a boss drop in on boss waves).
		await _wait_until(func() -> bool: return arena.zone._pending == 0, 15.0)
		await _frames(2)
		sizes[w] = arena.zone._alive.size()
		for e in _enemies():
			if e is Chaser:
				chaser_hp[w] = e.max_hp
				break
		var boss := get_tree().get_first_node_in_group("boss") as Enemy
		if boss and not boss.dead:
			boss_seen = true
			boss_hp = boss.max_hp
		# Wipe the wave out (bosses too: several heavy hits to push through their phases).
		var cleared := await _wait_until(func() -> bool:
			for e in _enemies():
				if e.is_in_group("boss"):
					e.take_damage(e.max_hp * 0.2, e.global_position, mech)
				else:
					e.die()
			return arena.zone.wave > w or Game.endless_wave >= w, 30.0)
		_check("wave %d (%d enemies) cleared" % [w, sizes[w]], cleared)
		if w == 5:
			_check("wave 5 is a boss wave (boss HP %.0f)" % boss_hp, boss_seen and boss_hp >= 1500.0)

	_check("waves grow (%s)" % str(sizes), sizes.get(4, 0) > sizes.get(1, 0) and sizes.get(6, 0) > sizes.get(4, 0))
	_check("enemies get tougher (chaser HP %s)" % str(chaser_hp),
		chaser_hp.has(1) and chaser_hp.has(6) and chaser_hp[6] > chaser_hp[1] * 1.4)
	_check("best wave saved (%d)" % Game.endless_best, Game.endless_best >= 6)
	_check("5 waves beaten unlock the Sniper Beam", Game.is_unlocked(&"sniper"))
	_check("leveled up along the way (level %d, %d upgrades)" % [Upgrades.level, Upgrades.stacks.size()],
		Upgrades.level >= 3 and not Upgrades.stacks.is_empty())
	await _new_robots()

	# Stuck-wave safety nets. Let the next wave warp in, then keep one enemy alive.
	await _wait_until(func() -> bool: return arena.zone._pending == 0 and not arena.zone._alive.is_empty(), 20.0)
	await _frames(5)
	var keep: Enemy = null
	for e in _enemies():
		if keep == null and not e.is_in_group("boss"):
			keep = e
		elif not e.is_in_group("boss"):
			e.die()
	await _frames(5)
	if keep and not arena._layout.obstacles.is_empty():
		# 1) Shoved inside a solid obstacle -> rescued back onto open floor.
		var poly: PackedVector2Array = arena._layout.obstacles[0]
		var c := Vector2.ZERO
		for p in poly:
			c += p
		keep.global_position = arena.map_to_world(c / poly.size())
		keep.move_speed = 0.0
		await _frames(45)
		var lp: Vector2 = keep.global_position / arena._k
		_check("enemy wedged inside an obstacle is rescued", not Geometry2D.is_point_in_polygon(lp, poly))
		# 2) Nobody kills it for STALL_TIME (20 s) -> it warps in near the mech.
		# (a far spot that IS on the floor, so only the stall guard can move it)
		var far := keep.global_position
		for p in arena.zone.spawn_points:
			if p.distance_to(mech.global_position) > far.distance_to(mech.global_position):
				far = p
		keep.global_position = far
		var warped := await _wait_until(func() -> bool: return keep.global_position.distance_to(far) > 50.0, 36.0)
		var d := keep.global_position.distance_to(mech.global_position)
		_check("stuck last enemy warps in near the mech (%.0f px away)" % d, warped and d > 250.0 and d < 900.0)
		keep.die()

	# Death -> Endless results.
	await _wait_until(func() -> bool: return not Upgrades.choosing, 10.0)
	mech._invuln = 0.0
	mech.shield_charges = 0
	mech.take_damage(99999.0, mech.global_position)
	var hud := arena.get_node("HUD")
	_check("game over shows Endless results", await _wait_until(func() -> bool: return hud._over_panel.visible, 6.0)
		and "Survived" in hud._over_stats.text)
	print(hud._over_stats.text)

	print("ENDLESS TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


## The Endless-only robots: late mixes bring them in (elites capped), early ones don't, and all six
## run their AI next to the (invulnerable) mech for a few seconds: mines, flames, lunges, charges, wards.
func _new_robots() -> void:
	var kinds := ["hornet", "coil", "widow", "cinder", "bastion", "tidebreaker"]
	var seen := {}
	var caps_ok := true
	for i in 40:
		var l: Array[String] = arena.zone.endless_wave(24)
		for k in l:
			seen[k] = true
		caps_ok = caps_ok and l.count("bastion") <= 3 and l.count("tidebreaker") <= 2
	_check("late Endless waves bring the new robots (%s)" % ", ".join(seen.keys()), kinds.all(func(k: String) -> bool: return seen.has(k)))
	_check("Bastion / Tidebreaker per-wave caps hold", caps_ok)
	_check("early waves don't have them", not arena.zone.endless_wave(2).any(func(k: String) -> bool: return k in kinds))
	var center := mech.global_position + Vector2(320, 0)
	var bots := {}
	for i in kinds.size():
		var e: Enemy = arena.zone.ENEMIES[kinds[i]].instantiate()
		e.position = center + Vector2.from_angle(TAU * i / kinds.size()) * 110.0
		(arena.zone.enemy_parent if arena.zone.enemy_parent else arena.zone.get_parent()).add_child(e)
		bots[kinds[i]] = e
	await _frames(360)
	_check("all six new robots run their AI for 6 s", kinds.all(func(k: String) -> bool:
		return is_instance_valid(bots[k]) and not bots[k].dead))
	_check("Widow lays mines (%d)" % bots["widow"].mines_laid, bots["widow"].mines_laid > 0)
	_check("Bastion wards nearby robots (%d)" % bots["bastion"]._warded.size(), not bots["bastion"]._warded.is_empty())
	_check("Tidebreaker has armor", bots["tidebreaker"].max_armor > 0.0)
	# Warded robots take half damage.
	var ally: Enemy = bots["bastion"]._warded[0] if not bots["bastion"]._warded.is_empty() else null
	if ally and is_instance_valid(ally):
		var before: float = ally.hp + ally.armor
		ally.take_damage(10.0, ally.global_position + Vector2(0, 1), mech)
		_check("warded robot takes half damage (%.1f)" % (before - ally.hp - ally.armor), is_equal_approx(before - ally.hp - ally.armor, 5.0)
			or ally.armor_tier > 0)
	# Cinder's fuel tanks blow when it dies (no errors, hurts nearby robots).
	for k in kinds:
		if is_instance_valid(bots[k]) and not bots[k].dead:
			bots[k].die()
	await _frames(10)
	_check("new robots die cleanly", kinds.all(func(k: String) -> bool: return not is_instance_valid(bots[k]) or bots[k].dead))
