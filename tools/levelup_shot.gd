extends Node
## Debug capture of the level-up menu:  -- --gun-range --attach=res://tools/levelup_shot.gd --levelup-shot=PATH
## Levels the mech up once the scene is running, waits for the cards to animate in, saves a screenshot.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	var path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--levelup-shot="):
			path = a.trim_prefix("--levelup-shot=")
	# The real mouse over the window must not flip a --touch capture back to keyboard mode.
	Controls.ignore_real_input = true
	for i in 60:
		await get_tree().process_frame
	if OS.get_cmdline_user_args().has("--touch") and Controls.device != Controls.Device.TOUCH:
		Controls.device = Controls.Device.TOUCH
		Controls.device_changed.emit(Controls.device)
		for i in 10:
			await get_tree().process_frame
	Upgrades.add_xp(Upgrades.xp_to_next() - Upgrades.xp + 0.01)
	for i in 50:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("level-up screenshot saved: ", path, "  menu open: ", Upgrades.choosing)
	get_tree().quit()
