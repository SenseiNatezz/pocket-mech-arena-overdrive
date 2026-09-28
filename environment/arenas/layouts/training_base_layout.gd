extends RefCounted
## TRAINING BASE (Weapon Range): gameplay traced over the straight-down painted night-time Higgsfield map
## (assets/hq/training_base.png, 3312 x 2480, top-down like the level maps). Coordinates are ORIGINAL
## image pixels (traced at half size); the range draws it at gun_range.gd MAP_SCALE.
##   walkable      - the concrete deck inside the hangars (top), containers (left / bottom) and target
##                   walls (right)
##   dividers      - the 5 glowing lane dividers as [left end, right end] along their centre line
##   obstacles     - built from the dividers (solid rects)
##   occluders     - none (top-down)
##   lane_targets  - one target drone near the far end of each of the 4 firing lanes (top lane first)
##   cluster       - a tight group of drones on the open deck (splash / melee practice)

var image_size := Vector2(3312, 2480)

var walkable := _x2(PackedVector2Array([
	Vector2(285, 255), Vector2(1400, 255), Vector2(1440, 300), Vector2(1440, 1000), Vector2(350, 1005),
	Vector2(345, 830), Vector2(285, 800),
]))

## Lane dividers as [left end, right end] along their centre line.
var dividers := [
	[Vector2(1930, 696), Vector2(2880, 696)],
	[Vector2(1930, 948), Vector2(2880, 948)],
	[Vector2(1930, 1204), Vector2(2880, 1204)],
	[Vector2(1920, 1480), Vector2(2880, 1480)],
	[Vector2(1930, 1736), Vector2(2880, 1736)],
]

var obstacles: Array[PackedVector2Array] = []
var occluders: Array[PackedVector2Array] = []

## The mech starts on the landing circle (this is the world origin).
var spawn := Vector2(1190, 1390)
var repair_station := Vector2(760, 1000)
var lane_targets: Array[Vector2] = []
var cluster: Array[Vector2] = [Vector2(1200, 780), Vector2(1300, 730), Vector2(1100, 730), Vector2(1260, 860),
	Vector2(1140, 860)]


func _init() -> void:
	for d in dividers:
		var a: Vector2 = d[0]
		var b: Vector2 = d[1]
		obstacles.append(PackedVector2Array([a + Vector2(0, -18), b + Vector2(0, -18), b + Vector2(0, 18),
			a + Vector2(0, 18)]))
	# Drones sit mid-lane, a little way in front of the target wall.
	for i in dividers.size() - 1:
		var top: Array = dividers[i]
		var bottom: Array = dividers[i + 1]
		lane_targets.append((top[1].lerp(top[0], 0.18) + bottom[1].lerp(bottom[0], 0.18)) / 2.0)


static func _x2(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p * 2.0)
	return out
