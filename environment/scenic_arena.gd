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
const MAP_SHARPEN := preload("res://environment/map_sharpen.gdshader")
@export var map_layout: Script
## World pixels per painting pixel (sets how big the scenery is compared to the Gundam).
@export var map_scale := 1.0
## Ambient particles over the map: snow (Frozen Outpost), pollen (Jungle), embers (Volcanic Forge),
## spores (Alien Outpost: glowing teal motes), wind (Skyway Junction: fast streaks), dust (Ruined Plaza),
## sandstorm (Titan Graveyard: sand streaks + rolling haze), space (Orbital Dry Dock: drifting sparks, no clouds).
## Every scenic arena also gets slow cloud shadows drifting across (see CloudShadows) - except over lava and in space.
@export_enum("none", "snow", "pollen", "embers", "spores", "wind", "dust", "sandstorm", "space") var weather := "none"
## Very bright floor (Frozen Outpost ice): the painting is dimmed a touch (PALE_FLOOR_SHADE) so white shots
## and blasts still pop, and scorch marks turn to grey soot instead of black ink (BlastFx.pale_floor).
@export var pale_floor := false
const PALE_FLOOR_SHADE := Color(0.84, 0.87, 0.92)
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
## GOLD SALVAGER (enemies/gold_salvager.gd): while the waves of a real run are on, one every
## SALVAGER_EVERY seconds (the first after SALVAGER_FIRST), never two at once; the Hangar's Salvager Beacon
## shortens the wait (Game.salvager_interval_mult). `-- --salvager=S`: the first one after S seconds.
const SALVAGER := preload("res://enemies/gold_salvager.gd")
const SALVAGER_FIRST := Vector2(70.0, 110.0)
const SALVAGER_EVERY := Vector2(120.0, 180.0)
var _salvager_t := 0.0
## THREAT BOSS ESCORT: the kinds of the elite guards that drop in with a boss (cycled).
const ESCORT_KINDS: Array[String] = ["striker", "shooter", "tank"]

@onready var world: Node2D = $World
@onready var nav_region: NavigationRegion2D = $Navigation


func _ready() -> void:
	add_to_group("arena")
	BlastFx.pale_floor = pale_floor
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
	objective_changed.emit.call_deferred(_opening_objective())


## The line under the HUD before wave 1: each map gets its own (it used to say "Hold the plaza" everywhere).
const OPENING_OBJECTIVES := {
	"Frozen Outpost": "Secure the outpost",
	"Jungle Megafactory": "Clear the reactor yard",
	"Alien Outpost": "Break through the colony defenders",
	"Skyway Junction": "Hold the skyway",
	"Ruined Plaza": "Take back the plaza",
	"Volcanic Forge": "Shut down the foundry",
	"Titan Graveyard": "Hold the basin",
	"Orbital Dry Dock": "Retake the dock",
}


func _opening_objective() -> String:
	if Game.is_endless():
		return "Survive the waves"
	return String(OPENING_OBJECTIVES.get(arena_name, "Clear the area"))


func map_to_world(p: Vector2) -> Vector2:
	return p * _k


func rect_center(_r: Variant = null) -> Vector2:
	return map_to_world(_layout.boss_spawn)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	Game.run_time += delta
	_storm_tick(delta)
	_salvager_tick(delta)
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
	# HD: the painting is drawn through a contrast-adaptive sharpening shader (crisper on HD / 4K
	# screens); the occluders cut from it share the same material so the seams match.
	var sharpen: ShaderMaterial = null
	if not OS.get_cmdline_user_args().has("--no-sharpen"):  # (debug: before / after comparisons)
		sharpen = ShaderMaterial.new()
		sharpen.shader = MAP_SHARPEN
	var art := Sprite2D.new()
	art.name = "MapArt"
	art.texture = map_texture
	art.material = sharpen
	art.centered = false
	art.scale = Vector2(_k, _k)
	art.z_index = -10
	if pale_floor:
		art.self_modulate = PALE_FLOOR_SHADE
	add_child(art)
	move_child(art, 0)
	# Occluders: the same painting, cut to the tall scenery's outline, drawn above characters.
	for poly: PackedVector2Array in _layout.occluders:
		var o := Polygon2D.new()
		o.texture = map_texture
		o.material = sharpen
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(p * _k)
		o.polygon = pts
		o.uv = poly
		o.z_index = 6
		if pale_floor:
			o.self_modulate = PALE_FLOOR_SHADE
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
	if weather != "embers" and weather != "space":
		cam.add_child(CloudShadows.new())
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
	elif weather == "embers":
		# Glowing sparks drifting up off the lava.
		p.amount = 120
		p.direction = Vector2(0.2, -1)
		p.spread = 30.0
		p.initial_velocity_min = 30.0
		p.initial_velocity_max = 90.0
		p.gravity = Vector2(6, -12)
		p.scale_amount_min = 1.5
		p.scale_amount_max = 4.0
		ramp.set_color(0, Color(1.0, 0.8, 0.35, 0.95))
		ramp.set_color(1, Color(1.0, 0.3, 0.05, 0.0))
	elif weather == "spores":
		# Glowing alien spores bobbing up and drifting.
		p.amount = 150
		p.direction = Vector2(0.3, -1)
		p.spread = 60.0
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 24.0
		p.gravity = Vector2(3, -3)
		p.texture = preload("res://assets/fx/glow.tres")
		p.scale_amount_min = 0.18
		p.scale_amount_max = 0.42
		p.lifetime = 7.0
		p.preprocess = 7.0
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = add
		ramp.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		ramp.colors = PackedColorArray([Color(0.4, 1.0, 0.85, 0.0), Color(0.5, 1.0, 0.92, 1.0), Color(0.3, 0.7, 1.0, 0.0)])
	elif weather == "wind":
		# High-altitude wind: thin fast streaks.
		p.amount = 95
		p.direction = Vector2(1, 0.12)
		p.spread = 4.0
		p.initial_velocity_min = 520.0
		p.initial_velocity_max = 760.0
		p.gravity = Vector2.ZERO
		p.lifetime = 1.6
		p.preprocess = 1.6
		p.scale_amount_min = 1.3
		p.scale_amount_max = 2.2
		p.particle_flag_align_y = false
		var streak := Image.create(72, 3, false, Image.FORMAT_RGBA8)
		for x in 72:
			streak.set_pixel(x, 0, Color(1, 1, 1, float(x) / 72.0 * 0.6))
			streak.set_pixel(x, 1, Color(1, 1, 1, float(x) / 72.0))
			streak.set_pixel(x, 2, Color(1, 1, 1, float(x) / 72.0 * 0.6))
		p.texture = ImageTexture.create_from_image(streak)
		p.angle_min = rad_to_deg(atan2(0.12, 1.0))
		p.angle_max = p.angle_min
		ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		ramp.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(0.92, 0.96, 1.0, 0.7), Color(1, 1, 1, 0.0)])
	elif weather == "dust":
		# Dust blowing over the ruins: big pale haze puffs rolling across, plus fine bright specks (tan
		# motes alone vanished against the tan floor).
		p.amount = 34
		p.direction = Vector2(1, 0.2)
		p.spread = 15.0
		p.initial_velocity_min = 60.0
		p.initial_velocity_max = 110.0
		p.gravity = Vector2.ZERO
		p.lifetime = 7.0
		p.preprocess = 7.0
		p.texture = preload("res://assets/fx/glow.tres")
		p.scale_amount_min = 1.6
		p.scale_amount_max = 3.2
		ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		ramp.colors = PackedColorArray([Color(1.0, 0.93, 0.8, 0.0), Color(1.0, 0.94, 0.82, 0.22), Color(1.0, 0.92, 0.78, 0.0)])
		var specks := CPUParticles2D.new()
		specks.z_index = 20
		specks.amount = 200
		specks.lifetime = 4.0
		specks.preprocess = 4.0
		specks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		specks.emission_rect_extents = Vector2(900, 520)
		specks.local_coords = false
		specks.direction = Vector2(1, 0.25)
		specks.spread = 25.0
		specks.initial_velocity_min = 70.0
		specks.initial_velocity_max = 150.0
		specks.scale_amount_min = 2.5
		specks.scale_amount_max = 4.5
		var sr := Gradient.new()
		sr.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
		sr.colors = PackedColorArray([Color(1.0, 0.97, 0.9, 0.0), Color(1.0, 0.97, 0.9, 0.85), Color(1.0, 0.93, 0.82, 0.0)])
		specks.color_ramp = sr
		cam.add_child(specks)
	elif weather == "sandstorm":
		# Sand blowing across the basin: fast thin streaks plus big ochre haze puffs rolling with them.
		p.amount = 130
		p.direction = Vector2(1, 0.18)
		p.spread = 6.0
		p.initial_velocity_min = 380.0
		p.initial_velocity_max = 560.0
		p.gravity = Vector2.ZERO
		p.lifetime = 2.2
		p.preprocess = 2.2
		p.scale_amount_min = 1.2
		p.scale_amount_max = 2.4
		var grain := Image.create(48, 3, false, Image.FORMAT_RGBA8)
		for x in 48:
			grain.set_pixel(x, 0, Color(1, 1, 1, float(x) / 48.0 * 0.5))
			grain.set_pixel(x, 1, Color(1, 1, 1, float(x) / 48.0))
			grain.set_pixel(x, 2, Color(1, 1, 1, float(x) / 48.0 * 0.5))
		p.texture = ImageTexture.create_from_image(grain)
		p.angle_min = rad_to_deg(atan2(0.18, 1.0))
		p.angle_max = p.angle_min
		ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
		ramp.colors = PackedColorArray([Color(1.0, 0.85, 0.6, 0.0), Color(1.0, 0.88, 0.66, 0.75), Color(1.0, 0.8, 0.55, 0.0)])
		var haze := CPUParticles2D.new()
		haze.z_index = 20
		haze.amount = 26
		haze.lifetime = 6.0
		haze.preprocess = 6.0
		haze.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		haze.emission_rect_extents = Vector2(900, 520)
		haze.local_coords = false
		haze.direction = Vector2(1, 0.15)
		haze.spread = 10.0
		haze.initial_velocity_min = 140.0
		haze.initial_velocity_max = 220.0
		haze.texture = preload("res://assets/fx/glow.tres")
		haze.scale_amount_min = 2.0
		haze.scale_amount_max = 3.6
		var hr := Gradient.new()
		hr.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		hr.colors = PackedColorArray([Color(0.95, 0.7, 0.4, 0.0), Color(0.95, 0.72, 0.42, 0.2), Color(0.9, 0.65, 0.35, 0.0)])
		haze.color_ramp = hr
		cam.add_child(haze)
	elif weather == "space":
		# Slow glittering motes (ice crystals / hull flakes) drifting past the deck.
		p.amount = 70
		p.direction = Vector2(-0.6, 1)
		p.spread = 50.0
		p.initial_velocity_min = 10.0
		p.initial_velocity_max = 34.0
		p.gravity = Vector2.ZERO
		p.lifetime = 8.0
		p.preprocess = 8.0
		p.texture = preload("res://assets/fx/glow.tres")
		p.scale_amount_min = 0.06
		p.scale_amount_max = 0.16
		var sadd := CanvasItemMaterial.new()
		sadd.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = sadd
		ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		ramp.colors = PackedColorArray([Color(0.8, 0.85, 1.0, 0.0), Color(0.85, 0.9, 1.0, 0.9), Color(0.8, 0.7, 1.0, 0.3),
			Color(0.85, 0.9, 1.0, 0.9), Color(0.8, 0.85, 1.0, 0.0)])
	else:
		p.direction = Vector2(1, -0.3)
		p.spread = 40.0
		p.initial_velocity_min = 8.0
		p.initial_velocity_max = 30.0
		p.gravity = Vector2(0, -4)
		p.amount = 150
		p.scale_amount_min = 2.0
		p.scale_amount_max = 4.5
		ramp.set_color(0, Color(1.0, 0.95, 0.6, 0.95))
		ramp.set_color(1, Color(1.0, 0.85, 0.4, 0.0))
	p.color_ramp = ramp
	cam.add_child(p)


# --- flow --------------------------------------------------------------------------------------------------

func _setup_flow() -> void:
	_salvager_t = randf_range(SALVAGER_FIRST.x, SALVAGER_FIRST.y) * Game.salvager_interval_mult()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--salvager="):
			_salvager_t = a.trim_prefix("--salvager=").to_float()
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
		# (the campaign's per-level toughness doesn't apply: Endless plays the same on every map)
		zone.hp_mult = 1.0
		zone.damage_mult = 1.0
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
				banner.emit("WAVE BROKEN - REINFORCEMENTS INBOUND" if zone.last_overlapped else "WAVE CLEARED", Color(0.4, 1.0, 0.6)))
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


## A campaign boss's HP: the arena's boss_hp x difficulty, +CAMPAIGN_BOSS_HP_PER_LEVEL per pilot level (like
## Endless bosses). Upgrades stack up fast - Triple Shot alone lands ~2.5x on a boss-sized target - so a boss
## with fixed HP melted in seconds late in a run; now it keeps pace with the build the pilot brings.
const CAMPAIGN_BOSS_HP_PER_LEVEL := 0.08


func campaign_boss_hp() -> float:
	return boss_hp * Game.diff("boss_hp") * (1.0 + CAMPAIGN_BOSS_HP_PER_LEVEL * (Upgrades.level - 1))


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
	b.max_hp = campaign_boss_hp()
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
	_spawn_escort(b.position)
	# Dying from here on offers RETRY BOSS (starts the arena straight at this fight).
	Game.save_boss_checkpoint()


## THREAT BOSS ESCORT (Game.threat_escort): elite guards warp in around a boss as it lands (they count toward
## an Endless boss wave; a campaign boss's death takes them down with it).
func _spawn_escort(at: Vector2) -> void:
	var n := Game.threat_escort()
	for i in n:
		var pos := at + Vector2.from_angle(TAU * i / n + 0.4) * 190.0
		if not is_open(pos, 40.0):
			pos = at + Vector2.from_angle(TAU * i / n + 0.4) * 100.0
		zone.spawn_guard(ESCORT_KINDS[i % ESCORT_KINDS.size()], pos)


## GOLD SALVAGER timer (waves only, real runs only, one at a time).
func _salvager_tick(delta: float) -> void:
	if not Game.scrap_enabled or zone == null or not zone.is_running:
		return
	_salvager_t -= delta
	if _salvager_t > 0.0:
		return
	_salvager_t = randf_range(SALVAGER_EVERY.x, SALVAGER_EVERY.y) * Game.salvager_interval_mult()
	if get_tree().get_nodes_in_group("salvagers").is_empty():
		spawn_salvager()


## Sends a Gold Salvager in on open floor near (not on top of) the pilot. Its HP grows with the pilot level.
func spawn_salvager() -> Enemy:
	var mech := world.get_node_or_null("Mech") as Mech
	if mech == null or mech.dead or zone == null:
		return null
	var near: Array[Vector2] = []
	for p in zone.spawn_points:
		var d := p.distance_to(mech.global_position)
		if d > 380.0 and d < 620.0:
			near.append(p)
	var s: Enemy = SALVAGER.new()
	s.max_hp = (150.0 + 30.0 * Upgrades.level) * sqrt(Game.diff("hp"))
	s.position = near.pick_random() if not near.is_empty() else zone._pick_spawn_point()
	world.add_child(s)
	return s


func _on_boss_defeated() -> void:
	Game.mark_cleared()
	objective_changed.emit("Area cleared!")
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.dead:
			e.die()
	Upgrades.vacuum()
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void: arena_cleared.emit())


# --- endless mode ------------------------------------------------------------------------------------------

## Endless bosses: Warden / Ronin / Seraph in the run's shuffled order (Game.endless_boss_order); every
## lap through the three adds "MK-II", "MK-III"... Boss HP = the campaign boss's own HP x
## (ENDLESS_BOSS_HP_BASE + ENDLESS_BOSS_HP_STEP per earlier boss) x (+ENDLESS_BOSS_HP_PER_LEVEL per player
## level past 1) x difficulty, so fights last ~30-60 s even against strong builds.
const ENDLESS_BOSS_HP_BASE := 1.35
const ENDLESS_BOSS_HP_STEP := 0.4
const ENDLESS_BOSS_HP_PER_LEVEL := 0.08
const MARKS := ["II", "III", "IV", "V", "VI"]
## Every this many waves (boss waves excepted), a supply drop: XP burst + a repair.
const SUPPLY_EVERY := 3
## Endless twists: a new one every this many waves from wave 6 (see _roll_twist); storm strike timer.
const TWIST_EVERY := 5
var _storm_t := 3.0
const SUPPLY_XP := 0.4
const SUPPLY_HEAL := 0.15


func _on_endless_wave_started(i: int, _n: int) -> void:
	# A new 5-wave block (waves 6, 11, 16...) rolls a new TWIST.
	if i > 1 and (i - 1) % TWIST_EVERY == 0:
		_roll_twist()
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
	# (an overlapped wave still has a straggler or two around: "broken", not "cleared")
	var done := "BROKEN" if zone.last_overlapped else "CLEARED"
	if zone.is_boss_wave(i):
		banner.emit("BOSS DESTROYED", Color(0.4, 1.0, 0.6))
	elif i % SUPPLY_EVERY == 0:
		banner.emit("WAVE %d %s  -  SUPPLY DROP" % [i, done], Color(0.4, 1.0, 0.6))
		_supply_drop()
	else:
		banner.emit("WAVE %d %s" % [i, done], Color(0.4, 1.0, 0.6))
	objective_changed.emit("Reinforcements inbound - finish the stragglers!" if zone.last_overlapped else "Next wave incoming...")


## ENDLESS TWIST (Game.TWISTS): a random modifier for the next 5 waves, never the same twice in a row.
## Announced with a banner, the objective line and a radio call; the HUD shows it under the run info.
func _roll_twist() -> void:
	var options := Game.TWISTS.keys()
	options.erase(Game.endless_twist)
	Game.endless_twist = options.pick_random()
	var info: Dictionary = Game.TWISTS[Game.endless_twist]
	_storm_t = 3.0
	get_tree().create_timer(1.3, false).timeout.connect(func() -> void:
		banner.emit("TWIST: %s" % info["name"], info["color"])
		objective_changed.emit(String(info["desc"]))
		Radio.say(StringName("twist_" + String(Game.endless_twist)), true))


## CRYSTAL STORM twist: every few seconds, violet lightning strikes a spot near the pilot and one of the
## robots (the strikes hurt everything, so lure robots into them).
func _storm_tick(delta: float) -> void:
	if not zone or not zone.endless or Game.endless_twist != &"storm" or not zone.is_running:
		return
	_storm_t -= delta
	if _storm_t > 0.0:
		return
	_storm_t = randf_range(1.8, 2.8)
	var mech := world.get_node_or_null("Mech") as Mech
	if mech == null or mech.dead:
		return
	var spots: Array[Vector2] = [mech.global_position + Vector2.from_angle(randf() * TAU) * randf_range(120.0, 340.0)]
	var foes := get_tree().get_nodes_in_group("enemies")
	if not foes.is_empty():
		var e: Node2D = foes.pick_random()
		if is_instance_valid(e):
			spots.append(e.global_position)
	for p in spots:
		var s: Node2D = Combat.STRIKE.new()
		s.setup(p, 85.0, 16.0 * zone.wave_damage_mult(), null, 1.1, "all", Vector2.INF)
		s.tint = Color(0.65, 0.3, 1.0)
		s.lightning = true
		Combat.world().add_child(s)


## Supply drop (every SUPPLY_EVERY waves): a crate slams down next to the pilot and bursts into XP
## (SUPPLY_XP of a level) plus a SUPPLY_HEAL repair - a reward between the ever-longer level-ups.
func _supply_drop() -> void:
	var mech := world.get_node_or_null("Mech") as Mech
	if mech == null or mech.dead:
		return
	var at := mech.global_position + Vector2.from_angle(randf() * TAU) * 90.0
	Combat.shockwave(at, 120.0, Color(0.4, 1.0, 0.6), 0.4)
	Combat.burst(at, Color(0.5, 1.0, 0.7), 360.0, 1.3)
	Sfx.play(&"pickup", -2.0, 0.0)
	Radio.say(&"supply", true)
	Upgrades.supply_xp(at, SUPPLY_XP)
	mech.heal(mech.max_hp * SUPPLY_HEAL)


## Boss wave: the next boss in the run's order drops in (telegraphed).
func _endless_boss(wave: int) -> void:
	var k := wave / Game.ENDLESS_BOSS_EVERY
	zone.reserve()
	var at := map_to_world(_layout.boss_spawn)
	Combat.artillery(at, 240.0, 30.0 * zone.wave_damage_mult(), null, 2.0, "player")
	Sfx.play(&"alarm", -4.0, 0.0)
	get_tree().create_timer(2.0, false).timeout.connect(_drop_endless_boss.bind(k, at))


func _drop_endless_boss(k: int, at: Vector2) -> void:
	if Game.endless_boss_order.is_empty():
		Game.roll_endless_bosses()
	var order := Game.endless_boss_order
	var b: Enemy = load(order[(k - 1) % order.size()]).instantiate()
	b.max_hp *= (ENDLESS_BOSS_HP_BASE + ENDLESS_BOSS_HP_STEP * (k - 1)) \
		* (1.0 + ENDLESS_BOSS_HP_PER_LEVEL * (Upgrades.level - 1)) * Game.diff("boss_hp")
	b.damage_mult = zone.wave_damage_mult()
	var lap := (k - 1) / order.size()
	if lap > 0:
		b.set("boss_name", "%s MK-%s" % [b.get("boss_name"), MARKS[mini(lap - 1, MARKS.size() - 1)]])
	b.position = at
	world.add_child(b)
	boss = b
	zone.track(b)
	var accent: Color = b.get("accent")
	Combat.explosion_fx(b.position, 260.0, accent)
	Combat.shake(0.8)
	b.connect("defeated", _on_endless_boss_defeated)
	boss_started.emit(b)
	_spawn_escort(b.position)


## Boss down: its escort goes with it, the pilot gets patched up for the next stretch, and a free
## upgrade pick (BOSS REWARD) comes on top of any level-ups.
func _on_endless_boss_defeated() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.dead and not e.is_in_group("boss"):
			e.die()
	var mech := world.get_node_or_null("Mech") as Mech
	if mech and not mech.dead:
		mech.heal(mech.max_hp * 0.3)
		mech.add_repair_charge()
		# (a beat later, once the boss's death blast has played out)
		get_tree().create_timer(1.6, false).timeout.connect(func() -> void:
			if is_instance_valid(mech) and not mech.dead:
				Upgrades.grant_bonus_pick())


## Slow cloud shadows: a few huge, very soft dark patches drifting across the whole view (drawn in world
## space as a child of the camera, so they slide over the floor, the robots and the mech alike).
class CloudShadows:
	extends Node2D
	const GLOW := preload("res://assets/fx/glow.tres")
	const DRIFT := Vector2(26.0, 9.0)
	var _clouds: Array = []   # [world position, radius, darkness]

	func _ready() -> void:
		z_as_relative = false
		z_index = 15
		top_level = true
		for i in 4:
			_clouds.append([Vector2(randf_range(-1400, 1400), randf_range(-900, 900)), randf_range(380.0, 620.0), randf_range(0.18, 0.26)])

	func _process(delta: float) -> void:
		var cam := get_parent() as Camera2D
		if cam == null:
			return
		var c := cam.get_screen_center_position()
		for cl: Array in _clouds:
			cl[0] += DRIFT * delta
			# Wrap around a 2800 x 1800 window centred on the view, so there are always a few about.
			var off: Vector2 = cl[0] - c
			if off.x > 1500.0:
				cl[0].x -= 3000.0
			elif off.x < -1500.0:
				cl[0].x += 3000.0
			if off.y > 950.0:
				cl[0].y -= 1900.0
			elif off.y < -950.0:
				cl[0].y += 1900.0
		queue_redraw()

	func _draw() -> void:
		for cl: Array in _clouds:
			var p: Vector2 = cl[0]
			var r: float = cl[1]
			var d: float = cl[2]
			# Two offset blobs per cloud so the edge is irregular.
			draw_texture_rect(GLOW, Rect2(p - Vector2(r, r * 0.7), Vector2(r * 2.0, r * 1.4)), false, Color(0, 0.02, 0.05, d))
			draw_texture_rect(GLOW, Rect2(p + Vector2(r * 0.4, r * 0.2) - Vector2(r * 0.7, r * 0.6), Vector2(r * 1.4, r * 1.2)),
				false, Color(0, 0.02, 0.05, d * 0.8))
