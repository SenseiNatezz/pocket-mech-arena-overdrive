class_name MapLife
extends Node2D
## Life on a painted map (ScenicArena adds one), all drawn in code:
##   DETAILS  small things scattered over the open floor so it isn't one flat sheet - snow drifts, ice cracks
##            and frozen puddles on the ice; sand ripples in the desert; cables, skid marks and stains on the
##            decks; rubble, leaves, ash... Picked per map by its weather, placed by a fixed seed (the same
##            every run), only on walkable floor and never on obstacles, vents or the spawn. Flat, no collision.
##   LIGHTS   the lamps, lava, crystals and beacons PAINTED on the map (environment/map_lights.gd, found by
##            art_src/maps/find_lights.py) come alive: lamps and crystals breathe, fire flickers, red
##            beacons blink.
##   MOOD     a colour mood per map: the screen edges fall off to a dark tint and a faint colour wash lies
##            over the picture (cold blue on the ice, hot orange in the forge...).

const GLOW := preload("res://assets/fx/glow.tres")
const MOOD_SHADER := preload("res://environment/map_mood.gdshader")

## Per weather: how many details, and [kind, weight] - see Details._draw_one for the kinds.
const THEMES := {
	"snow": {"count": 260, "kinds": [["drift", 5], ["crack", 4], ["puddle", 1]],
		"drift": Color(0.96, 0.98, 1.0, 0.5), "crack": Color(0.06, 0.14, 0.3, 0.6), "puddle": Color(0.34, 0.56, 0.86, 0.26)},
	"pollen": {"count": 110, "kinds": [["leaves", 4], ["puddle", 2], ["crack", 1], ["rubble", 1]],
		"crack": Color(0.08, 0.1, 0.04, 0.4), "puddle": Color(0.08, 0.2, 0.14, 0.34), "rubble": Color(0.42, 0.44, 0.34)},
	"spores": {"count": 90, "kinds": [["crack", 3], ["puddle", 2], ["rubble", 1], ["stain", 1]],
		"crack": Color(0.03, 0.02, 0.1, 0.5), "puddle": Color(0.2, 0.7, 0.75, 0.1), "rubble": Color(0.26, 0.24, 0.36)},
	"wind": {"count": 70, "kinds": [["skid", 3], ["stain", 3], ["cable", 1], ["scrap", 1]]},
	"dust": {"count": 70, "kinds": [["rubble", 3], ["crack", 2], ["drift", 2], ["stain", 1]],
		"drift": Color(0.7, 0.62, 0.52, 0.2), "crack": Color(0.05, 0.04, 0.05, 0.45), "rubble": Color(0.4, 0.37, 0.36)},
	"embers": {"count": 90, "kinds": [["crack", 4], ["drift", 2], ["rubble", 1], ["stain", 2]],
		"drift": Color(0.1, 0.09, 0.09, 0.3), "crack": Color(0.04, 0.02, 0.02, 0.6), "crack_glow": Color(1.0, 0.45, 0.1, 0.5),
		"rubble": Color(0.24, 0.2, 0.19)},
	"sandstorm": {"count": 240, "kinds": [["ripple", 5], ["drift", 3], ["rubble", 3]],
		"drift": Color(1.0, 0.88, 0.62, 0.42), "rubble": Color(0.66, 0.4, 0.24)},
	"space": {"count": 120, "kinds": [["skid", 3], ["stain", 2], ["cable", 2], ["scrap", 1]]},
}
## Per weather: the dark tint at the screen edges (alpha = how dark the corners get) and the colour wash.
const MOODS := {
	"snow": [Color(0.02, 0.07, 0.2, 0.42), Color(0.55, 0.78, 1.0, 0.05)],
	"pollen": [Color(0.02, 0.08, 0.03, 0.4), Color(0.95, 1.0, 0.6, 0.035)],
	"spores": [Color(0.06, 0.0, 0.14, 0.42), Color(0.5, 0.4, 1.0, 0.045)],
	"wind": [Color(0.02, 0.04, 0.12, 0.4), Color(1.0, 0.72, 0.42, 0.03)],
	"dust": [Color(0.07, 0.03, 0.1, 0.4), Color(1.0, 0.8, 0.62, 0.035)],
	"embers": [Color(0.18, 0.03, 0.0, 0.42), Color(1.0, 0.45, 0.15, 0.055)],
	"sandstorm": [Color(0.16, 0.07, 0.0, 0.36), Color(1.0, 0.82, 0.5, 0.035)],
	"space": [Color(0.0, 0.02, 0.08, 0.44), Color(0.7, 0.85, 1.0, 0.03)],
}
## Maps whose painting is toned down a touch (a flat white deck); ScenicArena reads it for the art's shade.
const SHADES := {"space": Color(0.86, 0.89, 0.96)}


## `layout` = the map's layout script instance, `k` = world px per map px, `map_key` = "arctic", "dock"...
func setup(layout: Object, k: float, weather: String, map_key: String, seed_text: String) -> void:
	if OS.get_cmdline_user_args().has("--no-map-life"):  # (debug: before / after comparisons)
		return
	if THEMES.has(weather):
		var d := Details.new()
		d.name = "Details"
		d.build(layout, k, THEMES[weather], hash(seed_text))
		add_child(d)
	var table: Array = MapLights.TABLES.get(map_key, [])
	if not table.is_empty():
		var l := Lights.new()
		l.name = "Lights"
		l.table = table
		l.k = k
		add_child(l)
	if MOODS.has(weather):
		var layer := CanvasLayer.new()
		layer.name = "Mood"
		layer.layer = 2  # (over the world, under the HUD)
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = MOOD_SHADER
		mat.set_shader_parameter("edge", MOODS[weather][0])
		mat.set_shader_parameter("wash", MOODS[weather][1])
		rect.material = mat
		layer.add_child(rect)
		add_child(layer)


## The painted lights, animated: additive glows over the painting (and over anything standing in the light).
class Lights:
	extends Node2D
	var table: Array = []
	var k := 1.0
	var _t := 0.0

	func _ready() -> void:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		z_as_relative = false
		z_index = 7

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		# Only the lights on screen.
		var view := (get_viewport().get_canvas_transform().affine_inverse() * get_viewport_rect()).grow(260.0)
		for i in table.size():
			var l: Array = table[i]
			var p := Vector2(l[0], l[1]) * k
			if not view.has_point(p):
				continue
			var r: float = l[2] * k
			var ph := i * 1.7
			var a := 0.0
			match int(l[6]):
				1:  # fire: a restless flicker
					a = 0.1 + 0.1 * (0.5 + 0.5 * sin(_t * 2.1 + ph)) + 0.05 * sin(_t * 9.3 + ph * 3.0) + 0.03 * sin(_t * 17.0 + ph)
				2:  # beacon: a short flash, then dark
					var cyc := fposmod(_t * 0.75 + ph * 0.37, 1.0)
					a = 0.9 * clampf(1.0 - cyc / 0.22, 0.0, 1.0)
					r = 46.0 * k
					if a > 0.0:
						draw_texture_rect(GLOW, Rect2(p - Vector2.ONE * r * 0.3, Vector2.ONE * r * 0.6), false, Color(1, 0.9, 0.85, a))
				_:  # lamp / crystal: slow breathing
					a = 0.05 + 0.17 * (0.5 + 0.5 * sin(_t * 1.25 + ph))
			if a > 0.004:
				draw_texture_rect(GLOW, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(l[3], l[4], l[5], a))


## The floor details (just above the painting): places them, then hands them to Chunks to draw.
class Details:
	extends Node2D
	const CHUNK := 700.0
	var _items: Array = []  # [kind, pos, rot, scale, seed]

	func _ready() -> void:
		z_as_relative = false
		z_index = -9

	func build(layout: Object, k: float, theme: Dictionary, seed_value: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var walk: PackedVector2Array = layout.walkable
		var box := Rect2(walk[0], Vector2.ZERO)
		for p in walk:
			box = box.expand(p)
		# Keep clear of the things that sit on the floor.
		var avoid: Array[Vector2] = [layout.spawn, layout.boss_spawn, layout.repair_station]
		for key in ["vents", "barrels", "crates", "destructible_cover"]:
			if key in layout:
				avoid.append_array(layout.get(key))
		var total := 0.0
		for kd: Array in theme.kinds:
			total += kd[1]
		var tries := 0
		while _items.size() < int(theme.count) and tries < 12000:
			tries += 1
			var p := Vector2(rng.randf_range(box.position.x, box.end.x), rng.randf_range(box.position.y, box.end.y))
			if not Geometry2D.is_point_in_polygon(p, walk):
				continue
			var blocked := false
			for o: PackedVector2Array in layout.obstacles:
				if Geometry2D.is_point_in_polygon(p, o):
					blocked = true
					break
			for a in avoid:
				if a.distance_to(p) < 80.0:
					blocked = true
					break
			if blocked:
				continue
			var roll := rng.randf() * total
			var kind := ""
			for kd: Array in theme.kinds:
				roll -= kd[1]
				if roll <= 0.0:
					kind = kd[0]
					break
			_items.append([kind, p * k, rng.randf() * TAU, rng.randf_range(0.9, 1.6), rng.randi()])
		# One child per CHUNK px square, so only the details near the screen are drawn.
		var chunks := {}
		for it: Array in _items:
			var cell := Vector2i((it[1] / CHUNK).floor())
			if not chunks.has(cell):
				var c := Chunk.new()
				c.theme = theme
				chunks[cell] = c
				add_child(c)
			chunks[cell].items.append(it)


## One square of floor details: built once, drawn once (static).
class Chunk:
	extends Node2D
	var items: Array = []
	var theme := {}
	var _theme: Dictionary:
		get: return theme
	var _items: Array:
		get: return items

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		for it: Array in _items:
			rng.seed = it[4]
			_draw_one(it[0], it[1], it[2], it[3], rng)
		draw_set_transform(Vector2.ZERO)

	func _blob(rng: RandomNumberGenerator, rx: float, ry: float, n := 28) -> PackedVector2Array:
		var pts := PackedVector2Array()
		# A smooth, slightly lumpy outline (two slow waves round the edge, not per-point noise).
		var p1 := rng.randf() * TAU
		var p2 := rng.randf() * TAU
		var lump := rng.randf_range(0.08, 0.2)
		for i in n:
			var a := TAU * i / n
			pts.append(Vector2(cos(a) * rx, sin(a) * ry) * (1.0 + lump * sin(a * 2.0 + p1) + lump * 0.6 * sin(a * 3.0 + p2)))
		return pts

	func _draw_one(kind: String, pos: Vector2, rot: float, s: float, rng: RandomNumberGenerator) -> void:
		draw_set_transform(pos, rot, Vector2(s, s))
		# The sun is up-left on every map: in this item's own (turned) space, light comes from `sun`.
		var sun := Vector2(-1, -1).normalized().rotated(-rot)
		match kind:
			"drift":  # a low heap (snow, sand, dust, ash): shaded side, body, lit crest
				var col: Color = _theme.get("drift", Color(1, 1, 1, 0.2))
				for i in 3:
					var w := rng.randf_range(60.0, 120.0)
					var h := w * rng.randf_range(0.55, 0.8)
					var at := Vector2(rng.randf_range(-45.0, 45.0), rng.randf_range(-22.0, 22.0))
					draw_texture_rect(GLOW, Rect2(at - sun * 6.0 - Vector2(w, h) * 0.5, Vector2(w, h)), false, Color(0, 0.02, 0.08, 0.12))
					draw_texture_rect(GLOW, Rect2(at - Vector2(w, h) * 0.5, Vector2(w, h)), false, Color(col, col.a * 0.6))
			"crack":  # a branching crack: a dark line with a thin lit lip
				var col: Color = _theme.get("crack", Color(0, 0, 0, 0.45))
				var glow: Color = _theme.get("crack_glow", Color(0, 0, 0, 0))
				var lines: Array[PackedVector2Array] = []
				var main := PackedVector2Array([Vector2.ZERO])
				var dir := Vector2.RIGHT
				for i in rng.randi_range(4, 7):
					dir = dir.rotated(rng.randf_range(-0.6, 0.6))
					main.append(main[main.size() - 1] + dir * rng.randf_range(16.0, 34.0))
				lines.append(main)
				for b in rng.randi_range(1, 2):
					var at := main[rng.randi_range(1, main.size() - 2)]
					var bd := Vector2.RIGHT.rotated(rng.randf_range(-1.4, 1.4) + (PI * 0.5 if b == 0 else -PI * 0.5) * 0.6)
					var br := PackedVector2Array([at])
					for i in rng.randi_range(2, 3):
						bd = bd.rotated(rng.randf_range(-0.5, 0.5))
						br.append(br[br.size() - 1] + bd * rng.randf_range(12.0, 24.0))
					lines.append(br)
				for ln in lines:
					var lip := PackedVector2Array()
					for p in ln:
						lip.append(p - sun * 1.4)
					draw_polyline(lip, Color(1, 1, 1, col.a * 0.3), 1.0, true)
					draw_polyline(ln, col, 1.8, true)
					if glow.a > 0.0:
						draw_polyline(ln, glow, 0.9, true)
			"puddle":  # still water / ice: a dark glassy patch, a lit rim on the far side, a streak of sky
				var col: Color = _theme.get("puddle", Color(0.2, 0.3, 0.4, 0.3))
				var rx := rng.randf_range(34.0, 62.0)
				var ry := rx * rng.randf_range(0.5, 0.75)
				var pts := _blob(rng, rx, ry)
				# (a soft-edged slick: a glow of the colour under a fainter hard shape, so it has no sticker outline)
				draw_texture_rect(GLOW, Rect2(-Vector2(rx, ry) * 1.25, Vector2(rx, ry) * 2.5), false, Color(col, col.a * 0.9))
				draw_colored_polygon(pts, Color(col, col.a * 0.45))
				var shine := PackedVector2Array()
				for p in _blob(rng, rx * 0.45, ry * 0.16, 16):
					shine.append(p + sun * ry * 0.3)
				draw_colored_polygon(shine, Color(1, 1, 1, col.a * 0.32))
			"scrap", "rubble":  # torn plates / broken stone: each with a drop shadow and a lit edge
				var stone := kind == "rubble"
				var base: Color = _theme.get("rubble", Color(0.4, 0.4, 0.42)) if stone else Color(0.26, 0.27, 0.3)
				draw_texture_rect(GLOW, Rect2(Vector2(-34, -30), Vector2(68, 60)), false, Color(0, 0, 0, 0.18))
				for i in rng.randi_range(4, 7):
					var size := rng.randf_range(5.0, 13.0) * (0.8 if stone else 1.0)
					var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 26.0)
					var piece := PackedVector2Array()
					for p in _blob(rng, size, size * rng.randf_range(0.6, 0.9), 9 if stone else rng.randi_range(4, 5)):
						piece.append(p + at)
					var shadow := PackedVector2Array()
					for p in piece:
						shadow.append(p - sun * 3.0)
					draw_colored_polygon(shadow, Color(0, 0, 0, 0.32))
					var c := base * rng.randf_range(0.7, 1.15)
					draw_colored_polygon(piece, Color(c.r, c.g, c.b, 0.95))
					if stone:  # the lit top of the rock
						var top := PackedVector2Array()
						for p in piece:
							top.append(at + (p - at) * 0.6 + sun * size * 0.22)
						draw_colored_polygon(top, Color(c.lightened(0.22), 0.9))
					else:
						draw_polyline(PackedVector2Array([piece[0] + sun, piece[1] + sun, piece[2] + sun]), Color(1, 1, 1, 0.22), 1.2, true)
			"ripple":  # wind ripples in sand: a few curved ridges, lit on one side and shaded on the other
				var n := rng.randi_range(5, 8)
				var w := rng.randf_range(110.0, 200.0)
				for i in n:
					var y := (i - n * 0.5) * 11.0
					var ridge := PackedVector2Array()
					var bend := rng.randf_range(-10.0, 10.0)
					var len := w * rng.randf_range(0.6, 1.0)
					for j in 9:
						var u := j / 8.0 - 0.5
						ridge.append(Vector2(u * len, y + bend * (1.0 - 4.0 * u * u) + sin(u * 9.0 + i) * 2.0))
					var dark := PackedVector2Array()
					for p in ridge:
						dark.append(p - sun * 2.2)
					draw_polyline(dark, Color(0.35, 0.16, 0.04, 0.2), 3.0, true)
					draw_polyline(ridge, Color(1.0, 0.94, 0.78, 0.22), 2.0, true)
			"stain":  # oil / scorch stain: a dark soft patch with a darker heart
				var w := rng.randf_range(50.0, 100.0)
				draw_texture_rect(GLOW, Rect2(-Vector2(w, w * 0.7) * 0.5, Vector2(w, w * 0.7)), false, Color(0.02, 0.02, 0.03, 0.26))
				draw_texture_rect(GLOW, Rect2(Vector2(w * 0.08, 0) - Vector2(w, w) * 0.2, Vector2(w, w) * 0.4), false, Color(0, 0, 0, 0.3))
			"skid":  # skid marks: two faint dark tracks curving together
				var len := rng.randf_range(90.0, 190.0)
				var bend := rng.randf_range(-26.0, 26.0)
				for side in [-9.0, 9.0]:
					var tr := PackedVector2Array()
					for j in 10:
						var u := j / 9.0
						tr.append(Vector2(u * len - len * 0.5, side + bend * u * u))
					draw_polyline(tr, Color(0.03, 0.03, 0.05, 0.2), 5.0, true)
			"cable":  # a cable lying on the deck: shadow, the cable, a thin highlight
				var len := rng.randf_range(120.0, 240.0)
				var c1 := Vector2(len * 0.3, rng.randf_range(-60.0, 60.0))
				var c2 := Vector2(len * 0.7, rng.randf_range(-60.0, 60.0))
				var run := PackedVector2Array()
				for j in 17:
					run.append(Vector2.ZERO.bezier_interpolate(c1, c2, Vector2(len, 0), j / 16.0) - Vector2(len * 0.5, 0))
				var shadow := PackedVector2Array()
				var hi := PackedVector2Array()
				for p in run:
					shadow.append(p - sun * 2.5)
					hi.append(p + sun * 0.9)
				draw_polyline(shadow, Color(0, 0, 0, 0.3), 4.0, true)
				draw_polyline(run, Color(0.1, 0.11, 0.14, 0.95), 3.4, true)
				draw_polyline(hi, Color(0.75, 0.8, 0.9, 0.3), 1.0, true)
				draw_circle(run[0], 3.6, Color(0.85, 0.55, 0.15, 0.95))
			"leaves":  # fallen leaves: a loose scatter of small leaf shapes
				for i in rng.randi_range(7, 13):
					var at := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 42.0)
					var c := Color(0.22, 0.4, 0.12).lerp(Color(0.75, 0.62, 0.15), rng.randf()) * rng.randf_range(0.7, 1.1)
					var leaf := PackedVector2Array()
					var lr := rng.randf() * TAU
					var ls := rng.randf_range(4.0, 8.0)
					for p in [Vector2(-1, 0), Vector2(0, -0.45), Vector2(1, 0), Vector2(0, 0.45)]:
						leaf.append(at + (p * ls).rotated(lr))
					var sh := PackedVector2Array()
					for p in leaf:
						sh.append(p - sun * 1.5)
					draw_colored_polygon(sh, Color(0, 0, 0, 0.25))
					draw_colored_polygon(leaf, Color(c.r, c.g, c.b, 0.9))
