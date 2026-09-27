extends Node
## Full arena flow test:  godot --path . -- --arena=1 --arena-test
## Checks layout, navigation, props, pits, hazards, pickups, the 5-wave encounter, the boss door,
## all boss phases and the victory screen. Prints PASS/FAIL lines; exit code 0 = all passed.

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


func _count(script_name: String) -> int:
	var n := 0
	for node in arena.find_children("*", "", true, false):
		var s: Script = node.get_script()
		if s and s.resource_path.ends_with(script_name):
			n += 1
	return n


func _first(script_name: String) -> Node:
	for node in arena.find_children("*", "", true, false):
		var s: Script = node.get_script()
		if s and s.resource_path.ends_with(script_name):
			return node
	return null


func _run() -> void:
	await _frames(10)
	arena = get_tree().current_scene
	mech = get_tree().get_first_node_in_group("player") as Mech
	_check("arena + mech loaded", arena.is_in_group("arena") and mech != null)
	mech._invuln = 1e9
	_check("mech placed at spawn", mech.global_position.distance_to(arena.player_spawn) < 5.0)
	_check("floor tiles painted (%d)" % arena.floor_layer.get_used_cells().size(), arena.floor_layer.get_used_cells().size() > 500)
	_check("wall tiles painted (%d)" % arena.wall_layer.get_used_cells().size(), arena.wall_layer.get_used_cells().size() > 100)
	var boss_center: Vector2 = arena.rect_center(arena.boss_rect)
	await _frames(5)
	var map: RID = get_viewport().world_2d.navigation_map
	var path := NavigationServer2D.map_get_path(map, mech.global_position, arena.zone.global_position, true)
	_check("navmesh path spawn -> zone (%d pts)" % path.size(), path.size() >= 2 and path[path.size() - 1].distance_to(arena.zone.global_position) < 120.0)
	_check("pits placed (%d)" % _count("pit.gd"), _count("pit.gd") >= 1)
	_check("cover placed (%d)" % _count("cover_block.gd"), _count("cover_block.gd") >= 4)
	_check("crates placed (%d)" % _count("crate.gd"), _count("crate.gd") >= 2)
	_check("barrels placed (%d)" % _count("explosive_barrel.gd"), _count("explosive_barrel.gd") >= 2)
	_check("electric panels placed (%d)" % _count("electric_panel.gd"), _count("electric_panel.gd") >= 1)
	_check("repair stations (%d)" % _count("repair_station.gd"), _count("repair_station.gd") in [1, 2])
	_check("boss door locked", not arena.door.is_open)

	# Pit: walking in costs HP and respawns at the edge.
	var pit: Node2D = _first("pit.gd")
	mech._invuln = 0.0
	var hp0 := mech.hp
	mech.global_position = pit.global_position + Vector2(pit.size.x / 2 + 70, 0)
	await _frames(4)
	Controls.touch_move = Vector2.LEFT
	await _wait_until(func() -> bool: return mech.is_falling(), 2.0)
	Controls.touch_move = Vector2.ZERO
	_check("walking into a pit makes the mech fall", mech.is_falling())
	await _wait_until(func() -> bool: return not mech.is_falling(), 2.0)
	var in_pit := Rect2(pit.global_position - pit.size / 2, pit.size).has_point(mech.global_position)
	_check("pit fall costs HP (%.0f -> %.0f) and respawns outside" % [hp0, mech.hp], mech.hp < hp0 and not in_pit)
	# Boost clears a pit (across its narrow side).
	var horizontal: bool = pit.size.x <= pit.size.y
	var axis := Vector2.RIGHT if horizontal else Vector2.DOWN
	var width: float = pit.size.x if horizontal else pit.size.y
	mech.global_position = pit.global_position - axis * (width / 2 + 30)
	await _frames(50)
	var hp_before_boost := mech.hp
	Controls.touch_move = axis
	Input.action_press(&"boost")
	await _frames(2)
	Input.action_release(&"boost")
	await _frames(30)
	Controls.touch_move = Vector2.ZERO
	var crossed := (mech.global_position - pit.global_position).dot(axis) > width / 2
	_check("boosting across a %.0f px pit doesn't fall" % width, not mech.is_falling() and mech.hp == hp_before_boost and crossed)
	mech.hp = mech.max_hp
	mech._invuln = 1e9

	# Electric panel hurts after its warning.
	var panel: Node2D = _first("electric_panel.gd")
	mech.global_position = panel.global_position
	mech._invuln = 0.0
	var hp1 := mech.hp
	await _wait_until(func() -> bool: return mech.hp < hp1, 6.0)
	_check("electric panel damages when live", mech.hp < hp1)
	mech._invuln = 1e9
	mech.hp = mech.max_hp
	mech.global_position = arena.player_spawn
	await _frames(5)

	# Barrel explodes (and can chain).
	var barrels_before := _count("explosive_barrel.gd")
	var barrel := _first("explosive_barrel.gd")
	barrel.take_hit(999.0, barrel.global_position)
	await _frames(30)
	_check("barrel explodes (%d -> %d)" % [barrels_before, _count("explosive_barrel.gd")], _count("explosive_barrel.gd") < barrels_before)
	# Crate drops a pickup that the mech collects.
	var crate := _first("crate.gd")
	crate.set("drop_chance", 1.0)
	var crate_pos: Vector2 = crate.global_position
	crate.take_hit(999.0, crate.global_position)
	await _frames(3)
	_check("crate drops a pickup", _count("pickup.gd") >= 1)
	mech.heat = 0.0
	mech.hp = 50.0
	mech.repair_charges = 0
	mech.overdrive_meter = 0.0
	mech.global_position = crate_pos + Vector2(0, 5)
	await _frames(20)
	_check("pickup collected", _count("pickup.gd") == 0 and (mech.hp > 50.0 or mech.heat > 0.0 or mech.repair_charges > 0 or mech.overdrive_meter > 0.0))
	mech.hp = mech.max_hp
	mech.repair_charges = mech.repair_charges_max

	# Cover takes several hits then breaks.
	var cover := _first("cover_block.gd")
	cover.take_hit(60.0, cover.global_position)
	await _frames(2)
	_check("cover survives a few hits", is_instance_valid(cover))
	cover.take_hit(500.0, cover.global_position)
	await _frames(2)
	_check("cover breaks after enough damage", not is_instance_valid(cover))

	# Encounter zone: 5 waves.
	mech.global_position = arena.zone.global_position
	await _wait_until(func() -> bool: return arena.zone.is_running, 2.0)
	_check("zone starts when the player enters", arena.zone.is_running)
	_check("barrier seals the zone", arena.zone.barriers[0].active)
	var moved_checked := false
	for w in arena.waves.size():
		await _wait_until(func() -> bool: return arena.zone.wave == w + 1 and arena.zone._pending == 0 and arena.zone.alive_count() > 0, 12.0)
		_check("wave %d spawned %d enemies" % [w + 1, arena.zone.alive_count()], arena.zone.wave == w + 1 and arena.zone.alive_count() > 0)
		if not moved_checked:
			moved_checked = true
			var e: Enemy = arena.zone._alive[0]
			var p0 := e.global_position
			mech._invuln = 1e9
			await _frames(90)
			_check("enemies move (%.0f px in 1.5 s)" % (e.global_position.distance_to(p0) if is_instance_valid(e) else -1.0),
				is_instance_valid(e) and e.global_position.distance_to(p0) > 30.0)
		for e in arena.zone._alive.duplicate():
			if is_instance_valid(e):
				e.die()
	await _wait_until(func() -> bool: return arena.zone.is_cleared, 5.0)
	_check("zone cleared after 5 waves", arena.zone.is_cleared)
	_check("barrier drops", not arena.zone.barriers[0].active)
	_check("boss door opens", arena.door.is_open)

	# Boss.
	mech.global_position = boss_center + Vector2(0, arena.boss_rect.size.y * 16)
	await _wait_until(func() -> bool: return arena.boss != null, 3.0)
	var boss = arena.boss
	_check("boss spawns in the boss room", boss != null)
	_check("door closes behind the player", not arena.door.is_open)
	await _frames(150)
	var bullets := 0
	for b in Combat.world().get_children():
		if b is Bullet and b.active and not b.player_owned:
			bullets += 1
	_check("boss attacks (%d enemy bullets / strikes)" % bullets, bullets > 0 or Combat.world().get_children().any(func(n): return n.get("delay") != null))
	boss.take_damage(boss.max_hp * 0.36, boss.global_position, mech)
	_check("boss phase 2 at 66%", boss.phase == 2)
	await _frames(90)
	boss.take_damage(boss.max_hp * 0.36, boss.global_position, mech)
	_check("boss phase 3 at 33%", boss.phase == 3)
	await _frames(90)
	boss.take_damage(boss.max_hp, boss.global_position, mech)
	var hud := arena.get_node("HUD")
	await _wait_until(func() -> bool: return hud._win_panel.visible, 8.0)
	_check("victory screen after the boss dies", hud._win_panel.visible)
	_check("arena marked cleared", Game.cleared.has(Game.arena_index))
	print("ARENA TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
