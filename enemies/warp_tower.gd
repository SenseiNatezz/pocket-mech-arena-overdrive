class_name WarpTower
extends Enemy
## WARP TOWER (the WARP TOWERS sector objective, environment/sector_objective.gd): a stationary pylon that rises
## out of the floor and keeps warping in small packs of Scrap Mites (PACK every PACK_EVERY seconds, while fewer
## than MAX_MITES of its own are out) until it's destroyed. Tough, never moves, no contact damage. It always
## shows its health bar, and the HUD points arrows at it (group "objective_markers"). Drawn in code: an armoured
## hex base, a glowing warp core in a slowly turning ring cage, and a beam of light pulsing up out of the top.

const CYAN := Color(0.35, 0.95, 1.0)
const BASE_HP := 520.0
const PACK := 4
const PACK_EVERY := Vector2(7.0, 9.5)
const MAX_MITES := 12
const RISE := 0.8

## Set by the objective before it enters the tree: the arena's world node (where mites go) and its HP scale.
var world: Node
var hp_scale := 1.0
var _pack_t := 3.0
var _mites: Array[Node] = []
var _rise := 0.0


func _init() -> void:
	max_hp = BASE_HP
	move_speed = 0.0
	acceleration = 0.0
	contact_damage = 0.0
	hit_radius = 34.0


func _ready() -> void:
	max_hp *= hp_scale
	super._ready()
	add_to_group("objective_markers")
	_pack_t = randf_range(2.5, 4.0)
	collision_mask = 0  # (never moves: nothing to collide with)
	Combat.shockwave(global_position, 120.0, CYAN, 0.5)
	Combat.burst(global_position, CYAN, 360.0, 1.4)


func _think(delta: float) -> void:
	desired_velocity = Vector2.ZERO
	_rise = minf(_rise + delta / RISE, 1.0)
	_pack_t -= delta
	if _pack_t > 0.0:
		return
	_pack_t = randf_range(PACK_EVERY.x, PACK_EVERY.y)
	_mites.assign(_mites.filter(func(m: Node) -> bool: return is_instance_valid(m) and not m.get("dead")))
	if _mites.size() >= MAX_MITES or world == null:
		return
	# Warp ring, then the pack spills out of it.
	for k in 3:
		get_tree().create_timer(k * 0.18, false).timeout.connect(func() -> void:
			if is_inside_tree():
				Combat.shockwave(global_position, 90.0 - k * 20.0, CYAN, 0.3))
	get_tree().create_timer(0.55, false).timeout.connect(_spawn_pack)


func _spawn_pack() -> void:
	if dead or not is_inside_tree() or world == null:
		return
	for i in PACK:
		var m: Enemy = EncounterZone.ENEMIES["mite"].instantiate()
		m.position = global_position + Vector2.from_angle(TAU * i / PACK + randf() * 0.6) * randf_range(46.0, 70.0)
		m.max_hp *= hp_scale
		m.damage_mult = damage_mult
		world.add_child(m)
		_mites.append(m)


func knock(_impulse: Vector2) -> void:
	pass


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	velocity = Vector2.ZERO


func _draw() -> void:
	var k := _rise
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	# Ground glow + soft shadow.
	draw_texture_rect(GroundFx.GLOW, Rect2(-62, -36, 124, 76), false, Color(0, 0, 0, 0.4))
	draw_texture_rect(GroundFx.GLOW, Rect2(-80, -50, 160, 100), false, Color(CYAN, 0.18 + 0.12 * pulse))
	# Hex base (armoured plates, lit from the top-left).
	var base := PackedVector2Array()
	for i in 6:
		base.append(Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * Vector2(40, 28))
	draw_colored_polygon(base, tint(Color(0.17, 0.2, 0.26)))
	var rim := base.duplicate()
	rim.append(base[0])
	draw_polyline(rim, tint(Color(0.45, 0.55, 0.65)), 2.0, true)
	# The pylon rises out of the base: two armoured legs and a warp core between them.
	var h := 64.0 * k
	for s in [-1.0, 1.0]:
		var leg := PackedVector2Array([Vector2(16 * s, 4), Vector2(24 * s, 4), Vector2(14 * s, -h), Vector2(8 * s, -h)])
		draw_colored_polygon(leg, tint(Color(0.24, 0.28, 0.36) if s < 0.0 else Color(0.15, 0.18, 0.24)))
	var core := Vector2(0, -h * 0.55)
	draw_texture_rect(GroundFx.GLOW, Rect2(core - Vector2(34, 34), Vector2(68, 68)), false, Color(CYAN, 0.55 + 0.3 * pulse))
	draw_circle(core, 9.0 * k, tint(Color(0.85, 1.0, 1.0)))
	# Two cage rings turning around the core (flattened: seen from above at an angle).
	for r in 2:
		var a0 := _t * (1.6 if r == 0 else -1.1)
		draw_arc(core, 20.0 + r * 7.0, a0, a0 + PI * 1.3, 18, Color(CYAN, 0.8), 2.0, true)
	# Beam out of the top.
	if k >= 1.0:
		var top := Vector2(0, -h)
		for i in 6:
			var kk := float(i) / 6.0
			draw_rect(Rect2(top.x - 5.0 * (1.0 - kk), top.y - 24.0 * (i + 1), 10.0 * (1.0 - kk), 24.0),
				Color(CYAN, (0.35 + 0.2 * pulse) * (1.0 - kk)))
	draw_hp_bar(-h - 20.0)


## Always shows its bar (an objective target, not a robot that comes to you).
func draw_hp_bar(y: float) -> void:
	var w := 70.0
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 8), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, y, w * clampf(hp / max_hp, 0.0, 1.0), 6), CYAN.lerp(Color.WHITE, _flash * 0.6))


func _has_ground_shadow() -> bool:
	return false
