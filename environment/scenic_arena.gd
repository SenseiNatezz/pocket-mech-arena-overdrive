class_name ScenicArena
extends Node2D
## A level built on ONE painted 2.5D environment (Higgsfield render seen from a high 3/4 angle).
## The painting is the whole level; a layout script (environment/arenas/layouts/) traces:
##   walkable outline (solid edges), obstacle footprints (solid), occluders (tall scenery cut out of the
##   painting and drawn OVER the mech, fading out when it walks behind them), hazards and props.
## Flow: intro card -> 5 waves in the plaza -> the boss drops in -> victory.
## Exposes the same signals/fields as Arena so the HUD, Game, autopilot and tests work unchanged.

signal objective_changed(text: String)
signal banner(text: String, color: Color)
signal boss_started(boss: Node)
signal arena_cleared
signal player_died

const P := "res://environment/props/"
const H := "res://environment/hazards/"

@export var arena_name := "Frozen Outpost"
@export var map_texture: Texture2D
@export var map_layout: Script
## World pixels per painting pixel (sets how big the scenery is compared to the Gundam).
@export var map_scale := 1.0
@export_enum("none", "snow", "pollen") var weather := "none"
@export var intro_texture: Texture2D
@export var intro_subtitle := ""

@export_group("Encounter")
@export var waves: PackedStringArray = [
	"chaser:4",
	"chaser:3, shooter:2",
	"chaser:3, shooter:1, tank:2",
	"shooter:4, tank:2",
	"chaser:5, shooter:2, tank:2",
]
@export var enemy_hp_mult := 1.0
@export var enemy_damage_mult := 1.0
@export var bombard_from_wave := 3
@export var boss_hp := 2400.0
@export var boss_name := "WARDEN"
@export var boss_accent := Color(1.0, 0.25, 0.2)
## Boss for this level (Warden when empty). Endless mode keeps its own boss list.
@export var boss_scene: PackedScene

var zone: EncounterZone
var boss: Node
var door: Node = null  # no separate boss room: the boss comes to you
var player_spawn := Vector2.ZERO
var _layout: Object
var _rescue_t := 0.0
var _k := 1.0
var _occluders: Array[Polygon2D] = []
var _occluder_world: Array[PackedVector2Array] = []
var _boss_started := false

@onready var world: Node2D = $World
@onready var nav_region: NavigationRegion2D = $Navigation


func _ready() -> void:
	add_to_group("arena")
	if Game.is_endless():
		arena_name = "Endless - " + arena_name
		intro_subtitle = "Endless mode  //  survive as long as you can  -  a boss every %d waves" % Game.ENDLESS_BOSS_EVERY
	_layout = map_layout.new()
	_k = map_scale
	_build_art()
	_build_collision()
	_spawn_props()
	_setup_flow()
	_bake_navigation()
	var mech := world.get_node_or_null("Mech") as Mech
	if mech:
		mech.global_position = player_spawn
		mech.died.connect(func() -> void: player_died.emit())
		var cam := mech.get_node("Camera2D") as Camera2D
		var size: Vector2 = _layout.image_size * _k
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = int(size.x)
		cam.limit_bottom = int(size.y)
		cam.reset_smoothing()
		_add_weather(cam)
	objective_changed.emit.call_deferred("Hold the plaza")


func map_to_world(p: Vector2) -> Vector2:
	return p * _k


func rect_center(_r: Variant = null) -> Vector2:
	return map_to_world(_layout.boss_spawn)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	Game.run_time += delta
	_rescue_t -= delta
	if _rescue_t <= 0.0:
		_rescue_t = 0.5
		_rescue_escaped()
	# Fade tall scenery the Gundam is standing behind so it never gets lost.
	var mech := world.get_node_or_null("Mech") as Node2D
	if mech == null:
		return
	var probes := [mech.global_position, mech.global_position + Vector2(0, -60), mech.global_position + Vector2(-40, -30),
		mech.global_position + Vector2(40, -30)]
	for i in _occluders.size():
		var behind := false
		for p: Vector2 in probes:
			if Geometry2D.is_point_in_polygon(p, _occluder_world[i]):
				behind = true
				break
		var o := _occluders[i]
		o.modulate.a = move_toward(o.modulate.a, 0.38 if behind else 1.0, delta * 3.0)


# --- build -------------------------------------------------------------------------------------------------

func _build_art() -> void:
	var art := Sprite2D.new()
	art.name = "MapArt"
	art.texture = map_texture
	art.centered = false
	art.scale = Vector2(_k, _k)
	art.z_index = -10
	add_child(art)
	move_child(art, 0)
	# Occluders: the same painting, cut to the tall scenery's outline, drawn above characters.
	for poly: PackedVector2Array in _layout.occluders:
		var o := Polygon2D.new()
		o.texture = map_texture
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(p * _k)
		o.polygon = pts
		o.uv = poly
		o.z_index = 6
		add_child(o)
		_occluders.append(o)
		_occluder_world.append(pts)


func _build_collision() -> void:
	var holder := Node2D.new()
	holder.name = "MapCollision"
	add_child(holder)
	# Floor edge: a closed solid outline (segments) so nothing can leave the walkable area.
	var edge := StaticBody2D.new()
	edge.collision_layer = 1
	edge.collision_mask = 0
	var cp := CollisionPolygon2D.new()
	cp.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	var pts := PackedVector2Array()
	for p in _layout.walkable:
		pts.append(p * _k)
	pts.append(_layout.walkable[0] * _k)
	cp.polygon = pts
	edge.add_child(cp)
	holder.add_child(edge)
	for poly: PackedVector2Array in _layout.obstacles:
		var body := StaticBody2D.new()
		body.collision_layer = 32  # solid scenery: blocks movement and bullets
		body.collision_mask = 0
		body.add_to_group("nav_obstacles")
		var c := CollisionPolygon2D.new()
		var w := PackedVector2Array()
		for p in poly:
			w.append(p * _k)
		c.polygon = w
		body.add_child(c)
		holder.add_child(body)


func _add(parent: Node, path: String, pos: Vector2, base: Variant, props := {}) -> Node2D:
	var n: Node2D = base.new()
	n.set_script(load(path))
	n.position = pos
	for k: String in props:
		n.set(k, props[k])
	parent.add_child(n)
	return n


func _spawn_props() -> void:
	player_spawn = map_to_world(_layout.spawn)
	for i in _layout.vents.size():
		_add(world, H + "steam_vent.gd", map_to_world(_layout.vents[i]), Area2D,
			{"phase": i * 1.7, "gas_color": _layout.get("vent_color") if "vent_color" in _layout else Color.WHITE})
	if "panels" in _layout:
		for i in _layout.panels.size():
			_add(world, H + "electric_panel.gd", map_to_world(_layout.panels[i]), Area2D,
				{"size": Vector2(160, 110), "phase": i * 1.3})
	_add(world, P + "repair_station.gd", map_to_world(_layout.repair_station), Node2D)
	for p: Vector2 in _layout.barrels:
		_add(world, H + "explosive_barrel.gd", map_to_world(p), StaticBody2D)
	for p: Vector2 in _layout.crates:
		_add(world, P + "crate.gd", map_to_world(p), StaticBody2D)
	for i in _layout.destructible_cover.size():
		_add(world, P + "cover_block.gd", map_to_world(_layout.destructible_cover[i]), StaticBody2D,
			{"size": Vector2(150 if i % 2 == 0 else 90, 48)})
	# Top-down maps: destructible cover with matching art (Higgsfield): assets/hq/<layout.prop_folder>/,
	# props_snow when the layout doesn't say (neutral non-snow set: props_topdown).
	if "props" in _layout:
		var folder: String = _layout.prop_folder if "prop_folder" in _layout else "props_snow"
		for p: Array in _layout.props:
			var kind: Array = SNOW_PROPS[p[0]]
			var props: Dictionary = kind[2].duplicate()
			props["texture"] = load("res://assets/hq/%s/%s.png" % [folder, p[0]])
			props["rotation"] = deg_to_rad(p[2])
			_add(world, kind[0], map_to_world(p[1]), kind[1], props)


## Top-down destructible props: kind -> [script, base type, settings]. Sizes are world px; `hits_to_break`
## = how many hits it takes (heavy hits count double).
var SNOW_PROPS := {
	"crate_wood": ["res://environment/props/crate.gd", StaticBody2D,
		{"box": Vector2(80, 80), "draw_size": 88.0, "hits_to_break": 6}],
	"crate_steel": ["res://environment/props/crate.gd", StaticBody2D,
		{"box": Vector2(80, 78), "draw_size": 88.0, "hits_to_break": 10}],
	"cargo": ["res://environment/props/cover_block.gd", StaticBody2D, {"size": Vector2(150, 150), "hits_to_break": 22}],
	"barrier": ["res://environment/props/cover_block.gd", StaticBody2D, {"size": Vector2(230, 72), "hits_to_break": 16}],
	"sandbags": ["res://environment/props/cover_block.gd", StaticBody2D, {"size": Vector2(210, 68), "hits_to_break": 12}],
	"barrel": ["res://environment/hazards/explosive_barrel.gd", StaticBody2D, {"radius": 26.0}],
}


## Is this world point on open floor (inside the walkable outline, clear of edges and obstacles)?
## Safety net: the floor edge is a thin outline, and big crowds (Hard / Extreme) can squeeze an enemy
## through it. Anything found outside the walkable area warps back to the nearest spawn point.
func _rescue_escaped() -> void:
	if zone == null or zone.spawn_points.is_empty():
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.dead:
			continue
		# Off the floor, or shoved INSIDE a solid obstacle (where every shot hits the obstacle first).
		var lp: Vector2 = e.global_position / _k
		var stuck := not Geometry2D.is_point_in_polygon(lp, _layout.walkable)
		for poly: PackedVector2Array in _layout.obstacles:
			if not stuck and Geometry2D.is_point_in_polygon(lp, poly):
				stuck = true
		if not stuck:
			continue
		var best: Vector2 = zone.spawn_points[0]
		for p in zone.spawn_points:
			if p.distance_squared_to(e.global_position) < best.distance_squared_to(e.global_position):
				best = p
		e.global_position = best
		e.velocity = Vector2.ZERO
		Combat.shockwave(best, 70.0, Color(1.0, 0.3, 0.8), 0.3)


func is_open(world_pos: Vector2, margin := 80.0) -> bool:
	var p := world_pos / _k
	var m := margin / _k
	if not Geometry2D.is_point_in_polygon(p, _layout.walkable):
		return false
	var w: PackedVector2Array = _layout.walkable
	for i in w.size():
		if Geometry2D.get_closest_point_to_segment(p, w[i], w[(i + 1) % w.size()]).distance_to(p) < m:
			return false
	for poly: PackedVector2Array in _layout.obstacles:
		if Geometry2D.is_point_in_polygon(p, poly):
			return false
		for i in poly.size():
			if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) < m:
				return false
	return true


func _bake_navigation() -> void:
	var np := NavigationPolygon.new()
	np.agent_radius = 30.0
	np.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	np.parsed_collision_mask = 32
	np.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	np.source_geometry_group_name = &"nav_obstacles"
	var pts := PackedVector2Array()
	for p in _layout.walkable:
		pts.append(p * _k)
	np.add_outline(pts)
	nav_region.navigation_polygon = np
	nav_region.bake_navigation_polygon(false)


func _add_weather(cam: Camera2D) -> void:
	if weather == "none":
		return
	var p := CPUParticles2D.new()
	p.z_index = 20
	p.amount = 220 if weather == "snow" else 90
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(900, 520)
	p.local_coords = false
	var ramp := Gradient.new()
	if weather == "snow":
		p.direction = Vector2(-0.35, 1)
		p.spread = 12.0
		p.initial_velocity_min = 60.0
		p.initial_velocity_max = 140.0
		p.gravity = Vector2(-10, 20)
		p.scale_amount_min = 1.5
		p.scale_amount_max = 4.0
		ramp.set_color(0, Color(1, 1, 1, 0.9))
		ramp.set_color(1, Color(0.85, 0.92, 1.0, 0.0))
	else:
		p.direction = Vector2(1, -0.3)
		p.spread = 40.0
		p.initial_velocity_min = 8.0
		p.initial_velocity_max = 30.0
		p.gravity = Vector2(0, -4)
		p.scale_amount_min = 1.5
		p.scale_amount_max = 3.5
		ramp.set_color(0, Color(1.0, 0.95, 0.6, 0.8))
		ramp.set_color(1, Color(1.0, 0.85, 0.4, 0.0))
	p.color_ramp = ramp
	cam.add_child(p)


# --- flow --------------------------------------------------------------------------------------------------

func _setup_flow() -> void:
	zone = EncounterZone.new()
	var size: Vector2 = _layout.image_size * _k
	zone.zone_size = size
	zone.position = size / 2
	zone.waves = waves
	zone.hp_mult = enemy_hp_mult
	zone.damage_mult = enemy_damage_mult
	zone.bombard_from_wave = bombard_from_wave
	zone.enemy_parent = world
	zone.monitoring = false  # the fight starts after the intro card, not on spawn
	if Game.is_endless():
		zone.endless = true
		zone.hp_ramp = 0.12
		zone.damage_ramp = 0.04
		zone.bombard_from_wave = 4
		zone.bombard_interval = 6.0
	var pts := PackedVector2Array()
	var step := 70.0
	var y := 0.0
	while y < size.y:
		var x := 0.0
		while x < size.x:
			var p := Vector2(x, y)
			if is_open(p, 80.0) and p.distance_to(player_spawn) > 300.0:
				pts.append(p)
			x += step
		y += step
	zone.spawn_points = pts
	add_child(zone)
	zone.started.connect(func() -> void:
		banner.emit("HOSTILES INBOUND", Color(1.0, 0.35, 0.4))
		objective_changed.emit("Destroy all hostiles"))
	if zone.endless:
		zone.wave_started.connect(_on_endless_wave_started)
		zone.wave_cleared.connect(_on_endless_wave_cleared)
	else:
		zone.wave_started.connect(func(i: int, n: int) -> void:
			banner.emit("WAVE %d / %d" % [i, n], Color(1.0, 0.8, 0.3))
			objective_changed.emit("Wave %d / %d - destroy all hostiles" % [i, n]))
		zone.wave_cleared.connect(func(i: int, n: int) -> void:
			if i < n:
				banner.emit("WAVE CLEARED", Color(0.4, 1.0, 0.6)))
	zone.cleared.connect(_on_zone_cleared)
	if Game.start_at_boss:
		# RETRY BOSS: no waves - the boss drops straight in (checkpoint restored by Game.retry_boss()).
		zone.is_cleared = true
		get_tree().create_timer(1.0, false).timeout.connect(_on_zone_cleared)
		return
	# The fight starts once the intro card has faded (or right away if the player moves off).
	get_tree().create_timer(3.2, false).timeout.connect(func() -> void:
		if not zone.is_running and not zone.is_cleared:
			zone.start())


func _on_zone_cleared() -> void:
	banner.emit("WARNING: %s INBOUND" % boss_name, boss_accent)
	objective_changed.emit("Survive - the %s is dropping in" % boss_name)
	# Drop zone telegraph, then the boss lands with a shockwave.
	var at := map_to_world(_layout.boss_spawn)
	Combat.artillery(at, 240.0, 30.0 * enemy_damage_mult * Game.diff("damage"), null, 2.0, "player")
	Sfx.play(&"alarm", -4.0, 0.0)
	get_tree().create_timer(2.0, false).timeout.connect(_start_boss)


func debug_skip_to_boss() -> void:
	zone.is_cleared = true
	zone.is_running = false
	_start_boss()


func _start_boss() -> void:
	if _boss_started:
		return
	_boss_started = true
	banner.emit(boss_name, boss_accent)
	objective_changed.emit("Destroy the %s" % boss_name)
	var b: Enemy = (boss_scene if boss_scene else load("res://enemies/warden_boss.tscn")).instantiate()
	b.max_hp = boss_hp * Game.diff("boss_hp")
	b.damage_mult = enemy_damage_mult * Game.diff("damage")
	b.set("boss_name", boss_name)
	b.set("accent", boss_accent)
	b.position = map_to_world(_layout.boss_spawn)
	world.add_child(b)
	boss = b
	Combat.explosion_fx(b.position, 260.0, boss_accent)
	Combat.shake(0.8)
	b.connect("defeated", _on_boss_defeated)
	boss_started.emit(b)
	# Dying from here on offers RETRY BOSS (starts the arena straight at this fight).
	Game.save_boss_checkpoint()


func _on_boss_defeated() -> void:
	Game.mark_cleared()
	objective_changed.emit("Area cleared!")
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.dead:
			e.die()
	Upgrades.vacuum()
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void: arena_cleared.emit())


# --- endless mode ------------------------------------------------------------------------------------------

## Endless bosses cycle through these variants (name, accent); each one is tougher than the last.
const ENDLESS_BOSSES := [
	["WARDEN", Color(1.0, 0.25, 0.2)],
	["WARDEN - CRYO UNIT", Color(0.45, 0.85, 1.0)],
	["WARDEN - VERDANT", Color(0.5, 1.0, 0.35)],
	["WARDEN MK-II", Color(1.0, 0.6, 0.15)],
	["WARDEN - VOID", Color(0.75, 0.4, 1.0)],
]
const ENDLESS_BOSS_HP := 1500.0


func _on_endless_wave_started(i: int, _n: int) -> void:
	if zone.is_boss_wave(i):
		banner.emit("BOSS WAVE %d" % i, Color(1.0, 0.35, 0.3))
		objective_changed.emit("Wave %d - destroy the boss and its escort" % i)
		_endless_boss(i)
	else:
		banner.emit("WAVE %d" % i, Color(1.0, 0.8, 0.3))
		objective_changed.emit("Wave %d - destroy all hostiles" % i)


func _on_endless_wave_cleared(i: int, _n: int) -> void:
	# Weapon unlocks are announced by the HUD's unlock toast (Game.weapon_unlocked).
	Game.record_endless_wave(i)
	if zone.is_boss_wave(i):
		banner.emit("BOSS DESTROYED", Color(0.4, 1.0, 0.6))
	else:
		banner.emit("WAVE %d CLEARED" % i, Color(0.4, 1.0, 0.6))
	objective_changed.emit("Next wave incoming...")


## Boss wave: the next Warden variant drops in (telegraphed) with more HP every time.
func _endless_boss(wave: int) -> void:
	var k := wave / Game.ENDLESS_BOSS_EVERY
	var info: Array = ENDLESS_BOSSES[(k - 1) % ENDLESS_BOSSES.size()]
	zone.reserve()
	var at := map_to_world(_layout.boss_spawn)
	Combat.artillery(at, 240.0, 30.0 * zone.wave_damage_mult(), null, 2.0, "player")
	Sfx.play(&"alarm", -4.0, 0.0)
	get_tree().create_timer(2.0, false).timeout.connect(_drop_endless_boss.bind(k, info, at))


func _drop_endless_boss(k: int, info: Array, at: Vector2) -> void:
	var b: Enemy = load("res://enemies/warden_boss.tscn").instantiate()
	b.max_hp = ENDLESS_BOSS_HP * (1.0 + 0.5 * (k - 1)) * Game.diff("boss_hp")
	b.damage_mult = zone.wave_damage_mult()
	b.set("boss_name", info[0] if k <= ENDLESS_BOSSES.size() else "%s  #%d" % [info[0], k])
	b.set("accent", info[1])
	b.position = at
	world.add_child(b)
	boss = b
	zone.track(b)
	Combat.explosion_fx(b.position, 260.0, info[1])
	Combat.shake(0.8)
	b.connect("defeated", _on_endless_boss_defeated)
	boss_started.emit(b)


## Boss down: its escort goes with it, and the pilot gets patched up for the next stretch.
func _on_endless_boss_defeated() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.dead and not e.is_in_group("boss"):
			e.die()
	var mech := world.get_node_or_null("Mech") as Mech
	if mech and not mech.dead:
		mech.heal(mech.max_hp * 0.3)
		mech.add_repair_charge()
