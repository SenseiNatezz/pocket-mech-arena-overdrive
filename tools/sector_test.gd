extends Node
## CAMPAIGN SECTORS + SWARMS test (Game.start_arena / next_sector, ScenicArena sector waves, enemies/scrap_mite.gd):
##   godot --headless --path . -- --arena=1 --sector=1 --no-intro --temp-save --attach=res://tools/sector_test.gd
## A Campaign level runs over three maps: two random lead-in maps, then its own map with the boss. Each
## sector has 8 waves from the level's own table with Scrap Mite packs; clearing a lead-in sector moves on
## with the level, upgrades, HP (+repair) and repair kits; the boss only comes on the last map.
## -> "SECTOR TEST OK (0 failed)"

static var _running := false
var _fails := 0


func _ready() -> void:
	if _running:
		queue_free()
		return
	_running = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _seconds(s: float) -> void:
	await _frames(int(s * Engine.physics_ticks_per_second))


func _arena() -> ScenicArena:
	return get_tree().get_first_node_in_group("arena") as ScenicArena


func _mech() -> Mech:
	return get_tree().get_first_node_in_group("player") as Mech


func _run() -> void:
	reparent(get_tree().root)
	Controls.ignore_real_input = true
	await _seconds(1.0)
	var home: String = Game.ARENAS[0]["scene"]
	_check("three sector maps, the level's own map last, no repeats (%s)" % ", ".join(Game.sector_scenes.map(
		func(s: String) -> String: return s.get_file())),
		Game.sector_scenes.size() == 3 and Game.sector_scenes[2] == home and not Game.sector_scenes.slice(0, 2).has(home)
		and Game.sector_scenes[0] != Game.sector_scenes[1])
	var a := _arena()
	_check("sector 1 is a lead-in map", a != null and a.scene_file_path == Game.sector_scenes[0] and a._lead_in
		and Game.campaign_sector == 1)
	if a == null:
		_finish()
		return
	_check("sector 1 has %d waves from the level's table, each with Scrap Mites" % ScenicArena.SECTOR_WAVES,
		a.zone.waves.size() == ScenicArena.SECTOR_WAVES and Array(a.zone.waves).all(func(w: String) -> bool: return "mite:" in w))
	var lvl1: PackedStringArray = load(home).get_state().get_node_property_value(0, _prop(load(home), &"waves"))
	_check("...built from Frozen Outpost's own robots (first wave starts from its wave 1)",
		a.zone.waves[0].begins_with(lvl1[0].split(",")[0].split(":")[0]))
	_check("intro says which sector it is (%s)" % a.intro_subtitle, a.intro_subtitle.begins_with("Sector 1 / 3"))

	# A swarm wave really sends packs of mites.
	await _seconds(4.5)
	var mites := 0
	for t in 40:
		await _seconds(0.25)
		mites = a.zone.mites_out()
		if mites >= 5:
			break
	_check("Scrap Mites warp in as a pack (%d out)" % mites, mites >= 5)

	# Level, upgrades, HP and kits carry into sector 2.
	Upgrades.level = 6
	Upgrades.stacks[&"rapid"] = 2
	var m := _mech()
	m.hp = m.max_hp * 0.3
	m.repair_charges = 1
	m._invuln = 1e9  # (map hazards can still nick it before the doors open)
	a.debug_skip_to_boss.call()  # (on a lead-in map this clears the sector instead - see below)
	# ROUTE CHOICE: two doors (different maps, twists and deals); the automated run takes door A.
	var choice: RouteChoice = null
	for t in 30:
		await _seconds(0.25)
		for c in a.get_children():
			if c is RouteChoice:
				choice = c
		if choice and choice.visible:
			break
	var routes: Array[Dictionary] = choice._routes if choice else []
	_check("sector clear opens the route doors (%s)" % ", ".join(routes.map(func(r: Dictionary) -> String:
		return "%s / %s / %s" % [r["name"], r["twist"], r["deal"]])),
		choice != null and choice.visible and get_tree().paused and routes.size() == 2)
	_check("...two different maps, neither used yet nor the level's own", routes.size() == 2
		and routes[0]["scene"] != routes[1]["scene"] and not [home, Game.sector_scenes[0]].has(routes[0]["scene"])
		and not [home, Game.sector_scenes[0]].has(routes[1]["scene"]))
	_check("...with different twists and deals", routes.size() == 2 and routes[0]["twist"] != routes[1]["twist"]
		and routes[0]["deal"] != routes[1]["deal"] and Game.TWISTS.has(routes[0]["twist"])
		and Game.SECTOR_DEALS.has(routes[0]["deal"]))
	for t in 40:
		await _seconds(0.25)
		if Game.campaign_sector == 2 and _arena() and _arena() != a and _arena().zone:
			break
	a = _arena()
	m = _mech()
	var took: Dictionary = routes[0] if not routes.is_empty() else {}
	_check("door A's map is sector 2", a != null and Game.campaign_sector == 2 and a.scene_file_path == Game.sector_scenes[1]
		and a.scene_file_path == took.get("scene", ""))
	_check("...under its twist and deal (%s, %s)" % [Game.active_twist(), Game.active_deal()],
		Game.active_twist() == took.get("twist") and Game.active_deal() == took.get("deal"))
	_check("level + upgrades carried (LV %d, rapid %d)" % [Upgrades.level, int(Upgrades.stacks.get(&"rapid", 0))],
		Upgrades.level == 6 and int(Upgrades.stacks.get(&"rapid", 0)) >= 2)
	# (a SUPPLY CACHE's free card may have been ARMOR, which heals - so then only "at least")
	var frac := m.hp / m.max_hp if m else 0.0
	_check("HP carried + patched up (%.0f%%)" % (100.0 * frac), m and (absf(frac - 0.7) < 0.03
		or (Game.active_deal() == &"supply" and frac >= 0.68)))
	if Game.active_deal() == &"supply":
		_check("SUPPLY CACHE deals a free card on arrival", Upgrades.level == 6 and Upgrades.bonus_title == "SUPPLY CACHE")
	_check("repair kits carried (%d)" % m.repair_charges, m and m.repair_charges == 1)
	_check("no boss on a lead-in map", get_tree().get_nodes_in_group("boss").is_empty())

	a.debug_skip_to_boss.call()
	for t in 60:
		await _seconds(0.25)
		if Game.campaign_sector == 3 and _arena() and _arena() != a and _arena().zone:
			break
	await _seconds(1.0)
	a = _arena()
	_check("then sector 3 = the level's own map (both doors lead there)", a != null and Game.campaign_sector == 3
		and a.scene_file_path == home and not a._lead_in)

	# Twists and deals in numbers (twist_value multiplies a twist and a deal together).
	var keep_t := Game.sector_twists.duplicate()
	var keep_d := Game.sector_deals.duplicate()
	Game.sector_twists[2] = &"gold"
	Game.sector_deals[2] = &""
	_check("GOLD RUSH twist: double scrap (%.1f)" % Game.twist_value("scrap"), is_equal_approx(Game.twist_value("scrap"), 2.0))
	Game.sector_twists[2] = &"swarm"
	Game.sector_deals[2] = &"haul"
	_check("SWARM + SCRAP HAUL: robots x%.2f HP (0.55 x 1.2)" % Game.twist_value("enemy_hp"),
		is_equal_approx(Game.twist_value("enemy_hp"), 0.55 * 1.2))
	Game.sector_twists[2] = &"elite"
	Game.sector_deals[2] = &"bounty"
	_check("ELITE SURGE + BOUNTY HUNT add up (+%.2f elite chance)" % Game.twist_value("elite_add", 0.0),
		is_equal_approx(Game.twist_value("elite_add", 0.0), 0.45))
	Game.sector_deals[2] = &"safe"
	_check("SAFE PASSAGE: robots hit softer (x%.2f)" % a.zone.wave_damage_mult(),
		is_equal_approx(Game.twist_value("enemy_damage"), 0.8))
	# OVERHEAT: a destroyed robot blows up and the blast reaches the pilot.
	Game.sector_twists[2] = &"overheat"
	Game.sector_deals[2] = &""
	m = _mech()
	m.hp = m.max_hp
	m._invuln = 0.0
	m.shield_charges = 0  # (an Energy Shield card from a free pick would eat the blast)
	var hound: Enemy = EncounterZone.ENEMIES["chaser"].instantiate()
	hound.position = m.global_position + Vector2(50, 0)
	a.world.add_child(hound)
	await _frames(3)
	var hp0 := m.hp
	hound.die()
	await _seconds(0.8)
	_check("OVERHEAT: a destroyed robot blows up and hurts the pilot (%.0f -> %.0f HP)" % [hp0, m.hp], m.hp < hp0)
	Game.sector_twists.assign(keep_t)
	Game.sector_deals.assign(keep_d)
	a.debug_skip_to_boss.call()
	await _seconds(2.0)
	_check("the boss comes on the last map", not get_tree().get_nodes_in_group("boss").is_empty())

	# The wave builder: sector 1 eases in, the boss sector ends on the level's hardest wave.
	var w1 := ScenicArena.sector_waves(lvl1, 1)
	var w3 := ScenicArena.sector_waves(lvl1, 3)
	_check("the boss sector ends on the level's last wave", w3[-1].begins_with(ScenicArena._thin_wave(lvl1[-1], ScenicArena.SECTOR_FULL[2])))
	_check("swarm waves (every other one) bring the big packs", int(w1[1].split("mite:")[1]) > int(w1[0].split("mite:")[1]))
	_finish()


## Index of property `name` on a packed scene's root node.
func _prop(ps: PackedScene, name: StringName) -> int:
	var st := ps.get_state()
	for i in st.get_node_property_count(0):
		if st.get_node_property_name(0, i) == name:
			return i
	return -1


func _finish() -> void:
	print("SECTOR TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1
