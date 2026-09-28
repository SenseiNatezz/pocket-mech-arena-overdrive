extends Node
## Debug (autoload): command-line helpers for testing and preview captures. Args go after `--`:
##   --arena=N                   start directly in arena N (1-based)
##   --smoke-test                controls test (run with the test range scene)
##   --arena-test                full arena flow test (waves, hazards, pits, boss, victory)
##   --autoplay                  an AI pilots the mech (for preview captures)
##   --playtest-report           log wave/level/HP/perf every 5 s + a summary (--playtest-time=S)
##   --attach=RES_PATH           attach any tool script to the arena / range scene (one-off checks)
##   --swing-capture=DIR         (with --gun-range) contact sheets of every melee swing + finisher
##   --boss                      skip the waves and go straight to the boss
##   --goto-map=FX,FY            (painted arenas) put the mech at a fraction of the map, e.g. 0.5,0.05
##   --shot=PATH --shot-time=S   save a screenshot after S seconds, then quit
##   --touch                     force on-screen touch controls
##   --endless                   start directly in Endless mode
##   --tutorial                  start the tutorial   (--tutorial-test: play it through automatically)
##   --upgrade-test              level-up / upgrade / weapon test (run with the test range scene)
##   --endless-test              Endless mode flow test (use with --endless)
##   --weapon=ID                 try a primary weapon (blaster, sniper, sword, gatling) without saving
##   --temp-save                 use a throwaway save file (tests use this)
##   --upgrades=ID:N,ID:N        start with these upgrades, e.g. --upgrades=blades:2,shield:1
##   --level-up=S                trigger a level-up S seconds into the scene (preview the menu)
## Does nothing when no debug args are given.

var _args := OS.get_cmdline_user_args()
var _last_scene: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in _args:
		if a.begins_with("--arena="):
			Game.start_arena.call_deferred(int(a.trim_prefix("--arena=")) - 1)
		elif a == "--endless":
			Game.start_endless.call_deferred()
		elif a == "--tutorial":
			Game.to_tutorial.call_deferred()
		elif a == "--gun-range":
			Game.to_gun_range.call_deferred()
		elif a.begins_with("--shot="):
			_shot(a.trim_prefix("--shot="), _arg_float("--shot-time=", 1.5))
	set_process(_args.has("--smoke-test") or _args.has("--arena-test") or _args.has("--upgrade-test") or _args.has("--endless-test") or _args.has("--gun-range-test") or "--swing-capture=" in " ".join(_args) or _args.has("--tutorial-test") or _args.has("--difficulty-test") or _args.has("--boss-retry-test") or "--upgrades=" in " ".join(_args) or "--level-up=" in " ".join(_args) or _args.has("--autoplay") or "--attach=" in " ".join(_args) or _args.has("--playtest-report") or _args.has("--boss") or _args.has("--beam-demo") or "--showcase=" in " ".join(_args) or _args.has("--prop-probe") or "--goto-map" in " ".join(_args))


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene == _last_scene or not scene.is_node_ready():
		return
	_last_scene = scene
	var is_arena := scene.is_in_group("arena")
	if _args.has("--smoke-test") and scene.name == "TestRange":
		_attach(scene, "res://tools/smoke_test.gd")
	if _args.has("--upgrade-test") and scene.name == "TestRange":
		_attach(scene, "res://tools/upgrade_test.gd")
	if _args.has("--endless-test") and is_arena and Game.is_endless():
		_attach(scene, "res://tools/endless_test.gd")
	if _args.has("--tutorial-test") and scene.name == "Tutorial":
		_attach(scene, "res://tools/tutorial_test.gd")
	if "--swing-capture=" in " ".join(_args) and scene.name == "GunRange":
		_attach(scene, "res://tools/swing_capture.gd")
	if _args.has("--gun-range-test") and scene.name == "GunRange":
		_attach(scene, "res://tools/gun_range_test.gd")
	if _args.has("--difficulty-test") and is_arena:
		_attach(scene, "res://tools/difficulty_test.gd")
	if _args.has("--boss-retry-test") and is_arena and get_tree().root.get_node_or_null("BossRetryTest") == null:
		var n := Node.new()
		n.name = "BossRetryTest"
		n.set_script(load("res://tools/boss_retry_test.gd"))
		scene.add_child(n)
	if _args.has("--arena-test") and is_arena:
		_attach(scene, "res://tools/scenic_test.gd" if scene.has_method("is_open") else "res://tools/arena_test.gd")
	for a in _args:
		if a.begins_with("--attach=") and (is_arena or scene.name in ["TestRange", "GunRange", "Tutorial"]):
			_attach(scene, a.trim_prefix("--attach="))
	if _args.has("--playtest-report") and (is_arena or scene.name in ["TestRange", "GunRange"]):
		_attach(scene, "res://tools/playtest_report.gd")
	if _args.has("--autoplay") and (is_arena or scene.name == "TestRange"):
		_attach(scene, "res://tools/autopilot.gd")
	if _args.has("--prop-probe") and is_arena:
		_attach(scene, "res://tools/prop_probe.gd")
	if _args.has("--beam-demo") and is_arena:
		_attach(scene, "res://tools/beam_demo.gd")
	if "--showcase=" in " ".join(_args) and (is_arena or scene.name == "GunRange"):
		_attach(scene, "res://tools/showcase_demo.gd")
	if _args.has("--boss") and is_arena:
		scene.debug_skip_to_boss.call_deferred()
	for a in _args:
		if a.begins_with("--upgrades="):
			for part in a.trim_prefix("--upgrades=").split(","):
				var kv := part.split(":")
				Upgrades.stacks[StringName(kv[0])] = int(kv[1]) if kv.size() > 1 else 1
			var m := get_tree().get_first_node_in_group("player") as Mech
			if m:
				m.shield_charges = Upgrades.shield_max()
		elif a.begins_with("--level-up="):
			get_tree().create_timer(a.trim_prefix("--level-up=").to_float(), false).timeout.connect(func() -> void:
				Upgrades.add_xp(Upgrades.xp_to_next() - Upgrades.xp + 0.01))
		if a.begins_with("--goto-map=") and (is_arena or scene.name == "GunRange") and scene._layout:
			var f := a.trim_prefix("--goto-map=").split_floats(",")
			var mech := get_tree().get_first_node_in_group("player") as Node2D
			mech.global_position = scene.map_to_world(scene._layout.image_size * Vector2(f[0], f[1]))


func _attach(scene: Node, path: String) -> void:
	var n := Node.new()
	n.set_script(load(path))
	scene.add_child(n)


func _shot(path: String, delay: float) -> void:
	await get_tree().create_timer(delay, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: ", path)
	get_tree().quit()


func _arg_float(prefix: String, fallback: float) -> float:
	for a in _args:
		if a.begins_with(prefix):
			return a.trim_prefix(prefix).to_float()
	return fallback
