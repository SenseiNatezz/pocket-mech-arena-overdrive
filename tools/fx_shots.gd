extends Node
## Weapon / FX close-up captures in the Weapon Range (attach with --attach):
##   godot --path . --resolution 1280x720 -- --gun-range --temp-save --no-hitstop --attach=res://tools/fx_shots.gd
##       --fx=SCENE --fx-out=DIR [--fx-frames=10,14,18] [--fx-zoom=2.0]
## Scenes: drone (3 Bit Drones vs robots), rifle / gatling / pistols (the weapon firing at a line of
## robots), death (a Magma Crawler, a Scrap Hound and a Heavy Tank destroyed in front of the mech),
## lava (Magma Crawler lava trail + burst pool), boss (a Warden landing: camera focus + card).
## Saves DIR/<scene>_<frame>.png at each listed physics frame (counted from the start of the scene),
## then quits. The mech is invulnerable and stands still at the landing circle aiming right.

var arena: Node
var mech: Mech
var _frames: Array[int] = [20, 24, 28, 32, 40, 60]
var _out := "user://fx"
var _scene := "rifle"
var _zoom := 0.0


func _ready() -> void:
	# (--attach also fires on the main menu the run starts from; only the Weapon Range copy runs)
	if get_parent().name != "GunRange":
		queue_free()
		return
	Controls.ignore_real_input = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fx="):
			_scene = a.trim_prefix("--fx=")
		elif a.begins_with("--fx-out="):
			_out = a.trim_prefix("--fx-out=")
		elif a.begins_with("--fx-frames="):
			_frames.clear()
			for s in a.trim_prefix("--fx-frames=").split(","):
				_frames.append(int(s))
		elif a.begins_with("--fx-zoom="):
			_zoom = float(a.trim_prefix("--fx-zoom="))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _spawn(kind: String, offset: Vector2, hp := 4000.0) -> Enemy:
	var e: Enemy = load("res://enemies/%s.tscn" % kind).instantiate()
	e.position = mech.global_position + offset
	e.max_hp = hp
	arena.add_child(e)
	return e


func _hold() -> void:
	mech._invuln = 1e9
	mech.hp = mech.max_hp
	Controls.touch_aim = Vector2.RIGHT
	Controls.touch_move = Vector2.ZERO


func _run() -> void:
	await get_tree().physics_frame
	arena = get_tree().current_scene
	mech = get_tree().get_first_node_in_group("player") as Mech
	var cam := mech.get_node("Camera2D")
	if _zoom > 0.0:
		cam.zoom_override = _zoom
	await get_tree().create_timer(0.6).timeout
	arena.clear_enemies()
	if arena.get("panel"):
		arena.panel.visible = false
	var fire := false
	var kill_at := -1
	var kill: Array[Enemy] = []
	match _scene:
		"drone":
			Upgrades.stacks[&"drones"] = 3
			arena.select_weapon(&"blaster", false)
			for i in 3:
				_spawn("chaser", Vector2(330, -120 + i * 120)).move_speed = 0.0
		"rifle", "gatling", "pistols", "rockets":
			arena.select_weapon({"rifle": &"blaster", "gatling": &"gatling", "pistols": &"dual_pistols",
				"rockets": &"rockets"}[_scene], false)
			for i in 3:
				_spawn("heavy_tank" if i == 1 else "chaser", Vector2(300 + i * 30, -100 + i * 100)).move_speed = 0.0
			fire = true
		"death":
			arena.select_weapon(&"blaster", false)
			kill.append(_spawn("magma_crawler", Vector2(300, -130), 50.0))
			kill.append(_spawn("chaser", Vector2(330, 40), 50.0))
			kill.append(_spawn("heavy_tank", Vector2(250, 190), 50.0))
			for e in kill:
				e.move_speed = 0.0
			kill_at = 12
		"lava":
			arena.select_weapon(&"blaster", false)
			var c := _spawn("magma_crawler", Vector2(280, 0), 50.0)
			kill.append(c)
			kill_at = 50
		"boss":
			arena.spawn_boss("warden_boss")
	var last: int = _frames.max()
	for f in last + 1:
		_hold()
		if fire:
			Input.action_press(&"fire_primary")
		if f == kill_at:
			for e in kill:
				if is_instance_valid(e) and not e.dead:
					e.take_damage(1e6, e.global_position, mech)
		await get_tree().physics_frame
		if f in _frames:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%03d.png" % [_out, _scene, f])
	Input.action_release(&"fire_primary")
	print("FX SHOTS DONE: ", _scene)
	get_tree().quit()
