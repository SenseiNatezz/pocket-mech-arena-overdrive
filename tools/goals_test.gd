extends Node
## GOLD SALVAGER / THREAT TIERS / CONTRACTS test. Run:
##   godot --headless --path . res://environment/test_range.tscn -- --goals-test --temp-save
## Gold Salvager: it's spotted, flees, pays each prize (SCRAP FRENZY x7 that only counts down while the game
## runs, LUCKY, XP SURGE, OVERDRIVE, JACKPOT drones), falls back to LUCKY when a prize can't land, warps out
## with no prize when time runs out or a script wipes it, and the HUD announces it.
## Threat: diff() stacks the tiers on Extreme only, a win opens the next tier, bounties pay once per weapon
## per tier, the Loadout picker steps through the open tiers, and it all saves.
## Contracts: counters move only in real runs, contracts complete (toast + results lines), claim pays once,
## row bonuses switch on, the two unlocks (Salvager Beacon row, SALVAGE PROTOCOL card) open, the Hangar
## CONTRACTS tab shows them, and progress saves.
## Armory Mastery Pool: real-run mastery XP (mastered weapons too) + a bonus per mastery level fill it, the
## four checkpoints switch on +5% scrap / +1 reroll / +10% XP / FINISHER for all, the HUD toasts them, the
## results and the Armory show it, it saves, and an older save starts from its mastery.
## Prints PASS/FAIL per check; exit code 0 = all passed.

const CHASER := preload("res://enemies/chaser.tscn")
const SALVAGER := preload("res://enemies/gold_salvager.gd")

var _fails := 0
var mech: Mech
var hud: Node
var _spotted := 0
var _caught: Array = []
var _escaped := 0


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


func _target(pos: Vector2, hp := 60.0) -> Enemy:
	var e: Enemy = CHASER.instantiate()
	e.max_hp = hp
	e.move_speed = 0.0
	e.contact_damage = 0.0
	e.set("lunge_range", 0.0)
	e.position = pos
	get_tree().current_scene.add_child(e)
	return e


func _salvager(offset: Vector2, prize := &"") -> Enemy:
	var s: Enemy = SALVAGER.new()
	s.position = mech.global_position + offset
	s.set("prize_override", prize)
	get_tree().current_scene.add_child(s)
	return s


func _kill(e: Enemy) -> void:
	e.take_damage(e.hp + 1.0, e.global_position, mech)


func _run() -> void:
	await _frames(5)
	mech = get_tree().get_first_node_in_group("player") as Mech
	hud = get_tree().current_scene.get_node("HUD")
	get_tree().current_scene.get_node("Dummies").queue_free()
	mech.global_position = Vector2(-200, -560)
	mech._invuln = 1e9
	Controls.touch_aim = Vector2.RIGHT
	Upgrades.reset()
	Upgrades.level = Upgrades.MAX_LEVEL
	Game.salvager_spotted.connect(func() -> void: _spotted += 1)
	Game.salvager_caught.connect(func(p: StringName, a: float) -> void: _caught.append([p, a]))
	Game.salvager_escaped.connect(func() -> void: _escaped += 1)
	await _frames(5)
	await _salvager_checks()
	_threat_checks()
	await _contract_checks()
	await _ui_checks()
	await _pool_checks()
	Game.scrap_enabled = false
	print("GOALS TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


# --- gold salvager -----------------------------------------------------------------------------------------

func _salvager_checks() -> void:
	Game.scrap_enabled = true
	Game.bank_scrap()
	var s := _salvager(Vector2(140, 0), &"frenzy")
	await _frames(3)
	_check("a Gold Salvager is spotted (signal %d) and is a harmless, targetable robot" % _spotted,
		_spotted == 1 and s.is_in_group("salvagers") and s.is_in_group("enemies") and s.contact_damage == 0.0)
	_check("...and the HUD calls it out (\"%s\")" % hud._banner.text, hud._banner.text == "GOLD SALVAGER!")
	var d0 := s.global_position.distance_to(mech.global_position)
	await _frames(90)
	var d1 := s.global_position.distance_to(mech.global_position)
	_check("it flees from the pilot (%.0f -> %.0f px)" % [d0, d1], d1 > d0 + 80.0)
	# SCRAP FRENZY.
	_kill(s)
	_check("shot down: a SCRAP FRENZY starts (%.1f s, signal %s)" % [Game.frenzy_t, str(_caught)],
		is_equal_approx(Game.frenzy_t, Game.FRENZY_TIME) and _caught.size() == 1 and _caught[0][0] == &"frenzy")
	await _frames(2)
	_check("...with a banner (\"%s\")" % hud._banner.text, hud._banner.text == "SCRAP FRENZY  x7!")
	Game.bank_scrap()
	var got := Game.earn_scrap(100.0, &"waves")
	_check("during a frenzy every scrap gain is x7 (+%.0f), the extra filed under Gold Salvager (%s)" % [got,
		str(Game.run_scrap_parts)], is_equal_approx(got, 700.0) and is_equal_approx(float(Game.run_scrap_parts.get(&"gold", 0.0)), 600.0)
		and is_equal_approx(float(Game.run_scrap_parts.get(&"waves", 0.0)), 100.0))
	var f0 := Game.frenzy_t
	await _frames(30)
	var f1 := Game.frenzy_t
	get_tree().paused = true
	for i in 20:
		await get_tree().process_frame
	var f2 := Game.frenzy_t
	get_tree().paused = false
	_check("the frenzy runs down in play (%.2f -> %.2f) but not while paused (%.2f)" % [f0, f1, f2],
		f1 < f0 - 0.3 and is_equal_approx(f1, f2))
	Game.frenzy_t = 0.0
	Game.bank_scrap()
	# LUCKY: 15% of the run's scrap so far, as chips.
	Game.credit_scrap(10000.0, &"kills")
	var lucky := _salvager(Vector2(150, 40), &"lucky")
	await _frames(3)
	var before := Game.run_scrap
	_kill(lucky)
	# (the kill itself pays its usual scrap on top)
	_check("LUCKY pays 15%% of the run's scrap at once (+%.0f, run +%.0f) as flying chips" % [_caught[-1][1], Game.run_scrap - before],
		is_equal_approx(_caught[-1][1], 1500.0) and Game.run_scrap - before >= 1500.0 and Game.scrap_in_flight >= 1499.0
		and _caught[-1][0] == &"lucky")
	Game.bank_scrap()
	# XP SURGE (falls back to LUCKY at the level cap).
	var xs := _salvager(Vector2(150, -40), &"xp")
	await _frames(3)
	_kill(xs)
	_check("XP SURGE at the level cap pays LUCKY instead (%s, +%.0f)" % [_caught[-1][0], _caught[-1][1]],
		_caught[-1][0] == &"lucky" and _caught[-1][1] >= SALVAGER.LUCKY_MIN)
	Upgrades.level = 5
	Upgrades.xp = 0.0
	var xs2 := _salvager(Vector2(150, 80), &"xp")
	await _frames(3)
	var orbs0 := get_tree().get_nodes_in_group("xp_orbs").size()
	_kill(xs2)
	await _frames(3)
	_check("XP SURGE sprays XP shards (%d -> %d)" % [orbs0, get_tree().get_nodes_in_group("xp_orbs").size()],
		_caught[-1][0] == &"xp" and get_tree().get_nodes_in_group("xp_orbs").size() > orbs0)
	await _frames(60)
	Upgrades.level = Upgrades.MAX_LEVEL
	Upgrades.xp = 0.0
	Upgrades.pending = 0
	# OVERDRIVE.
	mech.overdrive_meter = 0.0
	mech.overdrive_left = 0.0
	var od := _salvager(Vector2(150, -80), &"overdrive")
	await _frames(3)
	_kill(od)
	_check("OVERDRIVE fills the meter (%.0f)" % mech.overdrive_meter, _caught[-1][0] == &"overdrive" and mech.overdrive_meter >= 100.0)
	mech.overdrive_meter = 0.0
	# JACKPOT: little gold drones that each pay scrap; no extra "spotted" calls.
	Game.bank_scrap()
	var spotted0 := _spotted
	var jp := _salvager(Vector2(160, 0), &"jackpot")
	await _frames(3)
	spotted0 = _spotted
	_kill(jp)
	await _frames(3)
	var minis := get_tree().get_nodes_in_group("salvagers").filter(func(n: Node) -> bool: return n.get("mini") == true)
	_check("JACKPOT bursts into %d little gold drones (no extra callouts)" % minis.size(),
		minis.size() == SALVAGER.JACKPOT_DRONES and _spotted == spotted0 and _caught[-1][0] == &"jackpot")
	var gold0 := float(Game.run_scrap_parts.get(&"gold", 0.0))
	var m: Enemy = minis[0]
	var val: float = m.get("value")
	await _frames(20)
	_kill(m)
	_check("...each one shot down pays its scrap (+%.0f)" % (float(Game.run_scrap_parts.get(&"gold", 0.0)) - gold0),
		val > 0.0 and is_equal_approx(float(Game.run_scrap_parts.get(&"gold", 0.0)) - gold0, val))
	for n in get_tree().get_nodes_in_group("salvagers"):
		n.queue_free()
	await _frames(3)
	# A scripted wipe (boss down) or the timer running out: it warps away, no prize.
	var n_caught := _caught.size()
	var wiped := _salvager(Vector2(150, 0))
	await _frames(3)
	wiped.die()
	var esc0 := _escaped
	_check("wiped out by a script, it warps away with no prize (escaped %d, caught %d)" % [esc0, _caught.size()],
		_caught.size() == n_caught and _escaped == 1 and wiped.dead)
	var late := _salvager(Vector2(150, 0))
	await _frames(3)
	late.set("_life", 0.05)
	await _frames(10)
	_check("when its time runs out it gets away (escaped %d)" % _escaped, _escaped == 2 and not is_instance_valid(late))
	await _frames(2)
	_check("...and the HUD says so (\"%s\")" % hud._banner.text, hud._banner.text == "IT GOT AWAY...")
	Game.bank_scrap()
	Game.scrap_enabled = false


# --- threat tiers ------------------------------------------------------------------------------------------

func _threat_checks() -> void:
	Game.difficulty = 3
	Game.threat = 0
	Game.threat_unlocked = 0
	Game.threat_best = 0
	Game.bounties.clear()
	_check("plain Extreme is unchanged (hp %.2f, scrap %.2f)" % [Game.diff("hp"), Game.diff("scrap")],
		is_equal_approx(Game.diff("hp"), 1.7) and is_equal_approx(Game.diff("scrap"), 1.7) and Game.threat_level() == 0)
	Game.threat = 3
	_check("THREAT 3 stacks ARMORED + ELITE TIDE + HEAVY ORDNANCE (hp %.3f, elite %.2f, damage %.4f, scrap %.3f)" % [
		Game.diff("hp"), Game.diff("elite"), Game.diff("damage"), Game.diff("scrap")],
		is_equal_approx(Game.diff("hp"), 2.04) and is_equal_approx(Game.diff("elite"), 0.18)
		and is_equal_approx(Game.diff("damage"), 2.0125) and is_equal_approx(Game.diff("scrap"), 2.975)
		and is_equal_approx(Game.diff("count"), 1.75) and Game.threat_escort() == 0)
	Game.threat = 10
	_check("THREAT 10 (hp %.3f, boss %.4f, heal %.3f, bombard %.2f, scrap %.2f, escort %d)" % [Game.diff("hp"),
		Game.diff("boss_hp"), Game.diff("heal"), Game.diff("bombard"), Game.diff("scrap"), Game.threat_escort()],
		is_equal_approx(Game.diff("hp"), 2.55) and is_equal_approx(Game.diff("boss_hp"), 2.8125)
		and is_equal_approx(Game.diff("heal"), 0.39) and is_equal_approx(Game.diff("bombard"), 2.72)
		and is_equal_approx(Game.diff("scrap"), 5.95) and Game.threat_escort() == 3
		and is_equal_approx(Game.diff("speed"), 1.18 * 1.12) and is_equal_approx(Game.diff("elite"), 0.26))
	Game.difficulty = 1
	_check("threat only counts on Extreme (Normal + threat 10: hp %.2f)" % Game.diff("hp"),
		Game.threat_level() == 0 and is_equal_approx(Game.diff("hp"), 1.0))
	# Unlocking + bounties.
	Game.difficulty = 3
	Game.threat = 0
	Game.scrap_enabled = true
	Game.bank_scrap()
	Game.weapon = &"blaster"
	var won: Array = []
	var on_won := func(t: int, b: int, o: bool) -> void: won.append([t, b, o])
	Game.threat_won.connect(on_won)
	Game.mark_cleared()
	_check("winning on plain Extreme opens THREAT 1 (%s)" % str(won), Game.threat_unlocked == 1 and won[-1] == [0, 0, true])
	Game.set_threat(5)
	_check("the picker only reaches open tiers (asked 5, got %d)" % Game.threat, Game.threat == 1)
	Game.bank_scrap()
	Game.mark_cleared()
	_check("a THREAT 1 win pays the Beam Rifle's bounty (+%s) and opens THREAT 2" % Game.fmt_int(int(Game.run_scrap_parts.get(&"bounty", 0.0))),
		won[-1] == [1, Game.BOUNTY_SCRAP, true] and is_equal_approx(float(Game.run_scrap_parts.get(&"bounty", 0.0)), 1000.0)
		and Game.threat_unlocked == 2 and Game.threat_best == 1)
	Game.mark_cleared()
	_check("...only once per weapon (%s)" % str(won[-1]), won[-1] == [1, 0, false])
	Game.weapon = &"sword"
	Game.mark_cleared()
	_check("...but every weapon has its own (Beam Saber: %s)" % str(won[-1]), won[-1] == [1, 1000, false]
		and Game.weapon_threat_best(&"sword") == 1 and Game.weapon_threat_best(&"blaster") == 1
		and Game.weapon_threat_best(&"katana") == 0)
	Game.weapon = &"blaster"
	Game.set_threat(2)
	Game.mode = &"endless"
	Game.record_endless_wave(9)
	var n_won := won.size()
	Game.record_endless_wave(Game.THREAT_ENDLESS_WAVE)
	_check("Endless: surviving wave %d is a win (THREAT 2 bounty %s)" % [Game.THREAT_ENDLESS_WAVE, str(won[-1])],
		won.size() == n_won + 1 and won[-1] == [2, 2000, true] and Game.threat_unlocked == 3)
	Game.mode = &"campaign"
	Game.threat_won.disconnect(on_won)
	# Saving.
	Game.save()
	Game.threat = 0
	Game.threat_unlocked = 0
	Game.bounties.clear()
	Game._load()
	_check("threat progress saves (tier %d, open %d, best %d, %d bounties)" % [Game.threat, Game.threat_unlocked,
		Game.threat_best, Game.bounties.size()], Game.threat == 2 and Game.threat_unlocked == 3 and Game.threat_best == 2
		and Game.bounties.size() == 3 and Game.bounty_claimed(&"sword", 1))
	Game.bank_scrap()
	Game.scrap_enabled = false
	Game.difficulty = 1


# --- contracts ---------------------------------------------------------------------------------------------

func _contract_checks() -> void:
	Game.contract_stats.clear()
	Game.contracts_done.clear()
	Game.contracts_claimed.clear()
	Game.scrap = 0
	# (toasts still queued from the checks above)
	hud._contract_queue.clear()
	if hud._contract_tw:
		hud._contract_tw.kill()
	hud._contract_toast.modulate.a = 0.0
	var done: Array[StringName] = []
	var on_done := func(id: StringName) -> void: done.append(id)
	Contracts.contract_done.connect(on_done)
	# Kills only count in real runs.
	var e := _target(mech.global_position + Vector2(150, 0))
	await _frames(2)
	_kill(e)
	_check("kills outside real runs don't count (%d)" % Contracts.value("kills"), Contracts.value("kills") == 0)
	Game.scrap_enabled = true
	Contracts.start_run()
	Game.contract_stats["kills"] = 99
	var e2 := _target(mech.global_position + Vector2(150, 40))
	await _frames(2)
	_kill(e2)
	_check("the 100th kill completes First Blood (signal %s, this run %s)" % [str(done), str(Contracts.completed_run)],
		Contracts.is_done(&"first_blood") and done.has(&"first_blood") and Contracts.completed_run.has(&"first_blood")
		and Contracts.value("w:blaster") == 1 and Contracts.value("k:Chaser") == 1)
	var toast := await _wait_until(func() -> bool: return hud._contract_toast.modulate.a > 0.9, 1.5)
	_check("a CONTRACT COMPLETE toast shows (\"%s\")" % (hud._contract_toast.find_child("Name", true, false) as Label).text,
		toast and (hud._contract_toast.find_child("Name", true, false) as Label).text == "FIRST BLOOD")
	_check("it's ready to claim, not paid yet (scrap %d)" % Game.scrap, Contracts.is_ready(&"first_blood") and Game.scrap == 0)
	_check("claiming pays the row's reward once (+%d, then +%d)" % [Contracts.claim(&"first_blood"), Contracts.claim(&"first_blood")],
		Game.scrap == 400 and Contracts.is_claimed(&"first_blood"))
	# Stats the save already knows complete on the next check.
	Game.waves_beaten = 15
	Contracts.check()
	_check("Wave Breaker reads the waves beaten (%d)" % Contracts.value("waves"), Contracts.is_done(&"wave_breaker"))
	# Unlocks: the Salvager Beacon row and the SALVAGE PROTOCOL card.
	Game.scrap = 100000
	_check("the Salvager Beacon row is locked until Gold Rush is done", Game.hangar_locked(&"beacon")
		and not Game.buy_hangar(&"beacon") and Game.hangar_level(&"beacon") == 0)
	_check("the SALVAGE PROTOCOL card isn't dealt before Jackpot", not Upgrades.is_available(&"salvage_protocol"))
	var s := _salvager(Vector2(150, 0), &"frenzy")
	await _frames(3)
	_kill(s)
	Game.frenzy_t = 0.0
	_check("shooting down a Gold Salvager completes Gold Rush and opens the Beacon (%d bought)" % Game.hangar_level(&"beacon"),
		Contracts.is_done(&"gold_rush") and not Game.hangar_locked(&"beacon") and Game.buy_hangar(&"beacon")
		and Game.hangar_level(&"beacon") == 1 and is_equal_approx(Game.salvager_interval_mult(), 0.88))
	Game.bank_scrap()
	Game.credit_scrap(5000.0, &"kills")
	Game.bank_scrap()
	_check("banking 5,000 in one run completes Jackpot and the card is dealt (best run %d)" % Contracts.value("best_run_scrap"),
		Contracts.is_done(&"jackpot") and Upgrades.is_available(&"salvage_protocol"))
	Upgrades.stacks[&"salvage_protocol"] = 2
	var g := Game.earn_scrap(100.0, &"kills")
	_check("SALVAGE PROTOCOL 2: +30%% scrap (+%.0f)" % g, is_equal_approx(g, 130.0))
	Upgrades.stacks.erase(&"salvage_protocol")
	Game.bank_scrap()
	# Row bonuses: claim all of ROOKIE and PILOT.
	for id in Contracts.row_ids(0) + Contracts.row_ids(1):
		if not Game.contracts_done.has(id):
			Game.contracts_done.append(id)
	var r0 := Contracts.claim_all()
	_check("CLAIM ALL pays everything ready (+%s) and lights ROOKIE + PILOT" % Game.fmt_int(r0),
		Contracts.row_complete(0) and Contracts.row_complete(1) and not Contracts.row_complete(2) and Contracts.ready_ids().is_empty())
	var g2 := Game.earn_scrap(100.0, &"kills")
	_check("ROOKIE: +5%% scrap (+%.0f); PILOT: +5%% damage (x%.3f)" % [g2, Contracts.damage_mult()],
		is_equal_approx(g2, 105.0) and is_equal_approx(Contracts.damage_mult(), 1.05))
	Game.bank_scrap()
	for id in Contracts.row_ids(2):
		if not Game.contracts_claimed.has(id):
			Game.contracts_claimed.append(id)
	Upgrades.reset()
	_check("VETERAN: +1 reroll every run (%d)" % Upgrades.rerolls, Upgrades.rerolls == Upgrades.BASE_REROLLS + 1)
	Upgrades.level = Upgrades.MAX_LEVEL
	Game.contracts_claimed.assign(Game.contracts_claimed.filter(func(id: StringName) -> bool: return not Contracts.row_ids(2).has(id)))
	_check("the closest unfinished contracts come first (%s)" % str(Contracts.closest(2)), Contracts.closest(2).size() == 2
		and not Contracts.is_done(Contracts.closest(2)[0]) and Contracts.fraction(Contracts.closest(2)[0]) >= Contracts.fraction(Contracts.closest(2)[1]))
	# Saving.
	Game.save()
	var stats := Game.contract_stats.duplicate()
	var n_done := Game.contracts_done.size()
	var n_claimed := Game.contracts_claimed.size()
	Game.contract_stats.clear()
	Game.contracts_done.clear()
	Game.contracts_claimed.clear()
	Game._load()
	_check("contract progress saves (%d done, %d claimed, kills %d)" % [Game.contracts_done.size(), Game.contracts_claimed.size(),
		Contracts.value("kills")], Game.contracts_done.size() == n_done and Game.contracts_claimed.size() == n_claimed
		and Game.contract_stats == stats and Contracts.is_claimed(&"first_blood"))
	# A veteran save: finished contracts are simply ready, without toasts.
	var n_signals := done.size()
	Game.unlocked.assign([&"blaster", &"sword", &"sniper", &"dual_sabers", &"katana", &"gatling", &"spear", &"rockets", &"axe"])
	var any := Contracts.check(false)
	_check("an existing save's finished contracts become ready silently (Collector ready: %s)" % Contracts.is_ready(&"collector"),
		any and Contracts.is_ready(&"collector") and done.size() == n_signals)
	Contracts.contract_done.disconnect(on_done)
	Game.scrap_enabled = false


# --- UI ----------------------------------------------------------------------------------------------------

func _ui_checks() -> void:
	# Results screen CONTRACTS block.
	Game.scrap_enabled = true
	Contracts.completed_run.assign([&"first_blood", &"gold_rush"])
	hud._show_goals(hud._win_goals)
	var done_l := hud._win_goals.find_child("Done", true, false) as Label
	var next_l := hud._win_goals.find_child("Next", true, false) as Label
	_check("the results screen lists this run's contracts and the next closest (\"%s\" / \"%s\")" % [done_l.text.replace("\n", " | "),
		next_l.text.replace("\n", " | ")], hud._win_goals.visible and done_l.text.contains("First Blood")
		and done_l.text.contains("Gold Rush") and next_l.text.begins_with("NEXT"))
	hud._win_goals.hide()
	Game.scrap_enabled = false
	# Hangar: CONTRACTS tab.
	var page := HangarPage.new()
	get_tree().current_scene.add_child(page)
	await _frames(2)
	_check("the Hangar opens on UPGRADES with a CONTRACTS tab (\"%s\")" % page._tab_btns[1].text,
		not page._contracts.visible and page._chassis_grid.visible and page._tab_btns[1].text.begins_with("CONTRACTS"))
	page._set_tab(1)
	await _frames(2)
	_check("the CONTRACTS tab shows all %d contracts in 5 rows" % page._contracts._cards.size(),
		page._contracts.visible and not page._chassis_grid.visible and page._contracts._cards.size() == Contracts.LIST.size()
		and page._contracts._grids.size() == Contracts.ROWS.size())
	var ready := Contracts.ready_ids().size()
	_check("...with CLAIM ALL while %d are ready (\"%s\")" % [ready, page._contracts._claim_all.text],
		ready > 0 and page._contracts._claim_all.visible and page._tab_btns[1].text.contains("READY"))
	var scrap0 := Game.scrap
	page._contracts._on_claim_all()
	await _frames(2)
	_check("CLAIM ALL pays out and refreshes the Hangar (%s scrap, label \"%s\")" % [Game.fmt_int(Game.scrap), page._scrap_label.text],
		Game.scrap > scrap0 and Contracts.ready_ids().is_empty() and not page._contracts._claim_all.visible
		and page._scrap_label.text == "%s SCRAP" % Game.fmt_int(Game.scrap))
	page._set_tab(0)
	Game.contracts_done.erase(&"gold_rush")
	page.refresh()
	var beacon = page._upgrade_rows[&"beacon"]
	_check("a locked Hangar row says which contract opens it (\"%s\")" % beacon._desc.text,
		beacon.buy.disabled and beacon.buy.text == "LOCKED" and beacon._desc.text.contains("Gold Rush"))
	page.queue_free()
	# Loadout THREAT picker.
	Game.difficulty = 3
	Game.threat = 0
	Game.threat_unlocked = 2
	var lo := ArmoryPage.new()
	lo.start_mode = true
	get_tree().current_scene.add_child(lo)
	await _frames(2)
	lo.focus_equipped()
	_check("the Loadout shows the THREAT picker on Extreme", lo._threat != null and lo._threat.active() and lo._threat._right.visible)
	lo._threat.step(1)
	lo._threat.step(1)
	lo._threat.step(1)
	_check("...which steps through the open tiers only (THREAT %d)" % Game.threat, Game.threat == 2)
	lo._threat.step(-1)
	_check("...and back down (THREAT %d)" % Game.threat, Game.threat == 1)
	Game.difficulty = 1
	lo.focus_equipped()
	_check("on other difficulties it's just a hint (no arrows)", not lo._threat.active() and not lo._threat._right.visible
		and lo._pool == null)
	lo.queue_free()
	await _frames(2)


# --- armory mastery pool -----------------------------------------------------------------------------------

func _pool_checks() -> void:
	Game.mastery.clear()
	Game.mastery_pool = 0
	Game.weapon = &"blaster"
	mech.weapon = &"blaster"
	Upgrades.level = Upgrades.MAX_LEVEL
	Game.scrap_enabled = true
	Game.bank_scrap()
	var hits: Array = []
	var on_cp := func(i: int) -> void: hits.append(i)
	Game.pool_checkpoint.connect(on_cp)
	# A 900 HP robot is worth 20 mastery XP.
	var e := _target(mech.global_position + Vector2(150, 0), 900.0)
	await _frames(2)
	_kill(e)
	_check("a kill's mastery XP also fills the pool (%d)" % Game.mastery_pool, Game.mastery_pool == 20)
	var e2 := _target(mech.global_position + Vector2(150, 50), 900.0)
	await _frames(2)
	_kill(e2)
	_check("...and a mastery level-up adds %d more (LV %d, pool %d)" % [Game.POOL_LEVEL_BONUS, Game.mastery_level(&"blaster"),
		Game.mastery_pool], Game.mastery_level(&"blaster") == 1 and Game.mastery_pool == 40 + Game.POOL_LEVEL_BONUS)
	Game.mastery[&"katana"] = Game.MASTERY_XP[9]
	var p0 := Game.mastery_pool
	Game.add_mastery(&"katana", 25)
	_check("a MASTERED weapon keeps filling the pool (+%d) without more mastery" % (Game.mastery_pool - p0),
		Game.mastery_pool - p0 == 25 and Game.mastery_xp(&"katana") == Game.MASTERY_XP[9])
	Game.scrap_enabled = false
	var e3 := _target(mech.global_position + Vector2(150, -50), 900.0)
	await _frames(2)
	_kill(e3)
	_check("no pool outside real runs (%d)" % Game.mastery_pool, Game.mastery_pool == p0 + 25)
	Game.scrap_enabled = true
	# Checkpoints and their perks.
	Game.bank_scrap()
	var base := Game.earn_scrap(100.0, &"kills")
	Game.mastery_pool = Game.pool_checkpoint_xp(0) - 1
	hits.clear()
	Game.add_pool(1)
	var boosted := Game.earn_scrap(100.0, &"kills")
	_check("10%%: a checkpoint (%s) and +5%% scrap (%.2f -> %.2f)" % [str(hits), base, boosted],
		hits == [0] and is_equal_approx(boosted, base * 1.05))
	Game.bank_scrap()
	Upgrades.reset()
	var r0 := Upgrades.rerolls
	Game.add_pool(Game.pool_checkpoint_xp(1) - Game.mastery_pool)
	Upgrades.reset()
	_check("25%%: +1 level-up reroll every run (%d -> %d)" % [r0, Upgrades.rerolls], Upgrades.rerolls == r0 + 1 and hits == [0, 1])
	Upgrades.level = 5
	Upgrades.xp = 0.0
	Upgrades.add_xp(10.0)
	var x0 := Upgrades.xp
	Upgrades.xp = 0.0
	Game.add_pool(Game.pool_checkpoint_xp(2) - Game.mastery_pool)
	Upgrades.add_xp(10.0)
	_check("50%%: +10%% XP (%.2f -> %.2f)" % [x0, Upgrades.xp], x0 > 0.0 and is_equal_approx(Upgrades.xp, x0 * 1.1) and hits == [0, 1, 2])
	Upgrades.level = Upgrades.MAX_LEVEL
	Upgrades.xp = 0.0
	Game.mastery[&"sniper"] = 0
	var before := Game.has_finisher(&"sniper")
	Game.add_pool(Game.POOL_MAX)
	_check("95%%: FINISHER on every weapon (Sniper Beam at LV 0: %s -> %s), the pool caps at %s" % [before,
		Game.has_finisher(&"sniper"), Game.fmt_int(Game.mastery_pool)], not before and Game.has_finisher(&"sniper")
		and Game.mastery_pool == Game.POOL_MAX and hits == [0, 1, 2, 3])
	var shown := await _wait_until(func() -> bool: return hud._pool_toast.modulate.a > 0.9, 1.5)
	var head := (hud._pool_toast.find_child("Head", true, false) as Label).text
	_check("a MASTERY POOL toast shows each checkpoint (\"%s\")" % head, shown and head.contains("95%"))
	Game.pool_checkpoint.disconnect(on_cp)
	# The results screen's mastery line.
	Game.credit_scrap(10.0, &"kills")
	hud._show_scrap_results(hud._win_scrap)
	var ml := (hud._win_scrap.find_child("Mastery", true, false) as Label).text
	_check("the results show the pool (\"%s\")" % ml, ml.ends_with("POOL 100%"))
	hud._win_scrap.hide()
	# Saving, and a save from before the pool.
	Game.mastery_pool = 7777
	Game.save()
	Game.mastery_pool = 0
	Game._load()
	_check("the pool saves (%d)" % Game.mastery_pool, Game.mastery_pool == 7777)
	var old := ConfigFile.new()
	old.set_value("mastery", "xp", {"blaster": 100, "katana": 40})
	old.save(Game.save_path)
	Game.mastery.clear()
	Game._load()
	var want := 100 + 2 * Game.POOL_LEVEL_BONUS + 40 + Game.POOL_LEVEL_BONUS
	_check("an older save starts its pool from its mastery so far (%d = %d)" % [Game.mastery_pool, want], Game.mastery_pool == want)
	# The Armory shows it.
	var ar := ArmoryPage.new()
	get_tree().current_scene.add_child(ar)
	await _frames(2)
	_check("the Armory shows the MASTERY POOL strip", ar._pool != null and ar._threat == null and ar._pool.visible
		and ar._pool.size.x > 300.0)
	ar.queue_free()
	Game.scrap_enabled = false
	await _frames(2)
