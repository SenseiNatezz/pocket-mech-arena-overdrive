extends Node
## Arena side of the GOLD SALVAGER + THREAT TIERS (see tools/goals_test.gd for the rest). Run:
##   godot --headless --path . -- --arena=1 --no-intro --temp-save --difficulty=3 --threat=5 --salvager=1 --goals-arena-test
## Checks that a Gold Salvager shows up during the waves (not part of the wave, HP from the pilot level and
## the threat), that a THREAT 5 boss lands with 3 elite guards, that the boss going down wipes the guards and
## makes a live Salvager warp out (no prize), and that the win pays the weapon's THREAT 5 bounty, opens
## THREAT 6 and says so on the results screen.
## Prints PASS/FAIL per check; exit code 0 = all passed.

var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.ignore_real_input = true
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_fails += 1


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return cond.call()


## Live elite robots (not bosses) near `at`.
func _guards(at: Vector2) -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and e.elite and not e.is_in_group("boss") and not e.dead \
				and (e as Node2D).global_position.distance_to(at) < 320.0:
			out.append(e)
	return out


func _run() -> void:
	var arena := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	mech._invuln = 1e9
	var hud := get_tree().root.find_children("*", "CanvasLayer", true, false).filter(
		func(n: Node) -> bool: return n.get("_contract_toast") != null)[0] as Node
	_check("THREAT 5 on Extreme is in effect (tier %d, escort %d)" % [Game.threat_level(), Game.threat_escort()],
		Game.threat_level() == 5 and Game.threat_escort() == 3)
	var salvagers := func() -> Array: return get_tree().get_nodes_in_group("salvagers")
	var came := await _wait_until(func() -> bool: return not salvagers.call().is_empty(), 9.0)
	_check("a Gold Salvager shows up once the waves are on", came and arena.zone.is_running)
	if came:
		var s: Enemy = salvagers.call()[0]
		var want := (150.0 + 30.0 * Upgrades.level) * sqrt(Game.diff("hp"))
		_check("...outside the wave (not tracked) with HP from the pilot level + threat (%.0f / %.0f)" % [s.max_hp, want],
			not arena.zone._alive.has(s) and is_equal_approx(s.max_hp, want))
		var d := s.global_position.distance_to(mech.global_position)
		_check("...near the pilot but not on top of it (%.0f px)" % d, d > 300.0 and d < 700.0)
	# Straight to the boss: it lands with its THREAT 5 escort.
	var caught: Array = []
	var on_caught := func(p: StringName, _a: float) -> void: caught.append(p)
	Game.salvager_caught.connect(on_caught)
	arena.debug_skip_to_boss()
	var boss_pos: Vector2 = arena.map_to_world(arena._layout.boss_spawn)
	var guards := func() -> Array: return _guards(boss_pos)
	var escorted := await _wait_until(func() -> bool: return guards.call().size() >= 3, 3.0)
	_check("a THREAT 5 boss lands with 3 elite guards (%d near it)" % guards.call().size(), escorted)
	var boss: Enemy = arena.boss
	_check("...and +25%% HP on top of Extreme (x%.2f: %.0f HP from %.0f)" % [Game.diff("boss_hp"), boss.max_hp, arena.boss_hp],
		is_equal_approx(Game.diff("boss_hp"), 2.25) and boss.max_hp >= arena.boss_hp * 2.25 - 1.0)
	# A live Salvager when the boss goes down warps out (no prize).
	var s2: Enemy = arena.spawn_salvager()
	await get_tree().physics_frame
	Game.bank_scrap()
	var unlocked0 := Game.threat_unlocked
	boss.take_damage(boss.hp + 1e7, boss.global_position, mech)
	var bounty := 0
	await _wait_until(func() -> bool: return int(Game.run_scrap_parts.get(&"bounty", 0.0)) > 0, 6.0)
	bounty = int(Game.run_scrap_parts.get(&"bounty", 0.0))
	await get_tree().physics_frame
	_check("the boss going down wipes its guards and the Salvager warps out unpaid (caught %s)" % str(caught),
		guards.call().is_empty() and (not is_instance_valid(s2) or s2.dead) and caught.is_empty())
	Game.salvager_caught.disconnect(on_caught)
	_check("the win pays the %s THREAT 5 bounty (+%s) and opens THREAT 6 (was %d)" % [Game.weapon, Game.fmt_int(bounty), unlocked0],
		bounty == Game.BOUNTY_SCRAP * 5 and Game.threat_unlocked == 6 and Game.bounty_claimed(Game.weapon, 5))
	var shown := await _wait_until(func() -> bool: return hud._win_panel.visible, 6.0)
	_check("the results say so (\"%s\")" % hud._win_stats.text.replace("\n", " | "),
		shown and hud._win_stats.text.contains("THREAT 5 WON") and hud._win_stats.text.contains("THREAT 6 UNLOCKED"))
	var parts := (hud._win_scrap.find_child("Parts", true, false) as Label).text
	_check("...with the bounty in the scrap breakdown (\"%s\")" % parts, parts.contains("Bounty 5,000"))
	get_tree().paused = false
	print("GOALS ARENA TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
