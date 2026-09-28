extends SceneTree
## Crops the Higgsfield title-screen mech render (transparent PNG) to its visible pixels, scales it to
## TARGET_H px tall and saves assets/hq/title_mech.png. Prints where the eyes / saber tip land in the
## output (as fractions of its size) for ui/main_menu.gd's glow effects.
##   godot --headless --path . --script res://tools/process_title_mech.gd -- --src=PNG

const DST := "res://assets/hq/title_mech.png"
const TARGET_H := 1100
## Points of interest in the SOURCE render (px).
const POINTS := {"eye_l": Vector2(836, 544), "eye_r": Vector2(1018, 544), "saber_tip": Vector2(1480, 187)}


func _init() -> void:
	var src := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.trim_prefix("--src=")
	var img := Image.load_from_file(src)
	img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	img = img.get_region(used)
	var k := float(TARGET_H) / img.get_height()
	img.resize(roundi(img.get_width() * k), TARGET_H, Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(DST))
	print("title_mech %dx%d (crop %s)" % [img.get_width(), img.get_height(), used])
	for n: String in POINTS:
		var p: Vector2 = (POINTS[n] - Vector2(used.position)) / Vector2(used.size)
		print("%s = Vector2(%.3f, %.3f)" % [n, p.x, p.y])
	quit()
