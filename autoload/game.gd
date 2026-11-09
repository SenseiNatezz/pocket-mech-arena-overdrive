extends Node
## Game (autoload): arena list, scene flow (menu <-> arenas, endless mode), run stats, weapon unlocks
## and saved settings.

## Weapons just unlocked mid-run by beating a wave (the HUD shows a toast).
signal weapon_unlocked(names: Array[String])
## Scrap paid out without a chip (wave / arena bonuses): the HUD ticker's "+N" pop says what it was for.
signal scrap_bonus(amount: float, label: String)
## A weapon's mastery reached a new level mid-run (the HUD shows a MASTERY UP toast).
signal mastery_up(weapon_id: StringName, level: int)
## The ARMORY MASTERY POOL passed checkpoint `index` (POOL_CHECKPOINTS; the HUD toasts it).
signal pool_checkpoint(index: int)
## GOLD SALVAGER (enemies/gold_salvager.gd): one showed up / was shot down (`prize` = &"frenzy", &"lucky",
## &"xp", &"overdrive" or &"jackpot"; `amount` = scrap it paid at once) / got away. The HUD announces them.
signal salvager_spotted
signal salvager_caught(prize: StringName, amount: float)
signal salvager_escaped
## THREAT TIERS: a run on Extreme was won at `tier` (0 = plain Extreme): an arena's boss beaten, or Endless
## wave THREAT_ENDLESS_WAVE survived. `bounty` = scrap the weapon's bounty paid (0 = none / claimed before),
## `opened` = it unlocked the next tier.
signal threat_won(tier: int, bounty: int, opened: bool)
## For the Contracts (autoload/contracts.gd): an arena's boss went down, a wave was beaten, a run's scrap
## was banked, a Hangar level was bought.
signal arena_won(index: int)
signal wave_won
signal run_banked(amount: int, parts: Dictionary)
signal hangar_bought(id: StringName)

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
	# Paint recolours the Halo Forge's gold trim (shaders/hit_flash.gdshader); index 0 keeps it gold.
	{"name": "Gold", "color": Color(0.95, 0.7, 0.12), "none": true},
	{"name": "Crimson", "color": Color(0.85, 0.12, 0.12), "hue": 0.99, "sat": 1.05, "val": 0.95},
	{"name": "Emerald", "color": Color(0.12, 0.62, 0.3), "hue": 0.38, "sat": 0.95, "val": 0.8},
	{"name": "Stealth", "color": Color(0.14, 0.15, 0.18), "hue": 0.62, "sat": 0.12, "val": 0.42},
	{"name": "Blue", "color": Color(0.16, 0.36, 0.95), "hue": 0.61, "sat": 1.0, "val": 0.95},
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
## Body colour: repaints the Halo Forge's white armour plates (shaders/hit_flash.gdshader `body_recolor`,
## showcase_recolor.gdshader); index 0 keeps them white.
const BODY: Array[Dictionary] = [
	{"name": "White", "color": Color(0.93, 0.94, 0.96), "none": true},
	{"name": "Graphite", "color": Color(0.36, 0.38, 0.42)},
	{"name": "Navy", "color": Color(0.24, 0.36, 0.66)},
	{"name": "Crimson", "color": Color(0.74, 0.16, 0.18)},
	{"name": "Sand", "color": Color(0.84, 0.74, 0.54)},
]
const DEFAULT_LOOK := {"armor": 0, "energy": 1, "booster": 0, "body": 0}
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
	# One in each fist, firing in turn (player/mech.gd _fire_bolts, art: art_src/weapons/build_beam_pistol.py).
	{"id": &"dual_pistols", "name": "Dual Beam Pistols", "waves": 6, "icon": "dual_pistols", "stats": [1, 5, 2],
		"desc": "A beam pistol in each hand firing in turn: a blistering stream of quick light shots. Low damage per hit and short range, but you keep full speed while firing."},
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
## THREAT TIERS (past Extreme; Hades' Heat / Brotato's Danger levels): on Extreme, THREAT 1-10 each add one
## more condition (cumulative) and +THREAT_SCRAP scrap. Win a run on Extreme to open THREAT 1, and a run
## at THREAT N to open N+1 ("win" = beat an arena's boss, or survive Endless wave THREAT_ENDLESS_WAVE).
## The first win at each tier with each weapon pays a one-time BOUNTY (BOUNTY_SCRAP x tier scrap).
## Picked on the Loadout screen (ui/armory_page.gd); every multiplier goes through diff(), so all the
## systems that read the difficulty follow along. Keys: hp / damage / speed / bombard / boss_hp / heal
## multiply, `elite` adds to the elite chance, `escort` = elite guards that drop in with every boss.
const THREAT_MAX := 10
const THREAT_SCRAP := 0.25
const THREAT_ENDLESS_WAVE := 10
const BOUNTY_SCRAP := 1000
const THREAT_COLOR := Color(1.0, 0.36, 0.22)
const THREAT_TIERS: Array[Dictionary] = [
	{"name": "ARMORED", "desc": "Robots have +20% HP.", "hp": 1.2},
	{"name": "ELITE TIDE", "desc": "+8% chance a robot is a gold elite.", "elite": 0.08},
	{"name": "HEAVY ORDNANCE", "desc": "Robots hit 15% harder.", "damage": 1.15},
	{"name": "BOMBARDMENT", "desc": "Artillery falls 60% more often.", "bombard": 1.6},
	{"name": "BOSS ESCORT", "desc": "Bosses bring 3 elite guards and +25% HP.", "boss_hp": 1.25, "escort": 3},
	{"name": "SCARCE REPAIRS", "desc": "Every repair heals 35% less.", "heal": 0.65},
	{"name": "OVERCLOCKED", "desc": "Robots move 12% faster.", "speed": 1.12},
	{"name": "FORTIFIED", "desc": "Robots have another +25% HP.", "hp": 1.25},
	{"name": "ELITE LEGION", "desc": "Another +8% chance of gold elites.", "elite": 0.08},
	{"name": "APEX", "desc": "Robots hit 20% harder, bosses +25% HP.", "damage": 1.2, "boss_hp": 1.25},
]
## Chosen tier (only counts on Extreme, see threat_level), highest tier open, highest tier won, and the
## bounties claimed ("weapon:tier" -> true). Saved.
var threat := 0
var threat_unlocked := 0
var threat_best := 0
var bounties := {}
## Best difficulty each arena was cleared on (arena index -> DIFFICULTIES index; the Contracts read it).
var arena_best_diff := {}
## CONTRACTS (autoload/contracts.gd keeps the logic; the progress lives here so it saves with the rest):
## lifetime counters, and the contracts completed / claimed.
var contract_stats := {}
var contracts_done: Array[StringName] = []
var contracts_claimed: Array[StringName] = []

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
## Settings: DYNAMIC CAMERA (zoom follows the fight, punch-ins, boss focus - player/mech_camera.gd),
## controller RUMBLE (Combat.rumble) and floating DAMAGE NUMBERS (Combat.damage_number). All on by default.
var dynamic_camera := true
var rumble := true
var damage_numbers := true
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
## id -> name, what one level does, max level, cost of each level, and `mk`: what every MK level past
## the max adds (ENDLESS HANGAR: a maxed row keeps going as MK II, MK III... forever, each MK level +2%
## to the row's stat - see hangar_mk() - at HANGAR_MK_COST x the last price).
## Every scrap number is x10 since save version 2 (SAVE_VERSION; older saves are converted on load).
const HANGAR := {
	&"frame": {"name": "Reinforced Frame", "desc": "+10 max HP per level", "max": 5,
		"cost": [400, 800, 1400, 2200, 3200], "mk": "+2% max HP"},
	&"calibration": {"name": "Weapon Calibration", "desc": "+5% damage per level", "max": 5,
		"cost": [500, 1000, 1600, 2400, 3400], "mk": "+2% damage"},
	&"servos": {"name": "Servo Motors", "desc": "+4% move speed per level", "max": 3, "cost": [400, 900, 1600],
		"mk": "+2% move speed"},
	&"analytics": {"name": "Combat Analytics", "desc": "+6% XP per level", "max": 3, "cost": [700, 1400, 2300],
		"mk": "+2% XP"},
	&"kits": {"name": "Spare Repair Kits", "desc": "+1 repair kit per level", "max": 2, "cost": [1200, 2600],
		"mk": "+2% repair kit healing"},
	&"head_start": {"name": "Head Start", "desc": "Start every run with a free upgrade pick (per level)", "max": 2,
		"cost": [1500, 3500], "mk": "+2% chance of one more free pick", "mk_cap": 1.0},
	&"last_stand": {"name": "Last Stand", "desc": "Once per arena, survive a fatal hit with 1 HP", "max": 1,
		"cost": [2500], "mk": "+2% max HP left when it saves you", "mk_cap": 0.5},
	&"salvage_rights": {"name": "Salvage Rights", "desc": "+10% scrap per level", "max": 3, "cost": [600, 1200, 2000],
		"mk": "+2% scrap"},
	&"rerolls": {"name": "Tactical Uplink", "desc": "+1 level-up reroll per run (per level)", "max": 3,
		"cost": [1000, 2000, 3000], "mk": "+2% chance a reroll is free", "mk_cap": 0.5},
	&"banishes": {"name": "Purge Protocol", "desc": "+1 level-up banish per run (per level)", "max": 2,
		"cost": [1500, 3000], "mk": "+2% chance a banish is free", "mk_cap": 0.5},
	# Locked until the "Gold Rush" contract is done (`lock` = contract id, see hangar_locked).
	&"beacon": {"name": "Salvager Beacon", "desc": "Gold Salvagers show up 12% more often per level", "max": 3,
		"cost": [1500, 3000, 5000], "mk": "+2% SCRAP FRENZY time", "lock": &"gold_rush"},
}
## ENDLESS HANGAR: each MK level adds this much (a fraction) to its row's stat (chance-type rows stop at
## their `mk_cap`; the stat rows never stop)...
const HANGAR_MK_STEP := 0.02
## ...and costs this much more than the level before it (MK II = the last listed cost x1.15).
const HANGAR_MK_COST := 1.15
## Mech chassis (Hangar): multipliers on the standard frame. `ability` is the frame's signature trick
## (player/mech.gd), `role` the frame class shown under the name, `sheet` the mech design whose sprite sheet
## it flies (assets/sprites/mechs/<sheet>/, see chassis_frames; designs in Mech Designs\New 10 - DESIGNS.md).
const CHASSIS: Array[Dictionary] = [
	{"id": &"standard", "name": "NIMBUS-07", "role": "Standard frame", "sheet": &"nimbus", "cost": 0, "hp": 1.0,
		"speed": 1.0, "boost_cd": 1.0, "boost_speed": 1.0, "taken": 1.0, "scale": 1.0, "color": Color(1.0, 0.84, 0.4),
		"ability": "ADAPTIVE CORE: level-ups offer 4 upgrade cards instead of 3.", "desc": "The all-rounder: solid armor, solid speed."},
	{"id": &"striker", "name": "ARROWHEAD", "role": "Striker frame", "sheet": &"arrowhead", "cost": 2500, "hp": 0.75,
		"speed": 1.18, "boost_cd": 0.6, "boost_speed": 1.15, "taken": 1.0, "scale": 0.82, "color": Color(0.3, 1.0, 0.85),
		"ability": "AFTERBURNER: boost slices through robots, and every kill recharges your boost faster.",
		"desc": "Light and fast: -25% HP, +18% speed, boost recharges 40% faster."},
	{"id": &"bulwark", "name": "RAMPART", "role": "Bulwark frame", "sheet": &"rampart", "cost": 3500, "hp": 1.5,
		"speed": 0.86, "boost_cd": 1.2, "boost_speed": 0.9, "taken": 0.8, "scale": 1.25, "color": Color(1.0, 0.55, 0.25),
		"ability": "SIEGE MODE: hold still to brace (+30% damage, -30% damage taken); boost rams robots aside.",
		"desc": "Heavy armor: +50% HP, takes 20% less damage, but slower."},
	{"id": &"artillery", "name": "TEMPEST", "role": "Artillery frame", "sheet": &"tempest", "cost": 4500,
		"hp": 1.15, "speed": 0.92, "boost_cd": 1.1, "boost_speed": 0.95, "taken": 0.95, "scale": 1.12,
		"color": Color(1.0, 0.9, 0.2),
		"ability": "SALVO: the shoulder pods fire 4 heavy homing rockets at nearby robots every 4 seconds.",
		"desc": "Walking artillery: +15% HP, takes 5% less damage, a little slower."},
	{"id": &"duelist", "name": "ONIBI", "role": "Duelist frame", "sheet": &"onibi", "cost": 5000, "hp": 0.9,
		"speed": 1.08, "boost_cd": 0.85, "boost_speed": 1.05, "taken": 1.0, "scale": 0.95, "color": Color(1.0, 0.34, 0.32),
		"ability": "IAIDO: melee weapons hit 30% harder and build Overdrive 50% faster; melee kills heal 3 HP.",
		"desc": "A blade master: guns deal 20% less damage, -10% HP, +8% speed."},
	{"id": &"guardian", "name": "SOLSTICE", "role": "Guardian frame", "sheet": &"solstice", "cost": 5500, "hp": 1.1,
		"speed": 0.95, "boost_cd": 1.0, "boost_speed": 1.0, "taken": 1.0, "scale": 1.12, "color": Color(1.0, 0.8, 0.3),
		"ability": "BARRIER: always carries a shield charge that recharges 25% faster; when it breaks it blasts robots back.",
		"desc": "Defensive frame: +10% HP and +1 Defense Shield charge, a little slower."},
	{"id": &"carrier", "name": "CORVID", "role": "Carrier frame", "sheet": &"corvid", "cost": 6000, "hp": 0.85,
		"speed": 1.03, "boost_cd": 1.0, "boost_speed": 1.0, "taken": 1.05, "scale": 0.98, "color": Color(0.72, 0.48, 1.0),
		"ability": "FEATHER SWARM: launches with 2 Bit Drones (the upgrade adds a 3rd), and kills can fire homing feathers.",
		"desc": "Lets its drones fight: -15% HP, takes 5% more damage."},
	{"id": &"phantom", "name": "VESPER", "role": "Phantom frame", "sheet": &"vesper", "cost": 7000, "hp": 0.8,
		"speed": 1.1, "boost_cd": 0.7, "boost_speed": 1.0, "taken": 1.0, "scale": 0.9, "color": Color(1.0, 0.42, 0.85),
		"ability": "PHASE BLINK: boost is an instant blink, and attacks within 1.5 s of a blink are critical (x2 damage).",
		"desc": "Glass cannon: -20% HP, +10% speed, boost recharges 30% faster."},
]
## Where a chassis's rendered sprite frames live (the Blender pipeline writes frames.tres + frames_nogun.tres).
const MECH_SPRITES := "res://assets/sprites/mechs/%s/%s.tres"
const NIMBUS_FRAMES := "res://assets/sprites/gundam_frames.tres"
const NIMBUS_FRAMES_NOGUN := "res://assets/sprites/gundam_frames_nogun.tres"
var _frames_cache := {}
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
## What the last bank_scrap() added (the results screen shows it), split like run_scrap_parts.
var last_banked := 0
var last_parts := {}

## LIVE SCRAP: what one robot / wave / boss / arena clear pays (x the multipliers in earn_scrap). A kill
## pays its XP value / 3 x10 (at least SCRAP_KILL), bosses SCRAP_BOSS on top.
const SCRAP_KILL := 10.0
const SCRAP_PER_XP := 10.0 / 3.0
const SCRAP_BOSS := 250.0
const SCRAP_WAVE := 50.0
const SCRAP_CLEAR := 400.0
## Order + labels of the results screen's breakdown (the `part` given to earn_scrap / credit_scrap).
const SCRAP_PARTS := [[&"kills", "Kills"], [&"waves", "Waves"], [&"boss", "Boss"], [&"arena", "Arena clear"],
	[&"gold", "Gold Salvager"], [&"bounty", "Bounty"]]
## GOLD SALVAGER prize SCRAP FRENZY: every scrap gain x FRENZY_MULT for FRENZY_TIME seconds (the extra is
## filed under "gold"). `frenzy_t` = seconds left (counts down only while the game runs).
const FRENZY_MULT := 7.0
const FRENZY_TIME := 20.0
var frenzy_t := 0.0
## Gold Salvager spawn spacing: the Hangar's Salvager Beacon makes them 12% more frequent per level.
const BEACON_STEP := 0.12
const SCRAP_CHIP := preload("res://environment/props/scrap_chip.gd")
## This run's scrap by source (keys from SCRAP_PARTS).
var run_scrap_parts := {}
## Kill scrap is credited at once, but its SCRAP CHIPS take a moment to fly to the mech: this much of
## run_scrap is still in the air (the HUD ticker shows run_scrap minus it, so it rolls up as they land).
var scrap_in_flight := 0.0
## Bumped whenever the run's scrap is banked / reset, so chips left over from an earlier run are ignored.
var _scrap_epoch := 0

## Save file layout version: 2 = scrap x10 (older banks are multiplied on load, see _load).
const SAVE_VERSION := 2

## WEAPON MASTERY: kills in real runs feed the equipped weapon's mastery (the robot's XP value, bosses
## capped at MASTERY_BOSS_XP). Levels 1-10 on a rising curve; every level is +2% damage with that weapon
## (mech.gd scales its primary fire), LV 5 adds FINISHER (its hits on robots under 35% HP land 25%
## harder, see Enemy.take_damage) and LV 10 is MASTERED (gold name badge in the HUD and the Armory).
const MASTERY_MAX := 10
## Total mastery XP for each level (index 0 = LV 1).
const MASTERY_XP: Array[int] = [30, 75, 140, 230, 360, 550, 830, 1230, 1820, 2670]
const MASTERY_DAMAGE := 0.02
const MASTERY_FINISHER_LEVEL := 5
const MASTERY_FINISHER_HP := 0.35
const MASTERY_FINISHER_MULT := 1.25
const MASTERY_BOSS_XP := 30
## weapon id -> mastery XP (saved).
var mastery := {}
var _mastery_dirty := false

## ARMORY MASTERY POOL (Melvor Idle's mastery pool): every point of weapon mastery XP a real run earns also
## fills one shared pool - mastered weapons included, so kills keep paying after LV 10 - plus
## POOL_LEVEL_BONUS for every mastery level any weapon gains (fresh weapons level fastest, so trying other
## weapons fills it quicker). Passing a checkpoint (a share of POOL_MAX) switches its perk on for good:
## +5% scrap (scrap_mult), +1 level-up reroll every run (Upgrades.reset), +10% XP (Upgrades.add_xp) and
## FINISHER on every weapon (has_finisher). Saved in [mastery] pool; an older save starts with what its
## mastery so far is worth (see _seed_pool).
const POOL_MAX := 20000
const POOL_LEVEL_BONUS := 150
const POOL_CHECKPOINTS: Array[Dictionary] = [
	{"at": 0.10, "perk": "+5% scrap", "short": "+5% SCRAP"},
	{"at": 0.25, "perk": "+1 level-up reroll every run", "short": "+1 REROLL"},
	{"at": 0.50, "perk": "+10% XP", "short": "+10% XP"},
	{"at": 0.95, "perk": "FINISHER on every weapon", "short": "FINISHER ALL"},
]
const POOL_SCRAP := 0.05
const POOL_XP := 0.1
var mastery_pool := 0

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
			look = {"armor": int(v[0]), "energy": int(v[1]), "booster": int(v[2]), "body": int(v[3]) if v.size() > 3 else 0}
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
		elif a.begins_with("--hangar="):  # debug: --hangar=frame:3,last_stand:1 (not saved; past the max = MK levels)
			for part in a.trim_prefix("--hangar=").split(","):
				var kv := part.split(":")
				hangar[StringName(kv[0])] = int(kv[1])
		elif a.begins_with("--mastery="):  # debug: --mastery=blaster:600,sword:2670 (weapon mastery XP; use --temp-save)
			for part in a.trim_prefix("--mastery=").split(","):
				var kv := part.split(":")
				mastery[StringName(kv[0])] = int(kv[1])
		elif a.begins_with("--pool="):  # debug (use --temp-save): Armory Mastery Pool XP
			mastery_pool = clampi(int(a.trim_prefix("--pool=")), 0, POOL_MAX)
		elif a.begins_with("--threat="):  # debug (use with --temp-save): pick + open THREAT N (Extreme only)
			threat = clampi(int(a.trim_prefix("--threat=")), 0, THREAT_MAX)
			threat_unlocked = maxi(threat_unlocked, threat)
		elif a.begins_with("--contract-stat="):  # debug (use --temp-save): --contract-stat=kills=120,w:blaster=40
			for part in a.trim_prefix("--contract-stat=").split(","):
				var kv := part.rsplit("=", true, 1)
				contract_stats[kv[0]] = int(kv[1])
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


## SCRAP FRENZY counts down only while the game runs (not in the level-up menu or the pause menu).
func _process(delta: float) -> void:
	if frenzy_t > 0.0 and not get_tree().paused:
		frenzy_t = maxf(frenzy_t - delta, 0.0)


func _on_enemy_killed(e: Node) -> void:
	kills += 1
	if not scrap_enabled or not (e is Enemy):
		return
	# Scrap: a third of the robot's XP value (x10), bosses SCRAP_BOSS on top - flown to the mech as chips.
	var boss := e.is_in_group("boss")
	var got := earn_scrap(maxf(SCRAP_KILL, Upgrades.xp_value(e) * SCRAP_PER_XP) + (SCRAP_BOSS if boss else 0.0),
		&"boss" if boss else &"kills")
	_drop_scrap((e as Node2D).global_position, got, 12 if boss else clampi(ceili(got / 12.0), 1, 5))
	# Weapon mastery for whatever the mech is wielding.
	add_mastery(weapon, mini(Upgrades.xp_value(e), MASTERY_BOSS_XP))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		bank_scrap()


# --- hangar ---------------------------------------------------------------------------------------------

## Adds scrap to this run (scrap_mult applied), filed under `part` (one of SCRAP_PARTS) for the results
## screen. During a SCRAP FRENZY the gain is x FRENZY_MULT, the extra filed under "gold". Returns what was
## actually added.
func earn_scrap(amount: float, part := &"kills") -> float:
	if not scrap_enabled:
		return 0.0
	var got := amount * scrap_mult()
	_file_scrap(got, part)
	if frenzy_t > 0.0:
		var extra := got * (FRENZY_MULT - 1.0)
		_file_scrap(extra, &"gold")
		got += extra
	return got


## Every multiplier on earned scrap: difficulty (+ Threat), Salvage Rights (+ MK), the Endless twist, the
## Contracts' row bonuses, the SALVAGE PROTOCOL level-up card and the Mastery Pool's first checkpoint.
func scrap_mult() -> float:
	return diff("scrap") * (1.0 + 0.1 * hangar_level(&"salvage_rights") + hangar_mk_bonus(&"salvage_rights")) \
		* twist_value("scrap") * Contracts.scrap_mult() * Upgrades.salvage_protocol_mult() \
		* (1.0 + POOL_SCRAP if pool_reached(0) else 1.0) * Parts.mult("scrap")


## Scrap paid as it is (Gold Salvager prizes, Threat bounties): no multipliers. Returns what was added (0
## outside real runs).
func credit_scrap(amount: float, part: StringName) -> float:
	if not scrap_enabled or amount <= 0.0:
		return 0.0
	_file_scrap(amount, part)
	return amount


func _file_scrap(amount: float, part: StringName) -> void:
	run_scrap += amount
	run_scrap_parts[part] = float(run_scrap_parts.get(part, 0.0)) + amount


## GOLD SALVAGER prize: SCRAP FRENZY for FRENZY_TIME s (+2% per Salvager Beacon MK level); a second one
## while it runs adds the time on top.
func start_frenzy() -> void:
	frenzy_t += FRENZY_TIME * (1.0 + hangar_mk_bonus(&"beacon"))


## Gold Salvager spacing multiplier (Salvager Beacon: 12% more often per level).
func salvager_interval_mult() -> float:
	return 1.0 - BEACON_STEP * hangar_level(&"beacon")


## Sprays already credited scrap at `pos` as `chips` gold chips that fly to the mech.
func drop_scrap(pos: Vector2, amount: float, chips: int) -> void:
	_drop_scrap(pos, amount, chips)


## A bonus with no chips (wave / arena clear): credited at once, and the HUD pop names it.
func _scrap_bonus(amount: float, part: StringName, label: String) -> void:
	var got := earn_scrap(amount, part)
	if got > 0.0:
		scrap_bonus.emit(got, label)


## Sprays `amount` of (already credited) scrap at `pos` as `chips` gold chips that fly to the mech.
func _drop_scrap(pos: Vector2, amount: float, chips: int) -> void:
	if amount <= 0.0:
		return
	scrap_in_flight += amount
	var world := Combat.world()
	for i in chips:
		var c: Node2D = SCRAP_CHIP.new()
		c.value = amount / chips
		c.epoch = _scrap_epoch
		c.position = pos
		c.pop = Vector2.from_angle(randf() * TAU) * randf_range(70.0, 160.0 + chips * 14.0)
		world.add_child.call_deferred(c)


## A scrap chip reached the mech (or vanished with its scene): it no longer counts as in flight.
func land_scrap(amount: float, epoch: int) -> void:
	if epoch == _scrap_epoch:
		scrap_in_flight = maxf(scrap_in_flight - amount, 0.0)


## What the HUD's scrap ticker shows: this run's scrap minus the chips still flying in.
func run_scrap_landed() -> float:
	return maxf(run_scrap - scrap_in_flight, 0.0)


## Moves this run's scrap into the bank (and saves). Returns what was added; last_parts keeps its
## breakdown (whole numbers that add up to it) for the results screen.
func bank_scrap() -> int:
	last_banked = roundi(run_scrap)
	last_parts = _whole_parts(run_scrap_parts, last_banked)
	run_scrap = 0.0
	run_scrap_parts.clear()
	scrap_in_flight = 0.0
	_scrap_epoch += 1
	if last_banked > 0 or _mastery_dirty:
		scrap += last_banked
		if last_banked > 0:
			run_banked.emit(last_banked, last_parts)
		save()
	return last_banked


## Rounds each part, then puts the rounding left-over on the biggest, so the parts sum to `total`.
static func _whole_parts(parts: Dictionary, total: int) -> Dictionary:
	var out := {}
	var sum := 0
	var big: Variant = null
	for k in parts:
		out[k] = roundi(float(parts[k]))
		sum += int(out[k])
		if big == null or float(parts[k]) > float(parts[big]):
			big = k
	if big != null:
		out[big] = int(out[big]) + total - sum
	return out


## Base level of `id`, capped at the row's max (levels bought past it are MK levels, see hangar_mk).
func hangar_level(id: StringName) -> int:
	var l := int(hangar.get(id, 0))
	return mini(l, int(HANGAR[id]["max"])) if HANGAR.has(id) else l


## ENDLESS HANGAR: MK levels bought past the row's max (1 = MK II, 2 = MK III...).
func hangar_mk(id: StringName) -> int:
	return maxi(int(hangar.get(id, 0)) - int(HANGAR[id]["max"]), 0) if HANGAR.has(id) else 0


## The row's MK bonus as a fraction (+2% per MK level, up to the row's `mk_cap` if it has one).
func hangar_mk_bonus(id: StringName) -> float:
	var b := HANGAR_MK_STEP * hangar_mk(id)
	return minf(b, float(HANGAR[id]["mk_cap"])) if HANGAR.has(id) and HANGAR[id].has("mk_cap") else b


## Most MK levels a capped row can take (-1 = no limit).
func hangar_mk_max(id: StringName) -> int:
	var info: Dictionary = HANGAR[id]
	return ceili(float(info["mk_cap"]) / HANGAR_MK_STEP - 0.001) if info.has("mk_cap") else -1


## "MK II" for the first MK level, "MK III" for the next... ("" before any).
func hangar_mk_name(id: StringName, extra := 0) -> String:
	var mk := hangar_mk(id) + extra
	return "" if mk <= 0 else "MK " + roman(mk + 1)


## Cost of the next level of `id`: the listed costs, then MK levels forever, each HANGAR_MK_COST times
## the one before (rounded to 10). -1 only when a capped row (`mk_cap`) is full.
func hangar_cost(id: StringName) -> int:
	var info: Dictionary = HANGAR[id]
	var l := int(hangar.get(id, 0))
	var costs: Array = info["cost"]
	if l < int(info["max"]):
		return int(costs[l])
	var mk := l - int(info["max"]) + 1
	if hangar_mk_max(id) >= 0 and mk > hangar_mk_max(id):
		return -1
	return roundi(float(costs[-1]) * pow(HANGAR_MK_COST, mk) / 10.0) * 10


func buy_hangar(id: StringName) -> bool:
	var c := hangar_cost(id)
	if c < 0 or scrap < c or hangar_locked(id):
		return false
	scrap -= c
	hangar[id] = int(hangar.get(id, 0)) + 1
	hangar_bought.emit(id)
	save()
	return true


## A Hangar row with a `lock` (a contract id) stays locked until that contract is done.
func hangar_locked(id: StringName) -> bool:
	return HANGAR.has(id) and HANGAR[id].has("lock") and not Contracts.is_done(HANGAR[id]["lock"])


## Roman numerals (MK names); plain digits from 4000 up.
static func roman(n: int) -> String:
	if n <= 0 or n >= 4000:
		return str(n)
	var out := ""
	for p: Array in [[1000, "M"], [900, "CM"], [500, "D"], [400, "CD"], [100, "C"], [90, "XC"], [50, "L"], [40, "XL"],
			[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]:
		while n >= int(p[0]):
			out += String(p[1])
			n -= int(p[0])
	return out


## 12345 -> "12,345" (scrap amounts).
static func fmt_int(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# --- weapon mastery --------------------------------------------------------------------------------------

func mastery_xp(id: StringName) -> int:
	return int(mastery.get(id, 0))


func mastery_level(id: StringName) -> int:
	var x := mastery_xp(id)
	var l := 0
	while l < MASTERY_MAX and x >= MASTERY_XP[l]:
		l += 1
	return l


## [XP into the current level, XP the level needs] (both 0 once mastered).
func mastery_progress(id: StringName) -> Vector2i:
	var l := mastery_level(id)
	if l >= MASTERY_MAX:
		return Vector2i.ZERO
	var lo := 0 if l == 0 else MASTERY_XP[l - 1]
	return Vector2i(mastery_xp(id) - lo, MASTERY_XP[l] - lo)


## How far into its current mastery level `id` is (1 when mastered).
func mastery_fraction(id: StringName) -> float:
	var p := mastery_progress(id)
	return 1.0 if p.y <= 0 else clampf(float(p.x) / p.y, 0.0, 1.0)


## Damage multiplier for `id`'s own attacks: +2% per mastery level.
func mastery_damage_mult(id: StringName) -> float:
	return 1.0 + MASTERY_DAMAGE * mastery_level(id)


## LV 5 perk: FINISHER (hits on robots under MASTERY_FINISHER_HP of their HP deal x1.25) - for every weapon
## once the Mastery Pool's last checkpoint is reached.
func has_finisher(id: StringName) -> bool:
	return mastery_level(id) >= MASTERY_FINISHER_LEVEL or pool_reached(3)


## LV 10: MASTERED (gold name badge).
func is_mastered(id: StringName) -> bool:
	return mastery_level(id) >= MASTERY_MAX


## Adds mastery XP to `id` (saved when the run banks, or right away on a level-up), and the same to the
## MASTERY POOL (plus POOL_LEVEL_BONUS per level gained). A mastered weapon only feeds the pool.
func add_mastery(id: StringName, amount: int) -> void:
	if amount <= 0 or not WEAPONS.any(func(w: Dictionary) -> bool: return w["id"] == id):
		return
	add_pool(amount)
	if is_mastered(id):
		return
	var before := mastery_level(id)
	mastery[id] = mastery_xp(id) + amount
	_mastery_dirty = true
	var now := mastery_level(id)
	if now > before:
		add_pool(POOL_LEVEL_BONUS * (now - before))
		save()
		mastery_up.emit(id, now)


# --- armory mastery pool ---------------------------------------------------------------------------------

## Pool XP needed for checkpoint `i`.
func pool_checkpoint_xp(i: int) -> int:
	return roundi(POOL_MAX * float(POOL_CHECKPOINTS[i]["at"]))


func pool_reached(i: int) -> bool:
	return mastery_pool >= pool_checkpoint_xp(i)


## How many checkpoints are reached (they're in order).
func pool_checkpoints_reached() -> int:
	var n := 0
	for i in POOL_CHECKPOINTS.size():
		if pool_reached(i):
			n = i + 1
	return n


func pool_fraction() -> float:
	return clampf(float(mastery_pool) / POOL_MAX, 0.0, 1.0)


## Fills the pool (up to POOL_MAX); every checkpoint passed is announced (pool_checkpoint) and saved.
func add_pool(amount: int) -> void:
	if amount <= 0 or mastery_pool >= POOL_MAX:
		return
	var before := pool_checkpoints_reached()
	mastery_pool = mini(mastery_pool + amount, POOL_MAX)
	_mastery_dirty = true
	var now := pool_checkpoints_reached()
	for i in range(before, now):
		pool_checkpoint.emit(i)
	if now > before:
		save()


## A save from before the pool: it starts with what the mastery earned so far is worth.
func _seed_pool() -> int:
	var total := 0
	for id in mastery:
		total += mastery_xp(id) + POOL_LEVEL_BONUS * mastery_level(id)
	return mini(total, POOL_MAX)


func chassis_info(id: StringName = &"") -> Dictionary:
	var want := chassis if id == &"" else id
	for c in CHASSIS:
		if c["id"] == want:
			return c
	return CHASSIS[0]


## Sprite frames a chassis flies: its own design's sheet once rendered (MECH_SPRITES), else NIMBUS-07's.
## `gun` = the frames with the painted Beam Rifle (only shown with the blaster).
func chassis_frames(id: StringName = &"", gun := true) -> SpriteFrames:
	var sheet := String(chassis_info(id).get("sheet", &"nimbus"))
	var key := sheet + ("" if gun else ":nogun")
	if not _frames_cache.has(key):
		var path := MECH_SPRITES % [sheet, "frames" if gun else "frames_nogun"]
		if not ResourceLoader.exists(path):
			path = NIMBUS_FRAMES if gun else NIMBUS_FRAMES_NOGUN
		_frames_cache[key] = load(path)
	return _frames_cache[key]


## True while a chassis has no art of its own yet (it borrows NIMBUS-07's sheet, tinted its colour).
func chassis_placeholder(id: StringName = &"") -> bool:
	var sheet := String(chassis_info(id).get("sheet", &"nimbus"))
	return sheet != "nimbus" and not ResourceLoader.exists(MECH_SPRITES % [sheet, "frames"])


## Tint for a chassis drawn with NIMBUS-07's art (white when it has its own sheet).
func chassis_tint(id: StringName = &"") -> Color:
	if not chassis_placeholder(id):
		return Color.WHITE
	return Color.WHITE.lerp(chassis_info(id)["color"], 0.45)


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
	if wave == THREAT_ENDLESS_WAVE and scrap_enabled and is_extreme():
		_threat_win()
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


## Applies the trim paint and the body colour to a ShaderMaterial using shaders/hit_flash.gdshader.
func apply_armor(mat: ShaderMaterial, armor_index := -1, body_index := -1) -> void:
	var a: Dictionary = ARMOR[clampi(armor_index if armor_index >= 0 else look["armor"], 0, ARMOR.size() - 1)]
	mat.set_shader_parameter("recolor", not a.get("none", false))
	if not a.get("none", false):
		mat.set_shader_parameter("target_hue", a["hue"])
		mat.set_shader_parameter("sat_mult", a["sat"])
		mat.set_shader_parameter("val_mult", a["val"])
	var b: Dictionary = BODY[clampi(body_index if body_index >= 0 else int(look.get("body", 0)), 0, BODY.size() - 1)]
	mat.set_shader_parameter("body_recolor", not b.get("none", false))
	mat.set_shader_parameter("body_color", b["color"])


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
	_scrap_bonus(SCRAP_CLEAR, &"arena", "ARENA CLEAR")
	if not cleared.has(arena_index):
		cleared.append(arena_index)
	if scrap_enabled and difficulty > int(arena_best_diff.get(arena_index, -1)):
		arena_best_diff[arena_index] = difficulty
	arena_won.emit(arena_index)
	_threat_win()
	save()
	return check_unlocks()


# --- threat tiers ----------------------------------------------------------------------------------------

func is_extreme() -> bool:
	return difficulty == DIFFICULTIES.size() - 1


## The THREAT tier in effect (0 unless the difficulty is Extreme).
func threat_level() -> int:
	return clampi(threat, 0, THREAT_MAX) if is_extreme() else 0


## Loadout screen: pick a tier (up to the highest one open).
func set_threat(t: int) -> void:
	threat = clampi(t, 0, mini(threat_unlocked, THREAT_MAX))
	save()


static func bounty_key(id: StringName, tier: int) -> String:
	return "%s:%d" % [id, tier]


func bounty_claimed(id: StringName, tier: int) -> bool:
	return bounties.has(bounty_key(id, tier))


## Highest THREAT tier won with weapon `id` (0 = none yet).
func weapon_threat_best(id: StringName) -> int:
	var best := 0
	for t in range(1, THREAT_MAX + 1):
		if bounty_claimed(id, t):
			best = t
	return best


## Elite guards that drop in with every boss at the current threat (BOSS ESCORT).
func threat_escort() -> int:
	var n := 0
	for i in threat_level():
		n += int(THREAT_TIERS[i].get("escort", 0))
	return n


## A run on Extreme was won (an arena's boss beaten, or Endless wave THREAT_ENDLESS_WAVE survived): opens the
## next THREAT tier, records the best, and pays the weapon's one-time BOUNTY for this tier.
func _threat_win() -> void:
	if not scrap_enabled or not is_extreme():
		return
	var t := threat_level()
	var opened := false
	if t >= threat_unlocked and threat_unlocked < THREAT_MAX:
		threat_unlocked = t + 1
		opened = true
	threat_best = maxi(threat_best, t)
	var bounty := 0
	if t >= 1 and not bounty_claimed(weapon, t):
		bounties[bounty_key(weapon, t)] = true
		bounty = BOUNTY_SCRAP * t
		credit_scrap(bounty, &"bounty")
		scrap_bonus.emit(float(bounty), "BOUNTY")
	threat_won.emit(t, bounty, opened)


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
	_scrap_bonus(SCRAP_WAVE, &"waves", "WAVE")
	wave_won.emit()
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

## Current difficulty's multiplier `key` (count, hp, damage, speed, boss_hp, bombard, heal, elite, scrap...),
## with the THREAT tiers in effect on top (see THREAT_TIERS): `elite` adds, `scrap` gets +THREAT_SCRAP per
## tier, the rest multiply.
func diff(key: String) -> float:
	var v: float = DIFFICULTIES[difficulty][key]
	var t := threat_level()
	if t <= 0:
		return v
	if key == "scrap":
		return v * (1.0 + THREAT_SCRAP * t)
	for i in t:
		var tier: Dictionary = THREAT_TIERS[i]
		if tier.has(key):
			v = v + float(tier[key]) if key == "elite" else v * float(tier[key])
	return v


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
	cfg.set_value("settings", "dynamic_camera", dynamic_camera)
	cfg.set_value("settings", "rumble", rumble)
	cfg.set_value("settings", "damage_numbers", damage_numbers)
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
	cfg.set_value("progress", "save_version", SAVE_VERSION)
	cfg.set_value("hangar", "scrap", scrap)
	cfg.set_value("hangar", "upgrades", hangar)
	var mxp := {}
	for id in mastery:
		mxp[String(id)] = int(mastery[id])
	cfg.set_value("mastery", "xp", mxp)
	cfg.set_value("mastery", "pool", mastery_pool)
	_mastery_dirty = false
	cfg.set_value("progress", "threat", threat)
	cfg.set_value("progress", "threat_unlocked", threat_unlocked)
	cfg.set_value("progress", "threat_best", threat_best)
	cfg.set_value("progress", "bounties", bounties.keys())
	cfg.set_value("progress", "arena_best_diff", arena_best_diff)
	cfg.set_value("contracts", "stats", contract_stats)
	var done_names: Array[String] = []
	for id in contracts_done:
		done_names.append(String(id))
	cfg.set_value("contracts", "done", done_names)
	var claimed_names: Array[String] = []
	for id in contracts_claimed:
		claimed_names.append(String(id))
	cfg.set_value("contracts", "claimed", claimed_names)
	cfg.set_value("hangar", "chassis", String(chassis))
	var owned: Array[String] = []
	for id in chassis_owned:
		owned.append(String(id))
	cfg.set_value("hangar", "chassis_owned", owned)
	cfg.set_value("mech", "look", look)
	cfg.set_value("mech", "weapon", String(range_restore if range_restore != &"" else weapon))
	Parts.save_to(cfg)  # [parts]: owned + equipped mech parts (autoload/parts.gd)
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
	dynamic_camera = bool(cfg.get_value("settings", "dynamic_camera", true))
	rumble = bool(cfg.get_value("settings", "rumble", true))
	damage_numbers = bool(cfg.get_value("settings", "damage_numbers", true))
	Controls.load_bindings(cfg.get_value("controls", "keys", {}))
	cleared.assign(cfg.get_value("progress", "cleared", []))
	var saved: Dictionary = cfg.get_value("mech", "look", {})
	for k in DEFAULT_LOOK:
		look[k] = int(saved.get(k, DEFAULT_LOOK[k]))
	endless_best = int(cfg.get_value("progress", "endless_best", 0))
	_last_first_boss = str(cfg.get_value("progress", "endless_first_boss", ""))
	radio_voice = bool(cfg.get_value("settings", "radio_voice", true))
	scrap = int(cfg.get_value("hangar", "scrap", 0))
	# Saves from before scrap went x10 (version 1): scale the bank to match the new prices. The file
	# only says version 2 once it's saved with the scaled number, so this can never apply twice.
	if int(cfg.get_value("progress", "save_version", 1)) < 2:
		scrap *= 10
	var saved_mastery: Dictionary = cfg.get_value("mastery", "xp", {})
	for k in saved_mastery:
		mastery[StringName(k)] = maxi(int(saved_mastery[k]), 0)
	mastery_pool = clampi(int(cfg.get_value("mastery", "pool", 0)), 0, POOL_MAX) if cfg.has_section_key("mastery", "pool") \
		else _seed_pool()
	threat_unlocked = clampi(int(cfg.get_value("progress", "threat_unlocked", 0)), 0, THREAT_MAX)
	threat = clampi(int(cfg.get_value("progress", "threat", 0)), 0, threat_unlocked)
	threat_best = clampi(int(cfg.get_value("progress", "threat_best", 0)), 0, THREAT_MAX)
	bounties.clear()
	for k in cfg.get_value("progress", "bounties", []):
		bounties[str(k)] = true
	arena_best_diff.clear()
	var best_diff: Dictionary = cfg.get_value("progress", "arena_best_diff", {})
	for k in best_diff:
		arena_best_diff[int(k)] = int(best_diff[k])
	contract_stats = (cfg.get_value("contracts", "stats", {}) as Dictionary).duplicate()
	contracts_done.clear()
	for n in cfg.get_value("contracts", "done", []):
		contracts_done.append(StringName(n))
	contracts_claimed.clear()
	for n in cfg.get_value("contracts", "claimed", []):
		contracts_claimed.append(StringName(n))
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
	# Mech parts (a save from before them gets the STOCK parts).
	Parts.load_from(cfg)


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
	frenzy_t = 0.0
	Contracts.start_run()


## Scene transition doors (ui/scene_shutter.gd): shut before a scene change, part after it. Off in
## headless runs (tests) and with --no-shutter.
var _shutter: SceneShutter
var _changing := false


func _change(path: String) -> void:
	if _changing:
		return  # already on its way to another scene
	var animate := DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--no-shutter")
	if animate:
		if _shutter == null:
			_shutter = SceneShutter.new()
			add_child(_shutter)
		_changing = true
		get_tree().paused = true
		await _shutter.close()
		_changing = false
		_change_now(path)
		# Part the doors once the new scene has had a frame to build.
		await get_tree().process_frame
		await get_tree().process_frame
		_shutter.open()
		return
	_change_now(path)


func _change_now(path: String) -> void:
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
