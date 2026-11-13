extends Node
## RIVAL PILOTS test (enemies/rival_mech.gd, Game.rival_beaten / chassis_cost, ScenicArena._maybe_rival) plus
## the arena's own music (autoload/music.gd ARENA_MUSIC):
##   godot --headless --path . -- --arena=4 --no-intro --temp-save --attach=res://tools/rival_test.gd
## Every Hangar mech's rival is built from its own art, moves, shoots and uses its signature move; shooting it
## down pays a bounty (more the first time) and makes that chassis 25% cheaper; a scripted wipe pays
## nothing; the Campaign's middle wave really sends this arena's rival. -> "RIVAL TEST OK (0 failed)"

static var _running := false
var _fails := 0
var _mech: Mech


func _ready() -> void:
	if _running:
		queue_free()
		return
	_running = true
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	# The pilot can't die during the test (the rivals do hit it).
	if is_instance_valid(_mech):
		_mech.hp = _mech.max_hp


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * Engine.physics_ticks_per_second))


func _run() -> void:
	reparent(get_tree().root)
	Controls.ignore_real_input = true
	await _seconds(1.0)
	var arena := get_tree().get_first_node_in_group("arena")
	_mech = get_tree().get_first_node_in_group("player") as Mech
	_check("in a scenic arena with the pilot", arena is ScenicArena and _mech != null)
	if not (arena is ScenicArena) or _mech == null:
		_finish()
		return
	var world: Node2D = arena.world

	# The arena's own battle track.
	_check("Skyway Junction plays its own track (%s)" % Music._arena_track,
		Music._arena_track == &"arena_skyway" and Music._streams.has(&"arena_skyway"))

	for c in Game.CHASSIS:
		var id: StringName = c["id"]
		var r := RivalMech.new()
		r.chassis_id = id
		r.position = _mech.global_position + Vector2(320, 0)
		world.add_child(r)
		await _frames(2)
		r._special_cd = 0.8
		var start := r.global_position
		var moved := false
		var fired := false
		var special := false
		for i in int(5.0 * Engine.physics_ticks_per_second):
			await get_tree().physics_frame
			if not is_instance_valid(r) or r.dead:
				break
			moved = moved or r.global_position.distance_to(start) > 25.0
			fired = fired or r._shot_t > 0.0
			special = special or r._special_cd > 2.0
		var name := String(c["name"])
		_check("%s rival: own art (legs + upper body)" % name, r._torso != null and r._torso.sprite_frames != null
			and r._legs != null)
		_check("%s rival: moves, fires and uses its signature move" % name, moved and fired and special)
		var before := Game.run_scrap
		var cost0 := int(c["cost"])
		r._state = &"fight"  # (not mid-shield: SUN BARRIER / SIEGE soak most of a hit)
		r.take_damage(r.hp + 1.0, r.global_position, _mech)
		await _frames(2)
		_check("%s rival: shot down pays a bounty (+%.0f)" % [name, Game.run_scrap - before],
			not is_instance_valid(r) or r.dead)
		_check("%s rival: remembered as beaten, first win pays the bonus" % name,
			Game.rivals_beaten.has(id) and Game.run_scrap - before >= (Game.RIVAL_BOUNTY + Game.RIVAL_FIRST_BONUS) * 0.5)
		if cost0 > 0:
			_check("%s: now %d scrap in the Hangar (was %d)" % [name, Game.chassis_cost(id), cost0],
				Game.chassis_cost(id) == roundi(cost0 * 0.75 / 10.0) * 10)
	var again := Game.rival_beaten(&"striker")
	_check("a rival beaten again pays only the bounty (%.0f)" % again, again > 0.0 and again < Game.RIVAL_FIRST_BONUS)

	# A scripted wipe (boss down) pays nothing.
	var w := RivalMech.new()
	w.chassis_id = &"bulwark"
	w.position = _mech.global_position + Vector2(-300, 0)
	world.add_child(w)
	await _frames(5)
	var before_wipe := Game.run_scrap
	w.die()
	await _frames(2)
	_check("a wiped rival pays no bounty (only the usual kill scrap: +%.0f)" % (Game.run_scrap - before_wipe),
		Game.run_scrap - before_wipe < Game.RIVAL_BOUNTY * 0.5)

	# The Campaign's middle wave sends this arena's rival (GRIFFIN on Skyway Junction), and the wave waits for it.
	for e in get_tree().get_nodes_in_group("rivals"):
		e.queue_free()
	await _frames(2)
	arena._maybe_rival(3, 5)
	await _seconds(ScenicArena.RIVAL_DELAY + 1.4)
	var sent: Array = get_tree().get_nodes_in_group("rivals")
	var want: StringName = Game.ARENA_RIVALS[Game.arena_index]
	_check("wave 3 of 5 sends this arena's rival (%s)" % want, sent.size() == 1 and sent[0].chassis_id == want)
	_check("the wave waits for it", sent.size() == 1 and arena.zone._alive.has(sent[0]))
	arena._maybe_rival(2, 5)
	await _seconds(ScenicArena.RIVAL_DELAY + 1.4)
	_check("other waves send none", get_tree().get_nodes_in_group("rivals").size() == 1)
	_finish()


func _finish() -> void:
	print("RIVAL TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1
