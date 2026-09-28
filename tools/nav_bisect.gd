extends SceneTree
## Debug: which obstacles make a layout's navigation bake fail? Bakes the walkable outline with every
## obstacle (grown by the agent radius, as the arena does), then again leaving each one out.
##   godot --headless --path . --script res://tools/nav_bisect.gd -- res://environment/arenas/layouts/<x>.gd [scale]

func _bake(outline: PackedVector2Array, obstacles: Array, skip: int) -> int:
	var np := NavigationPolygon.new()
	np.agent_radius = 30.0
	var src := NavigationMeshSourceGeometryData2D.new()
	src.add_traversable_outline(outline)
	for i in obstacles.size():
		if i != skip:
			src.add_obstruction_outline(obstacles[i])
	NavigationServer2D.bake_from_source_geometry_data(np, src)
	return np.get_polygon_count()


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var k := float(a[1]) if a.size() > 1 else 1.5
	var L: Object = load(a[0]).new()
	var outline := PackedVector2Array()
	for p in L.walkable:
		outline.append(p * k)
	var obs: Array = []
	for poly: PackedVector2Array in L.obstacles:
		var s := PackedVector2Array()
		for p in poly:
			s.append(p * k)
		obs.append(s)
	var full := _bake(outline, obs, -1)
	print("all %d obstacles -> %d nav polygons" % [obs.size(), full])
	if full == 0:
		for i in obs.size():
			var n := _bake(outline, obs, i)
			if n > 0:
				print("  without obstacle %d -> %d polygons  (%s)" % [i, n, L.obstacles[i]])
	print("outline only -> %d" % _bake(outline, [], -1))
	quit()
