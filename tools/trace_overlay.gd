extends SceneTree
## Tracing helper for painted maps: draws a 100 px grid (bold every 500) over the painting and, once the
## layout exists, its walkable (green), obstacles (red), occluders (blue), spawn / boss_spawn /
## repair_station (magenta), vents (orange) and props (cyan). Saves overlay_q0..q3.png (full-res quarters)
## and overlay_small.png (half size) into --dir. Paths must not contain spaces.
##   godot --headless --path . --script res://tools/trace_overlay.gd -- --dir=DIR/ --img=map.png --layout=res://...gd

var DIR := ""
var LAYOUT := ""
var IMG := ""


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="): DIR = a.trim_prefix("--dir=")
		elif a.begins_with("--img="): IMG = a.trim_prefix("--img=")
		elif a.begins_with("--layout="): LAYOUT = a.trim_prefix("--layout=")
	var img := Image.load_from_file(DIR + IMG)
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for x in range(0, w, 100):
		_vline(img, x, Color(1, 1, 0, 0.9) if x % 500 == 0 else Color(1, 1, 1, 0.35), 3 if x % 500 == 0 else 1)
	for y in range(0, h, 100):
		_hline(img, y, Color(1, 1, 0, 0.9) if y % 500 == 0 else Color(1, 1, 1, 0.35), 3 if y % 500 == 0 else 1)
	if ResourceLoader.exists(LAYOUT):
		var L: Object = load(LAYOUT).new()
		_poly(img, L.walkable, Color(0, 1, 0))
		for p in L.obstacles:
			_poly(img, p, Color(1, 0.2, 0.2))
		for p in L.occluders:
			_poly(img, p, Color(0.3, 0.6, 1))
		for key in ["spawn", "boss_spawn", "repair_station"]:
			if L.get(key) == null:
				continue
			_dot(img, L.get(key), Color(1, 0, 1), 18)
		for p in (L.get("vents") if L.get("vents") != null else []):
			_dot(img, p, Color(1, 0.55, 0.1), 16)
		for pr in (L.get("props") if L.get("props") != null else []):
			_dot(img, pr[1], Color(0, 1, 1), 12)
		for p in (L.get("lane_targets") if L.get("lane_targets") != null else []) + (L.get("cluster") if L.get("cluster") != null else []):
			_dot(img, p, Color(0, 1, 1), 14)
	img.save_png(DIR + "overlay_full.png")
	var half := Vector2i(w / 2, h / 2)
	for q in 4:
		var o := Vector2i((q % 2) * half.x, (q / 2) * half.y)
		img.get_region(Rect2i(o, half)).save_png(DIR + "overlay_q%d.png" % q)
	var small := img.duplicate()
	small.resize(w / 2, h / 2)
	small.save_png(DIR + "overlay_small.png")
	quit()


func _vline(img: Image, x: int, c: Color, t: int) -> void:
	for y in img.get_height():
		for k in t:
			if x + k < img.get_width():
				img.set_pixel(x + k, y, img.get_pixel(x + k, y).blend(c))


func _hline(img: Image, y: int, c: Color, t: int) -> void:
	for x in img.get_width():
		for k in t:
			if y + k < img.get_height():
				img.set_pixel(x, y + k, img.get_pixel(x, y + k).blend(c))


func _poly(img: Image, pts: PackedVector2Array, c: Color) -> void:
	for i in pts.size():
		_line(img, pts[i], pts[(i + 1) % pts.size()], c)


func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var n := int(a.distance_to(b)) + 1
	for i in n:
		var p := a.lerp(b, i / float(n))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				var q := Vector2i(p) + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, c)


func _dot(img: Image, p: Vector2, c: Color, r: int) -> void:
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var q := Vector2i(p) + Vector2i(dx, dy)
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, c)
