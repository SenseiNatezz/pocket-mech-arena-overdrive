class_name Lobber
extends Enemy
## "Mortar Crab": slow artillery walker. Stays far back and lobs shells at where you're heading. Each
## shell shows a red telegraph circle ~1 s before it lands.

@export var preferred_range := Vector2(380, 700)
@export var fire_cooldown := 2.8
@export var shell_damage := 18.0
@export var shell_radius := 72.0
@export var shells_per_volley := 1

var _cd := 1.5
var _recoil := 0.0


func _think(delta: float) -> void:
	facing = dir_to_target()
	var d := dist_to_target()
	if d > preferred_range.y:
		steer_to(target.global_position)
	elif d < preferred_range.x:
		desired_velocity = -facing * move_speed
	_cd -= delta
	_recoil = move_toward(_recoil, 0.0, delta * 3.0)
	if _cd <= 0.0 and d < 900.0:
		_cd = fire_cooldown
		_recoil = 1.0
		for i in shells_per_volley:
			var lead := target.velocity * 0.7
			var spot := target.global_position + lead + Vector2.from_angle(randf() * TAU) * randf_range(0, 60) * i
			Combat.artillery(spot, shell_radius, shell_damage * damage_mult, self, 1.0 + i * 0.2, "player",
				global_position + Vector2(0, -20))
		Sfx.play(&"missile", -8.0)


func _draw() -> void:
	draw_circle(Vector2(4, 10), hit_radius, Color(0, 0, 0, 0.3))
	var body := tint(Color(0.5, 0.42, 0.22))
	var step := sin(_t * 10.0) * 4.0 if velocity.length() > 20.0 else 0.0
	for i in 3:
		for side in [-1, 1]:
			var y := -10.0 + i * 10.0
			draw_line(Vector2(side * 14, y), Vector2(side * (30 + step * (1 if i % 2 == 0 else -1)), y + 8), Color(0.22, 0.2, 0.18), 4.0)
	draw_circle(Vector2.ZERO, hit_radius, body.darkened(0.3))
	draw_circle(Vector2(0, -3), hit_radius - 5, body)
	# Mortar tube (points up = lobbing).
	var tube := Vector2(0, -8 + _recoil * 5.0)
	draw_rect(Rect2(tube + Vector2(-7, -18), Vector2(14, 20)), Color(0.2, 0.2, 0.22))
	draw_circle(tube + Vector2(0, -18), 7, Color(0.1, 0.1, 0.12))
	draw_circle(tube + Vector2(0, -18), 4, Color(1.0, 0.45, 0.15, 0.4 + 0.6 * clampf(1.0 - _cd / fire_cooldown, 0.0, 1.0)))
	for side in [-1, 1]:
		draw_circle(Vector2(side * 10, 6), 3, Color(1.0, 0.6, 0.2))
	draw_hp_bar(-hit_radius - 26)
