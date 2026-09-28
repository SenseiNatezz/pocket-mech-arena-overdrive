extends Node
## Level-up / upgrade / weapon test. Run:
##   godot --path . res://environment/test_range.tscn -- --upgrade-test --temp-save
## Checks the XP curve, XP shards, the level-up menu, every upgrade's effect, the four primary weapons,
## weapon unlocks and the run checkpoint. Prints PASS/FAIL per check; exit code 0 = all passed.

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


## A stationary, harmless enemy to shoot at.
func _target(pos: Vector2, hp := 5000.0) -> Enemy:
	var e: Enemy = CHASER.instantiate()
	e.max_hp = hp
	e.move_speed = 0.0
	e.contact_damage = 0.0
	e.set("lunge_range", 0.0)
	e.position = pos
	get_tree().current_scene.add_child(e)
	return e


func _clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy:
			e.dead = true
			e.queue_free()
	for b in get_tree().get_nodes_in_group("xp_orbs"):
		b.queue_free()
	await _frames(2)


func _player_bullets() -> Array[Bullet]:
	var out: Array[Bullet] = []
	var pool := get_tree().current_scene.get_node_or_null("Combat")
	if pool:
		for b in pool.get_children():
			if b is Bullet and b.active and b.player_owned:
				out.append(b)
	return out


func _kill_bullets() -> void:
	for b in _player_bullets():
		b.deactivate()


func _set_level(id: StringName, lvl: int) -> void:
	Upgrades.stacks[id] = lvl


func _run() -> void:
	await _frames(5)
	mech = get_tree().get_first_node_in_group("player") as Mech
	hud = get_tree().current_scene.get_node("HUD")
	get_tree().current_scene.get_node("Dummies").queue_free()
	mech.global_position = Vector2(-200, -560)
	mech._invuln = 1e9
	Controls.touch_aim = Vector2.RIGHT
	Upgrades.reset()
	await _frames(5)

	# --- XP curve: quick levels 1-4, then level^2 (x1.6 from level 5, x2.2 from 10, x3 from 15) -----------
	var curve := [Upgrades.xp_to_next(1), Upgrades.xp_to_next(2), Upgrades.xp_to_next(3), Upgrades.xp_to_next(4),
		Upgrades.xp_to_next(5), Upgrades.xp_to_next(8)]
	_check("XP curve 4/6/8, 16, then x1.6: 40 at L5, 102 at L8 (%s)" % str(curve), curve == [4.0, 6.0, 8.0, 16.0, 40.0, 102.0])

	# --- XP shards --------------------------------------------------------------------------------
	var e := _target(mech.global_position + Vector2(110, 0), 60.0)
	await _frames(3)
	e.die()
	await _frames(3)
	_check("killed enemy drops XP shards", get_tree().get_nodes_in_group("xp_orbs").size() > 0)
	_check("shards fly to the mech and give XP", await _wait_until(func() -> bool: return Upgrades.xp > 0.0, 3.0))

	# --- level-up menu ----------------------------------------------------------------------------
	var menu: CanvasLayer = hud.level_menu
	Upgrades.add_xp(Upgrades.xp_to_next() - Upgrades.xp + 0.01)
	await _frames(1)
	_check("level-up opens the menu + pauses", menu.visible and get_tree().paused and Upgrades.choosing)
	_check("menu offers 3 different upgrades", _distinct_cards(menu) == 3)
	_check("pause menu can't open over the level-up menu", not hud._pause_panel.visible)
	await _wait_until(func() -> bool: return not Upgrades.choosing, 3.0)
	_check("pick applied + game resumes (level %d, %d upgrade)" % [Upgrades.level, Upgrades.stacks.size()],
		Upgrades.level == 2 and Upgrades.stacks.size() == 1 and not get_tree().paused and not menu.visible)
	Upgrades.add_xp(Upgrades.xp_to_next(2) + Upgrades.xp_to_next(3) - Upgrades.xp + 0.01)
	_check("double level-up queues 2 picks", Upgrades.pending == 2)
	await _wait_until(func() -> bool: return not Upgrades.choosing and Upgrades.pending == 0, 5.0)
	_check("both picks made (level %d)" % Upgrades.level, Upgrades.level == 4 and not get_tree().paused)
	# Nothing left to offer -> Field Repair fills the cards.
	for id: StringName in Upgrades.CATALOG:
		_set_level(id, Upgrades.CATALOG[id]["max"])
	_check("maxed out -> Field Repair offered", Upgrades.roll_choices(3).has(Upgrades.FIELD_REPAIR))
	Upgrades.reset()
	await _clear_enemies()

	# --- Triple Shot / bullet traits ----------------------------------------------------------------
	mech.weapon = &"blaster"
	_kill_bullets()
	mech._fire_primary(1.0)
	var single := _player_bullets().size()
	_kill_bullets()
	_set_level(&"multishot", 1)
	mech._fire_primary(1.0)
	var triple := _player_bullets().size()
	_kill_bullets()
	_set_level(&"multishot", 2)
	mech._fire_primary(1.0)
	var five := _player_bullets().size()
	_kill_bullets()
	_check("triple shot: 1 -> 3 -> 5 bolts (%d/%d/%d)" % [single, triple, five], single == 1 and triple == 3 and five == 5)
	Upgrades.reset()
	_set_level(&"pierce", 2)
	_set_level(&"target_lock", 2)
	_set_level(&"explosive", 3)
	mech._fire_primary(1.0)
	var b: Bullet = _player_bullets()[0]
	_check("bolts carry pierce / homing / explosive", b.pierce == 2 and b.homing > 0.0 and is_equal_approx(b.explosive, 0.35))
	_kill_bullets()
	Upgrades.reset()

	# Pierce: one bolt through two enemies in a row.
	var t1 := _target(mech.global_position + Vector2(260, 0))
	var t2 := _target(mech.global_position + Vector2(460, 0))
	await _frames(35)
	_set_level(&"pierce", 1)
	Combat.fire(mech.global_position + Vector2(40, 0), Vector2.RIGHT * 1100.0, 10.0, true, mech).pierce = 1
	await _frames(40)
	_check("piercing bolt hits both enemies", t1.hp < t1.max_hp and t2.hp < t2.max_hp)
	Upgrades.reset()
	await _clear_enemies()

	# Homing: a bolt fired 25 degrees off still finds its target.
	var off_target := _target(mech.global_position + Vector2(420, 0).rotated(0.44))
	await _frames(35)
	var hb := Combat.fire(mech.global_position, Vector2.RIGHT * 800.0, 10.0, true, mech)
	hb.homing = 6.0
	hb.set("_life", 2.0)
	await _frames(60)
	_check("homing bolt curves into an off-axis enemy", off_target.hp < off_target.max_hp)
	await _clear_enemies()

	# Target Lock: aim snaps onto an enemy near the aim line.
	var locked := _target(mech.global_position + Vector2(500, 0).rotated(deg_to_rad(9.0)))
	await _frames(35)
	var before := mech._shot_dir()
	_set_level(&"target_lock", 1)
	var snapped := mech._shot_dir()
	var want := (locked.global_position - mech.muzzle.global_position).normalized()
	_check("target lock snaps aim onto the enemy", snapped.angle_to(want) < 0.02 and absf(before.angle_to(want)) > 0.05)
	Upgrades.reset()
	await _clear_enemies()

	# Explosive: a small blast hurts enemies around the hit.
	var near := _target(mech.global_position + Vector2(300, 40))
	await _frames(35)
	Combat.small_blast(mech.global_position + Vector2(300, 0), 75.0, 30.0, mech)
	_check("explosive blast damages nearby enemies", near.hp < near.max_hp)
	await _clear_enemies()

	# --- Defense Shield ---------------------------------------------------------------------------
	Upgrades.apply(&"shield")
	await _frames(2)
	_check("shield upgrade grants a charge", mech.shield_charges == 1)
	mech._invuln = 0.0
	var hp0 := mech.hp
	mech.take_damage(20.0, mech.global_position + Vector2(50, 0))
	_check("shield blocks a hit", mech.hp == hp0 and mech.shield_charges == 0)
	mech._invuln = 0.0
	mech.take_damage(20.0, mech.global_position + Vector2(50, 0))
	_check("next hit (no charge) does damage", mech.hp < hp0)
	mech._shield_t = 0.05
	await _frames(10)
	_check("shield recharges", mech.shield_charges == 1)
	mech._invuln = 1e9
	mech.hp = mech.max_hp

	# --- Armor Plating / Field Repair ---------------------------------------------------------------
	# (The random picks earlier may already have taken Armor; start this check from a clean mech.)
	Upgrades.stacks.erase(&"armor")
	mech.max_hp = mech._base_max_hp
	var base_max := mech.max_hp
	Upgrades.apply(&"armor")
	await _frames(1)
	_check("armor plating: +25 max HP (%.0f -> %.0f)" % [base_max, mech.max_hp], is_equal_approx(mech.max_hp, base_max + 25.0))
	mech.hp = 10.0
	mech.repair_charges = 0
	Upgrades.apply(Upgrades.FIELD_REPAIR)
	await _frames(1)
	_check("field repair heals + restocks a kit", mech.hp >= 50.0 and mech.repair_charges == 1)
	mech.hp = mech.max_hp

	# --- Homing Missiles were removed; max level 20 + steeper XP after level 5 -----------------------
	_check("homing missiles are gone", not Upgrades.CATALOG.has(&"missiles"))
	_check("XP curve: 16 at L4, x1.6 at L5 (40), x2.2 at L10 (220), x3 at L15 (675)",
		Upgrades.xp_to_next(4) == 16.0 and Upgrades.xp_to_next(5) == 40.0 and Upgrades.xp_to_next(10) == 220.0
		and Upgrades.xp_to_next(15) == 675.0)
	_check("no more levels past MAX_LEVEL 20", Upgrades.MAX_LEVEL == 20 and Upgrades.xp_to_next(20) == INF)
	var lv_before := Upgrades.level
	var pending_before := Upgrades.pending
	Upgrades.level = Upgrades.MAX_LEVEL
	Upgrades.add_xp(100000.0)
	_check("XP does nothing at max level", Upgrades.level == Upgrades.MAX_LEVEL and Upgrades.pending == pending_before
		and Upgrades.xp_fraction() == 1.0)
	Upgrades.level = lv_before
	Upgrades.xp = 0.0

	# --- Orbit Blades -------------------------------------------------------------------------------
	var blade_target := _target(mech.global_position + Vector2(0, 105))
	await _frames(35)
	Upgrades.apply(&"blades")
	_check("orbit blades slice nearby enemies", await _wait_until(func() -> bool: return blade_target.hp < blade_target.max_hp, 2.0))
	Upgrades.stacks.erase(&"blades")
	await _clear_enemies()

	# --- Salvage Repair / Thrusters -----------------------------------------------------------------
	Upgrades.apply(&"salvage")
	mech.hp = 50.0
	var victim := _target(mech.global_position + Vector2(600, 300), 10.0)
	await _frames(3)
	victim.die()
	await _frames(2)
	_check("salvage repair heals on kill (%.0f HP)" % mech.hp, is_equal_approx(mech.hp, 52.0))
	mech.hp = mech.max_hp
	Upgrades.reset()
	Upgrades.apply(&"thrusters")
	Controls.touch_move = Vector2.DOWN
	await _frames(12)
	_check("thrusters: +10%% speed (%.0f px/s)" % mech.velocity.length(), mech.velocity.length() > mech.move_speed * 1.08)
	Controls.touch_move = Vector2.ZERO
	await _frames(20)
	mech.global_position = Vector2(-200, -560)
	Upgrades.reset()
	await _clear_enemies()
	await _frames(10)

	# --- Sniper Beam: pierces every enemy on the line -----------------------------------------------
	mech.weapon = &"sniper"
	var line: Array[Enemy] = [_target(mech.global_position + Vector2(300, 0)), _target(mech.global_position + Vector2(550, 0)),
		_target(mech.global_position + Vector2(800, 0))]
	var off_line := _target(mech.global_position + Vector2(500, 250))
	await _frames(35)
	mech.aim_dir = Vector2.RIGHT
	mech._fire_primary(1.0)
	await _frames(1)
	var all_hit := true
	for t in line:
		all_hit = all_hit and is_equal_approx(t.hp, t.max_hp - Mech.SNIPER_DAMAGE)
	_check("sniper beam hits all 3 enemies in a line", all_hit)
	_check("sniper beam misses enemies off the line", off_line.hp == off_line.max_hp)
	_set_level(&"multishot", 1)
	var traces_before := _count_script("sniper_trace.gd")
	mech._fire_primary(1.0)
	_check("sniper + triple shot = 3 beams", _count_script("sniper_trace.gd") - traces_before == 3)
	Upgrades.reset()
	await _clear_enemies()

	# --- Beam Sword: arc hits in front, parries bullets ------------------------------------------------
	mech.weapon = &"sword"
	mech._knockback = Vector2.ZERO
	mech.velocity = Vector2.ZERO
	await _frames(5)
	var front :=_target(mech.global_position + Vector2(110, 0))
	var behind := _target(mech.global_position + Vector2(-140, 0))
	await _frames(35)
	var enemy_bullet := Combat.fire(mech.global_position + Vector2(90, 30), Vector2.LEFT * 50.0, 5.0, false, null)
	mech.aim_dir = Vector2.RIGHT
	mech._fire_primary(1.0)
	await _frames(1)
	_check("sword slash hits the enemy in front (%.0f -> %.0f, %.0f px away)" % [front.max_hp, front.hp,
		front.global_position.distance_to(mech.global_position)], is_equal_approx(front.hp, front.max_hp - MeleeKit.WEAPONS[&"sword"]["damage"]))
	_check("sword slash misses the enemy behind", behind.hp == behind.max_hp)
	_check("sword slash cuts an enemy bullet", not enemy_bullet.active)
	_kill_bullets()
	_set_level(&"multishot", 1)
	mech._fire_primary(1.0)
	_check("sword + triple shot launches 3 energy waves", _player_bullets().size() == 3)
	_kill_bullets()
	Upgrades.reset()
	await _clear_enemies()

	# --- Gatling vs blaster fire rate ---------------------------------------------------------------
	var shots := {}
	for w: StringName in [&"blaster", &"gatling"]:
		mech.weapon = w
		_kill_bullets()
		var fired := 0
		var seen := {}
		Input.action_press(&"fire_primary")
		for i in 60:
			await get_tree().physics_frame
			for x in _player_bullets():
				if not seen.has(x):
					seen[x] = true
					fired += 1
		Input.action_release(&"fire_primary")
		shots[w] = fired
		await _frames(10)
	_check("gatling fires much faster than the blaster (%d vs %d shots/s)" % [shots[&"gatling"], shots[&"blaster"]],
		shots[&"gatling"] >= shots[&"blaster"] * 1.5)
	mech.weapon = &"blaster"

	# --- Unlocks + equip ------------------------------------------------------------------------------
	Game.cleared.clear()
	Game.unlocked.assign([&"blaster"])
	Game.endless_best = 0
	Game.waves_beaten = 0
	_check("nothing unlocked on a fresh save", Game.check_unlocks().is_empty())
	for i in 3:
		Game.record_wave_cleared()
	_check("beating 3 waves unlocks the Beam Saber", Game.is_unlocked(&"sword") and not Game.is_unlocked(&"sniper"))
	Game.waves_beaten = 9
	_check("reaching 10 waves unlocks every tier up to the Beam Katana",
		Game.record_wave_cleared() == ["Sniper Beam", "Dual Beam Sabers", "Beam Katana"])
	_check("locked weapons show their progress", Game.unlock_text(&"greatsword") == "Beat 30 waves (10 / 30)")
	Game.equip(&"gatling")
	_check("can't equip a locked weapon", Game.weapon != &"gatling")
	Game.equip(&"sword")
	_check("equip an unlocked weapon", Game.weapon == &"sword")
	Game.equip(&"blaster")

	# --- Run checkpoint (retry keeps the upgrades you started the arena with) --------------------------
	Upgrades.reset()
	_set_level(&"power", 2)
	Upgrades.level = 5
	Upgrades.save_checkpoint()
	_set_level(&"rapid", 3)
	Upgrades.level = 7
	Upgrades.restore_checkpoint()
	_check("restart restores the arena-start checkpoint", Upgrades.level == 5 and Upgrades.level_of(&"power") == 2
		and Upgrades.level_of(&"rapid") == 0)

	# --- Tank armor: soaks damage first at 1/tier, then HP ------------------------------------------
	var tanks := {}
	for tier in [2, 3]:
		var tank: Enemy = load("res://enemies/heavy_tank.tscn").instantiate()
		tank.armor_tier = tier
		tank.position = mech.global_position + Vector2(400, -200 + tier * 150)
		get_tree().current_scene.add_child(tank)
		tanks[tier] = tank
	await _frames(3)
	var tk2: Enemy = tanks[2]
	var tk3: Enemy = tanks[3]
	_check("tanks spawn with armor = max HP (%.0f / %.0f)" % [tk2.max_armor, tk2.max_hp],
		tk2.armor_tier == 2 and tk3.armor_tier == 3 and is_equal_approx(tk2.armor, tk2.max_hp))
	tk2.take_damage(60.0, tk2.global_position, mech)
	tk3.take_damage(60.0, tk3.global_position, mech)
	_check("armor takes damage / tier, HP untouched (2x: -%.0f, 3x: -%.0f)" % [tk2.max_armor - tk2.armor, tk3.max_armor - tk3.armor],
		is_equal_approx(tk2.max_armor - tk2.armor, 30.0) and is_equal_approx(tk3.max_armor - tk3.armor, 20.0)
		and tk2.hp == tk2.max_hp and tk3.hp == tk3.max_hp)
	tk2.armor = 5.0
	tk2.take_damage(30.0, tk2.global_position, mech)
	_check("breaking armor carries the rest into HP (hp %.0f)" % tk2.hp, tk2.armor <= 0.0 and is_equal_approx(tk2.hp, tk2.max_hp - 20.0))
	_check("triple-armor tanks are tinted, double aren't", tk3.armor_tint() != Color.WHITE and tk2.armor_tint() == Color.WHITE)
	_check("armor adds XP value", Upgrades.xp_value(tk3) > roundi(tk3.max_hp / 45.0))
	for t in tanks.values():
		t.queue_free()

	print("UPGRADE TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _distinct_cards(menu: Node) -> int:
	var ids := {}
	for c in menu._cards:
		ids[c.id] = true
	return ids.size()


func _count_script(file: String) -> int:
	var n := 0
	for node in get_tree().current_scene.find_children("*", "", true, false):
		var s: Script = node.get_script()
		if s and s.resource_path.ends_with(file) and not node.is_queued_for_deletion():
			n += 1
	return n
