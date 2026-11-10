extends Node
## Upgrades (autoload): the in-run level-up system.
##   XP       enemies drop XP shards (environment/props/xp_orb.gd); tougher enemies drop more.
##   LEVELS   every level-up pauses the game and offers 3 random upgrades (ui/level_up_menu.gd).
##            Campaign: levels 1-4 come quickly; from level 4 on each level costs level^2 XP (16, 25...).
##            Endless: the first level-up is quick (4 XP), then every level costs 5 x level^2 XP
##            (20, 45, 80, 125...) - endless waves keep growing, so leveling has to slow down with them.
##            Both get steeper in tiers after level 5 (x1.6 from level 5, x2.2 from 10, x3 from 15), and
##            MAX_LEVEL (20) is the cap: no more XP or picks after it.
##            Difficulty: XP gains x Game.diff("xp"), and the campaign's levels from 3 on cost
##            x Game.diff("xp_curve") (Extreme: 0.45 XP, 1.6x cost - its enemies drop far more XP).
##   REWARDS  Endless also hands out picks between level-ups: a free pick for every boss destroyed and a
##            supply drop (XP burst + repair) every third wave (see ScenicArena).
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
	# (effects: crit / cryo / executioner in enemies/enemy.gd, drones in player/weapons/bit_drones.gd,
	# the rest in player/mech.gd)
	&"crit": {"name": "Critical Targeting", "max": 3, "color": Color(1.0, 0.92, 0.35)},
	&"drones": {"name": "Bit Drones", "max": 3, "color": Color(0.45, 0.95, 1.0)},
	&"missile_pod": {"name": "Micro-Missile Pod", "max": 3, "color": Color(1.0, 0.55, 0.45)},
	&"chain": {"name": "Arc Emitter", "max": 3, "color": Color(0.6, 0.75, 1.0)},
	&"boost_burst": {"name": "Impulse Burst", "max": 3, "color": Color(0.35, 1.0, 0.95)},
	&"reactive": {"name": "Reactive Armor", "max": 3, "color": Color(1.0, 0.7, 0.4)},
	&"cryo": {"name": "Cryo Rounds", "max": 3, "color": Color(0.55, 0.9, 1.0)},
	&"redline": {"name": "Redline", "max": 3, "color": Color(1.0, 0.3, 0.3)},
	&"od_core": {"name": "Reactor Overcharge", "max": 3, "color": Color(1.0, 0.85, 0.3)},
	&"thermal": {"name": "Thermal Amplifier", "max": 3, "color": Color(1.0, 0.5, 0.2)},
	# `contract`: only dealt once that contract is done (autoload/contracts.gd). Effect: Game.scrap_mult.
	&"salvage_protocol": {"name": "Salvage Protocol", "max": 3, "color": Color(1.0, 0.8, 0.28), "contract": &"jackpot"},
}
## REROLL / BANISH / SKIP (level-up menu): charges per run. Rerolls deal 3 fresh cards, a banish removes
## an upgrade from the rest of the run, skipping a pick repairs SKIP_REPAIR HP instead. The Hangar adds
## charges (Tactical Uplink / Purge Protocol) and every NEXT ARENA adds a reroll.
const BASE_REROLLS := 2
const BASE_BANISHES := 1
const SKIP_REPAIR := 20.0

## COMBOS: two upgrades you've invested in (both taken, 3+ levels between them) unlock a gold COMBO card,
## dealt into the next level-up (it takes one of the three slots). One level each; `only` = weapons it
## works with. Effects live where they act (mech.gd, orbit_blades.gd, Combat.small_blast).
const COMBO_GOLD := Color(1.0, 0.8, 0.25)
const COMBOS := {
	&"cluster": {"name": "Cluster Missiles", "needs": [&"target_lock", &"explosive"],
		"desc": "Every explosion launches 3 homing micro-missiles at nearby robots."},
	&"blade_storm": {"name": "Blade Storm", "needs": [&"blades", &"shield"],
		"desc": "Orbit blades grow bigger, spin 60% faster and hit 50% harder."},
	&"overclock": {"name": "Overclock", "needs": [&"rapid", &"heat_sink"],
		"desc": "The hotter your mech runs, the faster it fires: up to +40% at full heat."},
	&"railgun": {"name": "Railgun", "needs": [&"pierce", &"power"], "only": [&"blaster", &"gatling", &"dual_pistols"],
		"desc": "Every 6th shot is a railgun slug: 4x damage, pierces everything."},
	&"nano_repair": {"name": "Nano Repair", "needs": [&"salvage", &"armor"],
		"desc": "Regenerate 2 HP a second after 3 s without taking damage."},
	&"seeker_swarm": {"name": "Seeker Swarm", "needs": [&"multishot", &"target_lock"], "only": [&"blaster", &"gatling", &"dual_pistols"],
		"desc": "Your side shots become seekers that chase down robots."},
	&"storm_bits": {"name": "Storm Bits", "needs": [&"drones", &"chain"],
		"desc": "Bit Drone shots always arc lightning to another robot nearby."},
	&"shatter": {"name": "Shatter", "needs": [&"cryo", &"explosive"],
		"desc": "Chilled robots burst into a freezing blast when destroyed."},
	&"executioner": {"name": "Executioner", "needs": [&"crit", &"redline"],
		"desc": "Critical hits destroy robots below 25% HP outright (not bosses)."},
}

var level := 1
var xp := 0.0
## Level-up picks waiting to be made (bonus picks included).
var pending := 0
## Of `pending`, how many are free picks (Hangar Head Start, Endless boss rewards) rather than levels.
## They're dealt first, under `bonus_title`.
var bonus_picks := 0
var bonus_title := "BOSS REWARD!"
## True while the level-up menu is open (the HUD's pause menu stays shut meanwhile).
var choosing := false
var stacks := {}
## Level-up menu charges left this run, and the upgrades banished from it.
var rerolls := 0
var banishes := 0
var banished: Array[StringName] = []
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
	Game.run_waves = 0  # difficulty WARM-UP counts waves per run (Game.warmup)
	xp = 0.0
	pending = 0
	bonus_picks = 0
	choosing = false
	stacks.clear()
	# PARTS (autoload/parts.gd): parts like the Missile Rack start every run with their upgrade at LV 1.
	for id in Parts.starting_upgrades():
		stacks[id] = 1
	rerolls = BASE_REROLLS + Game.hangar_level(&"rerolls") + Contracts.bonus_rerolls() + (1 if Game.pool_reached(1) else 0)
	banishes = BASE_BANISHES + Game.hangar_level(&"banishes")
	banished.clear()
	save_checkpoint()


## NEXT ARENA (upgrades carry over): one more reroll for the road.
func next_arena_bonus() -> void:
	rerolls += 1


## Fresh run from the menu with the Hangar's Head Start: free picks waiting when the arena opens (the
## level-up menu deals them as soon as it's ready).
func grant_head_start() -> void:
	var n := Game.hangar_level(&"head_start")
	# Head Start MK levels: a chance of one more free pick.
	if n > 0 and randf() < Game.hangar_mk_bonus(&"head_start"):
		n += 1
	if n > 0:
		pending += n
		bonus_picks += n
		bonus_title = "HEAD START"


## (unspent Head Start picks are part of the checkpoint, so RETRY offers them again)
func save_checkpoint() -> void:
	_checkpoint = {"level": level, "xp": xp, "stacks": stacks.duplicate(), "bonus": bonus_picks, "rerolls": rerolls,
		"banishes": banishes, "banished": banished.duplicate()}


func restore_checkpoint() -> void:
	level = _checkpoint.get("level", 1)
	xp = _checkpoint.get("xp", 0.0)
	stacks = _checkpoint.get("stacks", {}).duplicate()
	bonus_picks = _checkpoint.get("bonus", 0)
	rerolls = _checkpoint.get("rerolls", BASE_REROLLS)
	banishes = _checkpoint.get("banishes", BASE_BANISHES)
	banished.assign(_checkpoint.get("banished", []))
	pending = bonus_picks
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
	elif lvl >= 3:
		# Campaign on Extreme: every level past 3 costs extra.
		base *= Game.diff("xp_curve")
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
	xp += amount * xp_mult() * Game.diff("xp") * (1.0 + 0.06 * Game.hangar_level(&"analytics")
		+ Game.hangar_mk_bonus(&"analytics")) * Game.twist_value("xp") * Contracts.xp_mult() \
		* (1.0 + Game.POOL_XP if Game.pool_reached(2) else 1.0)
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
	# Armor counts as extra toughness (each armor point takes armor_tier damage to strip). Elites have
	# double HP already, so the 1.25 on top makes them worth 2.5x.
	var v := (e.max_hp + e.max_armor * e.armor_tier) / 45.0
	return maxi(1, roundi(v * (1.25 if e.elite else 1.0)))


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
	if level_of(id) >= u["max"] or banished.has(id):
		return false
	if u.has("only") and not u["only"].has(Game.weapon):
		return false
	if u.has("not_for") and u["not_for"].has(Game.weapon):
		return false
	if u.has("contract") and not Contracts.is_done(u["contract"]):
		return false
	return true


## Cards per level-up: 3, or 4 with the VX-7 Standard's ADAPTIVE CORE.
func card_count() -> int:
	return 4 if Game.chassis == &"standard" else 3


## Up to `n` distinct random upgrades that can still be taken (topped up with Field Repair). An unlocked
## COMBO always takes the last slot.
func roll_choices(n := 3) -> Array[StringName]:
	var pool: Array[StringName] = []
	for id: StringName in CATALOG:
		if is_available(id):
			pool.append(id)
	pool.shuffle()
	var combos := available_combos()
	var take := n - (1 if not combos.is_empty() else 0)
	var out: Array[StringName] = []
	for id in pool.slice(0, take):
		out.append(id)
	if not combos.is_empty():
		out.append(combos.pick_random())
	if out.size() < n:
		out.append(FIELD_REPAIR)
	return out


func is_combo(id: StringName) -> bool:
	return COMBOS.has(id)


## Combos whose two upgrades are both taken (3+ levels between them), not taken yet, for this weapon.
func available_combos() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in COMBOS:
		var c: Dictionary = COMBOS[id]
		if level_of(id) > 0 or banished.has(id) or (c.has("only") and not c["only"].has(Game.weapon)):
			continue
		var a := level_of(c["needs"][0])
		var b := level_of(c["needs"][1])
		if a > 0 and b > 0 and a + b >= 3:
			out.append(id)
	return out


## "Target Lock + Explosive Rounds" for a combo card.
func combo_parents(id: StringName) -> String:
	var c: Dictionary = COMBOS[id]
	return "%s + %s" % [CATALOG[c["needs"][0]]["name"], CATALOG[c["needs"][1]]["name"]]


func apply(id: StringName) -> void:
	if id != FIELD_REPAIR:
		stacks[id] = level_of(id) + 1
	pending = maxi(pending - 1, 0)
	bonus_picks = maxi(bonus_picks - 1, 0)
	upgrade_applied.emit(id)
	if is_combo(id):
		Radio.say(&"combo", true)


## Level-up menu REROLL: spends a charge (the menu deals fresh cards). False when none are left.
## (Hangar Tactical Uplink MK levels: a chance it's free.)
func use_reroll() -> bool:
	if rerolls <= 0:
		return false
	if randf() >= Game.hangar_mk_bonus(&"rerolls"):
		rerolls -= 1
	return true


## Level-up menu BANISH: `id` never shows up again this run. (Purge Protocol MK: a chance it's free.)
func banish(id: StringName) -> bool:
	if banishes <= 0 or id == FIELD_REPAIR or banished.has(id):
		return false
	if randf() >= Game.hangar_mk_bonus(&"banishes"):
		banishes -= 1
	banished.append(id)
	return true


## Level-up menu SKIP: no upgrade, a quick repair instead (the pick is used up).
func skip() -> void:
	pending = maxi(pending - 1, 0)
	bonus_picks = maxi(bonus_picks - 1, 0)
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech:
		mech.heal(SKIP_REPAIR)


## A free upgrade pick that isn't a level (Endless boss kill). Opens the pick menu right away.
func grant_bonus_pick() -> void:
	pending += 1
	bonus_picks += 1
	bonus_title = "BOSS REWARD!"
	Sfx.play(&"levelup", -4.0, 0.0)
	if not choosing:
		level_up_ready.emit()


## Supply drop: an XP burst worth `fraction` of the current level's cost (difficulty XP multipliers
## don't shrink it), sprayed as shards around `pos` and pulled straight to the player.
func supply_xp(pos: Vector2, fraction: float) -> void:
	if is_max_level():
		return
	var total := xp_to_next() * fraction / maxf(xp_mult() * Game.diff("xp"), 0.01)
	var world := Combat.world()
	for i in 8:
		var orb: Node2D = XP_ORB.new()
		orb.value = total / 8.0
		orb.position = pos
		orb.set("pop", Vector2.from_angle(TAU * i / 8.0) * randf_range(120.0, 220.0))
		world.add_child.call_deferred(orb)
	vacuum()


func display_name(id: StringName) -> String:
	if is_combo(id):
		return COMBOS[id]["name"]
	return "Field Repair" if id == FIELD_REPAIR else CATALOG[id]["name"]


func color(id: StringName) -> Color:
	if is_combo(id):
		return COMBO_GOLD
	return Color(0.4, 1.0, 0.5) if id == FIELD_REPAIR else CATALOG[id]["color"]


func max_level(id: StringName) -> int:
	return 1 if id == FIELD_REPAIR or is_combo(id) else CATALOG[id]["max"]


## What taking `id` right now does (describes the NEXT level, with real numbers).
func describe(id: StringName) -> String:
	if is_combo(id):
		return COMBOS[id]["desc"]
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
		&"crit":
			return "%d%% chance for any hit to deal double damage." % roundi(crit_chance(n) * 100.0)
		&"drones":
			return "%d drone%s fly with you, firing at the nearest robot every %.1fs." % [n, "" if n == 1 else "s",
				drone_interval(n)]
		&"missile_pod":
			return "Every %.1fs, launch %d homing micro-missiles at nearby robots." % [missile_interval(n), missile_count(n)]
		&"chain":
			return "%d%% chance for hits to arc lightning to %d nearby robot%s." % [roundi(chain_chance(n) * 100.0),
				n, "" if n == 1 else "s"]
		&"boost_burst":
			return "Boosting sets off a shockwave: %d damage around you." % roundi(boost_burst_damage(n))
		&"reactive":
			return "Taking a hit discharges a %d-damage blast around you." % roundi(reactive_damage(n))
		&"cryo":
			return "%d%% chance for hits to chill robots, slowing them by 40%% for 2s." % roundi(cryo_chance(n) * 100.0)
		&"redline":
			return "Below 40%% HP: +%d%% damage and +%d%% attack speed." % [roundi(redline_damage(n) * 100.0),
				roundi(redline_rate(n) * 100.0)]
		&"od_core":
			return "Overdrive lasts %ds longer and charges %d%% faster." % [roundi(od_bonus_time(n)),
				roundi((od_gain(n) - 1.0) * 100.0)]
		&"thermal":
			return "Nova + Cone cost %d%% less heat and deal +%d%% damage." % [roundi((1.0 - ability_cost_mult(n)) * 100.0),
				roundi((ability_damage_mult(n) - 1.0) * 100.0)]
		&"salvage_protocol":
			return "+15%% scrap from everything for the rest of this run (total +%d%%)." % (n * 15)
		&"field_repair":
			return "Repair 40 HP and restock one repair kit."
	return ""


# --- effect values (lvl -1 = current level) --------------------------------------------------------------

func _lv(id: StringName, lvl: int) -> int:
	return level_of(id) if lvl < 0 else lvl


## PARTS (autoload/parts.gd): the equipped parts' multiplier on a stat. Live values only (lvl < 0), so the
## level-up cards still describe the upgrade on its own.
func _part(stat: String, lvl: int) -> float:
	return Parts.mult(stat) if lvl < 0 else 1.0


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


## (Power Core, times the Hangar's Weapon Calibration + its MK levels and the PILOT contract row bonus)
func damage_mult(lvl := -1) -> float:
	return (1.0 + 0.15 * _lv(&"power", lvl)) * (1.0 + 0.05 * Game.hangar_level(&"calibration")
		+ Game.hangar_mk_bonus(&"calibration")) * Contracts.damage_mult() * _part("damage", lvl)


## SALVAGE PROTOCOL (a contract unlock): +15% scrap per level for the rest of the run.
func salvage_protocol_mult(lvl := -1) -> float:
	return 1.0 + 0.15 * _lv(&"salvage_protocol", lvl)


func max_hp_bonus(lvl := -1) -> float:
	return 25.0 * _lv(&"armor", lvl)


## (Thrusters, times the Hangar's Servo Motors (+ MK levels) and the chassis)
func move_mult(lvl := -1) -> float:
	return (1.0 + 0.1 * _lv(&"thrusters", lvl)) * (1.0 + 0.04 * Game.hangar_level(&"servos") + Game.hangar_mk_bonus(&"servos")) \
		* float(Game.chassis_info()["speed"]) * Game.twist_value("player_speed") * _part("speed", lvl)


func boost_cd_mult(lvl := -1) -> float:
	return (1.0 - 0.15 * _lv(&"thrusters", lvl)) * _part("boost_cd", lvl)


func blade_count(lvl := -1) -> int:
	var l := _lv(&"blades", lvl)
	return 0 if l <= 0 else l + 1


func explosive_chance(lvl := -1) -> float:
	var l := _lv(&"explosive", lvl)
	return 0.0 if l <= 0 else [0.15, 0.25, 0.35][l - 1]


func salvage_heal(lvl := -1) -> float:
	return 2.0 * _lv(&"salvage", lvl)


func heat_mult(lvl := -1) -> float:
	return (1.0 + 0.35 * _lv(&"heat_sink", lvl)) * _part("heat", lvl)


func magnet_mult(lvl := -1) -> float:
	return (1.0 + 0.6 * _lv(&"magnet", lvl)) * _part("magnet", lvl)


func xp_mult(lvl := -1) -> float:
	return 1.0 + 0.15 * _lv(&"magnet", lvl)


func crit_chance(lvl := -1) -> float:
	var l := _lv(&"crit", lvl)
	return (0.0 if l <= 0 else [0.1, 0.18, 0.26][l - 1]) + (Parts.add("crit") if lvl < 0 else 0.0)


func drone_count(lvl := -1) -> int:
	# CORVID (carrier chassis) launches with 2 drones; the upgrade adds the 3rd (bit_drones.gd has 3 slots).
	if lvl < 0 and Game.chassis == &"carrier":
		return mini(_lv(&"drones", lvl) + 2, 3)
	return _lv(&"drones", lvl)


func drone_interval(lvl := -1) -> float:
	var l := _lv(&"drones", lvl)
	return 0.9 if l <= 0 else [0.9, 0.8, 0.7][l - 1]


func missile_interval(lvl := -1) -> float:
	var l := _lv(&"missile_pod", lvl)
	return 3.0 if l <= 0 else [3.0, 2.4, 1.8][l - 1]


func missile_count(lvl := -1) -> int:
	return 3 if _lv(&"missile_pod", lvl) >= 3 else 2


func chain_chance(lvl := -1) -> float:
	var l := _lv(&"chain", lvl)
	return 0.0 if l <= 0 else [0.12, 0.2, 0.28][l - 1]


func boost_burst_damage(lvl := -1) -> float:
	var l := _lv(&"boost_burst", lvl)
	return 0.0 if l <= 0 else [25.0, 40.0, 55.0][l - 1]


func reactive_damage(lvl := -1) -> float:
	var l := _lv(&"reactive", lvl)
	return 0.0 if l <= 0 else [30.0, 50.0, 70.0][l - 1]


func cryo_chance(lvl := -1) -> float:
	var l := _lv(&"cryo", lvl)
	return 0.0 if l <= 0 else [0.2, 0.3, 0.4][l - 1]


func redline_damage(lvl := -1) -> float:
	var l := _lv(&"redline", lvl)
	return 0.0 if l <= 0 else [0.2, 0.35, 0.5][l - 1]


func redline_rate(lvl := -1) -> float:
	var l := _lv(&"redline", lvl)
	return 0.0 if l <= 0 else [0.15, 0.25, 0.35][l - 1]


func od_bonus_time(lvl := -1) -> float:
	return 2.0 * _lv(&"od_core", lvl)


func od_gain(lvl := -1) -> float:
	return 1.0 + 0.2 * _lv(&"od_core", lvl)


func ability_cost_mult(lvl := -1) -> float:
	return (1.0 - 0.12 * _lv(&"thermal", lvl)) * _part("ability_cost", lvl)


func ability_damage_mult(lvl := -1) -> float:
	return 1.0 + 0.2 * _lv(&"thermal", lvl)
