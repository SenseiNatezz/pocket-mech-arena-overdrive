extends RefCounted
## TITAN GRAVEYARD, top-down (level 7): gameplay traced over the straight-down painted Higgsfield map
## (assets/hq/env_desert_topdown.png, 3312 x 2480). Coordinates are ORIGINAL image pixels (traced at
## half size); the arena draws it at map_scale 1.5.
##   walkable   - the sand basin: the fallen titan's ribs and outstretched hand close the top, the red
##                mesas the right and bottom-right (the oasis pool too), the camp tents and mesas the
##                bottom, the wrecks and cliffs the left
##   obstacles  - the sunken tanks and dead mechs, crate stacks, boulders
##   occluders  - none (top-down)
##   vents      - none (the sandstorm and the Dune Burrowers are this map's hazards)
##   props      - destructible cover on top of the art (kinds: ScenicArena.SNOW_PROPS, art: prop_folder)

var image_size := Vector2(3312, 2480)

var walkable := _x2(PackedVector2Array([
	Vector2(420, 290), Vector2(470, 245), Vector2(620, 255), Vector2(760, 265), Vector2(900, 272),
	Vector2(1040, 268), Vector2(1180, 278), Vector2(1290, 290), Vector2(1370, 372), Vector2(1470, 420),
	Vector2(1560, 450), Vector2(1565, 800), Vector2(1480, 840), Vector2(1300, 870), Vector2(1200, 895),
	Vector2(1140, 960), Vector2(1080, 1015), Vector2(1000, 1045), Vector2(560, 1045), Vector2(440, 1040),
	Vector2(330, 1030), Vector2(300, 960), Vector2(220, 930), Vector2(120, 920), Vector2(110, 700),
	Vector2(120, 470), Vector2(220, 445), Vector2(330, 440), Vector2(400, 425), Vector2(440, 330),
]))

var obstacles: Array[PackedVector2Array] = [
	# Top: the boulder below the titan's ribs, the crate stack by the right-hand camp.
	_r2(472, 298, 530, 338), _r2(1300, 300, 1362, 358),
	# Right: the sunken tank, the dead mech, the rocks below it.
	_r2(1395, 450, 1530, 552), _r2(1420, 620, 1555, 745), _r2(1320, 722, 1400, 762),
	# Bottom: the boulders in front of the camp.
	_r2(705, 1000, 760, 1040),
	# Left: the tank half under the sand, the crate pile, the two dead mechs, the boulders.
	_r2(120, 500, 200, 585), _r2(120, 595, 152, 652), _r2(120, 742, 250, 830), _r2(200, 822, 380, 900),
	_r2(350, 948, 402, 978),
]

var occluders: Array[PackedVector2Array] = []

var vents: Array[Vector2] = []
var spawn := Vector2(1660, 1820)
var boss_spawn := Vector2(1660, 1200)
var repair_station := Vector2(960, 1760)
var barrels: Array[Vector2] = []
var crates: Array[Vector2] = []
var destructible_cover: Array[Vector2] = []
## Prop textures: assets/hq/<prop_folder>/<kind>.png
var prop_folder := "props_topdown"

var props := _props2([
	["sandbags", Vector2(560, 520), 20.0], ["sandbags", Vector2(1110, 470), -15.0], ["sandbags", Vector2(1180, 820), 10.0],
	["sandbags", Vector2(470, 820), 0.0], ["barrier", Vector2(830, 380), 0.0], ["barrier", Vector2(300, 640), 90.0],
	["barrier", Vector2(1450, 600), 90.0], ["cargo", Vector2(1250, 360), 0.0], ["cargo", Vector2(640, 960), 0.0],
	["crate_wood", Vector2(980, 960), 20.0], ["crate_wood", Vector2(260, 540), -10.0], ["crate_steel", Vector2(1380, 800), 0.0],
	["barrel", Vector2(700, 420), 0.0], ["barrel", Vector2(1020, 360), 0.0], ["barrel", Vector2(400, 980), 0.0],
	["barrel", Vector2(1300, 640), 0.0],
])


## Half-size tracing helpers: arguments are overview (half-size) pixels, stored as original pixels.
static func _r2(x0: float, y0: float, x1: float, y1: float) -> PackedVector2Array:
	return _x2(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]))


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
