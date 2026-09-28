extends RefCounted
## ALIEN OUTPOST, top-down (level 3): gameplay traced over the straight-down painted Higgsfield map
## (assets/hq/env_outpost_topdown.png, 3312 x 2480). Coordinates are ORIGINAL image pixels (traced at
## half size, so they're even numbers); the arena draws it at map_scale 1.5.
##   walkable   - the metal deck plazas inside the violet cliffs / crystal fields
##   obstacles  - domes, the radar dish, hangars, towers, generators, containers, rock + crystal patches
##   occluders  - none (top-down)
##   vents      - the steam grate in the middle of the command-core landing pad + one in the south-west;
##                the boss lands on the pad just south of the grate
##   props      - destructible cover on top of the art (kinds: ScenicArena.SNOW_PROPS, art: prop_folder)

var image_size := Vector2(3312, 2480)

var walkable := _x2(PackedVector2Array([
	Vector2(250, 30), Vector2(1250, 25), Vector2(1380, 60), Vector2(1540, 120), Vector2(1540, 480),
	Vector2(1590, 520), Vector2(1590, 730), Vector2(1500, 760), Vector2(1500, 990), Vector2(1450, 1090),
	Vector2(1300, 1090), Vector2(1250, 1000), Vector2(760, 1000), Vector2(760, 1090), Vector2(500, 1090),
	Vector2(430, 1000), Vector2(250, 1000), Vector2(90, 990), Vector2(70, 760), Vector2(70, 500),
	Vector2(130, 300), Vector2(160, 120),
]))

var obstacles: Array[PackedVector2Array] = [
	# North-west: the big dome, generators, crates, the crystal rock bed.
	_c2(240, 205, 80), _r2(100, 420, 190, 470), _r2(95, 540, 140, 625), _r2(285, 550, 345, 600),
	_r2(370, 250, 435, 295), _r2(325, 150, 360, 195), _r2(370, 70, 440, 110), _r2(365, 340, 500, 495),
	# North: the tank tower, container stacks, the workshop and the pylons around the landing pad.
	_r2(505, 55, 545, 100), _r2(645, 100, 730, 150), _r2(705, 160, 745, 195), _r2(510, 370, 590, 450),
	_r2(605, 235, 640, 280), _r2(700, 450, 730, 495), _r2(915, 450, 945, 495), _r2(705, 680, 730, 720),
	_r2(915, 685, 945, 720), _r2(750, 200, 800, 290),
	# North-centre rock + crystal beds, the relay tower, crates and the pump.
	_r2(885, 290, 1000, 440), _r2(1000, 300, 1110, 440), _r2(955, 100, 995, 170), _r2(1040, 225, 1090, 275),
	_r2(1070, 270, 1140, 340), _r2(1185, 370, 1250, 470), _r2(1180, 80, 1225, 120),
	# North-east: the second dome, a cargo hauler and the radar dish.
	_c2(1290, 135, 60), _r2(1300, 185, 1380, 250), _c2(1455, 330, 85),
	# East: the beacon tower, crystal bed, small dome, generator, container.
	_r2(1525, 560, 1570, 610), _r2(1285, 580, 1375, 650), _r2(1110, 545, 1160, 590), _r2(1185, 590, 1225, 635),
	_r2(1150, 710, 1215, 770),
	# South-east: the third dome + its tower, the generator block, the south dome complex.
	_c2(1410, 880, 75), _r2(1360, 720, 1450, 800), _r2(1050, 800, 1150, 880), _r2(900, 950, 1030, 1040),
	# South-west: the hangar, crates, tanks, rock beds.
	_r2(95, 830, 245, 990), _r2(145, 765, 210, 810), _r2(285, 770, 320, 830), _r2(515, 810, 610, 855),
	_r2(520, 860, 570, 900), _r2(440, 935, 500, 990), _r2(410, 700, 500, 800), _r2(650, 750, 760, 880),
	_r2(760, 820, 790, 935), _r2(495, 550, 560, 600),
	# South pad: tower and crate stacks.
	_r2(520, 1045, 570, 1095), _r2(600, 1040, 680, 1090), _r2(705, 1045, 745, 1090),
]

var occluders: Array[PackedVector2Array] = []

var vents: Array[Vector2] = [Vector2(1640, 1150), Vector2(600, 1800)]
var vent_color := Color(0.8, 0.7, 1.0)
var spawn := Vector2(1660, 1800)
var boss_spawn := Vector2(1640, 1280)
var repair_station := Vector2(640, 1300)
var barrels: Array[Vector2] = []
var crates: Array[Vector2] = []
var destructible_cover: Array[Vector2] = []
## Prop textures: assets/hq/<prop_folder>/<kind>.png
var prop_folder := "props_topdown"

var props := [
	["barrier", Vector2(1200, 1280), 0.0], ["barrier", Vector2(2100, 1300), 90.0], ["barrier", Vector2(1640, 760), 0.0],
	["sandbags", Vector2(700, 1400), 90.0], ["sandbags", Vector2(2500, 1120), 0.0], ["sandbags", Vector2(2000, 1520), 0.0],
	["cargo", Vector2(960, 400), 0.0], ["cargo", Vector2(2360, 500), 0.0],
	["crate_wood", Vector2(600, 840), 15.0], ["crate_wood", Vector2(2640, 940), 0.0],
	["crate_steel", Vector2(1320, 600), 0.0], ["crate_steel", Vector2(2400, 1800), 0.0],
	["barrel", Vector2(860, 1240), 0.0], ["barrel", Vector2(2000, 1160), 0.0], ["barrel", Vector2(1200, 1520), 0.0],
	["barrel", Vector2(2600, 1400), 0.0],
]


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
