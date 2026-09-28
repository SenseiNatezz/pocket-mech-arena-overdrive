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

@export_group("Painted map")
## Optional: a painted top-down map (e.g. a Higgsfield render) used as the main zone instead of
## generated tiles. Needs a layout script with the traced collision (environment/arenas/layouts/).
@export var map_texture: Texture2D
@export var map_layout: Script
## World pixels per image pixel (sets how big the painted map is compared to the mech).
@export var map_scale := 1.15
## Optional painted boss arena (needs a painted main map too). Its gate lines up with the door.
@export var boss_map_texture: Texture2D
@export var boss_layout: Script
@export var boss_map_scale := 0.8
## Tint for the tile start pad / outer walls and the far-below skyline (matches alien palettes).
@export var tile_tint := Color(1, 1, 1)
## Optional intro card shown for a few seconds when the arena starts.
@export var intro_texture: Texture2D
@export var intro_subtitle := ""
## Fills everything outside the playable rooms (no empty void around the map). Tiled texture if
## set (painted arenas), otherwise rooftop tiles.
@export var backdrop_texture: Texture2D
@export var backdrop_tint := Color(0.55, 0.55, 0.6)

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
@export var boss_hp := 2600.0
@export var boss_name := "WARDEN"
@export var boss_accent := Color(1.0, 0.25, 0.2)
## Boss for this level (Warden when empty). Endless mode keeps its own boss list.
@export var boss_scene: PackedScene

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
var _door_x := 0
var _gap_x := 0
var _boss_started := false
var _layout: Object
var _map_k := Vector2.ONE
var _boss_layout: Object
var _boss_k := Vector2.ONE

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
	for l: CanvasItem in [floor_layer, shadow_layer, decor_layer, wall_layer, rim_layer]:
		l.modulate = tile_tint
	_spawn_props()
	_setup_flow()
	_bake_navigation()
	var mech := world.get_node_or_null("Mech") as Mech
	if mech:
		mech.global_position = player_spawn
		mech.died.connect(func() -> void: player_died.emit())
		set_camera_region(&"main")
		(mech.get_node("Camera2D") as Camera2D).reset_smoothing()
	objective_changed.emit.call_deferred("Head north into the plaza")


## Camera limits follow the part of the level you're in, so the boss arena stays hidden behind its
## wall until the door opens:  main (start pad + battle zone) -> open (door open) -> boss.
func set_camera_region(region: StringName) -> void:
	var mech := world.get_node_or_null("Mech") as Mech
	if mech == null:
		return
	var cam := mech.get_node("Camera2D") as Camera2D
	var r: Rect2i
	match region:
		&"main":
			r = Rect2i(main_rect.position.x - 1, main_rect.position.y - 2, main_rect.size.x + 2, 0)
			r.end = Vector2i(r.end.x, start_rect.end.y + 1)
		&"boss":
			r = Rect2i(boss_rect.position.x - 1, boss_rect.position.y - 2, boss_rect.size.x + 2, boss_rect.size.y + 4)
		_:
			r = grid_rect
	var px := Rect2(Vector2(r.position) * T, Vector2(r.size) * T)
	var vp := get_viewport_rect().size
	if px.size.x < vp.x:
		px = px.grow_individual((vp.x - px.size.x) / 2, 0, (vp.x - px.size.x) / 2, 0)
	cam.limit_smoothed = true
	cam.limit_left = int(px.position.x)
	cam.limit_top = int(px.position.y)
	cam.limit_right = int(px.end.x)
	cam.limit_bottom = int(px.end.y)


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

	var painted := map_texture != null and map_layout != null
	_layout = map_layout.new() if painted else null
	var mw := maxi(roundi(size_in_screens.x * 20.0), 16)
	var mh := maxi(roundi(size_in_screens.y * 11.25), 12)
	if painted:
		mw = roundi(_layout.image_size.x * map_scale / T)
		mh = roundi(_layout.image_size.y * map_scale / T)
		_map_k = Vector2(mw * T, mh * T) / _layout.image_size
	var bw := mini(maxi(roundi(boss_room_screens.x * 20.0), 14), mw)
	var bh := maxi(roundi(boss_room_screens.y * 11.25), 10)
	_center_x = MARGIN + 1 + mw / 2
	_door_x = _center_x
	_gap_x = _center_x
	if painted:
		_door_x = MARGIN + 1 + roundi(_layout.door_x * _map_k.x / T)
		_gap_x = MARGIN + 1 + roundi(_layout.gap_x * _map_k.x / T)
	_boss_layout = boss_layout.new() if painted and boss_map_texture != null and boss_layout != null else null
	var boss_x := clampi(_door_x - bw / 2, MARGIN + 1, MARGIN + 1 + mw - bw)
	if _boss_layout:
		# Painted boss arena: its bottom band (fortress wall + gate) doubles as the main zone's north wall.
		var crop: Rect2 = _boss_layout.crop
		bw = mini(roundi(crop.size.x * boss_map_scale / T), mw)
		bh = roundi(crop.size.y * boss_map_scale / T)
		_boss_k = Vector2(bw * T, bh * T) / crop.size
		var gate_off := roundi((_boss_layout.gate_x - crop.position.x) * _boss_k.x / T)
		boss_x = clampi(_door_x - gate_off, MARGIN + 1, MARGIN + 1 + mw - bw)
		boss_rect = Rect2i(boss_x, MARGIN, bw, bh)
		main_rect = Rect2i(MARGIN + 1, boss_rect.end.y, mw, mh)
	else:
		boss_rect = Rect2i(boss_x, MARGIN + 2, bw, bh)
		main_rect = Rect2i(MARGIN + 1, boss_rect.end.y + 2, mw, mh)
	start_rect = Rect2i(_gap_x - 6, main_rect.end.y + 1, 12, 7)
	grid_rect = Rect2i(0, 0, mw + 2 + MARGIN * 2, start_rect.end.y + 1 + MARGIN)

	if not _boss_layout:
		_room_walls(boss_rect, 2)
	_room_walls(main_rect, 2)
	_room_walls(start_rect, 1)
	if _boss_layout:
		# The painted fortress wall replaces the tile wall where the boss arena sits.
		for y in [main_rect.position.y - 2, main_rect.position.y - 1]:
			for x in range(boss_rect.position.x, boss_rect.end.x):
				_unwall(Vector2i(x, y))
	else:
		_paint_floor(boss_rect, &"metal")
	if painted:
		for y in range(main_rect.position.y, main_rect.end.y):
			for x in range(main_rect.position.x, main_rect.end.x):
				_unwall(Vector2i(x, y))
	else:
		_paint_floor(main_rect, &"street")
	_paint_floor(start_rect, &"metal")
	_update_map_art()
	# Doorways: boss door (2 rows of wall) and the south gap into the start pad.
	for x in range(_door_x - 2, _door_x + 2):
		for y in [main_rect.position.y - 2, main_rect.position.y - 1]:
			_unwall(Vector2i(x, y))
			if not _boss_layout:
				floor_layer.set_cell(Vector2i(x, y), SRC, METAL)
	for x in range(_gap_x - 2, _gap_x + 2):
		_unwall(Vector2i(x, main_rect.end.y))
		floor_layer.set_cell(Vector2i(x, main_rect.end.y), SRC, METAL)
	if painted:
		if not _boss_layout:
			_boss_pillars()
		_fill_backdrop()
		return
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
	_fill_backdrop()


## Shows the painted map (if any) stretched over the main zone, under everything else.
func _update_map_art() -> void:
	var art := get_node_or_null("MapArt") as Sprite2D
	if map_texture == null or _layout == null:
		if art:
			art.queue_free()
		return
	if art == null:
		art = Sprite2D.new()
		art.name = "MapArt"
		add_child(art)
		move_child(art, 0)
	art.texture = map_texture
	art.centered = false
	art.z_index = -10
	art.position = Vector2(main_rect.position) * T
	art.scale = Vector2(main_rect.size) * T / map_texture.get_size()
	var boss_art := get_node_or_null("BossArt") as Sprite2D
	if _boss_layout == null:
		if boss_art:
			boss_art.queue_free()
		return
	if boss_art == null:
		boss_art = Sprite2D.new()
		boss_art.name = "BossArt"
		add_child(boss_art)
		move_child(boss_art, 1)
	var crop: Rect2 = _boss_layout.crop
	boss_art.texture = boss_map_texture
	boss_art.centered = false
	boss_art.region_enabled = true
	boss_art.region_rect = crop
	boss_art.z_index = -10
	boss_art.position = Vector2(boss_rect.position) * T
	boss_art.scale = _boss_k


## Painted boss arena pixel (original image coords) -> world position.
func boss_to_world(p: Vector2) -> Vector2:
	return Vector2(boss_rect.position) * T + (p - (_boss_layout.crop as Rect2).position) * _boss_k


## Painted map pixel -> world position.
func map_to_world(p: Vector2) -> Vector2:
	return Vector2(main_rect.position) * T + p * _map_k


## Covers every cell of the grid outside the rooms, walls and floors so no empty space shows.
func _fill_backdrop() -> void:
	var cells: Array[Vector2i] = []
	for y in range(grid_rect.position.y, grid_rect.end.y):
		for x in range(grid_rect.position.x, grid_rect.end.x):
			var c := Vector2i(x, y)
			if floor_layer.get_cell_source_id(c) != -1 or wall_layer.get_cell_source_id(c) != -1:
				continue
			if main_rect.has_point(c) or boss_rect.has_point(c) or start_rect.has_point(c):
				continue
			cells.append(c)
	var node := get_node_or_null("Backdrop") as Node2D
	if node:
		node.free()
	if backdrop_texture == null:
		# Own RNG so the backdrop never shifts the gameplay layout (props use _rng afterwards).
		var r := RandomNumberGenerator.new()
		r.seed = layout_seed + 99
		for c in cells:
			wall_layer.set_cell(c, SRC, ROOFS[r.randi() % ROOFS.size()])
		return
	node = Node2D.new()
	node.name = "Backdrop"
	node.z_index = -11
	node.modulate = backdrop_tint
	add_child(node)
	move_child(node, 0)
	var tex := backdrop_texture
	var tw := tex.get_width()
	var th := tex.get_height()
	node.draw.connect(func() -> void:
		for c in cells:
			var src := Rect2(posmod(c.x * T, tw), posmod(c.y * T, th), T, T)
			node.draw_texture_rect_region(tex, Rect2(Vector2(c) * T, Vector2(T, T)), src))


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
	if _layout:
		_spawn_map_props(P, H)
		return
	for r in _pit_rects:
		_add_prop(floor_props, P + "pit.gd", rect_center(r), StaticBody2D, {"size": Vector2(r.size) * T})
	_scatter_hq_decals()
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


## Painted-map mode: invisible collision traced over the art + gameplay props from the layout.
func _spawn_map_props(P: String, H: String) -> void:
	var holder := Node2D.new()
	holder.name = "MapCollision"
	add_child(holder)
	for poly: PackedVector2Array in _layout.solids:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.add_to_group("nav_obstacles")
		var cp := CollisionPolygon2D.new()
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(map_to_world(p))
		cp.polygon = pts
		body.add_child(cp)
		holder.add_child(body)
	for r: Rect2 in _layout.cover:
		var body := StaticBody2D.new()
		body.collision_layer = 32  # cover: stops bullets from both sides and blocks movement
		body.collision_mask = 0
		body.add_to_group("nav_obstacles")
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = r.size * _map_k
		shape.shape = box
		body.position = map_to_world(r.get_center())
		body.add_child(shape)
		holder.add_child(body)
	for r: Rect2 in _layout.pits:
		_add_prop(floor_props, P + "pit.gd", map_to_world(r.get_center()), StaticBody2D,
			{"size": r.size * _map_k, "draw_visual": false})
	var painted_barrels: bool = _layout.get("barrels_painted") != false
	for p: Vector2 in _layout.barrels:
		_add_prop(world, H + "explosive_barrel.gd", map_to_world(p), StaticBody2D, {"painted": painted_barrels})
	_spawn_structures()
	for p: Vector2 in _layout.crates:
		_add_prop(world, P + "crate.gd", map_to_world(p), StaticBody2D)
	if "destructible_cover" in _layout:
		for i in _layout.destructible_cover.size():
			var wide: bool = i % 2 == 0
			_add_prop(world, P + "cover_block.gd", map_to_world(_layout.destructible_cover[i]), StaticBody2D,
				{"size": Vector2(150 if wide else 90, 48)})
	for i in _layout.electric_panels.size():
		_add_prop(floor_props, H + "electric_panel.gd", map_to_world(_layout.electric_panels[i]), Area2D,
			{"size": Vector2(2 * T, 2 * T), "phase": i * 1.3})
	_add_prop(floor_props, P + "repair_station.gd", map_to_world(_layout.repair_station), Node2D)
	_add_prop(floor_props, P + "repair_station.gd", cell_center(Vector2i(start_rect.position.x + 2, start_rect.position.y + 3)), Node2D)
	if _boss_layout:
		for poly: PackedVector2Array in _boss_layout.solids:
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.add_to_group("nav_obstacles")
			var cp := CollisionPolygon2D.new()
			var pts := PackedVector2Array()
			for p in poly:
				pts.append(boss_to_world(p))
			cp.polygon = pts
			body.add_child(cp)
			holder.add_child(body)
		for r: Rect2 in _boss_layout.pillars:
			var body := StaticBody2D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			body.add_to_group("nav_obstacles")
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = r.size * _boss_k
			shape.shape = box
			body.position = boss_to_world(r.get_center())
			body.add_child(shape)
			holder.add_child(body)
	else:
		for i in 4:
			var c := _random_free_cell(boss_rect)
			if c.x >= 0 and c.y < boss_rect.end.y - 3:
				_block(Rect2i(c, Vector2i.ONE))
				_add_prop(world, P + "cover_block.gd", cell_center(c), StaticBody2D)
	player_spawn = cell_center(Vector2i(_gap_x, start_rect.position.y + 4))


## Painted-map mode: placed structures (outpost buildings), dormant turrets and ground decals.
func _spawn_structures() -> void:
	if _layout.get("structures") == null:
		return
	var poly: PackedVector2Array = _layout.get("wall_poly") if _layout.get("wall_poly") != null else PackedVector2Array()
	for s: Dictionary in _layout.structures:
		var st := OutpostStructure.new()
		st.texture = load("res://assets/hq/outpost/%s.png" % s["tex"])
		st.width = s["w"] * _map_k.x
		st.flip = s.get("flip", false)
		if s.get("poly", false):
			st.polygon = poly
		else:
			st.footprint = s.get("fp", st.footprint)
		st.max_hp = s.get("hp", 0.0) * enemy_hp_mult
		st.explosive = s.get("explosive", false)
		st.place_visual_center(map_to_world(s["at"]))
		world.add_child(st)
	for p: Vector2 in _layout.turrets:
		var t: Enemy = load("res://enemies/outpost_turret.tscn").instantiate()
		t.max_hp *= enemy_hp_mult * Game.diff("hp")
		t.damage_mult = enemy_damage_mult * Game.diff("damage")
		t.position = map_to_world(p)
		world.add_child(t)
	var crater: Texture2D = load("res://assets/hq/outpost/crater.png")
	for p: Vector2 in _layout.decals:
		var d := Sprite2D.new()
		d.texture = crater
		d.position = map_to_world(p)
		d.rotation = _rng.randf() * TAU
		d.scale = Vector2.ONE * _rng.randf_range(0.55, 0.8)
		d.z_index = -7
		floor_props.add_child(d)


## Image-space rects covered by placed structures and turrets (for spawn-point checks).
var _struct_rects: Array[Rect2] = []
func _structure_rects() -> Array[Rect2]:
	if not _struct_rects.is_empty() or _layout.get("structures") == null:
		return _struct_rects
	for s: Dictionary in _layout.structures:
		var tex: Texture2D = load("res://assets/hq/outpost/%s.png" % s["tex"])
		var size: Vector2 = tex.get_size() * (float(s["w"]) / tex.get_width())
		var vis := Rect2(s["at"] - size / 2, size)
		if s.get("poly", false):
			_struct_rects.append(Rect2(vis.position + Vector2(0, size.y * 0.25), Vector2(size.x, size.y * 0.75)))
		else:
			var f: Rect2 = s.get("fp", Rect2(0.1, 0.4, 0.8, 0.55))
			if s.get("flip", false):
				f.position.x = 1.0 - f.position.x - f.size.x
			_struct_rects.append(Rect2(vis.position + f.position * size, f.size * size))
	for p: Vector2 in _layout.turrets:
		_struct_rects.append(Rect2(p - Vector2(110, 90), Vector2(220, 180)))
	return _struct_rects


## Painted-map mode: is this world point open floor (not inside/near traced collision)?
func _map_open(world_pos: Vector2, margin := 48.0) -> bool:
	var p := (world_pos - Vector2(main_rect.position) * T) / _map_k
	var m := margin / _map_k.x
	for r in _structure_rects():
		if r.grow(m).has_point(p):
			return false
	for poly: PackedVector2Array in _layout.solids:
		if Geometry2D.is_point_in_polygon(p, poly):
			return false
		for i in poly.size():
			if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) < m:
				return false
	for r: Rect2 in _layout.cover:
		if r.grow(m).has_point(p):
			return false
	for r: Rect2 in _layout.pits:
		if r.grow(m).has_point(p):
			return false
	return true


## High-detail ground decals (Higgsfield renders): rubble piles and blast scorches, randomly rotated
## and scaled, on open floor in the main zone. Purely visual.
func _scatter_hq_decals() -> void:
	var decals: Array[Texture2D] = [load("res://assets/hq/rubble.png"), load("res://assets/hq/scorch.png")]
	var count := main_rect.get_area() / 45
	for i in count:
		var c := Vector2i(_rng.randi_range(main_rect.position.x + 1, main_rect.end.x - 2),
			_rng.randi_range(main_rect.position.y + 1, main_rect.end.y - 2))
		if _solid.has(c) or floor_layer.get_cell_source_id(c) == -1:
			continue
		var s := Sprite2D.new()
		s.texture = decals[i % decals.size()]
		s.position = cell_center(c) + Vector2(_rng.randf_range(-24, 24), _rng.randf_range(-24, 24))
		s.rotation = _rng.randf() * TAU
		s.scale = Vector2.ONE * _rng.randf_range(0.5, 0.85)
		s.modulate = Color(0.85, 0.85, 0.9, 0.9)
		s.z_index = -7
		floor_props.add_child(s)


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
	# Painted maps use indestructible cover (layer 6), so enemies path around it too.
	np.parsed_collision_mask = 1 | 64 | (32 if _layout else 0)
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
	var gap := _add_prop(world, P + "energy_barrier.gd", Vector2(_gap_x * T, main_rect.end.y * T + T / 2.0), StaticBody2D,
		{"size": Vector2(4 * T, T)})
	# Blast door to the boss room.
	var door_pos := Vector2(_door_x * T, (main_rect.position.y - 1) * T)
	var door_size := Vector2(4 * T, 2 * T)
	if _boss_layout:
		# Fill the painted gate exactly so nothing can slip past the closed door.
		var gl := boss_to_world(Vector2(_boss_layout.gate_left, 0)).x
		var gr := boss_to_world(Vector2(_boss_layout.gate_right, 0)).x
		door_pos.x = (gl + gr) / 2
		door_size.x = gr - gl + 8
	door = _add_prop(floor_props, P + "blast_door.gd", door_pos, StaticBody2D,
		{"size": door_size, "painted": _boss_layout != null})
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
			var open := _map_open(cell_center(c)) if _layout else not _solid.has(c) and not _blocked.has(c)
			if open:
				pts.append(cell_center(c))
	zone.spawn_points = pts
	add_child(zone)
	zone.started.connect(func() -> void:
		for t in get_tree().get_nodes_in_group("turrets"):
			t.set("active", true)
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
	set_camera_region(&"open")
	banner.emit("ZONE CLEARED - BOSS DOOR OPEN", Color(0.4, 1.0, 0.6))
	objective_changed.emit("Enter the boss arena (north)")


func _start_boss() -> void:
	_boss_started = true
	door.close()
	set_camera_region(&"boss")
	banner.emit(boss_name, boss_accent)
	objective_changed.emit("Destroy the %s" % boss_name)
	var b: Enemy = (boss_scene if boss_scene else load("res://enemies/warden_boss.tscn")).instantiate()
	b.max_hp = boss_hp * Game.diff("boss_hp")
	b.damage_mult = enemy_damage_mult * Game.diff("damage")
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
	Upgrades.vacuum()
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void: arena_cleared.emit())
