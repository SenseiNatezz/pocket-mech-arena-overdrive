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
	{"name": "Volcanic Forge", "scene": "res://environment/arenas/arena_04_volcanic_forge.tscn"},
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
## in total (campaign + Endless, counted in `waves_beaten`), or - for a weapon with `beat_arena` - once
## that arena is cleared (its boss beaten). Unlocks are permanent (New Game keeps them). `melee` weapons are handled by player/weapons/melee_kit.gd. `stats` = [damage, speed, range]
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
	# Unlocked by beating VULCAN (clearing the Volcanic Forge, ARENAS[5]) - or by 40 waves for Endless players.
	{"id": &"energy_sword", "name": "Energy Sword", "waves": 40, "beat_arena": 5, "melee": true, "icon": "energy_sword",
		"stats": [4, 4, 3], "desc": "A white-hot plasma blade. Every 4th hit is CRESCENT NOVA: a spinning cut that launches a piercing crescent wave."},
]
## Difficulty (main menu: New Game picker / Settings). Multipliers applied by encounter zones and
## arenas: count = enemies per wave, hp / damage / speed = every enemy, boss_hp = bosses, bombard =
## how often random artillery rains in (higher = more often). Normal is exactly 1.0 everywhere.
## "xp": XP multiplier (enemy XP already scales with their HP, so tougher difficulties need less of it).
## "heal": multiplier on every repair (kits, pickups, stations, Salvage, level-up repairs).
## "elite": chance a robot spawns as an elite (+1% a wave, see EncounterZone.elite_chance).
## "xp_curve": extra XP cost per level from level 3 on (campaign only; Endless has its own curve).
## "scrap": Hangar scrap multiplier (harder = more).
const DIFFICULTIES: Array[Dictionary] = [
	{"name": "Easy", "color": Color(0.45, 1.0, 0.55), "count": 0.65, "hp": 0.7, "damage": 0.55, "speed": 0.9,
		"boss_hp": 0.65, "bombard": 0.5, "xp": 1.0, "heal": 1.0, "elite": 0.0, "xp_curve": 1.0, "scrap": 0.75,
		"desc": "Fewer, weaker enemies that hit softly. For learning the ropes."},
	{"name": "Normal", "color": Color(0.5, 0.85, 1.0), "count": 1.0, "hp": 1.0, "damage": 1.0, "speed": 1.0,
		"boss_hp": 1.0, "bombard": 1.0, "xp": 1.0, "heal": 1.0, "elite": 0.0, "xp_curve": 1.0, "scrap": 1.0,
		"desc": "The intended challenge."},
	{"name": "Hard", "color": Color(1.0, 0.7, 0.3), "count": 1.35, "hp": 1.3, "damage": 1.35, "speed": 1.08,
		"boss_hp": 1.35, "bombard": 1.3, "xp": 1.0, "heal": 1.0, "elite": 0.0, "xp_curve": 1.0, "scrap": 1.3,
		"desc": "Bigger waves of tougher, harder-hitting enemies and beefier bosses."},
	{"name": "Extreme", "color": Color(1.0, 0.3, 0.3), "count": 1.75, "hp": 1.7, "damage": 1.75, "speed": 1.18,
		"boss_hp": 1.8, "bombard": 1.7, "xp": 0.45, "heal": 0.6, "elite": 0.1, "xp_curve": 1.6, "scrap": 1.7,
		"desc": "Brutal swarms with gold ELITES, huge bosses, slow levelling, weak repairs."},
]

## Endless mode fights on the open painted maps (one picked at random per run).
const ENDLESS_MAPS: Array[String] = [
	"res://environment/arenas/arena_00_frozen_outpost.tscn",
	"res://environment/arenas/arena_00b_jungle_megafactory.tscn",
	"res://environment/arenas/arena_04_volcanic_forge.tscn",
]
## Endless: a boss every this many waves.
const ENDLESS_BOSS_EVERY := 5
## Endless bosses: the campaign bosses, shuffled for every run (start_endless) so each run meets
## them in a different order, and never opening with the same boss as the run before (saved).
const ENDLESS_BOSS_SCENES: Array[String] = [
	"res://enemies/warden_boss.tscn",
	"res://enemies/bosses/ronin_boss.tscn",
	"res://enemies/bosses/seraph_boss.tscn",
	"res://enemies/bosses/vulcan_boss.tscn",
]
var endless_boss_order: Array[String] = []
var _last_first_boss := ""
## ENDLESS TWISTS: from wave 6, every 5-wave block (6-10, 11-15, ...) rolls a random modifier
## (ScenicArena._roll_twist, never the same twice in a row). Numeric effects are read through
## twist_value(); CRYSTAL STORM (lightning strikes) and BLACKOUT (darkness) are run by the arena / HUD.
const TWISTS := {
	&"storm": {"name": "CRYSTAL STORM", "color": Color(0.75, 0.45, 1.0),
		"desc": "Crystal lightning strikes the field - robots get hit too."},
	&"blackout": {"name": "BLACKOUT", "color": Color(0.55, 0.65, 0.85),
		"desc": "The lights are out: you only see what's near you."},
	&"elite": {"name": "ELITE SURGE", "color": Color(1.0, 0.8, 0.25), "elite_add": 0.25,
		"desc": "Far more gold elite robots."},
	&"gold": {"name": "GOLD RUSH", "color": Color(1.0, 0.85, 0.35), "scrap": 2.0, "xp": 1.5, "enemy_hp": 1.25,
		"desc": "Double scrap and +50% XP, but robots are 25% tougher."},
	&"swarm": {"name": "SWARM", "color": Color(1.0, 0.45, 0.4), "count": 1.8, "enemy_hp": 0.55,
		"desc": "Nearly twice as many robots, but much weaker."},
	&"hyper": {"name": "REACTOR SURGE", "color": Color(0.35, 0.95, 1.0), "enemy_speed": 1.25, "player_speed": 1.25,
		"boost_cd": 0.5, "desc": "Everything moves 25% faster, and your boost recharges twice as fast."},
}
var endless_twist := &""


## A multiplier (or bonus) from the current Endless twist; `default` when there's none.
func twist_value(key: String, default := 1.0) -> float:
	if not is_endless() or endless_twist == &"" or not TWISTS.has(endless_twist):
		return default
	return float(TWISTS[endless_twist].get(key, default))

var save_path := SAVE_PATH
var arena_index := 0
var screen_shake := true
## Index into DIFFICULTIES (saved with the settings).
var difficulty := 1
var master_volume := 0.8
## Separate music / sound-effect levels (the "Music" and "SFX" buses, both under Master).
var music_volume := 0.7
var sfx_volume := 0.9
## Settings: camera zoom (index into CAMERA_ZOOMS; a multiplier on the device's base zoom, see
## player/mech_camera.gd), fullscreen (desktop; F11 / Alt+Enter toggle it too), and the touch options:
## AUTO-FIRE at the auto-aim target, and the SIMPLE button layout (one smart HEAT button, Repair and
## Overdrive trigger on their own - see ui/touch_controls.gd).
const CAMERA_ZOOMS: Array[Dictionary] = [{"name": "Far", "mult": 0.8}, {"name": "Normal", "mult": 1.0},
	{"name": "Close", "mult": 1.15}]
var camera_zoom := 1
var fullscreen := true
var auto_fire := true
var touch_simple := true
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

## HANGAR (permanent progression): SCRAP is earned in every real run (kills, waves, bosses, arena clears,
## x the difficulty's "scrap" and the Salvage Rights upgrade). It's held in `run_scrap` and banked into
## `scrap` when the run ends (results screen), when you leave for the menu, or when the next run starts.
## Scrap buys permanent HANGAR upgrades and mech CHASSIS (ui/hangar_page.gd).
## id -> name, what one level does, max level, cost of each level.
const HANGAR := {
	&"frame": {"name": "Reinforced Frame", "desc": "+10 max HP per level", "max": 5, "cost": [40, 80, 140, 220, 320]},
	&"calibration": {"name": "Weapon Calibration", "desc": "+5% damage per level", "max": 5, "cost": [50, 100, 160, 240, 340]},
	&"servos": {"name": "Servo Motors", "desc": "+4% move speed per level", "max": 3, "cost": [40, 90, 160]},
	&"analytics": {"name": "Combat Analytics", "desc": "+6% XP per level", "max": 3, "cost": [70, 140, 230]},
	&"kits": {"name": "Spare Repair Kits", "desc": "+1 repair kit per level", "max": 2, "cost": [120, 260]},
	&"head_start": {"name": "Head Start", "desc": "Start every run with a free upgrade pick (per level)", "max": 2, "cost": [150, 350]},
	&"last_stand": {"name": "Last Stand", "desc": "Once per arena, survive a fatal hit with 1 HP", "max": 1, "cost": [250]},
	&"salvage_rights": {"name": "Salvage Rights", "desc": "+10% scrap per level", "max": 3, "cost": [60, 120, 200]},
	&"rerolls": {"name": "Tactical Uplink", "desc": "+1 level-up reroll per run (per level)", "max": 3, "cost": [100, 200, 300]},
	&"banishes": {"name": "Purge Protocol", "desc": "+1 level-up banish per run (per level)", "max": 2, "cost": [150, 300]},
}
## Mech chassis (Hangar): multipliers on the standard frame. `ability` is the frame's signature trick.
const CHASSIS: Array[Dictionary] = [
	{"id": &"standard", "name": "VX-7 Standard", "cost": 0, "hp": 1.0, "speed": 1.0, "boost_cd": 1.0,
		"boost_speed": 1.0, "taken": 1.0, "scale": 1.0, "color": Color(0.45, 0.75, 1.0),
		"ability": "ADAPTIVE CORE: level-ups offer 4 upgrade cards instead of 3.", "desc": "The frame you know: solid armor, solid speed."},
	{"id": &"striker", "name": "VX-5 Striker", "cost": 250, "hp": 0.75, "speed": 1.18, "boost_cd": 0.6,
		"boost_speed": 1.15, "taken": 1.0, "scale": 0.82, "color": Color(0.3, 1.0, 0.85),
		"ability": "AFTERBURNER: boost slices through robots, and every kill recharges your boost faster.",
		"desc": "Light and fast: -25% HP, +18% speed, boost recharges 40% faster."},
	{"id": &"bulwark", "name": "VX-9 Bulwark", "cost": 350, "hp": 1.5, "speed": 0.86, "boost_cd": 1.2,
		"boost_speed": 0.9, "taken": 0.8, "scale": 1.25, "color": Color(1.0, 0.65, 0.3),
		"ability": "SIEGE MODE: hold still to brace (+30% damage, -30% damage taken); boost rams robots aside.",
		"desc": "Heavy armor: +50% HP, takes 20% less damage, but slower."},
]
var scrap := 0
var hangar := {}
## Settings: mission control's voiced radio callouts (autoload/radio.gd).
var radio_voice := true
var chassis := &"standard"
var chassis_owned: Array[StringName] = [&"standard"]
## Scrap earned in the current run, not banked yet (see bank_scrap), and whether this run earns any
## (real campaign / Endless runs do; the tutorial and the ranges don't).
var run_scrap := 0.0
var scrap_enabled := false
## What the last bank_scrap() added (the results screen shows it).
var last_banked := 0

## Per-run stats (reset when an arena starts).
var kills := 0
var run_time := 0.0
## Endless: the last wave survived this run.
var endless_wave := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().title = "Pocket Mech Arena"
	# Debug: automated tests use a throwaway save so they never touch the player's progress.
	if OS.get_cmdline_user_args().has("--temp-save"):
		save_path = "user://test_settings.cfg"
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	else:
		_migrate_save()
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
		elif a.begins_with("--scrap="):  # debug (use with --temp-save): start with this much scrap
			scrap = int(a.trim_prefix("--scrap="))
		elif a.begins_with("--chassis="):  # debug: fly a chassis without buying it (not saved)
			chassis = StringName(a.trim_prefix("--chassis="))
		elif a.begins_with("--hangar="):  # debug: --hangar=frame:3,last_stand:1 (not saved)
			for part in a.trim_prefix("--hangar=").split(","):
				var kv := part.split(":")
				hangar[StringName(kv[0])] = int(kv[1])
	Combat.enemy_killed.connect(_on_enemy_killed)
	_apply_frame_pacing()
	# (test / capture runs keep their window: they pass --temp-save)
	if not OS.get_cmdline_user_args().has("--temp-save"):
		_apply_window()


## FULLSCREEN (desktop only: browsers need a click for it, phones are always full screen).
func can_fullscreen() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.has_feature("mobile")


func _apply_window() -> void:
	if not can_fullscreen() or OS.has_feature("web"):
		return
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)


func set_fullscreen(on: bool) -> void:
	fullscreen = on
	if OS.has_feature("web") and can_fullscreen():
		# (from a button press, so the browser allows it)
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_window()
	save()


func is_fullscreen() -> bool:
	var m := DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


## F11 / Alt+Enter: toggle fullscreen anywhere.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and can_fullscreen() \
			and (k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed)):
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()


func set_camera_zoom(i: int) -> void:
	camera_zoom = clampi(i, 0, CAMERA_ZOOMS.size() - 1)
	save()


func camera_zoom_mult() -> float:
	return float(CAMERA_ZOOMS[camera_zoom]["mult"])


## SMOOTH MOTION: the game simulates at 60 ticks a second by default, and on a 120-165 Hz monitor the
## extra frames just repeat old positions on an uneven beat (judder). On desktop the simulation instead
## runs in lockstep with an exact fraction of the display rate (144 Hz -> 72, 240 -> 80, 75 -> 75; never
## above 90 or below 50) with frames capped to match, so every frame shows fresh movement for the same
## number of refreshes. On the web (ProMotion phones run 120 Hz) frames are capped at 60 to match the
## 60 Hz simulation. Headless runs (tests) are untouched; `--no-pacing` turns it off.
func _apply_frame_pacing() -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("--no-pacing"):
		return
	if OS.has_feature("web") or OS.has_feature("mobile"):
		Engine.max_fps = 60
		return
	var hz := DisplayServer.screen_get_refresh_rate()
	if hz <= 0.0:
		return
	var div := 1
	while hz / div > 90.0:
		div += 1
	var rate := clampi(roundi(hz / div), 50, 90)
	Engine.physics_ticks_per_second = rate
	Engine.max_fps = rate


func _on_enemy_killed(e: Node) -> void:
	kills += 1
	# Scrap: a third of the robot's XP value, bosses +25 on top.
	if scrap_enabled and e is Enemy:
		earn_scrap(maxf(1.0, Upgrades.xp_value(e) / 3.0) + (25.0 if e.is_in_group("boss") else 0.0))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		bank_scrap()


# --- hangar ---------------------------------------------------------------------------------------------

## Adds scrap to this run (difficulty and Salvage Rights multipliers applied).
func earn_scrap(amount: float) -> void:
	if scrap_enabled:
		run_scrap += amount * diff("scrap") * (1.0 + 0.1 * hangar_level(&"salvage_rights")) * twist_value("scrap")


## Moves this run's scrap into the bank (and saves). Returns what was added.
func bank_scrap() -> int:
	last_banked = roundi(run_scrap)
	run_scrap = 0.0
	if last_banked > 0:
		scrap += last_banked
		save()
	return last_banked


func hangar_level(id: StringName) -> int:
	return int(hangar.get(id, 0))


## Cost of the next level of `id` (-1 when maxed).
func hangar_cost(id: StringName) -> int:
	var l := hangar_level(id)
	var info: Dictionary = HANGAR[id]
	return -1 if l >= int(info["max"]) else int(info["cost"][l])


func buy_hangar(id: StringName) -> bool:
	var c := hangar_cost(id)
	if c < 0 or scrap < c:
		return false
	scrap -= c
	hangar[id] = hangar_level(id) + 1
	save()
	return true


func chassis_info(id: StringName = &"") -> Dictionary:
	var want := chassis if id == &"" else id
	for c in CHASSIS:
		if c["id"] == want:
			return c
	return CHASSIS[0]


func owns_chassis(id: StringName) -> bool:
	return chassis_owned.has(id)


## Buys (if needed and affordable) and selects a chassis.
func pick_chassis(id: StringName) -> bool:
	if not owns_chassis(id):
		var c: int = chassis_info(id)["cost"]
		if scrap < c:
			return false
		scrap -= c
		chassis_owned.append(id)
	chassis = id
	save()
	return true


## `carry_upgrades`: keep the current level + upgrades (NEXT ARENA continues the run).
func start_arena(index: int, carry_upgrades := false) -> void:
	arena_index = clampi(index, 0, ARENAS.size() - 1)
	boss_checkpoint = {}
	mode = &"campaign"
	if not carry_upgrades:
		Upgrades.reset()
		Upgrades.grant_head_start()
	else:
		Upgrades.next_arena_bonus()
	Upgrades.save_checkpoint()
	_reset_run()
	scrap_enabled = true
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
	roll_endless_bosses()
	endless_twist = &""
	Upgrades.reset()
	Upgrades.grant_head_start()
	_reset_run()
	scrap_enabled = true
	_change(_endless_scene)


## New boss order for an Endless run (see ENDLESS_BOSS_SCENES).
func roll_endless_bosses() -> void:
	var order := ENDLESS_BOSS_SCENES.duplicate()
	order.shuffle()
	if order[0] == _last_first_boss:
		order.push_back(order.pop_front())
	endless_boss_order = order
	_last_first_boss = order[0]
	save()


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
	bank_scrap()
	scrap_enabled = false
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
	scrap_enabled = false
	_change(TEST_RANGE)


## Tutorial (environment/tutorial.gd): a guided first mission. Records no waves or unlocks.
func to_tutorial() -> void:
	mode = &"campaign"
	Upgrades.reset()
	_reset_run()
	scrap_enabled = false
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
	scrap_enabled = false
	_change(GUN_RANGE)


## Returns the names of weapons this unlocked.
func mark_cleared() -> Array[String]:
	earn_scrap(40.0)
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
	if w.has("beat_arena"):
		return "Defeat the %s boss (Level %d) - or beat %d waves (%d / %d)" % [ARENAS[w["beat_arena"]]["name"],
			int(w["beat_arena"]) + 1, w["waves"], mini(waves_beaten, w["waves"]), w["waves"]]
	return "Beat %d waves (%d / %d)" % [w["waves"], mini(waves_beaten, w["waves"]), w["waves"]]


func is_melee(id: StringName) -> bool:
	return weapon_info(id).get("melee", false)


## An encounter wave was beaten (campaign or Endless). Returns the names of weapons this unlocked
## (they're also queued in new_unlocks for the results screen).
func record_wave_cleared() -> Array[String]:
	waves_beaten += 1
	earn_scrap(5.0)
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
		# Waves beaten, or (if the weapon names one) clearing that arena.
		if waves_beaten >= int(w["waves"]) or (w.has("beat_arena") and cleared.has(int(w["beat_arena"]))):
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
	cfg.set_value("settings", "camera_zoom", camera_zoom)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "auto_fire", auto_fire)
	cfg.set_value("settings", "touch_simple", touch_simple)
	cfg.set_value("controls", "keys", Controls.bindings_to_save())
	cfg.set_value("progress", "cleared", cleared)
	var names: Array[String] = []
	for id in unlocked:
		names.append(String(id))
	cfg.set_value("progress", "unlocked", names)
	cfg.set_value("progress", "endless_best", endless_best)
	cfg.set_value("progress", "waves_beaten", waves_beaten)
	cfg.set_value("progress", "tutorial_done", tutorial_done)
	cfg.set_value("progress", "endless_first_boss", _last_first_boss)
	cfg.set_value("settings", "radio_voice", radio_voice)
	cfg.set_value("hangar", "scrap", scrap)
	cfg.set_value("hangar", "upgrades", hangar)
	cfg.set_value("hangar", "chassis", String(chassis))
	var owned: Array[String] = []
	for id in chassis_owned:
		owned.append(String(id))
	cfg.set_value("hangar", "chassis_owned", owned)
	cfg.set_value("mech", "look", look)
	cfg.set_value("mech", "weapon", String(range_restore if range_restore != &"" else weapon))
	cfg.save(save_path)


## Saves live in a folder named after project.godot's config/name, which was renamed to drop an old
## codename. On the first launch after that, copy the save over from the previous folder (a sibling
## "Pocket Mech Arena..." folder holding one) so nobody loses progress - desktop and web alike.
func _migrate_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		return
	var here := OS.get_user_data_dir()
	var base := here.get_base_dir()
	for d in DirAccess.get_directories_at(base):
		var old := base.path_join(d).path_join(SAVE_PATH.get_file())
		if d.begins_with("Pocket Mech Arena") and base.path_join(d) != here and FileAccess.file_exists(old):
			DirAccess.make_dir_recursive_absolute(here)
			DirAccess.copy_absolute(old, ProjectSettings.globalize_path(SAVE_PATH))
			return


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	screen_shake = cfg.get_value("settings", "screen_shake", true)
	difficulty = clampi(int(cfg.get_value("settings", "difficulty", 1)), 0, DIFFICULTIES.size() - 1)
	master_volume = cfg.get_value("settings", "master_volume", 0.8)
	music_volume = cfg.get_value("settings", "music_volume", 0.7)
	sfx_volume = cfg.get_value("settings", "sfx_volume", 0.9)
	camera_zoom = clampi(int(cfg.get_value("settings", "camera_zoom", 1)), 0, CAMERA_ZOOMS.size() - 1)
	fullscreen = bool(cfg.get_value("settings", "fullscreen", true))
	auto_fire = bool(cfg.get_value("settings", "auto_fire", true))
	touch_simple = bool(cfg.get_value("settings", "touch_simple", true))
	Controls.load_bindings(cfg.get_value("controls", "keys", {}))
	cleared.assign(cfg.get_value("progress", "cleared", []))
	var saved: Dictionary = cfg.get_value("mech", "look", {})
	for k in DEFAULT_LOOK:
		look[k] = int(saved.get(k, DEFAULT_LOOK[k]))
	endless_best = int(cfg.get_value("progress", "endless_best", 0))
	_last_first_boss = str(cfg.get_value("progress", "endless_first_boss", ""))
	radio_voice = bool(cfg.get_value("settings", "radio_voice", true))
	scrap = int(cfg.get_value("hangar", "scrap", 0))
	var saved_hangar: Dictionary = cfg.get_value("hangar", "upgrades", {})
	for k in saved_hangar:
		if HANGAR.has(StringName(k)):
			hangar[StringName(k)] = int(saved_hangar[k])
	for n in cfg.get_value("hangar", "chassis_owned", []):
		if not chassis_owned.has(StringName(n)):
			chassis_owned.append(StringName(n))
	var ch := StringName(cfg.get_value("hangar", "chassis", "standard"))
	chassis = ch if chassis_owned.has(ch) else &"standard"
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


## A new run (or arena) starts: bank whatever the last one earned, then reset the per-run stats.
func _reset_run() -> void:
	bank_scrap()
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
