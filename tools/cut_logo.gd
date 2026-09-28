extends SceneTree
## Cuts the POCKET MECH ARENA logo (Higgsfield render on a dark background) out to a transparent PNG.
##   godot --headless --path . --script res://tools/cut_logo.gd -- --src=PNG [--out=res://assets/hq/title_logo.png]
## Background = everything dark reachable from the image border (flood fill). Inside it, alpha follows
## brightness and the colour is un-premultiplied from black, so the cyan glow survives as soft light;
## the logo itself stays fully opaque. Also writes a preview over a sky-ish colour next to the source.

const DARK := 0.3
const OUT_W := 1100


func _init() -> void:
	var src := ""
	var out := "res://assets/hq/title_logo.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--src="):
			src = a.trim_prefix("--src=")
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
	var img := Image.load_from_file(src)
	img.convert(Image.FORMAT_RGBA8)
	img.resize(OUT_W, roundi(img.get_height() * float(OUT_W) / img.get_width()), Image.INTERPOLATE_LANCZOS)
	var w := img.get_width()
	var h := img.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if bg[i] == 1:
			continue
		var c := img.get_pixel(i % w, i / w)
		if maxf(c.r, maxf(c.g, c.b)) >= DARK:
			continue
		bg[i] = 1
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	for y in h:
		for x in w:
			if bg[y * w + x] == 0:
				continue
			var c := img.get_pixel(x, y)
			var m := maxf(c.r, maxf(c.g, c.b))
			# Alpha ramps up to fully opaque at the logo edge (DARK), and the colour is divided by it, so the
			# pixel shows exactly as it did over black: the glow reads as a soft dark-cyan backing plate.
			var a := clampf((m - 0.07) / (DARK - 0.07), 0.0, 1.0)
			var rgb := (Color(c.r, c.g, c.b) / maxf(a, 0.001)).clamp(Color(0, 0, 0), Color(1, 1, 1)) if a > 0.0 else Color.BLACK
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, a))
	# Crop to where the logo / its glow is actually visible (ignore the faintest haze).
	var used := Rect2i()
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.12:
				used = Rect2i(x, y, 1, 1) if used.size == Vector2i.ZERO else used.expand(Vector2i(x, y))
	used = used.grow(6).intersection(Rect2i(0, 0, w, h))
	img = img.get_region(used)
	img.save_png(ProjectSettings.globalize_path(out))
	var prev := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	prev.fill(Color(0.45, 0.3, 0.45))
	prev.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
	prev.save_png(src.get_base_dir().path_join("logo_preview.png"))
	print("logo %dx%d (from %s)" % [img.get_width(), img.get_height(), used])
	quit()
