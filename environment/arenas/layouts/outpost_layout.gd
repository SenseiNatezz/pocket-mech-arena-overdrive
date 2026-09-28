extends RefCounted
## ALIEN OUTPOST (arena 1): layout over the painted Higgsfield ground plate (assets/hq/outpost_ground.jpg,
## 3312 x 2480) plus the user's outpost asset set placed on top as solid structures.
## Coordinates are ORIGINAL image pixels. See map_a_layout.gd for the common fields.

var image_size := Vector2(3312, 2480)
var door_x := 1656.0   # top-center road -> boss gate
var gap_x := 1656.0    # bottom-center road -> start pad
## Barrels here are real props (not painted into the ground plate).
var barrels_painted := false

## Rock and crystal border of the plate (impassable), leaving the two roads open.
var solids: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(0, 0), Vector2(1450, 0), Vector2(1450, 165), Vector2(390, 165), Vector2(205, 330), Vector2(0, 330)]),
	PackedVector2Array([Vector2(1870, 0), Vector2(3312, 0), Vector2(3312, 330), Vector2(3115, 330), Vector2(2950, 170), Vector2(1870, 170)]),
	PackedVector2Array([Vector2(0, 330), Vector2(205, 330), Vector2(205, 2150), Vector2(0, 2150)]),
	PackedVector2Array([Vector2(3115, 330), Vector2(3312, 330), Vector2(3312, 2150), Vector2(3115, 2150)]),
	PackedVector2Array([Vector2(0, 2150), Vector2(205, 2150), Vector2(390, 2305), Vector2(1450, 2305), Vector2(1450, 2480), Vector2(0, 2480)]),
	PackedVector2Array([Vector2(1865, 2305), Vector2(2950, 2305), Vector2(3115, 2150), Vector2(3312, 2150), Vector2(3312, 2480), Vector2(1865, 2480)]),
]
var cover: Array[Rect2] = []

## The two painted chasms (too wide to boost across - go around).
var pits: Array[Rect2] = [Rect2(660, 790, 380, 370), Rect2(2270, 1600, 480, 380)]

## Structures from the outpost asset set: texture name, visual center, drawn width, footprint.
const FP_HANGAR := Rect2(0.06, 0.28, 0.88, 0.62)
const FP_DOME := Rect2(0.08, 0.3, 0.84, 0.62)
const FP_RADAR := Rect2(0.12, 0.62, 0.76, 0.36)
const FP_SILOS := Rect2(0.08, 0.22, 0.84, 0.66)
const FP_CRYSTAL := Rect2(0.15, 0.4, 0.7, 0.55)
## Diagonal barricade wall: ground band polygon in texture px (700 x 359 sprite).
var wall_poly := PackedVector2Array([Vector2(7, 103), Vector2(701, 300), Vector2(701, 351), Vector2(7, 156)])

var structures: Array[Dictionary] = [
	{"tex": "hangar", "at": Vector2(760, 400), "w": 520, "fp": FP_HANGAR},
	{"tex": "hangar", "at": Vector2(720, 1950), "w": 480, "fp": FP_HANGAR, "flip": true},
	{"tex": "dome", "at": Vector2(2920, 1330), "w": 420, "fp": FP_DOME},
	{"tex": "radar", "at": Vector2(330, 470), "w": 200, "fp": FP_RADAR},
	{"tex": "radar", "at": Vector2(2990, 2010), "w": 190, "fp": FP_RADAR, "flip": true},
	{"tex": "silos", "at": Vector2(2440, 1330), "w": 360, "fp": FP_SILOS, "hp": 350.0, "explosive": true},
	{"tex": "silos", "at": Vector2(420, 1250), "w": 300, "fp": FP_SILOS, "hp": 300.0, "explosive": true, "flip": true},
	{"tex": "crystals", "at": Vector2(470, 800), "w": 170, "fp": FP_CRYSTAL},
	{"tex": "crystals", "at": Vector2(1330, 1800), "w": 180, "fp": FP_CRYSTAL, "flip": true},
	{"tex": "crystals", "at": Vector2(3010, 820), "w": 170, "fp": FP_CRYSTAL},
	{"tex": "crystals", "at": Vector2(2330, 320), "w": 170, "fp": FP_CRYSTAL, "flip": true},
	{"tex": "crystals", "at": Vector2(330, 2080), "w": 160, "fp": FP_CRYSTAL},
	{"tex": "wall", "at": Vector2(1020, 1560), "w": 520, "poly": true},
	{"tex": "wall", "at": Vector2(2080, 1150), "w": 400, "poly": true, "flip": true},
]
## Dormant defense turrets that wake up when the fight starts.
var turrets: Array[Vector2] = [Vector2(1250, 560), Vector2(2070, 560), Vector2(1260, 2020), Vector2(2070, 2030)]
## Scorched-crater ground decals.
var decals: Array[Vector2] = [Vector2(1150, 1280), Vector2(1700, 1760), Vector2(1520, 460)]

var barrels: Array[Vector2] = [Vector2(2200, 1560), Vector2(620, 1450), Vector2(1880, 640), Vector2(1300, 1180)]
var destructible_cover: Array[Vector2] = [Vector2(1250, 1300), Vector2(2050, 1650), Vector2(1650, 650),
	Vector2(1650, 1700), Vector2(900, 1300)]
var repair_station := Vector2(1656, 1950)
var electric_panels: Array[Vector2] = [Vector2(1100, 1850), Vector2(2800, 1700), Vector2(1250, 320)]
var crates: Array[Vector2] = [Vector2(1150, 1050), Vector2(2600, 2150), Vector2(1880, 1500)]
