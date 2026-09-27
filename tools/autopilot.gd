extends Node
## Debug AI pilot (`-- --autoplay`): fights enemies, dodges artillery circles, avoids pits, uses
## abilities and follows the arena objective. Drives the same Controls/Input actions as a player.

var _strafe := 1.0
var _strafe_t := 0.0
var _taps := {}
var _path := PackedVector2Array()
var _path_t := 0.0
var _alt_t := 0.0


func _ready() -> void:
	Controls.ignore_real_input = true


func _tap(action: StringName) -> void:
	Input.action_press(action)
	_taps[action] = 2


func _physics_process(delta: float) -> void:
	for a in _taps.keys():
		_taps[a] -= 1
		if _taps[a] <= 0:
			Input.action_release(a)
			_taps.erase(a)
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech == null or mech.dead:
		Input.action_release(&"fire_primary")
		return
	var pos := mech.global_position
	_strafe_t -= delta
	if _strafe_t <= 0.0:
		_strafe_t = randf_range(1.0, 2.2)
		_strafe = -_strafe
	var target: Node2D = null
	var best := 1e9
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Node2D and not e.get("dead") and e.global_position.distance_to(pos) < best:
			best = e.global_position.distance_to(pos)
			target = e
	var move := Vector2.ZERO
	if target and best < 900.0:
		var to := target.global_position - pos
		Controls.touch_aim = to.normalized()
		Input.action_press(&"fire_primary")
		if best > 380.0:
			move = _follow(pos, target.global_position, delta)
		elif best < 220.0:
			move = -to.normalized()
		else:
			move = to.normalized().orthogonal() * _strafe
		_alt_t -= delta
		if best < 280.0 and _alt_t <= 0.0:
			_alt_t = 1.2
			_tap(&"fire_secondary")
		if best < 170.0 and mech.heat >= mech.nova_cost:
			_tap(&"heat_attack_1")
		elif best < 260.0 and mech.heat >= mech.cone_cost + 45.0:
			_tap(&"heat_attack_2")
	else:
		Input.action_release(&"fire_primary")
		move = _follow(pos, _objective(pos), delta)
		if move != Vector2.ZERO:
			Controls.touch_aim = move
	# Dodge artillery circles.
	for s in Combat.world().get_children():
		var r = s.get("radius")
		if r != null and s.get("delay") != null and s.global_position.distance_to(pos) < r + 30.0:
			move = (pos - s.global_position).normalized()
			if mech.boost_ready_fraction() >= 1.0:
				_tap(&"boost")
	# Don't walk into pits.
	for p in get_tree().get_nodes_in_group("pits"):
		var rect := Rect2(p.global_position - p.size / 2, p.size).grow(40)
		if rect.has_point(pos + move * 70.0):
			move = move.orthogonal() * _strafe
	if mech.hp < 45.0 and mech.repair_charges > 0:
		_tap(&"self_repair")
	if mech.overdrive_meter >= 100.0:
		_tap(&"overdrive")
	if mech.focus_interactable and mech.hp < mech.max_hp * 0.7:
		_tap(&"use")
	Controls.touch_move = move


func _objective(pos: Vector2) -> Vector2:
	var arena := get_tree().get_first_node_in_group("arena")
	if arena == null:
		return pos
	var zone = arena.zone
	if zone and not zone.is_running and not zone.is_cleared:
		return zone.global_position
	if zone and zone.is_cleared and arena.door and arena.door.is_open:
		return arena.rect_center(arena.boss_rect)
	return pos


func _follow(pos: Vector2, goal: Vector2, delta: float) -> Vector2:
	_path_t -= delta
	if _path_t <= 0.0 or _path.is_empty():
		_path_t = 0.4
		var map: RID = get_viewport().world_2d.navigation_map
		_path = NavigationServer2D.map_get_path(map, pos, goal, true)
	while _path.size() > 1 and _path[0].distance_to(pos) < 40.0:
		_path.remove_at(0)
	if _path.is_empty():
		return (goal - pos).normalized()
	return (_path[0] - pos).normalized() if _path[0].distance_to(pos) > 8.0 else Vector2.ZERO
