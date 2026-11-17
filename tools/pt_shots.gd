extends Node
## Playtest captures (scratch worktree only): attach to a run and save screenshots at set times.
##   godot --path . --resolution 1280x720 --audio-driver Dummy -- --arena=1 --sector=1 --no-intro --autoplay --temp-save
##       --attach=res://tools/pt_shots.gd --pt-out=C:/x --pt-tag=a1s1 --pt-times=6,14,24 [--pt-menu]
## Survives scene changes (moves itself to the root), then quits after the last shot.

static var _running := false
var _out := "user://pt"
var _tag := "shot"
var _times: Array[float] = [6.0, 14.0, 24.0]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene := get_parent()
	if _running or (not args.has("--pt-menu") and not (scene.is_in_group("arena") or scene.name == "GunRange")):
		queue_free()
		return
	_running = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in args:
		if a.begins_with("--pt-out="):
			_out = a.trim_prefix("--pt-out=")
		elif a.begins_with("--pt-tag="):
			_tag = a.trim_prefix("--pt-tag=")
		elif a.begins_with("--pt-times="):
			_times.clear()
			for s in a.trim_prefix("--pt-times=").split(","):
				_times.append(float(s))
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func _run() -> void:
	reparent(get_tree().root)
	var t0 := Time.get_ticks_msec()
	var skip := -1.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pt-skip="):
			skip = float(a.trim_prefix("--pt-skip="))
	for t in _times:
		while (Time.get_ticks_msec() - t0) / 1000.0 < t:
			if skip >= 0.0 and (Time.get_ticks_msec() - t0) / 1000.0 >= skip:
				skip = -1.0
				var ar := get_tree().get_first_node_in_group("arena")
				if ar and ar.has_method("debug_skip_to_boss"):
					Game.run_scrap = 3000.0
					ar.debug_skip_to_boss()
					print("PT SKIP sector cleared")
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s_%03d.png" % [_out, _tag, int(t)]
		get_viewport().get_texture().get_image().save_png(path)
		var sc := get_tree().current_scene
		print("PT SHOT ", path, " scene=", sc.name if sc else "-")
	get_tree().quit()
