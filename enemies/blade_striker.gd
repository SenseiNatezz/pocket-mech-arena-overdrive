class_name BladeStriker
extends Enemy
## "Blade Striker" (Higgsfield sprite): light ninja mech with twin magenta energy katanas. Weaves in
## fast, then telegraphs (blades flare + a thin line along the dash) and dash-slashes through the
## player's position, leaving afterimages. It's wide open for a moment after every slash.

const TEX := preload("res://assets/hq/enemies2/blade_striker.png")
const SPRITE_SCALE := 0.6
const BLADE := Color(1.0, 0.25, 0.85)
const WINDUP := 0.42
const DASH_TIME := 0.24

@export var slash_range := 200.0
@export var dash_speed := 980.0
@export var slash_damage := 16.0

enum State { STALK, WINDUP, DASH, RECOVER }

var _state := State.STALK
var _st := 0.0
var _cd := 1.0
var _dash_dir := Vector2.DOWN
var _hit_done := false
var _weave := 1.0
var _slash_fx := 0.0
var _trail: Array[Vector2] = []


func _ready() -> void:
	super._ready()
	_weave = [-1.0, 1.0].pick_random()


func _think(delta: float) -> void:
	_cd -= delta
	_st -= delta
	match _state:
		State.STALK:
			var to_t := dir_to_target()
			facing = facing.slerp(to_t, 1.0 - exp(-10.0 * delta))
			var d := dist_to_target()
			var los := has_line_of_sight(target.global_position)
			if d > slash_range or not los:
				steer_to(target.global_position)
				if los:
					desired_velocity += to_t.orthogonal() * _weave * move_speed * 0.5 * sin(_t * 3.0)
			else:
				desired_velocity = to_t.orthogonal() * _weave * move_speed * 0.6
			if _cd <= 0.0 and los and d < slash_range + 40.0:
				_state = State.WINDUP
				_st = WINDUP
				Sfx.play(&"select", -8.0, 0.2)
		State.WINDUP:
			# Tracks the player until the last instant, then commits.
			if _st > 0.12:
				_dash_dir = dir_to_target()
				facing = _dash_dir
			if _st <= 0.0:
				_state = State.DASH
				_st = DASH_TIME
				_hit_done = false
				_trail.clear()
				Sfx.play(&"saber", -5.0)
		State.DASH:
			desired_velocity = _dash_dir * dash_speed
			velocity = desired_velocity
			_trail.push_front(global_position)
			if _trail.size() > 6:
				_trail.pop_back()
			if not _hit_done and dist_to_target() < hit_radius + 64.0 and dir_to_target().dot(_dash_dir) > -0.4:
				_hit_done = true
				_slash_fx = 1.0
				target.take_damage(slash_damage * damage_mult, global_position, self)
				Combat.spark(target.global_position, BLADE, 1.3)
			if _st <= 0.0 or (get_slide_collision_count() > 0 and _st < DASH_TIME - 0.06):
				_state = State.RECOVER
				_st = 0.75
				_slash_fx = maxf(_slash_fx, 0.8)
				_weave = -_weave
		State.RECOVER:
			if _st <= 0.0:
				_state = State.STALK
				_cd = randf_range(1.1, 1.8)


func _process(delta: float) -> void:
	_slash_fx = move_toward(_slash_fx, 0.0, delta * 3.5)
	if _state != State.DASH and not _trail.is_empty() and Engine.get_process_frames() % 2 == 0:
		_trail.pop_back()


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var run := sin(_t * 14.0) * 0.03 if velocity.length() > 30.0 and _state != State.DASH else 0.0
	var s := Vector2(SPRITE_SCALE + run, SPRITE_SCALE - run)
	# Dash afterimages.
	for i in _trail.size():
		draw_set_transform(to_local(_trail[i]), rot, s)
		draw_texture(TEX, -half, Color(1.0, 0.3, 0.9, 0.32 * (1.0 - i / float(_trail.size()))))
	draw_set_transform(Vector2(6, 9), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.4))
	var body := tint(Color.WHITE)
	if _state == State.WINDUP:
		body = body.lerp(Color(1.6, 0.8, 1.6), 0.5 + 0.5 * sin(_t * 40.0))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, body)
	draw_set_transform(Vector2.ZERO)
	if _state == State.WINDUP:
		var k := 1.0 - _st / WINDUP
		var reach := _dash_dir * dash_speed * DASH_TIME
		draw_line(Vector2.ZERO, reach, Color(BLADE, 0.12 + 0.2 * k), 30.0)
		draw_line(Vector2.ZERO, reach, Color(BLADE, 0.6 + 0.4 * k), 2.0)
		draw_circle(Vector2.ZERO, hit_radius * (1.6 - 0.5 * k), Color(BLADE, 0.15 + 0.15 * k))
	if _slash_fx > 0.0:
		var a := facing.angle()
		draw_arc(Vector2.ZERO, 70.0, a - 1.4, a + 1.4, 20, Color(BLADE, 0.5 * _slash_fx), 18.0 * _slash_fx, true)
		draw_arc(Vector2.ZERO, 74.0, a - 1.2, a + 1.2, 20, Color(1, 0.9, 1, 0.9 * _slash_fx), 3.0, true)
	draw_hp_bar(-hit_radius - 34)
