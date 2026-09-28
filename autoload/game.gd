extends Node
## Game (autoload): arena list, scene flow (menu <-> arenas, endless mode), run stats, weapon unlocks
## and saved settings.

## Weapons just unlocked mid-run by beating a wave (the HUD shows a toast).
signal weapon_unlocked(names: Array[String])

const MAIN_MENU := "res://ui/main_menu.tscn"
const TEST_RANGE := "res://environment/test_range.tscn"
## Gun Range: the test range with EVERY weapon usable (switch freely) and enemies to spawn on demand.
const GUN_RANGE := "res://environment/gun_range.tscn"
const TUTORIAL := "res://environment/tutorial.tscn"
const ARENAS: Array[Dictionary] = [
	{"name": "Frozen Outpost", "scene": "res://environment/arenas/arena_00_frozen_outpost.tscn"},
	{"name": "Jungle Megafactory", "scene": "res://environment/arenas/arena_00b_jungle_megafactory.tscn"},
	{"name": "Alien Outpost", "scene": "res://environment/arenas/arena_01_alien_outpost.tscn"},
	{"name": "Skyway Junction", "scene": "res://environment/arenas/arena_02_skyway_junction.tscn"},
	{"name": "Ruined Plaza", "scene": "res://environment/arenas/arena_03_ruined_plaza.tscn"},
]
const SAVE_PATH := "user://settings.cfg"
const CUSTOMIZE := "res://ui/customize.tscn"
## Gundam Customization options (see ui/customize.gd). Armor recolors the blue panels of the sprite
## (hue/sat/val for the shader; "none" = original paint); energy = shots, muzzle flash and visor
## glow; booster = thruster flames and boost afterimages.
const ARMOR: Array[Dictionary] = [
	{"name": "Blue", "color": Color(0.16, 0.36, 0.95), "none": true},
	{"name": "Crimson", "color": Color(0.85, 0.12, 0.12), "hue": 0.99, "sat": 1.05, "val": 0.95},
	{"name": "Emerald", "color": Color(0.12, 0.62, 0.3), "hue": 0.38, "sat": 0.95, "val": 0.8},
	{"name": "Stealth", "color": Color(0.14, 0.15, 0.18), "hue": 0.62, "sat": 0.12, "val": 0.42},
	{"name": "Gold", "color": Color(0.95, 0.7, 0.12), "hue": 0.11, "sat": 1.0, "val": 1.1},
]
const ENERGY: Array[Dictionary] = [
	{"name": "Pink", "color": Color(1.0, 0.35, 0.8)},
	{"name": "Blue", "color": Color(0.35, 0.65, 1.0)},
	{"name": "Green", "color": Color(0.35, 1.0, 0.45)},
	{"name": "Orange", "color": Color(1.0, 0.55, 0.12)},
	{"name": "White", "color": Color(0.95, 0.97, 1.0)},
]
const BOOSTER: Array[Dictionary] = [
	{"name": "Cyan", "color": Color(0.25, 0.85, 1.0)},
	{"name": "Pink", "color": Color(1.0, 0.4, 0.8)},
	{"name": "Green", "color": Color(0.4, 1.0, 0.45)},
	{"name": "Orange", "color": Color(1.0, 0.55, 0.15)},
	{"name": "White", "color": Color(0.95, 0.97, 1.0)},
]
const DEFAULT_LOOK := {"armor": 0, "energy": 1, "booster": 0}
## Primary weapons (chosen in the main menu's Armory). Each unlocks once `waves` waves have been beaten
## in total (campaign + Endless, counted in `waves_beaten`). Unlocks are permanent (New Game keeps
## them). `melee` weapons are handled by player/weapons/melee_kit.gd. `stats` = [damage, speed, range]
## (1-5, for the Armory bars); `icon` = art in assets/hq/weapons.
const WEAPONS: Array[Dictionary] = [
	{"id": &"blaster", "name": "Beam Rifle", "waves": 0, "icon": "beam_rifle", "stats": [2, 4, 4],
		"desc": "Standard mid-range rifle: accurate, reliable rapid-fire energy bolts."},
	{"id": &"sword", "name": "Beam Saber", "waves": 3, "melee": true, "icon": "beam_saber", "stats": [3, 3, 2],
		"desc": "Fast melee slashes that cut bullets out of the air. Every 3rd hit is a DASH SLASH."},
	{"id": &"sniper", "name": "Sniper Beam", "waves": 5, "icon": "sniper", "stats": [4, 1, 5],
		"desc": "Slow, heavy hitscan beam that pierces EVERY enemy in a line."},
	{"id": &"dual_sabers", "name": "Dual Beam Sabers", "waves": 8, "melee": true, "icon": "dual_sabers",
		"stats": [2, 5, 2], "desc": "Blistering twin-blade combos. Every 5th hit WHIRLS both sabers around you."},
	{"id": &"katana", "name": "Beam Katana", "waves": 10, "melee": true, "icon": "katana", "stats": [3, 3, 3],
		"desc": "Long reach and wide anime sweeps. Every 3rd hit is an IAIDO dash straight through the enemy."},
	{"id": &"gatling", "name": "Gatling Cannon", "waves": 13, "icon": "gatling", "stats": [2, 5, 3],
		"desc": "A huge six-barrel cannon firing a storm of big heavy rounds. You move slower while firing."},
	{"id": &"spear", "name": "Beam Spear", "waves": 15, "melee": true, "icon": "spear", "stats": [3, 3, 4],
		"desc": "Long piercing thrusts. Every 3rd hit is a CHARGE that skewers a whole line of enemies."},
	{"id": &"rockets", "name": "Rocket Launcher", "waves": 18, "icon": "rocket_launcher", "stats": [5, 1, 4],
		"desc": "Heavy rockets that explode on impact, blasting everything nearby and breaking cover."},
	{"id": &"axe", "name": "Energy Axe", "waves": 20, "melee": true, "icon": "axe", "stats": [5, 1, 2],
		"desc": "Slow, brutal chops with massive knockback. Every 3rd hit is a GROUND SLAM shockwave."},
	{"id": &"scythe", "name": "Beam Scythe", "waves": 25, "melee": true, "icon": "scythe", "stats": [3, 2, 3],
		"desc": "Every swing is a full circle that hits the whole crowd. Every 3rd is a REAP that drags them in."},
	{"id": &"greatsword", "name": "Physical Greatsword", "waves": 30, "melee": true, "icon": "greatsword",
		"stats": [5, 1, 3], "desc": "A huge two-handed blade. Every 3rd hit is an overhead CLEAVE finisher."},
]
## Difficulty (main menu: New Game picker / Settings). Multipliers applied by encounter zones and
## arenas: count = enemies per wave, hp / damage / speed = every enemy, boss_hp = bosses, bombard =
## how often random artillery rains in (higher = more often). Normal is exactly 1.0 everywhere.
const DIFFICULTIES: Array[Dictionary] = [
	{"name": "Easy", "color": Color(0.45, 1.0, 0.55), "count": 0.65, "hp": 0.7, "damage": 0.55, "speed": 0.9,
		"boss_hp": 0.65, "bombard": 0.5, "desc": "Fewer, weaker enemies that hit softly. For learning the ropes."},
	{"name": "Normal", "color": Color(0.5, 0.85, 1.0), "count": 1.0, "hp": 1.0, "damage": 1.0, "speed": 1.0,
		"boss_hp": 1.0, "bombard": 1.0, "desc": "The intended challenge."},
	{"name": "Hard", "color": Color(1.0, 0.7, 0.3), "count": 1.35, "hp": 1.3, "damage": 1.35, "speed": 1.08,
		"boss_hp": 1.35, "bombard": 1.3, "desc": "Bigger waves of tougher, harder-hitting enemies and beefier bosses."},
	{"name": "Extreme", "color": Color(1.0, 0.3, 0.3), "count": 1.75, "hp": 1.7, "damage": 1.75, "speed": 1.18,
		"boss_hp": 1.8, "bombard": 1.7, "desc": "Swarms of fast, brutal enemies, relentless artillery and huge bosses."},
]

## Endless mode fights on the open painted maps (one picked at random per run).
const ENDLESS_MAPS: Array[String] = [
	"res://environment/arenas/arena_00_frozen_outpost.tscn",
	"res://environment/arenas/arena_00b_jungle_megafactory.tscn",
]
## Endless: a boss every this many waves.
const ENDLESS_BOSS_EVERY := 5

var save_path := SAVE_PATH
var arena_index := 0
var screen_shake := true
## Index into DIFFICULTIES (saved with the settings).
var difficulty := 1
var master_volume := 0.8
## Separate music / sound-effect levels (the "Music" and "SFX" buses, both under Master).
var music_volume := 0.7
var sfx_volume := 0.9
var cleared: Array[int] = []
var look := DEFAULT_LOOK.duplicate()
var weapon := &"blaster"
var unlocked: Array[StringName] = [&"blaster"]
## Most Endless waves ever survived (and the record when this run began, to spot a new one).
var endless_best := 0
var endless_best_at_start := 0
## Waves beaten in total, campaign + Endless (weapon unlocks).
var waves_beaten := 0
## Finished (or skipped) the tutorial. New players are offered it before their first run.
var tutorial_done := false
## Gun Range: the weapon equipped before entering (the range swaps `weapon` freely, in memory only).
## save() writes this instead, and leaving the range puts it back.
var range_restore := &""
## RETRY BOSS (campaign): taken when an arena's boss appears - arena, level, XP, upgrades, kills, time.
var boss_checkpoint := {}
## True for the arena scene loaded by retry_boss(): it skips the intro + waves and drops the boss in.
var start_at_boss := false
var _pending_boss_start := false
## &"campaign" or &"endless".
var mode := &"campaign"
## Weapons unlocked since the HUD last announced them (it shows + clears this list).
var new_unlocks: Array[String] = []
var _endless_scene := ""

## Per-run stats (reset when an arena starts).
var kills := 0
var run_time := 0.0
## Endless: the last wave survived this run.
var endless_wave := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Debug: automated tests use a throwaway save so they never touch the player's progress.
	if OS.get_cmdline_user_args().has("--temp-save"):
		save_path = "user://test_settings.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	_load()
	_apply_volume()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look="):  # debug: try a look without saving it
			var v := a.trim_prefix("--look=").split(",")
			look = {"armor": int(v[0]), "energy": int(v[1]), "booster": int(v[2])}
		elif a.begins_with("--weapon="):  # debug: try a weapon without saving it
			weapon = StringName(a.trim_prefix("--weapon="))
		elif a.begins_with("--difficulty="):  # debug: 0 easy, 1 normal, 2 hard, 3 extreme (not saved)
			difficulty = clampi(int(a.trim_prefix("--difficulty=")), 0, DIFFICULTIES.size() - 1)
		elif a.begins_with("--waves-beaten="):  # debug (use with --temp-save): preview unlock progress
			waves_beaten = int(a.trim_prefix("--waves-beaten="))
			check_unlocks()
			new_unlocks.clear()
	Combat.enemy_killed.connect(func(_e: Node) -> void: kills += 1)


## `carry_upgrades`: keep the current level + upgrades (NEXT ARENA continues the run).
func start_arena(index: int, carry_upgrades := false) -> void:
	arena_index = clampi(index, 0, ARENAS.size() - 1)
	boss_checkpoint = {}
	mode = &"campaign"
	if not carry_upgrades:
		Upgrades.reset()
	Upgrades.save_checkpoint()
	_reset_run()
	_change(ARENAS[arena_index]["scene"])


## The boss just appeared (ScenicArena._start_boss): remember where the run stood for RETRY BOSS.
func save_boss_checkpoint() -> void:
	if is_endless():
		return
	boss_checkpoint = {"arena": arena_index, "level": Upgrades.level, "xp": Upgrades.xp,
		"stacks": Upgrades.stacks.duplicate(), "kills": kills, "time": run_time}


func can_retry_boss() -> bool:
	return not is_endless() and boss_checkpoint.get("arena", -1) == arena_index


## Game over during a boss fight: reload the arena straight at the boss, with the level, upgrades,
## kills and time you had when it appeared (the waves are skipped).
func retry_boss() -> void:
	if not can_retry_boss():
		restart_arena()
		return
	var c := boss_checkpoint
	Upgrades.level = c["level"]
	Upgrades.xp = c["xp"]
	Upgrades.stacks = c["stacks"].duplicate()
	Upgrades.pending = 0
	Upgrades.choosing = false
	kills = c["kills"]
	run_time = c["time"]
	mode = &"campaign"
	_pending_boss_start = true
	_change(ARENAS[arena_index]["scene"])


## Endless mode: countless waves on a random open map, a boss every ENDLESS_BOSS_EVERY waves.
func start_endless(scene := "") -> void:
	mode = &"endless"
	_endless_scene = scene if scene != "" else ENDLESS_MAPS.pick_random()
	endless_best_at_start = endless_best
	Upgrades.reset()
	_reset_run()
	_change(_endless_scene)


func is_endless() -> bool:
	return mode == &"endless"


## Endless: a wave was survived. Returns the names of weapons this unlocked.
func record_endless_wave(wave: int) -> Array[String]:
	endless_wave = wave
	if wave > endless_best:
		endless_best = wave
		save()
	return check_unlocks()


## New Game: wipes arena progress and starts at arena 1 (unlocked weapons are kept).
func new_game() -> void:
	cleared.clear()
	save()
	start_arena(0)


## Continue: the first arena not cleared yet (arena 1 if everything is cleared).
func continue_index() -> int:
	for i in ARENAS.size():
		if not cleared.has(i):
			return i
	return 0


func has_progress() -> bool:
	return not cleared.is_empty()


func armor() -> Dictionary:
	return ARMOR[clampi(look["armor"], 0, ARMOR.size() - 1)]


func energy_color() -> Color:
	return ENERGY[clampi(look["energy"], 0, ENERGY.size() - 1)]["color"]


func booster_color() -> Color:
	return BOOSTER[clampi(look["booster"], 0, BOOSTER.size() - 1)]["color"]


func set_look(new_look: Dictionary) -> void:
	look = new_look.duplicate()
	save()


## Applies the armor paint to a ShaderMaterial using shaders/hit_flash.gdshader.
func apply_armor(mat: ShaderMaterial, armor_index := -1) -> void:
	var a: Dictionary = ARMOR[clampi(armor_index if armor_index >= 0 else look["armor"], 0, ARMOR.size() - 1)]
	mat.set_shader_parameter("recolor", not a.get("none", false))
	if not a.get("none", false):
		mat.set_shader_parameter("target_hue", a["hue"])
		mat.set_shader_parameter("sat_mult", a["sat"])
		mat.set_shader_parameter("val_mult", a["val"])


func to_customize() -> void:
	_change(CUSTOMIZE)


func restart_arena() -> void:
	if is_endless():
		start_endless(_endless_scene)
		return
	# Retry with the level + upgrades you had when this arena started.
	Upgrades.restore_checkpoint()
	start_arena(arena_index, true)


func has_next_arena() -> bool:
	return arena_index + 1 < ARENAS.size()


func next_arena() -> void:
	start_arena(arena_index + 1 if has_next_arena() else 0, has_next_arena())


func to_menu() -> void:
	_change(MAIN_MENU)


func to_test_range() -> void:
	# The HUD's restart from inside the Gun Range lands here: stay in the Gun Range.
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == GUN_RANGE:
		to_gun_range()
		return
	# ...and from inside the tutorial: start the tutorial over.
	if get_tree().current_scene and get_tree().current_scene.scene_file_path == TUTORIAL:
		to_tutorial()
		return
	mode = &"campaign"
	_reset_run()
	_change(TEST_RANGE)


## Tutorial (environment/tutorial.gd): a guided first mission. Records no waves or unlocks.
func to_tutorial() -> void:
	mode = &"campaign"
	Upgrades.reset()
	_reset_run()
	_change(TUTORIAL)


func finish_tutorial() -> void:
	if not tutorial_done:
		tutorial_done = true
		save()


## Gun Range: never records waves or unlocks, and only swaps the weapon in memory (see gun_range.gd).
func to_gun_range() -> void:
	if range_restore == &"":
		range_restore = weapon
	mode = &"campaign"
	Upgrades.reset()
	_reset_run()
	_change(GUN_RANGE)


## Returns the names of weapons this unlocked.
func mark_cleared() -> Array[String]:
	if not cleared.has(arena_index):
		cleared.append(arena_index)
		save()
	return check_unlocks()


# --- weapons -------------------------------------------------------------------------------------------

func weapon_info(id: StringName) -> Dictionary:
	for w in WEAPONS:
		if w["id"] == id:
			return w
	return WEAPONS[0]


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(id)


func unlock_text(id: StringName) -> String:
	var w := weapon_info(id)
	if int(w["waves"]) <= 0:
		return "Unlocked from the start"
	return "Beat %d waves (%d / %d)" % [w["waves"], mini(waves_beaten, w["waves"]), w["waves"]]


func is_melee(id: StringName) -> bool:
	return weapon_info(id).get("melee", false)


## An encounter wave was beaten (campaign or Endless). Returns the names of weapons this unlocked
## (they're also queued in new_unlocks for the results screen).
func record_wave_cleared() -> Array[String]:
	waves_beaten += 1
	var fresh := check_unlocks()
	if fresh.is_empty():
		save()
	else:
		weapon_unlocked.emit(fresh)
	return fresh


func equip(id: StringName) -> void:
	if is_unlocked(id):
		weapon = id
		save()


## Unlocks every weapon whose condition is now met. Returns the names of NEW unlocks.
func check_unlocks() -> Array[String]:
	var fresh: Array[String] = []
	for w in WEAPONS:
		if unlocked.has(w["id"]):
			continue
		if waves_beaten >= int(w["waves"]):
			unlocked.append(w["id"])
			fresh.append(w["name"])
	if not fresh.is_empty():
		new_unlocks.append_array(fresh)
		save()
	return fresh


# --- settings / save -------------------------------------------------------------------------------------

## Current difficulty's multiplier `key` (count, hp, damage, speed, boss_hp, bombard).
func diff(key: String) -> float:
	return DIFFICULTIES[difficulty][key]


func difficulty_name() -> String:
	return DIFFICULTIES[difficulty]["name"]


func set_difficulty(i: int) -> void:
	difficulty = clampi(i, 0, DIFFICULTIES.size() - 1)
	save()


func set_screen_shake(on: bool) -> void:
	screen_shake = on
	save()


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	save()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	save()


## Index of the named audio bus, creating it (routed to Master) the first time.
func _bus(bus_name: String) -> int:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus_name)
		AudioServer.set_bus_send(i, &"Master")
	return i


func set_volume(v: float) -> void:
	master_volume = clampf(v, 0.0, 1.0)
	_apply_volume()
	save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "screen_shake", screen_shake)
	cfg.set_value("settings", "difficulty", difficulty)
	cfg.set_value("settings", "master_volume", master_volume)
	cfg.set_value("settings", "music_volume", music_volume)
	cfg.set_value("settings", "sfx_volume", sfx_volume)
	cfg.set_value("progress", "cleared", cleared)
	var names: Array[String] = []
	for id in unlocked:
		names.append(String(id))
	cfg.set_value("progress", "unlocked", names)
	cfg.set_value("progress", "endless_best", endless_best)
	cfg.set_value("progress", "waves_beaten", waves_beaten)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("mech", "look", look)
	cfg.set_value("mech", "weapon", String(range_restore if range_restore != &"" else weapon))
	cfg.save(save_path)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	screen_shake = cfg.get_value("settings", "screen_shake", true)
	difficulty = clampi(int(cfg.get_value("settings", "difficulty", 1)), 0, DIFFICULTIES.size() - 1)
	master_volume = cfg.get_value("settings", "master_volume", 0.8)
	music_volume = cfg.get_value("settings", "music_volume", 0.7)
	sfx_volume = cfg.get_value("settings", "sfx_volume", 0.9)
	cleared.assign(cfg.get_value("progress", "cleared", []))
	var saved: Dictionary = cfg.get_value("mech", "look", {})
	for k in DEFAULT_LOOK:
		look[k] = int(saved.get(k, DEFAULT_LOOK[k]))
	endless_best = int(cfg.get_value("progress", "endless_best", 0))
	# Saves from before the wave counter: credit 5 waves per cleared arena + the Endless record.
	waves_beaten = maxi(int(cfg.get_value("progress", "waves_beaten", 0)), cleared.size() * 5 + endless_best)
	# Players who already have progress know the controls: don't push the tutorial on them.
	tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false)) or waves_beaten > 0 or not cleared.is_empty()
	for n in cfg.get_value("progress", "unlocked", []):
		if not unlocked.has(StringName(n)):
			unlocked.append(StringName(n))
	# Saves from before the Armory existed: grant anything already earned.
	check_unlocks()
	new_unlocks.clear()
	var w := StringName(cfg.get_value("mech", "weapon", "blaster"))
	weapon = w if is_unlocked(w) else &"blaster"


func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	for b in [["Music", music_volume], ["SFX", sfx_volume]]:
		var i := _bus(b[0])
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(b[1], 0.0001)))
		AudioServer.set_bus_mute(i, b[1] <= 0.001)


func _reset_run() -> void:
	kills = 0
	run_time = 0.0
	endless_wave = 0


func _change(path: String) -> void:
	start_at_boss = _pending_boss_start
	_pending_boss_start = false
	if path != GUN_RANGE and range_restore != &"":
		weapon = range_restore
		range_restore = &""
	get_tree().paused = false
	Controls.touch_move = Vector2.ZERO
	Controls.touch_aim = Vector2.ZERO
	for a in InputMap.get_actions():
		Input.action_release(a)
	get_tree().change_scene_to_file(path)
