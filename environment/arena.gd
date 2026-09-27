@tool
class_name Arena
extends Node2D
## A ruined-city arena on an elevated platform, built on TileMapLayers from the city tileset
## (3/4 top-down view). One scene per arena (environment/arenas/) - each just sets these exports.
##
## Layout (north at top):
##   BOSS ROOM   (behind a blast door)
##   MAIN ZONE   encounter zone: 5 waves behind an energy barrier, buildings, cover, pits, hazards
##   START PAD   spawn + repair station
##
## EASY SIZE SETTING: change `size_in_screens` (1 screen = 1280x720) or `layout_seed` in the
## Inspector. The layout rebuilds every time the scene runs; press "Rebuild Layout" to preview it in
## the editor.

signal objective_changed(text: String)
signal banner(text: String, color: Color)
signal boss_started(boss: Node)
signal arena_cleared
signal player_died

const T := 64
const MARGIN := 4
const SRC := 0

const BARRIER_TOP := Vector2i(0, 5)
const BARRIER_FACE := Vector2i(1, 5)
const CAR_A := Vector2i(2, 5)
const CAR_B := Vector2i(4, 5)
const JERSEY := Vector2i(6, 5)
const DUMPSTER := Vector2i(7, 5)
const RIM_N := Vector2i(0, 6)
const RIM_W := Vector2i(1, 6)
const RIM_E := Vector2i(2, 6)
const SHADOW_STRIP := Vector2i(4, 6)
const SHADOW_TOP := Vector2i(5, 6)
const LANE_H := Vector2i(3, 0)
const CROSSWALK := Vector2i(2, 1)
const METAL := Vector2i(4, 0)
const GRATE := Vector2i(5, 0)
const MANHOLE := Vector2i(6, 1)
const ASPHALT: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
	Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
	Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1),
	Vector2i(3, 1), Vector2i(4, 1), Vector2i(5, 1)]
const SIDEWALK: Array[Vector2i] = [Vector2i(6, 0), Vector2i(6, 0), Vector2i(6, 0), Vector2i(7, 0)]
const ROOFS: Array[Vector2i] = [Vector2i(0, 2), Vector2i(0, 2), Vector2i(0, 2), Vector2i(0, 2), Vector2i(1, 2),
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2)]
const FACADE_UP: Array[Vector2i] = [Vector2i(0, 3), Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
	Vector2i(4, 3), Vector2i(5, 3)]
const FACADE_GROUND: Array[Vector2i] = [Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]
const DECOR: Array[Vector2i] = [Vector2i(0, 7), Vector2i(0, 7), Vector2i(1, 7), Vector2i(1, 7), Vector2i(2, 7),
	Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7), Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7)]

@export_group("Layout")
@export var arena_name := "Ruined Plaza"
## Main combat zone size in screens (1 screen = 1280x720). 2-3 screens wide is the sweet spot.
@export var size_in_screens := Vector2(2.5, 2.0)
@export var boss_room_screens := Vector2(1.5, 1.3)
@export var layout_seed := 7
@export var buildings := 4
@export var pits := 3
@export var cover_blocks := 10
@export var crates := 6
@export var barrels := 6
@export var electric_panels := 3
@export var wrecks := 3
@export var skyline_tint := Color(1, 1, 1)
@export_tool_button("Rebuild Layout", "Reload") var rebuild_button := rebuild

@export_group("Encounter")
@export var waves: PackedStringArray = [
	"chaser:4",
	"chaser:3, shooter:2",
	"chaser:3, shooter:1, lobber:2",
	"shooter:4, lobber:2",
	"chaser:5, shooter:2, lobber:2",
]
@export var enemy_hp_mult := 1.0
@export var enemy_damage_mult := 1.0
@export var bombard_from_wave := 3
@export var boss_hp := 2600.0
@export var boss_name := "WARDEN"
@export var boss_accent := Color(1.0, 0.25, 0.2)

var main_rect: Rect2i
var boss_rect: Rect2i
var start_rect: Rect2i
var grid_rect: Rect2i
var player_spawn := Vector2.ZERO
var zone: Node
var boss: Node
var door: Node
var _rng := RandomNumberGenerator.new()
var _solid := {}
var _blocked := {}
var _keep_clear := {}
var _building_rects: Array[Rect2i] = []
var _pit_rects: Array[Rect2i] = []
var _center_x := 0
var _boss_started := false

@onready var floor_layer: TileMapLayer = $Floor
@onready var shadow_layer: TileMapLayer = $Shadows
@onready var decor_layer: TileMapLayer = $Decor
@onready var wall_layer: TileMapLayer = $Walls
@onready var rim_layer: TileMapLayer = $Rim
@onready var nav_region: NavigationRegion2D = $Navigation
@onready var floor_props: Node2D = $FloorProps
@onready var world: Node2D = $World
@onready var skyline: Node2D = $Skyline


func _ready() -> void:
	add_to_group("arena")
	rebuild()
	if Engine.is_editor_hint():
		return
	skyline.modulate = skyline_tint
	_spawn_props()
	_setup_flow()
	_bake_navigation()
	var mech := world.get_node_or_null("Mech") as Mech
	if mech:
		mech.global_position = player_spawn
		mech.died.connect(func() -> void: player_died.emit())
		var cam := mech.get_node("Camera2D") as Camera2D
		cam.limit_left = grid_rect.position.x * T
		cam.limit_top = grid_rect.position.y * T
		cam.limit_right = grid_rect.end.x * T
		cam.limit_bottom = grid_rect.end.y * T
		cam.reset_smoothing()
	objective_changed.emit.call_deferred("Head north into the plaza")


func _process(delta: float) -> void:
	if not Engine.is_editor_hint() and not get_tree().paused:
		Game.run_time += delta


# --- layout ------------------------------------------------------------------------------------------

func rebuild() -> void:
	for l: TileMapLayer in [floor_layer, shadow_layer, decor_layer, wall_layer, rim_layer]:
		l.clear()
	_solid.clear()
	_blocked.clear()
	_keep_clear.clear()
	_building_rects.clear()
	_pit_rects.clear()
	_rng.seed = layout_seed

	var mw := maxi(roundi(size_in_screens.x * 20.0), 16)
	var mh := maxi(roundi(size_in_screens.y * 11.25), 12)
	var bw := mini(maxi(roundi(boss_room_screens.x * 20.0), 14), mw)
	var bh := maxi(roundi(boss_room_screens.y * 11.25), 10)
	_center_x = MARGIN + 1 + mw / 2
	boss_rect = Rect2i(_center_x - bw / 2, MARGIN + 2, bw, bh)
	main_rect = Rect2i(MARGIN + 1, boss_rect.end.y + 2, mw, mh)
	start_rect = Rect2i(_center_x - 6, main_rect.end.y + 1, 12, 7)
	grid_rect = Rect2i(0, 0, mw + 2 + MARGIN * 2, start_rect.end.y + 1 + MARGIN)

	_room_walls(boss_rect, 2)
	_room_walls(main_rect, 2)
	_room_walls(start_rect, 1)
	_paint_floor(boss_rect, &"metal")
	_paint_floor(main_rect, &"street")
	_paint_floor(start_rect, &"metal")
	# Doorways: boss door (2 rows of wall) and the south gap into the start pad.
	for x in range(_center_x - 2, _center_x + 2):
		for y in [main_rect.position.y - 2, main_rect.position.y - 1, main_rect.end.y]:
			_unwall(Vector2i(x, y))
			floor_layer.set_cell(Vector2i(x, y), SRC, METAL)
	# Keep a walkable spine from the start pad to the boss door, and space near both doorways.
	for y in range(main_rect.position.y, main_rect.end.y):
		for x in range(_center_x - 3, _center_x + 3):
			_keep_clear[Vector2i(x, y)] = true
	for y in range(main_rect.end.y - 3, main_rect.end.y):
		for x in range(_center_x - 6, _center_x + 6):
			_keep_clear[Vector2i(x, y)] = true

	_place_buildings()
	_place_pits()
	_boss_pillars()
	_place_wrecks()
	_scatter_decor()


func _room_walls(r: Rect2i, top_rows: int) -> void:
	for x in range(r.position.x - 1, r.end.x + 1):
		if top_rows == 2:
			_wall(Vector2i(x, r.position.y - 2), BARRIER_TOP)
			var edge := x == r.position.x - 1 or x == r.end.x
			_wall(Vector2i(x, r.position.y - 1), BARRIER_TOP if edge else BARRIER_FACE)
		else:
			_wall(Vector2i(x, r.position.y - 1), BARRIER_TOP)
		_wall(Vector2i(x, r.end.y), BARRIER_TOP)
	for y in range(r.position.y - top_rows, r.end.y + 1):
		_wall(Vector2i(r.position.x - 1, y), BARRIER_TOP)
		_wall(Vector2i(r.end.x, y), BARRIER_TOP)


func _wall(c: Vector2i, atlas: Vector2i) -> void:
	wall_layer.set_cell(c, SRC, atlas)
	_solid[c] = true


func _unwall(c: Vector2i) -> void:
	wall_layer.erase_cell(c)
	rim_layer.erase_cell(c)
	_solid.erase(c)


func _pick(arr: Array[Vector2i]) -> Vector2i:
	return arr[_rng.randi() % arr.size()]


func _paint_floor(r: Rect2i, theme: StringName) -> void:
	var road_y := r.position.y + r.size.y / 2
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			_unwall(c)
			var atlas := _pick(ASPHALT)
			match theme:
				&"metal":
					var ring := maxi(absi(x - (r.position.x + r.size.x / 2)), absi(y - (r.position.y + r.size.y / 2)))
					atlas = GRATE if ring % 4 == 2 else METAL
				&"street":
					var edge := x == r.position.x or x == r.end.x - 1 or y == r.position.y or y == r.end.y - 1
					if edge:
						atlas = _pick(SIDEWALK)
					elif y == road_y:
						atlas = LANE_H
					elif absi(y - road_y) <= 2 and (x == r.position.x + 4 or x == r.end.x - 5):
						atlas = CROSSWALK
					elif _rng.randf() < 0.01:
						atlas = MANHOLE
			floor_layer.set_cell(c, SRC, atlas)


func _free_rect(r: Rect2i, clearance: int, avoid_keep_clear := true) -> bool:
	var g := r.grow(clearance)
	for y in range(g.position.y, g.end.y):
		for x in range(g.position.x, g.end.x):
			var c := Vector2i(x, y)
			if _solid.has(c) or _blocked.has(c):
				return false
	if avoid_keep_clear:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if _keep_clear.has(Vector2i(x, y)):
					return false
	return main_rect.encloses(r) or boss_rect.encloses(r) or start_rect.encloses(r)


func _block(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_blocked[Vector2i(x, y)] = true


func _place_buildings() -> void:
	var road_y := main_rect.position.y + main_rect.size.y / 2
	for attempt in 300:
		if _building_rects.size() >= buildings:
			break
		var w := _rng.randi_range(3, 5)
		var h := _rng.randi_range(3, 4)
		var r := Rect2i(_rng.randi_range(main_rect.position.x + 3, main_rect.end.x - 3 - w),
			_rng.randi_range(main_rect.position.y + 2, main_rect.end.y - 3 - h), w, h)
		if r.position.y <= road_y + 2 and r.end.y > road_y - 2:
			continue  # keep the avenue open
		if not _free_rect(r, 3):
			continue
		_building(r)
		_building_rects.append(r)
		# Sidewalk ring around the block.
		var ring := r.grow(1)
		for y in range(ring.position.y, ring.end.y):
			for x in range(ring.position.x, ring.end.x):
				if not r.has_point(Vector2i(x, y)):
					floor_layer.set_cell(Vector2i(x, y), SRC, _pick(SIDEWALK))


func _building(r: Rect2i) -> void:
	var f := 2 if r.size.y >= 4 else 1
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var atlas := _pick(ROOFS)
			if y >= r.end.y - f:
				atlas = _pick(FACADE_UP) if f == 2 and y == r.end.y - 2 else _pick(FACADE_GROUND)
			_wall(Vector2i(x, y), atlas)
	for x in range(r.position.x, r.end.x):
		rim_layer.set_cell(Vector2i(x, r.position.y), SRC, RIM_N)
	for y in range(r.position.y + 1, r.end.y - f):
		rim_layer.set_cell(Vector2i(r.position.x, y), SRC, RIM_W)
		rim_layer.set_cell(Vector2i(r.end.x - 1, y), SRC, RIM_E)
	for y in range(r.position.y, r.end.y):
		shadow_layer.set_cell(Vector2i(r.end.x, y), SRC, SHADOW_TOP if y == r.position.y else SHADOW_STRIP)
	_block(r.grow(1))


func _place_pits() -> void:
	var sizes: Array[Vector2i] = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3), Vector2i(4, 2), Vector2i(2, 4)]
	for attempt in 300:
		if _pit_rects.size() >= pits:
			break
		var s: Vector2i = sizes[_rng.randi() % sizes.size()]
		var r := Rect2i(_rng.randi_range(main_rect.position.x + 2, main_rect.end.x - 2 - s.x),
			_rng.randi_range(main_rect.position.y + 2, main_rect.end.y - 2 - s.y), s.x, s.y)
		if not _free_rect(r, 2):
			continue
		_pit_rects.append(r)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				floor_layer.erase_cell(Vector2i(x, y))
		_block(r.grow(1))


func _boss_pillars() -> void:
	var cx := boss_rect.position.x + boss_rect.size.x / 2
	var cy := boss_rect.position.y + boss_rect.size.y / 2
	var dx := boss_rect.size.x / 4 + 1
	var dy := boss_rect.size.y / 4
	for s: Vector2i in [Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
		var r := Rect2i(cx + s.x * dx - 1, cy + s.y * dy - 1, 2, 2)
		_building(r)


func _place_wrecks() -> void:
	var road_y := main_rect.position.y + main_rect.size.y / 2
	var placed := 0
	for attempt in 200:
		if placed >= wrecks:
			break
		var x := _rng.randi_range(main_rect.position.x + 3, main_rect.end.x - 4)
		var y: int = road_y + [-2, -1, 1, 2][_rng.randi() % 4]
		var r := Rect2i(x - 1, y, 3, 1)
		if not _free_rect(r, 1):
			continue
		wall_layer.set_cell(Vector2i(x, y), SRC, CAR_A if _rng.randf() < 0.5 else CAR_B)
		_block(r.grow(1))
		placed += 1
	# A few jersey barriers / dumpsters beside buildings.
	for b in _building_rects:
		if _rng.randf() < 0.7:
			var c := Vector2i(b.end.x + 1, b.position.y + _rng.randi_range(0, b.size.y - 1))
			if _free_rect(Rect2i(c, Vector2i.ONE), 0):
				wall_layer.set_cell(c, SRC, JERSEY if _rng.randf() < 0.5 else DUMPSTER)
				_block(Rect2i(c, Vector2i.ONE).grow(1))


func _scatter_decor() -> void:
	for r in [main_rect, start_rect]:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if _solid.has(c) or floor_layer.get_cell_source_id(c) == -1:
					continue
				if _rng.randf() < 0.035:
					decor_layer.set_cell(c, SRC, _pick(DECOR))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * T + Vector2(T, T) / 2


func rect_center(r: Rect2i) -> Vector2:
	return Vector2(r.position) * T + Vector2(r.size) * T / 2


func _random_free_cell(r: Rect2i, clearance := 1) -> Vector2i:
	for attempt in 200:
		var c := Vector2i(_rng.randi_range(r.position.x + 1, r.end.x - 2), _rng.randi_range(r.position.y + 1, r.end.y - 2))
		if _free_rect(Rect2i(c, Vector2i.ONE), clearance) and not _keep_clear.has(c):
			return c
	return Vector2i(-1, -1)


# --- runtime props --------------------------------------------------------------------------------------

func _spawn_props() -> void:
	var P := "res://environment/props/"
	var H := "res://environment/hazards/"
	for r in _pit_rects:
		_add_prop(floor_props, P + "pit.gd", rect_center(r), StaticBody2D, {"size": Vector2(r.size) * T})
	# Repair stations: start pad + main zone (beside the west wall).
	_add_prop(floor_props, P + "repair_station.gd", cell_center(Vector2i(start_rect.position.x + 2, start_rect.position.y + 3)), Node2D)
	var west := Vector2i(main_rect.position.x + 2, main_rect.position.y + main_rect.size.y / 2 - 3)
	if _free_rect(Rect2i(west, Vector2i.ONE), 1, false):
		_block(Rect2i(west, Vector2i.ONE).grow(1))
		_add_prop(floor_props, P + "repair_station.gd", cell_center(west), Node2D)
	# Electric panels (2x2 / 3x2 cells).
	for i in electric_panels:
		for attempt in 60:
			var s := Vector2i(_rng.randi_range(2, 3), 2)
			var c := Vector2i(_rng.randi_range(main_rect.position.x + 2, main_rect.end.x - 2 - s.x),
				_rng.randi_range(main_rect.position.y + 2, main_rect.end.y - 4 - s.y))
			var r := Rect2i(c, s)
			if _free_rect(r, 1, false):
				_block(r)
				_add_prop(floor_props, H + "electric_panel.gd", rect_center(r), Area2D, {"size": Vector2(s) * T, "phase": i * 1.3})
				break
	# Cover, crates and barrels (world layer: y-sorted with characters).
	for i in cover_blocks:
		var c := _random_free_cell(main_rect)
		if c.x < 0:
			continue
		var wide := _rng.randf() < 0.5 and _free_rect(Rect2i(c, Vector2i(2, 1)), 1)
		var r := Rect2i(c, Vector2i(2 if wide else 1, 1))
		_block(r)
		_add_prop(world, P + "cover_block.gd", rect_center(r), StaticBody2D, {"size": Vector2(120 if wide else 60, 40)})
	for i in 4:
		var c := _random_free_cell(boss_rect)
		if c.x >= 0 and c.y < boss_rect.end.y - 3:
			_block(Rect2i(c, Vector2i.ONE))
			_add_prop(world, P + "cover_block.gd", cell_center(c), StaticBody2D)
	for i in crates:
		var c := _random_free_cell(main_rect)
		if c.x >= 0:
			_block(Rect2i(c, Vector2i.ONE))
			_add_prop(world, P + "crate.gd", cell_center(c), StaticBody2D)
	for i in barrels:
		var c := _random_free_cell(main_rect if i < barrels - 1 else boss_rect)
		if c.x >= 0:
			_block(Rect2i(c, Vector2i.ONE))
			_add_prop(world, H + "explosive_barrel.gd", cell_center(c), StaticBody2D)
	player_spawn = cell_center(Vector2i(_center_x, start_rect.position.y + 4))


func _add_prop(parent: Node, script_path: String, pos: Vector2, base: Variant, props := {}) -> Node2D:
	var n: Node2D = base.new()
	n.set_script(load(script_path))
	n.position = pos
	for k: String in props:
		n.set(k, props[k])
	parent.add_child(n)
	return n


func _bake_navigation() -> void:
	wall_layer.add_to_group("nav_obstacles")
	var np := NavigationPolygon.new()
	np.agent_radius = 30.0
	np.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	np.parsed_collision_mask = 1 | 64
	np.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	np.source_geometry_group_name = &"nav_obstacles"
	var a := Vector2(grid_rect.position) * T
	var b := Vector2(grid_rect.end) * T
	np.add_outline(PackedVector2Array([a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]))
	nav_region.navigation_polygon = np
	nav_region.bake_navigation_polygon(false)


# --- level flow ------------------------------------------------------------------------------------------

func _setup_flow() -> void:
	var P := "res://environment/props/"
	# Energy barrier across the south gap (seals the zone once the fight starts).
	var gap := _add_prop(world, P + "energy_barrier.gd", Vector2(_center_x * T, main_rect.end.y * T + T / 2.0), StaticBody2D,
		{"size": Vector2(4 * T, T)})
	# Blast door to the boss room.
	door = _add_prop(floor_props, P + "blast_door.gd", Vector2(_center_x * T, (main_rect.position.y - 1) * T), StaticBody2D,
		{"size": Vector2(4 * T, 2 * T)})
	# Encounter zone = the main area minus its southern rows (so it triggers past the barrier line).
	zone = EncounterZone.new()
	var zr := Rect2(Vector2(main_rect.position) * T, Vector2(main_rect.size.x, main_rect.size.y - 3) * T)
	zone.zone_size = zr.size
	zone.position = zr.get_center()
	zone.waves = waves
	zone.hp_mult = enemy_hp_mult
	zone.damage_mult = enemy_damage_mult
	zone.bombard_from_wave = bombard_from_wave
	zone.barriers.append(gap)
	zone.enemy_parent = world
	var pts := PackedVector2Array()
	for y in range(main_rect.position.y + 1, main_rect.end.y - 4):
		for x in range(main_rect.position.x + 1, main_rect.end.x - 1):
			var c := Vector2i(x, y)
			if not _solid.has(c) and not _blocked.has(c):
				pts.append(cell_center(c))
	zone.spawn_points = pts
	add_child(zone)
	zone.started.connect(func() -> void:
		banner.emit("ZONE LOCKED", Color(1.0, 0.35, 0.4))
		objective_changed.emit("Destroy all hostiles"))
	zone.wave_started.connect(func(i: int, n: int) -> void:
		banner.emit("WAVE %d / %d" % [i, n], Color(1.0, 0.8, 0.3))
		objective_changed.emit("Wave %d / %d - destroy all hostiles" % [i, n]))
	zone.wave_cleared.connect(func(i: int, n: int) -> void:
		if i < n:
			banner.emit("WAVE CLEARED", Color(0.4, 1.0, 0.6)))
	zone.cleared.connect(_on_zone_cleared)
	# Boss trigger: inside the boss room past the door.
	var trig := Area2D.new()
	trig.collision_layer = 0
	trig.collision_mask = 2
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(boss_rect.size.x, boss_rect.size.y - 3) * T
	shape.shape = box
	trig.add_child(shape)
	trig.position = Vector2(boss_rect.position) * T + box.size / 2
	add_child(trig)
	trig.body_entered.connect(func(b: Node) -> void:
		if b is Mech and door.is_open and not _boss_started:
			_boss_started = true
			_start_boss.call_deferred())


## Debug (`-- --boss`): skip the waves and walk straight into the boss room.
func debug_skip_to_boss() -> void:
	zone.is_cleared = true
	_on_zone_cleared()
	var mech := world.get_node_or_null("Mech") as Node2D
	if mech:
		mech.global_position = rect_center(boss_rect) + Vector2(0, boss_rect.size.y * T * 0.3)


func _on_zone_cleared() -> void:
	door.open()
	banner.emit("ZONE CLEARED - BOSS DOOR OPEN", Color(0.4, 1.0, 0.6))
	objective_changed.emit("Enter the boss arena (north)")


func _start_boss() -> void:
	_boss_started = true
	door.close()
	banner.emit(boss_name, boss_accent)
	objective_changed.emit("Destroy the %s" % boss_name)
	var b: Enemy = load("res://enemies/warden_boss.tscn").instantiate()
	b.max_hp = boss_hp
	b.damage_mult = enemy_damage_mult
	b.set("boss_name", boss_name)
	b.set("accent", boss_accent)
	b.position = rect_center(Rect2i(boss_rect.position, Vector2i(boss_rect.size.x, boss_rect.size.y / 2)))
	world.add_child(b)
	boss = b
	b.connect("defeated", _on_boss_defeated)
	boss_started.emit(b)


func _on_boss_defeated() -> void:
	Game.mark_cleared()
	objective_changed.emit("Arena cleared!")
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.dead:
			e.die()
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void: arena_cleared.emit())
