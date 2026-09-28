extends SceneTree
## Builds the Customize-screen turnaround: 8 views of the showcase Gundam (Higgsfield renders in
## assets/hq/raw/turnaround) trimmed, scaled to the same body height and placed on identical canvases
## with the feet on the same baseline, so switching views looks like the body turning in place.
##   godot --headless --path . --script res://tools/build_turnaround.gd

const RAW := "res://assets/hq/raw/turnaround/"
const OUT := "res://assets/hq/turnaround/"
## 16 angles, 22.5 degrees apart, clockwise seen from above, starting facing the viewer.
const VIEWS := ["front", "mid_1", "front_right", "mid_3", "right", "mid_5", "back_right", "mid_7", "back",
	"mid_9", "back_left", "mid_11", "left", "mid_13", "front_left", "mid_15"]
const CANVAS := Vector2i(520, 640)
const BODY_H := 600


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for i in VIEWS.size():
		var path := ProjectSettings.globalize_path(RAW + VIEWS[i] + ".png")
		if not FileAccess.file_exists(path):
			print("missing ", VIEWS[i])
			continue
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a < 0.3:
					img.set_pixel(x, y, Color(c, 0.0))
		var used := img.get_used_rect()
		var part := img.get_region(used)
		var k := float(BODY_H) / used.size.y
		var w := mini(roundi(used.size.x * k), CANVAS.x)
		part.resize(w, roundi(used.size.y * k), Image.INTERPOLATE_LANCZOS)
		var canvas := Image.create_empty(CANVAS.x, CANVAS.y, false, Image.FORMAT_RGBA8)
		canvas.fill(Color(0, 0, 0, 0))
		canvas.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()),
			Vector2i((CANVAS.x - part.get_width()) / 2, CANVAS.y - part.get_height() - 8))
		canvas.save_png(ProjectSettings.globalize_path(OUT + "view_%d.png" % i))
		print("%d %s used=%s -> %s" % [i, VIEWS[i], used, part.get_size()])
	quit()
