extends SceneTree
## Debug: contact sheet of every PNG in a folder on a grey backdrop.  -- <res dir> <out.png> [cell]

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var cell := int(a[2]) if a.size() > 2 else 320
	var files: Array[String] = []
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(dir)):
		if f.ends_with(".png"):
			files.append(f)
	files.sort()
	var sheet := Image.create_empty(cell * files.size(), cell + 24, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.3, 0.32, 0.36))
	for i in files.size():
		var img := Image.load_from_file(ProjectSettings.globalize_path(dir + "/" + files[i]))
		img.convert(Image.FORMAT_RGBA8)
		img.resize(cell, cell)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * cell, 0))
		print(i, " ", files[i])
	sheet.save_png(a[1])
	quit()
