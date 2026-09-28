extends Node
## Difficulty test:  godot --path . -- --arena=1 --difficulty-test --temp-save --no-intro
## For Easy / Normal / Hard / Extreme: wave sizes scale by "count", spawned enemies' HP / damage / speed
## by "hp" / "damage" / "speed" (compared with Normal), and the boss's HP by "boss_hp".

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


func _spawn_one(zone: EncounterZone) -> Enemy:
	zone._pending += 1
	zone._spawn("chaser", Vector2(-99999, -99999))
	var e: Enemy = zone._alive[-1]
	zone._alive.erase(e)
	return e


func _run() -> void:
	await _frames(5)
	var arena := get_tree().current_scene
	var zone: EncounterZone = arena.zone
	var mech := get_tree().get_first_node_in_group("player") as Mech
	mech._invuln = 1e9
	var sample: Array[String] = []
	for i in 10:
		sample.append("chaser")
	Game.difficulty = 1
	var normal := _spawn_one(zone)
	var base_hp := normal.max_hp
	var base_dmg := normal.damage_mult
	var base_speed := normal.move_speed
	var base_bombard := zone.bombard_interval / Game.diff("bombard")
	normal.queue_free()
	var sizes: Array[int] = []
	for d in Game.DIFFICULTIES.size():
		Game.difficulty = d
		var info: Dictionary = Game.DIFFICULTIES[d]
		var n := zone._scale_for_difficulty(sample).size()
		sizes.append(n)
		_check("%s: a 10-enemy wave has %d enemies" % [info["name"], n], n == roundi(10 * info["count"]))
		var e := _spawn_one(zone)
		_check("%s: enemy HP x%.2f (%.0f)" % [info["name"], info["hp"], e.max_hp], is_equal_approx(e.max_hp, base_hp * info["hp"]))
		_check("%s: enemy damage x%.2f" % [info["name"], info["damage"]], is_equal_approx(e.damage_mult, base_dmg * info["damage"]))
		_check("%s: enemy speed x%.2f" % [info["name"], info["speed"]], is_equal_approx(e.move_speed, base_speed * info["speed"]))
		_check("%s: artillery every %.1f s" % [info["name"], zone.bombard_interval / Game.diff("bombard")],
			is_equal_approx(zone.bombard_interval / Game.diff("bombard"), base_bombard / info["bombard"]))
		e.queue_free()
	_check("harder = more enemies (%s)" % str(sizes), sizes[0] < sizes[1] and sizes[1] < sizes[2] and sizes[2] < sizes[3])

	# Boss HP on Extreme.
	Game.difficulty = 3
	arena.debug_skip_to_boss()
	await _frames(5)
	var boss: Enemy = arena.boss
	_check("Extreme boss HP x%.2f (%.0f)" % [Game.diff("boss_hp"), boss.max_hp], is_equal_approx(boss.max_hp, arena.boss_hp * Game.diff("boss_hp")))
	print("DIFFICULTY TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
