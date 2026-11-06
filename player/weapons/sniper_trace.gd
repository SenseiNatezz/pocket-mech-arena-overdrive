extends Node2D
## Sniper Beam shot visual: an animated energy lance (player/weapons/beam_body.gdshader - flowing plasma,
## filaments, pulse rings) from the muzzle to where the shot stopped. It hits at full width, then
## narrows to a white-hot thread and fades, with a flash ring at the muzzle and a burst at the impact.
## Spawned into the Combat world (world coordinates).

const LIFE := 0.34
const BODY_SHADER := preload("res://player/weapons/beam_body.gdshader")

var from := Vector2.ZERO
var to := Vector2.ZERO
var color := Color(0.5, 0.9, 1.0)
var _t := 0.0
var _body: Node2D
var _mat := ShaderMaterial.new()


func _ready() -> void:
	z_index = 6
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	_mat.shader = BODY_SHADER
	_mat.set_shader_parameter("beam_color", color)
	_mat.set_shader_parameter("edge_color", color.darkened(0.3))
	_mat.set_shader_parameter("flow_speed", 16.0)
	_body = Node2D.new()
	_body.material = _mat
	_body.show_behind_parent = true
	_body.draw.connect(_draw_body)
	add_child(_body)


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()
	_body.queue_redraw()


func _draw_body() -> void:
	var k := _t / LIFE
	var fade := 1.0 - k
	var length := maxf(from.distance_to(to), 1.0)
	var dir := (to - from) / length
	var h := lerpf(46.0, 8.0, ease(k, 0.6))
	_mat.set_shader_parameter("length_px", length)
	_mat.set_shader_parameter("t", _t + 0.37)
	_mat.set_shader_parameter("intensity", fade)
	_body.draw_set_transform(from, dir.angle())
	_body.draw_texture_rect(BeamCannon.white_tex(), Rect2(0, -h / 2.0, length, h), false)
	_body.draw_set_transform(Vector2.ZERO)


func _draw() -> void:
	var k := _t / LIFE
	var fade := 1.0 - k
	var w := lerpf(6.0, 1.5, k)
	draw_line(from, to, Color(1, 1, 1, fade), w)
	# Impact burst + ring, muzzle flash + ring.
	draw_circle(to, 8.0 + 24.0 * fade, Color(color, 0.45 * fade))
	draw_arc(to, 10.0 + 50.0 * k, 0.0, TAU, 28, Color(color.lightened(0.3), 0.8 * fade), 3.0, true)
	draw_circle(from, 18.0 * fade, Color(1, 1, 1, 0.8 * fade))
	draw_arc(from, 8.0 + 30.0 * k, 0.0, TAU, 20, Color(color, 0.7 * fade), 2.0, true)
