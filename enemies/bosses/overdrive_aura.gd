extends Node2D
## Boss OVERDRIVE glow (WardenBoss phase 4): heat pulses rippling out from the boss's edge, a ring of motes
## orbiting it, plus the nova telegraph - a ring that shrinks onto the boss while it charges
## (WardenBoss.nova_charge_k). Drawn over the boss (the big boss art would hide anything underneath).

var boss: WardenBoss
var _t := 0.0


func _ready() -> void:
	z_index = 1


func _process(delta: float) -> void:
	_t += delta
	if not is_instance_valid(boss) or boss.dead:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var r := maxf(boss.keep_out, boss.hit_radius * 1.3)
	var col := boss.accent
	var pulse := 0.5 + 0.5 * sin(_t * 9.0)
	for i in 3:
		var k := fmod(_t * 0.9 + i / 3.0, 1.0)
		draw_arc(Vector2.ZERO, r * (1.0 + 0.8 * k), 0.0, TAU, 64, Color(col.lightened(0.2), 0.6 * (1.0 - k)), 5.0 * (1.0 - k) + 1.5, true)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(col, 0.35 + 0.3 * pulse), 3.0, true)
	for i in 12:
		var a := TAU * i / 12.0 + _t * 0.7
		var p := Vector2.from_angle(a) * r * (1.05 + 0.08 * sin(_t * 3.0 + i))
		draw_circle(p, 4.0 + 2.5 * pulse, Color(col.lightened(0.45), 0.85))
	var c := boss.nova_charge_k()
	if c > 0.0:
		var rr := lerpf(r * 4.2, r * 1.1, c)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 64, Color(1, 0.95, 0.8, 0.35 + 0.5 * c), 3.0 + 4.0 * c, true)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 64, Color(col, 0.25 + 0.4 * c), 10.0 + 6.0 * c, true)
