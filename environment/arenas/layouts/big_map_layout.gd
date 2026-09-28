extends RefCounted
## Collision/gameplay layout traced over the big painted Higgsfield map (assets/hq/map_big.png).
## Coordinates are ORIGINAL image pixels (3312 x 2480); the arena scales them to the world.
## See map_a_layout.gd for what each list means.

var image_size := Vector2(3312, 2480)
var door_x := 1656.0   # top-center road -> boss gate
var gap_x := 1650.0    # bottom-center road -> start pad

var solids: Array[PackedVector2Array] = [
	# North-west: billboard building, fence and rubble slope down to the crater.
	PackedVector2Array([Vector2(0, 0), Vector2(430, 0), Vector2(440, 150), Vector2(560, 175), Vector2(720, 245),
		Vector2(770, 300), Vector2(640, 380), Vector2(560, 470), Vector2(520, 590), Vector2(530, 700),
		Vector2(400, 760), Vector2(0, 790)]),
	# North, left of the boss road: storefront, trees, fires.
	PackedVector2Array([Vector2(700, 0), Vector2(1390, 0), Vector2(1390, 190), Vector2(1300, 260), Vector2(1150, 250),
		Vector2(1100, 210), Vector2(1000, 215), Vector2(990, 100), Vector2(700, 100)]),
	# North-east: neon buildings, burning rubble and the billboard tower on the east side.
	PackedVector2Array([Vector2(1880, 0), Vector2(3312, 0), Vector2(3312, 990), Vector2(3150, 990), Vector2(3000, 900),
		Vector2(2960, 800), Vector2(2780, 600), Vector2(2560, 420), Vector2(2560, 300), Vector2(2300, 300),
		Vector2(2208, 250), Vector2(2050, 250), Vector2(1880, 130)]),
	# West and south-west: building, tree line, fires, crater rim and collapsed rooftops.
	PackedVector2Array([Vector2(0, 1060), Vector2(100, 1060), Vector2(170, 1080), Vector2(260, 1150), Vector2(270, 1350),
		Vector2(260, 1500), Vector2(440, 1510), Vector2(560, 1560), Vector2(580, 1700), Vector2(570, 1960),
		Vector2(820, 1990), Vector2(1000, 2050), Vector2(1150, 2050), Vector2(1300, 2150), Vector2(1320, 2480),
		Vector2(0, 2480)]),
	# South-east: fences, rubble, fires and the neon tower block.
	PackedVector2Array([Vector2(1960, 2480), Vector2(1950, 2120), Vector2(2100, 2060), Vector2(2208, 2050),
		Vector2(2450, 2050), Vector2(2640, 2020), Vector2(2770, 1800), Vector2(2770, 1650), Vector2(2980, 1560),
		Vector2(3060, 1400), Vector2(3080, 1270), Vector2(3312, 1250), Vector2(3312, 2480)]),
]

var cover: Array[Rect2] = [
	Rect2(790, 660, 210, 105), Rect2(1000, 258, 200, 100), Rect2(1219, 390, 220, 120), Rect2(1954, 480, 150, 110),
	Rect2(2210, 330, 110, 110), Rect2(1104, 710, 150, 116), Rect2(2114, 690, 95, 95), Rect2(2478, 530, 230, 130),
	Rect2(370, 826, 105, 140), Rect2(720, 966, 170, 110), Rect2(510, 1101, 230, 145), Rect2(760, 1306, 200, 135),
	Rect2(1234, 1356, 100, 80), Rect2(1399, 1511, 190, 130), Rect2(2144, 1056, 110, 120), Rect2(2948, 1046, 140, 110),
	Rect2(3200, 1000, 50, 60), Rect2(2290, 1446, 180, 140), Rect2(560, 1520, 100, 130), Rect2(1174, 1722, 150, 110),
	Rect2(2084, 1652, 80, 160), Rect2(2443, 1892, 210, 90), Rect2(60, 880, 100, 180),
]

var pits: Array[Rect2] = [
	Rect2(640, 390, 250, 270),   # north-west crater
	Rect2(2320, 830, 500, 320),  # east crater
	Rect2(590, 1715, 210, 190),  # south-west crater
]

var barrels: Array[Vector2] = [
	Vector2(810, 735), Vector2(1214, 320), Vector2(1236, 465), Vector2(2114, 505), Vector2(2192, 380),
	Vector2(1274, 790), Vector2(2256, 770), Vector2(705, 1001), Vector2(838, 1331), Vector2(1342, 1396),
	Vector2(1609, 1611), Vector2(2266, 1166), Vector2(3098, 1086), Vector2(2273, 1526), Vector2(1337, 1800),
	Vector2(2172, 1770),
]

## Extra DESTRUCTIBLE barricades (HQ sprite, breaks after a few hits) placed on open floor.
var destructible_cover: Array[Vector2] = [
	Vector2(1500, 900), Vector2(1830, 900), Vector2(1300, 1200), Vector2(2000, 1180), Vector2(1650, 1450),
	Vector2(1050, 1000), Vector2(2450, 1200), Vector2(1000, 1560),
]

var repair_station := Vector2(420, 960)
var electric_panels: Array[Vector2] = [Vector2(1900, 700), Vector2(1020, 1790), Vector2(2600, 1300)]
var crates: Array[Vector2] = [Vector2(1650, 500), Vector2(2000, 1300), Vector2(500, 1300)]
