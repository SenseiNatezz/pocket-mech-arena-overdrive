extends RefCounted
## Collision traced over the painted outpost command-core courtyard (assets/hq/outpost_boss.jpg,
## 3312 x 2480). `crop` is what's shown; its bottom band is the fortress wall with the gate, which
## lines up with the blast door at the top of the main map. Coordinates are ORIGINAL image pixels.

var image_size := Vector2(3312, 2480)
var crop := Rect2(0, 0, 3312, 2250)
var gate_x := 1655.0
var gate_left := 1440.0
var gate_right := 1871.0

var solids: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(0, 0), Vector2(3312, 0), Vector2(3312, 323), Vector2(0, 323)]),
	PackedVector2Array([Vector2(0, 323), Vector2(520, 323), Vector2(520, 2012), Vector2(0, 2012)]),
	PackedVector2Array([Vector2(2790, 323), Vector2(3312, 323), Vector2(3312, 2012), Vector2(2790, 2012)]),
	PackedVector2Array([Vector2(0, 2012), Vector2(1440, 2012), Vector2(1440, 2250), Vector2(0, 2250)]),
	PackedVector2Array([Vector2(1871, 2012), Vector2(3312, 2012), Vector2(3312, 2250), Vector2(1871, 2250)]),
]

## The four armored pillars (their bases).
var pillars: Array[Rect2] = [
	Rect2(955, 560, 310, 330), Rect2(2045, 560, 330, 330),
	Rect2(905, 1380, 345, 370), Rect2(2060, 1390, 335, 360),
]
