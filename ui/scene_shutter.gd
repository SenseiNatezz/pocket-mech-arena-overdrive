class_name SceneShutter
extends CanvasLayer
## Screen transition between scenes (Game._change): two armoured blast doors slide in from the sides and
## meet on an angled seam (dark gunmetal, hazard edge, a cyan light line along the seam), the scene changes
## behind them, then they part again. Runs while paused; skipped in headless runs (tests).
##   await shutter.close()   doors shut (CLOSE_TIME)
##   shutter.open()          doors part (OPEN_TIME)

const CLOSE_TIME := 0.2
const OPEN_TIME := 0.32
const SLANT := 70.0

var _k := 0.0   # 0 open .. 1 shut
var _tw: Tween
var _canvas: Control


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_doors)
	add_child(_canvas)
	visible = false


func close() -> void:
	visible = true
	_go(1.0, CLOSE_TIME, Tween.EASE_IN)
	await _tw.finished


func open() -> void:
	_go(0.0, OPEN_TIME, Tween.EASE_OUT)
	_tw.finished.connect(func() -> void: visible = _k > 0.001)


func _go(to: float, t: float, ease: Tween.EaseType) -> void:
	if _tw:
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(func(v: float) -> void:
		_k = v
		_canvas.queue_redraw(), _k, to, t).set_trans(Tween.TRANS_CUBIC).set_ease(ease)


func _draw_doors() -> void:
	if _k <= 0.001:
		return
	var vp := _canvas.size
	# Fully shut, both seams meet on the same slanted line through the middle.
	var w := (vp.x / 2.0 + SLANT * 0.5) * _k
	var ink := Color(0.05, 0.065, 0.09)
	var plate := Color(0.1, 0.12, 0.16)
	# Left door: its right edge slants (top further right).
	var l: PackedVector2Array
	var r: PackedVector2Array
	if w > SLANT:
		l = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - SLANT, vp.y), Vector2(0, vp.y)])
		r = PackedVector2Array([Vector2(vp.x, 0), Vector2(vp.x - w + SLANT, 0), Vector2(vp.x - w, vp.y), Vector2(vp.x, vp.y)])
	else:
		# Just starting out: each door is still a corner triangle.
		l = PackedVector2Array([Vector2(0, 0), Vector2(maxf(w, 1.0), 0), Vector2(0, vp.y * maxf(w, 1.0) / SLANT)])
		r = PackedVector2Array([Vector2(vp.x, vp.y * (1.0 - maxf(w, 1.0) / SLANT)), Vector2(vp.x - maxf(w, 1.0), vp.y), Vector2(vp.x, vp.y)])
		_canvas.draw_colored_polygon(l, ink)
		_canvas.draw_colored_polygon(r, ink)
		return
	for door in [l, r]:
		_canvas.draw_colored_polygon(door, ink)
	# Panel lines + a few rivets so the doors read as armour.
	for i in 5:
		var y := vp.y * (i + 1) / 6.0
		_canvas.draw_line(Vector2(0, y), Vector2(maxf(w - 80.0, 0.0), y), plate, 3.0)
		_canvas.draw_line(Vector2(vp.x, y), Vector2(vp.x - maxf(w - 80.0, 0.0), y), plate, 3.0)
	# The seam edges: hazard stripe band + cyan light line, brightest as they meet.
	var glow := Color(0.35, 0.78, 1.0, 0.5 + 0.5 * _k)
	_canvas.draw_line(l[1], l[2], glow, 3.0, true)
	_canvas.draw_line(r[1], r[2], glow, 3.0, true)
	var gold := Color(1.0, 0.8, 0.3, 0.85)
	_canvas.draw_line(l[1] - Vector2(14, 0), l[2] - Vector2(14, 0), gold, 4.0, true)
	_canvas.draw_line(r[1] + Vector2(14, 0), r[2] + Vector2(14, 0), gold, 4.0, true)
