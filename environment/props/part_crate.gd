class_name PartCrate
extends Node2D
## PART CRATE (Game.drop_part_crate): what a RIVAL PILOT always drops, and a boss or a gold elite sometimes. A
## violet salvage crate that pops out of the wreck under a tall LOOT BEAM. Walk over it to open it - after
## WAIT seconds it comes to you by itself, and if the map ends first it opens on its own - and it holds a part
## you don't own yet (Game.find_part: a found-only part half the time), which comes home with the run's scrap.
## The HUD shows a PART FOUND toast. (All drawn in code.)

const COLOR := Color(0.78, 0.45, 1.0)
const HOT := Color(1.0, 0.85, 1.0)
const COLLECT_RANGE := 46.0
const WAIT := 6.0
const BEAM_H := 260.0
const GLOW := preload("res://assets/fx/glow.tres")

var _t := 0.0
var _pop := Vector2.ZERO
## Height above the floor while it bounces out of the wreck.
var _z := 0.0
var _vz := 420.0
var _speed := 0.0
var _opened := false
## The loot beam: a solid violet column (reads on bright floors - sand, snow) under an additive glow (reads on
## dark ones), both behind the crate.
var _column: Node2D
var _beam: Node2D
const SIZE := 1.3


func _ready() -> void:
	add_to_group("part_crates")
	z_index = 2
	_pop = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 120.0)
	_column = Node2D.new()
	_column.show_behind_parent = true
	_column.draw.connect(_draw_column)
	add_child(_column)
	_beam = Node2D.new()
	_beam.show_behind_parent = true
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam.material = add
	_beam.draw.connect(_draw_beam)
	add_child(_beam)
	Combat.shockwave(global_position, 110.0, COLOR, 0.45)
	Combat.burst(global_position, COLOR, 380.0, 1.3)
	Sfx.play(&"pickup", -4.0, 0.0)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_t += delta
	# Bounce out of the wreck.
	if _z > 0.0 or _vz > 0.0:
		_vz -= 1500.0 * delta
		_z = maxf(_z + _vz * delta, 0.0)
		if _z <= 0.0 and _vz < 0.0:
			_vz = -_vz * 0.35 if _vz < -160.0 else 0.0
			if _vz == 0.0:
				Combat.shockwave(global_position, 60.0, COLOR, 0.25)
	position += _pop * delta
	_pop = _pop.lerp(Vector2.ZERO, 1.0 - exp(-4.0 * delta))
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech and not mech.dead:
		var d := global_position.distance_to(mech.global_position)
		if d < COLLECT_RANGE + mech.hit_radius and _t > 0.6:
			open()
			return
		if _t > WAIT:
			_speed = minf(_speed + 1500.0 * delta, 950.0)
			global_position = global_position.move_toward(mech.global_position, _speed * delta)
	queue_redraw()
	_column.queue_redraw()
	_beam.queue_redraw()


## Opens it: the part is found (Game.find_part), with a burst of violet light.
func open(fx := true) -> void:
	if _opened:
		return
	_opened = true
	Game.find_part()
	if fx:
		Combat.shockwave(global_position, 150.0, COLOR, 0.45)
		Combat.shockwave(global_position, 80.0, HOT, 0.25)
		Combat.burst(global_position, COLOR, 520.0, 1.6)
		Combat.spark(global_position, HOT, 2.4)
		Sfx.play(&"levelup", -4.0, 0.0)
		Sfx.play(&"coin", -6.0, 0.0)
	queue_free()


## A map ending with the crate still on the floor opens it (nothing found is ever left behind).
func _exit_tree() -> void:
	if not _opened and Game.scrap_enabled:
		_opened = true
		Game.find_part(false)


## The solid part of the beam (normal blend): a deep violet column with bright edges, fading upward, and a
## pulsing ring on the floor.
func _draw_column() -> void:
	var fade := clampf(_t / 0.4, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	var deep := Color(0.42, 0.12, 0.7)
	var steps := 12
	for i in steps:
		var k0 := float(i) / steps
		var h := BEAM_H / steps + 1.0
		var y0 := -BEAM_H * k0
		var a := (1.0 - k0) * fade
		_column.draw_rect(Rect2(-13, y0 - h, 26, h), Color(deep, 0.42 * a))
		_column.draw_rect(Rect2(-14, y0 - h, 2, h), Color(COLOR.lightened(0.3), 0.75 * a))
		_column.draw_rect(Rect2(12, y0 - h, 2, h), Color(COLOR.lightened(0.3), 0.75 * a))
	var r := 34.0 + 10.0 * pulse
	_column.draw_arc(Vector2(0, 2), r, 0.0, TAU, 40, Color(deep, 0.55 * fade), 5.0, true)
	_column.draw_arc(Vector2(0, 2), r, 0.0, TAU, 40, Color(COLOR.lightened(0.4), 0.8 * fade), 2.0, true)


func _draw_beam() -> void:
	var pulse := 0.75 + 0.25 * sin(_t * 4.0)
	var fade := clampf(_t / 0.4, 0.0, 1.0)
	# A tall column of light: wide soft glow, then a thin bright core, both fading toward the top.
	var steps := 14
	for i in steps:
		var k0 := float(i) / steps
		var y0 := -BEAM_H * k0
		var h := BEAM_H / steps + 1.0
		var a := (1.0 - k0) * (1.0 - k0) * fade
		_beam.draw_rect(Rect2(-17, y0 - h, 34, h), Color(COLOR, 0.16 * a * pulse))
		_beam.draw_rect(Rect2(-5, y0 - h, 10, h), Color(HOT, 0.4 * a * pulse))
	_beam.draw_texture_rect(GLOW, Rect2(-70, -46, 140, 92), false, Color(COLOR, 0.55 * fade * pulse))
	# Rising motes.
	for i in 6:
		var k := fmod(_t * 0.5 + i / 6.0, 1.0)
		var p := Vector2(sin(i * 2.3 + _t * 1.7) * 10.0, -k * BEAM_H * 0.8)
		_beam.draw_circle(p, 2.6 * (1.0 - k) + 0.8, Color(HOT, 0.8 * (1.0 - k) * fade))


func _draw() -> void:
	var lift := Vector2(0, -_z - 4.0 * sin(_t * 3.0) - 6.0)
	# Shadow on the floor (smaller while it's up in the air).
	var sk := 1.0 / (1.0 + _z / 120.0)
	draw_texture_rect(GLOW, Rect2(Vector2(-30, -12) * sk * SIZE + Vector2(3, 8), Vector2(60, 26) * sk * SIZE), false,
		Color(0, 0, 0, 0.45))
	draw_set_transform(lift, 0.0, Vector2.ONE * SIZE)
	# The crate: a squat armoured box (top face lighter), violet trim, a glowing core window with a "?" in it.
	var body := PackedVector2Array([Vector2(-20, -10), Vector2(20, -10), Vector2(24, -4), Vector2(24, 14), Vector2(20, 18),
		Vector2(-20, 18), Vector2(-24, 14), Vector2(-24, -4)])
	draw_colored_polygon(body, Color(0.16, 0.13, 0.22))
	var top := PackedVector2Array([Vector2(-20, -22), Vector2(20, -22), Vector2(24, -16), Vector2(24, -4), Vector2(20, -10),
		Vector2(-20, -10), Vector2(-24, -4), Vector2(-24, -16)])
	draw_colored_polygon(top, Color(0.3, 0.26, 0.4))
	var edge := body.duplicate()
	edge.append(body[0])
	draw_polyline(edge, Color(COLOR, 0.95), 2.0, true)
	draw_line(Vector2(-20, -22), Vector2(20, -22), Color(HOT, 0.8), 2.0)
	draw_line(Vector2(-24, -16), Vector2(-24, -4), Color(COLOR, 0.8), 2.0)
	draw_line(Vector2(24, -16), Vector2(24, -4), Color(COLOR, 0.8), 2.0)
	# Hazard chevrons on the front.
	for s in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([Vector2(16 * s, 0), Vector2(20 * s, 4), Vector2(16 * s, 8), Vector2(12 * s, 4)]),
			Color(COLOR, 0.7))
	var pulse := 0.6 + 0.4 * sin(_t * 6.0)
	draw_rect(Rect2(-9, -2, 18, 14), Color(0.05, 0.02, 0.1))
	draw_texture_rect(GLOW, Rect2(-16, -10, 32, 30), false, Color(COLOR, 0.6 * pulse))
	draw_string(ThemeDB.fallback_font, Vector2(-9, 10), "?", HORIZONTAL_ALIGNMENT_CENTER, 18, 13, HOT)
	draw_set_transform(Vector2.ZERO)
