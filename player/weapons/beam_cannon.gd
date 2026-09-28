class_name BeamCannon
extends Node2D
## Beam Cannon (Higgsfield VFX art in assets/hq/beam): the Gundam's special attack.
##   CHARGE (0.55 s): energy gathers at the muzzle (6-frame charge sheet) + a thin targeting laser;
##                    the mech slows down.
##   FIRE   (1.0 s):  a sustained beam from the muzzle to the first wall / solid obstacle. It pierces
##                    every enemy along the line (damage ticks), damages solid props it stops on, and
##                    slowly tracks the aim.
##   COOLDOWN (7 s):  shown on the HUD and the touch button.
## Damage is reported through the mech, so it builds heat and overdrive like other attacks.

const BODY := preload("res://assets/hq/beam/beam_body.png")
const MUZZLE := preload("res://assets/hq/beam/beam_muzzle_flash.png")
const IMPACT := preload("res://assets/hq/beam/beam_impact.png")
## Charge-up frames cut from the Higgsfield sheet with a soft edge (tools/cut_charge_frames.gd).
const CHARGE_FRAMES := 6

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
var _frames: Array[Texture2D] = []
var _add := CanvasItemMaterial.new()
## Set by the mech every frame (Power Core upgrade).
var damage_mult := 1.0


func _ready() -> void:
	top_level = true
	z_index = 7
	_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = _add
	for i in CHARGE_FRAMES:
		_frames.append(load("res://assets/hq/beam/charge_%d.png" % i))


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


func update(delta: float, aim: Vector2, muzzle: Vector2, overdrive: bool) -> void:
	_t += delta
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
	Combat.spark(_end, Color(0.5, 0.9, 1.0), 1.4)


func _draw() -> void:
	match state:
		State.CHARGE:
			var k := clampf(_t / charge_time, 0.0, 1.0)
			# Targeting laser.
			draw_line(_start, _end, Color(0.4, 0.85, 1.0, 0.25 + 0.3 * k), 2.0, true)
			draw_circle(_end, 6.0 + 6.0 * k, Color(0.5, 0.9, 1.0, 0.4))
			# Charge-up frames 0-4 growing at the muzzle.
			var f := mini(int(k * 5.0), 4)
			var s := 0.35 + 0.45 * k
			var tex := _frames[f]
			draw_set_transform(_start, _t * 5.0, Vector2(s, s))
			draw_texture(tex, -tex.get_size() / 2)
			draw_set_transform(Vector2.ZERO)
		State.FIRE:
			var pulse := 1.0 + 0.12 * sin(_t * 60.0)
			var fade := clampf((fire_time - _t) / 0.15, 0.0, 1.0) * clampf(_t / 0.06, 0.0, 1.0)
			var length := _start.distance_to(_end)
			var h := 190.0 * pulse * (0.4 + 0.6 * fade)
			# Beam body stretched muzzle -> end (scrolls for an energy-flow look).
			draw_set_transform(_start, _dir.angle(), Vector2.ONE)
			var scroll := fmod(_t * 2400.0, BODY.get_width())
			var x := -scroll
			while x < length:
				var seg := minf(BODY.get_width(), length - maxf(x, 0.0))
				var src_x := 0.0 if x >= 0.0 else -x
				var dst_x := maxf(x, 0.0)
				var w := minf(BODY.get_width() - src_x, length - dst_x)
				if w > 0.0:
					draw_texture_rect_region(BODY, Rect2(dst_x, -h / 2, w, h),
						Rect2(src_x, 0, w, BODY.get_height()), Color(1, 1, 1, fade))
				x += BODY.get_width()
			draw_set_transform(Vector2.ZERO)
			# Muzzle flash and impact burst.
			var ms := 0.55 * pulse
			draw_set_transform(_start, _t * 9.0, Vector2(ms, ms))
			draw_texture(MUZZLE, -MUZZLE.get_size() / 2, Color(1, 1, 1, fade))
			var is_ := (0.5 + 0.12 * sin(_t * 45.0)) * (0.5 + 0.5 * fade)
			draw_set_transform(_end, -_t * 7.0, Vector2(is_, is_))
			draw_texture(IMPACT, -IMPACT.get_size() / 2, Color(1, 1, 1, fade))
			draw_set_transform(Vector2.ZERO)
		State.COOLDOWN:
			# After-glow (frame 5) at the muzzle for a moment.
			if _t < 0.35:
				var tex := _frames[5]
				var a := 1.0 - _t / 0.35
				draw_set_transform(_start, 0.0, Vector2(0.6, 0.6))
				draw_texture(tex, -tex.get_size() / 2, Color(1, 1, 1, a))
				draw_set_transform(Vector2.ZERO)
