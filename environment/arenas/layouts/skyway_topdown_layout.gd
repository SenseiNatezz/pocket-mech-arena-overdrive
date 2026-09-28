extends RefCounted
## SKYWAY JUNCTION, top-down (level 4): gameplay traced over the straight-down painted Higgsfield map
## (assets/hq/env_skyway_topdown.png, 3312 x 2480). Coordinates are ORIGINAL image pixels (traced at
## half size); the arena draws it at map_scale 1.5.
##   walkable   - the highway deck and interchange, bounded by the building blocks and the drop to the city
##   obstacles  - the corner building blocks, the roundabout monument, toll booths, parked trucks / buses /
##                containers (the low diagonal barrier rails are left walkable)
##   occluders  - none (top-down)
##   vents      - two steam vents in the deck (hazards); the boss lands just south of the roundabout monument
##   props      - destructible cover on top of the art (kinds: ScenicArena.SNOW_PROPS, art: prop_folder)

var image_size := Vector2(3312, 2480)

var walkable := _x2(PackedVector2Array([
	Vector2(140, 60), Vector2(1530, 60), Vector2(1530, 720), Vector2(1520, 1100), Vector2(1060, 1110),
	Vector2(990, 1150), Vector2(760, 1150), Vector2(600, 1130), Vector2(120, 1100), Vector2(120, 700),
	Vector2(140, 300),
]))

var obstacles: Array[PackedVector2Array] = [
	# Corner building blocks (the deck is walled in by them).
	_r2(140, 60, 360, 500), _r2(360, 60, 520, 265), _r2(120, 500, 290, 700), _r2(100, 700, 420, 1110),
	_r2(390, 880, 620, 1135), _r2(1040, 980, 1260, 1140), _r2(1250, 780, 1530, 1110),
	_r2(1040, 30, 1300, 250), _r2(1300, 40, 1530, 340), _r2(1480, 460, 1530, 600),
	# Roundabout monument and the toll plaza (booths + queued cars).
	_c2(825, 555, 42), _r2(755, 910, 890, 960), _r2(760, 960, 880, 1010),
	# Parked trucks, buses, cargo containers, the parking row, a machine and a barrier.
	_r2(500, 440, 590, 470), _r2(490, 370, 610, 420), _r2(710, 220, 735, 275), _r2(905, 200, 930, 260),
	_r2(1185, 430, 1260, 470), _r2(1135, 290, 1190, 335), _r2(1195, 270, 1250, 320), _r2(740, 775, 775, 880),
	_r2(1165, 755, 1210, 870), _r2(1100, 800, 1125, 880), _r2(530, 755, 555, 810), _r2(655, 665, 705, 720),
	_r2(990, 530, 1020, 590), _r2(500, 680, 560, 710), _r2(505, 620, 590, 650), _r2(315, 640, 385, 660),
	_r2(1260, 520, 1310, 545), _r2(1270, 750, 1300, 860), _r2(1150, 650, 1200, 685),
]

var occluders: Array[PackedVector2Array] = []

var vents: Array[Vector2] = [Vector2(1300, 1560), Vector2(2100, 1320)]
var vent_color := Color(1.0, 0.8, 0.5)
var spawn := Vector2(1660, 2160)
var boss_spawn := Vector2(1650, 1280)
var repair_station := Vector2(840, 1120)
var barrels: Array[Vector2] = []
var crates: Array[Vector2] = []
var destructible_cover: Array[Vector2] = []
## Prop textures: assets/hq/<prop_folder>/<kind>.png
var prop_folder := "props_topdown"

var props := _props2([
	["barrier", Vector2(650, 500), 0.0], ["barrier", Vector2(1000, 440), 90.0], ["barrier", Vector2(1100, 700), 0.0],
	["sandbags", Vector2(430, 800), 90.0], ["sandbags", Vector2(960, 740), 0.0], ["sandbags", Vector2(1380, 600), 90.0],
	["cargo", Vector2(620, 180), 0.0], ["cargo", Vector2(1350, 400), 0.0],
	["crate_wood", Vector2(450, 330), 15.0], ["crate_wood", Vector2(1000, 360), 0.0],
	["crate_steel", Vector2(700, 380), 0.0], ["crate_steel", Vector2(1250, 640), 0.0],
	["barrel", Vector2(600, 560), 0.0], ["barrel", Vector2(1080, 560), 0.0], ["barrel", Vector2(900, 820), 0.0],
	["barrel", Vector2(640, 850), 0.0],
])


## Half-size tracing helpers: arguments are overview (half-size) pixels, stored as original pixels.
static func _r2(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return _x2(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]))


static func _c2(cx: float, cy: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append((Vector2(cx, cy) + Vector2.from_angle(TAU * i / 12.0) * r) * 2.0)
	return pts


static func _x2(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * 2.0)
	return out


static func _props2(list: Array) -> Array:
	var out := []
	for p in list:
		out.append([p[0], p[1] * 2.0, p[2]])
	return out
