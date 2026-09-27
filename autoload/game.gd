extends Node
## Game (autoload): arena list, scene flow (menu <-> arenas), run stats and saved settings.

const MAIN_MENU := "res://ui/main_menu.tscn"
const TEST_RANGE := "res://environment/test_range.tscn"
const ARENAS: Array[Dictionary] = [
	{"name": "Ruined Plaza", "scene": "res://environment/arenas/arena_01_ruined_plaza.tscn"},
	{"name": "Skyway Junction", "scene": "res://environment/arenas/arena_02_skyway_junction.tscn"},
]
const SAVE_PATH := "user://settings.cfg"

var arena_index := 0
var screen_shake := true
var master_volume := 0.8
var cleared: Array[int] = []

## Per-run stats (reset when an arena starts).
var kills := 0
var run_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	_apply_volume()
	Combat.enemy_killed.connect(func(_e: Node) -> void: kills += 1)


func start_arena(index: int) -> void:
	arena_index = clampi(index, 0, ARENAS.size() - 1)
	_reset_run()
	_change(ARENAS[arena_index]["scene"])


func restart_arena() -> void:
	start_arena(arena_index)


func has_next_arena() -> bool:
	return arena_index + 1 < ARENAS.size()


func next_arena() -> void:
	start_arena(arena_index + 1 if has_next_arena() else 0)


func to_menu() -> void:
	_change(MAIN_MENU)


func to_test_range() -> void:
	_reset_run()
	_change(TEST_RANGE)


func mark_cleared() -> void:
	if not cleared.has(arena_index):
		cleared.append(arena_index)
		save()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	save()


func set_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("progress", "cleared", cleared)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	screen_shake = cfg.get_value("settings", "screen_shake", true)
	master_volume = cfg.get_value("settings", "master_volume", 0.8)
	cleared.assign(cfg.get_value("progress", "cleared", []))


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))


func _reset_run() -> void:
	kills = 0
	run_time = 0.0


func _change(path: String) -> void:
	get_tree().paused = false
	Controls.touch_move = Vector2.ZERO
	Controls.touch_aim = Vector2.ZERO
	for a in InputMap.get_actions():
		Input.action_release(a)
	get_tree().change_scene_to_file(path)
