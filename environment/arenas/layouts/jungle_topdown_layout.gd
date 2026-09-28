extends RefCounted
## JUNGLE MEGAFACTORY, top-down (level 2): gameplay traced over the straight-down painted Higgsfield map
## (assets/hq/env_jungle_topdown.png, 3312 x 2480). Coordinates are ORIGINAL image pixels; the arena
## draws it at map_scale 1.5.
##   walkable   - the paved reactor yard inside the jungle / river border
##   obstacles  - buildings, pipe runs, the cooling tower, rock outcrops, cages, crate stacks, lamp towers
##   occluders  - none (top-down)
##   vents      - the two steam grates (hazards); the central ring pad is the boss landing zone
##   props      - destructible cover on top of the art: [kind, position, rotation degrees] (see
##                ScenicArena.SNOW_PROPS for the kinds; textures come from assets/hq/<prop_folder>/)

var image_size := Vector2(3312, 2480)

var walkable := PackedVector2Array([
	Vector2(300, 360), Vector2(380, 140), Vector2(1200, 110), Vector2(2380, 120), Vector2(2500, 300),
	Vector2(2500, 480), Vector2(2560, 620), Vector2(2560, 1060), Vector2(2590, 1080), Vector2(2590, 1860),
	Vector2(2380, 2010), Vector2(2060, 2080), Vector2(1460, 2150), Vector2(950, 2150), Vector2(700, 2120),
	Vector2(600, 2040), Vector2(600, 1330), Vector2(420, 1100), Vector2(300, 1000),
])

var obstacles: Array[PackedVector2Array] = [
	# North-west factory halls, crates and the corrugated container.
	_r(385, 50, 1200, 420), _r(295, 365, 790, 760), _r(475, 750, 850, 985), _r(840, 755, 905, 885),
	_r(335, 810, 410, 875), _r(318, 900, 385, 955), _r(435, 985, 580, 1075), _r(430, 1110, 700, 1320),
	_r(715, 1085, 775, 1150),
	# Mossy rock outcrop, crate stack and the overgrown cage platform north of the yard.
	PackedVector2Array([Vector2(1120, 540), Vector2(1180, 500), Vector2(1300, 450), Vector2(1420, 520),
		Vector2(1420, 620), Vector2(1340, 680), Vector2(1200, 650), Vector2(1130, 600)]),
	_r(1375, 280, 1465, 330), _r(1200, 740, 1330, 880),
	# North machine house, pipe runs, cage, crates and the stair tower.
	_r(1570, 120, 1836, 300), _r(1776, 300, 1821, 360), _r(1956, 135, 2330, 205), _r(2168, 150, 2325, 590),
	_r(2320, 465, 2370, 515), _r(2031, 240, 2121, 300), _r(2341, 415, 2406, 460), _r(2111, 605, 2231, 670),
	_r(1981, 420, 2131, 600), _r(2391, 100, 2491, 290), _r(2481, 285, 2546, 355),
	# Cooling tower, debris and a pump east of the yard.
	_circle(Vector2(2671, 700), 175.0), _r(2201, 875, 2296, 950), _r(2256, 1090, 2326, 1160),
	# East pumping station + its long pipe and the rocks at its foot, a lamp and a crate.
	_r(2590, 1080, 2860, 1480), _r(2595, 1240, 2690, 1850), _r(2610, 1650, 2720, 1850),
	_r(2471, 1455, 2501, 1515), _circle(Vector2(2541, 1325), 16.0),
	# South outbuilding, fence line, lamp tower.
	_r(2086, 1860, 2371, 2000), _r(1656, 2010, 2056, 2070), _r(1430, 1940, 1560, 2240),
	# West pipe run (vertical + elbow) and its crates.
	_r(595, 1440, 695, 2030), _r(660, 2025, 935, 2110), _r(700, 1630, 775, 1755), _r(750, 1935, 830, 2000),
]

var occluders: Array[PackedVector2Array] = []

var vents: Array[Vector2] = [Vector2(1690, 810), Vector2(1180, 1880)]
var vent_color := Color(0.85, 1.0, 0.85)
var spawn := Vector2(1450, 1700)
var boss_spawn := Vector2(1685, 1385)
var repair_station := Vector2(950, 1450)
var barrels: Array[Vector2] = []
var crates: Array[Vector2] = []
var destructible_cover: Array[Vector2] = []
## Prop textures: assets/hq/<prop_folder>/<kind>.png
var prop_folder := "props_topdown"

var props := [
	["barrier", Vector2(1400, 1050), 0.0], ["barrier", Vector2(2100, 1300), 90.0], ["barrier", Vector2(950, 1150), 0.0],
	["sandbags", Vector2(1900, 1650), 0.0], ["sandbags", Vector2(1250, 1500), 90.0], ["sandbags", Vector2(2200, 1500), 0.0],
	["cargo", Vector2(1600, 450), 0.0], ["cargo", Vector2(880, 1850), 0.0],
	["crate_wood", Vector2(1850, 1000), 15.0], ["crate_wood", Vector2(2000, 1830), 0.0],
	["crate_steel", Vector2(1000, 1300), 0.0], ["crate_steel", Vector2(2380, 1650), 0.0],
	["barrel", Vector2(1500, 1220), 0.0], ["barrel", Vector2(2000, 1100), 0.0], ["barrel", Vector2(1450, 800), 0.0],
	["barrel", Vector2(1150, 1300), 0.0],
]


static func _r(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(c + Vector2.from_angle(TAU * i / 12.0) * r)
	return pts
