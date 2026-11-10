extends Node
## Walking-legs capture in the Weapon Range (attach with --attach):
##   godot --path . --resolution 1280x720 -- --gun-range --temp-save --attach=res://tools/walk_shots.gd
##       --walk-out=DIR [--walk-zoom=2.0] [--walk-weapon=blaster]
## Drives the mech through a fixed routine (walk forward, strafe, walk backwards, turn on the spot, dash,
## circle while aiming at one point) and saves a 360 px crop around it every 2nd physics frame as
## DIR/w_<n>.png, plus `WALK STEP <name> <first crop>` lines. Also checks the legs layer exists and reacts
## (prints WALK SHOTS OK / FAILED).

const CROP := 360
## [name, physics frames, move, aim, dash at frame (-1 = none)]; steps named fire* hold the trigger.
const STEPS := [
	["stand", 30, Vector2.ZERO, Vector2.UP, -1],
	["forward", 70, Vector2.UP, Vector2.UP, -1],
	["strafe", 70, Vector2.RIGHT, Vector2.UP, -1],
	["backward", 70, Vector2.DOWN, Vector2.UP, -1],
	["turn", 80, Vector2.ZERO, Vector2.DOWN, -1],
	["dash", 60, Vector2.LEFT, Vector2.DOWN, 20],
	["diagonal", 70, Vector2(1, -1), Vector2.RIGHT, -1],
	["fire_stand", 50, Vector2.ZERO, Vector2.RIGHT, -1],
	["fire_walk", 80, Vector2.UP, Vector2.RIGHT, -1],
	["fire_sweep", 90, Vector2.LEFT, Vector2.ZERO, -1],
]
## --walk-demo: how it plays for real (the aim is NOT pinned). `free_*` = nobody to shoot, so the upper body
## turns with the walk; `circle` = walking a ring round a target robot while the auto-aim keeps the upper
## body (and the gun) turned on it, firing.
const DEMO := [
	["free_right", 45, Vector2.RIGHT, Vector2.ZERO, -1],
	["free_down", 45, Vector2.DOWN, Vector2.ZERO, -1],
	["free_left", 45, Vector2.LEFT, Vector2.ZERO, -1],
	["free_up", 45, Vector2.UP, Vector2.ZERO, -1],
	["circle", 240, Vector2.RIGHT, Vector2.ZERO, -1],
	["circle_dash", 150, Vector2.RIGHT, Vector2.ZERO, 70],
]
const CIRCLE_FRAMES := 170.0

var _out := "user://walk"
var _zoom := 2.0
var _weapon := &"blaster"
var _failed := 0


func _ready() -> void:
	if get_parent().name != "GunRange":
		queue_free()
		return
	Controls.ignore_real_input = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--walk-out="):
			_out = a.trim_prefix("--walk-out=")
		elif a.begins_with("--walk-zoom="):
			_zoom = float(a.trim_prefix("--walk-zoom="))
		elif a.begins_with("--walk-weapon="):
			_weapon = StringName(a.trim_prefix("--walk-weapon="))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failed += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", what])


func _run() -> void:
	await get_tree().physics_frame
	var arena := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	Game.dynamic_camera = false
	mech.get_node("Camera2D").zoom_override = _zoom
	await get_tree().create_timer(0.6).timeout
	arena.clear_enemies()
	if arena.get("panel"):
		arena.panel.visible = false
	arena.select_weapon(_weapon, false)
	var walks := mech.legs != null
	print("WALK ART: ", Game.chassis_walk_art(mech._chassis_id), " legs=", walks)
	var home := mech.global_position
	var n := 0
	var seen := {}
	var demo := OS.get_cmdline_user_args().has("--walk-demo")
	var dummy: Enemy
	if demo:
		Controls.force_auto_aim = true
	for step: Array in (DEMO if demo else STEPS):
		if String(step[0]).begins_with("circle") and dummy == null:
			# The ring the mech walks has this radius; the target robot stands in the middle of it.
			var r := mech.move_speed * Upgrades.move_mult() * CIRCLE_FRAMES / 60.0 / TAU
			dummy = load("res://enemies/chaser.tscn").instantiate()
			dummy.position = home + Vector2(0, r)
			dummy.max_hp = 1e7
			arena.add_child(dummy)
			dummy.move_speed = 0.0
		print("WALK STEP %s %d" % [step[0], n])
		mech.global_position = home  # (each step starts from the same spot, so it stays in view)
		mech.velocity = Vector2.ZERO
		(mech.get_node("Camera2D") as Camera2D).reset_smoothing()
		for f in int(step[1]):
			mech._invuln = 1e9
			Controls.touch_move = (step[2] as Vector2).normalized()
			Controls.touch_aim = step[3]
			if step[0] == "fire_sweep":  # the aim sweeps half a turn while walking
				Controls.touch_aim = Vector2.RIGHT.rotated(-PI * f / float(step[1]))
			Controls.touch_fire = String(step[0]).begins_with("fire") or String(step[0]).begins_with("circle")
			if String(step[0]).begins_with("circle"):
				Controls.touch_move = Vector2.RIGHT.rotated(TAU * f / CIRCLE_FRAMES)
			if f == int(step[4]):
				Input.action_press(&"boost")
			elif f == int(step[4]) + 1:
				Input.action_release(&"boost")
			await get_tree().physics_frame
			if walks:
				seen["%s:%s" % [step[0], mech.legs.animation]] = true
				if mech.sprite.animation == &"walk" and mech.sprite.frame == mech.legs.frame:
					seen["%s:body_walk" % step[0]] = true
				if mech.sprite.animation in [&"boost", &"bank_left", &"bank_right"]:
					seen["flight"] = true
				if step[0] == "backward" and f == 60:
					_check(mech._legs_back, "walking away from the aim steps backwards")
				if step[0] == "forward" and f == 60:
					_check(absf(angle_difference(mech.legs.rotation, 0.0)) < 0.1, "legs face the move")
				if step[0] == "strafe" and f == 60:
					_check(absf(angle_difference(mech.legs.rotation, PI / 2)) < 0.1 and absf(angle_difference(mech.body.rotation, 0.0)) < 0.2,
						"strafing: legs along the move, body on the aim")
			if f % 2 == 0:
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				var at := Vector2i(mech.get_global_transform_with_canvas().origin * Vector2(img.get_size()) / get_viewport().get_visible_rect().size)
				var r := Rect2i(at - Vector2i(CROP, CROP) / 2, Vector2i(CROP, CROP)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
				img.get_region(r).save_png("%s/w_%03d.png" % [_out, n])
				n += 1
	Controls.touch_move = Vector2.ZERO
	Controls.touch_fire = false
	if walks and not demo:
		_check(seen.has("stand:stand"), "stands on its legs")
		_check(seen.has("forward:walk"), "walk cycle plays while moving")
		_check(seen.has("turn:walk"), "legs shuffle round under a turned body")
		_check(seen.has("dash:slide"), "dash uses the slide pose")
		_check(seen.has("forward:body_walk"), "the upper body walks in step with the legs")
		_check(Sfx._from_file.get(&"step", false), "the footstep sound is loaded from its recording")
		_check(not seen.has("flight"), "body never plays a flight pose")
	print("WALK SHOTS %s (%d failed, %d crops)" % ["OK" if _failed == 0 else "FAILED", _failed, n])
	get_tree().quit(1 if _failed > 0 else 0)
