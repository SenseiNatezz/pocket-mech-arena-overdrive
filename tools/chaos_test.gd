extends Node
## CHAOS RIFT test (Game.CHAOS_*, environment/chaos_rift.gd, ui/chaos_boon.gd, the third route door):
##   godot --headless --path . -- --arena=1 --sector=1 --no-intro --no-rival --chaos --curse=strain --temp-save
##       --attach=res://tools/chaos_test.gd
## -> "CHAOS TEST OK (0 failed)"

static var _running := false
var _fails := 0


func _ready() -> void:
	if _running:
		queue_free()
		return
	_running = true
	_run.call_deferred()


func _seconds(s: float) -> void:
	for i in int(s * Engine.physics_ticks_per_second):
		await get_tree().physics_frame


## (overlays show themselves in _process: wait on drawn frames, not physics ticks)
func _idle(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _arena() -> ScenicArena:
	return get_tree().get_first_node_in_group("arena") as ScenicArena


func _mech() -> Mech:
	return get_tree().get_first_node_in_group("player") as Mech


func _find(parent: Node, type: Variant) -> Node:
	for c in parent.get_children():
		if is_instance_of(c, type):
			return c
	return null


func _run() -> void:
	reparent(get_tree().root)
	Controls.ignore_real_input = false  # (the doors / blessings are picked by the test, not auto-picked)
	await _seconds(1.0)
	var a := _arena()
	var m := _mech()
	if a == null or m == null:
		_check("arena + mech", false)
		_finish()
		return
	m._invuln = 1e9
	await _curse(a)
	_blessing_math()
	await _doors(a, m)
	_retry()
	_finish()


# --- 1. a cursed sector: the curse, its lift after 3 waves, the blessing pick -------------------------------

func _curse(a: ScenicArena) -> void:
	_check("--curse=strain curses the sector (%s)" % Game.active_curse(), Game.active_curse() == &"strain")
	_check("...robots hit 35%% harder (enemy_damage x%.2f)" % Game.twist_value("enemy_damage"),
		is_equal_approx(Game.twist_value("enemy_damage"), 1.35 * _twist_only("enemy_damage")))
	var rift := a.get_node_or_null("ChaosRift") as ChaosRift
	_check("the arena adds the CHAOS RIFT controller", rift != null)
	if rift == null:
		return
	_check("its plate counts %d waves to go" % rift.waves_left(), rift.waves_left() == Game.CHAOS_CURSE_WAVES)
	a.zone.wave_cleared.emit(1, 8)
	a.zone.wave_cleared.emit(2, 8)
	_check("two waves in, the curse still holds", Game.active_curse() == &"strain" and rift.waves_left() == 1)
	a.zone.wave_cleared.emit(3, 8)
	await _seconds(0.2)
	_check("wave 3 cleared: the curse lifts (enemy_damage back to x%.2f)" % Game.twist_value("enemy_damage"),
		Game.active_curse() == &"" and Game.chaos_lifted and is_equal_approx(Game.twist_value("enemy_damage"),
		_twist_only("enemy_damage")))
	var boon := _find(a, ChaosBoon) as ChaosBoon
	_check("...and the CHAOS BLESSING pick opens, game paused", boon != null and boon.visible and get_tree().paused)
	if boon == null:
		return
	var ids: Array = boon._offers.map(func(o: Dictionary) -> StringName: return o["id"])
	_check("three different blessings (%s)" % ", ".join(boon._offers.map(func(o: Dictionary) -> String:
		return "%s %s" % [o["id"], Game.CHAOS_RARITY[o["rarity"]]["name"]])),
		boon._offers.size() == 3 and ids.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2])
	_check("three cards on screen", boon._cards.size() == 3)
	# Take a kept blessing (not ARSENAL) and check its rule changes.
	var pick := 0
	for i in boon._offers.size():
		if Game.CHAOS_BLESSINGS[boon._offers[i]["id"]]["key"] != "":
			pick = i
			break
	var offer: Dictionary = boon._offers[pick]
	var key: String = Game.CHAOS_BLESSINGS[offer["id"]]["key"]
	await _seconds(0.0)
	boon._t = 1.0
	boon._choose(pick)
	await get_tree().create_timer(0.8, true, false, true).timeout
	_check("picking %s %s keeps it for the run" % [offer["id"], Game.CHAOS_RARITY[offer["rarity"]]["name"]],
		int(Game.chaos_blessings.get(offer["id"], -1)) == offer["rarity"])
	if key != "":
		var want := float(Game.CHAOS_BLESSINGS[offer["id"]]["values"][offer["rarity"]])
		_check("...%s is now x%.2f" % [key, Game.twist_value(key)], is_equal_approx(Game.twist_value(key), want * _twist_only(key)))
	_check("the pick closes and the game runs again", not is_instance_valid(boon) and not get_tree().paused)


## The twist / route deal's own share of a rule (so the checks hold whatever twist the sector rolled).
func _twist_only(key: String) -> float:
	var v := 1.0
	var t := Game.active_twist()
	if Game.TWISTS.has(t):
		v *= float(Game.TWISTS[t].get(key, 1.0))
	return v


# --- 2. blessing rules ------------------------------------------------------------------------------------

func _blessing_math() -> void:
	var keep := Game.chaos_blessings.duplicate()
	_check("blessing text reads right (%s / %s)" % [Game.chaos_blessing_text(&"hunger", 1), Game.chaos_blessing_text(&"blunt", 2)],
		Game.chaos_blessing_text(&"hunger", 1) == "+40% XP" and Game.chaos_blessing_text(&"blunt", 2) == "Robots hit 30% softer")
	_check("ARSENAL text (%s / %s)" % [Game.chaos_blessing_text(&"arsenal", 0), Game.chaos_blessing_text(&"arsenal", 2)],
		Game.chaos_blessing_text(&"arsenal", 0) == "1 free upgrade card right now"
		and Game.chaos_blessing_text(&"arsenal", 2) == "3 free upgrade cards right now")
	var p0 := Upgrades.pending
	Game.take_chaos_blessing(&"arsenal", 1)
	_check("ARSENAL (rare) deals 2 free upgrade cards (%d -> %d) and isn't kept" % [p0, Upgrades.pending],
		Upgrades.pending == p0 + 2 and not Game.chaos_blessings.has(&"arsenal"))
	Upgrades.pending = p0
	Upgrades.bonus_picks = maxi(Upgrades.bonus_picks - 2, 0)
	Game.chaos_blessings = {&"hunger": 2}
	var ok := true
	for k in 30:
		for o: Dictionary in Game.roll_chaos_blessings(3):
			ok = ok and o["id"] != &"hunger"
	_check("a blessing held at EPIC is never offered again", ok)
	Game.chaos_blessings = {&"tithe": 0}
	var raised := true
	for k in 30:
		for o: Dictionary in Game.roll_chaos_blessings(3):
			if o["id"] == &"tithe":
				raised = raised and o["rarity"] >= 1
	_check("one held at COMMON comes back RARE or better", raised)
	Game.take_chaos_blessing(&"tithe", 0)
	_check("...and taking it lower never downgrades it", Game.chaos_blessings[&"tithe"] == 0)
	Game.take_chaos_blessing(&"tithe", 2)
	_check("taking it at EPIC upgrades it", Game.chaos_blessings[&"tithe"] == 2)
	Game.chaos_blessings = keep


# --- 3. the third route door ------------------------------------------------------------------------------

func _doors(a: ScenicArena, m: Mech) -> void:
	var routes := Game.route_options()
	_check("--chaos: the route doors offer 3 routes (%d)" % routes.size(), routes.size() == 3)
	if routes.size() < 3:
		return
	var r3: Dictionary = routes[2]
	_check("door C is the CHAOS RIFT: a curse, no twist or deal (%s)" % r3.get("curse", &""),
		Game.CHAOS_CURSES.has(r3.get("curse", &"")) and r3["twist"] == &"" and r3["deal"] == &"")
	_check("...on a map of its own (%s)" % r3["name"], r3["scene"] != routes[0]["scene"] and r3["scene"] != routes[1]["scene"]
		and r3["scene"] != Game.sector_scenes[0])
	# The door screen: three doors, the rift sealed when the pilot is too hurt.
	m.hp = m.max_hp
	var choice := RouteChoice.new()
	a.add_child(choice)
	choice.open(routes)
	await _idle(4)
	_check("three doors on screen (%d doors, visible %s, sealed %s, level-up open %s, pending %d)" % [choice._doors.size(),
		choice.visible, choice._sealed, Upgrades.choosing, Upgrades.pending],
		choice._doors.size() == 3 and choice.visible and choice._sealed.is_empty())
	choice._done = true
	get_tree().paused = false
	choice.queue_free()
	m.hp = m.max_hp * 0.12
	var choice2 := RouteChoice.new()
	a.add_child(choice2)
	choice2.open(routes)
	await _idle(4)
	choice2._t = 1.0
	choice2._choose(2)
	_check("at 12% HP the rift is sealed and can't be picked", choice2._sealed.size() == 1 and choice2._sealed[0] == 2
		and not choice2._done)
	choice2._done = true
	get_tree().paused = false
	choice2.queue_free()
	# Through the rift: HP toll, the curse set on the next sector. (At 90% HP the patch-up alone would fill the
	# bar: the toll comes off after it, so it's really paid.)
	m.hp = m.max_hp * 0.9
	var nexts := Game.campaign_sector + 1
	Game.next_sector(0.9, 1, r3)
	_check("the rift takes its toll: 90%% + patch-up (max 100%%) - 15%% = %d%%" % roundi(Game.carry_hp * 100.0),
		is_equal_approx(Game.carry_hp, minf(0.9 + Game.SECTOR_REPAIR, 1.0) - Game.CHAOS_HP_COST))
	_check("sector %d is cursed (%s)" % [nexts, Game.sector_curses[nexts - 1]],
		Game.sector_curses[nexts - 1] == r3["curse"] and not Game.chaos_lifted)
	await _seconds(2.0)
	var a2 := _arena()
	_check("the next map (%s) has the rift controller" % (a2.name if a2 else "-"), is_instance_valid(a2)
		and a2.scene_file_path == r3["scene"] and a2.get_node_or_null("ChaosRift") != null)
	_check("...and the curse is live there (%s)" % Game.active_curse(), Game.active_curse() == r3["curse"])


# --- 4. RETRY LEVEL / a new run ----------------------------------------------------------------------------

func _retry() -> void:
	Game.chaos_blessings[&"stride"] = 1
	Game._chaos_checkpoint = {&"hollow": 0}
	Game.restart_arena()
	_check("RETRY LEVEL goes back to the blessings the level started with", Game.chaos_blessings == {&"hollow": 0})
	Game.start_arena(0, false, 1)
	# (sector 1 is cursed again only because this test runs with --curse=strain)
	_check("a new run starts with no blessings and no rift ahead", Game.chaos_blessings.is_empty()
		and Game.sector_curses.size() == 3 and Game.sector_curses[1] == &"" and Game.sector_curses[2] == &"")


func _finish() -> void:
	print("CHAOS TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1
