extends Node
## Incremental systems test: LIVE SCRAP, the ENDLESS HANGAR and WEAPON MASTERY. Run:
##   godot --path . res://environment/test_range.tscn -- --incremental-test --temp-save
## Checks that kills drop scrap chips that fly to the mech and roll up the HUD's scrap ticker (with "+N"
## pops; wave bonuses are labelled), that the results screen counts the run's scrap up with a breakdown
## that adds up, that a maxed Hangar row buys MK II (price, effects, Hangar card), that kills raise the
## equipped weapon's mastery (levels, +2% damage per level through the real fire path, FINISHER, the
## MASTERY UP toast), and that it all saves, loads back, and old saves get their scrap x10 exactly once.
## Prints PASS/FAIL per check; exit code 0 = all passed.

const CHASER := preload("res://enemies/chaser.tscn")

var _fails := 0
var mech: Mech
var hud: Node


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


## A stationary, harmless robot.
func _target(pos: Vector2, hp := 60.0) -> Enemy:
	var e: Enemy = CHASER.instantiate()
	e.max_hp = hp
	e.move_speed = 0.0
	e.contact_damage = 0.0
	e.set("lunge_range", 0.0)
	e.position = pos
	get_tree().current_scene.add_child(e)
	return e


func _run() -> void:
	await _frames(5)
	mech = get_tree().get_first_node_in_group("player") as Mech
	hud = get_tree().current_scene.get_node("HUD")
	get_tree().current_scene.get_node("Dummies").queue_free()
	mech.global_position = Vector2(-200, -560)
	mech._invuln = 1e9
	Controls.touch_aim = Vector2.RIGHT
	Upgrades.reset()
	# (pilot level-ups would pause the game mid-check: at the level cap kills give no more XP)
	Upgrades.level = Upgrades.MAX_LEVEL
	await _frames(5)
	await _scrap_checks()
	await _hangar_checks()
	await _mastery_checks()
	_save_checks()
	Game.scrap_enabled = false
	print("INCREMENTAL TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


# --- live scrap -------------------------------------------------------------------------------------------

func _scrap_checks() -> void:
	Game.scrap_enabled = true
	Game.bank_scrap()
	Game.scrap = 0
	var e := _target(mech.global_position + Vector2(160, 0), 60.0)
	await _frames(3)
	e.take_damage(99999.0, e.global_position, mech)
	# A 60 HP robot is worth 1 XP, so it pays the SCRAP_KILL minimum (x Normal difficulty's 1.0).
	_check("a kill credits its scrap at once (+%.1f)" % Game.run_scrap, is_equal_approx(Game.run_scrap, Game.SCRAP_KILL))
	_check("...carried by scrap chips, so the ticker hasn't counted it yet",
		is_equal_approx(Game.scrap_in_flight, Game.run_scrap) and Game.run_scrap_landed() == 0.0)
	await _frames(2)
	_check("the robot drops gold scrap chips", get_tree().get_nodes_in_group("scrap_chips").size() > 0)
	var landed := func() -> bool: return Game.scrap_in_flight <= 0.0 and get_tree().get_nodes_in_group("scrap_chips").is_empty()
	_check("the chips fly to the mech on their own", await _wait_until(landed, 3.0))
	_check("the HUD scrap counter rolls up to it with a +N pop (shows %.1f, pop +%.0f)" % [hud._scrap_shown, hud._scrap_pop],
		await _wait_until(func() -> bool: return absf(hud._scrap_shown - Game.run_scrap) < 0.01, 2.0)
		and is_equal_approx(hud._scrap_pop, Game.SCRAP_KILL))
	# A wave bonus has no chips: it pays at once, with a labelled pop.
	Game.record_wave_cleared()
	await _frames(2)
	_check("a wave bonus pops \"+%.0f %s\"" % [hud._scrap_pop, hud._scrap_pop_label],
		hud._scrap_pop_label == "WAVE" and is_equal_approx(hud._scrap_pop, Game.SCRAP_WAVE))
	# Results screen: banks it, counts it up, and the breakdown adds up.
	var total := roundi(Game.run_scrap)
	hud._show_scrap_results(hud._win_scrap)
	_check("the results screen banks the run (+%d, Hangar %d)" % [Game.last_banked, Game.scrap],
		Game.last_banked == total and Game.scrap == total and Game.run_scrap == 0.0)
	var parts := 0
	for k in Game.last_parts:
		parts += int(Game.last_parts[k])
	_check("...with a breakdown that adds up (%s)" % str(Game.last_parts),
		parts == total and int(Game.last_parts.get(&"kills", 0)) == 10 and int(Game.last_parts.get(&"waves", 0)) == 50)
	var amount := hud._win_scrap.find_child("Amount", true, false) as Label
	_check("...and counts it up to \"+%d\"" % total, hud._win_scrap.visible
		and await _wait_until(func() -> bool: return amount.text == "+" + Game.fmt_int(total), 3.0))
	hud._win_scrap.hide()
	_check("big numbers get thousands separators (%s)" % Game.fmt_int(1234567),
		Game.fmt_int(1234567) == "1,234,567" and Game.fmt_int(950) == "950" and Game.fmt_int(1000) == "1,000")
	Game.scrap_enabled = false


# --- endless hangar ---------------------------------------------------------------------------------------

func _hangar_checks() -> void:
	Game.hangar.clear()
	Game.hangar[&"frame"] = 5
	Game.scrap = 100000
	_check("a maxed row offers MK II at its last price x1.15 (%d)" % Game.hangar_cost(&"frame"), Game.hangar_cost(&"frame") == 3680)
	_check("buying it spends the scrap and adds an MK level", Game.buy_hangar(&"frame") and Game.scrap == 100000 - 3680
		and Game.hangar_mk(&"frame") == 1 and Game.hangar_level(&"frame") == 5 and Game.hangar_mk_name(&"frame") == "MK II")
	_check("MK III costs 15%% more (%d)" % Game.hangar_cost(&"frame"), Game.hangar_cost(&"frame") == 4230)
	Game.hangar[&"frame"] = 5 + 21
	_check("MK levels go on forever (%s, next %d scrap)" % [Game.hangar_mk_name(&"frame"), Game.hangar_cost(&"frame")],
		Game.hangar_mk_name(&"frame") == "MK XXII" and Game.hangar_cost(&"frame") > 50000)
	# Each MK level is +2% of the row's stat.
	Game.hangar[&"calibration"] = 5
	var d0 := Upgrades.damage_mult()
	Game.hangar[&"calibration"] = 8
	_check("Weapon Calibration MK IV adds +6%% damage (x%.4f)" % (Upgrades.damage_mult() / d0),
		is_equal_approx(Upgrades.damage_mult() / d0, 1.31 / 1.25))
	Game.hangar[&"servos"] = 3
	var m0 := Upgrades.move_mult()
	Game.hangar[&"servos"] = 4
	_check("Servo Motors MK II adds +2%% speed (x%.4f)" % (Upgrades.move_mult() / m0), is_equal_approx(Upgrades.move_mult() / m0, 1.14 / 1.12))
	# Spare Repair Kits MK: kits heal more (mech.gd).
	Game.hangar[&"kits"] = 2 + 5
	mech.hp = 10.0
	mech.repair_charges = 1
	mech._repair_cd = 0.0
	mech._self_repair()
	_check("Spare Repair Kits MK VI: kits heal +10%% (%.0f HP)" % (mech.hp - 10.0),
		is_equal_approx(mech.hp - 10.0, mech.repair_amount * Game.diff("heal") * 1.1))
	# Last Stand MK: survive with a share of max HP (mech.gd).
	Game.hangar[&"last_stand"] = 1 + 10
	mech.hp = mech.max_hp
	mech._last_stand_used = false
	mech._apply_damage(mech.max_hp + 50.0)
	_check("Last Stand MK XI saves you on 20%% HP (%.0f / %.0f)" % [mech.hp, mech.max_hp],
		not mech.dead and is_equal_approx(mech.hp, mech.max_hp * 0.2))
	mech.hp = mech.max_hp
	# The Hangar card shows it.
	var page := HangarPage.new()
	get_tree().current_scene.add_child(page)
	await _frames(2)
	var row = page._upgrade_rows[&"frame"]
	_check("the Hangar card shows the MK badge and a gold MK buy button (\"%s\" / \"%s\")" % [row._mk_badge.text, row.buy.text],
		row._mk_badge.visible and row._mk_badge.text == "MK XXII" and row.buy.text.begins_with("MK XXIII") and row._mk_line.visible)
	var fresh = page._upgrade_rows[&"analytics"]
	_check("...and a row that isn't maxed still says UPGRADE (\"%s\")" % fresh.buy.text,
		fresh.buy.text.begins_with("UPGRADE") and not fresh._mk_badge.visible and not fresh._mk_line.visible)
	page.queue_free()
	Game.hangar.clear()
	Game.scrap = 0
	await _frames(15)


# --- weapon mastery ---------------------------------------------------------------------------------------

func _mastery_checks() -> void:
	Game.mastery.clear()
	Game.weapon = &"blaster"
	mech.weapon = &"blaster"
	Game.scrap_enabled = true
	var ups := []
	var on_up := func(id: StringName, lvl: int) -> void: ups.append([id, lvl])
	Game.mastery_up.connect(on_up)
	# Two tough robots (900 HP: 20 XP each) take the Beam Rifle past LV 1 (30).
	for i in 2:
		var e := _target(mech.global_position + Vector2(160, 60 * i), 900.0)
		await _frames(2)
		e.take_damage(999999.0, e.global_position, mech)
	_check("kills give the equipped weapon mastery XP (%d)" % Game.mastery_xp(&"blaster"), Game.mastery_xp(&"blaster") == 40)
	_check("...and it levels up (LV %d, signal %s)" % [Game.mastery_level(&"blaster"), str(ups)],
		Game.mastery_level(&"blaster") == 1 and ups.size() == 1 and ups[0] == [&"blaster", 1])
	var toast_up := await _wait_until(func() -> bool: return hud._mastery_toast.modulate.a > 0.9, 1.5)
	var toast_name := (hud._mastery_toast.find_child("Name", true, false) as Label).text
	_check("a MASTERY UP toast shows (\"%s\", alpha %.2f, at %s)" % [toast_name, hud._mastery_toast.modulate.a,
		str(hud._mastery_toast.position)], toast_up and toast_name.contains("LV 1"))
	_check("other weapons are untouched", Game.mastery_xp(&"sniper") == 0)
	Game.scrap_enabled = false
	var off := _target(mech.global_position + Vector2(160, -60), 900.0)
	await _frames(2)
	off.take_damage(999999.0, off.global_position, mech)
	_check("no mastery outside real runs (ranges, tutorial)", Game.mastery_xp(&"blaster") == 40)
	Game.mastery_up.disconnect(on_up)
	await _frames(30)

	# +2% damage per level, through the real fire path (mech.gd scales the primary weapon).
	var t := _target(mech.global_position + Vector2(230, 0), 1000000.0)
	var hits: Array[float] = []
	var rec := func(amount: float, _src: Node, target: Node) -> void:
		if target == t:
			hits.append(amount)
	Combat.damage_dealt.connect(rec)
	await _frames(3)
	Game.mastery[&"blaster"] = 0
	await _fire_once()
	var a0: float = hits[0] if not hits.is_empty() else 0.0
	hits.clear()
	Game.mastery[&"blaster"] = Game.MASTERY_XP[4]
	await _fire_once()
	var a5: float = hits[0] if not hits.is_empty() else 0.0
	Combat.damage_dealt.disconnect(rec)
	_check("each mastery level is +2%% damage with the weapon (LV 0 %.1f -> LV 5 %.1f)" % [a0, a5],
		a0 > 0.0 and is_equal_approx(a5 / a0, 1.1))
	t.queue_free()

	# FINISHER (LV 5): hits on robots under 35% HP land 25% harder.
	var low := _target(mech.global_position + Vector2(160, 120), 1000.0)
	var high := _target(mech.global_position + Vector2(160, 180), 1000.0)
	await _frames(2)
	low.hp = 300.0
	low.take_damage(100.0, low.global_position, mech)
	high.take_damage(100.0, high.global_position, mech)
	_check("FINISHER: a robot under 35%% HP takes +25%% (-%.0f), a healthy one doesn't (-%.0f)" % [300.0 - low.hp, 1000.0 - high.hp],
		is_equal_approx(low.hp, 175.0) and is_equal_approx(high.hp, 900.0))
	Game.mastery[&"blaster"] = Game.MASTERY_XP[3]
	low.take_damage(10.0, low.global_position, mech)
	_check("...and only from mastery LV 5 (LV 4: -%.0f)" % (175.0 - low.hp), is_equal_approx(low.hp, 165.0))
	low.queue_free()
	high.queue_free()
	# LV 10: MASTERED, and the XP stops there.
	Game.mastery[&"blaster"] = Game.MASTERY_XP[9]
	Game.add_mastery(&"blaster", 50)
	_check("LV 10 is MASTERED (+%d%% damage) and stops counting" % roundi((Game.mastery_damage_mult(&"blaster") - 1.0) * 100.0),
		Game.is_mastered(&"blaster") and Game.mastery_xp(&"blaster") == Game.MASTERY_XP[9]
		and is_equal_approx(Game.mastery_damage_mult(&"blaster"), 1.2) and Game.mastery_fraction(&"blaster") == 1.0)
	Game.mastery[&"blaster"] = 100
	var p := Game.mastery_progress(&"blaster")
	_check("progress inside a level (LV %d, %d / %d)" % [Game.mastery_level(&"blaster"), p.x, p.y],
		Game.mastery_level(&"blaster") == 2 and p == Vector2i(25, 65))
	Game.scrap_enabled = false
	await _frames(5)


## One shot of the equipped weapon through the mech's own firing code (waits for the bolt to land).
func _fire_once() -> void:
	await _frames(20)
	Input.action_press(&"fire_primary")
	await _frames(1)
	Input.action_release(&"fire_primary")
	await _frames(30)


# --- saving -----------------------------------------------------------------------------------------------

func _save_checks() -> void:
	Game.mastery.clear()
	Game.mastery[&"katana"] = 400
	Game.scrap = 4321
	Game.hangar.clear()
	Game.hangar[&"servos"] = 5
	Game.save()
	var cfg := ConfigFile.new()
	cfg.load(Game.save_path)
	var mxp: Dictionary = cfg.get_value("mastery", "xp", {})
	_check("the save holds mastery XP and the save version", int(mxp.get("katana", 0)) == 400
		and int(cfg.get_value("progress", "save_version", 0)) == Game.SAVE_VERSION)
	Game.mastery.clear()
	Game.scrap = 0
	Game.hangar.clear()
	Game._load()
	_check("...and loads back (katana mastery LV %d, Servo Motors %s, %s scrap)" % [Game.mastery_level(&"katana"),
		Game.hangar_mk_name(&"servos"), Game.fmt_int(Game.scrap)], Game.mastery_xp(&"katana") == 400
		and Game.hangar_mk(&"servos") == 2 and Game.scrap == 4321)
	# A save from before scrap went x10 (no save_version): its bank is scaled once, upgrades kept.
	var old := ConfigFile.new()
	old.set_value("hangar", "scrap", 1234)
	old.set_value("hangar", "upgrades", {"frame": 2, "calibration": 5})
	old.set_value("progress", "cleared", [0])
	old.save(Game.save_path)
	Game.scrap = 0
	Game.hangar.clear()
	Game.mastery.clear()
	Game._load()
	_check("an old save's scrap is scaled x10 (1,234 -> %s), its upgrades kept" % Game.fmt_int(Game.scrap),
		Game.scrap == 12340 and Game.hangar_level(&"frame") == 2 and Game.hangar_level(&"calibration") == 5
		and Game.hangar_mk(&"calibration") == 0 and Game.mastery.is_empty())
	Game.save()
	Game._load()
	_check("...exactly once (%s after a save + reload)" % Game.fmt_int(Game.scrap), Game.scrap == 12340)
