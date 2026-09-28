class_name TitleScene
extends Control
## Animated hero scene behind the title menu (built in code, Higgsfield art):
##   background  deep-blue space: Earth, an orbital station, nebula (assets/hq/title_space.png), fitted
##               to the screen height and anchored left, with a slow drift
##   sky         twinkling star glints, an occasional shooting star, small ships crossing far away
##   mech        the player's robot (assets/hq/title_mech.png) hovering over a holo-pedestal: gentle bob
##               and sway, a blue aura, eyes and beam saber pulsing pink
##   pedestal    dark disc with a glowing cyan ring, a rotating dashed outer ring, a faint light column and
##               rising holo motes
##   intro       the first time per launch the mech drops onto the pedestal (ring shockwave) and its eyes
##               power on; later visits start settled
## `mech_center_x` is set by the menu so the mech always stays clear of the menu column.

const BG := preload("res://assets/hq/title_space.png")
const MECH := preload("res://assets/hq/title_mech.png")
const GLOW := preload("res://assets/fx/glow.tres")
## Eye / saber positions as fractions of the mech art (tools/process_title_mech.gd prints them).
const EYES := [Vector2(0.483, 0.228), Vector2(0.588, 0.228)]
const SABER_TIP := Vector2(0.855, 0.075)
const PINK := Color(1.0, 0.35, 0.85)
const CYAN := Color(0.35, 0.85, 1.0)
const INTRO := 1.4

static var _intro_played := false

## Screen x of the mech's centre (the menu keeps it left of its column).
var mech_center_x := 360.0
## Portrait overrides from the menu (0 = landscape defaults): mech height and feet y in pixels, and the
## point of the backdrop (fraction of its width) to centre on screen instead of anchoring it left.
var mech_height := 0.0
var feet_y := 0.0
var bg_focus := 0.0
var _bg: TextureRect
var _sky: Node2D
var _stage: Node2D
var _mech: Sprite2D
var _fx: Node2D
var _aura: Node2D
var _motes: CPUParticles2D
var _t := 0.0
var _intro := 0.0
var _land_flash := 0.0
## Eyes power on (0 -> 1) once the mech has landed.
var _power := 0.0
var _stars: Array[Vector3] = []
var _shoot := {}
var _shoot_t := 3.0
var _ship := {}
var _ship_t := 5.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var black := ColorRect.new()
	black.color = Color(0.01, 0.015, 0.05)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)
	_bg = TextureRect.new()
	_bg.texture = BG
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_sky = Node2D.new()
	_sky.draw.connect(_draw_sky)
	add_child(_sky)
	for i in 70:
		_stars.append(Vector3(randf(), randf() * 0.85, randf() * TAU))
	# Pedestal + light column behind the mech, the mech, then additive glows on top.
	_stage = Node2D.new()
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	_aura = Node2D.new()
	_aura.material = _additive()
	_aura.draw.connect(_draw_aura)
	add_child(_aura)
	_motes = CPUParticles2D.new()
	_motes.amount = 40
	_motes.lifetime = 2.6
	_motes.preprocess = 2.6
	_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_motes.direction = Vector2.UP
	_motes.spread = 6.0
	_motes.gravity = Vector2.ZERO
	_motes.initial_velocity_min = 25.0
	_motes.initial_velocity_max = 70.0
	_motes.scale_amount_min = 1.5
	_motes.scale_amount_max = 3.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(CYAN, 0.0))
	ramp.add_point(0.2, Color(CYAN.lightened(0.3), 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(CYAN, 0.0))
	_motes.color_ramp = ramp
	_motes.material = _additive()
	add_child(_motes)
	_mech = Sprite2D.new()
	_mech.texture = MECH
	_mech.centered = false
	add_child(_mech)
	_fx = Node2D.new()
	_fx.material = _additive()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_intro = 0.0 if _intro_played else INTRO
	_power = 0.0 if _intro > 0.0 else 1.0
	_intro_played = true


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Mech height on screen and where its feet stand.
func _mech_h() -> float:
	return mech_height if mech_height > 0.0 else size.y * 0.64


func _feet() -> Vector2:
	return Vector2(mech_center_x, feet_y if feet_y > 0.0 else size.y * 0.87)


## 0..1 progress of the landing intro (1 = settled).
func _intro_k() -> float:
	return 1.0 - clampf(_intro / INTRO, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	if _intro > 0.0:
		_intro -= delta
		if _intro <= 0.0:
			_land_flash = 1.0
			Sfx.play(&"slam", -12.0, 0.0)
	_land_flash = move_toward(_land_flash, 0.0, delta * 1.6)
	if _intro <= 0.0:
		_power = move_toward(_power, 1.0, delta * 1.5)
	# Background: fit height, anchored left (or centred on `bg_focus`), slow drift.
	var vp := size
	var aspect := float(BG.get_width()) / BG.get_height()
	var z := 1.03 + 0.015 * sin(_t * 0.1)
	_bg.size = Vector2(vp.y * aspect, vp.y) * z
	var bx := -vp.y * aspect * (z - 1.0) * 0.3
	if bg_focus > 0.0:
		bx = clampf(vp.x / 2.0 - _bg.size.x * bg_focus, vp.x - _bg.size.x, 0.0)
	_bg.position = Vector2(bx + sin(_t * 0.07) * 6.0, -vp.y * (z - 1.0) * 0.5)
	# Mech: hover bob + sway; during the intro it drops in from above.
	var h := _mech_h()
	var s := h / MECH.get_height()
	var w := MECH.get_width() * s
	var k := _intro_k()
	var drop := (1.0 - ease(k, 2.4)) * -vp.y * 0.9
	var bob := sin(_t * 1.4) * h * 0.012 * k
	var feet := _feet()
	_mech.scale = Vector2(s, s)
	_mech.rotation = sin(_t * 0.9) * 0.012 * k
	# (the art's feet end ~4% above its bottom edge; this sets them just above the disc's top face)
	_mech.position = Vector2(feet.x - w / 2.0, feet.y - h + h * 0.035 + bob + drop)
	_motes.position = feet + Vector2(0, -6)
	_motes.emission_rect_extents = Vector2(w * 0.42, 6)
	_motes.emitting = k >= 1.0
	# Sky events.
	_shoot_t -= delta
	if _shoot_t <= 0.0:
		_shoot_t = randf_range(4.0, 8.0)
		var start := Vector2(randf_range(vp.x * 0.45, vp.x), randf_range(0.0, vp.y * 0.3))
		_shoot = {"p": start, "v": Vector2(-randf_range(700, 1000), randf_range(180, 320)), "t": 0.0}
	if not _shoot.is_empty():
		_shoot["t"] += delta
		_shoot["p"] += _shoot["v"] * delta
		if _shoot["t"] > 0.7:
			_shoot = {}
	_ship_t -= delta
	if _ship_t <= 0.0 and _ship.is_empty():
		_ship_t = randf_range(9.0, 14.0)
		var y := randf_range(vp.y * 0.1, vp.y * 0.45)
		_ship = {"p": Vector2(vp.x + 40, y), "v": Vector2(-randf_range(60, 110), randf_range(-8, 8))}
	if not _ship.is_empty():
		_ship["p"] += _ship["v"] * delta
		if _ship["p"].x < -60:
			_ship = {}
	_sky.queue_redraw()
	_stage.queue_redraw()
	_fx.queue_redraw()
	_aura.queue_redraw()


func _draw_sky() -> void:
	var vp := size
	for s in _stars:
		var a := 0.5 + 0.5 * sin(_t * (1.1 + s.z * 0.4) + s.z * 7.0)
		if a < 0.6:
			continue
		var p := Vector2(s.x * vp.x, s.y * vp.y)
		var r := 1.0 + (a - 0.6) * 5.0
		var c := Color(0.75, 0.88, 1.0, (a - 0.6) * 1.6)
		_sky.draw_circle(p, r * 2.2, Color(c, c.a * 0.25))
		_sky.draw_line(p - Vector2(r * 4, 0), p + Vector2(r * 4, 0), c, 1.0, true)
		_sky.draw_line(p - Vector2(0, r * 4), p + Vector2(0, r * 4), c, 1.0, true)
	if not _shoot.is_empty():
		var p: Vector2 = _shoot["p"]
		var tail: Vector2 = p - _shoot["v"].normalized() * 140.0
		var fade: float = 1.0 - _shoot["t"] / 0.7
		_sky.draw_line(tail, p, Color(0.7, 0.9, 1.0, 0.0), 2.0, true)
		_sky.draw_polyline(PackedVector2Array([tail, p.lerp(tail, 0.3), p]), Color(0.8, 0.95, 1.0, 0.8 * fade), 2.0, true)
		_sky.draw_circle(p, 2.5, Color(1, 1, 1, fade))
	if not _ship.is_empty():
		var p: Vector2 = _ship["p"]
		_sky.draw_line(p, p + Vector2(46, 0), Color(0.4, 0.8, 1.0, 0.35), 2.0, true)
		_sky.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(4, -3), p + Vector2(6, 0),
			p + Vector2(4, 3)]), Color(0.75, 0.8, 0.95, 0.9))
		_sky.draw_circle(p + Vector2(7, 0), 2.5, Color(0.5, 0.9, 1.0, 0.9))


func _draw_stage() -> void:
	var feet := _feet()
	var w := MECH.get_width() * _mech_h() / MECH.get_height()
	var rx := w * 0.52
	var ry := rx * 0.2
	var k := _intro_k()
	var pulse := 0.5 + 0.5 * sin(_t * 2.2)
	# Light column rising from the pedestal (faint), brighter right after landing.
	var col_a := 0.07 + 0.05 * pulse + _land_flash * 0.25
	var top := feet.y - _mech_h() * 1.15
	_stage.draw_polygon(PackedVector2Array([feet + Vector2(-rx * 0.85, 0), feet + Vector2(rx * 0.85, 0),
		Vector2(feet.x + rx * 0.55, top), Vector2(feet.x - rx * 0.55, top)]),
		PackedColorArray([Color(CYAN, col_a), Color(CYAN, col_a), Color(CYAN, 0.0), Color(CYAN, 0.0)]))
	# Disc: body with thickness, top face, inner glowing ring.
	for i in 12:
		_ellipse(feet + Vector2(0, 16 - i), rx, ry, Color(0.03, 0.05, 0.1).lerp(Color(0.1, 0.13, 0.2), i / 12.0))
	_ellipse(feet, rx, ry, Color(0.09, 0.11, 0.17))
	_ellipse(feet, rx * 0.84, ry * 0.84, Color(0.05, 0.07, 0.12))
	_ring(feet, rx * 0.78, ry * 0.78, Color(CYAN, 0.55 + 0.35 * pulse), 3.0)
	_ring(feet, rx * 0.78 + 4, ry * 0.78 + 2, Color(CYAN, 0.18 + 0.1 * pulse), 7.0)
	_ring(feet, rx, ry, Color(0.5, 0.65, 0.9, 0.5), 1.5)
	# Rotating dashed outer ring.
	for i in 16:
		var a0 := _t * 0.5 + TAU * i / 16.0
		_arc(feet, rx * 1.08, ry * 1.08, a0, a0 + TAU / 32.0, Color(CYAN, 0.45))
	# Mech shadow on the disc (smaller while it's high up during the intro).
	var hover := 0.85 + 0.15 * (0.5 + 0.5 * sin(_t * 1.4 + PI))
	_ellipse(feet + Vector2(0, -2), rx * 0.5 * hover * (0.3 + 0.7 * k), ry * 0.5 * hover * (0.3 + 0.7 * k), Color(0, 0, 0, 0.35 * k))
	# Landing shockwave.
	if _land_flash > 0.0:
		var g := 1.0 + (1.0 - _land_flash) * 0.9
		_ring(feet, rx * g, ry * g, Color(CYAN.lightened(0.4), _land_flash * 0.9), 4.0)


func _draw_fx() -> void:
	var h := _mech_h()
	var s := h / MECH.get_height()
	var size_px := Vector2(MECH.get_width(), MECH.get_height()) * s
	var origin := _mech.position
	var power := _power
	# Eyes: pulse, with a quick flicker when they power on.
	var eye := (0.55 + 0.25 * sin(_t * 3.0)) * power
	if power > 0.0 and power < 1.0:
		eye *= 0.5 + 0.5 * signf(sin(_t * 60.0))
	for e: Vector2 in EYES:
		var p: Vector2 = origin + (size_px * e).rotated(_mech.rotation)
		_glow(p, h * 0.07, Color(PINK, 0.9 * eye))
		_glow(p, h * 0.025, Color(1, 0.85, 1, eye))
	# Beam saber on the back.
	var tip: Vector2 = origin + (size_px * SABER_TIP).rotated(_mech.rotation)
	_glow(tip + Vector2(-h * 0.03, h * 0.08), h * 0.2, Color(PINK, 0.22 + 0.1 * sin(_t * 5.0)))


func _glow(p: Vector2, r: float, c: Color) -> void:
	_fx.draw_texture_rect(GLOW, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, c)


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_stage.draw_colored_polygon(pts, col)


func _ring(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	_arc(c, rx, ry, 0.0, TAU, col, w)


func _arc(c: Vector2, rx: float, ry: float, a0: float, a1: float, col: Color, w := 2.5) -> void:
	var pts := PackedVector2Array()
	var n := maxi(4, int(absf(a1 - a0) / TAU * 64.0))
	for i in n + 1:
		var a := lerpf(a0, a1, i / float(n))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_stage.draw_polyline(pts, col, w, true)


## Soft blue aura behind the mech (additive, under the sprite).
func _draw_aura() -> void:
	var h := _mech_h()
	var s := h / MECH.get_height()
	var size_px := Vector2(MECH.get_width(), MECH.get_height()) * s
	var c := _mech.position + size_px * Vector2(0.5, 0.45)
	var a := 0.16 + 0.06 * sin(_t * 1.1) + _land_flash * 0.2
	var r := h * 0.75
	_aura.draw_texture_rect(GLOW, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(0.2, 0.45, 1.0, a))
