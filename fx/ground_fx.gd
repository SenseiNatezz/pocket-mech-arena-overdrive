class_name GroundFx
extends RefCounted
## The ground under the fight (so the painted maps don't read as a flat picture):
##
## LIGHT - one additive layer just above the painted map (z -6: under the mech, the robots and the tall
##   scenery) that the fight lights up: blasts, muzzle flashes, rounds in flight, hits, the beam, thrusters.
##     flash(pos, r, col, power, life)    a light that fades out over `life` seconds (a blast, a hit)
##     glow(key, pos, r, col, power)      a light that stays while it is refreshed every frame (a round in
##                                        flight, a muzzle, thrusters); `key` = who owns it (one light each)
##     glow_line(key, a, b, r, col, power) the same along a line (the beam)
## MARKS - one layer under the fresh blast FX (z -8) that keeps what a fight leaves behind, fading after a
##   while and capped so a long run stays cheap (the layer only redraws when something is added or fades):
##     char_mark(pos, r)                   the charred patch a blast leaves (BlastFx.scorch)
##     wreck(pos, r, tint)                 scrap metal where a robot was destroyed (Enemy.die)
##     footprint(pos, rot, size)           a walking mech's footprint - only on snow and sand (floor_kind)
## ScenicArena calls set_floor() per map; any other scene (Weapon Range, tutorial) gets the defaults.

const GLOW := preload("res://assets/fx/glow.tres")
## "snow" / "sand": footprints show; "" (metal decks, plazas): none.
static var floor_kind := ""
## How strong the floor light is on this map (very pale floors take less: added light washes white ice out).
static var light_gain := 1.0
static var _floor_owner: WeakRef = null

static var _light: WeakRef = null
static var _marks: WeakRef = null


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


## The map's floor: `kind` "snow" / "sand" / "" and how strong the floor light is. Only holds while `owner`
## (the arena) exists, so the next scene starts from the defaults.
static func set_floor(owner: Node, kind: String, gain := 1.0) -> void:
	floor_kind = kind
	light_gain = gain
	_floor_owner = weakref(owner)


static func _check_floor() -> void:
	if _floor_owner != null and _floor_owner.get_ref() == null:
		floor_kind = ""
		light_gain = 1.0
		_floor_owner = null


static func _light_layer() -> LightLayer:
	var l: LightLayer = _light.get_ref() if _light else null
	if l == null or not l.is_inside_tree():
		var scene := _tree().current_scene
		if scene == null:
			return null
		l = LightLayer.new()
		l.name = "FloorLight"
		scene.add_child(l)
		_light = weakref(l)
	return l


static func _mark_layer() -> MarkLayer:
	var m: MarkLayer = _marks.get_ref() if _marks else null
	if m == null or not m.is_inside_tree():
		var scene := _tree().current_scene
		if scene == null:
			return null
		m = MarkLayer.new()
		m.name = "GroundMarks"
		scene.add_child(m)
		_marks = weakref(m)
	return m


# --- light -----------------------------------------------------------------------------------------------

static func flash(pos: Vector2, r: float, col: Color, power := 0.6, life := 0.35) -> void:
	var l := _light_layer()
	_check_floor()
	if l:
		l.add_flash(pos, r, col, power * light_gain, life)


static func glow(key: int, pos: Vector2, r: float, col: Color, power := 0.4) -> void:
	var l := _light_layer()
	_check_floor()
	if l:
		l.set_glow(key, pos, r, col, power * light_gain)


static func glow_line(key: int, a: Vector2, b: Vector2, r: float, col: Color, power := 0.4) -> void:
	var l := _light_layer()
	if not l:
		return
	_check_floor()
	var n := clampi(int(a.distance_to(b) / (r * 0.7)) + 1, 2, 24)
	for i in n:
		l.set_glow(key * 32 + i, a.lerp(b, float(i) / float(n - 1)), r, col, power * light_gain)


# --- marks -----------------------------------------------------------------------------------------------

static func char_mark(pos: Vector2, r: float) -> void:
	var m := _mark_layer()
	if m:
		m.add_char(pos, r)


static func wreck(pos: Vector2, r: float, tint: Color) -> void:
	var m := _mark_layer()
	if m:
		m.add_wreck(pos, r, tint)


static func footprint(pos: Vector2, rot: float, size := 1.0) -> void:
	_check_floor()
	if floor_kind == "":
		return
	var m := _mark_layer()
	if m:
		m.add_step(pos, rot, size)


## The light layer: every light is the soft radial glow texture, added on top of the floor.
class LightLayer:
	extends Node2D
	## How long a glow outlives its last refresh (fades out over this).
	const GLOW_HOLD := 0.09
	const MAX_FLASHES := 90
	var _flashes: Array = []  # [pos, r, col, power, t, life]
	var _glows := {}  # key -> [pos, r, col, power, age]

	func _ready() -> void:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		z_as_relative = false
		z_index = -6

	func add_flash(pos: Vector2, r: float, col: Color, power: float, life: float) -> void:
		if _flashes.size() >= MAX_FLASHES:
			_flashes.pop_front()
		_flashes.append([pos, r, col, power, 0.0, maxf(life, 0.02)])

	func set_glow(key: int, pos: Vector2, r: float, col: Color, power: float) -> void:
		_glows[key] = [pos, r, col, power, 0.0]

	func _process(delta: float) -> void:
		for i in range(_flashes.size() - 1, -1, -1):
			_flashes[i][4] += delta
			if _flashes[i][4] >= _flashes[i][5]:
				_flashes.remove_at(i)
		for k in _glows.keys():
			_glows[k][4] += delta
			if _glows[k][4] >= GLOW_HOLD:
				_glows.erase(k)
		queue_redraw()

	func _light(pos: Vector2, r: float, col: Color, power: float) -> void:
		if power <= 0.004:
			return
		draw_texture_rect(GLOW, Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(col.r, col.g, col.b, power))

	func _draw() -> void:
		for f: Array in _flashes:
			var k: float = 1.0 - f[4] / f[5]
			# A quick bloom up, then it dies away (squared, so most of it is in the first moments).
			var up := minf(f[4] / 0.03, 1.0)
			_light(f[0], f[1] * (0.85 + 0.15 * up), f[2], f[3] * k * k * up)
		for g: Array in _glows.values():
			var k: float = 1.0 - clampf((g[4] - 0.02) / (GLOW_HOLD - 0.02), 0.0, 1.0)
			_light(g[0], g[1], g[2], g[3] * k)


## The marks layer: charred patches, robot scrap and footprints, drawn as plain shapes (no textures but
## the soft glow), oldest first; each kind has a cap and the oldest go first.
class MarkLayer:
	extends Node2D
	const CHAR_LIFE := 75.0
	const WRECK_LIFE := 75.0
	const STEP_LIFE := 16.0
	const FADE := 8.0
	const STEP_FADE := 6.0
	const CAPS := {&"char": 45, &"wreck": 40, &"step": 140}
	## How often fading marks redraw (they change slowly; the layer is otherwise only redrawn on add).
	const REDRAW_EVERY := 0.2
	var _marks: Array = []  # dicts: kind, pos, rot, r, t, life, fade, + per-kind data
	var _count := {&"char": 0, &"wreck": 0, &"step": 0}
	var _redraw_t := 0.0
	var _dirty := false

	func _ready() -> void:
		z_as_relative = false
		z_index = -8

	func _add(m: Dictionary) -> void:
		var kind: StringName = m.kind
		if _count[kind] >= CAPS[kind]:
			for i in _marks.size():
				if _marks[i].kind == kind:
					_marks.remove_at(i)
					_count[kind] -= 1
					break
		m.t = 0.0
		_marks.append(m)
		_count[kind] += 1
		_dirty = true

	func add_char(pos: Vector2, r: float) -> void:
		var streaks := []
		for i in 9:
			streaks.append([randf() * TAU, randf_range(0.8, 1.35), randf_range(1.2, 2.6)])
		_add({kind = &"char", pos = pos, rot = randf() * TAU, r = r, life = CHAR_LIFE, fade = FADE, streaks = streaks})

	func add_wreck(pos: Vector2, r: float, tint: Color) -> void:
		# A handful of torn plates and a couple of small bits, scattered round where the robot stood.
		var pieces := []
		var n := clampi(int(r / 9.0) + 3, 4, 9)
		for i in n:
			var size := maxf(r * randf_range(0.24, 0.46), 6.0) * (0.55 if i >= n - 2 else 1.0)
			var pts := PackedVector2Array()
			var corners := randi_range(4, 6)
			for c in corners:
				var a := TAU * c / corners + randf_range(-0.35, 0.35)
				pts.append(Vector2.from_angle(a) * size * randf_range(0.55, 1.0) * Vector2(1.0, randf_range(0.45, 0.9)))
			var at := Vector2.from_angle(randf() * TAU) * r * sqrt(randf()) * 0.85
			var shade := randf_range(0.45, 0.85)
			pieces.append([at, randf() * TAU, pts, shade])
		_add({kind = &"wreck", pos = pos, rot = 0.0, r = r, life = WRECK_LIFE, fade = FADE, pieces = pieces,
			tint = tint})

	func add_step(pos: Vector2, rot: float, size: float) -> void:
		_add({kind = &"step", pos = pos, rot = rot, r = size, life = STEP_LIFE, fade = STEP_FADE})

	func _process(delta: float) -> void:
		var fading := false
		for i in range(_marks.size() - 1, -1, -1):
			var m: Dictionary = _marks[i]
			m.t += delta
			if m.t >= m.life:
				_count[m.kind] -= 1
				_marks.remove_at(i)
				_dirty = true
			elif m.t >= m.life - m.fade:
				fading = true
		_redraw_t -= delta
		if _dirty or (fading and _redraw_t <= 0.0):
			_redraw_t = REDRAW_EVERY
			_dirty = false
			queue_redraw()

	func _draw() -> void:
		var pale := BlastFx.pale_floor
		for m: Dictionary in _marks:
			var a := clampf((m.life - m.t) / m.fade, 0.0, 1.0)
			match m.kind:
				&"char":
					_draw_char(m, a, pale)
				&"wreck":
					_draw_wreck(m, a, pale)
				&"step":
					_draw_step(m, a)
		draw_set_transform(Vector2.ZERO)

	func _draw_char(m: Dictionary, a: float, pale: bool) -> void:
		var r: float = m.r
		var outer := Color(0.14, 0.18, 0.26, 0.36) if pale else Color(0.02, 0.015, 0.01, 0.45)
		var inner := Color(0.1, 0.11, 0.15, 0.34) if pale else Color(0.03, 0.02, 0.015, 0.4)
		var soot := Color(0.12, 0.14, 0.2, 0.22) if pale else Color(0.03, 0.02, 0.02, 0.24)
		draw_set_transform(m.pos, m.rot)
		draw_texture_rect(GLOW, Rect2(Vector2.ONE * -r * 1.25, Vector2.ONE * r * 2.5), false, Color(outer, outer.a * a))
		draw_texture_rect(GLOW, Rect2(Vector2.ONE * -r * 0.65, Vector2.ONE * r * 1.3), false, Color(inner, inner.a * a))
		for s: Array in m.streaks:
			var d := Vector2.from_angle(s[0])
			draw_line(d * r * 0.4, d * r * float(s[1]), Color(soot, soot.a * a), float(s[2]), true)

	func _draw_wreck(m: Dictionary, a: float, pale: bool) -> void:
		var tint: Color = m.tint
		var r: float = m.r
		# The burnt ground under the wreck, then each plate: a drop shadow, dark metal, a lit top edge.
		draw_set_transform(m.pos)
		var under := Color(0.15, 0.18, 0.24, 0.22) if pale else Color(0.0, 0.0, 0.0, 0.28)
		draw_texture_rect(GLOW, Rect2(Vector2.ONE * -r * 0.95, Vector2.ONE * r * 1.9), false, Color(under, under.a * a))
		for p: Array in m.pieces:
			var pts: PackedVector2Array = p[2]
			var shade: float = p[3]
			draw_set_transform(m.pos + p[0] + Vector2(2.0, 3.0), p[1])
			draw_colored_polygon(pts, Color(0, 0, 0, 0.35 * a))
			draw_set_transform(m.pos + p[0], p[1])
			var metal := Color(0.2, 0.2, 0.22).lerp(tint, 0.35) * shade
			draw_colored_polygon(pts, Color(metal, 0.95 * a))
			var edge := PackedVector2Array([pts[pts.size() - 1], pts[0], pts[1]])
			draw_polyline(edge, Color(metal.lightened(0.45), 0.8 * a), 1.4, true)

	func _draw_step(m: Dictionary, a: float) -> void:
		# A mech foot pressed into the ground: an oval toe pad and a heel, dark, with the pushed-up snow / sand
		# catching the light along the far edge.
		var s: float = m.r
		var snow := GroundFx.floor_kind == "snow"
		var dent := Color(0.08, 0.14, 0.26, 0.34) if snow else Color(0.2, 0.12, 0.05, 0.32)
		var rim := Color(1.0, 1.0, 1.0, 0.26) if snow else Color(1.0, 0.93, 0.78, 0.16)
		draw_set_transform(m.pos, m.rot, Vector2(s * 0.68, s))
		# The lit inner wall is the one facing the sun (up-left), i.e. the down-right edge in world space.
		var from: float = -0.15 * PI - m.rot
		for pad: Array in [[Vector2(0, -5), 8.0], [Vector2(0, 7), 5.5]]:
			draw_circle(pad[0], pad[1], Color(dent, dent.a * a))
			draw_arc(pad[0], pad[1] - 0.8, from, from + 0.75 * PI, 10, Color(rim, rim.a * a), 1.6, true)
