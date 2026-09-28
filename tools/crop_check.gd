extends SceneTree
## Debug: crops a region of a screenshot at 2x for close inspection.  -- <in.png> <x> <y> <w> <h> <out.png>

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var img := Image.load_from_file(a[0])
	var r := Rect2i(int(a[1]), int(a[2]), int(a[3]), int(a[4]))
	var c := img.get_region(r)
	c.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
	c.save_png(a[5])
	quit()
