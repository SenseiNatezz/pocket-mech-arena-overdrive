extends Node
## Playtest reporter (`-- --playtest-report`, usually with --autoplay): logs a line every few seconds
## (wave, level, HP, kills, enemies, bullets, XP shards, node count, script cost per frame) and a
## summary when the run ends - the mech dies, the arena is cleared, or --playtest-time=S runs out.
## Used to hunt bugs, leaks and balance problems across modes / weapons / difficulties.

const EVERY := 5.0

var _t := 0.0
var _next := EVERY
var _limit := 240.0
var _max_nodes := 0
var _max_enemies := 0
var _max_bullets := 0
var _max_phys_ms := 0.0
var _phys_sum := 0.0
var _phys_n := 0
var _nodes_start := 0
var _ended := false
var _deaths := 0
var _spikes := 0
var _stall_wave := -1
var _stall_t := 0.0
var _stall_logged := false
var mech: Mech


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--playtest-time="):
			_limit = a.trim_prefix("--playtest-time=").to_float()
	await get_tree().process_frame
	mech = get_tree().get_first_node_in_group("player") as Mech
	_nodes_start = get_tree().get_node_count()
	if mech:
		mech.died.connect(func() -> void: _deaths += 1)
	print("PLAYTEST START mode=%s weapon=%s difficulty=%s scene=%s" % [Game.mode, Game.weapon,
		Game.difficulty_name(), get_tree().current_scene.name])


func _process(delta: float) -> void:
	if _ended or mech == null:
		return
	if not get_tree().paused:
		_t += delta
	var phys := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var frame_ms := delta * 1000.0
	# Hitches: log when and what was happening (first few only).
	if (phys > 50.0 or frame_ms > 100.0) and _spikes < 12:
		_spikes += 1
		print("  HITCH t=%.1fs frame=%.0fms phys=%.0fms wave=%d enemies=%d boss=%s paused=%s" % [_t, frame_ms, phys, _wave(),
			_alive_enemies(), get_tree().get_first_node_in_group("boss") != null, get_tree().paused])
	_max_phys_ms = maxf(_max_phys_ms, phys)
	_phys_sum += phys
	_phys_n += 1
	var nodes := get_tree().get_node_count()
	var enemies := _alive_enemies()
	var bullets := _bullets()
	_max_nodes = maxi(_max_nodes, nodes)
	_max_enemies = maxi(_max_enemies, enemies)
	_max_bullets = maxi(_max_bullets, bullets)
	# Stuck-wave diagnostics: the same wave for 40 s with only a few enemies left.
	if _wave() != _stall_wave:
		_stall_wave = _wave()
		_stall_t = _t
	elif _t - _stall_t > 40.0 and enemies > 0 and enemies <= 3 and not _stall_logged:
		_stall_logged = true
		_log_stuck()
	if _t >= _next:
		_next += EVERY
		print("  t=%3ds wave=%2d lv=%2d hp=%3d/%3d kills=%3d enemies=%2d bullets=%3d shards=%2d nodes=%4d phys=%.1fms" % [
			int(_t), _wave(), Upgrades.level, ceili(mech.hp), roundi(mech.max_hp), Game.kills, enemies, bullets,
			get_tree().get_nodes_in_group("xp_orbs").size(), nodes, phys])
	var hud := get_tree().current_scene.get_node_or_null("HUD")
	var over: bool = hud != null and hud.get("_over_panel") != null and hud._over_panel.visible
	var won: bool = hud != null and hud.get("_win_panel") != null and hud._win_panel.visible
	if over or won or _t >= _limit:
		_end("DIED" if over else ("CLEARED" if won else "TIME"))


func _end(why: String) -> void:
	_ended = true
	print("PLAYTEST END %s  time=%ds wave=%d level=%d kills=%d hp=%d  upgrades=%s" % [why, int(_t), _wave(),
		Upgrades.level, Game.kills, ceili(mech.hp), str(Upgrades.stacks)])
	print("PLAYTEST PERF max_enemies=%d max_bullets=%d nodes %d->%d (max %d) phys avg=%.2fms max=%.2fms" % [
		_max_enemies, _max_bullets, _nodes_start, get_tree().get_node_count(), _max_nodes,
		_phys_sum / maxf(_phys_n, 1.0), _max_phys_ms])
	get_tree().quit(0)


func _wave() -> int:
	var arena := get_tree().get_first_node_in_group("arena")
	if arena and arena.get("zone"):
		return arena.zone.wave
	return 0


func _alive_enemies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.dead:
			n += 1
	return n


func _bullets() -> int:
	var n := 0
	var pool := get_tree().current_scene.get_node_or_null("Combat")
	if pool:
		for b in pool.get_children():
			if b is Bullet and b.active:
				n += 1
	return n


## Where are the last enemies of a stuck wave, and why can't they be reached?
func _log_stuck() -> void:
	var arena := get_tree().get_first_node_in_group("arena")
	var zone = arena.get("zone") if arena else null
	print("  STUCK wave=%d for %ds, mech at %s  paused=%s zone=%s spawn_points=%d choosing=%s" % [_wave(),
		int(_t - _stall_t), mech.global_position.round(), get_tree().paused, zone,
		zone.spawn_points.size() if zone else -1, Upgrades.choosing])
	for e in get_tree().get_nodes_in_group("enemies"):
		if not (e is Enemy) or e.dead:
			continue
		var p: Vector2 = e.global_position
		var info := "    %s at %s hp=%d/%d dist=%d los=%s" % [e.get_script().resource_path.get_file(), p.round(), e.hp, e.max_hp,
			p.distance_to(mech.global_position), e.has_line_of_sight(mech.global_position)]
		if arena and arena.get("_layout") and arena.has_method("is_open"):
			var lp: Vector2 = p / arena._k
			var inside := false
			for poly: PackedVector2Array in arena._layout.obstacles:
				if Geometry2D.is_point_in_polygon(lp, poly):
					inside = true
			info += " on_floor=%s inside_obstacle=%s open=%s" % [Geometry2D.is_point_in_polygon(lp, arena._layout.walkable),
				inside, arena.is_open(p, 0.0)]
		print(info)
	# Does the arena's off-floor rescue still work right now? (Diagnoses rare stuck-off-map enemies.)
	if arena and arena.has_method("_rescue_escaped"):
		var before := {}
		for e in get_tree().get_nodes_in_group("enemies"):
			if e is Enemy and not e.dead:
				before[e] = e.global_position
		arena._rescue_escaped()
		for e in before:
			if e.global_position != before[e]:
				print("    rescue moved %s %s -> %s" % [e.get_script().resource_path.get_file(), before[e].round(), e.global_position.round()])
