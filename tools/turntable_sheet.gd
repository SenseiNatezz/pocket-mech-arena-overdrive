extends SceneTree
## Debug: 16 evenly spaced turntable frames side by side (scratchpad/turntable_frames.png).

func _init() -> void:
	var sheet := Image.create_empty(16 * 150, 160, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.14, 0.22))
	for i in 16:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/hq/turntable/frame_%03d.png" % (i * 12)))
		img.convert(Image.FORMAT_RGBA8)
		img.resize(150, 150)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(i * 150, 5))
	sheet.save_png(OS.get_environment("TEMP").path_join("turntable_frames.png"))
	quit()
