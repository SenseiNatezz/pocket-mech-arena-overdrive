extends RefCounted
## JUNGLE MEGAFACTORY (level 2): gameplay traced over the painted 2.5D Higgsfield scene
## (assets/hq/env_jungle.jpg, 3312 x 2480). See arctic_layout.gd for what each list means.

var image_size := Vector2(3312, 2480)

var walkable := PackedVector2Array([
	Vector2(1300, 800), Vector2(1700, 715), Vector2(2200, 700), Vector2(2340, 700), Vector2(2380, 1240),
	Vector2(2440, 1320), Vector2(2940, 1920), Vector2(2400, 2180), Vector2(2080, 2400), Vector2(1700, 2420),
	Vector2(1420, 2260), Vector2(1250, 2330), Vector2(600, 2060), Vector2(480, 1700), Vector2(430, 1420),
	Vector2(700, 1260), Vector2(950, 1160), Vector2(1030, 1000),
])

var obstacles: Array[PackedVector2Array] = [
	# Broken concrete pylon (left).
	PackedVector2Array([Vector2(1040, 1200), Vector2(1320, 1170), Vector2(1340, 1360), Vector2(1060, 1380)]),
	# Central shattered pylon on its rubble base.
	PackedVector2Array([Vector2(1900, 1560), Vector2(2180, 1500), Vector2(2360, 1560), Vector2(2360, 1760),
		Vector2(2100, 1810), Vector2(1900, 1760)]),
]

var occluders: Array[PackedVector2Array] = [
	# Left pylon body.
	PackedVector2Array([Vector2(1020, 660), Vector2(1310, 640), Vector2(1350, 1200), Vector2(1030, 1220)]),
	# Central pylon body.
	PackedVector2Array([Vector2(1980, 980), Vector2(2330, 990), Vector2(2370, 1560), Vector2(1890, 1570),
		Vector2(1920, 1100)]),
	# Mossy pipe in the foreground (bottom-left).
	PackedVector2Array([Vector2(520, 2040), Vector2(900, 2150), Vector2(1300, 2270), Vector2(1450, 2480),
		Vector2(0, 2480), Vector2(0, 2000)]),
]

## Toxic gas vents on the painted floor grates.
var vents: Array[Vector2] = [Vector2(1950, 1885), Vector2(2400, 1390), Vector2(570, 1480)]
var vent_color := Color(0.45, 1.0, 0.35)
var spawn := Vector2(1150, 1900)
var boss_spawn := Vector2(1740, 1330)
var repair_station := Vector2(2000, 2150)
var barrels: Array[Vector2] = [Vector2(1500, 900), Vector2(2150, 900), Vector2(800, 1450), Vector2(2500, 1700)]
var crates: Array[Vector2] = [Vector2(1650, 1650), Vector2(1250, 1000), Vector2(2200, 1950)]
var destructible_cover: Array[Vector2] = [Vector2(1550, 1200), Vector2(1850, 1050), Vector2(1400, 1600),
	Vector2(1700, 1150), Vector2(900, 1750)]
