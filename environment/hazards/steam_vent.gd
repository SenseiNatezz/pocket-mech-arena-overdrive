extends Area2D
## Steam vent hazard on a painted floor grate. Cycles IDLE (light wisps) -> WARNING (hiss, pulsing
## ring, ~0.9 s) -> ERUPTION (scalding steam column that hurts the player AND enemies on it).

@export var radius := 90.0
@export var idle_time := 3.2
@export var warn_time := 0.9
@export var erupt_time := 1.3
@export var damage_per_tick := 9.0
@export var tick := 0.4
@export var phase := 0.0
## Gas color: white steam (arctic) or toxic green (jungle).
@export var gas_color := Color(1, 1, 1)

enum State { IDLE, WARN, ERUPT }

var state := State.IDLE
var _t := 0.0
var _tick_t := 0.0
var _steam: CPUParticles2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 256
	monitorable = false
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius * 0.8
	shape.shape = c
	add_child(shape)
	z_index = 3
	_steam = CPUParticles2D.new()
	_steam.amount = 60
	_steam.lifetime = 1.4
	_steam.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_steam.emission_sphere_radius = radius * 0.45
	_steam.direction = Vector2.UP
	_steam.spread = 18.0
	_steam.gravity = Vector2(0, -40)
	_steam.texture = preload("res://assets/fx/glow.tres")
	_steam.scale_amount_min = 0.35
	_steam.scale_amount_max = 0.9
	var ramp := Gradient.new()
	ramp.set_color(0, Color(gas_color, 0.55))
	ramp.set_color(1, Color(gas_color.lerp(Color(0.85, 0.92, 1.0), 0.3), 0.0))
	_steam.color_ramp = ramp
	add_child(_steam)
	_t = fposmod(phase, idle_time + warn_time + erupt_time)


func _physics_process(delta: float) -> void:
	_t += delta
	var cycle := idle_time + warn_time + erupt_time
	if _t >= cycle:
		_t -= cycle
	var s := State.IDLE if _t < idle_time else (State.WARN if _t < idle_time + warn_time else State.ERUPT)
	if s != state:
		state = s
		if state == State.ERUPT:
			_tick_t = 0.0
			Sfx.play(&"dash", -8.0, 0.1)
		elif state == State.WARN:
			Sfx.play(&"charge", -18.0)
	match state:
		State.IDLE:
			_steam.initial_velocity_min = 20.0
			_steam.initial_velocity_max = 50.0
			_steam.modulate.a = 0.15
		State.WARN:
			_steam.initial_velocity_min = 60.0
			_steam.initial_velocity_max = 120.0
			_steam.modulate.a = 0.45
		State.ERUPT:
			_steam.initial_velocity_min = 260.0
			_steam.initial_velocity_max = 420.0
			_steam.modulate.a = 1.0
			_tick_t -= delta
			if _tick_t <= 0.0:
				_tick_t = tick
				for b in get_overlapping_bodies():
					if b.has_method("take_damage") and not (b.get("dead") == true):
						b.take_damage(damage_per_tick, b.global_position + Vector2(0, 1), self)
	queue_redraw()


func _draw() -> void:
	if state == State.WARN:
		var k := (_t - idle_time) / warn_time
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(1.0, 0.85, 0.5, 0.5 + 0.4 * sin(_t * 30.0)), 3.0, true)
		draw_circle(Vector2.ZERO, radius * k, Color(1.0, 0.7, 0.3, 0.15))
	elif state == State.ERUPT:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.12))
		draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(1.0, 0.6, 0.3, 0.6), 2.0, true)
