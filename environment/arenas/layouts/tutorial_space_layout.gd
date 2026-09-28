extends RefCounted
## TUTORIAL SPACE DECK: gameplay traced over the straight-down painted Higgsfield map of a mech training
## deck on a space station above Earth (assets/hq/tutorial_space.png, 3312 x 2480, top-down like the
## level maps). Coordinates are ORIGINAL image pixels (traced at half size).
##   walkable   - the landing deck inside its hazard-striped edge (hangars at the top, cargo, fuel tanks and
##                machinery around the other sides, space beyond); the bottom-right cargo stack is cut out
##   obstacles  - none on the deck itself
##   occluders  - none (top-down)

var image_size := Vector2(3312, 2480)

var walkable := _x2(PackedVector2Array([
	Vector2(385, 300), Vector2(1335, 300), Vector2(1335, 950), Vector2(1130, 955), Vector2(1125, 1045),
	Vector2(700, 1045), Vector2(390, 1040),
]))

var obstacles: Array[PackedVector2Array] = []
var occluders: Array[PackedVector2Array] = []

## The mech starts on the launch pad (this is the world origin).
var spawn := Vector2(1660, 1340)
var repair_station := Vector2(940, 1900)


static func _x2(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * 2.0)
	return out
