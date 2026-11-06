class_name LavaPool
extends Node2D
## A puddle of molten slag left by the Volcanic Forge robots (Magma Crawler trails, Slagspitter globs,
## the Vulcan boss). Grows in, bubbles, burns the player while they stand in it (ticks match the mech's
## short hit-invulnerability), then crusts over and fades. Never hurts robots.
## Damage scales with the robot that made it (its damage_mult, read at hit time while it's alive).

const TICK := 0.4
const ORANGE := Color(1.0, 0.42, 0.08)
const YELLOW := Color(1.0, 0.85, 0.35)
const CRUST := Color(0.16, 0.07, 0.05)

var radius := 50.0
var life := 4.0
var dps := 12.0
var source: Node
var _mult := 1.0
var _age := 0.0
var _tick := 0.2
var _seed := 0


## Drops a pool at `pos` (world). `source` = the robot that made it (for damage scaling / credit).
## `delay` = seconds before it appears (e.g. when a lobbed glob lands), even if the robot is gone by then.
static func spawn(pos: Vector2, r: float, seconds: float, damage_per_second: float, from: Node = null,
		delay := 0.0) -> LavaPool:
	var p := LavaPool.new()
	p.global_position = pos
	p.radius = r
	p.life = seconds
	p.dps = damage_per_second
	p.source = from
	p._age = -delay
	if is_instance_valid(from) and from.get("damage_mult") != null:
		p._mult = from.damage_mult
	p.z_index = -1
	p._seed = randi()
	p.add_to_group("lava_pools")
	Combat.world().add_child(p)
	return p


func _process(delta: float) -> void:
	_age += delta
	if _age < 0.0:
		return
	if is_instance_valid(source) and source.get("damage_mult") != null:
		_mult = source.damage_mult
	_tick -= delta
	if _tick <= 0.0 and _hot() > 0.5:
		_tick = TICK
		var mech := get_tree().get_first_node_in_group("player") as Node2D
		if mech and not mech.get("dead") and mech.global_position.distance_to(global_position) < radius * _size() + 10.0:
			mech.take_damage(dps * TICK * _mult, global_position, source if is_instance_valid(source) else null)
	if _age >= life:
		queue_free()
	queue_redraw()


## 0..1 growth (quick swell in, slow shrink at the end).
func _size() -> float:
	return clampf(_age / 0.25, 0.0, 1.0) * lerpf(1.0, 0.6, clampf((_age - life + 0.8) / 0.8, 0.0, 1.0))


## 1 while molten, dropping to 0 as it crusts over in the last second.
func _hot() -> float:
	return clampf((life - _age) / 1.0, 0.0, 1.0)


func _draw() -> void:
	if _age < 0.0:
		return
	var r := radius * _size()
	if r < 2.0:
		return
	var hot := _hot()
	# Lumpy outline that changes in steps (like the cel-drawn effects).
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var pts := PackedVector2Array()
	for i in 14:
		pts.append(Vector2.from_angle(TAU * i / 14.0) * r * rng.randf_range(0.82, 1.08))
	var frame := int(_age * 8.0)
	var inner := PackedVector2Array()
	for p in pts:
		inner.append(p * 0.72)
	draw_colored_polygon(_grow(pts, 1.12), Color(CRUST, 0.8))
	draw_colored_polygon(pts, ORANGE.lerp(CRUST.lightened(0.15), 1.0 - hot))
	draw_colored_polygon(inner, YELLOW.lerp(ORANGE.darkened(0.3), 1.0 - hot))
	if hot > 0.3:
		# Bubbles popping (a new set every step).
		var b := RandomNumberGenerator.new()
		b.seed = _seed + frame
		for i in 3:
			var at := Vector2.from_angle(b.randf() * TAU) * r * b.randf_range(0.1, 0.6)
			var br := b.randf_range(3.0, 7.0) * (0.6 + 0.4 * hot)
			draw_circle(at, br + 1.5, Color(CRUST, 0.6 * hot))
			draw_circle(at, br, Color(1.0, 0.95, 0.7, 0.9 * hot))
	# A faint warning ring so the edge reads on the dark floor.
	draw_arc(Vector2.ZERO, r * 1.05, 0, TAU, 28, Color(ORANGE, 0.35 * hot), 2.0, true)


func _grow(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * k)
	return out
