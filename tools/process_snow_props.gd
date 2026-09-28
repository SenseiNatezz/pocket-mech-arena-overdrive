extends SceneTree
## Crops the Higgsfield top-down snow prop sprites to their visible pixels, scales them to game size
## and saves them in assets/hq/props_snow/ (plus a preview sheet next to the sources).
##   godot --headless --path . --script res://tools/process_snow_props.gd -- --src=DIR [--dst=res://assets/hq/<folder>/]
## (--dst: other prop sets, e.g. the neutral top-down set in props_topdown used by the non-snow maps)

var DST := "res://assets/hq/props_snow/"
## name -> longest side in pixels after processing
const SIZES := {"crate_wood": 192, "crate_steel": 192, "cargo": 256, "barrel": 128, "barrier": 512, "sandbags": 512}


func _init() -> void:
	var src := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.trim_prefix("--src=")
		elif a.begins_with("--dst="):
			DST = a.trim_prefix("--dst=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DST))
	var sheet := Image.create(6 * 260, 280, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.35, 0.45, 0.6))
	var i := 0
	for n: String in SIZES:
		var img := Image.load_from_file(src.path_join(n + ".png"))
		img.convert(Image.FORMAT_RGBA8)
		var used := img.get_used_rect()
		img = img.get_region(used)
		var longest: int = SIZES[n]
		var k := float(longest) / maxf(img.get_width(), img.get_height())
		img.resize(maxi(1, roundi(img.get_width() * k)), maxi(1, roundi(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
		img.save_png(ProjectSettings.globalize_path(DST + n + ".png"))
		print("%s used %s -> %dx%d" % [n, used, img.get_width(), img.get_height()])
		var prev := img.duplicate()
		var pk := 250.0 / maxf(prev.get_width(), prev.get_height())
		prev.resize(roundi(prev.get_width() * pk), roundi(prev.get_height() * pk))
		sheet.blend_rect(prev, Rect2i(Vector2i.ZERO, prev.get_size()), Vector2i(i * 260 + 5, 15))
		i += 1
	sheet.save_png(src.path_join("props_sheet.png"))
	quit()
