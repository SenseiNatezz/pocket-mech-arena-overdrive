extends SceneTree
## Puts the front turnaround view on a plain light studio background (1080x1080) as the start/end
## frame for the Higgsfield turntable video.

func _init() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path("res://assets/hq/raw/turnaround/front.png"))
	src.convert(Image.FORMAT_RGBA8)
	var used := src.get_used_rect()
	var part := src.get_region(used)
	var k := 820.0 / used.size.y
	part.resize(roundi(used.size.x * k), 820, Image.INTERPOLATE_LANCZOS)
	var bg := Image.create_empty(1080, 1080, false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.86, 0.87, 0.89))
	bg.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i((1080 - part.get_width()) / 2, 1080 - 820 - 110))
	bg.save_png(ProjectSettings.globalize_path("res://assets/hq/raw/turnaround/turntable_start.png"))
	print("ok")
	quit()
