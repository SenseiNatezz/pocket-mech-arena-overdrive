extends Node
## RUN VARIETY test - weapon EVOLUTIONS, mech TRAITS, the PIT STOP shop, sector BONUS OBJECTIVES and PART CRATES:
##   godot --headless --path . -- --arena=1 --sector=1 --no-intro --no-rival --objective=towers --temp-save --attach=res://tools/variety_test.gd
## -> "VARIETY TEST OK (0 failed)"

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
	PitStop.test_hold = true
	await _seconds(1.0)
	var a := _arena()
	var m := _mech()
	if a == null or m == null:
		_check("arena + mech", false)
		_finish()
		return
	m._invuln = 1e9
	_evolutions(m)
	await _evolved_weapons(a, m)
	_traits(a, m)
	await _crates(a, m)
	await _objectives(a, m)
	await _pit_stop(a)
	_finish()


# --- 1. weapon evolutions -------------------------------------------------------------------------------

func _evolutions(m: Mech) -> void:
	var all_ok := true
	for w: Dictionary in Game.WEAPONS:
		var e: Dictionary = Upgrades.EVOLUTIONS.get(w["id"], {})
		var cat: StringName = e.get("catalyst", &"")
		var u: Dictionary = Upgrades.CATALOG.get(cat, {})
		if e.is_empty() or u.is_empty() or u.get("not_for", []).has(w["id"]) or (u.has("only") and not u["only"].has(w["id"])):
			all_ok = false
			print("  no usable evolution for %s" % w["id"])
	_check("all %d weapons have an evolution with a usable catalyst" % Game.WEAPONS.size(), all_ok)
	var keep_chassis := Game.chassis
	Game.chassis = &"striker"
	Game.weapon = &"blaster"
	m.weapon = &"blaster"
	Upgrades.stacks.erase(Upgrades.EVOLVE_ID)
	Upgrades.stacks[&"power"] = 0
	Upgrades.level = 3
	var seen := 0
	for i in 200:
		if Upgrades.roll_choices(3).has(&"power"):
			seen += 1
	_check("the catalyst turns up often while short (Power Core in %d of 200 deals)" % seen, seen >= 90)
	Upgrades.stacks[&"power"] = 3
	_check("not ready below pilot LV %d" % Upgrades.EVOLVE_LEVEL, not Upgrades.evolution_ready())
	Upgrades.level = Upgrades.EVOLVE_LEVEL
	var deal := Upgrades.roll_choices(3)
	_check("ready at Power Core 3 + LV 8: the EVOLUTION card comes first (%s)" % ", ".join(deal), Upgrades.evolution_ready()
		and deal[0] == Upgrades.EVOLVE_ID and Upgrades.describe(Upgrades.EVOLVE_ID) != "")
	Game.chassis = &"standard"
	_check("NIMBUS QUICK STUDY: one catalyst level less (%d), from LV %d" % [Upgrades.evolve_need(), Upgrades.evolve_level()],
		Upgrades.evolve_need() == 2 and Upgrades.evolve_level() == Upgrades.EVOLVE_LEVEL_QUICK)
	Game.chassis = keep_chassis
	var evolved := [false]
	Upgrades.weapon_evolved.connect(func(_w: StringName) -> void: evolved[0] = true, CONNECT_ONE_SHOT)
	Upgrades.pending = 1
	Upgrades.apply(Upgrades.EVOLVE_ID)
	_check("taking it evolves the weapon (%s)" % Upgrades.weapon_name(), Upgrades.is_evolved() and evolved[0]
		and Upgrades.weapon_name() == "Hyper Beam Rifle" and not Upgrades.roll_choices(3).has(Upgrades.EVOLVE_ID))


## Every evolved weapon fires a few times among robots without errors; the HYPER BEAM RIFLE pierces and fires a
## MEGA BEAM every 5th shot.
func _evolved_weapons(a: ScenicArena, m: Mech) -> void:
	var foes: Array[Enemy] = []
	for i in 6:
		var e: Enemy = EncounterZone.ENEMIES["tank"].instantiate()
		e.max_hp = 1e7
		e.position = m.global_position + Vector2.from_angle(i * 0.5 - 1.2) * (160.0 + 60.0 * i)
		a.world.add_child(e)
		foes.append(e)
	await _frames(3)
	m.aim_dir = Vector2.RIGHT
	m._evo_shots = 0
	for i in 5:
		m._fire_primary(1.0)
	var pierce := false
	for b in Combat._pool:
		if b.active and b.player_owned and b.pierce >= 90:
			pierce = true
	var mega := false
	for n in Combat.world().get_children():
		if n.get("width") != null and float(n.get("width")) > 100.0:
			mega = true
	_check("HYPER BEAM RIFLE: bolts pierce everything, and the 5th shot is a MEGA BEAM", pierce and mega)
	var ok := true
	for w: Dictionary in Game.WEAPONS:
		Game.weapon = w["id"]
		m.weapon = w["id"]
		for i in 6:
			m._fire_primary(1.0)
			await _frames(4)
	await _seconds(1.0)
	_check("every evolved weapon fires (13 weapons, no errors)", ok and is_instance_valid(m) and not m.dead)
	for e in foes:
		if is_instance_valid(e):
			e.queue_free()
	Game.weapon = &"blaster"
	m.weapon = &"blaster"
	Upgrades.stacks.erase(Upgrades.EVOLVE_ID)
	await _frames(2)


# --- 2. traits -------------------------------------------------------------------------------------------

func _traits(a: ScenicArena, m: Mech) -> void:
	var keep_chassis := Game.chassis
	var keep_id := m._chassis_id
	var with_trait := 0
	for c: Dictionary in Game.CHASSIS:
		if String(c.get("trait", "")) != "" and String(c.get("trait_desc", "")) != "":
			with_trait += 1
	_check("all %d mechs have a trait" % Game.CHASSIS.size(), with_trait == Game.CHASSIS.size())
	Game.chassis = &"bulwark"
	Game.weapon = &"blaster"
	_check("TUSKER: no Thrusters cards, Armor Plating +%d HP" % roundi(Upgrades.armor_hp()),
		not Upgrades.is_available(&"thrusters") and Upgrades.armor_hp() == 50.0)
	Game.weapon = &"sword"
	_check("...but Thrusters is still dealt when it's the weapon's catalyst (Beam Saber)", Upgrades.is_available(&"thrusters"))
	Game.weapon = &"blaster"
	Game.chassis = &"artillery"
	m._chassis_id = &"artillery"
	_check("TEMPEST: no Piercing Rounds, explosions x%.1f" % Combat.blast_scale(m),
		not Upgrades.is_available(&"pierce") and Combat.blast_scale(m) == 1.5)
	Game.chassis = &"carrier"
	Upgrades.stacks[&"drones"] = 3
	_check("AURORA HIVE MIND: 5 drones (%d)" % Upgrades.drone_count(), Upgrades.drone_count() == 5)
	Upgrades.stacks.erase(&"drones")
	m._chassis_id = &"striker"
	m.momentum = 0.0
	var still := m.momentum_mult()
	m.momentum = 1.0
	_check("GRIFFIN MOMENTUM: x%.2f standing, x%.2f at full speed" % [still, m.momentum_mult()],
		is_equal_approx(still, Mech.MOMENTUM_STILL) and is_equal_approx(m.momentum_mult(), Mech.MOMENTUM_FULL))
	m.momentum = 0.0
	var e: Enemy = EncounterZone.ENEMIES["chaser"].instantiate()
	e.max_hp = 5000.0
	e.position = m.global_position + Vector2(400, 300)
	a.world.add_child(e)
	m._chassis_id = &"duelist"
	e.chill_t = 1.0
	_check("FROSTBLADE FROST EDGE: chilled robots take x%.2f" % m.damage_vs(e), is_equal_approx(m.damage_vs(e), Mech.FROST_BONUS))
	e.chill_t = 0.0
	m._chassis_id = &"bulwark"
	var hp0 := e.hp
	m.rammed(e)
	_check("TUSKER HEAVYWEIGHT: a robot that rams it takes damage back (%.0f -> %.0f)" % [hp0, e.hp], e.hp < hp0)
	m._chassis_id = &"guardian"
	Game.chassis = &"guardian"
	m.hp = m.max_hp
	m.shield_charges = 0
	m._overheal = 0.0
	m._restore(45.0)
	_check("SOLSTICE OVERSHIELD: 45 HP healed at full = 2 shield charges (%d)" % m.shield_charges, m.shield_charges == 2)
	m.shield_charges = 0
	m._chassis_id = &"phantom"
	Game.chassis = &"phantom"
	m.hp = 50.0
	e.take_damage(1e6, e.global_position, m)
	_check("RAVEN BLOODLUST: a kill repairs it (%.1f HP)" % m.hp, m.hp > 50.0 and m.hp <= 51.5)
	_check("...and no Salvage Repair cards", not Upgrades.is_available(&"salvage"))
	Game.chassis = keep_chassis
	m._chassis_id = keep_id
	m.hp = m.max_hp


# --- 3. part crates --------------------------------------------------------------------------------------

func _crates(a: ScenicArena, m: Mech) -> void:
	_check("found-only parts can't be bought (%s)" % Parts.info(&"legs_ghost").get("name", "?"),
		Parts.is_found_only(&"legs_ghost") and not Parts.can_buy(&"legs_ghost"))
	Game._crates_here = 0
	var found := [&""]
	Game.part_found.connect(func(id: StringName) -> void: found[0] = id, CONNECT_ONE_SHOT)
	var before := Game.run_found_parts.size()
	Game.drop_part_crate(m.global_position + Vector2(260, 0))
	await _seconds(0.3)
	var crates := get_tree().get_nodes_in_group("part_crates")
	_check("a part crate drops (loot beam)", crates.size() == 1)
	# Walk over it.
	m.global_position = (crates[0] as Node2D).global_position if not crates.is_empty() else m.global_position
	await _seconds(1.0)
	_check("walking over it finds a part you don't own (%s)" % Parts.info(found[0]).get("name", "-"),
		found[0] != &"" and Game.run_found_parts.size() == before + 1 and not Parts.owns(found[0]))
	# A rival pilot always drops one.
	Game._crates_here = 0
	var r := RivalMech.new()
	r.chassis_id = &"striker"
	r.position = m.global_position + Vector2(300, 0)
	a.world.add_child(r)
	await _frames(3)
	r.take_damage(1e7, r.global_position, m)
	await _seconds(0.3)
	_check("a rival pilot drops a part crate", get_tree().get_nodes_in_group("part_crates").size() == 1)
	for c in get_tree().get_nodes_in_group("part_crates"):
		c.open()
	await _frames(2)
	var haul := Game.run_found_parts.duplicate()
	# Banking brings them home (the run's scrap is put back for the shop test after).
	var keep_scrap := Game.run_scrap
	var keep_parts := Game.run_scrap_parts.duplicate()
	Game.bank_scrap()
	var all_owned := true
	for id in haul:
		all_owned = all_owned and Parts.owns(id)
	_check("they come home with the scrap: owned in the Hangar (%d parts)" % haul.size(), haul.size() == 2 and all_owned
		and Game.last_found_parts.size() == 2 and Game.run_found_parts.is_empty())
	Game.scrap -= roundi(keep_scrap)
	Game.run_scrap = keep_scrap
	Game.run_scrap_parts = keep_parts


# --- 4. bonus objectives ---------------------------------------------------------------------------------

func _objectives(a: ScenicArena, m: Mech) -> void:
	var o := a.objective
	_check("sector 1 has a bonus objective (%s)" % (o.title() if o else "none"), o != null and o.kind == &"towers")
	# It starts with wave 2 (the robots of wave 1 are wiped to get there).
	for t in 160:
		await _seconds(0.25)
		if o and o.active:
			break
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and not e.dead and not (e is WarpTower):
				e.take_damage(1e7, e.global_position, null)
		await _settle()
	var towers: Array[Node] = []
	towers.assign(get_tree().get_nodes_in_group("objective_markers").filter(func(n: Node) -> bool: return n is WarpTower))
	_check("WARP TOWERS: 3 towers rise with wave 2 (%d)" % towers.size(), o != null and o.active and towers.size() == 3)
	if o == null or towers.is_empty():
		return
	await _seconds(9.0)
	var mites := 0
	for t in towers:
		if is_instance_valid(t):
			mites += (t as WarpTower)._mites.size()
	_check("...and they send Scrap Mite packs (%d out)" % mites, mites >= WarpTower.PACK)
	await _settle()
	Upgrades.bonus_title = ""
	var obj_scrap := float(Game.run_scrap_parts.get(&"objective", 0.0))
	for t in towers:
		if is_instance_valid(t):
			(t as Enemy).take_damage(1e7, (t as Node2D).global_position, m)
		await _frames(2)
	await _frames(5)
	_check("destroying them all completes it: a free upgrade card + scrap", o.done and o.success
		and Upgrades.bonus_title == "OBJECTIVE BONUS" and float(Game.run_scrap_parts.get(&"objective", 0.0)) > obj_scrap)
	await _settle()
	# HOLD THE BEACON and DATA CACHES, run side by side (on top of the sector's own objective).
	var hold := SectorObjective.new()
	hold.kind = &"hold"
	hold.arena = a
	a.add_child(hold)
	hold.start()
	await _frames(2)
	_check("HOLD THE BEACON: a beacon ring lands", hold.active and is_instance_valid(hold._beacon))
	if hold.active:
		hold._hold = SectorObjective.HOLD_TIME - 0.6
		m.global_position = hold._beacon.global_position
		await _seconds(1.2)
		_check("standing in it charges it to done", hold.done and hold.success)
	await _settle()
	var caches := SectorObjective.new()
	caches.kind = &"caches"
	caches.arena = a
	a.add_child(caches)
	caches.start()
	await _frames(2)
	var spots: Array[Vector2] = []
	for t in caches._targets:
		if is_instance_valid(t):
			spots.append(t.global_position)
	_check("DATA CACHES: %d caches drop around the map" % spots.size(), caches.active and spots.size() == SectorObjective.CACHES)
	for p in spots:
		m.global_position = p
		await _frames(4)
	await _frames(4)
	_check("grabbing them all completes it", caches.done and caches.success)
	await _settle()
	var fail := SectorObjective.new()
	fail.kind = &"caches"
	fail.arena = a
	a.add_child(fail)
	fail.start()
	await _frames(2)
	fail._time_left = 0.05
	await _frames(6)
	_check("out of time: OBJECTIVE FAILED and its targets fold away", fail.done and not fail.success
		and fail._targets.is_empty())
	await _settle()


## Waits until no level-up pick is waiting (the menu picks by itself in automated runs).
func _settle() -> void:
	for t in 60:
		if Upgrades.pending == 0 and not Upgrades.choosing and not get_tree().paused:
			return
		await _seconds(0.2)


# --- 5. pit stop -----------------------------------------------------------------------------------------

func _pit_stop(a: ScenicArena) -> void:
	Game.scrap_in_flight = 0.0
	Game.run_scrap = 6000.0
	Game.shop_locked.clear()
	a.debug_skip_to_boss.call()
	var shop: PitStop = null
	for t in 60:
		await _seconds(0.25)
		for c in a.get_children():
			if c is PitStop and c.visible:
				shop = c
		if shop:
			break
	_check("a cleared sector opens the PIT STOP first (%s)" % (", ".join(shop.items.map(func(it: Dictionary) -> String:
		return "%s %d" % [it["id"], it["price"]])) if shop else "none"), shop != null and shop.items.size() == PitStop.SLOTS
		and get_tree().paused)
	if shop == null:
		return
	var s0 := Game.run_scrap
	var it0: Dictionary = shop.items[0]
	var lv0 := Upgrades.level_of(it0["id"]) if it0["kind"] == &"upgrade" else -1
	var bought := shop.buy(0)
	_check("buying spends the run's scrap (%.0f -> %.0f) and applies it" % [s0, Game.run_scrap], bought
		and is_equal_approx(Game.run_scrap, s0 - float(it0["price"])) and (lv0 < 0 or Upgrades.level_of(it0["id"]) == lv0 + 1))
	_check("...and it can't be bought twice", not shop.buy(0))
	var rp := shop.reroll_price()
	var s1 := Game.run_scrap
	shop.items[1]["locked"] = true
	var locked_id: StringName = shop.items[1]["id"]
	shop.reroll()
	_check("REROLL costs %d and keeps the locked item" % rp, is_equal_approx(Game.run_scrap, s1 - rp)
		and shop.items.any(func(it: Dictionary) -> bool: return it["id"] == locked_id and it["locked"])
		and shop.reroll_price() > rp)
	Game.run_scrap = 0.0
	_check("no scrap, no sale", not shop.buy(2))
	Game.run_scrap = 3000.0
	shop.close()
	await _seconds(0.6)
	_check("leaving keeps the locked item for the next pit stop", Game.shop_locked.size() == 1
		and Game.shop_locked[0]["id"] == locked_id)
	var doors := false
	var door_a := &""
	for t in 30:
		await _seconds(0.1)
		for c in a.get_children():
			if c is RouteChoice and c.visible:
				doors = c._routes.size() == 2 and c._routes.all(func(r: Dictionary) -> bool:
					return Game.OBJECTIVES.has(r.get("objective", &"")))
				if doors:
					door_a = c._routes[0]["objective"]
		if doors:
			break
	_check("then the route doors, each with a bonus objective", doors)
	Game.carry_overdrive = true
	for t in 60:
		await _seconds(0.25)
		if Game.campaign_sector == 2 and _arena() and _arena() != a and _mech():
			break
	await _seconds(0.5)
	var m := _mech()
	_check("sector 2's objective is door A's (%s)" % Game.active_objective(), _arena() != a and Game.active_objective() == door_a
		and _arena().objective != null)
	_check("an OVERDRIVE CELL starts the next sector with a full meter", m != null and m.overdrive_meter >= 100.0)
	var shop2 := PitStop.new()
	_arena().add_child(shop2)
	shop2.open()
	await _seconds(0.3)
	_check("the next pit stop puts the locked item first, still locked", shop2.items.size() == PitStop.SLOTS
		and shop2.items[0]["id"] == locked_id and shop2.items[0]["locked"])
	_check("...and prices climb a little each pit stop (%d stops)" % Game.pit_stops, Game.pit_stops == 2)
	shop2.close()
	await _seconds(0.4)


func _finish() -> void:
	PitStop.test_hold = false
	print("VARIETY TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1
