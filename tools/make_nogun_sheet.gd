extends SceneTree
## Builds assets/sprites/gundam_sheet_nogun.png: the mech sprite sheet with the painted rifle removed
## (used while any weapon other than the Beam Rifle is equipped - the real weapon is drawn in the fist).
##   godot --headless --path . --script res://tools/make_nogun_sheet.gd
## Per 256 x 256 frame: the rifle is the thin column sticking up out of the right fist. Scanning down
## the right half, every row that is still thin (<= RIFLE_MAX_W opaque px) is rifle and gets cleared;
## the first wide row is the fist / shoulder, where it stops.

const SRC := "res://assets/sprites/gundam_sheet.png"
const DST := "res://assets/sprites/gundam_sheet_nogun.png"
const FRAME := 256
const X_FROM := 150
const RIFLE_MAX_W := 25
const ALPHA := 0.1


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	sheet.convert(Image.FORMAT_RGBA8)
	for fy in sheet.get_height() / FRAME:
		for fx in sheet.get_width() / FRAME:
			var o := Vector2i(fx * FRAME, fy * FRAME)
			var cut := _clean(sheet, o)
			if cut >= 0:
				print("frame %d,%d rifle cut above y=%d" % [fx, fy, cut])
	sheet.save_png(ProjectSettings.globalize_path(DST))
	quit()


## Clears the rifle in the frame at `o`. Returns the row where the fist starts (-1 = empty frame).
func _clean(sheet: Image, o: Vector2i) -> int:
	var top := -1
	for y in FRAME:
		if _row_width(sheet, o, y) > 0:
			top = y
			break
	if top < 0:
		return -1
	var fist := top
	for y in range(top, FRAME):
		var w := _row_width(sheet, o, y)
		if w > RIFLE_MAX_W:
			fist = y
			break
		for x in range(X_FROM, FRAME):
			sheet.set_pixel(o.x + x, o.y + y, Color(0, 0, 0, 0))
	# Also the faint (near-transparent) tip pixels above the first solid row.
	for y in top:
		for x in range(X_FROM, FRAME):
			sheet.set_pixel(o.x + x, o.y + y, Color(0, 0, 0, 0))
	return fist


func _row_width(sheet: Image, o: Vector2i, y: int) -> int:
	var n := 0
	for x in range(X_FROM, FRAME):
		if sheet.get_pixel(o.x + x, o.y + y).a > ALPHA:
			n += 1
	return n
