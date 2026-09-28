extends RefCounted
## FROZEN OUTPOST (level 1): gameplay traced over the painted 2.5D Higgsfield scene
## (assets/hq/env_arctic.jpg, 3312 x 2480). Coordinates are ORIGINAL image pixels.
##   walkable   - outline of the floor the mech can roam (everything outside is scenery)
##   obstacles  - solid footprints inside the floor (where tall things touch the ground)
##   occluders  - the TALL parts of scenery that draw over the mech when it walks behind them
##   vents      - painted steam grates that erupt as hazards

var image_size := Vector2(3312, 2480)

var walkable := PackedVector2Array([
	Vector2(560, 560), Vector2(520, 700), Vector2(640, 840), Vector2(650, 1000), Vector2(560, 1240),
	Vector2(600, 1480), Vector2(700, 1700), Vector2(820, 1900), Vector2(950, 2050), Vector2(1250, 2130),
	Vector2(1650, 2120), Vector2(2130, 1850), Vector2(2550, 1560), Vector2(2680, 1420), Vector2(2690, 1180),
	Vector2(2670, 1000), Vector2(2600, 900), Vector2(2450, 860), Vector2(2300, 790), Vector2(2150, 670),
	Vector2(2050, 590), Vector2(1850, 570), Vector2(1660, 520), Vector2(1400, 505), Vector2(1100, 480),
	Vector2(880, 470), Vector2(860, 500),
])

var obstacles: Array[PackedVector2Array] = [
	# Ice spire cluster + frozen container at its base.
	PackedVector2Array([Vector2(890, 780), Vector2(1000, 720), Vector2(1250, 710), Vector2(1380, 770),
		Vector2(1390, 960), Vector2(1280, 1010), Vector2(1060, 1015), Vector2(900, 960)]),
	# Crates by the radar mound.
	PackedVector2Array([Vector2(2410, 875), Vector2(2530, 875), Vector2(2530, 945), Vector2(2410, 945)]),
	PackedVector2Array([Vector2(1900, 470), Vector2(2050, 470), Vector2(2050, 575), Vector2(1900, 575)]),
	# Lamp posts.
	PackedVector2Array([Vector2(600, 880), Vector2(650, 880), Vector2(650, 920), Vector2(600, 920)]),
	PackedVector2Array([Vector2(2040, 1870), Vector2(2080, 1870), Vector2(2080, 1905), Vector2(2040, 1905)]),
]

var occluders: Array[PackedVector2Array] = [
	# Tall ice spires (upper part, above their footprint).
	PackedVector2Array([Vector2(870, 1000), Vector2(880, 520), Vector2(990, 400), Vector2(1100, 330),
		Vector2(1180, 250), Vector2(1240, 300), Vector2(1300, 520), Vector2(1400, 760), Vector2(1400, 1000)]),
	# Yellow heating pipes along the lower-left edge (in front of the floor).
	PackedVector2Array([Vector2(230, 1560), Vector2(700, 1790), Vector2(1000, 2010), Vector2(1400, 2170),
		Vector2(1700, 2160), Vector2(1700, 2480), Vector2(0, 2480), Vector2(0, 1560)]),
]

var vents: Array[Vector2] = [Vector2(1690, 855), Vector2(2040, 1300), Vector2(1410, 1905)]
var spawn := Vector2(1150, 1850)
var boss_spawn := Vector2(1960, 1330)
var repair_station := Vector2(900, 1300)
var barrels: Array[Vector2] = [Vector2(1500, 640), Vector2(2350, 1150), Vector2(760, 1150), Vector2(1800, 1850)]
var crates: Array[Vector2] = [Vector2(1650, 1150), Vector2(2200, 1000), Vector2(1100, 1500)]
var destructible_cover: Array[Vector2] = [Vector2(1500, 1400), Vector2(2250, 1500), Vector2(1350, 1150),
	Vector2(1750, 1000), Vector2(1100, 1700)]
