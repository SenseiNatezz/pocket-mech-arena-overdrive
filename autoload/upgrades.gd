extends Node
## Upgrades (autoload): the in-run level-up system.
##   XP       enemies drop XP shards (environment/props/xp_orb.gd); tougher enemies drop more.
##   LEVELS   every level-up pauses the game and offers 3 random upgrades (ui/level_up_menu.gd).
##            Campaign: levels 1-4 come quickly; from level 4 on each level costs level^2 XP (16, 25...).
##            Endless: the first level-up is quick (4 XP), then every level costs 5 x level^2 XP
##            (20, 45, 80, 125...) - endless waves keep growing, so leveling has to slow down with them.
##            Both get steeper in tiers after level 5 (x1.6 from level 5, x2.2 from 10, x3 from 15), and
##            MAX_LEVEL (20) is the cap: no more XP or picks after it.
##   RUN      stacks reset when a run starts from the menu, carry over on NEXT ARENA, and RESTART
##            restores the checkpoint taken when the arena started.
## Every number an upgrade changes lives in the helpers at the bottom, so the mech and the menu's
## descriptions always agree.

signal xp_changed
## A level-up pick is waiting (the level-up menu opens).
signal level_up_ready
signal upgrade_applied(id: StringName)

const XP_ORB := preload("res://environment/props/xp_orb.gd")
## Offered when every upgrade is maxed out (or too few are left to fill 3 cards).
const FIELD_REPAIR := &"field_repair"
## Endless XP cost per level from level 2 on: ENDLESS_XP_FACTOR * level^2.
const ENDLESS_XP_FACTOR := 5.0
## Highest level a run can reach.
const MAX_LEVEL := 20
## XP cost multiplier by the level you're levelling FROM: [from level, multiplier] (checked high to low).
const XP_TIERS := [[15, 3.0], [10, 2.2], [5, 1.6]]

## `only` / `not_for`: primary weapons the upgrade is limited to / never offered with.
const CATALOG := {
	&"target_lock": {"name": "Target Lock", "max": 3, "color": Color(1.0, 0.3, 0.35)},
	&"multishot": {"name": "Triple Shot", "max": 2, "color": Color(0.4, 0.85, 1.0)},
	&"shield": {"name": "Defense Shield", "max": 4, "color": Color(0.45, 0.8, 1.0)},
	&"pierce": {"name": "Piercing Rounds", "max": 3, "color": Color(0.75, 0.6, 1.0), "not_for": [&"sniper", &"rockets"]},
	&"rapid": {"name": "Rapid Fire", "max": 5, "color": Color(1.0, 0.85, 0.3)},
	&"power": {"name": "Power Core", "max": 5, "color": Color(1.0, 0.4, 0.2)},
	&"armor": {"name": "Armor Plating", "max": 4, "color": Color(0.55, 0.7, 0.85)},
	&"thrusters": {"name": "Thrusters", "max": 3, "color": Color(0.3, 0.95, 1.0)},
	&"blades": {"name": "Orbit Blades", "max": 3, "color": Color(0.85, 0.5, 1.0)},
	&"explosive": {"name": "Explosive Rounds", "max": 3, "color": Color(1.0, 0.5, 0.15), "not_for": [&"rockets"]},
	&"salvage": {"name": "Salvage Repair", "max": 3, "color": Color(0.4, 1.0, 0.5)},
	&"heat_sink": {"name": "Heat Sink", "max": 3, "color": Color(1.0, 0.6, 0.25)},
	&"magnet": {"name": "Scavenger", "max": 2, "color": Color(0.4, 1.0, 0.85)},
}

var level := 1
var xp := 0.0
## Level-up picks waiting to be made.
var pending := 0
## True while the level-up menu is open (the HUD's pause menu stays shut meanwhile).
var choosing := false
var stacks := {}
## Shards spawned before this time fly straight to the player (see vacuum()).
var vacuum_until_ms := 0
var _checkpoint := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Combat.enemy_killed.connect(_on_enemy_killed)
	reset()


## Fresh run: level 1, no upgrades.
func reset() -> void:
	level = 1
	xp = 0.0
	pending = 0
	choosing = false
	stacks.clear()
	save_checkpoint()


func save_checkpoint() -> void:
	_checkpoint = {"level": level, "xp": xp, "stacks": stacks.duplicate()}


func restore_checkpoint() -> void:
	level = _checkpoint.get("level", 1)
	xp = _checkpoint.get("xp", 0.0)
	stacks = _checkpoint.get("stacks", {}).duplicate()
	pending = 0
	choosing = false


# --- XP -----------------------------------------------------------------------------------------------

## XP needed to go from `lvl` to `lvl + 1`: 4, 6, 8 for the first levels, then level^2 from level 4,
## times the XP_TIERS multiplier past level 5. INF at MAX_LEVEL (nothing left to earn).
func xp_to_next(lvl := -1) -> float:
	if lvl < 0:
		lvl = level
	if lvl >= MAX_LEVEL:
		return INF
	var base := 2.0 + 2.0 * lvl if lvl < 4 else float(lvl * lvl)
	if Game.is_endless() and lvl >= 2:
		base = ENDLESS_XP_FACTOR * lvl * lvl
	for t: Array in XP_TIERS:
		if lvl >= int(t[0]):
			return roundf(base * float(t[1]))
	return base


func is_max_level() -> bool:
	return level >= MAX_LEVEL


func xp_fraction() -> float:
	return 1.0 if is_max_level() else clampf(xp / xp_to_next(), 0.0, 1.0)


func add_xp(amount: float) -> void:
	if is_max_level():
		xp = 0.0
		return
	xp += amount * xp_mult()
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
	xp_changed.emit()
	if gained > 0:
		pending += gained
		Sfx.play(&"levelup", -4.0, 0.0)
		if not choosing:
			level_up_ready.emit()


## XP an enemy is worth (tougher = more; bosses drop a big haul).
func xp_value(e: Enemy) -> int:
	if e.is_in_group("boss"):
		return 30 + roundi(e.max_hp / 200.0)
	# Armor counts as extra toughness (each armor point takes armor_tier damage to strip).
	return maxi(1, roundi((e.max_hp + e.max_armor * e.armor_tier) / 45.0))


func _on_enemy_killed(e: Node) -> void:
	if not (e is Enemy) or not e.is_inside_tree():
		return
	var value := xp_value(e)
	# Split into a few shards so big kills burst into a satisfying spray.
	var shards := clampi(ceili(value / 3.0), 1, 8)
	var world := Combat.world()
	for i in shards:
		var orb: Node2D = XP_ORB.new()
		orb.value = value / float(shards)
		orb.position = e.global_position
		orb.set("pop", Vector2.from_angle(randf() * TAU) * randf_range(60.0, 180.0 + shards * 20.0))
		world.add_child.call_deferred(orb)


## Pull every XP shard on the map to the player (end of a wave / boss down). Shards dropped in the
## next second (kills that land at the same moment) are pulled in too.
func vacuum() -> void:
	vacuum_until_ms = Time.get_ticks_msec() + 1000
	for o in get_tree().get_nodes_in_group("xp_orbs"):
		o.set("vacuum", true)


# --- picks --------------------------------------------------------------------------------------------

func level_of(id: StringName) -> int:
	return stacks.get(id, 0)


func is_available(id: StringName) -> bool:
	var u: Dictionary = CATALOG[id]
	if level_of(id) >= u["max"]:
		return false
	if u.has("only") and not u["only"].has(Game.weapon):
		return false
	if u.has("not_for") and u["not_for"].has(Game.weapon):
		return false
	return true


## Up to `n` distinct random upgrades that can still be taken (topped up with Field Repair).
func roll_choices(n := 3) -> Array[StringName]:
	var pool: Array[StringName] = []
	for id: StringName in CATALOG:
		if is_available(id):
			pool.append(id)
	pool.shuffle()
	var out: Array[StringName] = []
	for id in pool.slice(0, n):
		out.append(id)
	if out.size() < n:
		out.append(FIELD_REPAIR)
	return out


func apply(id: StringName) -> void:
	if id != FIELD_REPAIR:
		stacks[id] = level_of(id) + 1
	pending = maxi(pending - 1, 0)
	upgrade_applied.emit(id)


func display_name(id: StringName) -> String:
	return "Field Repair" if id == FIELD_REPAIR else CATALOG[id]["name"]


func color(id: StringName) -> Color:
	return Color(0.4, 1.0, 0.5) if id == FIELD_REPAIR else CATALOG[id]["color"]


func max_level(id: StringName) -> int:
	return 1 if id == FIELD_REPAIR else CATALOG[id]["max"]


## What taking `id` right now does (describes the NEXT level, with real numbers).
func describe(id: StringName) -> String:
	var n := level_of(id) + 1
	var w := Game.weapon
	match id:
		&"target_lock":
			return "Aim snaps onto enemies within %d deg, and your shots curve toward targets." % roundi(aim_assist_deg(n))
		&"multishot":
			var k := multishot_count(n)
			if Game.is_melee(w):
				return "Each swing also launches %d piercing energy waves." % k
			match w:
				&"sniper":
					return "Fire %d sniper beams at once in a narrow fan." % k
				&"rockets":
					return "Fire %d rockets at once in a small fan." % k
			return "Fire %d bolts at once in a spread (%s)." % [k, "triple shot" if k == 3 else "five-way shot"]
		&"shield":
			return "Energy shield blocks %d hit%s, recharging one every %.0fs." % [
				shield_max(n), "" if shield_max(n) == 1 else "s", shield_recharge(n)]
		&"pierce":
			return "Shots pass through %d more enem%s." % [n, "y" if n == 1 else "ies"]
		&"rapid":
			return "+15%% attack speed (total +%d%%)." % (n * 15)
		&"power":
			return "+15%% damage for every weapon and ability (total +%d%%)." % (n * 15)
		&"armor":
			return "+25 max HP and repair 25 HP now (total +%d HP)." % (n * 25)
		&"thrusters":
			return "+10%% move speed, -15%% boost cooldown (total +%d%% / -%d%%)." % [n * 10, n * 15]
		&"blades":
			return "%d energy blades orbit your mech, slicing anything they touch." % blade_count(n)
		&"explosive":
			return "%d%% chance for hits to explode, damaging nearby enemies." % roundi(explosive_chance(n) * 100.0)
		&"salvage":
			return "Every kill repairs %d HP." % roundi(salvage_heal(n))
		&"heat_sink":
			return "+%d%% heat and overdrive gain from damage dealt." % roundi((heat_mult(n) - 1.0) * 100.0)
		&"magnet":
			return "XP shards fly to you from %d%% farther, and give +%d%% XP." % [
				roundi((magnet_mult(n) - 1.0) * 100.0), roundi((xp_mult(n) - 1.0) * 100.0)]
		&"field_repair":
			return "Repair 40 HP and restock one repair kit."
	return ""


# --- effect values (lvl -1 = current level) --------------------------------------------------------------

func _lv(id: StringName, lvl: int) -> int:
	return level_of(id) if lvl < 0 else lvl


func aim_assist_deg(lvl := -1) -> float:
	var l := _lv(&"target_lock", lvl)
	return 0.0 if l <= 0 else [12.0, 18.0, 26.0][l - 1]


## Bullet turn rate toward targets (radians per second).
func homing(lvl := -1) -> float:
	var l := _lv(&"target_lock", lvl)
	return 0.0 if l <= 0 else [2.5, 4.0, 6.0][l - 1]


func multishot_count(lvl := -1) -> int:
	return 1 + 2 * _lv(&"multishot", lvl)


func shield_max(lvl := -1) -> int:
	var l := _lv(&"shield", lvl)
	return 0 if l <= 0 else [1, 2, 2, 3][l - 1]


func shield_recharge(lvl := -1) -> float:
	var l := _lv(&"shield", lvl)
	return 99.0 if l <= 0 else [10.0, 9.0, 7.0, 6.0][l - 1]


func pierce(lvl := -1) -> int:
	return _lv(&"pierce", lvl)


func fire_rate_mult(lvl := -1) -> float:
	return 1.0 + 0.15 * _lv(&"rapid", lvl)


func damage_mult(lvl := -1) -> float:
	return 1.0 + 0.15 * _lv(&"power", lvl)


func max_hp_bonus(lvl := -1) -> float:
	return 25.0 * _lv(&"armor", lvl)


func move_mult(lvl := -1) -> float:
	return 1.0 + 0.1 * _lv(&"thrusters", lvl)


func boost_cd_mult(lvl := -1) -> float:
	return 1.0 - 0.15 * _lv(&"thrusters", lvl)


func blade_count(lvl := -1) -> int:
	var l := _lv(&"blades", lvl)
	return 0 if l <= 0 else l + 1


func explosive_chance(lvl := -1) -> float:
	var l := _lv(&"explosive", lvl)
	return 0.0 if l <= 0 else [0.15, 0.25, 0.35][l - 1]


func salvage_heal(lvl := -1) -> float:
	return 2.0 * _lv(&"salvage", lvl)


func heat_mult(lvl := -1) -> float:
	return 1.0 + 0.35 * _lv(&"heat_sink", lvl)


func magnet_mult(lvl := -1) -> float:
	return 1.0 + 0.6 * _lv(&"magnet", lvl)


func xp_mult(lvl := -1) -> float:
	return 1.0 + 0.15 * _lv(&"magnet", lvl)
