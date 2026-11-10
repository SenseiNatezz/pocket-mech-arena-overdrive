extends Node
## Titan Graveyard (level 7) + Orbital Dry Dock (level 8) robots and bosses test:
##   godot --headless --path . -- --arena=7 --no-intro --attach=res://tools/frontier_test.gd --temp-save
##   godot --headless --path . -- --arena=8 --no-intro --attach=res://tools/frontier_test.gd --temp-save
## Arena 7: the Dune Burrower goes under (can't be hit) and erupts under the mech, the Sand Skiff rams
## and shoots, the Heliostat charges, locks and fires its sun lance; then SCARAB runs every attack in
## phase 3 (and can't be hurt while buried).
## Arena 8: the Mag Mine Drone lays mines that blow up near the mech, the Grav Tug's tractor beam drags
## the mech toward it, the Void Skimmer blinks next to the mech and fires; then ZENITH runs every attack
## in phase 3 (its gravity well pulls the mech in).

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


func _clear_spot(arena: Node, mech: Mech, dist: float) -> Vector2:
	var space := mech.get_world_2d().direct_space_state
	for i in 24:
		var p := mech.global_position + Vector2.from_angle(PI + TAU * i / 24.0) * dist
		var q := PhysicsRayQueryParameters2D.create(mech.global_position, p, 1 | 32)
		if arena.is_open(p, 70.0) and space.intersect_ray(q).is_empty():
			return p
	return mech.global_position + Vector2(-dist, 0)


func _clear_enemies(keep: Node = null) -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e != keep:
			e.queue_free()
	for m in get_tree().get_nodes_in_group("mag_mines"):
		m.queue_free()


func _spawn(arena: Node, mech: Mech, path: String, dist: float) -> Enemy:
	var e: Enemy = load(path).instantiate()
	e.position = _clear_spot(arena, mech, dist)
	arena.get_node("World").add_child(e)
	return e


func _run() -> void:
	Controls.ignore_real_input = true
	await _frames(30)
	var arena := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	var name: String = arena.get("arena_name")
	_check("arena loaded (%s)" % name, name == "Titan Graveyard" or name == "Orbital Dry Dock")
	if arena.zone:
		arena.zone.set_process(false)
		arena.zone.set_physics_process(false)
	_clear_enemies()
	await _frames(5)
	if name == "Titan Graveyard":
		await _graveyard(arena, mech)
	else:
		await _dock(arena, mech)
	print("FRONTIER TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _graveyard(arena: Node, mech: Mech) -> void:
	# Dune Burrower: dives (unhittable while under), tunnels in, erupts under the mech.
	var bur := _spawn(arena, mech, "res://enemies/dune_burrower.tscn", 420.0) as DuneBurrower
	var buried_safe := false
	var erupted := false
	var hit := false
	var dmg_seen := 0.0
	for i in 600:
		var hp0 := mech.hp
		await get_tree().physics_frame
		if mech.hp < hp0:
			dmg_seen += hp0 - mech.hp
		mech.hp = mech.max_hp
		if bur.is_buried() and not buried_safe:
			var h := bur.hp
			Combat.area_damage(bur.global_position, 80.0, 50.0, mech)
			buried_safe = is_equal_approx(h, bur.hp) and not bur.is_in_group("damageable")
		if bur._state == DuneBurrower.State.EMERGE:
			erupted = true
			hit = hit or dmg_seen > 0.0
			if i > 60:
				break
	_check("Dune Burrower can't be hit while it tunnels", buried_safe)
	_check("Dune Burrower erupts under the mech (%.0f damage)" % dmg_seen, erupted and dmg_seen > 0.0)
	bur.take_damage(9999.0, bur.global_position, mech)
	_clear_enemies()
	await _frames(5, mech)

	# Sand Skiff: shoots and rams.
	var sk := _spawn(arena, mech, "res://enemies/sand_skiff.tscn", 380.0) as SandSkiff
	var rammed := false
	for i in 600:
		await _frames(1, mech)
		rammed = rammed or sk._state == SandSkiff.State.RAM
		if rammed:
			break
	_check("Sand Skiff lines up and rams", rammed)
	_clear_enemies()
	await _frames(5, mech)

	# Heliostat: charge -> lock -> sun lance that hurts the mech in the open.
	var he := _spawn(arena, mech, "res://enemies/heliostat.tscn", 520.0) as Heliostat
	var locked := false
	var fired := false
	var lance_dmg := 0.0
	for i in 600:
		var hp0 := mech.hp
		await get_tree().physics_frame
		lance_dmg += maxf(hp0 - mech.hp, 0.0)
		mech.hp = mech.max_hp
		mech.velocity = Vector2.ZERO
		locked = locked or he._state == Heliostat.State.LOCK
		if he._state == Heliostat.State.FIRE:
			fired = true
			break
	await _frames(2)
	_check("Heliostat charges and locks its aim", locked)
	_check("Heliostat's sun lance hits a mech standing still (%.0f)" % lance_dmg, fired and lance_dmg >= 10.0)
	_clear_enemies()
	await _frames(5, mech)

	# SCARAB: every attack in phase 3; can't be hurt while buried.
	arena.debug_skip_to_boss()
	await _frames(240, mech)
	var boss := get_tree().get_first_node_in_group("boss") as ScarabBoss
	_check("SCARAB drops in", boss != null)
	if boss == null:
		return
	boss.phase = 3
	var attacks: Array[StringName] = [&"charge_warn", &"shards", &"dive", &"flare_warn", &"summon"]
	var ran := {}
	var buried_immune := false
	var flared := false
	var minions := 0
	for attack in attacks:
		_clear_enemies(boss)
		await _frames(2, mech)
		boss._roar = 0.0
		boss.begin_attack(attack)
		for i in 600:
			await _frames(1, mech)
			if not is_instance_valid(boss):
				break
			if boss._buried and not buried_immune:
				var h := boss.hp
				boss.take_damage(200.0, boss.global_position, mech)
				buried_immune = is_equal_approx(h, boss.hp)
			flared = flared or boss._state == &"flare"
			if attack == &"summon":
				minions = maxi(minions, get_tree().get_nodes_in_group("enemies").size() - 1)
			if boss._state == &"idle":
				ran[attack] = true
				break
	var missing := attacks.filter(func(s: StringName) -> bool: return not ran.has(s))
	_check("SCARAB runs every attack back to idle (missing: %s)" % str(missing), missing.is_empty())
	_check("SCARAB can't be hurt while it burrows", buried_immune)
	_check("the solar flare fires", flared)
	_check("it calls desert robots (%d)" % minions, minions >= 2)


func _dock(arena: Node, mech: Mech) -> void:
	# Mag Mine Drone: lays mines; a mine next to the mech blows up and hurts it.
	var dr := _spawn(arena, mech, "res://enemies/mag_mine_drone.tscn", 340.0) as MagMineDrone
	var laid := 0
	for i in 400:
		await _frames(1, mech)
		laid = maxi(laid, get_tree().get_nodes_in_group("mag_mines").size())
	_check("Mag Mine Drone lays mines (%d)" % laid, laid >= 2)
	dr.queue_free()
	for m in get_tree().get_nodes_in_group("mag_mines"):
		m.queue_free()
	var mine := MagMine.drop(mech.global_position + Vector2(60, 0), 20.0, null)
	var mine_dmg := 0.0
	for i in 120:
		var hp0 := mech.hp
		await get_tree().physics_frame
		mine_dmg += maxf(hp0 - mech.hp, 0.0)
		mech.hp = mech.max_hp
	_check("a mine near the mech blows up and hurts it (%.0f)" % mine_dmg, mine_dmg > 0.0 and not is_instance_valid(mine))
	_clear_enemies()
	await _frames(5, mech)

	# Grav Tug: the tractor beam drags the mech toward it.
	var tug := _spawn(arena, mech, "res://enemies/grav_tug.tscn", 400.0) as GravTug
	var beamed := false
	var closer := false
	for i in 600:
		var d0 := mech.global_position.distance_to(tug.global_position)
		await _frames(1, mech)
		if tug._state == GravTug.State.BEAM:
			beamed = true
			var d1 := mech.global_position.distance_to(tug.global_position)
			closer = closer or d1 < d0 - 1.0
			if closer:
				break
	_check("Grav Tug locks a tractor beam", beamed)
	_check("the beam drags the mech toward it", closer)
	_clear_enemies()
	await _frames(5, mech)

	# Void Skimmer: blinks next to the mech and bursts.
	var sk := _spawn(arena, mech, "res://enemies/void_skimmer.tscn", 420.0) as VoidSkimmer
	var blinked := false
	var near := false
	for i in 600:
		await _frames(1, mech)
		if sk._state == VoidSkimmer.State.BURST:
			blinked = true
			near = sk.global_position.distance_to(mech.global_position) < VoidSkimmer.BLINK_DIST + 40.0
			break
	_check("Void Skimmer blinks in beside the mech (near: %s)" % near, blinked and near)
	_clear_enemies()
	await _frames(5, mech)

	# ZENITH: every attack in phase 3; the gravity well pulls the mech in.
	arena.debug_skip_to_boss()
	await _frames(240, mech)
	var boss := get_tree().get_first_node_in_group("boss") as ZenithBoss
	_check("ZENITH drops in", boss != null)
	if boss == null:
		return
	boss.phase = 3
	var attacks: Array[StringName] = [&"broadside", &"strike", &"well", &"launch", &"gun_warn"]
	var ran := {}
	var pulled := false
	var gun_fired := false
	var minions := 0
	for attack in attacks:
		_clear_enemies(boss)
		await _frames(2, mech)
		boss._roar = 0.0
		boss.begin_attack(attack)
		for i in 600:
			var d0 := mech.global_position.distance_to(boss.global_position) if is_instance_valid(boss) else 0.0
			await _frames(1, mech)
			if not is_instance_valid(boss):
				break
			if boss._state == &"well" and mech.global_position.distance_to(boss.global_position) < d0 - 0.5:
				pulled = true
			gun_fired = gun_fired or boss._state == &"gun"
			if attack == &"launch":
				minions = maxi(minions, get_tree().get_nodes_in_group("enemies").size() - 1)
			if boss._state == &"idle":
				ran[attack] = true
				break
	var missing := attacks.filter(func(s: StringName) -> bool: return not ran.has(s))
	_check("ZENITH runs every attack back to idle (missing: %s)" % str(missing), missing.is_empty())
	_check("its gravity well pulls the mech in", pulled)
	_check("the main gun fires", gun_fired)
	_check("it launches dock robots (%d)" % minions, minions >= 2)
