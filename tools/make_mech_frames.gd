extends SceneTree
## Multi-mech pipeline, Godot step (art_src/mechs/make_mech.py runs it after Blender renders the sheet):
##   godot --headless --path . --script res://tools/make_mech_frames.gd -- --sheet=<name>
## From res://assets/sprites/mechs/<name>/sheet.png (7 rows x 8 cells of 256 px, the same layout as
## assets/sprites/gundam_sheet.png: idle 8, boost 6, bank_left 6, bank_right 6, dash 6, fire 4, aim 6) it writes:
##   sheet_nogun.png      the sheet with the painted rifle cleared (any weapon but the Beam Rifle is drawn in
##                        the fist instead) - the same scan as tools/make_nogun_sheet.gd
##   frames.tres          SpriteFrames over sheet.png (animations, speeds and loops copied from
##   frames_nogun.tres    assets/sprites/gundam_frames*.tres)
##   fists.tres           per-frame fist + rifle-tip points (the same scan as tools/measure_fists.gd) as metadata
##                        "fist" / "rifle_tip" ({anim: [Vector2...]}); read by player/weapons/held_weapon.gd for this
##                        mech instead of its built-in FIST / RIFLE_TIP (a .tres, so exports pack it)
## Run --import afterwards so Godot picks up the new PNGs.

const FRAME := 256
const X_FROM := 150
const RIFLE_MAX_W := 25
const NOGUN_ALPHA := 0.1
const MEASURE_ALPHA := 0.5
const FIST_DEPTH := 6.0
## animation -> [sheet row, frame count]
const ANIMS := {"idle": [0, 8], "boost": [1, 6], "bank_left": [2, 6], "bank_right": [3, 6], "dash": [4, 6],
	"fire": [5, 4], "aim": [6, 6]}


func _init() -> void:
	var name := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sheet="):
			name = a.trim_prefix("--sheet=")
	if name == "":
		push_error("make_mech_frames: pass -- --sheet=<name>")
		quit(1)
		return
	var dir := "res://assets/sprites/mechs/%s/" % name
	var src := ProjectSettings.globalize_path(dir + "sheet.png")
	var sheet := Image.load_from_file(src)
	if sheet == null or sheet.is_empty():
		push_error("make_mech_frames: no sheet at " + src)
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	# Fist / rifle-tip table (measured on the sheet with its rifle).
	var fists := {}
	var tips := {}
	for anim: String in ANIMS:
		var f_pts := PackedStringArray()
		var t_pts := PackedStringArray()
		for c in int(ANIMS[anim][1]):
			var r := _rifle(sheet, Vector2i(c * FRAME, int(ANIMS[anim][0]) * FRAME))
			f_pts.append("Vector2(%.1f, %.1f)" % [r["fist"].x, r["fist"].y])
			t_pts.append("Vector2(%.1f, %.1f)" % [r["tip"].x, r["tip"].y])
		fists[anim] = ", ".join(f_pts)
		tips[anim] = ", ".join(t_pts)
	var txt := "[gd_resource type=\"Resource\" format=3]\n\n[resource]\n"
	for key: String in ["fist", "rifle_tip"]:
		var table: Dictionary = fists if key == "fist" else tips
		var parts := PackedStringArray()
		for anim: String in table:
			parts.append("&\"%s\": [%s]" % [anim, table[anim]])
		txt += "metadata/%s = {\n%s\n}\n" % [key, ",\n".join(parts)]
	var f := FileAccess.open(ProjectSettings.globalize_path(dir + "fists.tres"), FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	# Rifle-free sheet.
	var nogun := sheet.duplicate() as Image
	for fy in nogun.get_height() / FRAME:
		for fx in nogun.get_width() / FRAME:
			_clean(nogun, Vector2i(fx * FRAME, fy * FRAME))
	nogun.save_png(ProjectSettings.globalize_path(dir + "sheet_nogun.png"))
	# SpriteFrames: the shipped mech's frame sets, pointed at this mech's sheets.
	_retarget("res://assets/sprites/gundam_frames.tres", "res://assets/sprites/gundam_sheet.png", dir + "frames.tres",
		dir + "sheet.png")
	_retarget("res://assets/sprites/gundam_frames_nogun.tres", "res://assets/sprites/gundam_sheet_nogun.png",
		dir + "frames_nogun.tres", dir + "sheet_nogun.png")
	print("MECH FRAMES OK: ", dir)
	quit()


func _retarget(template: String, old_path: String, out: String, new_path: String) -> void:
	var t := FileAccess.get_file_as_string(ProjectSettings.globalize_path(template))
	t = t.replace("path=\"%s\"" % old_path, "path=\"%s\"" % new_path)
	var f := FileAccess.open(ProjectSettings.globalize_path(out), FileAccess.WRITE)
	f.store_string(t)
	f.close()


# --- rifle scan (tools/measure_fists.gd) ---------------------------------------------------------------

func _rifle(sheet: Image, o: Vector2i) -> Dictionary:
	var xs: Array[float] = []
	var ys: Array[float] = []
	for y in FRAME:
		var n := 0
		var sx := 0.0
		for x in range(X_FROM, FRAME):
			if sheet.get_pixel(o.x + x, o.y + y).a > MEASURE_ALPHA:
				n += 1
				sx += x
		if n == 0:
			continue
		if n > RIFLE_MAX_W:
			break
		xs.append(sx / n)
		ys.append(y)
	if xs.size() < 4:
		# No rifle found in this cell (empty frame): the shipped mech's idle fist.
		return {"fist": Vector2(179.8, 106.9), "tip": Vector2(197.4, 15.0)}
	var from := int(xs.size() * 0.3)
	var my := 0.0
	var mx := 0.0
	for i in range(from, xs.size()):
		my += ys[i]
		mx += xs[i]
	my /= xs.size() - from
	mx /= xs.size() - from
	var num := 0.0
	var den := 0.0
	for i in range(from, xs.size()):
		num += (ys[i] - my) * (xs[i] - mx)
		den += (ys[i] - my) * (ys[i] - my)
	var b := num / maxf(den, 0.0001)
	var base := Vector2(mx + b * (ys[-1] - my), ys[-1])
	var top := Vector2(mx + b * (ys[0] - my), ys[0])
	var up := (top - base).normalized()
	return {"fist": base - up * FIST_DEPTH, "tip": top}


# --- rifle removal (tools/make_nogun_sheet.gd) ---------------------------------------------------------

func _clean(sheet: Image, o: Vector2i) -> void:
	var top := -1
	for y in FRAME:
		if _row_width(sheet, o, y) > 0:
			top = y
			break
	if top < 0:
		return
	for y in range(top, FRAME):
		if _row_width(sheet, o, y) > RIFLE_MAX_W:
			break
		for x in range(X_FROM, FRAME):
			sheet.set_pixel(o.x + x, o.y + y, Color(0, 0, 0, 0))
	for y in top:
		for x in range(X_FROM, FRAME):
			sheet.set_pixel(o.x + x, o.y + y, Color(0, 0, 0, 0))


func _row_width(sheet: Image, o: Vector2i, y: int) -> int:
	var n := 0
	for x in range(X_FROM, FRAME):
		if sheet.get_pixel(o.x + x, o.y + y).a > NOGUN_ALPHA:
			n += 1
	return n
