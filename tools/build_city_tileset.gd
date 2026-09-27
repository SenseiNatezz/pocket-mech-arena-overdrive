extends SceneTree
## Builds res://environment/tiles/city_tileset.tres from assets/tiles/city_tiles.png
## (run gen_city_tiles.gd first, then import, then this):
##   godot --headless --path . --script res://tools/build_city_tileset.gd
## Solid tiles get a full collision box on physics layer 0 (world layer 1 "walls").

const TEX := "res://assets/tiles/city_tiles.png"
const OUT := "res://environment/tiles/city_tileset.tres"


func _init() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(64, 64)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var src := TileSetAtlasSource.new()
	src.texture = load(TEX)
	src.texture_region_size = Vector2i(64, 64)
	ts.add_source(src, 0)

	var full := PackedVector2Array([Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)])
	for y in 8:
		for x in 8:
			var c := Vector2i(x, y)
			if y == 5 and (x == 3 or x == 5):
				continue  # right halves of the 2-wide cars
			var size := Vector2i(2, 1) if y == 5 and (x == 2 or x == 4) else Vector2i.ONE
			src.create_tile(c, size)
			var solid := y in [2, 3, 4] or (y == 5)
			if y == 2 and x > 5 or y == 3 and x > 5 or y == 4 and x > 4:
				solid = false
			if not solid:
				continue
			var td := src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			var pts := full
			if size.x == 2:
				pts = PackedVector2Array([Vector2(-58, -22), Vector2(58, -22), Vector2(58, 22), Vector2(-58, 22)])
			elif c == Vector2i(6, 5):
				pts = PackedVector2Array([Vector2(-28, -14), Vector2(28, -14), Vector2(28, 14), Vector2(-28, 14)])
			elif c == Vector2i(7, 5):
				pts = PackedVector2Array([Vector2(-24, -18), Vector2(24, -18), Vector2(24, 18), Vector2(-24, 18)])
			td.set_collision_polygon_points(0, 0, pts)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://environment/tiles"))
	var err := ResourceSaver.save(ts, OUT)
	print("saved %s (%s)" % [OUT, error_string(err)])
	quit()
