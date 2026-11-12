extends Node
## Boss OVERDRIVE + HUD hit-direction test (run it on any arena; arena 6 = VULCAN, arena 2 = RONIN):
##   godot --headless --path . -- --arena=1 --no-intro --attach=res://tools/overdrive_test.gd --temp-save
## The boss drops in and is knocked down through its phases: at 20% HP it enters OVERDRIVE (phase 4: roar,
## aura, banner, the HUD bar says OVERDRIVE), charges and fires the nova ring, and still dies normally.
## Then a hit from a known direction leaves a HUD marker pointing that way, and a big hit flashes the edge.

var _fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_fails += 1


func _frames(n: int, mech: Mech = null) -> void:
	for i in n:
		await get_tree().physics_frame
		if mech and not mech.dead:
			mech.hp = mech.max_hp
			mech._invuln = 1.0
		if Upgrades.pending > 0 or Upgrades.choosing:
			Upgrades.pending = 0
			for m in get_tree().root.find_children("*", "", true, false):
				if m.has_method("is_open") and m.has_method("pick") and m.is_open():
					m.close()
			get_tree().paused = false


## SCARAB tunnels under the sand and can't be hit while buried: wait for it to come back up first.
func _surfaced(boss: Node, mech: Mech) -> void:
	for i in 600:
		if not is_instance_valid(boss) or not boss.get("_buried"):
			return
		await _frames(1, mech)


func _enemy_bullets() -> int:
	var n := 0
	var pool := get_tree().current_scene.get_node_or_null("Combat")
	for b in (pool.get_children() if pool else []):
		if b is Bullet and b.active and not b.player_owned:
			n += 1
	return n


func _run() -> void:
	Controls.ignore_real_input = true
	await _frames(20)
	var arena := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	var hud := arena.get_node("HUD")
	await _hit_marks(hud, mech)

	arena.debug_skip_to_boss()
	await _frames(240, mech)
	var boss := arena.boss as WardenBoss
	_check("the boss is here (%s, %.0f HP)" % [boss.boss_name if boss else "-", boss.max_hp if boss else 0.0], boss != null)
	if boss == null:
		_finish()
		return
	var banners: Array[String] = []
	arena.banner.connect(func(t: String, _c: Color) -> void: banners.append(t))
	# Down through phases 2 and 3 (waiting out each roar).
	for want in [2, 3]:
		await _surfaced(boss, mech)
		boss.take_damage(boss.hp - boss.max_hp * (0.66 if want == 2 else 0.33) + 1.0, boss.global_position, mech)
		_check("phase %d at %.0f%% HP" % [want, boss.hp / boss.max_hp * 100.0], boss.phase == want)
		await _frames(110, mech)
	await _surfaced(boss, mech)
	boss.take_damage(boss.hp - boss.max_hp * 0.3, boss.global_position, mech)
	_check("still phase 3 at 30%", boss.phase == 3)
	await _surfaced(boss, mech)
	boss.take_damage(boss.hp - boss.max_hp * (WardenBoss.OVERDRIVE_AT - 0.01), boss.global_position, mech)
	_check("OVERDRIVE (phase 4) at %.0f%% HP" % (boss.hp / boss.max_hp * 100.0), boss.phase == 4)
	_check("it roars (invulnerable for a moment)", boss._roar > 1.0)
	var hp0 := boss.hp
	boss.take_damage(50.0, boss.global_position, mech)
	_check("no damage during the roar", is_equal_approx(boss.hp, hp0))
	_check("OVERDRIVE banner (%s)" % str(banners), banners.any(func(t: String) -> bool: return t.contains("OVERDRIVE")))
	_check("aura on the boss", is_instance_valid(boss._aura))
	_check("HUD bar ticks at 20%", WardenBoss.OVERDRIVE_AT < 0.33)
	# The nova: a charge (shrinking ring), then a ring of slow shots.
	var charged := false
	var fired := false
	for i in 600:
		await _frames(1, mech)
		if boss.nova_charge_k() > 0.0:
			charged = true
		if charged and boss.nova_charge_k() == 0.0 and boss._nova_t > WardenBoss.OVERDRIVE_NOVA_EVERY - 0.5:
			fired = true
			break
	_check("the nova charges", charged)
	_check("...and fires (%d enemy shots live)" % _enemy_bullets(), fired and _enemy_bullets() >= WardenBoss.OVERDRIVE_NOVA_BULLETS - WardenBoss.OVERDRIVE_NOVA_GAP - 2)
	_check("attacks still cycle in OVERDRIVE", boss._state != &"" )
	# And it still dies.
	await _frames(60, mech)
	await _surfaced(boss, mech)
	boss.take_damage(boss.hp + 10.0, boss.global_position, mech)
	await _frames(200, mech)
	_check("it dies normally", not is_instance_valid(boss) or boss.dead)
	_finish()


## A hit from the right leaves a marker pointing right; a big hit flashes that edge.
func _hit_marks(hud: Node, mech: Mech) -> void:
	mech._invuln = 0.0
	mech.shield_charges = 0
	var src := Node2D.new()
	get_tree().current_scene.add_child(src)
	src.global_position = mech.global_position + Vector2(600, 0)
	mech.take_damage(3.0, mech.global_position + Vector2(5, 0), src)
	var marks: Array = hud.get("_hit_marks")
	_check("a hit leaves a direction marker (%d)" % marks.size(), marks.size() == 1)
	if marks.size() == 1:
		var d: Vector2 = marks[0]["dir"]
		_check("it points at the shooter (%s)" % str(d.snapped(Vector2(0.01, 0.01))), d.dot(Vector2.RIGHT) > 0.95)
		_check("a small hit isn't BIG", not marks[0]["big"])
	_check("no edge flash for a small hit", float(hud.get("_edge_flash")) == 0.0)
	mech._invuln = 0.0
	src.global_position = mech.global_position + Vector2(0, -700)
	mech.take_damage(mech.max_hp * 0.25, mech.global_position, src)
	marks = hud.get("_hit_marks")
	_check("a second direction adds a marker (%d)" % marks.size(), marks.size() == 2)
	_check("a big hit flashes the screen edge", float(hud.get("_edge_flash")) > 0.9)
	_check("...on the side it came from (%s)" % str(hud.get("_edge_dir")), (hud.get("_edge_dir") as Vector2).dot(Vector2.UP) > 0.95)
	await _frames(int(60 * 1.4), mech)
	_check("markers fade out", (hud.get("_hit_marks") as Array).is_empty())
	src.queue_free()


func _finish() -> void:
	print("OVERDRIVE TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)
