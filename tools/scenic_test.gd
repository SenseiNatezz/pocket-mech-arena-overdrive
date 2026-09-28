extends Node
## Flow test for painted 2.5D levels (ScenicArena):  godot --path . -- --arena=1 --arena-test
## Checks art, collision edges, obstacles, occluder fading, hazards, props, 5 waves, boss drop-in,
## boss phases and the victory screen. Exit code 0 = all passed.

var _fails := 0
var arena: ScenicArena
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
		_skip_level_ups()


## Level-ups (XP from the kills) would pause the game: this test is about the arena, so skip them.
func _skip_level_ups() -> void:
	if Upgrades.pending <= 0 and not Upgrades.choosing:
		return
	Upgrades.pending = 0
	for n in get_tree().root.find_children("*", "", true, false):
		if n.has_method("is_open") and n.has_method("pick") and n.is_open():
			n.close()
	Upgrades.choosing = false
	get_tree().paused = false


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		_skip_level_ups()
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
	arena = get_tree().current_scene as ScenicArena
	mech = get_tree().get_first_node_in_group("player") as Mech
	_check("scenic arena + mech loaded", arena != null and mech != null)
	mech._invuln = 1e9
	_check("painting shown", arena.get_node_or_null("MapArt") != null)
	_check("mech at spawn on open floor", arena.is_open(mech.global_position, 40.0))
	# Top-down maps have no tall scenery to fade (nothing hides the mech), so no occluders there.
	var top_down: bool = arena._layout.occluders.is_empty()
	if not top_down:
		_check("occluders built (%d)" % arena._occluders.size(), arena._occluders.size() >= 2)
	_check("enemy spawn points (%d)" % arena.zone.spawn_points.size(), arena.zone.spawn_points.size() > 60)
	var map: RID = get_viewport().world_2d.navigation_map
	var target := arena.map_to_world(arena._layout.boss_spawn)
	var path := NavigationServer2D.map_get_path(map, mech.global_position, target, true)
	_check("navmesh path spawn -> plaza (%d pts)" % path.size(), path.size() >= 2 and path[path.size() - 1].distance_to(target) < 150.0)

	# Edges: walking straight off the painted floor is blocked.
	var start := mech.global_position
	Controls.touch_move = Vector2(-1, 0.35).normalized()
	await _frames(180)
	Controls.touch_move = Vector2.ZERO
	_check("floor edge blocks the mech (still on floor)", Geometry2D.is_point_in_polygon(mech.global_position / arena._k, arena._layout.walkable))

	# Obstacle: can't walk through the first footprint; occluder fades when behind it.
	var obs: PackedVector2Array = arena._layout.obstacles[0]
	var c := Vector2.ZERO
	for p in obs:
		c += p
	c /= obs.size()
	var c_world := arena.map_to_world(c)
	mech.global_position = c_world + Vector2(0, 260)
	await _frames(3)
	Controls.touch_move = Vector2.UP
	await _frames(120)
	Controls.touch_move = Vector2.ZERO
	_check("obstacle footprint is solid", not Geometry2D.is_point_in_polygon(mech.global_position / arena._k, obs))
	mech.global_position = c_world + Vector2(0, -170)
	await _frames(60)
	if not top_down:
		_check("tall scenery fades when the Gundam is behind it (a=%.2f)" % arena._occluders[0].modulate.a, arena._occluders[0].modulate.a < 0.7)
	mech.global_position = start
	await _frames(60)
	if not top_down:
		_check("scenery opaque again when clear", arena._occluders[0].modulate.a > 0.9)

	# Hazard hurts.
	var hz: Node2D = _first("steam_vent.gd")
	if hz == null:
		hz = _first("electric_panel.gd")
	_check("hazards placed", hz != null)
	mech.global_position = hz.global_position
	mech._invuln = 0.0
	var hp1 := mech.hp
	await _wait_until(func() -> bool: return mech.hp < hp1, 7.0)
	_check("hazard damages the Gundam", mech.hp < hp1)
	mech._invuln = 1e9
	mech.hp = mech.max_hp
	mech.global_position = start
	await _frames(5)

	_check("barrels / crates / cover / repair placed", _count("explosive_barrel.gd") >= 2 and _count("crate.gd") >= 2
		and _count("cover_block.gd") >= 3 and _count("repair_station.gd") == 1)
	var barrel := _first("explosive_barrel.gd")
	var nb := _count("explosive_barrel.gd")
	barrel.take_hit(999.0, barrel.global_position)
	await _frames(30)
	_check("barrel explodes", _count("explosive_barrel.gd") < nb)

	# Waves.
	await _wait_until(func() -> bool: return arena.zone.is_running, 5.0)
	_check("fight starts after the intro", arena.zone.is_running)
	var moved_checked := false
	for w in arena.waves.size():
		await _wait_until(func() -> bool: return arena.zone.wave == w + 1 and arena.zone._pending == 0 and arena.zone.alive_count() > 0, 12.0)
		_check("wave %d spawned %d enemies" % [w + 1, arena.zone.alive_count()], arena.zone.wave == w + 1 and arena.zone.alive_count() > 0)
		var off: Array[String] = []
		var poly: PackedVector2Array = arena._layout.walkable
		for e in arena.zone._alive:
			if not is_instance_valid(e):
				continue
			var p: Vector2 = e.global_position / arena._k
			if not Geometry2D.is_point_in_polygon(p, poly):
				var d := INF
				for i in poly.size():
					d = minf(d, Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) * arena._k)
				off.append("%s %.0fpx out" % [e.name, d])
		_check("wave %d enemies spawned on the floor %s" % [w + 1, off if not off.is_empty() else ""], off.is_empty())
		if not moved_checked:
			moved_checked = true
			var starts := {}
			for e in arena.zone._alive:
				starts[e] = e.global_position
			await _frames(120)
			var moved := 0
			for e in starts:
				if is_instance_valid(e) and e.global_position.distance_to(starts[e]) > 30.0:
					moved += 1
			_check("enemies move (%d / %d)" % [moved, starts.size()], moved * 2 >= starts.size())
		for e in arena.zone._alive.duplicate():
			if is_instance_valid(e):
				e.die()
	await _wait_until(func() -> bool: return arena.zone.is_cleared, 5.0)
	_check("all 5 waves cleared", arena.zone.is_cleared)
	await _wait_until(func() -> bool: return arena.boss != null, 5.0)
	var boss = arena.boss
	_check("boss drops in after the waves", boss != null)
	await _frames(150)
	boss.take_damage(boss.max_hp * 0.36, boss.global_position, mech)
	_check("boss phase 2", boss.phase == 2)
	await _frames(90)
	boss.take_damage(boss.max_hp * 0.36, boss.global_position, mech)
	_check("boss phase 3", boss.phase == 3)
	await _frames(90)
	boss.take_damage(boss.max_hp, boss.global_position, mech)
	var hud := arena.get_node("HUD")
	await _wait_until(func() -> bool: return hud._win_panel.visible, 8.0)
	_check("victory screen", hud._win_panel.visible)
	_check("level marked cleared", Game.cleared.has(Game.arena_index))
	print("ARENA TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
