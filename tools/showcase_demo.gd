extends Node
## Preview captures (with on-screen captions):
##   -- --arena=1 --showcase=weapons   every melee weapon doing a full combo (finisher included)
##   -- --arena=1 --showcase=enemies   Blade Strikers, an Aegis Guardian and Lancers attacking
##   -- --arena=2 --showcase=boss      the level's boss through all three phases
##   -- --arena=1 --showcase=tank      Heavy Tanks: cannon aim + shells, missile pods, crushing cover
##   -- --gun-range --showcase=range   Gun Range tour: switching weapons on the bar vs spawned enemies
##   -- --gun-range --showcase=guns    Gatling Cannon (big gun in hand) and Rocket Launcher vs enemies
## Add --write-movie <dir>/frame.png --fixed-fps 30 to record. The mech is invulnerable.

var arena: Node
var mech: Mech
var _caption: Label
var _sub: Label


func _ready() -> void:
	Controls.ignore_real_input = true
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_caption = _label(40, Color.WHITE, 598)
	_sub = _label(18, Color(0.75, 0.9, 1.0), 648)
	layer.add_child(_caption)
	layer.add_child(_sub)
	_run.call_deferred()


func _label(fs: int, col: Color, y: float) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(0, y)
	l.size = Vector2(1280, 50)
	return l


func _say(title: String, sub := "") -> void:
	_caption.text = title
	_sub.text = sub


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
		mech._invuln = 1e9
		mech.hp = mech.max_hp
		if Upgrades.pending > 0 or Upgrades.choosing:
			Upgrades.pending = 0
			for m in get_tree().root.find_children("*", "", true, false):
				if m.has_method("is_open") and m.has_method("pick") and m.is_open():
					m.close()
			get_tree().paused = false


func _spawn(kind: String, pos: Vector2, hp := -1.0) -> Enemy:
	var e: Enemy = load("res://enemies/%s.tscn" % kind).instantiate()
	e.position = pos
	if hp > 0.0:
		e.max_hp = hp
	arena.world.add_child(e)
	return e


func _run() -> void:
	await get_tree().physics_frame
	arena = get_tree().current_scene
	mech = get_tree().get_first_node_in_group("player") as Mech
	mech._invuln = 1e9
	var mode := "weapons"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--showcase="):
			mode = a.trim_prefix("--showcase=")
	match mode:
		"weapons":
			await _weapons()
		"enemies":
			await _enemies()
		"boss":
			await _boss()
		"tank":
			await _tanks()
		"range":
			await _range()
		"guns":
			await _guns()
	get_tree().quit()


func _open_spot() -> Vector2:
	arena.zone.is_cleared = true
	arena.zone.monitoring = false
	return arena.map_to_world(Vector2(1250, 1520)) if arena.has_method("map_to_world") else mech.global_position


func _weapons() -> void:
	var base := _open_spot()
	mech.global_position = base
	for w in Game.WEAPONS:
		if not w.get("melee", false):
			continue
		mech.weapon = w["id"]
		_say(String(w["name"]).to_upper(), w["desc"])
		var pack: Array[Enemy] = []
		for i in 5:
			var p := base + Vector2(150 + (i % 3) * 55, -110 + i * 55)
			pack.append(_spawn(["chaser", "shooter", "chaser", "shooter", "chaser"][i], p, 260.0))
		await _frames(25)
		var rate: float = MeleeKit.rate(w["id"])
		var hold := int(60.0 * (3.0 / rate + 0.5))
		Input.action_press(&"fire_primary")
		for f in hold:
			var tgt := Combat.nearest_enemy(mech.global_position, 700.0)
			Controls.touch_aim = (tgt.global_position - mech.global_position).normalized() if tgt else Vector2.RIGHT
			await _frames(1)
		Input.action_release(&"fire_primary")
		await _frames(30)
		for e in pack:
			if is_instance_valid(e) and not e.dead:
				e.die()
		mech.global_position = base
		await _frames(10)


func _enemies() -> void:
	var base := _open_spot()
	mech.global_position = base
	_say("NEW ENEMY ROBOTS", "Blade Striker  //  Aegis Guardian  //  Lancer")
	await _frames(40)
	_say("BLADE STRIKER", "Twin energy katanas: telegraphed dash-slash, open after every strike")
	for i in 2:
		_spawn("blade_striker", base + Vector2(380, -160 + i * 320), 600.0)
	await _orbit(base, 240)
	_say("AEGIS GUARDIAN", "Cyan energy shield blocks shots from the front - flank it. Plasma-mace slam up close")
	_spawn("aegis_guardian", base + Vector2(330, 0), 900.0)
	await _orbit(base, 300)
	_say("LANCER", "Spider sniper: green laser locks on, then a piercing rail shot - move off the line!")
	for i in 2:
		_spawn("lancer", base + Vector2(520, -260 + i * 520), 600.0)
	await _orbit(base, 300)


## Circles the spot, shooting at the nearest enemy.
func _orbit(center: Vector2, frames: int) -> void:
	Input.action_press(&"fire_primary")
	for f in frames:
		var a := f / 140.0 * TAU
		var want := center + Vector2(cos(a), sin(a)) * 180.0
		Controls.touch_move = (want - mech.global_position).limit_length(60.0) / 60.0
		var tgt := Combat.nearest_enemy(mech.global_position, 900.0)
		Controls.touch_aim = (tgt.global_position - mech.global_position).normalized() if tgt else Vector2.RIGHT
		await _frames(1)
	Input.action_release(&"fire_primary")
	Controls.touch_move = Vector2.ZERO


func _boss() -> void:
	arena.zone.is_cleared = true
	arena.zone.is_running = false
	arena.zone.monitoring = false
	arena._start_boss()
	var boss: Enemy = arena.boss
	mech.global_position = boss.global_position + Vector2(0, 360)
	await _frames(20)
	for phase in 3:
		_say("%s  -  PHASE %d" % [boss.get("boss_name"), phase + 1], [
			"Phase 1", "Phase 2: new attacks unlocked", "Phase 3: everything, faster"][phase])
		var frames := 420 if phase < 2 else 480
		for f in frames:
			if not is_instance_valid(boss):
				return
			var a := f / 300.0 * TAU
			var want := boss.global_position + Vector2(cos(a), sin(a)) * 340.0
			Controls.touch_move = (want - mech.global_position).limit_length(80.0) / 80.0
			Controls.touch_aim = (boss.global_position - mech.global_position).normalized()
			await _frames(1)
		if phase < 2:
			boss.take_damage(boss.max_hp * 0.34, boss.global_position, mech)
			await _frames(60)
	Controls.touch_move = Vector2.ZERO


func _tanks() -> void:
	var base := _open_spot()
	mech.global_position = base
	_say("HEAVY TANK", "Twin cannon (aim line, then heavy shells)  //  missile pods  //  crushes cover in its way")
	for i in 2:
		_spawn("heavy_tank", base + Vector2(560, -220 + i * 440), 1400.0)
	await _frames(60)
	await _orbit(base, 700)


## Gun Range tour: a few weapons from the bar against spawned enemies.
func _range() -> void:
	# The Gun Range's weapon bar sits at the bottom: captions go up top instead.
	_caption.position.y = 150
	_sub.position.y = 198
	_say("WEAPON RANGE", "Every weapon unlocked  //  switch on the bar (1-9, 0 / wheel / Tab)  //  spawn any enemy")
	mech.global_position = Vector2(0, 150)
	await _frames(60)
	for kind in ["heavy_tank", "aegis_guardian", "blade_striker", "chaser", "chaser"]:
		arena.spawn_enemy(kind)
	await _frames(40)
	for id: StringName in [&"blaster", &"katana", &"axe", &"scythe", &"greatsword", &"sniper"]:
		arena.select_weapon(id)
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and e.max_hp < 600.0:
				e.max_hp = 600.0
				e.hp = 600.0
		Input.action_press(&"fire_primary")
		var melee := Game.is_melee(id)
		for f in 150:
			var tgt := Combat.nearest_enemy(mech.global_position, 1400.0)
			if tgt:
				var to := tgt.global_position - mech.global_position
				Controls.touch_move = to.normalized() * (1.0 if melee and to.length() > 140.0 else 0.0)
				if not melee and to.length() < 300.0:
					Controls.touch_move = -to.normalized()
				Controls.touch_aim = to.normalized()
			await _frames(1)
		Input.action_release(&"fire_primary")
		Controls.touch_move = Vector2.ZERO
		if get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return e is Enemy).size() < 3:
			arena.spawn_enemy(["heavy_tank", "blade_striker", "lancer"].pick_random())
	await _frames(30)


## Weapon Range: the Gatling Cannon, then the Rocket Launcher, against spawned enemies.
func _guns() -> void:
	_caption.position.y = 150
	_sub.position.y = 198
	mech.global_position = Vector2(-150, 150)
	for part in [[&"gatling", "GATLING CANNON", "Huge six-barrel cannon in hand  //  heavier rounds, more damage"],
			[&"rockets", "ROCKET LAUNCHER", "New unlockable  //  rockets explode on impact and splash everything nearby"]]:
		arena.clear_enemies()
		arena.select_weapon(part[0])
		_say(part[1], part[2])
		for kind in ["heavy_tank", "aegis_guardian", "chaser", "chaser", "shooter", "blade_striker"]:
			arena.spawn_enemy(kind)
		await _frames(50)
		Input.action_press(&"fire_primary")
		for f in 330:
			var tgt := Combat.nearest_enemy(mech.global_position, 1400.0)
			Controls.touch_aim = (tgt.global_position - mech.global_position).normalized() if tgt else Vector2.RIGHT
			var a := f / 200.0 * TAU
			var want := Vector2(-150, 150) + Vector2(cos(a), sin(a)) * 120.0
			Controls.touch_move = (want - mech.global_position).limit_length(60.0) / 60.0
			if get_tree().get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return e is Enemy).size() < 3:
				arena.spawn_enemy(["chaser", "heavy_tank", "blade_striker"].pick_random())
			await _frames(1)
		Input.action_release(&"fire_primary")
		Controls.touch_move = Vector2.ZERO
	await _frames(20)
