class_name SmokePuff
extends Node2D
## A soft puff of smoke / dust (normal blend, so it darkens the floor instead of glowing): swells, drifts,
## and fades. Used for gun smoke, bullet-hit dust, explosion smoke columns and burning wrecks.
##   SmokePuff.spawn(pos, color, radius, seconds, drift)

const GLOW := preload("res://assets/fx/glow.tres")

var color := Color(0.4, 0.4, 0.42)
var radius := 16.0
var life := 0.6
var drift := Vector2.ZERO
var _t := 0.0
var _spin := 0.0


static func spawn(pos: Vector2, col: Color, r: float, seconds: float, velocity := Vector2.ZERO, z := 3) -> SmokePuff:
	var p := SmokePuff.new()
	p.global_position = pos
	p.color = col
	p.radius = r
	p.life = seconds
	p.drift = velocity
	p.z_index = z
	p._spin = randf() * TAU
	Combat.world().add_child(p)
	return p


func _process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	position += drift * delta
	drift *= exp(-1.5 * delta)
	queue_redraw()


func _draw() -> void:
	var k := _t / life
	var r := radius * (0.55 + 0.75 * sqrt(k))
	var a := color.a * (1.0 - k) * minf(1.0, _t / 0.05)
	# Three overlapping lobes so it isn't a perfect circle.
	for i in 3:
		var off := Vector2.from_angle(_spin + i * TAU / 3.0) * r * 0.32
		draw_texture_rect(GLOW, Rect2(off - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(color, a * 0.75))
