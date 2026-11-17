class_name SectorObjective
extends Node2D
## BONUS OBJECTIVE of a Campaign sector (Game.active_objective / Game.OBJECTIVES), added by ScenicArena. It
## starts START_DELAY seconds into the sector's 2nd wave and has TIME_LIMIT seconds (ending early if the
## sector's waves run out first):
##   WARP TOWERS      TOWERS warp towers (enemies/warp_tower.gd) rise far apart on open floor and keep sending
##                    Scrap Mite packs until they're destroyed. Destroy them all.
##   HOLD THE BEACON  a beacon ring lands on open floor away from the pilot; standing inside charges it
##                    (HOLD_TIME seconds in all - stepping out only pauses it).
##   DATA CACHES      CACHES data caches drop around the map; walk over each one (each pays a little XP).
## Done in time: OBJECTIVE COMPLETE - a free upgrade card, scrap and maybe a part crate (Game.objective_reward).
## Not done: OBJECTIVE FAILED and its targets fold away; nothing else is lost.
## The HUD draws the tracker (title / progress / time_left) and arrows to every target ("objective_markers").
## `-- --objective=towers|hold|caches` picks the first sector's (tests / captures; Game._roll_sectors).

signal finished(success: bool)

const START_DELAY := 2.5
const TIME_LIMIT := {&"towers": 110.0, &"hold": 95.0, &"caches": 80.0}
const TOWERS := 3
const CACHES := 4
const HOLD_TIME := 18.0
const HOLD_RADIUS := 170.0
const CACHE_XP := 0.08

var kind := &""
var arena: ScenicArena
var active := false
var done := false
var success := false
var _time_left := 0.0
var _hold := 0.0
var _targets: Array[Node2D] = []
var _total := 0
var _got := 0
var _beacon: Beacon


func _ready() -> void:
	add_to_group("sector_objective")
	if not Game.OBJECTIVES.has(kind):
		kind = &""
	if kind == &"" or arena == null or arena.zone == null:
		return
	arena.zone.wave_started.connect(func(i: int, _n: int) -> void:
		if i == 2 and not active and not done:
			get_tree().create_timer(START_DELAY, false).timeout.connect(start))


func info() -> Dictionary:
	return Game.OBJECTIVES.get(kind, {})


func title() -> String:
	return String(info().get("name", ""))


func color() -> Color:
	return info().get("color", Color.WHITE)


## 0..1 toward done.
func progress() -> float:
	if kind == &"hold":
		return clampf(_hold / HOLD_TIME, 0.0, 1.0)
	return float(_got) / maxf(_total, 1.0)


## "2 / 3" (towers, caches) or "64%" (beacon).
func progress_text() -> String:
	if kind == &"hold":
		return "%d%%" % floori(progress() * 100.0)
	return "%d / %d" % [_got, _total]


func time_left() -> float:
	return _time_left


## Starts it (the 2nd wave's begun): places the targets, announces it.
func start() -> void:
	if active or done or not is_inside_tree() or arena.zone == null or not arena.zone.is_running:
		return
	active = true
	_time_left = float(TIME_LIMIT.get(kind, 90.0))
	match kind:
		&"towers":
			for p in _spread_points(TOWERS, 520.0):
				var t: WarpTower = WarpTower.new()
				t.position = p
				t.world = arena.world
				t.hp_scale = arena.zone.hp_mult * Game.diff("hp") * (1.0 + arena.zone.hp_ramp * maxi(arena.zone.wave - 1, 0))
				t.damage_mult = arena.zone.wave_damage_mult()
				t.died.connect(_on_target_done.unbind(1))
				arena.world.add_child(t)
				_targets.append(t)
		&"caches":
			for p in _spread_points(CACHES, 380.0):
				var c := DataCache.new()
				c.position = p
				c.color = color()
				c.collected.connect(_on_target_done)
				arena.world.add_child(c)
				_targets.append(c)
		&"hold":
			var p: Array[Vector2] = _spread_points(1, 520.0)
			_beacon = Beacon.new()
			_beacon.position = p[0] if not p.is_empty() else arena.player_spawn
			_beacon.radius = HOLD_RADIUS
			_beacon.color = color()
			arena.world.add_child(_beacon)
			_targets.append(_beacon)
	_total = _targets.size()
	arena.banner.emit("BONUS: %s" % title(), color())
	arena.objective_changed.emit(String(info().get("desc", "")))
	Sfx.play(&"alarm", -12.0, 0.0)


func _process(delta: float) -> void:
	if not active or get_tree().paused:
		return
	_time_left -= delta
	if kind == &"hold" and is_instance_valid(_beacon):
		var mech := get_tree().get_first_node_in_group("player") as Mech
		var inside := mech != null and not mech.dead and mech.global_position.distance_to(_beacon.global_position) <= HOLD_RADIUS
		_beacon.charging = inside
		if inside:
			_hold += delta
		_beacon.progress = progress()
		if _hold >= HOLD_TIME:
			_complete()
			return
	if _time_left <= 0.0:
		_fail()


func _on_target_done() -> void:
	if not active:
		return
	_got += 1
	if kind == &"caches":
		var mech := get_tree().get_first_node_in_group("player") as Mech
		if mech:
			Upgrades.supply_xp(mech.global_position, CACHE_XP)
	if _got >= _total:
		_complete()


func _complete() -> void:
	if done:
		return
	active = false
	done = true
	success = true
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if is_instance_valid(_beacon):
		_beacon.finish(true)
	arena.banner.emit("OBJECTIVE COMPLETE", Color(0.45, 1.0, 0.6))
	arena.objective_changed.emit("Bonus objective complete - free upgrade incoming")
	Sfx.play(&"levelup", -2.0, 0.0)
	if mech:
		Combat.shockwave(mech.global_position, 200.0, color(), 0.5)
		Game.objective_reward(mech.global_position)
	finished.emit(true)


func _fail() -> void:
	if done:
		return
	active = false
	done = true
	arena.banner.emit("OBJECTIVE FAILED", Color(0.7, 0.72, 0.8))
	_clear_targets()
	finished.emit(false)


## The sector's waves are over (ScenicArena): an objective still running fails, and its targets fold away.
func end_sector() -> void:
	if active:
		_fail()
	else:
		_clear_targets()


func _clear_targets() -> void:
	for t in _targets:
		if not is_instance_valid(t):
			continue
		Combat.shockwave(t.global_position, 70.0, Color(0.7, 0.75, 0.85), 0.3)
		if t is Beacon:
			(t as Beacon).finish(false)
		else:
			if t is Enemy:
				(t as Enemy).dead = true  # (folds away: no wreck, no reward)
			t.queue_free()
	_targets.clear()


## `n` open floor points far from the pilot and from each other (farthest-point picks from the arena's spawn
## points), at least `min_far` from the mech when the map allows.
func _spread_points(n: int, min_far: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var pts: PackedVector2Array = arena.zone.spawn_points
	if pts.is_empty():
		return out
	var mech := get_tree().get_first_node_in_group("player") as Node2D
	var me: Vector2 = mech.global_position if mech else arena.player_spawn
	var pool: Array[Vector2] = []
	for p in pts:
		if p.distance_to(me) >= min_far and arena.is_open(p, 110.0):
			pool.append(p)
	if pool.size() < n:
		pool.assign(Array(pts))
	pool.shuffle()
	pool = pool.slice(0, 260)
	# First: a point a fair way off, then each next the one farthest from those picked.
	var first := pool[0]
	for p in pool:
		if absf(p.distance_to(me) - 700.0) < absf(first.distance_to(me) - 700.0):
			first = p
	out.append(first)
	while out.size() < n:
		var best := pool[0]
		var best_d := -1.0
		for p in pool:
			var d := INF
			for q in out:
				d = minf(d, p.distance_to(q))
			# (don't wander off to the far corners: stay within reach of the pilot)
			d -= maxf(p.distance_to(me) - 1300.0, 0.0) * 0.6
			if d > best_d:
				best_d = d
				best = p
		out.append(best)
	return out


## HOLD THE BEACON's ring: a pad that charges while the pilot stands in it (progress arc, rising light), the
## painted beacon pylon (assets/hq/objectives/beacon.png) in the middle.
class Beacon:
	extends Node2D
	const ART := preload("res://assets/hq/objectives/beacon.png")
	## How wide the pylon is drawn (world px).
	const ART_SIZE := 92.0
	var radius := 170.0
	var color := Color(0.5, 1.0, 0.55)
	var progress := 0.0
	var charging := false
	var _t := 0.0
	var _fade := 1.0
	var _ending := false

	func _ready() -> void:
		add_to_group("objective_markers")
		z_index = -6
		Combat.shockwave(global_position, radius, color, 0.6)

	func finish(ok: bool) -> void:
		if _ending:
			return
		_ending = true
		if ok:
			Combat.shockwave(global_position, radius * 1.3, color, 0.6)
			Combat.burst(global_position, color, 600.0, 1.8)
		var tw := create_tween()
		tw.tween_property(self, "_fade", 0.0, 0.8)
		tw.tween_callback(queue_free)

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pulse := 0.5 + 0.5 * sin(_t * (8.0 if charging else 3.0))
		var a := _fade
		draw_circle(Vector2.ZERO, radius, Color(color, (0.08 + 0.06 * pulse + (0.08 if charging else 0.0)) * a))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, 0.5 * a), 3.0, true)
		# Dashed inner ring turning slowly.
		for i in 12:
			var a0 := _t * 0.4 + i * TAU / 12.0
			draw_arc(Vector2.ZERO, radius - 16.0, a0, a0 + 0.3, 6, Color(color, 0.45 * a), 2.0, true)
		# Progress arc.
		if progress > 0.0:
			draw_arc(Vector2.ZERO, radius + 8.0, -PI / 2, -PI / 2 + TAU * progress, 64, Color(color.lightened(0.3), 0.95 * a),
				7.0, true)
		# The beacon in the middle: the painted pylon on a contact shadow, its crystal glowing (brighter and
		# quicker while charging) and a soft column of light rising off it (taller while charging).
		var half := ART_SIZE * 0.5
		draw_texture_rect(GroundFx.GLOW, Rect2(-half * 1.25, -half * 1.0, ART_SIZE * 1.25, ART_SIZE * 1.1), false,
			Color(0, 0, 0, 0.45 * a))
		draw_texture_rect(ART, Rect2(-half, -half, ART_SIZE, ART_SIZE), false, Color(1, 1, 1, a))
		var glow := 0.22 + 0.3 * pulse + (0.25 if charging else 0.0)
		draw_texture_rect(GroundFx.GLOW, Rect2(-half * 0.6, -half * 0.6, half * 1.2, half * 1.2), false,
			Color(color.lightened(0.45), glow * a))
		var h := (150.0 if charging else 80.0) * (0.8 + 0.2 * pulse)
		draw_texture_rect(GroundFx.GLOW, Rect2(-14.0, -h, 28.0, h + 10.0), false, Color(color.lightened(0.3), 0.35 * glow * a))
		if charging:
			var f := UiFont.BOLD
			var p := Vector2(-80, radius + 34.0)
			draw_string_outline(f, p, "CHARGING", HORIZONTAL_ALIGNMENT_CENTER, 160, 16, 4, Color(0, 0, 0, 0.75 * a))
			draw_string(f, p, "CHARGING", HORIZONTAL_ALIGNMENT_CENTER, 160, 16, Color(color.lightened(0.3), 0.9 * a))


## DATA CACHES' pickup: a glowing data core with a blinking antenna; walk over it to grab it.
class DataCache:
	extends Node2D
	signal collected
	const RANGE := 52.0
	var color := Color(1.0, 0.8, 0.35)
	var _t := 0.0
	var _taken := false

	func _ready() -> void:
		add_to_group("objective_markers")
		z_index = 1
		_t = randf() * 3.0
		Combat.shockwave(global_position, 80.0, color, 0.4)

	func _process(delta: float) -> void:
		_t += delta
		var mech := get_tree().get_first_node_in_group("player") as Mech
		if not _taken and mech and not mech.dead and mech.global_position.distance_to(global_position) < RANGE + mech.hit_radius:
			_taken = true
			Combat.shockwave(global_position, 110.0, color, 0.4)
			Combat.burst(global_position, color, 420.0, 1.3)
			Sfx.play(&"pickup", -3.0, 0.0)
			collected.emit()
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var bob := sin(_t * 3.0) * 4.0
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_texture_rect(GroundFx.GLOW, Rect2(-34, -14, 68, 34), false, Color(0, 0, 0, 0.4))
		draw_texture_rect(GroundFx.GLOW, Rect2(-48, -60 + bob, 96, 96), false, Color(color, 0.3 + 0.25 * pulse))
		var c := Vector2(0, -18 + bob)
		var d := PackedVector2Array([c + Vector2(0, -18), c + Vector2(14, 0), c + Vector2(0, 18), c + Vector2(-14, 0)])
		draw_colored_polygon(d, Color(0.12, 0.1, 0.06))
		var rim := d.duplicate()
		rim.append(d[0])
		draw_polyline(rim, color, 2.5, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(7, 0), c + Vector2(0, 9), c + Vector2(-7, 0)]),
			Color(color.lightened(0.4), 0.7 + 0.3 * pulse))
		draw_line(c + Vector2(0, -18), c + Vector2(0, -34), Color(0.6, 0.6, 0.65), 2.0)
		draw_circle(c + Vector2(0, -36), 3.0, Color(1.0, 0.3, 0.25) if fmod(_t, 1.0) < 0.5 else Color(0.4, 0.15, 0.1))
