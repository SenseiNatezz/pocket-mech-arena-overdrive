class_name ScrapMite
extends Enemy
## "Scrap Mite": the HORDE robot. A small, fast, rust-red scavenger that comes in packs (EncounterZone wave
## kind "mite", spawned PACK at a time from one warp ring) to fill the gaps between the tough robots. Dies to
## a hit or two, nips for light contact damage, and is worth a fraction of a normal kill (xp_chance: XP
## shards and scrap).
## Kept cheap so dozens can run at once, even on phones: no pathfinding agent (straight at the pilot with a
## per-mite flanking weave, sliding along walls; one goes round a wall it is stuck on with a navmesh agent
## made only then), it doesn't collide with other robots or the mech, a light death puff, and it draws a
## shrunken, rust-tinted Scrap Hound.

const TEX := preload("res://assets/hq/scrap_hound.png")
const SPRITE_SCALE := 0.3
const RUST := Color(1.0, 0.62, 0.48)
## How much of a normal kill a mite is worth (XP shard chance, scrap share).
@export var xp_chance := 0.35

## Every mite alive (for the cheap spacing push: a pack spreads into a ring round the pilot instead of
## stacking into one blob on top of it).
static var _all: Array[ScrapMite] = []
const SPACING := 34.0
## Circling distance from the pilot, and the dart-in bite (seconds left / cooldown).
const RING := 95.0
var _bite := 0.0
var _bite_cd := 0.0
var _weave := 0.0
var _side := 1.0
var _stuck_t := 0.0
var _last_pos := Vector2.ZERO
var _detour := 0.0


func _init() -> void:
	swarm = true


func _ready() -> void:
	super._ready()
	# Bodies only bump into walls / cover / pits (not other robots or the mech), so a pack flows round you.
	collision_layer = 0
	collision_mask = 1 | 32 | 64
	_weave = randf() * TAU
	_side = -1.0 if randf() < 0.5 else 1.0
	_spawn_t = 0.25
	_last_pos = global_position
	_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


func _has_ground_shadow() -> bool:
	return false


func _think(delta: float) -> void:
	var to := target.global_position - global_position
	var d := to.length()
	if d < 1.0:
		return
	var dir := to / d
	# Weave in from the side while still far off (packs spread into a ring instead of a single file).
	var weave := clampf((d - 90.0) / 300.0, 0.0, 1.0) * 0.55
	dir = (dir + dir.orthogonal() * _side * weave * (0.6 + 0.4 * sin(_t * 3.0 + _weave))).normalized()
	# Stuck on a wall for a moment: go round it on the navmesh for a while.
	_stuck_t += delta
	if _stuck_t >= 0.5:
		var moved := global_position.distance_to(_last_pos)
		_last_pos = global_position
		_stuck_t = 0.0
		if moved < 20.0 and d > 80.0:
			_detour = 1.5
	# Biting: they circle the pilot at RING and take turns darting in for a nip (contact damage needs them
	# within hit_radius + 24 of it), then fall back - so a pack rings you instead of piling on top.
	_bite_cd -= delta
	if _bite > 0.0:
		_bite -= delta
		desired_velocity = dir * move_speed * 1.5
		if velocity.length() > 20.0:
			facing = velocity.normalized()
		return
	if d < RING + 30.0 and _bite_cd <= 0.0:
		_bite = 0.3
		_bite_cd = randf_range(1.3, 2.6)
		return
	if d < RING:
		dir = (-dir * 0.7 + dir.orthogonal() * _side).normalized()
	elif d < RING + 60.0:
		dir = (dir * 0.3 + dir.orthogonal() * _side).normalized()
	# Spacing: pushed off mites that are too close.
	var push := Vector2.ZERO
	for m in _all:
		if m == self or not is_instance_valid(m):
			continue
		var off := global_position - m.global_position
		var dd := off.length()
		if dd < SPACING and dd > 0.01:
			push += off / dd * (1.0 - dd / SPACING)
	dir += push * 1.4
	if _detour > 0.0:
		_detour -= delta
		if _agent == null:
			_agent = NavigationAgent2D.new()
			_agent.path_desired_distance = 24.0
			_agent.target_desired_distance = 24.0
			_agent.radius = hit_radius
			add_child(_agent)
		steer_to(target.global_position)
	else:
		desired_velocity = dir.limit_length(1.4) * move_speed
	if velocity.length() > 20.0:
		facing = velocity.normalized()


func die() -> void:
	if dead:
		return
	dead = true
	Combat.spark(global_position, Color(1.0, 0.6, 0.3), 0.7)
	Combat.burst(global_position, Color(0.45, 0.32, 0.26), 160.0, 0.8)
	Combat.report_kill(self)
	died.emit(self)
	queue_free()


func _draw() -> void:
	var rot := facing.angle() + PI / 2
	var gait := sin(_t * 26.0) * 0.07 if velocity.length() > 30.0 else 0.0
	var s := Vector2(1.0 - gait, 1.0 + gait) * SPRITE_SCALE
	var half := TEX.get_size() / 2
	draw_set_transform(Vector2(4, 6), rot, s)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2.ZERO, rot, s)
	draw_texture(TEX, -half, tint(RUST))
	draw_set_transform(Vector2.ZERO)
	draw_hp_bar(-hit_radius - 10.0)
