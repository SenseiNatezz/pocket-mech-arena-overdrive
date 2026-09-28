extends Node2D
## WEAPON RANGE (main menu "Weapon Range"; named gun_range internally): the night-time TRAINING BASE
## (painted Higgsfield map, assets/hq/training_base.png, traced in
## environment/arenas/layouts/training_base_layout.gd) with EVERY weapon usable, locked or not, plus
## live enemies and bosses on demand.
##   1-9, 0, - / mouse wheel / Tab (Shift+Tab back) / the weapon bar   switch weapon
##   Spawn panel (right)                                            drop in any enemy type or a boss
##                                                                  (one at a time); CLEAR removes all
## Map: open deck in the middle (the mech starts on the landing circle = world 0,0), 4 firing lanes
## on the right with a target drone at the end of each (Lane1-4, top lane first), a tight drone
## cluster on the open deck (Cluster1-5) and one more drone (Solo).
## The mech can't be destroyed here. Weapons are swapped in memory only (Game.range_restore keeps the
## equipped one for saving), and nothing here records waves, unlocks or clears.

const PANEL := preload("res://ui/gun_range_panel.gd")
const MAP := preload("res://assets/hq/training_base.png")
const LAYOUT := preload("res://environment/arenas/layouts/training_base_layout.gd")
## World pixels per painting pixel.
const MAP_SCALE := 1.5
## Where the extra "Solo" drone stands (painting pixels): open deck below the lanes.
const SOLO_SPOT := Vector2(1700, 1880)
## [scene name in res://enemies, display name]
const ENEMY_KINDS := [
	["chaser", "Scrap Hound"], ["shooter", "Scrap Gunner"], ["blade_striker", "Blade Striker"],
	["aegis_guardian", "Aegis Guardian"], ["lancer", "Lancer"], ["heavy_tank", "Heavy Tank"],
	# Endless-mode robots.
	["hornet", "Hornet"], ["coil", "Coil"], ["widow", "Widow"], ["cinder", "Cinder"], ["bastion", "Bastion"],
	["tidebreaker", "Tidebreaker"],
]
## [scene path under res://enemies, display name, accent]
const BOSS_KINDS := [
	["warden_boss", "Warden", Color(1.0, 0.25, 0.2)],
	["bosses/ronin_boss", "Ronin", Color(1.0, 0.45, 0.15)],
	["bosses/seraph_boss", "Seraph", Color(0.75, 0.35, 1.0)],
]
## Range bosses have less HP than in the campaign so every phase is quick to reach.
const BOSS_HP := 1800.0
const SPAWN_DISTANCE := 460.0

var panel: CanvasLayer
var _spawned: Array[Enemy] = []
var _boss: Enemy
var _layout: Object
var _open_points := PackedVector2Array()

@onready var mech: Mech = $Mech


func _ready() -> void:
	_layout = LAYOUT.new()
	_build_map()
	_place_props()
	var cam := mech.get_node("Camera2D") as Camera2D
	var top_left := map_to_world(Vector2.ZERO)
	var bottom_right := map_to_world(_layout.image_size)
	cam.limit_left = int(top_left.x)
	cam.limit_top = int(top_left.y)
	cam.limit_right = int(bottom_right.x)
	cam.limit_bottom = int(bottom_right.y)
	mech.global_position = Vector2.ZERO
	cam.reset_smoothing()
	panel = PANEL.new()
	panel.gun_range = self
	add_child(panel)
	select_weapon(Game.weapon, false)


func weapon_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for w in Game.WEAPONS:
		ids.append(w["id"])
	return ids


func select_weapon(id: StringName, announce := true) -> void:
	mech.weapon = id
	Game.weapon = id  # in memory only: upgrade cards read it; save() writes Game.range_restore
	mech._fire_cd = 0.0
	panel.refresh()
	if announce:
		var hud := get_node_or_null("HUD")
		if hud:
			hud.show_banner(String(Game.weapon_info(id)["name"]).to_upper(), Color(1.0, 0.85, 0.3))
		Sfx.play(&"select", -6.0, 0.0)


func cycle_weapon(step: int) -> void:
	var ids := weapon_ids()
	var i := ids.find(mech.weapon)
	select_weapon(ids[posmod(i + step, ids.size())])


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			_select_index(k - KEY_1)
		elif k == KEY_0:
			_select_index(9)
		elif k == KEY_MINUS:
			_select_index(10)
		elif k == KEY_TAB:
			cycle_weapon(-1 if event.shift_pressed else 1)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			cycle_weapon(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cycle_weapon(1)


func _select_index(i: int) -> void:
	var ids := weapon_ids()
	if i < ids.size():
		select_weapon(ids[i])


## Drops an enemy in (with the usual warp-in ring) a short way from the mech, on open deck.
func spawn_enemy(kind: String) -> void:
	var pos := _spawn_point(SPAWN_DISTANCE)
	var e: Enemy = load("res://enemies/%s.tscn" % kind).instantiate()
	e.position = pos
	add_child(e)
	_spawned.append(e)
	e.died.connect(func(x: Enemy) -> void: _spawned.erase(x))


## One boss at a time (spawning another replaces it). Drops in with the usual shockwave and gets the
## HUD's boss health bar.
func spawn_boss(path: String) -> void:
	if is_instance_valid(_boss):
		_boss.queue_free()
	var pos := _spawn_point(520.0, 140.0)
	var b: Enemy = load("res://enemies/%s.tscn" % path).instantiate()
	b.max_hp = BOSS_HP
	b.position = pos
	add_child(b)
	_boss = b
	Combat.explosion_fx(pos, 220.0, b.get("accent"))
	Combat.shake(0.6)
	var hud := get_node_or_null("HUD")
	if hud:
		hud.boss = b
		hud.show_banner(String(b.get("boss_name")), b.get("accent"))
	b.connect("defeated", func() -> void:
		if hud:
			hud.show_banner("BOSS DESTROYED", Color(0.4, 1.0, 0.6)))


## Removes every enemy (spawned ones, a boss and anything it summoned) and any Widow mines left lying
## around.
func clear_enemies() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and is_instance_valid(e):
			Combat.shockwave(e.global_position, 60.0, Color(0.5, 0.9, 1.0), 0.3)
			e.queue_free()
	for n in get_tree().get_nodes_in_group("damageable"):
		if n is Widow.Mine and is_instance_valid(n):
			n.queue_free()
	_spawned.clear()
	Combat.clear_enemy_bullets()


func _physics_process(_delta: float) -> void:
	# Practice mode: the mech can't be destroyed.
	if is_instance_valid(mech) and not mech.dead:
		mech.hp = mech.max_hp


# --- training base map ------------------------------------------------------------------------------

## Painting pixel -> world position. The landing circle (layout `spawn`) is the world origin.
func map_to_world(p: Vector2) -> Vector2:
	return (p - _layout.spawn) * MAP_SCALE


func _build_map() -> void:
	var art := Sprite2D.new()
	art.name = "MapArt"
	art.texture = MAP
	art.centered = false
	art.scale = Vector2.ONE * MAP_SCALE
	art.position = map_to_world(Vector2.ZERO)
	art.z_index = -10
	add_child(art)
	move_child(art, 0)
	# Deck edge: a closed solid outline so nothing leaves the walkable area.
	var edge := StaticBody2D.new()
	edge.name = "DeckEdge"
	edge.collision_layer = 1
	edge.collision_mask = 0
	var cp := CollisionPolygon2D.new()
	cp.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
	var outline := PackedVector2Array()
	for p in _layout.walkable:
		outline.append(map_to_world(p))
	var closed := outline.duplicate()
	closed.append(outline[0])
	cp.polygon = closed
	edge.add_child(cp)
	add_child(edge)
	# Lane dividers etc.: solid to movement AND bullets (layer 6), and enemies path around them.
	for poly: PackedVector2Array in _layout.obstacles:
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
		add_child(body)
	var nav := NavigationRegion2D.new()
	nav.name = "Navigation"
	add_child(nav)
	var np := NavigationPolygon.new()
	np.agent_radius = 30.0
	np.parsed_geometry_type = NavigationPolygon.PARSED_GEOMETRY_STATIC_COLLIDERS
	np.parsed_collision_mask = 32
	np.source_geometry_mode = NavigationPolygon.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	np.source_geometry_group_name = &"nav_obstacles"
	np.add_outline(outline)
	nav.navigation_polygon = np
	nav.bake_navigation_polygon(false)
	# Open deck points for spawning (checked once, reused).
	var y := 0.0
	while y < _layout.image_size.y:
		var x := 0.0
		while x < _layout.image_size.x:
			var wp := map_to_world(Vector2(x, y))
			if is_open(wp, 90.0):
				_open_points.append(wp)
			x += 60.0
		y += 60.0


## Target drones: one at the far end of each firing lane, a tight cluster on the open deck, one solo.
## (The drones' _ready already ran, so their respawn home is moved with them.)
func _place_props() -> void:
	var spots := {"Solo": map_to_world(SOLO_SPOT)}
	for i in _layout.lane_targets.size():
		spots["Lane%d" % (i + 1)] = map_to_world(_layout.lane_targets[i])
	for i in _layout.cluster.size():
		spots["Cluster%d" % (i + 1)] = map_to_world(_layout.cluster[i])
	for d in get_node("Dummies").get_children():
		if spots.has(String(d.name)):
			d.global_position = spots[String(d.name)]
			d.set("_home", d.global_position)
	var station := get_node_or_null("RepairStation") as Node2D
	if station:
		station.global_position = map_to_world(_layout.repair_station)


## Is this world point on open deck (inside the walkable outline, `margin` px clear of its edge and
## of every obstacle)?
func is_open(world_pos: Vector2, margin := 80.0) -> bool:
	var p: Vector2 = world_pos / MAP_SCALE + _layout.spawn
	var m := margin / MAP_SCALE
	var w: PackedVector2Array = _layout.walkable
	if not Geometry2D.is_point_in_polygon(p, w):
		return false
	for i in w.size():
		if Geometry2D.get_closest_point_to_segment(p, w[i], w[(i + 1) % w.size()]).distance_to(p) < m:
			return false
	for poly: PackedVector2Array in _layout.obstacles:
		if Geometry2D.is_point_in_polygon(p, poly):
			return false
		for i in poly.size():
			if Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()]).distance_to(p) < m:
				return false
	return true


## An open-deck spot about `distance` from the mech (the closest match if the ideal ring is blocked).
func _spawn_point(distance: float, margin := 90.0) -> Vector2:
	for i in 30:
		var p := mech.global_position + Vector2.from_angle(randf() * TAU) * distance
		if is_open(p, margin):
			return p
	var best := Vector2.ZERO
	var best_err := INF
	for p in _open_points:
		var err := absf(p.distance_to(mech.global_position) - distance)
		if err < best_err:
			best_err = err
			best = p
	return best
