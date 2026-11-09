class_name BeamCannon
extends Node2D
## Beam Cannon: the mech's special attack, a Gundam-style mega beam in the pilot's energy colour (pink by
## default; gold in overdrive). All drawn in code, additively:
##   CHARGE (0.55 s): energy particles are sucked into the muzzle, where an orb of light grows, flickering
##                    hotter, with a ring closing in and a thin targeting line; the mech slows down.
##   FIRE   (1.0 s):  a lens-flare burst and shockwave rings at the muzzle, and the beam shoots out to the
##                    first wall / solid obstacle (player/weapons/mega_beam.gdshader: white-hot core,
##                    coloured corona, ring ripples, a light helix, a fast width pulse). It pierces every
##                    enemy along the line (damage ticks), damages solid props it stops on, and slowly
##                    tracks the aim; where it hits, a flare boils with rings and sparks. At the end it
##                    thins to a line and leaves a fading after-image.
##   COOLDOWN (7 s):  shown on the HUD and the touch button.
## Damage is reported through the mech, so it builds heat and overdrive like other attacks.

## The beam itself (see the shader).
const BEAM_SHADER := preload("res://player/weapons/mega_beam.gdshader")
const TINT_SHADER := preload("res://player/weapons/mega_beam_tint.gdshader")
const GLOW := preload("res://assets/fx/glow.tres")
## How long the beam takes to shoot out to its end, the opening flash, the closing squeeze to a line, and
## the after-image.
const REACH_TIME := 0.08
const FLASH_TIME := 0.16
const THIN_TIME := 0.18
const AFTERGLOW := 0.3

@export var charge_time := 0.55
@export var fire_time := 1.0
@export var cooldown := 7.0
@export var max_length := 1150.0
@export var width := 44.0
@export var damage_per_tick := 13.0
@export var tick := 0.08
@export var turn_rate := 2.2

enum State { READY, CHARGE, FIRE, COOLDOWN }

var state := State.READY
var cooldown_left := 0.0
var mech: Node2D
var _t := 0.0
var _tick_t := 0.0
var _dir := Vector2.RIGHT
var _start := Vector2.ZERO
var _end := Vector2.ZERO
var _add := CanvasItemMaterial.new()
var _body: Node2D
var _body_mat := ShaderMaterial.new()
var _tint: Node2D
var _tint_mat := ShaderMaterial.new()
## Impact spark timer, and the beam colour of the current shot.
var _spark_t := 0.0
var _col := Color(1.0, 0.35, 0.8)
## Set by the mech every frame (Power Core upgrade).
var damage_mult := 1.0


func _ready() -> void:
	top_level = true
	z_index = 7
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _add
	_body_mat.shader = BEAM_SHADER
	# Under the beam: a normal-blend colour band (keeps the corona saturated on bright floors).
	_tint_mat.shader = TINT_SHADER
	_tint = Node2D.new()
	_tint.material = _tint_mat
	_tint.show_behind_parent = true
	_tint.draw.connect(_draw_quad.bind(_tint, _tint_mat))
	add_child(_tint)
	_body = Node2D.new()
	_body.material = _body_mat
	_body.show_behind_parent = true
	_body.draw.connect(_draw_quad.bind(_body, _body_mat))
	add_child(_body)


func is_busy() -> bool:
	return state == State.CHARGE or state == State.FIRE


## 0..1 recharge progress (1 = ready).
func ready_fraction() -> float:
	return 1.0 if state == State.READY else (0.0 if is_busy() else 1.0 - cooldown_left / cooldown)


## How much the mech's movement is slowed right now (1 = normal).
func move_factor() -> float:
	return 0.45 if state == State.CHARGE else (0.25 if state == State.FIRE else 1.0)


func try_fire(aim: Vector2) -> bool:
	if state != State.READY:
		return false
	state = State.CHARGE
	_t = 0.0
	_dir = aim.normalized()
	Sfx.play(&"charge", -4.0, 0.0)
	return true


## The beam colour: the pilot's energy colour (gold in overdrive), like the rifle's shots.
func _beam_color() -> Color:
	return mech._shot_color() if mech and mech.has_method("_shot_color") else Color(1.0, 0.35, 0.8)


func update(delta: float, aim: Vector2, muzzle: Vector2, overdrive: bool) -> void:
	_t += delta
	if state == State.CHARGE or state == State.FIRE:
		_col = _beam_color()
	match state:
		State.CHARGE:
			_dir = aim.normalized()
			_start = muzzle
			_end = _trace(muzzle, _dir)
			if _t >= charge_time:
				state = State.FIRE
				_t = 0.0
				_tick_t = 0.0
				Sfx.play(&"beam_rifle", 0.0, 0.0)
				Sfx.play(&"laser", -4.0, 0.0)
				Combat.shake(0.45)
				Combat.hitstop(0.06)
				# The firing flash: shockwave rings punch out of the muzzle.
				Combat.shockwave(muzzle, 170.0, _col, 0.4)
				Combat.shockwave(muzzle, 95.0, Color(1, 1, 1, 0.9), 0.22)
		State.FIRE:
			# Slowly sweeps toward the aim while firing.
			var a := _dir.angle()
			a = rotate_toward(a, aim.angle(), turn_rate * delta)
			_dir = Vector2.from_angle(a)
			_start = muzzle
			_end = _trace(muzzle, _dir)
			if mech and mech.has_method("recoil"):
				mech.recoil(-_dir * 450.0 * delta)
			_tick_t -= delta
			if _tick_t <= 0.0:
				_tick_t = tick
				_damage_tick(1.5 if overdrive else 1.0)
				Combat.shake(0.08)
			# Sparks spray off the impact point.
			_spark_t -= delta
			if _spark_t <= 0.0 and _t > REACH_TIME:
				_spark_t = 0.07
				Combat.burst(_end, _col.lightened(0.3), 380.0, 0.8)
			if _t >= fire_time:
				state = State.COOLDOWN
				cooldown_left = cooldown
				_t = 0.0
		State.COOLDOWN:
			cooldown_left -= delta
			if cooldown_left <= 0.0:
				cooldown_left = 0.0
				state = State.READY
	queue_redraw()
	_tint.queue_redraw()
	_body.queue_redraw()


## The beam's radius (px): the hit width plus its corona.
func _radius() -> float:
	return width * 0.85


## The beam body (shader quad) under the muzzle flash and impact (show_behind_parent).
## One beam quad (the colour band, then the beam itself) on `node` with its shader material `mat`.
func _draw_quad(node: Node2D, mat: ShaderMaterial) -> void:
	if state != State.FIRE:
		return
	var length := maxf(_start.distance_to(_end), 1.0)
	var h := _radius() * 1.6 * 2.0
	mat.set_shader_parameter("beam_color", _col)
	mat.set_shader_parameter("length_px", length)
	mat.set_shader_parameter("t", _t)
	mat.set_shader_parameter("intensity", 1.0 - smoothstep(fire_time - 0.05, fire_time, _t))
	mat.set_shader_parameter("reach", clampf(_t / REACH_TIME, 0.0, 1.0))
	mat.set_shader_parameter("thin", 1.0 - 0.92 * smoothstep(fire_time - THIN_TIME, fire_time, _t))
	# (a textured rect, so the shader gets UVs running 0..1 along and across the beam)
	node.draw_set_transform(_start, _dir.angle())
	node.draw_texture_rect(white_tex(), Rect2(0, -h / 2.0, length, h), false)
	node.draw_set_transform(Vector2.ZERO)


## A small white texture the shader beams are drawn with (shared).
static var _white: Texture2D


static func white_tex() -> Texture2D:
	if _white == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(img)
	return _white


## Beam end: first wall (layer 1) or solid obstacle/prop (layer 6) along the line.
func _trace(from: Vector2, dir: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * max_length, 1 | 32)
	if mech is CollisionObject2D:
		q.exclude = [mech.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit.position if not hit.is_empty() else from + dir * max_length


func _damage_tick(mult: float) -> void:
	var dmg := damage_per_tick * mult * damage_mult
	for n in get_tree().get_nodes_in_group("damageable"):
		if not is_instance_valid(n) or n == mech or n.is_in_group("player") or n.get("dead") == true:
			continue
		var r: float = n.get("hit_radius") if n.get("hit_radius") != null else 20.0
		var p: Vector2 = n.global_position
		if Geometry2D.get_closest_point_to_segment(p, _start, _end).distance_to(p) <= width * 0.5 + r:
			n.take_damage(dmg, _start, mech)
			if n.has_method("knock"):
				n.knock(_dir * 120.0)
	for n in get_tree().get_nodes_in_group("destructibles"):
		if is_instance_valid(n):
			var p: Vector2 = n.global_position
			var r: float = n.get("hit_radius") if n.get("hit_radius") != null else 20.0
			if Geometry2D.get_closest_point_to_segment(p, _start, _end).distance_to(p) <= width * 0.5 + r:
				n.take_hit(dmg, _start)
	# Solid bases of enemy structures (outpost turrets) at the beam's end.
	var q := PhysicsRayQueryParameters2D.create(_start, _end + _dir * 8.0, 32)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit.collider.has_meta("owner_enemy"):
		var e: Node = hit.collider.get_meta("owner_enemy")
		if is_instance_valid(e):
			e.take_damage(dmg, _start, mech)
	Combat.spark(_end, _col.lightened(0.3), 1.4)


## Soft round glow (the shared radial gradient texture), radius `r`.
func _glow(p: Vector2, r: float, c: Color) -> void:
	draw_texture_rect(GLOW, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, c)


## Four-point lens-flare star at `p`: arms `along` the beam and `across` it.
func _flare(p: Vector2, along: float, across: float, c: Color) -> void:
	var d := _dir * along
	var n := _dir.orthogonal() * across
	var k := minf(along, across) * 0.14
	var dk := _dir * k
	var nk := _dir.orthogonal() * k
	draw_colored_polygon(PackedVector2Array([p + d, p + dk + nk, p + n, p - dk + nk, p - d, p - dk - nk, p - n,
		p + dk - nk]), c)


## A four-point sparkle `r` long around the origin (under a draw transform).
func _flare_local(r: float, c: Color) -> void:
	var k := r * 0.14
	draw_colored_polygon(PackedVector2Array([Vector2(r, 0), Vector2(k, k), Vector2(0, r), Vector2(-k, k), Vector2(-r, 0),
		Vector2(-k, -k), Vector2(0, -r), Vector2(k, -k)]), c)


func _draw() -> void:
	var white := Color(1, 1, 1)
	match state:
		State.CHARGE:
			var k := clampf(_t / charge_time, 0.0, 1.0)
			var flick := 0.85 + 0.15 * sin(_t * 70.0)
			# Targeting line.
			draw_line(_start, _end, Color(_col, 0.18 + 0.25 * k), 1.5, true)
			draw_circle(_end, 5.0 + 5.0 * k, Color(_col, 0.35))
			# Energy particles sucked into the muzzle, faster and brighter as the charge builds.
			for i in 22:
				var ph := fmod(_t * (1.6 + 1.6 * k) + i * 0.137, 1.0)
				var ang := i * 2.4 + _t * 6.0 * (1.0 if i % 2 == 0 else -1.0)
				var r := (1.0 - ph) * (110.0 - 40.0 * k)
				var p := _start + Vector2.from_angle(ang + ph * 3.0) * r
				var c := _col.lerp(white, ph * 0.6)
				draw_line(p, p + (_start - p).normalized() * (4.0 + 8.0 * ph), Color(c, (0.3 + 0.6 * k) * ph), 2.0, true)
			# A ring closing in on the muzzle.
			var ring_r := lerpf(80.0, 18.0, k)
			draw_arc(_start, ring_r, _t * 8.0, _t * 8.0 + TAU * 0.8, 32, Color(_col.lightened(0.3), 0.3 + 0.5 * k),
				2.0 + 2.0 * k, true)
			# The orb of light growing at the muzzle: colour bloom, white-hot heart, a twinkle.
			_glow(_start, (24.0 + 46.0 * k) * flick, Color(_col, 0.45 + 0.45 * k))
			_glow(_start, (10.0 + 20.0 * k * k) * flick, Color(_col.lerp(white, 0.7), 0.8))
			draw_circle(_start, (3.0 + 7.0 * k * k) * flick, white)
			if k > 0.5:
				_flare(_start, 26.0 * k * flick, 26.0 * k * flick, Color(1, 1, 1, (k - 0.5) * 1.6))
		State.FIRE:
			var length := _start.distance_to(_end)
			var reach := clampf(_t / REACH_TIME, 0.0, 1.0)
			var head := _start + _dir * length * reach
			var pulse := 1.0 + 0.1 * sin(_t * 60.0)
			var thin := 1.0 - 0.9 * smoothstep(fire_time - THIN_TIME, fire_time, _t)
			# Firing flash: a big white lens flare, an anamorphic streak across the beam, a bright bloom.
			if _t < FLASH_TIME:
				var a := 1.0 - _t / FLASH_TIME
				_glow(_start, 150.0 * a, Color(_col, 0.8 * a))
				_glow(_start, 60.0 * a, Color(1, 1, 1, a))
				_flare(_start, 120.0 * a, 70.0 * a, Color(1, 1, 1, a))
				draw_set_transform(_start, _dir.angle() + PI / 2, Vector2(1.0, 0.07))
				draw_texture_rect(GLOW, Rect2(-360, -360, 720, 720), false, Color(_col.lerp(white, 0.5), 0.9 * a))
				draw_set_transform(Vector2.ZERO)
			# Muzzle: a white-hot orb with a coloured bloom, throbbing, and a turning sparkle.
			_glow(_start, 64.0 * pulse * thin, Color(_col, 0.7))
			_glow(_start, 26.0 * pulse, Color(_col.lerp(white, 0.6), 0.9))
			draw_circle(_start, 10.0 * pulse * thin + 2.0, white)
			draw_set_transform(_start, _t * 6.0, Vector2.ONE)
			_flare_local(30.0 * pulse * thin, Color(1, 1, 1, 0.75))
			draw_set_transform(Vector2.ZERO)
			# Impact: a boiling flare where the beam hits, rings rippling out of it.
			if reach >= 1.0:
				var boil := 1.0 + 0.15 * sin(_t * 47.0) + 0.1 * sin(_t * 23.0)
				_glow(_end, 110.0 * boil * thin, Color(_col, 0.7))
				_glow(_end, 44.0 * boil, Color(_col.lerp(white, 0.6), 0.95))
				draw_circle(_end, 13.0 * boil * thin + 3.0, white)
				for i in 3:
					var ph := fmod(_t * 3.5 + i / 3.0, 1.0)
					draw_arc(_end, 20.0 + 80.0 * ph, 0.0, TAU, 36, Color(_col.lightened(0.3), (1.0 - ph) * 0.75 * thin),
						3.0, true)
			else:
				_glow(head, 40.0, Color(_col.lerp(white, 0.5), 0.9))
		State.COOLDOWN:
			# After-image: the beam's path fades as a thin line; the muzzle glow dies down.
			if _t < AFTERGLOW:
				var a := 1.0 - _t / AFTERGLOW
				draw_line(_start, _end, Color(_col, 0.5 * a * a), 6.0 * a, true)
				draw_line(_start, _end, Color(1, 1, 1, 0.8 * a * a), 1.5, true)
				_glow(_start, 40.0 * a, Color(_col, 0.6 * a))
				_glow(_end, 60.0 * a, Color(_col, 0.5 * a))
