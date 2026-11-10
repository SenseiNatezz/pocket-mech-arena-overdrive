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
	Game.run_waves = 99  # past the WARM-UP: full multipliers (checked on their own in _warmup_checks)
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
		# (Extreme can roll an elite: x2 HP, x1.3 damage, x1.15 speed on top)
		var el := [2.0, 1.3, 1.15] if e.elite else [1.0, 1.0, 1.0]
		_check("%s: enemy HP x%.2f (%.0f)" % [info["name"], info["hp"], e.max_hp], is_equal_approx(e.max_hp, base_hp * info["hp"] * el[0]))
		_check("%s: enemy damage x%.2f" % [info["name"], info["damage"]], is_equal_approx(e.damage_mult, base_dmg * info["damage"] * el[1]))
		_check("%s: enemy speed x%.2f" % [info["name"], info["speed"]], is_equal_approx(e.move_speed, base_speed * info["speed"] * el[2]))
		_check("%s: artillery every %.1f s" % [info["name"], zone.bombard_interval / Game.diff("bombard")],
			is_equal_approx(zone.bombard_interval / Game.diff("bombard"), base_bombard / info["bombard"]))
		e.queue_free()
	_check("harder = more enemies (%s)" % str(sizes), sizes[0] < sizes[1] and sizes[1] < sizes[2] and sizes[2] < sizes[3])
	_warmup_checks(zone, base_hp, sample)
	await _extreme_extras(zone, mech)
	await _tank_checks(zone, mech)

	# Boss HP on Extreme.
	Game.difficulty = 3
	arena.debug_skip_to_boss()
	await _frames(5)
	var boss: Enemy = arena.boss
	_check("Extreme boss HP x%.2f (%.0f)" % [Game.diff("boss_hp"), boss.max_hp], is_equal_approx(boss.max_hp, arena.boss_hp * Game.diff("boss_hp") * (1.0 + arena.CAMPAIGN_BOSS_HP_PER_LEVEL * (Upgrades.level - 1))))
	print("DIFFICULTY TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


## Extreme only: elites spawn, XP gains shrink, campaign levels past 3 cost more, repairs are weaker.
func _extreme_extras(zone: EncounterZone, mech: Mech) -> void:
	Game.difficulty = 1
	_check("Normal: no elites", zone.elite_chance() == 0.0)
	var lv2_normal := Upgrades.xp_to_next(2)
	var lv4_normal := Upgrades.xp_to_next(4)
	mech.hp = 50.0
	mech.heal(20.0)
	var healed_normal := mech.hp - 50.0
	Game.difficulty = 3
	var elites := 0
	for i in 60:
		var e := _spawn_one(zone)
		if e.elite:
			elites += 1
			if i < 60 and elites == 1:
				_check("elites are worth more XP", Upgrades.xp_value(e) > roundi((e.max_hp / 2.0) / 45.0))
		e.queue_free()
	_check("Extreme: %d of 60 robots spawned as elites (%.0f%%)" % [elites, zone.elite_chance() * 100.0], elites > 0 and elites < 30)
	_check("Extreme: levels past 3 cost more (level 4: %.0f vs %.0f XP), early levels don't" % [Upgrades.xp_to_next(4), lv4_normal],
		Upgrades.xp_to_next(4) >= lv4_normal * 1.5 and is_equal_approx(Upgrades.xp_to_next(2), lv2_normal))
	var xp0 := Upgrades.xp
	var lv0 := Upgrades.level
	Upgrades.add_xp(1.0)
	_check("Extreme: XP gains x%.2f (%.2f)" % [Game.diff("xp"), Upgrades.xp - xp0], Upgrades.level == lv0 and is_equal_approx(Upgrades.xp - xp0, Game.diff("xp")))
	Upgrades.xp = xp0
	mech.hp = 50.0
	mech.heal(20.0)
	_check("Extreme: repairs x%.1f (%.0f vs %.0f HP)" % [Game.diff("heal"), mech.hp - 50.0, healed_normal],
		is_equal_approx(mech.hp - 50.0, healed_normal * Game.diff("heal")))
	mech.hp = mech.max_hp
	Game.difficulty = 1
	await _frames(2)


## Heavy Tank: thin armor on early waves, full later; the rear vent takes 2.5x damage.
func _tank_checks(zone: EncounterZone, mech: Mech) -> void:
	Game.difficulty = 1
	var w := zone.wave
	zone.wave = 1
	var thin := zone.armor_fraction()
	zone.wave = 9
	var full := zone.armor_fraction()
	zone.wave = w
	_check("tank armor: %.0f%% of HP on wave 1, %.0f%% by wave 9" % [thin * 100.0, full * 100.0], thin < 0.5 and full > 0.95)
	var tank: HeavyTank = zone.ENEMIES["tank"].instantiate()
	tank.position = mech.global_position + Vector2(0, -2000)
	tank.armor_fraction = 1.0
	tank.armor_tier = 2
	(zone.enemy_parent if zone.enemy_parent else zone.get_parent()).add_child(tank)
	await _frames(2)
	tank.facing = Vector2.UP
	var eff := func() -> float: return tank.hp + tank.armor * tank.armor_tier
	var before: float = eff.call()
	tank.take_damage(20.0, tank.global_position + Vector2(0, -150))  # front
	var front: float = before - eff.call()
	before = eff.call()
	tank.take_damage(20.0, tank.global_position + Vector2(0, 150))  # rear vent
	var rear: float = before - eff.call()
	_check("tank rear vent takes %.1fx damage (front %.0f, rear %.0f)" % [rear / maxf(front, 0.01), front, rear],
		is_equal_approx(rear, front * HeavyTank.REAR_MULT))
	tank.queue_free()


## WARM-UP: a run's 1st / 2nd wave on Extreme get Game.WARMUP of the step above Normal; Easy / Normal never change.
func _warmup_checks(zone: EncounterZone, base_hp: float, sample: Array[String]) -> void:
	Game.difficulty = 3
	var full_n := zone._scale_for_difficulty(sample).size()
	for i in Game.WARMUP.size():
		Game.run_waves = i + 1
		var w: float = Game.WARMUP[i]
		var want_hp := 1.0 + (float(Game.DIFFICULTIES[3]["hp"]) - 1.0) * w
		_check("Extreme wave %d warm-up: robot HP x%.2f" % [i + 1, Game.diff("hp")], is_equal_approx(Game.diff("hp"), want_hp))
		_check("Extreme wave %d warm-up: elites %.0f%%" % [i + 1, Game.diff("elite") * 100.0],
			is_equal_approx(Game.diff("elite"), float(Game.DIFFICULTIES[3]["elite"]) * w))
		_check("Extreme wave %d: boss HP not eased" % (i + 1), is_equal_approx(Game.diff("boss_hp"), Game.DIFFICULTIES[3]["boss_hp"]))
		var n := zone._scale_for_difficulty(sample).size()
		_check("Extreme wave %d warm-up: %d of %d robots" % [i + 1, n, full_n], n < full_n)
	Game.run_waves = 1
	Game.difficulty = 0
	_check("Easy is never eased (HP x%.2f)" % Game.diff("hp"), is_equal_approx(Game.diff("hp"), Game.DIFFICULTIES[0]["hp"]))
	Game.difficulty = 1
	_check("Normal is never eased", is_equal_approx(Game.diff("damage"), 1.0))
	Game.run_waves = 3
	Game.difficulty = 3
	_check("Extreme wave 3: full strength", is_equal_approx(Game.diff("hp"), Game.DIFFICULTIES[3]["hp"]))
	Game.run_waves = 99
