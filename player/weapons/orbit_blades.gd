extends Node2D
## Orbit Blades upgrade: energy blades circling the mech. They slice enemies they touch (each enemy
## at most every HIT_COOLDOWN seconds) and cut enemy bullets out of the air.
## BLADE STORM combo (Orbit Blades + Defense Shield): bigger blades on a wider orbit, 60% faster spin,
## 50% more damage, gold-edged with motion trails.

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
		pts.append(mech.global_position + Vector2.from_angle(_a + TAU * i / n) * _radius())
	return pts


func _physics_process(delta: float) -> void:
	_a = fmod(_a + SPIN * (1.6 if _storm() else 1.0) * delta, TAU)
	for id in _cd.keys():
		_cd[id] -= delta
		if _cd[id] <= 0.0:
			_cd.erase(id)
	visible = Upgrades.blade_count() > 0 and not mech.dead
	if not visible:
		return
	var pts := blade_positions()
	var color := Game.energy_color()
	for e in Combat.enemies_in_area(mech.global_position, _radius() + _hit() + 90.0):
		var id := e.get_instance_id()
		if _cd.has(id):
			continue
		var r: float = e.get("hit_radius") if e.get("hit_radius") != null else 20.0
		for p in pts:
			if p.distance_to(e.global_position) < _hit() + r:
				e.take_damage(DAMAGE * (1.5 if _storm() else 1.0) * Upgrades.damage_mult(), p, mech)
				if e.has_method("knock"):
					e.knock((e.global_position - mech.global_position).normalized() * 160.0)
				Combat.spark(p, color, 0.9)
				_cd[id] = HIT_COOLDOWN
				break
	for p in pts:
		Combat.deflect_bullets(p, _hit() + 8.0)
	queue_redraw()


func _draw() -> void:
	var n := Upgrades.blade_count()
	var color := Game.energy_color()
	var storm := _storm()
	var rad := _radius()
	var k := 1.4 if storm else 1.0
	draw_arc(Vector2.ZERO, rad, 0.0, TAU, 64, Color(color, 0.12 if storm else 0.08), 3.0, true)
	for i in n:
		var a := _a + TAU * i / n
		# Blade Storm: a fading motion trail behind each blade.
		if storm:
			for j in 4:
				var ta := a - (j + 1) * 0.09
				draw_circle(Vector2.from_angle(ta) * rad, 14.0 - j * 2.5, Color(color, 0.14 - j * 0.03))
		var c := Vector2.from_angle(a) * rad
		var t := Vector2.from_angle(a + PI / 2)  # blade points along the orbit
		var o := Vector2.from_angle(a)
		var blade := PackedVector2Array([c + t * 24.0 * k, c + o * 7.0 * k, c - t * 16.0 * k, c - o * 7.0 * k])
		draw_circle(c, 22.0 * k, Color(color, 0.16))
		draw_colored_polygon(blade, Color(color, 0.85))
		if storm:
			draw_polyline(PackedVector2Array([blade[0], blade[1], blade[2], blade[3], blade[0]]), Color(Upgrades.COMBO_GOLD, 0.9), 2.0, true)
		draw_colored_polygon(PackedVector2Array([c + t * 18.0 * k, c + o * 3.0 * k, c - t * 10.0 * k, c - o * 3.0 * k]), Color(1, 1, 1, 0.9))


func _storm() -> bool:
	return Upgrades.level_of(&"blade_storm") > 0


func _radius() -> float:
	return RADIUS * (1.25 if _storm() else 1.0)


func _hit() -> float:
	return BLADE_HIT * (1.4 if _storm() else 1.0)
