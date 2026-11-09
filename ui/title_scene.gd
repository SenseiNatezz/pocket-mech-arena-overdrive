class_name TitleScene
extends Control
## Animated hero scene behind the title menu (built in code over two pictures):
##   background  deep-blue space: Earth, an orbital station, nebula (assets/hq/title_space.png), fitted to
##               the screen height and anchored left, with a slow drift; god rays fan out of its sunrise
##   sky         twinkling star glints, an occasional shooting star, small ships crossing far away, and a
##               distant battle: beam shots and blasts flickering far off, low-key
##   vignette    the edges fall off to dark so the hero is the brightest thing on screen
##   halo        the gold ring behind the mech: a gold ring of light with a tick ring and HUD arcs
##               turning around it, a glint racing round; it ignites when the mech lands
##   mech        the player's robot, NIMBUS-07 (assets/hq/title_mech.png, rendered from its 3D model in
##               a low-angle aiming pose, art_src/halo_forge/tools/render_title.py), big (about 80% of the
##               screen height) on a holo-pedestal running off the bottom edge: gentle bob and sway, a soft
##               cyan glow hugging its silhouette, a light sweep across the armour every few seconds, its
##               visor pulsing blue
##   pedestal    dark disc with a glowing cyan ring, a rotating dashed outer ring, a faint light column and
##               rising holo motes
##   intro       the first time per launch the mech drops onto the pedestal (ring shockwave), its visor
##               powers on with a flare and the halo ignites; later visits start settled
## The menu (ui/main_menu.gd) sets `mech_center_x` / `mech_height` / `feet_y` so the mech stands clear of its
## columns, and slips its own shade in over the backdrop but under the mech (add_backdrop_layer).

const BG := preload("res://assets/hq/title_space.png")
const MECH := preload("res://assets/hq/title_mech.png")
const GLOW := preload("res://assets/fx/glow.tres")
const SHEEN := preload("res://ui/mech_sheen.gdshader")
## Visor points (both ends of NIMBUS-07's visor) as fractions of the mech art (render_title.py prints
## them).
const EYES := [Vector2(0.643, 0.115), Vector2(0.666, 0.115)]
## Where the sunrise is in the backdrop art (fraction of its size): the god rays fan out from there.
const SUN := Vector2(0.354, 0.424)
## Landscape: the mech's height as a fraction of the screen height, and where its feet stand (the pedestal
## runs off the bottom edge).
const HERO_H := 0.8
const HERO_FEET := 0.985
## The halo's centre (fraction of the art, at the chest) and radius (fraction of the mech's height).
const HALO_AT := Vector2(0.5, 0.36)
const HALO_R := 0.47
const VISOR := Color(0.3, 0.7, 1.0)
const CYAN := Color(0.35, 0.85, 1.0)
const GOLD := Color(1.0, 0.76, 0.28)
const INTRO := 1.4
## Light sweep across the armour: every SHEEN_EVERY seconds, taking SHEEN_TIME.
const SHEEN_EVERY := 7.0
const SHEEN_TIME := 1.1

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
var _battle_layer: Node2D
var _rays: Node2D
var _vignette: TextureRect
var _halo: Node2D
var _stage: Node2D
var _rim: Node2D
var _mech: Sprite2D
var _fx: Node2D
var _aura: Node2D
var _motes: CPUParticles2D
var _t := 0.0
var _intro := 0.0
var _land_flash := 0.0
## Eyes power on (0 -> 1) once the mech has landed; the halo ignites with them.
var _power := 0.0
var _flare := 0.0
var _flared := false
var _stars: Array[Vector3] = []
var _shoot := {}
var _shoot_t := 3.0
var _ship := {}
var _ship_t := 5.0
## Distant battle events: {kind, a, b, col, t, life}.
var _battle: Array[Dictionary] = []
var _battle_t := 1.5


## The hero art's width / height.
static func art_aspect() -> float:
	return float(MECH.get_width()) / MECH.get_height()


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
	_sky = _layer(_draw_sky, false)
	_battle_layer = _layer(_draw_battle, true)
	_rays = _layer(_draw_rays, true)
	for i in 70:
		_stars.append(Vector3(randf(), randf() * 0.85, randf() * TAU))
	# Vignette: the edges fall off to dark.
	var g := Gradient.new()
	g.set_color(0, Color(0, 0.01, 0.04, 0.0))
	g.add_point(0.55, Color(0, 0.01, 0.04, 0.0))
	g.set_color(g.get_point_count() - 1, Color(0, 0.01, 0.04, 0.62))
	var vt := GradientTexture2D.new()
	vt.gradient = g
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(1.05, 0.5)
	vt.width = 256
	vt.height = 256
	_vignette = TextureRect.new()
	_vignette.texture = vt
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	# Halo, pedestal + light column, glows, then the mech, then additive glows on top.
	_halo = _layer(_draw_halo, true)
	_stage = _layer(_draw_stage, false)
	_aura = _layer(_draw_aura, true)
	_rim = _layer(_draw_rim, true)
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
	var sheen := ShaderMaterial.new()
	sheen.shader = SHEEN
	_mech.material = sheen
	add_child(_mech)
	_fx = _layer(_draw_fx, true)
	_intro = 0.0 if _intro_played else INTRO
	_power = 0.0 if _intro > 0.0 else 1.0
	_flared = _intro <= 0.0
	_intro_played = true


## A full-screen drawing layer (`additive` = light that adds onto what's below).
func _layer(f: Callable, additive: bool) -> Node2D:
	var n := Node2D.new()
	if additive:
		n.material = _additive()
	n.draw.connect(f)
	add_child(n)
	return n


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## Whether the landing intro is still playing (the menu times its own entrance to it).
func intro_active() -> bool:
	return _intro > 0.0


## Adds `layer` (a full-screen Control) over the backdrop - right after the vignette, so under the halo,
## pedestal and mech (the menu's darkening behind its columns).
func add_backdrop_layer(layer: Control) -> void:
	add_child(layer)
	move_child(layer, _vignette.get_index() + 1)


## Mech height on screen and where its feet stand.
func _mech_h() -> float:
	return mech_height if mech_height > 0.0 else size.y * HERO_H


func _feet() -> Vector2:
	return Vector2(mech_center_x, feet_y if feet_y > 0.0 else size.y * HERO_FEET)


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
	if not _flared and _power > 0.55:
		_flared = true
		_flare = 1.0
	_flare = move_toward(_flare, 0.0, delta * 2.5)
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
	var bob := sin(_t * 1.4) * h * 0.01 * k
	var feet := _feet()
	_mech.scale = Vector2(s, s)
	_mech.rotation = sin(_t * 0.9) * 0.01 * k
	# (the art is cropped to the mech, so its feet are its bottom edge; set them on the disc's top face)
	_mech.position = Vector2(feet.x - w / 2.0, feet.y - h + h * 0.01 + bob + drop)
	var cycle := fmod(_t + 2.0, SHEEN_EVERY)
	(_mech.material as ShaderMaterial).set_shader_parameter("sweep",
		lerpf(-0.15, 1.15, cycle / SHEEN_TIME) if cycle < SHEEN_TIME and k >= 1.0 else -1.0)
	_motes.position = feet + Vector2(0, -6)
	_motes.emission_rect_extents = Vector2(w * 0.42, 6)
	_motes.emitting = k >= 1.0
	_update_sky(delta, vp)
	for n in [_sky, _battle_layer, _rays, _halo, _stage, _aura, _rim, _fx]:
		n.queue_redraw()


func _update_sky(delta: float, vp: Vector2) -> void:
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
	# Distant battle: a beam shot or a blast somewhere far off every few seconds.
	_battle_t -= delta
	if _battle_t <= 0.0:
		_battle_t = randf_range(1.6, 4.5)
		var at := Vector2(randf_range(vp.x * 0.3, vp.x * 0.95), randf_range(vp.y * 0.08, vp.y * 0.5))
		var col: Color = [Color(1.0, 0.45, 0.8), Color(0.45, 0.85, 1.0), Color(1.0, 0.8, 0.4)].pick_random()
		if randf() < 0.6:
			var d := Vector2.from_angle(randf_range(-0.5, 0.5) + (PI if randf() < 0.5 else 0.0))
			_battle.append({"kind": 0, "a": at, "b": at + d * randf_range(120, 280), "col": col, "t": 0.0, "life": 0.35})
		else:
			_battle.append({"kind": 1, "a": at, "b": at, "col": col, "t": 0.0, "life": 0.7})
	for e in _battle:
		e["t"] += delta
	_battle = _battle.filter(func(e: Dictionary) -> bool: return e["t"] < e["life"])


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
		_sky.draw_polyline(PackedVector2Array([tail, p.lerp(tail, 0.3), p]), Color(0.8, 0.95, 1.0, 0.8 * fade), 2.0, true)
		_sky.draw_circle(p, 2.5, Color(1, 1, 1, fade))
	if not _ship.is_empty():
		var p: Vector2 = _ship["p"]
		_sky.draw_line(p, p + Vector2(46, 0), Color(0.4, 0.8, 1.0, 0.35), 2.0, true)
		_sky.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(4, -3), p + Vector2(6, 0),
			p + Vector2(4, 3)]), Color(0.75, 0.8, 0.95, 0.9))
		_sky.draw_circle(p + Vector2(7, 0), 2.5, Color(0.5, 0.9, 1.0, 0.9))


## Distant battle flickers (additive, low-key so they never compete with the hero).
func _draw_battle() -> void:
	for e in _battle:
		var k: float = e["t"] / e["life"]
		var col: Color = e["col"]
		var a: Vector2 = e["a"]
		if int(e["kind"]) == 0:
			# A beam shot streaking across, then a pop where it ends.
			var b: Vector2 = e["b"]
			var head := a.lerp(b, minf(k / 0.4, 1.0))
			var tail := a.lerp(b, maxf((k - 0.3) / 0.7, 0.0))
			var fade := 1.0 - maxf(k - 0.6, 0.0) / 0.4
			_battle_layer.draw_line(tail, head, Color(col, 0.55 * fade), 2.0, true)
			_battle_layer.draw_line(tail, head, Color(1, 1, 1, 0.5 * fade), 1.0, true)
			if k > 0.4:
				var u := (k - 0.4) / 0.6
				_glow_on(_battle_layer, b, 14.0 + 10.0 * u, Color(col, 0.6 * (1.0 - u)))
		else:
			# A blast: a flash and a ring opening out.
			_glow_on(_battle_layer, a, 18.0 * (1.0 - k) + 6.0, Color(col, 0.7 * (1.0 - k)))
			_battle_layer.draw_arc(a, 6.0 + 26.0 * k, 0.0, TAU, 24, Color(col, 0.45 * (1.0 - k)), 1.5, true)


## God rays fanning down out of the sunrise in the backdrop, breathing slowly.
func _draw_rays() -> void:
	var sun := _bg.position + _bg.size * SUN
	var L := size.y * 1.4
	for i in 6:
		var ang := deg_to_rad(68.0 + i * 13.0) + 0.04 * sin(_t * 0.23 + i * 1.7)
		var spread := deg_to_rad(2.2 + 1.6 * float(i % 3))
		var a := (0.05 + 0.025 * sin(_t * 0.4 + i * 2.1)) * (0.85 if i % 2 == 0 else 0.6)
		var p1 := sun + Vector2.from_angle(ang - spread) * L
		var p2 := sun + Vector2.from_angle(ang + spread) * L
		_rays.draw_polygon(PackedVector2Array([sun, p1, p2]),
			PackedColorArray([Color(1.0, 0.86, 0.62, a), Color(1.0, 0.8, 0.55, 0.0), Color(1.0, 0.8, 0.55, 0.0)]))
	_glow_on(_rays, sun, size.y * 0.16, Color(1.0, 0.85, 0.6, 0.16 + 0.04 * sin(_t * 0.6)))


## The halo behind NIMBUS-07: a gold ring of light (soft bloom, a bright core line), an inner
## dashed ring and an outer tick ring turning opposite ways, three HUD arcs, a glint racing round. It
## ignites (grows in and brightens) with the visor when the mech lands.
func _draw_halo() -> void:
	var h := _mech_h()
	var s := h / MECH.get_height()
	var c := _mech.position + Vector2(MECH.get_width(), MECH.get_height()) * s * HALO_AT
	var ign := ease(_power, 0.4)
	if ign <= 0.0:
		return
	var R := h * HALO_R * (0.75 + 0.25 * ign) * (1.0 + 0.012 * sin(_t * 1.3))
	var a := ign * (0.9 + 0.1 * sin(_t * 2.0))
	_glow_on(_halo, c, R * 1.25, Color(0.25, 0.4, 0.9, 0.18 * a))
	_halo.draw_arc(c, R, 0.0, TAU, 128, Color(GOLD, 0.1 * a), 28.0, true)
	_halo.draw_arc(c, R, 0.0, TAU, 128, Color(GOLD, 0.32 * a), 8.0, true)
	_halo.draw_arc(c, R, 0.0, TAU, 128, Color(1.0, 0.95, 0.8, 0.85 * a), 2.2, true)
	# Inner dashed ring, turning backwards.
	for i in 24:
		var a0 := -_t * 0.12 + TAU * i / 24.0
		_halo.draw_arc(c, R * 0.86, a0, a0 + TAU / 48.0, 6, Color(CYAN, 0.45 * a), 2.0, true)
	# Outer tick ring, turning forwards; every sixth tick longer.
	for i in 72:
		var ang := _t * 0.05 + TAU * i / 72.0
		var d := Vector2.from_angle(ang)
		var long := i % 6 == 0
		_halo.draw_line(c + d * R * 1.07, c + d * R * (1.12 if long else 1.09), Color(GOLD, (0.5 if long else 0.28) * a),
			1.6 if long else 1.0, true)
	# Three HUD arcs further out.
	for i in 3:
		var a0 := _t * 0.18 + TAU * i / 3.0
		_halo.draw_arc(c, R * 1.18, a0, a0 + 0.55, 24, Color(CYAN, 0.5 * a), 2.5, true)
		_halo.draw_arc(c, R * 1.18, a0 + 0.6, a0 + 0.66, 4, Color(CYAN, 0.8 * a), 2.5, true)
	# A glint racing round the ring.
	var gp := c + Vector2.from_angle(_t * 1.6) * R
	_glow_on(_halo, gp, 26.0, Color(1.0, 0.9, 0.65, 0.7 * a))
	_glow_on(_halo, gp, 8.0, Color(1, 1, 1, 0.9 * a))
	# Landing: the ring flashes out.
	if _land_flash > 0.0:
		_halo.draw_arc(c, R * (1.0 + (1.0 - _land_flash) * 0.35), 0.0, TAU, 96, Color(1, 0.95, 0.8, _land_flash * 0.8), 5.0, true)


func _draw_stage() -> void:
	var feet := _feet()
	var w := MECH.get_width() * _mech_h() / MECH.get_height()
	var rx := w * 0.56
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
	_ellipse(feet + Vector2(0, -2), rx * 0.55 * hover * (0.3 + 0.7 * k), ry * 0.55 * hover * (0.3 + 0.7 * k), Color(0, 0, 0, 0.35 * k))
	# Landing shockwave.
	if _land_flash > 0.0:
		var g := 1.0 + (1.0 - _land_flash) * 0.9
		_ring(feet, rx * g, ry * g, Color(CYAN.lightened(0.4), _land_flash * 0.9), 4.0)


## A soft cyan glow hugging the mech's silhouette (the art drawn again, nudged out in a ring of directions).
func _draw_rim() -> void:
	var a := (0.5 + 0.5 * _intro_k()) * (0.9 + 0.1 * sin(_t * 1.7))
	_rim.draw_set_transform(_mech.position, _mech.rotation, _mech.scale)
	var s := maxf(_mech.scale.x, 0.01)
	# (6 directions per ring: 12 draws of the art, light enough for phones)
	for ring in [[3.0, 0.08], [7.0, 0.045]]:
		for k in 6:
			var o := Vector2.from_angle(TAU * k / 6.0 + 0.3) * (float(ring[0]) / s)
			_rim.draw_texture(MECH, o, Color(0.45, 0.8, 1.0, float(ring[1]) * a))
	_rim.draw_set_transform(Vector2.ZERO)


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
	var mid := Vector2.ZERO
	for e: Vector2 in EYES:
		var p: Vector2 = origin + (size_px * e).rotated(_mech.rotation)
		mid += p / EYES.size()
		_glow(p, h * 0.06, Color(VISOR, 0.8 * eye))
		_glow(p, h * 0.02, Color(0.85, 0.95, 1, eye))
	# Power-on flare across the visor: an anamorphic streak and a star.
	if _flare > 0.0:
		var f := _flare
		_fx.draw_set_transform(mid, 0.0, Vector2(1.0, 0.05))
		_fx.draw_texture_rect(GLOW, Rect2(Vector2(-h, -h) * 0.9, Vector2(h, h) * 1.8), false, Color(0.6, 0.85, 1.0, 0.9 * f))
		_fx.draw_set_transform(Vector2.ZERO)
		_glow(mid, h * 0.12 * f, Color(0.8, 0.95, 1.0, f))


func _glow(p: Vector2, r: float, c: Color) -> void:
	_glow_on(_fx, p, r, c)


func _glow_on(n: Node2D, p: Vector2, r: float, c: Color) -> void:
	n.draw_texture_rect(GLOW, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, c)


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
