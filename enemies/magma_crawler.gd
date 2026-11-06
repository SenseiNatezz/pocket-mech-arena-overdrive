class_name MagmaCrawler
extends Enemy
## "Magma Crawler" (Higgsfield sprite, Volcanic Forge): a six-legged foundry beetle carrying a sac of
## molten slag. Scuttles at you dripping small LavaPools behind it; close in, its sac flares (telegraph)
## and it lunges to bite. When destroyed the sac bursts: a short blast and a big pool of lava - don't
## finish it off at point-blank range.

const TEX := preload("res://assets/hq/enemies5/magma_crawler.png")
const SPRITE_SCALE := 0.5
const LUNGE_RANGE := 180.0
const WINDUP := 0.4
const LUNGE_SPEED := 560.0
const LUNGE_TIME := 0.28
const TRAIL_EVERY := 0.85

@export var bite_damage := 14.0
@export var trail_dps := 9.0

enum State { WALK, WINDUP, LUNGE, RECOVER }

var _state := State.WALK
var _st := 0.0
var _lunge_cd := 1.2
var _trail_t := 0.5
var _lunge_dir := Vector2.ZERO
var _bit := false


func die() -> void:
	if dead:
		return
	var p := global_position
	super.die()
	Combat.explode(p, 90.0, 12.0 * damage_mult, self, "player", LavaPool.ORANGE, 220.0)
	LavaPool.spawn(p, 78.0, 5.0, trail_dps * 1.4, null)


func _think(delta: float) -> void:
	_st -= delta
	_lunge_cd -= delta
	var to_t := dir_to_target()
	var d := dist_to_target()
	match _state:
		State.WALK:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 6.0 * delta))
			steer_to(target.global_position)
			_trail_t -= delta
			if _trail_t <= 0.0 and velocity.length() > 30.0:
				_trail_t = TRAIL_EVERY
				LavaPool.spawn(global_position - facing * hit_radius, 30.0, 3.2, trail_dps, self)
			if _lunge_cd <= 0.0 and d < LUNGE_RANGE and has_line_of_sight(target.global_position):
				_state = State.WINDUP
				_st = WINDUP
				Sfx.play(&"charge", -14.0, 0.15)
		State.WINDUP:
			facing = Vector2.from_angle(rotate_toward(facing.angle(), to_t.angle(), 8.0 * delta))
			if _st <= 0.0:
				_state = State.LUNGE
				_st = LUNGE_TIME
				_lunge_dir = facing
				_bit = false
				Sfx.play(&"dash", -10.0, 0.15)
		State.LUNGE:
			desired_velocity = _lunge_dir * LUNGE_SPEED
			velocity = desired_velocity
			if not _bit and d < hit_radius + 34.0:
				_bit = true
				target.take_damage(bite_damage * damage_mult, global_position, self)
				Combat.spark(target.global_position, LavaPool.ORANGE, 1.2)
			if _st <= 0.0:
				_state = State.RECOVER
				_st = 0.6
		State.RECOVER:
			if _st <= 0.0:
				_state = State.WALK
				_lunge_cd = 1.6


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var half := TEX.get_size() / 2
	var skitter := sin(_t * 22.0) * 0.03 if velocity.length() > 20.0 else 0.0
	var s := Vector2(SPRITE_SCALE + skitter, SPRITE_SCALE - skitter)
	draw_set_transform(Vector2(6, 9), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.4))
	draw_set_transform(Vector2.ZERO, rot, s)
	var glow := 0.0
	if _state == State.WINDUP:
		glow = 1.0 - _st / WINDUP
	elif _state == State.LUNGE:
		glow = 1.0
	draw_texture(TEX, -half, tint(Color.WHITE.lerp(Color(1.6, 1.1, 0.7), glow * 0.5)))
	draw_set_transform(Vector2.ZERO)
	# The molten sac pulses (brighter while it winds up).
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	draw_circle(-facing * 6.0, 18.0 + 6.0 * pulse + 10.0 * glow, Color(LavaPool.ORANGE, 0.12 + 0.12 * pulse + 0.25 * glow))
	draw_hp_bar(-hit_radius - 26)
