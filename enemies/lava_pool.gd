class_name LavaPool
extends Node2D
## A puddle of molten slag left by the Volcanic Forge robots (Magma Crawler trails, Slagspitter globs,
## the Vulcan boss). Grows in, churns, burns the player while they stand in it (ticks match the mech's
## short hit-invulnerability), then crusts over and fades. Never hurts robots.
## Look: fx/lava_pool.gdshader (flowing magma, crust plates with glowing cracks spreading in as it cools,
## scorched rim, heat glow on the floor) + embers rising off it. Lies on the floor under the robots.
## Damage scales with the robot that made it (its damage_mult, read at hit time while it's alive).

const TICK := 0.4
const SHADER := preload("res://fx/lava_pool.gdshader")
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
	# On the floor: under robots and the mech (painted maps sit at z -10, decals at -7).
	p.z_as_relative = false
	p.z_index = -6
	p._seed = randi()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("seed", float(p._seed % 1000) * 0.137)
	p.material = mat
	var e := Embers.new()
	e.pool = p
	p.add_child(e)
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
		# (PARTS HOVER: the Hover Skirt floats over it)
		if mech and not mech.get("dead") and not Parts.hovers(mech) and mech.global_position.distance_to(global_position) < radius * _size() + 10.0:
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
	var m := material as ShaderMaterial
	m.set_shader_parameter("hot", _hot())
	m.set_shader_parameter("grow", 1.0)
	var h := r * 1.35
	draw_texture_rect(_white(), Rect2(-h, -h, h * 2.0, h * 2.0), false)


static var _white_tex: Texture2D


static func _white() -> Texture2D:
	if _white_tex == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


## Embers rising off the molten pool (additive sparks; fewer as it crusts over).
class Embers:
	extends Node2D
	var pool: LavaPool
	var _t := 0.0

	func _ready() -> void:
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		material = add
		_t = randf() * 10.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if pool._age < 0.0:
			return
		var r := pool.radius * pool._size()
		var hot := pool._hot()
		var n := clampi(int(r / 9.0), 3, 10)
		for i in n:
			var cyc := fmod(_t * 0.7 + i * 0.37, 1.0)
			var a := float(i) * 2.399 + float(pool._seed % 100)
			var base := Vector2.from_angle(a) * r * 0.65 * fmod(i * 0.618, 1.0)
			var p := base + Vector2(sin(_t * 2.0 + i) * 4.0, -cyc * 46.0)
			var alpha := hot * (1.0 - cyc) * minf(cyc * 5.0, 1.0)
			draw_circle(p, 2.2 * (1.0 - cyc) + 0.8, Color(1.0, 0.6, 0.2, alpha))
		# Hot shimmer over the molten middle.
		draw_texture_rect(RifleFx.GLOW, Rect2(-r, -r, r * 2.0, r * 2.0), false, Color(1.0, 0.45, 0.1, 0.22 * hot))
