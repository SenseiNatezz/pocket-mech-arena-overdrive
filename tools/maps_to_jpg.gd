extends SceneTree
## Converts the painted map PNGs in assets/hq to high-quality JPEGs (much smaller downloads).
##   godot --headless --path . --script res://tools/maps_to_jpg.gd

func _init() -> void:
	for f in ["map_a", "map_big", "boss_arena", "title_bg", "customize_bg", "outpost_ground", "outpost_boss", "env_arctic", "env_jungle"]:
		var src := ProjectSettings.globalize_path("res://assets/hq/%s.png" % f)
		if not FileAccess.file_exists(src):
			continue
		var img := Image.load_from_file(src)
		img.convert(Image.FORMAT_RGB8)
		img.save_jpg(ProjectSettings.globalize_path("res://assets/hq/%s.jpg" % f), 0.92)
		DirAccess.remove_absolute(src)
		print("converted ", f)
	quit()
