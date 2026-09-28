extends RefCounted
## Collision/gameplay layout traced over the painted Higgsfield map "Map A" (assets/hq/map_a.png).
## All coordinates are in ORIGINAL image pixels (2688 x 1520); the arena scales them to the world.
##   solids   - buildings / rubble around the edges (block movement, bullets and navigation)
##   cover    - painted cars, barricades and crate stacks (block movement + bullets, indestructible)
##   pits     - the two painted holes (boost across; fall = HP loss)
##   barrels  - painted red barrels, made into real explosive barrels
##   door_x   - x of the boss door (top crosswalk);  gap_x - x of the entrance from the start pad

var image_size := Vector2(2688, 1520)
var door_x := 720.0
var gap_x := 1650.0

var solids: Array[PackedVector2Array] = [
	# West block: billboard building + rubble slope.
	PackedVector2Array([Vector2(0, 0), Vector2(600, 0), Vector2(600, 110), Vector2(440, 120), Vector2(470, 220),
		Vector2(590, 300), Vector2(600, 500), Vector2(520, 560), Vector2(400, 580), Vector2(390, 700), Vector2(0, 700)]),
	# West edge: utility pole wreckage, smoke and fire.
	PackedVector2Array([Vector2(0, 700), Vector2(390, 700), Vector2(300, 760), Vector2(245, 790), Vector2(240, 1060),
		Vector2(180, 1230), Vector2(0, 1250)]),
	# North edge: planter, rubble and burning debris east of the boss door.
	PackedVector2Array([Vector2(860, 0), Vector2(1800, 0), Vector2(1800, 150), Vector2(1600, 150), Vector2(1590, 235),
		Vector2(1344, 235), Vector2(1200, 160), Vector2(1040, 160), Vector2(1030, 140), Vector2(860, 140)]),
	# North-east: neon storefront building and the building in the corner.
	PackedVector2Array([Vector2(1800, 0), Vector2(2688, 0), Vector2(2688, 200), Vector2(2450, 210), Vector2(2230, 250),
		Vector2(2100, 300), Vector2(1900, 300), Vector2(1800, 150)]),
	# South-west: collapsed rooftops, broken frames and fires.
	PackedVector2Array([Vector2(0, 1250), Vector2(180, 1230), Vector2(260, 1150), Vector2(480, 1150), Vector2(560, 1280),
		Vector2(720, 1200), Vector2(770, 1330), Vector2(950, 1380), Vector2(1080, 1390), Vector2(1200, 1330),
		Vector2(1410, 1330), Vector2(1410, 1520), Vector2(0, 1520)]),
	# South-east: billboard tower, power poles and rubble.
	PackedVector2Array([Vector2(1960, 1520), Vector2(1980, 1380), Vector2(2070, 1300), Vector2(2080, 1160),
		Vector2(2230, 1100), Vector2(2380, 1060), Vector2(2420, 900), Vector2(2540, 820), Vector2(2688, 760),
		Vector2(2688, 1520)]),
]

var cover: Array[Rect2] = [
	Rect2(735, 140, 180, 115),   # burnt car (north)
	Rect2(1010, 160, 180, 130),  # crate stack (north)
	Rect2(1225, 255, 55, 110),   # upright barricade
	Rect2(535, 515, 85, 80),     # barricade (west)
	Rect2(900, 510, 140, 95),    # barricade (center-west)
	Rect2(1750, 340, 140, 100),  # crates (north-east)
	Rect2(1670, 550, 220, 110),  # burnt car (east)
	Rect2(1785, 640, 135, 70),   # barricade beside the car
	Rect2(1160, 910, 90, 100),   # crate + barricade (center)
	Rect2(1275, 1010, 130, 65),  # barricade (center)
	Rect2(880, 1270, 200, 110),  # toppled barricade (south-west)
	Rect2(1950, 1095, 95, 165),  # crate stack (south-east)
	Rect2(2195, 1080, 50, 80),   # crate (south-east)
]

var pits: Array[Rect2] = [
	Rect2(270, 800, 285, 295),   # west crater
	Rect2(2230, 400, 400, 275),  # east collapse
]

var barrels: Array[Vector2] = [
	Vector2(512, 570), Vector2(878, 545), Vector2(985, 240), Vector2(1805, 255),
	Vector2(1257, 1043), Vector2(1934, 1210), Vector2(2179, 1135),
]

## Open spots (image px) for gameplay props that aren't painted into the map.
var repair_station := Vector2(1500, 1215)
var electric_panels: Array[Vector2] = [Vector2(700, 420), Vector2(1100, 1170), Vector2(2010, 860)]
var crates: Array[Vector2] = [Vector2(680, 300), Vector2(1450, 420), Vector2(2400, 760)]
