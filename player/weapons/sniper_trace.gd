extends Node2D
## Sniper Beam shot visual: a searing line from the muzzle to where the shot stopped, which thins out
## and fades. Spawned into the Combat world (world coordinates).

const LIFE := 0.28

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color(0.5, 0.9, 1.0)
var _t := 0.0


func _ready() -> void:
	z_index = 6
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var fade := 1.0 - k
	var w := lerpf(18.0, 2.0, k)
	draw_line(from, to, Color(color, 0.22 * fade), w * 2.8)
	draw_line(from, to, Color(color, 0.75 * fade), w)
	draw_line(from, to, Color(1, 1, 1, fade), maxf(w * 0.35, 1.5))
	draw_circle(to, 6.0 + 20.0 * fade, Color(color, 0.45 * fade))
	draw_circle(from, 16.0 * fade, Color(1, 1, 1, 0.8 * fade))
