class_name DuneBurrower
extends Enemy
## "Dune Burrower" (Higgsfield sprite, Titan Graveyard): a drill-nosed digger. It dives under the sand
## (a moving mound - nothing can hit it down there), tunnels after you, then a ring of churning sand opens
## under you (the telegraph) and it bursts out: a blast that throws you back plus a ring of sand shards.
## Freshly surfaced it is slow and exposed for a moment - that's the time to punish it.

const TEX := preload("res://assets/hq/enemies6/dune_burrower.png")
const SPRITE_SCALE := 0.48
const SAND := Color(0.95, 0.76, 0.46)
const SAND_DARK := Color(0.62, 0.42, 0.22)
const TURQ := Color(0.3, 1.0, 0.85)
const DIG_SPEED := 230.0
const DIVE_TIME := 0.45
const TUNNEL_MAX := 3.2
const WARN := 0.75
const ERUPT_R := 95.0
const EXPOSED := 1.5

@export var erupt_damage := 10.0

enum State { SURFACED, DIVE, TUNNEL, WARN, EMERGE }

var _state := State.SURFACED
var _st := 1.2
var _mark := Vector2.ZERO
## 0 = above ground, 1 = fully under the sand.
var _sink := 0.0
var _puff_t := 0.0
var _contact := 0.0


func _ready() -> void:
	super._ready()
	_contact = contact_damage
	_st = randf_range(0.6, 1.4)


func is_buried() -> bool:
	return _state == State.TUNNEL or _state == State.WARN


func _set_buried(b: bool) -> void:
	collision_layer = 0 if b else 256
	$Hurtbox.collision_layer = 0 if b else 4
	contact_damage = 0.0 if b else _contact
	if b:
		remove_from_group("damageable")
	else:
		add_to_group("damageable")


func _think(delta: float) -> void:
	_st -= delta
	match _state:
		State.SURFACED:
			_sink = move_toward(_sink, 0.0, delta * 3.0)
			facing = Vector2.from_angle(rotate_toward(facing.angle(), dir_to_target().angle(), 5.0 * delta))
			steer_to(target.global_position, move_speed * 0.55)
			if _st <= 0.0:
				_state = State.DIVE
				_st = DIVE_TIME
				Combat.burst(global_position, SAND, 220.0, 1.3)
				Sfx.play(&"dash", -12.0, 0.2)
		State.DIVE:
			_sink = 1.0 - _st / DIVE_TIME
			if _st <= 0.0:
				_sink = 1.0
				_set_buried(true)
				_state = State.TUNNEL
				_st = TUNNEL_MAX
		State.TUNNEL:
			steer_to(target.global_position, DIG_SPEED)
			if velocity.length() > 20.0:
				facing = velocity.normalized()
			_puff_t -= delta
			if _puff_t <= 0.0:
				_puff_t = 0.12
				Combat.spark(global_position + Vector2(randf_range(-14, 14), randf_range(-14, 14)), SAND, 0.8)
			if dist_to_target() < 70.0 or _st <= 0.0:
				_state = State.WARN
				_st = WARN
				_mark = target.global_position + target.velocity * 0.2
				Sfx.play(&"charge", -14.0, 0.2)
		State.WARN:
			desired_velocity = (_mark - global_position).limit_length(DIG_SPEED * 1.4)
			if _st <= 0.0:
				_erupt()
		State.EMERGE:
			_sink = move_toward(_sink, 0.0, delta * 4.0)
			if _st <= 0.0:
				_state = State.SURFACED
				_st = randf_range(2.2, 3.0)


func _erupt() -> void:
	# (stays where the tunnel got it if the mark is behind a wall)
	if has_line_of_sight(_mark):
		global_position = _mark
	_set_buried(false)
	_state = State.EMERGE
	_st = EXPOSED
	Combat.area_damage(global_position, ERUPT_R, erupt_damage * damage_mult, self, true, Vector2.ZERO, PI, 320.0)
	Combat.shockwave(global_position, ERUPT_R * 1.4, SAND, 0.4)
	Combat.burst(global_position, SAND, 420.0, 1.8)
	Combat.debris(global_position, 30.0, SAND_DARK)
	Combat.shake(0.2)
	Sfx.play(&"slam", -8.0, 0.15)
	for i in 8:
		shoot(Vector2.from_angle(TAU * i / 8.0 + randf() * 0.3), 260.0, 8.0, SAND, 1.0)


func _draw() -> void:
	if _state == State.WARN:
		var at := _mark - global_position
		var k := 1.0 - _st / WARN
		draw_circle(at, ERUPT_R, Color(SAND_DARK, 0.18 + 0.2 * k))
		draw_arc(at, ERUPT_R, 0, TAU, 40, Color(1.0, 0.45, 0.2, 0.9), 3.0, true)
		draw_arc(at, ERUPT_R * k, 0, TAU, 40, Color(SAND, 0.8), 2.5, true)
		for i in 6:
			var a := _t * 3.0 + TAU * i / 6.0
			draw_line(at + Vector2.from_angle(a) * ERUPT_R * 0.35, at + Vector2.from_angle(a + 0.5) * ERUPT_R * 0.8,
				Color(SAND, 0.6), 2.0, true)
	if is_buried():
		# The sand mound over the tunnelling drill.
		var wob := 1.0 + 0.08 * sin(_t * 18.0)
		draw_set_transform(Vector2.ZERO, facing.angle(), Vector2(1.25 * wob, 0.85))
		draw_circle(Vector2.ZERO, 30.0, Color(SAND_DARK, 0.55))
		draw_circle(Vector2(-4, -3), 22.0, Color(SAND, 0.7))
		draw_set_transform(Vector2.ZERO)
		return
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var s := Vector2.ONE * SPRITE_SCALE * (1.0 - 0.35 * _sink)
	draw_set_transform(Vector2(5, 8), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.4 * (1.0 - _sink)))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, tint(Color(1, 1, 1, 1.0 - 0.6 * _sink)))
	draw_set_transform(Vector2.ZERO)
	if _state == State.EMERGE:
		draw_arc(Vector2.ZERO, hit_radius + 10.0, 0, TAU, 32, Color(TURQ, 0.5 * _st / EXPOSED), 2.0, true)
	draw_hp_bar(-hit_radius - 24)
