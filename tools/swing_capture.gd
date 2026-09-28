extends Node
## Melee swing preview (Weapon Range):  godot --path . -- --gun-range --swing-capture=OUT_DIR
## For every melee weapon: stands the mech beside the drone cluster, plays a basic swing and then a
## finisher, and saves a contact sheet (frames every 3 physics frames, 4 x 3 grid, cropped around the
## mech) to OUT_DIR/swing_<id>.png. Quits when done.

const FRAMES := 12
const STEP := 3
const CROP := Vector2i(560, 420)

var _out := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.ignore_real_input = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--swing-capture="):
			_out = a.trim_prefix("--swing-capture=")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	await _frames(20)
	var gr := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	var cluster: Array = gr.get_node("Dummies").get_children().filter(func(d: Node) -> bool: return d.name.begins_with("Cluster"))
	var center := Vector2.ZERO
	for d in cluster:
		center += d.global_position
	center /= cluster.size()
	for id: StringName in MeleeKit.WEAPONS:
		gr.select_weapon(id, false)
		mech.global_position = center + Vector2(170, 0)
		mech.velocity = Vector2.ZERO
		Controls.touch_aim = Vector2.LEFT
		mech.melee.combo = 0
		await _frames(40)
		var shots: Array[Image] = []
		mech._fire_primary(1.0)
		for i in FRAMES:
			await _frames(STEP)
			await RenderingServer.frame_post_draw
			shots.append(_crop(mech))
		_save(shots, "swing_%s.png" % id)
		# Finisher: run the combo up to its last hit.
		var combo: int = MeleeKit.WEAPONS[id]["combo"]
		mech.melee._last_id = id
		mech.melee.combo = combo - 2
		mech.melee._last_swing = Time.get_ticks_msec() / 1000.0
		mech.global_position = center + Vector2(260, 0)
		await _frames(2)
		var fin: Array[Image] = []
		mech._fire_primary(1.0)
		for i in FRAMES:
			await _frames(STEP)
			await RenderingServer.frame_post_draw
			fin.append(_crop(mech))
		_save(fin, "finisher_%s.png" % id)
		print("captured ", id)
	get_tree().quit()


func _crop(mech: Mech) -> Image:
	var img := get_viewport().get_texture().get_image()
	var screen := mech.get_global_transform_with_canvas().origin
	var r := Rect2i(Vector2i(screen) - CROP / 2, CROP)
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	return img.get_region(r)


func _save(shots: Array[Image], name: String) -> void:
	var cols := 4
	var cell := CROP / 2
	var sheet := Image.create(cell.x * cols, cell.y * ceili(shots.size() / float(cols)), false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var s := shots[i]
		s.resize(cell.x, cell.y)
		sheet.blit_rect(s, Rect2i(Vector2i.ZERO, cell), Vector2i((i % cols) * cell.x, (i / cols) * cell.y))
	sheet.save_png(_out.path_join(name))
