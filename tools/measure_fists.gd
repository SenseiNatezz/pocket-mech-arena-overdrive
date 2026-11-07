extends SceneTree
## Prints HeldWeapon's FIST and RIFLE_TIP tables, measured from the painted Beam Rifle in
## assets/sprites/gundam_sheet.png (run again if the mech sheet changes, then paste the output into
## player/weapons/held_weapon.gd):
##   godot --headless --path . --script res://tools/measure_fists.gd
## Per 256 x 256 frame the rifle is the thin column sticking up out of the right fist (the same scan as
## tools/make_nogun_sheet.gd: in the right half every row that is still thin is rifle, the first wide row
## is the fist). A line fitted through the row centres gives the rifle's axis. FIST = where the rifle
## enters the fist, moved FIST_DEPTH px back along the axis (the middle of the fist, where a held
## weapon's handle goes); RIFLE_TIP = the rifle's top row (the barrel tip, where the shots leave).

const SRC := "res://assets/sprites/gundam_sheet.png"
const FRAME := 256
const X_FROM := 150
const RIFLE_MAX_W := 25
const ALPHA := 0.5
const FIST_DEPTH := 6.0
## animation -> [sheet row, frame count] (assets/sprites/gundam_frames.tres)
const ANIMS := {"idle": [0, 8], "boost": [1, 6], "bank_left": [2, 6], "bank_right": [3, 6], "dash": [4, 6],
	"fire": [5, 4], "aim": [6, 6]}


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	sheet.convert(Image.FORMAT_RGBA8)
	var fist := "const FIST := {\n"
	var tip := "const RIFLE_TIP := {\n"
	for anim: String in ANIMS:
		var f_pts := PackedStringArray()
		var t_pts := PackedStringArray()
		for c in int(ANIMS[anim][1]):
			var r := _rifle(sheet, Vector2i(c * FRAME, int(ANIMS[anim][0]) * FRAME))
			f_pts.append(_v(r["fist"]))
			t_pts.append(_v(r["tip"]))
		fist += "\t&\"%s\": [%s],\n" % [anim, ", ".join(f_pts)]
		tip += "\t&\"%s\": [%s],\n" % [anim, ", ".join(t_pts)]
	print(fist + "}")
	print(tip + "}")
	quit()


func _rifle(sheet: Image, o: Vector2i) -> Dictionary:
	var xs: Array[float] = []
	var ys: Array[float] = []
	for y in FRAME:
		var n := 0
		var sx := 0.0
		for x in range(X_FROM, FRAME):
			if sheet.get_pixel(o.x + x, o.y + y).a > ALPHA:
				n += 1
				sx += x
		if n == 0:
			continue
		if n > RIFLE_MAX_W:
			break
		xs.append(sx / n)
		ys.append(y)
	# Least squares x = mx + b * (y - my) over the lower 70% of the rifle (its tip end is thin and faint).
	var from := int(xs.size() * 0.3)
	var my := 0.0
	var mx := 0.0
	for i in range(from, xs.size()):
		my += ys[i]
		mx += xs[i]
	my /= xs.size() - from
	mx /= xs.size() - from
	var num := 0.0
	var den := 0.0
	for i in range(from, xs.size()):
		num += (ys[i] - my) * (xs[i] - mx)
		den += (ys[i] - my) * (ys[i] - my)
	var b := num / den
	var base := Vector2(mx + b * (ys[-1] - my), ys[-1])
	var top := Vector2(mx + b * (ys[0] - my), ys[0])
	var up := (top - base).normalized()
	return {"fist": base - up * FIST_DEPTH, "tip": top}


static func _v(p: Vector2) -> String:
	return "Vector2(%.1f, %.1f)" % [p.x, p.y]
