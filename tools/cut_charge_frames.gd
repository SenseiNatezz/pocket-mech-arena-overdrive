extends SceneTree
## Cuts the 6 beam charge-up frames out of assets/hq/beam/beam_charge_sheet.png into separate
## textures (charge_0..5.png) with a soft radial fade, so the glow never shows a square cell edge.
##   godot --headless --path . --script res://tools/cut_charge_frames.gd

const CENTERS := [85, 270, 460, 660, 875, 1078]
const CY := 430
const CELL := 220


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path("res://assets/hq/beam/beam_charge_sheet.png"))
	sheet.convert(Image.FORMAT_RGBA8)
	for i in CENTERS.size():
		var img := Image.create_empty(CELL, CELL, false, Image.FORMAT_RGBA8)
		var half := CELL / 2.0
		for y in CELL:
			for x in CELL:
				var sx: int = CENTERS[i] - CELL / 2 + x
				var sy: int = CY - CELL / 2 + y
				if sx < 0 or sy < 0 or sx >= sheet.get_width() or sy >= sheet.get_height():
					continue
				var c := sheet.get_pixel(sx, sy)
				var d := Vector2(x - half, y - half).length() / half
				var fade := clampf((1.0 - d) / 0.35, 0.0, 1.0)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * fade))
		img.save_png(ProjectSettings.globalize_path("res://assets/hq/beam/charge_%d.png" % i))
	print("cut ", CENTERS.size(), " frames")
	quit()
