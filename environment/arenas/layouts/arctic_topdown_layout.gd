extends RefCounted
## FROZEN OUTPOST, top-down (level 1): gameplay traced over the straight-down painted Higgsfield map
## (assets/hq/env_arctic_topdown.png, 3312 x 2480). Coordinates are ORIGINAL image pixels; the arena
## draws it at map_scale 1.5 (about 5000 x 3700 world px) so the mech is small next to the buildings.
##   walkable   - the explorable area: plaza + the snowfields around it, inside the rock border
##   obstacles  - everything solid standing on it: buildings, containers, pipe runs, crate piles,
##                towers, the radar dish, ice-rock clusters and fences
##   occluders  - none (top-down: nothing tall hides the mech)
##   vents      - the three steam grates (hazards)
##   props      - destructible cover placed on top of the art: [kind, position, rotation degrees]
##                (kinds: see ScenicArena.SNOW_PROPS)

var image_size := Vector2(3312, 2480)

var walkable := PackedVector2Array([
	Vector2(130, 95), Vector2(2470, 95), Vector2(2600, 250), Vector2(2560, 480), Vector2(2960, 480),
	Vector2(2990, 700), Vector2(2990, 1650), Vector2(2950, 1950), Vector2(2800, 2080), Vector2(2450, 2140),
	Vector2(2200, 2290), Vector2(620, 2290), Vector2(480, 2200), Vector2(300, 2100), Vector2(130, 1900),
])

var obstacles: Array[PackedVector2Array] = [
	# North-west research station: main block + courtyard wing + lower container row.
	PackedVector2Array([Vector2(300, 95), Vector2(1165, 95), Vector2(1165, 392), Vector2(690, 392),
		Vector2(690, 320), Vector2(300, 320)]),
	PackedVector2Array([Vector2(175, 315), Vector2(695, 315), Vector2(695, 640), Vector2(610, 640),
		Vector2(610, 760), Vector2(745, 760), Vector2(745, 990), Vector2(175, 990)]),
	_r(1280, 95, 1345, 160), _r(1320, 150, 1405, 250), _r(1340, 268, 1455, 332),
	# Ice-rock outcrop + frozen container north of the plaza.
	PackedVector2Array([Vector2(1045, 540), Vector2(1160, 505), Vector2(1300, 440), Vector2(1410, 470),
		Vector2(1400, 560), Vector2(1380, 690), Vector2(1270, 700), Vector2(1270, 900), Vector2(1125, 900),
		Vector2(1125, 790), Vector2(1050, 780)]),
	# West containers and crates.
	_r(315, 1110, 595, 1335), _r(645, 1095, 715, 1165),
	# North containers, heating pipes, pump, crate piles.
	_r(1610, 125, 1840, 280), _r(1765, 265, 1820, 330),
	_r(1946, 95, 2370, 170), _r(2190, 120, 2380, 530), _r(2350, 415, 2460, 505),
	_r(2026, 190, 2146, 270), _r(2006, 390, 2171, 575), _r(2126, 590, 2256, 670), _r(2371, 355, 2461, 415),
	_r(2511, 275, 2586, 360),
	# Radar dish + the rocks at its foot.
	_circle(Vector2(2750, 735), 185.0),
	PackedVector2Array([Vector2(2400, 610), Vector2(2530, 600), Vector2(2560, 760), Vector2(2530, 990),
		Vector2(2440, 960), Vector2(2380, 780)]),
	_r(2256, 890, 2356, 1000), _r(2311, 1015, 2386, 1090), _r(2436, 1025, 2556, 1180),
	# East pipe run, frame tower, cage, crates.
	_r(2681, 1030, 2791, 1930), _r(2786, 1010, 2906, 1400), _r(2546, 1430, 2666, 1580), _r(2786, 1710, 2936, 1880),
	# South-east ice rocks, container, crates, fence, guard hut.
	PackedVector2Array([Vector2(2420, 1760), Vector2(2560, 1680), Vector2(2700, 1700), Vector2(2790, 1830),
		Vector2(2700, 1945), Vector2(2500, 1920), Vector2(2420, 1850)]),
	_r(2146, 1940, 2396, 2100), _r(2031, 2070, 2126, 2155), _r(1656, 2160, 2126, 2190), _r(1400, 2050, 1535, 2290),
	# South-west heating pipes, machinery, crates, beacon tower, rocks.
	_r(500, 1505, 600, 2215), _r(500, 2120, 860, 2220), _r(590, 1690, 700, 1840), _r(630, 2010, 740, 2120),
	_r(290, 1560, 425, 1685), _r(290, 1820, 450, 2040),
	# Small west platform, a stray east crate, and the lamp posts.
	_r(310, 1010, 480, 1080), _r(2320, 1110, 2390, 1170),
	_circle(Vector2(790, 750), 16.0), _circle(Vector2(710, 2030), 16.0), _circle(Vector2(1610, 2050), 16.0),
	_circle(Vector2(2080, 2060), 16.0), _circle(Vector2(2610, 1325), 16.0), _circle(Vector2(940, 2270), 16.0),
]

var occluders: Array[PackedVector2Array] = []

var vents: Array[Vector2] = [Vector2(1675, 835), Vector2(1711, 1485), Vector2(1132, 1992)]
var vent_color := Color(0.85, 0.95, 1.0)
var spawn := Vector2(1250, 1800)
var boss_spawn := Vector2(1700, 1150)
var repair_station := Vector2(860, 1350)
var barrels: Array[Vector2] = []
var crates: Array[Vector2] = []
var destructible_cover: Array[Vector2] = []

var props := [
	["barrier", Vector2(1250, 1150), 0.0], ["barrier", Vector2(2150, 1250), 90.0],
	["barrier", Vector2(1600, 620), 0.0], ["barrier", Vector2(1950, 1820), 0.0],
	["sandbags", Vector2(1000, 1500), 90.0], ["sandbags", Vector2(1350, 1650), 0.0],
	["sandbags", Vector2(2250, 900), 0.0], ["sandbags", Vector2(1850, 1050), 0.0],
	["cargo", Vector2(1500, 1350), 0.0], ["cargo", Vector2(2050, 1550), 0.0],
	["crate_wood", Vector2(900, 1100), 0.0], ["crate_wood", Vector2(1500, 900), 15.0],
	["crate_wood", Vector2(1000, 1850), -10.0], ["crate_steel", Vector2(2300, 1500), 0.0],
	["crate_steel", Vector2(1750, 450), 0.0], ["crate_steel", Vector2(2200, 800), 0.0],
	["barrel", Vector2(1050, 1250), 0.0], ["barrel", Vector2(1950, 1250), 0.0],
	["barrel", Vector2(1700, 1950), 0.0], ["barrel", Vector2(2350, 1250), 0.0], ["barrel", Vector2(800, 700), 0.0],
]


static func _r(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(c + Vector2.from_angle(TAU * i / 12.0) * r)
	return pts
