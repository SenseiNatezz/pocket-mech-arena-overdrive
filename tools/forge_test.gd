extends Node
## Volcanic Forge robots + boss test (level 6):
##   godot --headless --path . -- --arena=6 --no-intro --attach=res://tools/forge_test.gd --temp-save
## Each new robot runs its AI next to the (kept-alive) mech and does its thing: the Magma Crawler drips
## lava and lunges, the Slagspitter lobs globs that leave lava, the Anvil leaps and slams. Lava pools
## burn the mech (and never robots). Then VULCAN drops in and every one of its attacks fires in phase 3,
## including the core beams (open core takes extra damage).

var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_fails += 1


func _frames(n: int, mech: Mech = null) -> void:
	for i in n:
		await get_tree().physics_frame
		if mech and not mech.dead:
			mech.hp = mech.max_hp
		if Upgrades.pending > 0 or Upgrades.choosing:
			Upgrades.pending = 0
			for m in get_tree().root.find_children("*", "", true, false):
				if m.has_method("is_open") and m.has_method("pick") and m.is_open():
					m.close()
			get_tree().paused = false


## A point `dist` from the mech on open floor with a clear line of sight to it (walls / cover block).
func _clear_spot(arena: Node, mech: Mech, dist: float) -> Vector2:
	var space := mech.get_world_2d().direct_space_state
	for i in 24:
		var p := mech.global_position + Vector2.from_angle(PI + TAU * i / 24.0) * dist
		var q := PhysicsRayQueryParameters2D.create(mech.global_position, p, 1 | 32)
		if arena.is_open(p, 70.0) and space.intersect_ray(q).is_empty():
			return p
	return mech.global_position + Vector2(-dist, 0)


func _pools() -> int:
	return get_tree().get_nodes_in_group("lava_pools").size()


func _run() -> void:
	Controls.ignore_real_input = true
	await _frames(30)
	var arena := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	_check("Volcanic Forge loaded (%s)" % arena.get("arena_name"), arena.get("arena_name") == "Volcanic Forge")
	# Keep the wave director out of the way.
	if arena.zone:
		arena.zone.set_process(false)
		arena.zone.set_physics_process(false)
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await _frames(5)
	var parent: Node = arena.get_node("World")
	var at := mech.global_position

	# Lava pools burn the mech, not robots.
	var hp0 := mech.hp
	var pool := LavaPool.spawn(at, 60.0, 2.0, 30.0)
	await _frames(40)
	_check("a lava pool burns the mech (%.0f -> %.0f)" % [hp0, mech.hp], mech.hp < hp0)
	pool.queue_free()

	# Magma Crawler: trail + lunge, then a big pool when it dies.
	var crawler: MagmaCrawler = load("res://enemies/magma_crawler.tscn").instantiate()
	crawler.position = _clear_spot(arena, mech, 390.0)
	parent.add_child(crawler)
	var lunged := false
	var before := _pools()
	for i in 300:
		await _frames(1, mech)
		lunged = lunged or crawler._state == MagmaCrawler.State.LUNGE
	_check("Magma Crawler drips lava (%d pools)" % (_pools() - before), _pools() > before)
	_check("Magma Crawler lunges", lunged)
	crawler.take_damage(9999.0, crawler.global_position, mech)
	await _frames(3, mech)
	var big_pool := get_tree().get_nodes_in_group("lava_pools").any(func(p: LavaPool) -> bool: return p.radius >= 70.0)
	_check("its sac bursts into a big lava pool when it dies", big_pool)
	for p in get_tree().get_nodes_in_group("lava_pools"):
		p.queue_free()

	# Slagspitter: keeps its distance and lobs globs that leave lava.
	var spitter: Slagspitter = load("res://enemies/slagspitter.tscn").instantiate()
	spitter.position = at + Vector2(0, -420)
	parent.add_child(spitter)
	await _frames(420, mech)
	_check("Slagspitter's globs leave lava (%d pools)" % _pools(), _pools() > 0)
	_check("Slagspitter keeps its distance (%.0f px)" % spitter.global_position.distance_to(mech.global_position),
		spitter.global_position.distance_to(mech.global_position) > 250.0)
	var hp_s := spitter.hp
	spitter.take_damage(10.0, spitter.global_position - spitter.facing * 50.0, mech)
	_check("its furnace tank takes double damage from behind (%.0f)" % (hp_s - spitter.hp), hp_s - spitter.hp >= 19.0)
	spitter.queue_free()

	# Anvil: leaps in and slams (dropped on open floor in plain view, inside its leap range).
	var anvil: Anvil = load("res://enemies/anvil.tscn").instantiate()
	anvil.position = _clear_spot(arena, mech, 340.0)
	parent.add_child(anvil)
	var leapt := false
	var stuck := false
	for i in 480:
		await _frames(1, mech)
		leapt = leapt or anvil._state == Anvil.State.LEAP
		stuck = stuck or anvil._state == Anvil.State.STUCK
	_check("Anvil leaps", leapt)
	_check("Anvil slams down (stuck after)", stuck)
	anvil.queue_free()
	for p in get_tree().get_nodes_in_group("lava_pools"):
		p.queue_free()
	await _frames(5, mech)

	# VULCAN: every attack in phase 3.
	arena.debug_skip_to_boss()
	await _frames(240, mech)
	var boss := get_tree().get_first_node_in_group("boss") as VulcanBoss
	_check("VULCAN drops in", boss != null)
	if boss:
		boss.phase = 3
		var ran := {}
		var boss_leapt := false
		var beams_extra := false
		var lava := {}
		var minions := 0
		# Start each attack in turn and let it play out back to idle. (Lob, eruption and summon fire on
		# their first frame, so they're judged by what they leave behind.)
		for attack: StringName in [&"crouch", &"lob", &"cannon", &"eruption", &"summon", &"beams"]:
			for e in get_tree().get_nodes_in_group("enemies"):
				if e != boss:
					e.queue_free()
			for p in get_tree().get_nodes_in_group("lava_pools"):
				p.queue_free()
			await _frames(2, mech)
			boss._roar = 0.0
			boss.begin_attack(attack)
			for i in 480:
				await _frames(1, mech)
				if not is_instance_valid(boss):
					break
				boss_leapt = boss_leapt or boss._state == &"leap"
				lava[attack] = maxi(lava.get(attack, 0), _pools())
				if attack == &"summon":
					minions = maxi(minions, get_tree().get_nodes_in_group("enemies").size() - 1)
				if boss._state == &"beams" and boss._state_t < VulcanBoss.BEAM_TIME and not beams_extra:
					var h := boss.hp
					boss.take_damage(100.0, boss.global_position, mech)
					beams_extra = h - boss.hp >= 149.0
				if boss._state == &"idle":
					ran[attack] = true
					break
		var missing := [&"crouch", &"lob", &"cannon", &"eruption", &"summon", &"beams"].filter(
			func(s: StringName) -> bool: return not ran.has(s))
		_check("VULCAN runs every attack back to idle (missing: %s)" % str(missing), missing.is_empty())
		_check("the hammer slam leaps", boss_leapt)
		_check("lob / eruption leave lava (%d / %d pools)" % [lava.get(&"lob", 0), lava.get(&"eruption", 0)],
			lava.get(&"lob", 0) >= 4 and lava.get(&"eruption", 0) >= 8)
		_check("it summons forge robots (%d)" % minions, minions >= 2)
		_check("its open core takes +50% damage during the beams", beams_extra)
	print("FORGE TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
