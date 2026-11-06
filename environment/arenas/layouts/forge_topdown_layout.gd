extends RefCounted
## VOLCANIC FORGE, top-down (level 6): gameplay traced over the straight-down painted Higgsfield map
## (assets/hq/env_forge_topdown.png, 3312 x 2480). Coordinates are ORIGINAL image pixels (traced at
## half size); the arena draws it at map_scale 1.5.
##   walkable   - the foundry floor inside the ring of forge buildings (lava all around outside), with the
##                short corridors at the top gate and beside the south furnace gate
##   obstacles  - the four raised gate blocks around the central landing ring, fan housings, generators,
##                crates, benches, tipped-over slag canisters, the machine by the south-east buildings
##   occluders  - none (top-down)
##   vents      - two lava vents in the floor cracks (hazards); the boss lands in the central ring
##   props      - destructible cover on top of the art (kinds: ScenicArena.SNOW_PROPS, art: prop_folder)

var image_size := Vector2(3312, 2480)

var walkable := _x2(PackedVector2Array([
	Vector2(300, 285), Vector2(560, 270), Vector2(575, 150), Vector2(752, 150), Vector2(756, 102),
	Vector2(904, 102), Vector2(906, 160), Vector2(1000, 165), Vector2(1060, 150), Vector2(1066, 292),
	Vector2(1360, 300), Vector2(1402, 330), Vector2(1405, 700), Vector2(1362, 712), Vector2(1350, 800),
	Vector2(1242, 818), Vector2(1240, 878), Vector2(1062, 886), Vector2(1060, 1048), Vector2(1002, 1048),
	Vector2(996, 880), Vector2(756, 880), Vector2(748, 892), Vector2(500, 892), Vector2(440, 880),
	Vector2(305, 878),
]))

var obstacles: Array[PackedVector2Array] = [
	# The raised gate blocks on the central landing ring (N, S, W, E).
	_r2(792, 415, 852, 452), _r2(792, 645, 852, 688), _r2(634, 528, 668, 592), _r2(990, 528, 1026, 592),
	# North-west: fan housing, generator, crate.
	_r2(695, 262, 748, 325), _r2(515, 375, 610, 432), _r2(488, 450, 556, 492),
	# West / south-west: crate pair, tipped canister, fan housing, the box by the furnace gate.
	_r2(512, 605, 578, 670), _c2(685, 728, 30), _r2(510, 762, 640, 828), _r2(683, 858, 718, 905),
	# North-east: crate stack, bench, long bench, fan housing, box.
	_r2(1000, 265, 1055, 360), _r2(935, 268, 995, 290), _r2(1045, 443, 1135, 467), _r2(1180, 392, 1238, 462),
	_r2(1238, 503, 1288, 537),
	# East / south-east: crate pair, bench, tipped canister, the machine.
	_r2(1084, 612, 1148, 652), _r2(1185, 718, 1292, 746), _c2(978, 818, 30), _r2(1112, 798, 1172, 882),
]

var occluders: Array[PackedVector2Array] = []

var vents: Array[Vector2] = [Vector2(860, 1400), Vector2(2600, 1200)]
var vent_color := Color(1.0, 0.55, 0.15)
var spawn := Vector2(1640, 1520)
var boss_spawn := Vector2(1640, 1090)
var repair_station := Vector2(760, 1120)
var barrels: Array[Vector2] = []
var crates: Array[Vector2] = []
var destructible_cover: Array[Vector2] = []
## Prop textures: assets/hq/<prop_folder>/<kind>.png
var prop_folder := "props_topdown"

var props := _props2([
	["barrier", Vector2(640, 330), 0.0], ["barrier", Vector2(1120, 540), 90.0], ["barrier", Vector2(430, 560), 90.0],
	["sandbags", Vector2(900, 360), 0.0], ["sandbags", Vector2(1300, 380), 0.0], ["sandbags", Vector2(380, 800), 0.0],
	["cargo", Vector2(1290, 660), 0.0], ["cargo", Vector2(430, 330), 0.0],
	["crate_steel", Vector2(740, 810), 0.0], ["crate_steel", Vector2(1330, 480), 0.0],
	["crate_wood", Vector2(560, 540), 15.0],
	["barrel", Vector2(740, 600), 0.0], ["barrel", Vector2(940, 480), 0.0], ["barrel", Vector2(1060, 760), 0.0],
	["barrel", Vector2(620, 220), 0.0],
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
