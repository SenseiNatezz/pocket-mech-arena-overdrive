class_name PaintedDeck
extends RefCounted
## One painted Higgsfield map as a playable floor, for scenes that aren't full arenas (tutorial...).
## The layout script gives `image_size`, `walkable`, `obstacles` and `spawn` in painting pixels; the
## layout's `spawn` becomes the world origin. build() adds to `parent`:
##   MapArt sprite, a solid deck edge (layer 1), solid obstacles (layer 6, also bullet cover), a baked
##   navmesh, and sets the camera limits to the painting.

var layout: Object
var scale := 1.0


func _init(layout_script: Script, map_scale := 1.0) -> void:
	layout = layout_script.new()
	scale = map_scale


func map_to_world(p: Vector2) -> Vector2:
	return (p - layout.spawn) * scale


func world_to_map(w: Vector2) -> Vector2:
	return w / scale + layout.spawn


func build(parent: Node, texture: Texture2D, cam: Camera2D) -> void:
	var art := Sprite2D.new()
	art.name = "MapArt"
	art.texture = texture
	art.centered = false
	art.scale = Vector2.ONE * scale
	art.position = map_to_world(Vector2.ZERO)
	art.z_index = -10
	parent.add_child(art)
	parent.move_child(art, 0)
	var outline := PackedVector2Array()
	for p in layout.walkable:
		outline.append(map_to_world(p))
	var edge := StaticBody2D.new()
	edge.name = "DeckEdge"
	edge.collision_layer = 1
	edge.collision_mask = 0
	var cp := CollisionPolygon2D.new()
	cp.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	var closed := outline.duplicate()
	closed.append(outline[0])
	cp.polygon = closed
	edge.add_child(cp)
	parent.add_child(edge)
	for poly: PackedVector2Array in layout.obstacles:
		var body := StaticBody2D.new()
		body.collision_layer = 32
		body.collision_mask = 0
		body.add_to_group("nav_obstacles")
		var c := CollisionPolygon2D.new()
		var w := PackedVector2Array()
		for p in poly:
			w.append(map_to_world(p))
		c.polygon = w
		body.add_child(c)
		parent.add_child(body)
	var nav := NavigationRegion2D.new()
	nav.name = "Navigation"
	parent.add_child(nav)
	var np := NavigationPolygon.new()
	np.agent_radius = 30.0
	np.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	np.parsed_collision_mask = 32
	np.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	np.source_geometry_group_name = &"nav_obstacles"
	np.add_outline(outline)
	nav.navigation_polygon = np
	nav.bake_navigation_polygon(false)
	if cam:
		var tl := map_to_world(Vector2.ZERO)
		var br := map_to_world(layout.image_size)
		cam.limit_left = int(tl.x)
		cam.limit_top = int(tl.y)
		cam.limit_right = int(br.x)
		cam.limit_bottom = int(br.y)


## Is this world point on open deck, `margin` px clear of the edge and every obstacle?
func is_open(world_pos: Vector2, margin := 80.0) -> bool:
	var p := world_to_map(world_pos)
	var m := margin / scale
	var w: PackedVector2Array = layout.walkable
	if not Geometry2D.is_point_in_polygon(p, w):
		return false
	for i in w.size():
		if Geometry2D.get_closest_point_to_segment(p, w[i], w[(i + 1) % w.size()]).distance_to(p) < m:
			return false
	for poly: PackedVector2Array in layout.obstacles:
		if Geometry2D.is_point_in_polygon(p, poly):
			return false
		for i in poly.size():
			if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) < m:
				return false
	return true


## `want` if it's open deck, else the nearest open point toward the origin (the deck's centre).
func clamp_to_deck(want: Vector2, margin := 120.0) -> Vector2:
	if is_open(want, margin):
		return want
	for i in range(1, 21):
		var p := want.lerp(Vector2.ZERO, i / 20.0)
		if is_open(p, margin):
			return p
	return Vector2.ZERO
