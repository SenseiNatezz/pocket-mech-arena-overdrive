extends SceneTree
## Debug helper: writes crops of a map image with a coordinate grid (every 128 px, bold every 512 px,
## in original image pixels) so collision can be traced accurately.
##   godot --headless --path . --script res://tools/grid_crops.gd -- <file in assets/hq/raw> <cols> <rows>

## Debug crops go to the system temp folder.
var OUT := OS.get_environment("TEMP").replace("\\", "/") + "/"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var file: String = args[0]
	var cols := int(args[1])
	var rows := int(args[2])
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/hq/raw/" + file))
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for x in range(0, w, 128):
		var bold := x % 512 == 0
		for y in h:
			for t in (4 if bold else 2):
				if x + t < w:
					img.set_pixel(x + t, y, Color(0, 1, 1) if bold else Color(1, 1, 0))
	for y in range(0, h, 128):
		var bold := y % 512 == 0
		for x in w:
			for t in (4 if bold else 2):
				if y + t < h:
					img.set_pixel(x, y + t, Color(0, 1, 1) if bold else Color(1, 1, 0))
	var cw := w / cols
	var ch := h / rows
	for r in rows:
		for c in cols:
			img.get_region(Rect2i(c * cw, r * ch, cw, ch)).save_png(OUT + "%s_r%dc%d.png" % [file.get_basename(), r, c])
	print("done %dx%d crops of %dx%d" % [cols, rows, cw, ch])
	quit()
