extends Node2D
## Orbit Blades upgrade: energy blades circling the mech. They slice enemies they touch (each enemy
## at most every HIT_COOLDOWN seconds) and cut enemy bullets out of the air.

const RADIUS := 105.0
const BLADE_HIT := 22.0
const DAMAGE := 18.0
const HIT_COOLDOWN := 0.45
const SPIN := 3.4

var mech: Mech
var _a := 0.0
## Enemy instance id -> seconds until that enemy can be hit again.
var _cd := {}


func _ready() -> void:
	z_index = 3
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


func blade_positions() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := Upgrades.blade_count()
	for i in n:
		pts.append(mech.global_position + Vector2.from_angle(_a + TAU * i / n) * RADIUS)
	return pts


func _physics_process(delta: float) -> void:
	_a = fmod(_a + SPIN * delta, TAU)
	for id in _cd.keys():
		_cd[id] -= delta
		if _cd[id] <= 0.0:
			_cd.erase(id)
	visible = Upgrades.blade_count() > 0 and not mech.dead
	if not visible:
		return
	var pts := blade_positions()
	var color := Game.energy_color()
	for e in Combat.enemies_in_area(mech.global_position, RADIUS + BLADE_HIT + 90.0):
		var id := e.get_instance_id()
		if _cd.has(id):
			continue
		var r: float = e.get("hit_radius") if e.get("hit_radius") != null else 20.0
		for p in pts:
			if p.distance_to(e.global_position) < BLADE_HIT + r:
				e.take_damage(DAMAGE * Upgrades.damage_mult(), p, mech)
				if e.has_method("knock"):
					e.knock((e.global_position - mech.global_position).normalized() * 160.0)
				Combat.spark(p, color, 0.9)
				_cd[id] = HIT_COOLDOWN
				break
	for p in pts:
		Combat.deflect_bullets(p, BLADE_HIT + 8.0)
	queue_redraw()


func _draw() -> void:
	var n := Upgrades.blade_count()
	var color := Game.energy_color()
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 64, Color(color, 0.08), 3.0, true)
	for i in n:
		var a := _a + TAU * i / n
		var c := Vector2.from_angle(a) * RADIUS
		var t := Vector2.from_angle(a + PI / 2)  # blade points along the orbit
		var o := Vector2.from_angle(a)
		var blade := PackedVector2Array([c + t * 24.0, c + o * 7.0, c - t * 16.0, c - o * 7.0])
		draw_circle(c, 22.0, Color(color, 0.16))
		draw_colored_polygon(blade, Color(color, 0.85))
		draw_colored_polygon(PackedVector2Array([c + t * 18.0, c + o * 3.0, c - t * 10.0, c - o * 3.0]), Color(1, 1, 1, 0.9))
