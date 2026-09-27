extends Node
## Debug (autoload): command-line helpers for testing and preview captures. Args go after `--`:
##   --arena=N                   start directly in arena N (1-based)
##   --smoke-test                controls test (run with the test range scene)
##   --arena-test                full arena flow test (waves, hazards, pits, boss, victory)
##   --autoplay                  an AI pilots the mech (for preview captures)
##   --boss                      skip the waves and go straight to the boss
##   --shot=PATH --shot-time=S   save a screenshot after S seconds, then quit
##   --touch                     force on-screen touch controls
## Does nothing when no debug args are given.

var _args := OS.get_cmdline_user_args()
var _last_scene: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in _args:
		if a.begins_with("--arena="):
			Game.start_arena.call_deferred(int(a.trim_prefix("--arena=")) - 1)
		elif a.begins_with("--shot="):
			_shot(a.trim_prefix("--shot="), _arg_float("--shot-time=", 1.5))
	set_process(_args.has("--smoke-test") or _args.has("--arena-test") or _args.has("--autoplay") or _args.has("--boss"))


func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == null or scene == _last_scene or not scene.is_node_ready():
		return
	_last_scene = scene
	var is_arena := scene.is_in_group("arena")
	if _args.has("--smoke-test") and scene.name == "TestRange":
		_attach(scene, "res://tools/smoke_test.gd")
	if _args.has("--arena-test") and is_arena:
		_attach(scene, "res://tools/arena_test.gd")
	if _args.has("--autoplay") and (is_arena or scene.name == "TestRange"):
		_attach(scene, "res://tools/autopilot.gd")
	if _args.has("--boss") and is_arena:
		scene.debug_skip_to_boss.call_deferred()


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
