extends SceneTree
## Turns frames extracted from the Higgsfield turntable video (assets/hq/raw/turntable_src/frame*.png,
## one full 360-degree turn, first frame = front) into the Customize-screen frame sequence
## (assets/hq/turntable/frame_NNN.png). Frames without alpha get their plain studio background keyed out.
## The camera is static, so ONE shared crop is used for every frame (no jitter between frames).
##   godot --headless --path . --script res://tools/build_turntable.gd -- [frame_count]

const SRC := "res://assets/hq/raw/turntable_src2/"
const OUT := "res://assets/hq/turntable/"
const CANVAS := Vector2i(560, 560)
const FEET := Vector2i(280, 548)
const BODY_H := 520.0


func _init() -> void:
	var files: Array[String] = []
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(SRC)):
		if f.ends_with(".png"):
			files.append(f)
	files.sort()
	var want := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else files.size()
	# The extracted frames already stop just before the video returns to the front.
	var total := files.size()
	var picks: Array[String] = []
	for i in want:
		picks.append(files[int(float(i) / want * total)])
	var imgs: Array[Image] = []
	var union := Rect2i()
	for f in picks:
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + f))
		img.convert(Image.FORMAT_RGBA8)
		_key(img)
		imgs.append(img)
		var u := img.get_used_rect()
		union = u if union.size == Vector2i.ZERO else union.merge(u)
	var k := BODY_H / union.size.y
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for f in DirAccess.get_files_at(ProjectSettings.globalize_path(OUT)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + f))
	for i in imgs.size():
		var part := imgs[i].get_region(union)
		part.resize(roundi(union.size.x * k), roundi(union.size.y * k), Image.INTERPOLATE_LANCZOS)
		var canvas := Image.create_empty(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		canvas.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()),
			Vector2i(FEET.x - part.get_width() / 2, FEET.y - part.get_height()))
		canvas.save_png(ProjectSettings.globalize_path(OUT + "frame_%03d.png" % i))
	print("built %d frames, union %s, scale %.3f" % [imgs.size(), union, k])
	quit()


## Background key for frames with no alpha: samples the backdrop at the corners and removes pixels
## close to it (soft edge), keeping saturated armor and bright highlights.
func _key(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	if img.get_pixel(4, 4).a < 0.5:
		return  # already has alpha (background removed upstream)
	var bg := Color(0, 0, 0)
	for p in [Vector2i(6, 6), Vector2i(w - 7, 6), Vector2i(6, h - 7), Vector2i(w - 7, h - 7)]:
		bg += img.get_pixelv(p) / 4.0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var d := Vector3(c.r - bg.r, c.g - bg.g, c.b - bg.b).length()
			var a := clampf((d - 0.035) / 0.06, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	# Keep only the largest connected blob region: clear specks by removing isolated low-alpha dust.
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var c := img.get_pixel(x, y)
			if c.a > 0.0 and c.a < 0.6:
				var n := img.get_pixel(x - 1, y).a + img.get_pixel(x + 1, y).a + img.get_pixel(x, y - 1).a + img.get_pixel(x, y + 1).a
				if n < 0.8:
					img.set_pixel(x, y, Color(c, 0.0))
