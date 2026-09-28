extends RefCounted
## Collision traced over the painted Higgsfield boss arena (assets/hq/boss_arena.png, 3312 x 2480).
## Only `crop` is shown in game; its bottom band is the fortress wall with the gate, which lines up
## with the blast door at the top of the main map. Coordinates are ORIGINAL image pixels.

var image_size := Vector2(3312, 2480)
var crop := Rect2(400, 150, 2512, 2050)
var gate_x := 1650.0
## Inner edges of the gate opening in the south wall (the blast door fills exactly this gap).
var gate_left := 1380.0
var gate_right := 1926.0

var solids: Array[PackedVector2Array] = [
	# North wall, pipes and rubble in the corners.
	PackedVector2Array([Vector2(0, 0), Vector2(3312, 0), Vector2(3312, 520), Vector2(2790, 520), Vector2(2700, 450),
		Vector2(2420, 340), Vector2(1040, 340), Vector2(1030, 500), Vector2(530, 500), Vector2(0, 520)]),
	# West wall with billboards.
	PackedVector2Array([Vector2(0, 520), Vector2(530, 500), Vector2(560, 1000), Vector2(530, 2000), Vector2(0, 2000)]),
	# East wall and the tower by the south-east corner.
	PackedVector2Array([Vector2(3312, 520), Vector2(2790, 520), Vector2(2770, 1000), Vector2(2760, 1650),
		Vector2(2740, 1930), Vector2(2790, 2000), Vector2(3312, 2000)]),
	# South wall, west of the gate.
	PackedVector2Array([Vector2(0, 2000), Vector2(530, 2000), Vector2(560, 1930), Vector2(1380, 1930),
		Vector2(1380, 2200), Vector2(0, 2200)]),
	# South wall, east of the gate.
	PackedVector2Array([Vector2(1926, 1930), Vector2(2740, 1930), Vector2(2790, 2000), Vector2(3312, 2000),
		Vector2(3312, 2200), Vector2(1926, 2200)]),
]

## The four support pillars (solid; block bullets too).
var pillars: Array[Rect2] = [
	Rect2(1035, 580, 180, 270), Rect2(2085, 580, 180, 270),
	Rect2(995, 1340, 195, 290), Rect2(2110, 1340, 195, 290),
]
