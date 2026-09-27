extends Node2D
## Parallax background: the arenas are elevated platforms, and far below them (visible past the
## edges and through pits) is a lit ruined city. Built from Parallax2D layers drawn procedurally:
##   far layer  - city blocks with lit windows + street light trails (slow parallax)
##   haze layer - drifting smog clouds (medium parallax + autoscroll)
##   near layer - sparse drifting embers/ash (faster parallax)

@export var tint := Color(1, 1, 1)
@export var seed_value := 3
## Extra autoscroll for menus (world scenes leave this at zero; the camera drives the parallax).
@export var drift := Vector2.ZERO

const TILE := 1024.0


func _ready() -> void:
	z_index = -20
	_add_layer(0.25, _draw_city, drift * 0.4)
	_add_layer(0.45, _draw_haze, Vector2(-12, -5) + drift * 0.7)
	_add_layer(0.7, _draw_ash, Vector2(-25, 18) + drift)


func _add_layer(scale: float, painter: Callable, auto: Vector2) -> void:
	var p := Parallax2D.new()
	p.scroll_scale = Vector2(scale, scale)
	p.repeat_size = Vector2(TILE, TILE)
	p.repeat_times = 3
	p.autoscroll = auto
	var canvas := Node2D.new()
	canvas.draw.connect(painter.bind(canvas))
	canvas.modulate = tint
	p.add_child(canvas)
	add_child(p)


func _draw_city(c: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	c.draw_rect(Rect2(0, 0, TILE, TILE), Color(0.04, 0.05, 0.09))
	# Street grid glow.
	for i in 5:
		var y := i * TILE / 5.0 + 90.0
		c.draw_rect(Rect2(0, y - 10, TILE, 20), Color(0.08, 0.07, 0.12))
		c.draw_line(Vector2(0, y), Vector2(TILE, y), Color(1.0, 0.55, 0.2, 0.25), 2.0)
		var x := i * TILE / 5.0 + 60.0
		c.draw_rect(Rect2(x - 10, 0, 20, TILE), Color(0.08, 0.07, 0.12))
		c.draw_line(Vector2(x, 0), Vector2(x, TILE), Color(0.3, 0.8, 1.0, 0.2), 2.0)
	# Light trails (cars).
	for i in 40:
		var horiz := rng.randf() < 0.5
		var lane := rng.randi_range(0, 4) * TILE / 5.0 + (90.0 if horiz else 60.0) + rng.randf_range(-5, 5)
		var at := rng.randf_range(0, TILE)
		var col := Color(1.0, 0.3, 0.25, 0.7) if rng.randf() < 0.5 else Color(1.0, 0.95, 0.8, 0.7)
		if horiz:
			c.draw_line(Vector2(at, lane), Vector2(at + 18, lane), col, 2.0)
		else:
			c.draw_line(Vector2(lane, at), Vector2(lane, at + 18), col, 2.0)
	# Rooftops.
	for i in 150:
		var w := rng.randf_range(28, 90)
		var h := rng.randf_range(28, 90)
		var p := Vector2(rng.randf_range(0, TILE - w), rng.randf_range(0, TILE - h))
		var shade := rng.randf_range(0.07, 0.16)
		var roof := Color(shade * 0.8, shade * 0.85, shade * 1.3)
		c.draw_rect(Rect2(p + Vector2(5, 7), Vector2(w, h)), Color(0, 0, 0, 0.45))
		c.draw_rect(Rect2(p, Vector2(w, h)), roof)
		c.draw_rect(Rect2(p, Vector2(w, 2)), roof.lightened(0.2))
		var lit := rng.randf()
		for k in rng.randi_range(0, 6):
			var wp := p + Vector2(rng.randf_range(3, w - 6), rng.randf_range(3, h - 6))
			var col: Color = [Color(0.4, 0.9, 1.0), Color(1.0, 0.75, 0.35), Color(1.0, 0.3, 0.7)][int(lit * 3.0) % 3]
			c.draw_rect(Rect2(wp, Vector2(3, 3)), Color(col, rng.randf_range(0.4, 0.9)))
		if rng.randf() < 0.08:
			c.draw_circle(p + Vector2(w, h) / 2, 3, Color(1.0, 0.2, 0.15, 0.9))
			c.draw_circle(p + Vector2(w, h) / 2, 12, Color(1.0, 0.2, 0.15, 0.15))


func _draw_haze(c: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 11
	for i in 26:
		var p := Vector2(rng.randf_range(0, TILE), rng.randf_range(0, TILE))
		var r := rng.randf_range(80, 220)
		for k in 4:
			c.draw_circle(p, r * (1.0 - k * 0.2), Color(0.35, 0.3, 0.45, 0.035))


func _draw_ash(c: Node2D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 23
	for i in 70:
		var p := Vector2(rng.randf_range(0, TILE), rng.randf_range(0, TILE))
		var ember := rng.randf() < 0.3
		c.draw_circle(p, rng.randf_range(1.0, 2.2), Color(1.0, 0.5, 0.2, 0.6) if ember else Color(0.7, 0.7, 0.75, 0.25))
