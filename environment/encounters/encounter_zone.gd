class_name EncounterZone
extends Area2D
## Encounter zone: when the player steps inside, the energy barriers seal it and `waves` spawn one
## after another (each enemy warps in at a telegraphed spot away from the player). Clearing the last
## wave drops the barriers and emits `cleared` (the arena then opens the boss door).
##
## Wave format (one string per wave):  "chaser:4, shooter:2, lobber:1"

signal started
signal wave_started(index: int, total: int)
signal wave_cleared(index: int, total: int)
signal cleared

const ENEMIES := {
	"chaser": preload("res://enemies/chaser.tscn"),
	"shooter": preload("res://enemies/shooter.tscn"),
	"lobber": preload("res://enemies/lobber.tscn"),
}

@export var waves: PackedStringArray = [
	"chaser:4",
	"chaser:3, shooter:2",
	"chaser:3, shooter:1, lobber:2",
	"shooter:4, lobber:2",
	"chaser:5, shooter:2, lobber:2",
]
@export var zone_size := Vector2(1600, 900)
@export var hp_mult := 1.0
@export var damage_mult := 1.0
## Extra HP per wave (0.08 = +8% each wave).
@export var hp_ramp := 0.08
## From this wave on (1-based), random artillery shells rain on the player every few seconds.
@export var bombard_from_wave := 3
@export var bombard_interval := 5.0

var barriers: Array[Node] = []
var spawn_points: PackedVector2Array = []
var enemy_parent: Node
var wave := 0
var is_running := false
var is_cleared := false
var _alive: Array[Enemy] = []
var _pending := 0
var _bombard_t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = zone_size
	shape.shape = box
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Mech and not is_running and not is_cleared:
		start()


func start() -> void:
	is_running = true
	for b in barriers:
		b.active = true
	started.emit()
	get_tree().create_timer(1.2, false).timeout.connect(_next_wave)


func alive_count() -> int:
	return _alive.size() + _pending


func _next_wave() -> void:
	wave += 1
	wave_started.emit(wave, waves.size())
	var list: Array[String] = []
	for part in waves[wave - 1].split(",", false):
		var kv := part.strip_edges().split(":")
		for i in (int(kv[1]) if kv.size() > 1 else 1):
			list.append(kv[0].strip_edges())
	list.shuffle()
	_pending = list.size()
	for i in list.size():
		get_tree().create_timer(0.2 + i * 0.25, false).timeout.connect(_telegraph_spawn.bind(list[i]))


func _telegraph_spawn(kind: String) -> void:
	var pos := _pick_spawn_point()
	# Warp-in telegraph: a pulsing magenta ring for 0.7 s.
	for k in 3:
		get_tree().create_timer(k * 0.22, false).timeout.connect(func() -> void:
			Combat.shockwave(pos, 70.0 - k * 15.0, Color(1.0, 0.3, 0.8), 0.3))
	get_tree().create_timer(0.7, false).timeout.connect(_spawn.bind(kind, pos))


func _spawn(kind: String, pos: Vector2) -> void:
	_pending -= 1
	if not ENEMIES.has(kind):
		push_warning("Unknown enemy kind '%s'" % kind)
		_check_clear()
		return
	var e: Enemy = ENEMIES[kind].instantiate()
	e.position = pos
	e.max_hp *= hp_mult * (1.0 + hp_ramp * (wave - 1))
	e.damage_mult = damage_mult
	e.died.connect(_on_enemy_died)
	_alive.append(e)
	(enemy_parent if enemy_parent else get_parent()).add_child(e)


func _pick_spawn_point() -> Vector2:
	var mech := get_tree().get_first_node_in_group("player") as Node2D
	var best := global_position
	for i in 20:
		var p := spawn_points[randi() % spawn_points.size()] if not spawn_points.is_empty() else \
			global_position + Vector2(randf_range(-0.4, 0.4) * zone_size.x, randf_range(-0.4, 0.4) * zone_size.y)
		best = p
		if mech == null or p.distance_to(mech.global_position) > 340.0:
			break
	return best


func _on_enemy_died(e: Enemy) -> void:
	_alive.erase(e)
	_check_clear()


func _check_clear() -> void:
	if not is_running or _pending > 0 or not _alive.is_empty():
		return
	wave_cleared.emit(wave, waves.size())
	if wave >= waves.size():
		is_running = false
		is_cleared = true
		for b in barriers:
			b.active = false
		cleared.emit()
	else:
		get_tree().create_timer(2.2, false).timeout.connect(_next_wave)


func _physics_process(delta: float) -> void:
	if not is_running or wave < bombard_from_wave:
		return
	_bombard_t -= delta
	if _bombard_t <= 0.0:
		_bombard_t = bombard_interval
		var mech := get_tree().get_first_node_in_group("player") as Mech
		if mech and not mech.dead:
			for i in 3:
				var off := Vector2.ZERO if i == 0 else Vector2.from_angle(randf() * TAU) * randf_range(110, 220)
				Combat.artillery(mech.global_position + mech.velocity * 0.6 + off, 75.0, 14.0 * damage_mult, null, 1.0 + i * 0.25)
