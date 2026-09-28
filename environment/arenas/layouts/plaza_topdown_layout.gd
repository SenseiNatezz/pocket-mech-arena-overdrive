extends RefCounted
## RUINED PLAZA, top-down (level 5): gameplay traced over the straight-down painted Higgsfield map
## (assets/hq/env_plaza_topdown.png, 3312 x 2480). Coordinates are ORIGINAL image pixels (traced at
## half size); the arena draws it at map_scale 1.5.
##   walkable   - the plaza and the two streets leaving it, inside the ruined city blocks
##   obstacles  - the fountain, monuments, bomb craters, burned-out cars / trucks, fallen beams, rubble heaps
##   occluders  - none (top-down)
##   vents      - two burst gas mains in the street (hazards); the boss lands just south of the fountain
##   props      - destructible cover on top of the art (kinds: ScenicArena.SNOW_PROPS, art: prop_folder)

var image_size := Vector2(3312, 2480)

var walkable := _x2(PackedVector2Array([
	Vector2(150, 160), Vector2(760, 160), Vector2(770, 40), Vector2(990, 40), Vector2(990, 160),
	Vector2(1270, 170), Vector2(1270, 240), Vector2(1500, 250), Vector2(1520, 500), Vector2(1440, 520),
	Vector2(1440, 760), Vector2(1510, 780), Vector2(1510, 990), Vector2(1250, 1010), Vector2(990, 1000),
	Vector2(990, 1100), Vector2(760, 1100), Vector2(760, 1000), Vector2(420, 1000), Vector2(230, 990),
	Vector2(150, 760), Vector2(150, 500), Vector2(140, 250),
]))

var obstacles: Array[PackedVector2Array] = [
	# Fountain, monuments, bomb craters, the collapsed structure north-east of the fountain.
	_c2(830, 585, 75), _c2(1255, 485, 38), _c2(355, 780, 36),
	_c2(570, 290, 70), _c2(620, 525, 48), _c2(1070, 860, 75), _r2(1050, 280, 1160, 360),
	# North-west: wrecks, crates and fallen beams.
	_r2(620, 320, 690, 385), _r2(455, 415, 500, 450), _r2(340, 330, 380, 360), _r2(375, 360, 425, 400),
	_r2(350, 460, 365, 510), _r2(545, 450, 580, 500), _r2(715, 380, 760, 420), _r2(760, 250, 800, 290),
	# North: the truck on the avenue, rubble, debris around the fountain.
	_r2(870, 125, 910, 200), _r2(920, 400, 970, 420), _r2(960, 460, 1000, 515),
	_r2(1040, 420, 1060, 480),
	# North-east: trucks, wrecks.
	_r2(1110, 400, 1170, 440), _r2(1200, 330, 1250, 370), _r2(1265, 290, 1300, 320), _r2(1385, 380, 1435, 410),
	_r2(1380, 440, 1440, 490),
	# East: cars and vans around the plaza.
	_r2(1080, 550, 1130, 590), _r2(1180, 570, 1220, 610), _r2(1160, 655, 1220, 685), _r2(1070, 680, 1130, 730),
	_r2(1270, 670, 1310, 710), _r2(980, 580, 1030, 610), _r2(1170, 750, 1230, 790),
	# West: wrecks, the generator, a car.
	_r2(440, 560, 500, 600), _r2(320, 610, 370, 660), _r2(270, 690, 320, 740), _r2(450, 680, 490, 720),
	_r2(560, 640, 650, 710), _r2(180, 680, 200, 730),
	# South: wrecks, fallen beams, trucks.
	_r2(410, 820, 450, 870), _r2(480, 820, 510, 850), _r2(590, 850, 650, 900), _r2(670, 800, 720, 835),
	_r2(700, 830, 800, 870), _r2(790, 850, 820, 880), _r2(850, 950, 900, 990), _r2(920, 980, 960, 1010),
	_r2(1180, 820, 1230, 850), _r2(1300, 830, 1340, 880),
]

var occluders: Array[PackedVector2Array] = []

var vents: Array[Vector2] = [Vector2(800, 1900), Vector2(2500, 500)]
var vent_color := Color(1.0, 0.8, 0.6)
var spawn := Vector2(1560, 1840)
var boss_spawn := Vector2(1660, 1440)
var repair_station := Vector2(600, 1120)
var barrels: Array[Vector2] = []
var crates: Array[Vector2] = []
var destructible_cover: Array[Vector2] = []
## Prop textures: assets/hq/<prop_folder>/<kind>.png
var prop_folder := "props_topdown"

var props := _props2([
	["barrier", Vector2(690, 470), 0.0], ["barrier", Vector2(1000, 760), 90.0], ["barrier", Vector2(430, 760), 0.0],
	["sandbags", Vector2(1300, 580), 0.0], ["sandbags", Vector2(880, 300), 0.0], ["sandbags", Vector2(260, 900), 90.0],
	["cargo", Vector2(1150, 230), 0.0], ["cargo", Vector2(1360, 620), 0.0],
	["crate_wood", Vector2(450, 300), 15.0], ["crate_wood", Vector2(1250, 930), 0.0],
	["crate_steel", Vector2(560, 960), 0.0], ["crate_steel", Vector2(1400, 300), 0.0],
	["barrel", Vector2(760, 480), 0.0], ["barrel", Vector2(900, 450), 0.0], ["barrel", Vector2(1150, 500), 0.0],
	["barrel", Vector2(620, 780), 0.0],
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
