extends SceneTree
## Generates res://assets/tiles/city_tiles.png: original placeholder art for the ruined-city
## tileset (64 px tiles, 8x8 atlas). Re-run after tweaking, then run build_city_tileset.gd:
##   godot --headless --path . --script res://tools/gen_city_tiles.gd
##
## Atlas map (column, row):
##   row 0  floors: asphalt, asphalt cracked, asphalt broken, lane dash (H), metal plate, grate,
##          sidewalk, sidewalk mossy
##   row 1  floors: rubble, oil stain, crosswalk, scorch, overgrown, puddle, manhole, lane dash (V)
##   row 2  roofs (solid): plain, vent, broken, AC unit, rubble, beacon
##   row 3  upper facades (solid): dark windows, lit + broken, damaged, pipes, neon sign, warm light
##   row 4  ground facades (solid): shopfront, shutter, door, cracked wall, collapsed
##   row 5  barrier top, barrier face (solid), wreck car A (2 wide), wreck car B (2 wide),
##          jersey barrier, dumpster
##   row 6  overlays: north rim, west rim, east rim, shadow, shadow strip, shadow strip top
##   row 7  decor: debris, trash, fallen lamp, tire, big crack, weeds, live cable, traffic cone

const T := 64
const OUT := "res://assets/tiles/city_tiles.png"

var img: Image
var rng := RandomNumberGenerator.new()
var ox := 0
var oy := 0
var tw := T
var th := T


func _init() -> void:
	rng.seed = 20260926
	img = Image.create_empty(T * 8, T * 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_floors()
	_roofs()
	_facades()
	_props()
	_overlays()
	_decor()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/tiles"))
	var err := img.save_png(OUT)
	print("wrote %s (%s)" % [OUT, error_string(err)])
	quit()


# --- drawing helpers (coordinates local to the current tile) --------------------------------------

func at(tx: int, ty: int, w := 1, h := 1) -> void:
	ox = tx * T
	oy = ty * T
	tw = w * T
	th = h * T


func put(x: int, y: int, c: Color) -> void:
	if x < 0 or y < 0 or x >= tw or y >= th or c.a <= 0.0:
		return
	img.set_pixel(ox + x, oy + y, img.get_pixel(ox + x, oy + y).blend(c))


func fill_noise(base: Color, amount: float) -> void:
	for y in th:
		for x in tw:
			var v := rng.randf_range(-amount, amount)
			img.set_pixel(ox + x, oy + y, Color(base.r + v, base.g + v, base.b + v * 1.1, base.a))


func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			put(xx, yy, c)


func noisy_rect(x: int, y: int, w: int, h: int, c: Color, amount: float) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var v := rng.randf_range(-amount, amount)
			put(xx, yy, Color(c.r + v, c.g + v, c.b + v, c.a))


func disc(cx: float, cy: float, r: float, c: Color, soft := 0.0) -> void:
	for y in range(floori(cy - r), ceili(cy + r) + 1):
		for x in range(floori(cx - r), ceili(cx + r) + 1):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d <= r:
				var a := c.a if soft <= 0.0 else c.a * clampf((r - d) / soft, 0.0, 1.0)
				put(x, y, Color(c, a))


func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color, soft := 0.0) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var d := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry).length()
			if d <= 1.0:
				var a := c.a if soft <= 0.0 else c.a * clampf((1.0 - d) / soft, 0.0, 1.0)
				put(x, y, Color(c, a))


func ring(cx: float, cy: float, r: float, width: float, c: Color) -> void:
	for y in range(floori(cy - r - width), ceili(cy + r + width) + 1):
		for x in range(floori(cx - r - width), ceili(cx + r + width) + 1):
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if absf(d - r) <= width * 0.5:
				put(x, y, c)


func line(a: Vector2, b: Vector2, c: Color, width := 1.0) -> void:
	var steps := maxi(ceili(a.distance_to(b) * 2.0), 1)
	var seen := {}
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		var r := width * 0.5
		for y in range(floori(p.y - r), ceili(p.y + r) + 1):
			for x in range(floori(p.x - r), ceili(p.x + r) + 1):
				var key := Vector2i(x, y)
				if not seen.has(key) and Vector2(x + 0.5, y + 0.5).distance_to(p) <= maxf(r, 0.5):
					seen[key] = true
					put(x, y, c)


func poly(points: PackedVector2Array, c: Color) -> void:
	var r := Rect2(points[0], Vector2.ZERO)
	for p in points:
		r = r.expand(p)
	for y in range(floori(r.position.y), ceili(r.end.y) + 1):
		for x in range(floori(r.position.x), ceili(r.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), points):
				put(x, y, c)


func crack(start: Vector2, length: int, c: Color, branch := true) -> void:
	var p := start
	var ang := rng.randf() * TAU
	for i in length:
		ang += rng.randf_range(-0.6, 0.6)
		var n := p + Vector2.from_angle(ang) * 1.6
		line(p, n, c, 1.2)
		put(roundi(n.x) + 1, roundi(n.y) + 1, Color(1, 1, 1, 0.05))
		p = n
		if branch and rng.randf() < 0.06:
			crack(p, length / 3, Color(c, c.a * 0.8), false)


func chunk(cx: float, cy: float, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	var n := rng.randi_range(5, 7)
	for i in n:
		pts.append(Vector2(cx, cy) + Vector2.from_angle(TAU * i / n + rng.randf_range(-0.3, 0.3)) * r * rng.randf_range(0.6, 1.1))
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(1.5, 2.0))
	poly(shadow, Color(0, 0, 0, 0.45))
	poly(pts, c)
	# Light from the top-left: highlight the upper edge.
	for i in n:
		if pts[i].y < cy and pts[(i + 1) % n].y < cy:
			line(pts[i], pts[(i + 1) % n], c.lightened(0.35), 1.0)


# --- floors ----------------------------------------------------------------------------------------

const ASPHALT := Color(0.165, 0.175, 0.205)


func _asphalt(cracks := 0) -> void:
	fill_noise(ASPHALT, 0.022)
	for i in 3:
		var r := rng.randf_range(8, 14)
		disc(rng.randf_range(r, T - r), rng.randf_range(r, T - r), r, Color(0.3, 0.3, 0.34, 0.06), r)
	for i in 50:
		put(rng.randi_range(0, 63), rng.randi_range(0, 63), Color(0.36, 0.36, 0.4, 0.8))
	for i in 40:
		put(rng.randi_range(0, 63), rng.randi_range(0, 63), Color(0.07, 0.07, 0.09, 0.8))
	for i in cracks:
		crack(Vector2(rng.randf_range(10, 54), rng.randf_range(10, 54)), rng.randi_range(14, 28), Color(0.05, 0.05, 0.07, 0.9))


func _worn(c: Color, keep := 0.72) -> Color:
	return c if rng.randf() < keep else Color(c, c.a * 0.25)


func _floors() -> void:
	at(0, 0); _asphalt(0)
	at(1, 0); _asphalt(1)
	at(2, 0); _asphalt(3)
	for i in 5:
		chunk(rng.randf_range(8, 56), rng.randf_range(8, 56), rng.randf_range(2, 4), Color(0.3, 0.3, 0.33))

	at(3, 0); _asphalt(0)
	for y in range(29, 35):
		for x in range(6, 58):
			put(x, y, _worn(Color(0.86, 0.68, 0.18, 0.85)))

	# Metal deck plate.
	at(4, 0)
	fill_noise(Color(0.23, 0.25, 0.29), 0.014)
	rect(0, 0, 64, 2, Color(0.1, 0.11, 0.13))
	rect(0, 0, 2, 64, Color(0.1, 0.11, 0.13))
	rect(0, 2, 64, 1, Color(0.36, 0.38, 0.43))
	rect(2, 0, 1, 64, Color(0.36, 0.38, 0.43))
	rect(32, 2, 1, 62, Color(0.14, 0.15, 0.18, 0.7))
	for p: Vector2 in [Vector2(8, 8), Vector2(56, 8), Vector2(8, 56), Vector2(56, 56)]:
		disc(p.x + 0.5, p.y + 1, 2.2, Color(0, 0, 0, 0.5))
		disc(p.x, p.y, 2.0, Color(0.5, 0.52, 0.58))
	for i in 6:
		var a := Vector2(rng.randf_range(6, 58), rng.randf_range(6, 58))
		line(a, a + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(6, 14), Color(1, 1, 1, 0.06), 1.0)

	# Grate.
	at(5, 0)
	fill_noise(Color(0.07, 0.08, 0.1), 0.02)
	for x in range(3, 64, 8):
		noisy_rect(x, 3, 4, 58, Color(0.27, 0.29, 0.33), 0.015)
		rect(x, 3, 4, 1, Color(0.42, 0.44, 0.5))
		rect(x + 3, 3, 1, 58, Color(0.14, 0.15, 0.18))
	rect(0, 0, 64, 3, Color(0.2, 0.21, 0.25))
	rect(0, 61, 64, 3, Color(0.2, 0.21, 0.25))

	# Sidewalk pavers (+ mossy variant).
	for variant in 2:
		at(6 + variant, 0)
		fill_noise(Color(0.29, 0.29, 0.31), 0.018)
		for py in 2:
			for px in 2:
				var tint := rng.randf_range(-0.025, 0.025)
				rect(px * 32 + 1, py * 32 + 1, 30, 30, Color(0.5 + tint, 0.5 + tint, 0.52 + tint, 0.06))
				rect(px * 32 + 1, py * 32 + 1, 30, 1, Color(1, 1, 1, 0.08))
				rect(px * 32 + 1, py * 32 + 30, 30, 1, Color(0, 0, 0, 0.18))
		for k in [0, 32]:
			rect(k, 0, 1, 64, Color(0.13, 0.13, 0.15))
			rect(0, k, 64, 1, Color(0.13, 0.13, 0.15))
		if variant == 1:
			crack(Vector2(20, 40), 26, Color(0.08, 0.08, 0.09, 0.9))
			for i in 60:
				var along := rng.randi_range(0, 63)
				var k: int = [0, 32].pick_random()
				var p := Vector2(along, k) if rng.randf() < 0.5 else Vector2(k, along)
				disc(p.x + rng.randf_range(-1.5, 1.5), p.y + rng.randf_range(-1.5, 1.5), rng.randf_range(0.8, 2.0),
					Color(0.22 + rng.randf() * 0.1, 0.38 + rng.randf() * 0.12, 0.16, 0.9))

	# Row 1.
	at(0, 1); _asphalt(1)
	for i in 9:
		chunk(rng.randf_range(6, 58), rng.randf_range(6, 58), rng.randf_range(2.5, 6), Color(0.33 + rng.randf() * 0.08, 0.32, 0.33))

	at(1, 1); _asphalt(0)
	ellipse(33, 34, 22, 15, Color(0.05, 0.05, 0.07, 0.75), 0.35)
	ring(33, 34, 13, 2.0, Color(0.45, 0.25, 0.6, 0.18))
	ring(33, 34, 9, 1.5, Color(0.2, 0.55, 0.5, 0.15))

	at(2, 1); _asphalt(0)
	for bx in range(4, 64, 16):
		for y in range(4, 60):
			for x in range(bx, bx + 9):
				put(x, y, _worn(Color(0.78, 0.78, 0.74, 0.75), 0.8))

	at(3, 1); _asphalt(1)
	disc(32, 32, 28, Color(0.03, 0.02, 0.02, 0.8), 20)
	for i in 14:
		disc(rng.randf_range(16, 48), rng.randf_range(16, 48), rng.randf_range(0.6, 1.3), Color(1.0, 0.45, 0.1, rng.randf_range(0.4, 0.9)))

	at(4, 1); _asphalt(2)
	for i in 10:
		var c := Vector2(rng.randf_range(8, 56), rng.randf_range(8, 56))
		for j in 8:
			disc(c.x + rng.randf_range(-5, 5), c.y + rng.randf_range(-5, 5), rng.randf_range(1.0, 2.6),
				Color(0.2 + rng.randf() * 0.1, 0.36 + rng.randf() * 0.14, 0.15, 0.9))

	at(5, 1); _asphalt(0)
	ellipse(32, 33, 25, 15, Color(0.06, 0.1, 0.17, 0.92), 0.18)
	line(Vector2(18, 29), Vector2(34, 27), Color(0.35, 0.9, 1.0, 0.5), 1.5)
	line(Vector2(38, 38), Vector2(46, 37), Color(1.0, 0.35, 0.75, 0.45), 1.5)

	at(6, 1); _asphalt(0)
	disc(33, 34, 22, Color(0, 0, 0, 0.4))
	disc(32, 32, 21, Color(0.22, 0.22, 0.25))
	ring(32, 32, 19.5, 2.0, Color(0.12, 0.12, 0.14))
	for k in range(-15, 16, 6):
		line(Vector2(32 + k, 32 - sqrt(max(0.0, 225.0 - k * k))), Vector2(32 + k, 32 + sqrt(max(0.0, 225.0 - k * k))), Color(0.14, 0.14, 0.16), 1.5)
	ring(32, 32, 21, 1.0, Color(0.4, 0.4, 0.45, 0.7))

	at(7, 1); _asphalt(0)
	for y in range(6, 58):
		for x in range(29, 35):
			put(x, y, _worn(Color(0.86, 0.68, 0.18, 0.85)))


# --- roofs -----------------------------------------------------------------------------------------

const ROOF := Color(0.33, 0.34, 0.38)


func _roof_base() -> void:
	fill_noise(ROOF, 0.018)
	for i in 2:
		var r := rng.randf_range(8, 14)
		disc(rng.randf_range(r, T - r), rng.randf_range(r, T - r), r, Color(0.15, 0.14, 0.13, 0.12), r)
	for i in 30:
		put(rng.randi_range(0, 63), rng.randi_range(0, 63), Color(0.46, 0.47, 0.52, 0.7))


func _box(x: int, y: int, w: int, h: int, top: Color, height: int) -> void:
	rect(x + 3, y + 4, w + height, h + height, Color(0, 0, 0, 0.35))
	noisy_rect(x, y + height, w, h, top.darkened(0.35), 0.015)
	noisy_rect(x, y, w, h, top, 0.015)
	rect(x, y, w, 1, top.lightened(0.3))
	rect(x, y, 1, h, top.lightened(0.15))


func _roofs() -> void:
	at(0, 2); _roof_base()
	at(1, 2); _roof_base()
	_box(20, 18, 24, 18, Color(0.42, 0.44, 0.48), 6)
	for x in range(23, 42, 4):
		rect(x, 21, 2, 12, Color(0.18, 0.19, 0.22))

	at(2, 2); _roof_base()
	var hole := PackedVector2Array([Vector2(14, 20), Vector2(28, 12), Vector2(44, 16), Vector2(52, 32),
		Vector2(46, 48), Vector2(30, 52), Vector2(16, 42), Vector2(10, 30)])
	var edge := PackedVector2Array()
	for p in hole:
		edge.append((p - Vector2(32, 32)) * 1.18 + Vector2(32, 32))
	poly(edge, Color(0.24, 0.24, 0.27))
	poly(hole, Color(0.03, 0.03, 0.05))
	for i in 5:
		line(Vector2(rng.randf_range(12, 24), rng.randf_range(16, 48)), Vector2(rng.randf_range(40, 52), rng.randf_range(16, 48)),
			Color(0.55, 0.3, 0.18, 0.9), 1.5)
	for i in 6:
		chunk(rng.randf_range(10, 54), rng.randf_range(8, 56), rng.randf_range(2, 4), Color(0.38, 0.38, 0.42))

	at(3, 2); _roof_base()
	_box(14, 14, 32, 26, Color(0.5, 0.52, 0.55), 7)
	disc(30, 27, 10, Color(0.12, 0.13, 0.15))
	for i in 4:
		var a := TAU * i / 4 + 0.4
		line(Vector2(30, 27), Vector2(30, 27) + Vector2.from_angle(a) * 9, Color(0.4, 0.42, 0.46), 3.0)
	disc(30, 27, 2.5, Color(0.6, 0.62, 0.66))

	at(4, 2); _roof_base()
	for i in 12:
		chunk(rng.randf_range(10, 54), rng.randf_range(10, 54), rng.randf_range(3, 7), Color(0.4 + rng.randf() * 0.06, 0.4, 0.42))

	at(5, 2); _roof_base()
	line(Vector2(34, 44), Vector2(46, 50), Color(0, 0, 0, 0.35), 3.0)
	line(Vector2(32, 44), Vector2(32, 20), Color(0.5, 0.52, 0.56), 3.0)
	line(Vector2(26, 30), Vector2(38, 30), Color(0.45, 0.47, 0.5), 2.0)
	disc(32, 44, 5, Color(0.3, 0.31, 0.35))
	disc(32, 19, 10, Color(1.0, 0.15, 0.1, 0.35), 10)
	disc(32, 19, 3, Color(1.0, 0.35, 0.3))


# --- facades (vertical faces seen at the 3/4 angle) --------------------------------------------------

const WALL := Color(0.21, 0.22, 0.27)


func _wall_base(base := WALL) -> void:
	fill_noise(base, 0.016)
	rect(0, 0, 64, 2, base.lightened(0.18))
	rect(0, 2, 64, 1, Color(0, 0, 0, 0.35))
	for i in 3:
		crack(Vector2(rng.randf_range(4, 60), rng.randf_range(6, 60)), rng.randi_range(6, 12), Color(0.08, 0.08, 0.1, 0.6), false)


func _window(x: int, y: int, w: int, h: int, kind: String) -> void:
	rect(x - 2, y - 2, w + 4, h + 4, Color(0.33, 0.34, 0.4))
	match kind:
		"dark":
			rect(x, y, w, h, Color(0.05, 0.07, 0.11))
			line(Vector2(x + 2, y + h - 4), Vector2(x + w - 4, y + 3), Color(0.5, 0.65, 0.8, 0.22), 2.0)
		"cyan", "warm":
			var c := Color(0.35, 0.85, 1.0) if kind == "cyan" else Color(1.0, 0.72, 0.35)
			rect(x, y, w, h, c.darkened(0.25))
			rect(x + 1, y + 1, w - 2, h / 2, c)
			disc(x + w / 2.0, y + h / 2.0, w * 0.9, Color(c, 0.18), w * 0.9)
			rect(x, y + h / 2, w, 1, c.darkened(0.5))
		"broken":
			rect(x, y, w, h, Color(0.02, 0.02, 0.04))
			poly(PackedVector2Array([Vector2(x, y), Vector2(x + w * 0.6, y), Vector2(x, y + h * 0.4)]), Color(0.55, 0.75, 0.9, 0.35))
			poly(PackedVector2Array([Vector2(x + w, y + h), Vector2(x + w * 0.3, y + h), Vector2(x + w, y + h * 0.55)]), Color(0.55, 0.75, 0.9, 0.3))
	rect(x - 3, y + h + 2, w + 6, 2, Color(0.42, 0.43, 0.48))


func _facades() -> void:
	at(0, 3); _wall_base()
	_window(10, 16, 16, 26, "dark"); _window(38, 16, 16, 26, "dark")
	at(1, 3); _wall_base()
	_window(10, 16, 16, 26, "cyan"); _window(38, 16, 16, 26, "broken")
	at(2, 3); _wall_base()
	var hole := PackedVector2Array([Vector2(12, 12), Vector2(30, 8), Vector2(50, 18), Vector2(54, 40), Vector2(36, 54),
		Vector2(16, 48), Vector2(8, 30)])
	poly(hole, Color(0.03, 0.03, 0.05))
	for i in 4:
		line(Vector2(rng.randf_range(10, 20), rng.randf_range(14, 50)), Vector2(rng.randf_range(44, 54), rng.randf_range(14, 50)),
			Color(0.55, 0.3, 0.18), 1.5)
	at(3, 3); _wall_base(WALL.darkened(0.05))
	rect(46, 3, 6, 61, Color(0.45, 0.28, 0.2))
	rect(46, 3, 2, 61, Color(0.6, 0.38, 0.26))
	for y in [16, 40]:
		rect(12, y, 22, 10, Color(0.12, 0.13, 0.16))
		for x in range(13, 34, 3):
			rect(x, y + 1, 1, 8, Color(0.3, 0.31, 0.36))
	at(4, 3); _wall_base(WALL.darkened(0.1))
	disc(32, 30, 34, Color(1.0, 0.2, 0.7, 0.12), 30)
	var x := 6
	while x < 58:
		var seg := rng.randi_range(3, 7)
		if rng.randf() < 0.8:
			rect(x, 24, seg, 12, Color(1.0, 0.3, 0.75))
			rect(x, 26, seg, 3, Color(1.0, 0.75, 0.95))
		x += seg + 2
	at(5, 3); _wall_base()
	_window(10, 16, 16, 26, "warm"); _window(38, 16, 16, 26, "dark")

	# Ground floor, with contact shadow at the bottom.
	for i in 5:
		at(i, 4)
		_wall_base(WALL.darkened(0.08))
		match i:
			0:
				_window(6, 10, 52, 38, "broken")
				for j in 5:
					chunk(rng.randf_range(8, 56), rng.randf_range(52, 60), rng.randf_range(1.5, 3), Color(0.55, 0.75, 0.9, 0.7))
			1:
				rect(6, 8, 52, 50, Color(0.2, 0.19, 0.18))
				for y in range(8, 58, 4):
					noisy_rect(6, y, 52, 2, Color(0.36, 0.33, 0.3), 0.02)
				for j in 8:
					disc(rng.randf_range(8, 56), rng.randf_range(10, 56), rng.randf_range(1.5, 4), Color(0.5, 0.25, 0.1, 0.55), 2)
			2:
				rect(18, 10, 28, 50, Color(0.33, 0.34, 0.4))
				rect(21, 13, 22, 47, Color(0.08, 0.09, 0.12))
				rect(40, 34, 2, 4, Color(0.6, 0.6, 0.65))
				disc(32, 6, 6, Color(0.3, 1.0, 0.5, 0.35), 6)
				rect(29, 4, 6, 3, Color(0.5, 1.0, 0.6))
			3:
				for j in 4:
					crack(Vector2(rng.randf_range(10, 54), rng.randf_range(10, 50)), 18, Color(0.06, 0.06, 0.08, 0.8))
				rect(8, 4, 5, 60, Color(0.3, 0.32, 0.36))
			4:
				for j in 16:
					chunk(rng.randf_range(4, 60), rng.randf_range(34, 62), rng.randf_range(3, 8), Color(0.36 + rng.randf() * 0.05, 0.36, 0.39))
		for y in range(56, 64):
			rect(0, y, 64, 1, Color(0, 0, 0, (y - 55) * 0.06))


# --- props: boundary barrier, wrecks, blocks ---------------------------------------------------------

func _props() -> void:
	at(0, 5)
	fill_noise(Color(0.4, 0.4, 0.43), 0.016)
	rect(0, 0, 64, 3, Color(0.55, 0.55, 0.58))
	rect(31, 0, 2, 64, Color(0.25, 0.25, 0.28))
	for i in 2:
		crack(Vector2(rng.randf_range(8, 56), rng.randf_range(8, 56)), 10, Color(0.15, 0.15, 0.17, 0.8), false)

	at(1, 5)
	fill_noise(Color(0.27, 0.27, 0.3), 0.016)
	rect(0, 0, 64, 2, Color(0.5, 0.5, 0.53))
	for y in range(30, 46):
		for x in 64:
			var stripe := int((x + y) / 8.0) % 2 == 0
			put(x, y, _worn(Color(0.95, 0.75, 0.1) if stripe else Color(0.08, 0.08, 0.08), 0.85))
	for bx in [12, 52]:
		disc(bx, 16, 2.5, Color(0.55, 0.55, 0.6))
	for y in range(56, 64):
		rect(0, y, 64, 1, Color(0, 0, 0, (y - 55) * 0.06))

	_car(2, Color(0.46, 0.16, 0.12), false)
	_car(4, Color(0.22, 0.32, 0.42), true)

	at(6, 5)
	ellipse(35, 38, 30, 16, Color(0, 0, 0, 0.35), 0.4)
	noisy_rect(4, 18, 56, 28, Color(0.5, 0.5, 0.52), 0.02)
	rect(4, 18, 56, 3, Color(0.65, 0.65, 0.68))
	rect(4, 43, 56, 3, Color(0.35, 0.35, 0.38))
	for x in range(6, 58):
		if int(x / 7.0) % 2 == 0:
			rect(x, 26, 1, 10, Color(0.95, 0.4, 0.1, 0.9))

	at(7, 5)
	ellipse(36, 40, 30, 20, Color(0, 0, 0, 0.35), 0.4)
	noisy_rect(8, 14, 48, 36, Color(0.18, 0.34, 0.24), 0.02)
	rect(8, 14, 48, 2, Color(0.3, 0.5, 0.36))
	rect(31, 14, 2, 36, Color(0.1, 0.2, 0.14))
	for j in 6:
		disc(rng.randf_range(10, 54), rng.randf_range(16, 48), rng.randf_range(2, 4), Color(0.5, 0.28, 0.12, 0.6), 2)


func _car(tx: int, paint: Color, door_open: bool) -> void:
	at(tx, 5, 2, 1)
	ellipse(68, 38, 60, 24, Color(0, 0, 0, 0.4), 0.3)
	for p: Vector2 in [Vector2(24, 12), Vector2(100, 12), Vector2(24, 52), Vector2(100, 52)]:
		ellipse(p.x, p.y, 10, 5, Color(0.06, 0.06, 0.07))
	var body := PackedVector2Array([Vector2(8, 22), Vector2(16, 12), Vector2(112, 12), Vector2(122, 22),
		Vector2(122, 42), Vector2(112, 52), Vector2(16, 52), Vector2(8, 42)])
	poly(body, paint)
	poly(PackedVector2Array([Vector2(40, 16), Vector2(92, 16), Vector2(92, 48), Vector2(40, 48)]), paint.lightened(0.12))
	poly(PackedVector2Array([Vector2(30, 17), Vector2(40, 16), Vector2(40, 48), Vector2(30, 47)]), Color(0.04, 0.05, 0.07))
	poly(PackedVector2Array([Vector2(92, 16), Vector2(100, 18), Vector2(100, 46), Vector2(92, 48)]), Color(0.04, 0.05, 0.07))
	rect(16, 12, 96, 1, paint.lightened(0.35))
	for j in 7:
		disc(rng.randf_range(20, 110), rng.randf_range(16, 48), rng.randf_range(4, 11), Color(0.02, 0.02, 0.02, 0.35), 6)
	for j in 10:
		disc(rng.randf_range(12, 118), rng.randf_range(14, 50), rng.randf_range(1, 3), Color(0.5, 0.26, 0.1, 0.7), 1.5)
	if door_open:
		rect(52, 49, 22, 6, Color(0.03, 0.03, 0.04))
		line(Vector2(52, 53), Vector2(44, 62), paint.darkened(0.2), 3.0)


# --- overlays (building rims + shadows) ---------------------------------------------------------------

func _overlays() -> void:
	at(0, 6)
	rect(0, 0, 64, 4, Color(0.56, 0.58, 0.64))
	rect(0, 4, 64, 1, Color(0, 0, 0, 0.25))
	at(1, 6)
	rect(0, 0, 3, 64, Color(0.48, 0.5, 0.56))
	at(2, 6)
	rect(61, 0, 3, 64, Color(0.17, 0.18, 0.21))
	at(3, 6)
	rect(0, 0, 64, 64, Color(0, 0, 0, 0.3))
	at(4, 6)
	for x in 44:
		rect(x, 0, 1, 64, Color(0, 0, 0, 0.4 * (1.0 - x / 44.0)))
	at(5, 6)
	for y in 64:
		for x in 44:
			var a := 0.4 * (1.0 - x / 44.0) * clampf((y - x * 0.8) / 18.0, 0.0, 1.0)
			put(x, y, Color(0, 0, 0, a))


# --- decor (non-solid) ------------------------------------------------------------------------------

func _decor() -> void:
	at(0, 7)
	for i in 9:
		chunk(rng.randf_range(8, 56), rng.randf_range(8, 56), rng.randf_range(2, 5), Color(0.36 + rng.randf() * 0.08, 0.36, 0.38))

	at(1, 7)
	for i in 6:
		var c := Vector2(rng.randf_range(10, 54), rng.randf_range(10, 54))
		var a := rng.randf() * PI
		var d := Vector2.from_angle(a) * rng.randf_range(4, 7)
		var n := d.orthogonal().normalized() * rng.randf_range(3, 5)
		poly(PackedVector2Array([c - d - n, c + d - n, c + d + n, c - d + n]), Color(0.75, 0.73, 0.66, 0.85))
	for i in 3:
		var c := Vector2(rng.randf_range(10, 54), rng.randf_range(10, 54))
		ellipse(c.x, c.y, 5, 3, Color(0.7, 0.2, 0.15))
		ellipse(c.x - 1, c.y - 1, 3, 1.5, Color(0.9, 0.85, 0.8, 0.7))

	at(2, 7)
	line(Vector2(10, 56), Vector2(54, 16), Color(0, 0, 0, 0.35), 5.0)
	line(Vector2(6, 52), Vector2(50, 12), Color(0.45, 0.47, 0.52), 4.0)
	line(Vector2(6, 51), Vector2(50, 11), Color(0.62, 0.64, 0.7), 1.0)
	ellipse(52, 11, 8, 5, Color(0.3, 0.31, 0.35))
	ellipse(52, 11, 5, 3, Color(0.5, 0.9, 1.0, 0.8))
	disc(52, 11, 12, Color(0.4, 0.9, 1.0, 0.12), 12)

	at(3, 7)
	disc(34, 34, 14, Color(0, 0, 0, 0.35))
	disc(32, 32, 13, Color(0.08, 0.08, 0.09))
	for i in 12:
		var a := TAU * i / 12
		line(Vector2(32, 32) + Vector2.from_angle(a) * 10, Vector2(32, 32) + Vector2.from_angle(a) * 13, Color(0.18, 0.18, 0.2), 1.5)
	disc(32, 32, 6, Color(0.3, 0.31, 0.34))
	disc(32, 32, 3, Color(0.05, 0.05, 0.06))

	at(4, 7)
	for i in 3:
		crack(Vector2(32, 32), 30, Color(0.04, 0.04, 0.06, 0.95))

	at(5, 7)
	for i in 5:
		var c := Vector2(rng.randf_range(10, 54), rng.randf_range(10, 54))
		for j in 7:
			var a := -PI / 2 + rng.randf_range(-0.9, 0.9)
			line(c, c + Vector2.from_angle(a) * rng.randf_range(4, 9), Color(0.3 + rng.randf() * 0.1, 0.5 + rng.randf() * 0.15, 0.2), 1.5)

	at(6, 7)
	var prev := Vector2(0, 30)
	for i in range(1, 17):
		var p := Vector2(i * 4.0, 30 + sin(i * 0.7) * 10.0)
		line(prev, p, Color(0.06, 0.06, 0.07), 4.0)
		prev = p
	for i in 3:
		var t := rng.randf_range(10, 54)
		var p := Vector2(t, 30 + sin(t / 4.0 * 0.7) * 10.0)
		disc(p.x, p.y, 8, Color(0.4, 0.95, 1.0, 0.3), 8)
		disc(p.x, p.y, 2, Color(0.8, 1.0, 1.0))

	at(7, 7)
	ellipse(36, 40, 18, 9, Color(0, 0, 0, 0.35), 0.5)
	poly(PackedVector2Array([Vector2(14, 34), Vector2(50, 26), Vector2(50, 44)]), Color(1.0, 0.45, 0.1))
	poly(PackedVector2Array([Vector2(28, 31), Vector2(36, 29), Vector2(36, 41), Vector2(28, 39)]), Color(0.95, 0.95, 0.9))
	rect(48, 22, 6, 26, Color(0.15, 0.15, 0.17))
