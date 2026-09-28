extends SceneTree
## Debug: crop + upscale a region of an image over grey, with a grid every 32 source px (for reading
## sprite-space coordinates).  -- <res src> <x> <y> <w> <h> <scale> <out.png>

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var k := int(a[5])
	var img := Image.load_from_file(ProjectSettings.globalize_path(a[0]))
	img.convert(Image.FORMAT_RGBA8)
	var r := img.get_region(Rect2i(int(a[1]), int(a[2]), int(a[3]), int(a[4])))
	r.resize(r.get_width() * k, r.get_height() * k, Image.INTERPOLATE_NEAREST)
	var bg := Image.create_empty(r.get_width(), r.get_height(), false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.3, 0.32, 0.36))
	bg.blend_rect(r, Rect2i(Vector2i.ZERO, r.get_size()), Vector2i.ZERO)
	for x in range(0, bg.get_width(), 32 * k):
		for y in bg.get_height():
			bg.set_pixel(x, y, Color(1, 1, 0))
	for y in range(0, bg.get_height(), 32 * k):
		for x in bg.get_width():
			bg.set_pixel(x, y, Color(1, 1, 0))
	bg.save_png(a[6])
	quit()
