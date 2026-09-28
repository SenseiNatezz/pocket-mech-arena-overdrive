extends SceneTree
## Debug: puts the 8 turnaround views side by side (scratchpad/turnaround_sheet.png).

func _init() -> void:
	var sheet := Image.create_empty(16 * 130, 170, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.14, 0.22))
	for i in 16:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/hq/turnaround/view_%d.png" % i))
		img.convert(Image.FORMAT_RGBA8)
		img.resize(130, 160)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * 130, 5))
	sheet.save_png(OS.get_environment("TEMP").path_join("turnaround_sheet.png"))
	quit()
