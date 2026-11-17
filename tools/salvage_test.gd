extends Node
## SALVAGE COMBAT + LIMB DAMAGE test (autoload/salvage.gd). Run it in landscape, then with the phone layout:
##   godot --headless --path . res://environment/test_range.tscn -- --salvage-test --temp-save
##   godot --headless --path . res://environment/test_range.tscn -- --salvage-test --temp-save --portrait
## A fresh run has whole limbs and nothing bolted on (the mech exactly as before). Hits wear limbs down; each
## BROKEN limb costs what it says (HEAD no crits, ARMS attack speed + damage, LEGS speed, BACKPACK boost cooldown);
## repair kits patch limbs (even at full HP). Player kills drop the robot's own piece (melee tears it off, elites
## always drop, other robots' kills / swarms never), grabbing it bolts it on (its stat reaches the mech) and fixes
## the limb, a full slot pays scrap instead, and a new run clears it all. The HUD shows the feed.
## Prints PASS/FAIL per check; exit code 0 = all passed.

const CHASER := preload("res://enemies/chaser.tscn")

var _fails := 0
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


func _near(a: float, b: float, eps := 0.002) -> bool:
	return absf(a - b) <= eps


func _run() -> void:
	await _frames(5)
	mech = get_tree().get_first_node_in_group("player") as Mech
	Upgrades.reset()
	_fresh_checks()
	await _limb_checks()
	await _drop_checks()
	await _collect_checks()
	_reset_checks()
	Game.scrap_enabled = false
	Upgrades.reset()
	print("SALVAGE TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _fresh_checks() -> void:
	var whole := true
	for s in Salvage.SLOTS:
		whole = whole and Salvage.integrity[s] == 1.0
	_check("a fresh run: all four limbs whole", whole)
	_check("a fresh run: nothing bolted on", Salvage.bolted.is_empty())
	var neutral := true
	for st in ["speed", "damage", "rate", "fire_rate", "melee_rate", "boost_cd", "magnet"]:
		neutral = neutral and Salvage.mult(st) == 1.0
	_check("a fresh run: no salvage multipliers, no crit change", neutral and Salvage.add("crit") == 0.0)


func _limb_checks() -> void:
	var speed := Upgrades.move_mult()
	var dmg := Upgrades.damage_mult()
	var rate := mech._weapon_rate()
	var cd := Upgrades.boost_cd_mult()
	var broke: Array[StringName] = []
	var on_break := func(s: StringName) -> void: broke.append(s)
	Salvage.limb_broken.connect(on_break)
	Salvage.hit_limb(0.3, false, &"legs")
	_check("a hit taking 30%% HP wears the leg to %.2f (1 - 0.3 x %.1f)" % [Salvage.integrity[&"legs"], Salvage.LIMB_SHARE],
		_near(Salvage.integrity[&"legs"], 1.0 - 0.3 * Salvage.LIMB_SHARE))
	_check("a damaged (not broken) leg costs nothing", _near(Upgrades.move_mult(), speed))
	Salvage.hit_limb(1.0, false, &"legs")
	_check("LEGS BROKEN: the signal fires once", broke == [&"legs"])
	_check("LEGS BROKEN: move speed x0.75", _near(Upgrades.move_mult() / speed, 0.75))
	Salvage.hit_limb(1.0, false, &"legs")
	_check("hitting a broken leg doesn't break it again", broke.size() == 1)
	Salvage.hit_limb(1.0, false, &"arms")
	_check("ARMS BROKEN: attack speed x0.65", _near(mech._weapon_rate() / rate, 0.65))
	_check("ARMS BROKEN: damage x0.85", _near(Upgrades.damage_mult() / dmg, 0.85))
	Salvage.hit_limb(1.0, false, &"head")
	_check("HEAD BROKEN: no crits", Upgrades.crit_chance() <= 0.0)
	_check("HEAD BROKEN: damage x0.85 x0.9", _near(Upgrades.damage_mult() / dmg, 0.85 * 0.9))
	Salvage.hit_limb(1.0, false, &"backpack")
	_check("BACKPACK BROKEN: boost cooldown x1.6", _near(Upgrades.boost_cd_mult() / cd, 1.6))
	Salvage.limb_broken.disconnect(on_break)
	# From behind: about half the hits find the backpack.
	var back := 0
	for i in 400:
		if Salvage._pick_limb(true) == &"backpack":
			back += 1
	_check("hits from behind find the backpack more often (%d / 400)" % back, back > 220)
	# The repair kit patches limbs, even at full HP.
	Salvage.reset()
	Salvage.integrity[&"arms"] = 0.0
	mech.hp = mech.max_hp
	mech.repair_charges = 1
	mech._repair_cd = 0.0
	mech._self_repair()
	_check("a repair kit at full HP still works on a broken limb", mech.repair_charges == 0)
	_check("the kit patched the arm up by %.0f%%" % (Salvage.KIT_REPAIR * 100.0), _near(Salvage.integrity[&"arms"], Salvage.KIT_REPAIR))
	# A real hit on the mech wears some limb down.
	Salvage.reset()
	mech._invuln = 0.0
	mech.shield_charges = 0
	mech.take_damage(20.0, mech.global_position + Vector2(100, 0))
	var total := 0.0
	for s in Salvage.SLOTS:
		total += Salvage.integrity[s]
	_check("a 20 damage hit on the mech wore a limb down", total < 4.0)
	mech.hp = mech.max_hp
	Salvage.reset()


func _spawn(pos: Vector2) -> Enemy:
	var e: Enemy = CHASER.instantiate()
	e.move_speed = 0.0
	e.contact_damage = 0.0
	e.set("lunge_range", 0.0)
	e.position = pos
	get_tree().current_scene.add_child(e)
	return e


func _pieces() -> Array[Node]:
	return get_tree().get_nodes_in_group("salvage_pieces")


func _clear_pieces() -> void:
	for p in _pieces():
		p.remove_from_group("salvage_pieces")
		p.queue_free()


func _drop_checks() -> void:
	Game.scrap_enabled = true
	var far := mech.global_position + Vector2(600, 0)
	# Elite + the player's (melee) kill: always drops the robot's own piece.
	var e := _spawn(far)
	await _frames(2)
	e.make_elite()
	mech.weapon = &"sword"
	Combat.report_damage(1.0, mech, e)
	e.die()
	await _frames(3)
	var ps := _pieces()
	_check("an elite the pilot destroyed always drops a piece", ps.size() == 1)
	if ps.size() == 1:
		_check("it is the robot's own piece (Chaser Servo Legs)", ps[0].piece.get("name") == "Chaser Servo Legs")
		_check("a melee kill tears it off", ps[0].torn)
	_clear_pieces()
	# A robot that wasn't the pilot's kill: nothing.
	e = _spawn(far)
	await _frames(2)
	e.make_elite()
	e.die()
	await _frames(3)
	_check("a robot the pilot didn't destroy drops nothing", _pieces().is_empty())
	# Swarm robots never drop.
	e = _spawn(far)
	await _frames(2)
	e.make_elite()
	e.swarm = true
	Combat.report_damage(1.0, mech, e)
	e.die()
	await _frames(3)
	_check("swarm robots never drop a piece", _pieces().is_empty())
	# Odds: melee kills tear far more pieces off than gun kills.
	var melee_n := 0
	var gun_n := 0
	for i in 300:
		melee_n += 1 if randf() < Salvage.MELEE_CHANCE else 0
		gun_n += 1 if randf() < Salvage.GUN_CHANCE else 0
	_check("melee kills drop pieces far more often than gun kills (%d vs %d of 300)" % [melee_n, gun_n], melee_n > gun_n * 2)
	# No drops in the ranges / tutorial (scrap off).
	Game.scrap_enabled = false
	e = _spawn(far)
	await _frames(2)
	e.make_elite()
	Combat.report_damage(1.0, mech, e)
	e.die()
	await _frames(3)
	_check("no drops outside real runs", _pieces().is_empty())
	Game.scrap_enabled = true
	# A crowded map stops dropping at MAX_ON_MAP (a boss still gets its piece).
	for i in Salvage.MAX_ON_MAP + 2:
		Salvage.drop(&"Chaser", far + Vector2(i * 30, 300))
		await _frames(1)
	await _frames(2)
	_check("at most %d pieces lie on a map" % Salvage.MAX_ON_MAP, _pieces().size() == Salvage.MAX_ON_MAP)
	Salvage.drop(&"WardenBoss", far, false, true)
	await _frames(2)
	_check("a boss's piece drops even on a crowded map", _pieces().size() == Salvage.MAX_ON_MAP + 1)
	_clear_pieces()
	_check("an unknown robot drops a generic piece", Salvage.GENERIC.values().has(Salvage.piece_for(&"NotARobot")))
	mech.weapon = Game.weapon


func _collect_checks() -> void:
	Salvage.reset()
	var hud: Node = null
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.has_method("_on_salvaged"):
			hud = n
	Salvage.integrity[&"legs"] = 0.0
	var speed := Upgrades.move_mult() / 0.75  # what it is with the leg whole
	var got: Array[Dictionary] = []
	var on_got := func(p: Dictionary) -> void: got.append(p)
	Salvage.salvaged.connect(on_got)
	var p := Salvage.drop(&"Chaser", mech.global_position + Vector2(20, 0))
	await _frames(30)
	_check("walking into a piece picks it up", not is_instance_valid(p) and got.size() == 1)
	_check("it is bolted on", Salvage.bolted.size() == 1 and Salvage.count(&"legs") == 1)
	_check("it fully repaired the broken leg", Salvage.integrity[&"legs"] == 1.0 and got.size() == 1 and got[0]["repaired"])
	_check("its +5% move speed reaches the mech", _near(Upgrades.move_mult() / speed, 1.05))
	_check("the HUD feed shows it", hud != null and hud._salvage_feed.any(
		func(f: Dictionary) -> bool: return String(f["text"]).contains("BOLTED ON  CHASER SERVO LEGS")))
	# A piece left lying around comes to the mech by itself.
	p = Salvage.drop(&"Hornet", mech.global_position + Vector2(400, 0))
	await _frames(int((Salvage.PIECE.WAIT + 1.5) * 60.0))
	_check("a piece left lying comes to the mech after %.1f s" % Salvage.PIECE.WAIT, not is_instance_valid(p) and Salvage.count(&"backpack") == 1)
	_check("HORNET WING JETS: boost cooldown -7%", _near(Salvage.mult("boost_cd"), 0.93))
	Salvage.collect(Salvage.PIECES[&"Widow"])
	_check("WIDOW OPTICS: +4 crit points", _near(Salvage.add("crit"), 0.04))
	# A full slot pays scrap instead.
	Salvage.collect(Salvage.PIECES[&"Chaser"])
	Salvage.collect(Salvage.PIECES[&"Chaser"])
	var before := Game.run_scrap
	Salvage.collect(Salvage.PIECES[&"Chaser"])
	_check("a full slot (%d pieces) bolts nothing more" % Salvage.MAX_PER_SLOT, Salvage.count(&"legs") == Salvage.MAX_PER_SLOT)
	_check("... and pays scrap instead", Game.run_scrap > before and not got[-1]["bolted"])
	_check("the feed says the slot was full", String(hud._salvage_feed[-1]["text"]).contains("FULL") if hud else false)
	_check("the mech wears a plate per bolted piece (limb_fx)", mech.find_children("*", "Node2D", false, false).any(
		func(n: Node) -> bool: return n.get_script() == Mech.LIMB_FX))
	Salvage.salvaged.disconnect(on_got)


func _reset_checks() -> void:
	Salvage.integrity[&"arms"] = 0.0
	Upgrades.reset()
	_check("a new run clears bolted pieces and repairs every limb", Salvage.bolted.is_empty() and not Salvage.any_damaged())
