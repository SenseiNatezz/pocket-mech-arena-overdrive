extends RefCounted
## ORBITAL DRY DOCK, top-down (level 8): gameplay traced over the straight-down painted Higgsfield map
## (assets/hq/env_dock_topdown.png, 3312 x 2480). Coordinates are ORIGINAL image pixels (traced at
## half size); the arena draws it at map_scale 1.6.
##   walkable   - the white landing deck inside its guard rails (the battleship berth along the top, the
##                fuel-tank bays in the top-right and bottom-left corners and the dish platform in the
##                bottom-right are off the deck)
##   obstacles  - the cargo container stacks and the fuel cylinders on the deck, the two crates on the
##                top edge
##   occluders  - none (top-down)
##   vents      - two coolant vents over the deck grates; `panels` - live power panels by the launch pad
##   props      - destructible cover on top of the art (kinds: ScenicArena.SNOW_PROPS, art: prop_folder)

var image_size := Vector2(3312, 2480)

var walkable := _x2(PackedVector2Array([
	Vector2(165, 350), Vector2(310, 342), Vector2(1380, 334), Vector2(1382, 422), Vector2(1495, 430),
	Vector2(1495, 808), Vector2(1350, 818), Vector2(1340, 955), Vector2(285, 955), Vector2(285, 830),
	Vector2(165, 830),
]))

var obstacles: Array[PackedVector2Array] = [
	# Left: the twin gas cylinders, the container stack below them, the lower container stack.
	_r2(165, 375, 205, 470), _r2(205, 418, 278, 532), _r2(188, 685, 292, 785),
	# Bottom: the two container rows on the lower edge.
	_r2(365, 892, 490, 955), _r2(1155, 892, 1300, 955),
	# Right: the two container stacks.
	_r2(1380, 470, 1472, 557), _r2(1380, 685, 1462, 777),
	# Top edge: the two crates by the berth.
	_r2(468, 334, 505, 362), _r2(1155, 334, 1200, 362),
]

var occluders: Array[PackedVector2Array] = []

var vents: Array[Vector2] = [Vector2(1120, 820), Vector2(2180, 1640)]
var vent_color := Color(0.75, 0.55, 1.0)
## Live power panels (environment/hazards/electric_panel.gd) beside the launch pad.
var panels: Array[Vector2] = [Vector2(1180, 1240), Vector2(2140, 1240)]
var spawn := Vector2(1660, 1780)
var boss_spawn := Vector2(1660, 1280)
var repair_station := Vector2(660, 1240)
var barrels: Array[Vector2] = []
var crates: Array[Vector2] = []
var destructible_cover: Array[Vector2] = []
## Prop textures: assets/hq/<prop_folder>/<kind>.png
var prop_folder := "props_topdown"

var props := _props2([
	["barrier", Vector2(560, 520), 0.0], ["barrier", Vector2(1100, 520), 0.0], ["barrier", Vector2(560, 760), 0.0],
	["barrier", Vector2(1100, 760), 0.0], ["cargo", Vector2(400, 620), 90.0], ["cargo", Vector2(1260, 620), 90.0],
	["crate_steel", Vector2(700, 420), 0.0], ["crate_steel", Vector2(960, 860), 0.0], ["crate_steel", Vector2(1300, 420), 0.0],
	["sandbags", Vector2(330, 880), 0.0], ["sandbags", Vector2(1300, 860), 0.0],
	["barrel", Vector2(620, 880), 0.0], ["barrel", Vector2(1040, 400), 0.0], ["barrel", Vector2(250, 600), 0.0],
	["barrel", Vector2(1430, 620), 0.0],
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
