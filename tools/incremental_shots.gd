extends Node
## Preview captures of the incremental systems. Attach it and give it a file to save:
##   arena:  -- --arena=1 --no-intro --temp-save --attach=res://tools/incremental_shots.gd --inc-shot=C:/x/hud.png
##   menu:   -- --menu-page=7 (Hangar) or 3 (Armory) --temp-save --attach=... --inc-shot=...
##           (with --hangar=frame:7,... / --mastery=blaster:600,... / --scrap=N / --waves-beaten=N)
## Arena: a run's worth of scrap already on the HUD ticker and the weapon a kill short of a mastery level,
## then a few robots next to the mech are destroyed so scrap chips fly in, the counter pops "+N" and the
## MASTERY UP toast slides in; the shot is taken mid-flight. Hangar: scrolls to the permanent upgrades so
## the MK rows show. Saves the PNG, then quits.

const CHASER := preload("res://enemies/chaser.tscn")

var _path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--inc-shot="):
			_path = a.trim_prefix("--inc-shot=")
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	var scene := get_tree().current_scene
	if scene.name == "MainMenu":
		await _menu(scene)
	else:
		await _arena()
	await _shoot()


func _shoot() -> void:
	await RenderingServer.frame_post_draw
	if _path != "":
		get_viewport().get_texture().get_image().save_png(_path)
		print("screenshot saved: ", _path)
	get_tree().quit()


func _menu(menu: Node) -> void:
	await _wait(1.2)
	var page := menu.get("_hangar") as HangarPage
	if page and page.visible:
		var row = page._upgrade_rows[&"frame"]
		(row.buy as Button).grab_focus()
		await _wait(0.1)
		var grid_top: float = page._upgrade_grid.get_global_rect().position.y - page._scroll.get_global_rect().position.y
		page._scroll.scroll_vertical = int(page._scroll.scroll_vertical + grid_top - 46.0)
	await _wait(0.4)


func _arena() -> void:
	await _wait(0.5)
	var mech := get_tree().get_first_node_in_group("player") as Mech
	mech._invuln = 1e9
	# Mid-run: pilot level 6 (these kills won't level it up), a run's scrap already counted in.
	Upgrades.level = 6
	Upgrades.xp = 12.0
	Game.kills = 63
	Game.run_time = 154.0
	Game.earn_scrap(830.0, &"kills")
	Game.earn_scrap(150.0, &"waves")
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	if hud == null:
		hud = get_tree().get_first_node_in_group("hud")
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.get("_scrap_seen") != null:
			hud = n
	if hud:
		hud._scrap_seen = Game.run_scrap_landed()
		hud._scrap_shown = hud._scrap_seen
	# --inc-results: the ARENA CLEARED screen counting a full run's scrap up instead.
	if OS.get_cmdline_user_args().has("--inc-results") and hud:
		Game.mastery[Game.weapon] = 300
		Game.earn_scrap(1250.0, &"boss")
		Game.earn_scrap(400.0, &"arena")
		Game.earn_scrap(100.0, &"waves")
		Game.scrap = 21480
		hud._show_victory()
		await _wait(2.6)
		return
	# The equipped weapon two kills short of mastery LV 4.
	Game.mastery[Game.weapon] = Game.MASTERY_XP[3] - 2
	# (after the arena's name banner has faded)
	await _wait(1.9)
	await _burst(mech, [Vector2(150, -40), Vector2(120, 70), Vector2(-140, 50)])
	await _wait(0.75)
	await _burst(mech, [Vector2(170, -110), Vector2(-120, -90)])
	await _wait(0.25)


## Destroys fresh robots around the mech (they drop scrap chips + XP shards and count for mastery).
func _burst(mech: Mech, offsets: Array) -> void:
	var bots: Array[Enemy] = []
	for o: Vector2 in offsets:
		var e: Enemy = CHASER.instantiate()
		e.move_speed = 0.0
		e.contact_damage = 0.0
		e.set("lunge_range", 0.0)
		e.position = mech.global_position + o
		get_tree().current_scene.add_child(e)
		bots.append(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for e in bots:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(e.hp + e.armor * maxi(e.armor_tier, 1), e.global_position, mech)
