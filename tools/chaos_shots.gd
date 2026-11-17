extends Node
## CHAOS RIFT captures (windowed):
##   godot --path . --resolution 1280x720 --audio-driver Dummy -- --arena=1 --sector=1 --no-intro --no-rival --chaos
##       --curse=horde --temp-save --attach=res://tools/chaos_shots.gd --chaos-out=DIR [--portrait]
## Saves DIR/curse.png (the curse banner + plate, a few seconds into the waves), DIR/doors.png (the route doors
## with the CHAOS RIFT door) and DIR/boon.png (the blessing pick), then quits.

static var _running := false
var _out := "user://chaos"


func _ready() -> void:
	if _running or not get_parent().is_in_group("arena"):
		queue_free()
		return
	_running = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chaos-out="):
			_out = a.trim_prefix("--chaos-out=")
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, name])
	print("CHAOS SHOT ", name)


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	reparent(get_tree().root)
	var a := get_tree().get_first_node_in_group("arena") as ScenicArena
	var m := get_tree().get_first_node_in_group("player") as Mech
	m._invuln = 1e9
	await _wait(5.2)
	await _shot("curse")
	# The doors (Controls.ignore_real_input off so they wait to be photographed).
	Controls.ignore_real_input = false
	var doors := RouteChoice.new()
	a.add_child(doors)
	doors.open(Game.route_options())
	await _wait(0.9)
	await _shot("doors")
	doors._done = true
	doors.queue_free()
	get_tree().paused = false
	# The blessing pick.
	var rift := a.get_node_or_null("ChaosRift") as ChaosRift
	if rift:
		rift.lift()
	await _wait(0.9)
	await _shot("boon")
	get_tree().quit()
