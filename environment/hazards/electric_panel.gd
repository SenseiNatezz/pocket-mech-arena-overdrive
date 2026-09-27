extends Area2D
## Electrified floor panel. Cycles OFF -> WARNING (sparks, ~0.8 s) -> LIVE (hurts anything standing
## on it: the player and enemies alike). `size` is in pixels; `phase` offsets the cycle so a row of
## panels can ripple.

@export var size := Vector2(128, 128)
@export var off_time := 2.6
@export var warn_time := 0.8
@export var live_time := 1.6
@export var damage_per_tick := 10.0
@export var tick := 0.45
@export var phase := 0.0

enum State { OFF, WARN, LIVE }

var state := State.OFF
var _t := 0.0
var _tick_t := 0.0
var _bolts: Array[PackedVector2Array] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 256  # player body, enemy bodies
	monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size - Vector2(12, 12)
	shape.shape = box
	add_child(shape)
	z_index = -6
	_t = fposmod(phase, off_time + warn_time + live_time)


func _physics_process(delta: float) -> void:
	_t += delta
	var cycle := off_time + warn_time + live_time
	if _t >= cycle:
		_t -= cycle
	var new_state := State.OFF if _t < off_time else (State.WARN if _t < off_time + warn_time else State.LIVE)
	if new_state != state:
		state = new_state
		if state == State.LIVE:
			_tick_t = 0.0
			Sfx.play(&"charge", -14.0)
	if state == State.LIVE:
		_tick_t -= delta
		if _tick_t <= 0.0:
			_tick_t = tick
			for b in get_overlapping_bodies():
				if b.has_method("take_damage") and not (b.get("dead") == true):
					b.take_damage(damage_per_tick, b.global_position + Vector2(0, 1), self)
					Combat.spark(b.global_position, Color(0.5, 0.9, 1.0), 1.2)
	if state != State.OFF and (Engine.get_physics_frames() % 3 == 0):
		_regen_bolts()
	queue_redraw()


func _regen_bolts() -> void:
	_bolts.clear()
	var n := 2 if state == State.WARN else 6
	var half := size / 2 - Vector2(10, 10)
	for i in n:
		var pts := PackedVector2Array()
		var a := Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		var b := Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		for s in 7:
			var p := a.lerp(b, s / 6.0)
			if s > 0 and s < 6:
				p += Vector2(randf_range(-9, 9), randf_range(-9, 9))
			pts.append(p)
		_bolts.append(pts)


func _draw() -> void:
	var r := Rect2(-size / 2, size)
	draw_rect(r, Color(0.1, 0.13, 0.17, 0.92))
	var live := state == State.LIVE
	var glow := Color(0.35, 0.85, 1.0)
	var line_a := 0.18 if state == State.OFF else (0.45 + 0.4 * sin(_t * 30.0) if state == State.WARN else 0.9)
	var step := 16.0
	var x := r.position.x + step
	while x < r.end.x:
		draw_line(Vector2(x, r.position.y + 6), Vector2(x, r.end.y - 6), Color(glow, line_a * 0.5), 2.0)
		x += step
	draw_rect(r, Color(0.9, 0.75, 0.15, 0.9), false, 3.0)
	draw_rect(r.grow(-6), Color(glow, line_a), false, 2.0)
	if live:
		draw_rect(r, Color(glow, 0.16 + 0.06 * sin(_t * 40.0)))
	for pts in _bolts:
		draw_polyline(pts, Color(0.75, 0.95, 1.0, 0.95 if live else 0.5), 2.5 if live else 1.5, true)
	# Lightning-bolt warning glyph in the corner.
	var c := r.position + Vector2(14, 14)
	draw_colored_polygon(PackedVector2Array([c + Vector2(2, -8), c + Vector2(-4, 1), c + Vector2(0, 1), c + Vector2(-2, 8),
		c + Vector2(4, -1), c + Vector2(0, -1)]), Color(1.0, 0.85, 0.2))
