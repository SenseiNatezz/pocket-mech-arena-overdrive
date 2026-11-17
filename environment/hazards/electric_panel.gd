extends Area2D
## Electrified floor panel. Cycles OFF -> WARNING (sparks, ~0.8 s) -> LIVE (hurts anything standing
## on it: the player and enemies alike). `size` is in pixels; `phase` offsets the cycle so a row of
## panels can ripple.
## Looks: the painted panel (assets/hq/hazards/electric_panel.png, 2x art; corners kept, middle stretched to
## `size`), its coils lighting up as it charges, arcs crackling over the grille (an additive layer) and a
## cyan light on the floor around it while it's live.

const ART := preload("res://assets/hq/hazards/electric_panel.png")
## Corner / hazard-frame margin of the art (source px) kept unstretched.
const ART_MARGIN := 44.0
const GLOW_COL := Color(0.35, 0.85, 1.0)
static var _plate: StyleBoxTexture
var _fx: Node2D

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
	if _plate == null:
		_plate = StyleBoxTexture.new()
		_plate.texture = ART
		_plate.set_texture_margin_all(ART_MARGIN)
	# Coil glow + arcs on an additive layer above the plate.
	_fx = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_fx.material = add
	_fx.draw.connect(_draw_fx)
	add_child(_fx)


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
				if b.has_method("take_damage") and not (b.get("dead") == true) and not Parts.hovers(b):  # (PARTS HOVER)
					b.take_damage(damage_per_tick, b.global_position + Vector2(0, 1), self)
					Combat.spark(b.global_position, Color(0.5, 0.9, 1.0), 1.2)
	if state != State.OFF and (Engine.get_physics_frames() % 3 == 0):
		_regen_bolts()
	if state == State.LIVE:
		GroundFx.glow(get_instance_id() % 1000003, global_position, maxf(size.x, size.y) * 0.95, GLOW_COL,
			0.45 + 0.15 * sin(_t * 40.0))
	_fx.queue_redraw()


## Fresh arcs over the grille: a jagged main bolt with a fork or two (2 while it warns, 4 when live).
func _regen_bolts() -> void:
	_bolts.clear()
	var n := 2 if state == State.WARN else 4
	var half := size / 2 - Vector2(ART_MARGIN, ART_MARGIN) * 0.55
	for i in n:
		var a := Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		var b := Vector2(randf_range(-half.x, half.x), randf_range(-half.y, half.y))
		var pts := _jag(a, b, 9, 7.0)
		_bolts.append(pts)
		if state == State.LIVE and randf() < 0.45:
			var from := pts[randi_range(2, pts.size() - 3)]
			var to := (from + Vector2.from_angle(randf() * TAU) * randf_range(14.0, 30.0)).clamp(-half, half)
			_bolts.append(_jag(from, to, 4, 4.0))


func _jag(a: Vector2, b: Vector2, steps: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for s in steps + 1:
		var p := a.lerp(b, float(s) / steps)
		if s > 0 and s < steps:
			p += Vector2(randf_range(-amp, amp), randf_range(-amp, amp))
		pts.append(p)
	return pts


func _draw() -> void:
	# The painted plate (from 2x art: drawn at half scale so its frame keeps its size; the art's own bevels
	# shade its edge - no box around it).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(0.5, 0.5))
	draw_style_box(_plate, Rect2(-size, size * 2.0))
	draw_set_transform(Vector2.ZERO)


## Additive layer: the coils charge up (a WARN flicker, a steady glow when LIVE) and the arcs crackle -
## each bolt a wide soft halo, a blue body and a white-hot core.
func _draw_fx() -> void:
	if state == State.OFF:
		return
	var live := state == State.LIVE
	var inner := Rect2(-size / 2, size).grow(-ART_MARGIN * 0.5)
	var e := (0.5 + 0.12 * sin(_t * 40.0)) if live else (0.12 + 0.16 * absf(sin(_t * 26.0)))
	_fx.draw_rect(inner, Color(GLOW_COL, 0.22 * e))
	_fx.draw_texture_rect(GroundFx.GLOW, inner.grow(10), false, Color(GLOW_COL, 0.55 * e))
	for pts in _bolts:
		_fx.draw_polyline(pts, Color(GLOW_COL, 0.22 if live else 0.12), 9.0 if live else 6.0, true)
		_fx.draw_polyline(pts, Color(0.45, 0.85, 1.0, 0.75 if live else 0.4), 3.5 if live else 2.0, true)
		_fx.draw_polyline(pts, Color(1.0, 1.0, 1.0, 0.95 if live else 0.5), 1.4, true)
