extends Node
## MECH PARTS (autoload "Parts"; Hangar > PARTS tab, ui/parts_panel.gd): build the mech out of scrap-bought
## parts, Armored Core-lite. Four slots - HEAD (sensors), ARMS (weapon handling), LEGS (movement) and
## BACKPACK (booster) - each starting on a free STOCK part, so a save without parts plays exactly as before.
## Every other part trades a plus for a minus (`mods`), and most add a PERK:
##   mods   +/- fractions on a stat, read live through mult() (crit through add(), in chance points): hp,
##          damage, crit, rate (every weapon), fire_rate (guns), melee_rate, speed, dash (boost speed),
##          accel (handling), boost_cd, heat (heat + overdrive gain), magnet (pickup radius), scrap. Numbers
##          a perk explains instead (ability_cost, boosts) sit in mods too but get no stat line on the cards.
##   perk   STEADY (no recoil from your own weapons), SCRAPPER (kills repair while you hold a melee weapon),
##          VENTS (cheaper Heat Nova / Magma Cone), HOVER (lava pools, steam vents and shock panels can't hurt
##          you), DOUBLE DASH (a spare boost), and `start`: every run begins with that level-up upgrade at
##          LV 1 (TARGET LOCK, MICRO-MISSILE POD, IMPULSE BURST). Chassis abilities stack on top.
## Where they land: Upgrades (damage, speed, crit, heat, pickup radius, boost cooldown and ability cost, live;
## the `start` upgrades in reset()), the mech (_apply_parts at spawn: HP, dash, handling, boost charges and the
## BACKPACK's thruster flames; _weapon_rate; recoil; DOUBLE DASH), Game.scrap_mult (scrap), lava_pool.gd and
## the floor hazards (HOVER, via hovers()), and SCRAPPER here.
## Parts are bought with scrap in the Hangar (buying one equips it). Three unlock through contracts
## (`contract`; the contract card says "UNLOCKS Part: ..."). Owned + equipped parts save in [parts].

## Something was bought or equipped (the Hangar redraws).
signal changed

const SLOTS: Array[StringName] = [&"head", &"arms", &"legs", &"backpack"]
const SLOT_NAMES := {&"head": "HEAD", &"arms": "ARMS", &"legs": "LEGS", &"backpack": "BACKPACK"}
const SLOT_ROLES := {&"head": "sensors", &"arms": "weapon handling", &"legs": "movement", &"backpack": "booster"}
## Stat lines on the part cards, in this order: mods key, label, 1 when more is better / -1 when less is.
const STATS: Array[Array] = [
	["hp", "MAX HP", 1], ["damage", "DAMAGE", 1], ["crit", "CRIT CHANCE", 1], ["rate", "ATTACK SPEED", 1],
	["fire_rate", "GUN FIRE RATE", 1], ["melee_rate", "MELEE SPEED", 1], ["speed", "MOVE SPEED", 1],
	["dash", "DASH DISTANCE", 1], ["accel", "HANDLING", 1], ["boost_cd", "BOOST COOLDOWN", -1],
	["heat", "HEAT GAIN", 1], ["magnet", "PICKUP RADIUS", 1], ["scrap", "SCRAP", 1],
]
## Perk keyword -> [name on the card, what it does]. (`start` parts name their upgrade instead.)
const PERKS := {
	&"steady": ["STEADY", "No recoil from your own weapons."],
	&"scrapper": ["SCRAPPER", "Kills repair 2 HP while you hold a melee weapon."],
	&"vents": ["VENTS", "Heat Nova and Magma Cone cost 15% less heat."],
	&"hover": ["HOVER", "Lava pools, steam vents and shock panels can't hurt you."],
	&"double_dash": ["DOUBLE DASH", "A spare boost: dash twice in a row."],
}
const SCRAPPER_HEAL := 2.0
## id, slot, name, cost (scrap; 0 = the free STOCK part), mods, desc, and optionally perk, start (an
## Upgrades id), contract (unlocks once that contract is done), flame (BACKPACK: thruster colour) + flame_scale.
const LIST: Array[Dictionary] = [
	# HEAD (sensors)
	{"id": &"head_stock", "slot": &"head", "name": "Stock Sensors", "cost": 0, "mods": {},
		"desc": "The factory head. It does the job."},
	{"id": &"head_hawk", "slot": &"head", "name": "Longsight Optics", "cost": 2000, "mods": {"crit": 0.08, "hp": -0.1},
		"desc": "Long-range optics that find weak points, in a thin shell."},
	{"id": &"head_dish", "slot": &"head", "name": "Salvage Dish", "cost": 2500,
		"mods": {"magnet": 0.6, "scrap": 0.1, "damage": -0.08}, "desc": "A scanner tuned for loot, not targets."},
	{"id": &"head_lock", "slot": &"head", "name": "Lock-On Head", "cost": 3500, "mods": {"damage": -0.06},
		"start": &"target_lock", "desc": "A fire-control computer that steers your shots."},
	# ARMS (weapon handling)
	{"id": &"arms_stock", "slot": &"arms", "name": "Stock Arms", "cost": 0, "mods": {},
		"desc": "Balanced servos for guns and blades alike."},
	{"id": &"arms_gunner", "slot": &"arms", "name": "Gunner Arms", "cost": 2500,
		"mods": {"fire_rate": 0.15, "heat": -0.2}, "perk": &"steady",
		"desc": "Fast trigger servos and braced elbows. The vents can't keep up."},
	{"id": &"arms_brawler", "slot": &"arms", "name": "Brawler Arms", "cost": 2500,
		"mods": {"melee_rate": 0.2, "hp": -0.1}, "perk": &"scrapper",
		"desc": "Light, quick arms for blade work. Less plating."},
	{"id": &"arms_thermal", "slot": &"arms", "name": "Thermal Arms", "cost": 3500,
		"mods": {"heat": 0.3, "ability_cost": -0.15, "rate": -0.1}, "perk": &"vents",
		"desc": "Heat sinks that feed Nova and Cone. Heavy to swing."},
	# LEGS (movement)
	{"id": &"legs_stock", "slot": &"legs", "name": "Stock Legs", "cost": 0, "mods": {},
		"desc": "Steady footing, no surprises."},
	{"id": &"legs_sprint", "slot": &"legs", "name": "Sprinter Legs", "cost": 2000,
		"mods": {"speed": 0.12, "dash": 0.2, "hp": -0.15}, "desc": "Long strides and a long dash. Thin armor."},
	{"id": &"legs_anchor", "slot": &"legs", "name": "Anchor Legs", "cost": 2500,
		"mods": {"hp": 0.25, "speed": -0.12, "dash": -0.15}, "desc": "Armored pillars. Slow, but hard to drop."},
	{"id": &"legs_hover", "slot": &"legs", "name": "Hover Skirt", "cost": 4500,
		"mods": {"speed": 0.08, "accel": -0.3}, "perk": &"hover", "contract": &"campaigner",
		"desc": "Floats over the floor. Drifts when it turns."},
	# BACKPACK (booster)
	{"id": &"backpack_stock", "slot": &"backpack", "name": "Stock Booster", "cost": 0, "mods": {},
		"desc": "One boost, standard recharge."},
	{"id": &"backpack_twin", "slot": &"backpack", "name": "Twin Booster", "cost": 4000,
		"mods": {"boosts": 1, "boost_cd": 0.35}, "perk": &"double_dash", "contract": &"survivor",
		"flame": Color(0.45, 0.85, 1.0), "flame_scale": 1.2, "desc": "Two burners, two dashes. Slower to refill."},
	{"id": &"backpack_missile", "slot": &"backpack", "name": "Missile Rack", "cost": 5000,
		"mods": {"speed": -0.08}, "start": &"missile_pod", "contract": &"tank_buster",
		"flame": Color(1.0, 0.55, 0.2), "flame_scale": 0.95, "desc": "A launcher on your back. Heavy."},
	{"id": &"backpack_assault", "slot": &"backpack", "name": "Overburn Booster", "cost": 3500,
		"mods": {"dash": 0.15, "boost_cd": 0.25}, "start": &"boost_burst",
		"flame": Color(1.0, 0.32, 0.5), "flame_scale": 1.45, "desc": "A huge burner that hits like a shockwave."},
]

var owned: Array[StringName] = [&"head_stock", &"arms_stock", &"legs_stock", &"backpack_stock"]
var equipped := {&"head": &"head_stock", &"arms": &"arms_stock", &"legs": &"legs_stock", &"backpack": &"backpack_stock"}
var _index := {}


## (built here, not in _ready: Game loads the save - load_from() - before this autoload's _ready runs)
func _init() -> void:
	for p: Dictionary in LIST:
		_index[p["id"]] = p


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Combat.enemy_killed.connect(_on_enemy_killed)
	var debug := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--parts="):  # debug (use --temp-save): own + equip these, e.g. --parts=legs_hover,backpack_twin
			for n in a.trim_prefix("--parts=").split(",", false):
				var id := StringName(n)
				if _index.has(id):
					if not owned.has(id):
						owned.append(id)
					equipped[_index[id]["slot"]] = id
					debug = true
	# (Upgrades dealt the boot-time run before these were equipped: deal it again for the `start` upgrades)
	if debug:
		Upgrades.reset()


# --- the data --------------------------------------------------------------------------------------

func info(id: StringName) -> Dictionary:
	return _index.get(id, {})


func slot_ids(slot: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in LIST:
		if p["slot"] == slot:
			out.append(p["id"])
	return out


func stock_id(slot: StringName) -> StringName:
	return StringName(String(slot) + "_stock")


func equipped_id(slot: StringName) -> StringName:
	return equipped.get(slot, stock_id(slot))


func equipped_info(slot: StringName) -> Dictionary:
	return info(equipped_id(slot))


func is_equipped(id: StringName) -> bool:
	var p := info(id)
	return not p.is_empty() and equipped_id(p["slot"]) == id


func owns(id: StringName) -> bool:
	return owned.has(id) or (_index.has(id) and int(_index[id]["cost"]) == 0)


func owned_count() -> int:
	var n := 0
	for p: Dictionary in LIST:
		if owns(p["id"]):
			n += 1
	return n


func cost(id: StringName) -> int:
	return int(info(id).get("cost", 0))


## Waiting on its contract (see Contracts.info(contract) for its title / goal).
func is_locked(id: StringName) -> bool:
	var c: StringName = info(id).get("contract", &"")
	return c != &"" and not Contracts.is_done(c)


func can_buy(id: StringName) -> bool:
	return _index.has(id) and not owns(id) and not is_locked(id) and Game.scrap >= cost(id)


## The perk line for a card: [name, what it does], or [] for none.
func perk_line(id: StringName) -> Array:
	var p := info(id)
	if p.has("start"):
		return [Upgrades.display_name(p["start"]).to_upper(), "Every run starts with it at LV 1."]
	if p.has("perk") and PERKS.has(p["perk"]):
		return PERKS[p["perk"]]
	return []


## What swapping `id` in would change against the part its slot has on now - or, for the part that's on,
## what it changes from STOCK: [[label, change, good], ...] in STATS order. Multipliers compare as ratios
## (+12% speed vs a -12% part = +27%); crit compares in chance points.
func deltas(id: StringName) -> Array:
	var p := info(id)
	if p.is_empty():
		return []
	var slot: StringName = p["slot"]
	var base := info(stock_id(slot)) if is_equipped(id) else equipped_info(slot)
	var out := []
	for s: Array in STATS:
		var a := float(p["mods"].get(s[0], 0.0))
		var b := float(base["mods"].get(s[0], 0.0))
		var d := a - b if s[0] == "crit" else (1.0 + a) / (1.0 + b) - 1.0
		if absf(d) >= 0.005:
			out.append([s[1], d, (d > 0.0) == (int(s[2]) > 0)])
	return out


# --- what the equipped parts do ----------------------------------------------------------------------

## The equipped parts' multiplier on a stat (1.0 = all stock): each part's 1 + mod, multiplied together.
func mult(stat: String) -> float:
	var m := 1.0
	for slot in SLOTS:
		var mods: Dictionary = equipped_info(slot).get("mods", {})
		if mods.has(stat):
			m *= 1.0 + float(mods[stat])
	return m


## The equipped parts' total on an additive stat: crit (chance points) and boosts (spare boosts).
func add(stat: String) -> float:
	var v := 0.0
	for slot in SLOTS:
		v += float(equipped_info(slot).get("mods", {}).get(stat, 0.0))
	return v


func has_perk(perk: StringName) -> bool:
	for slot in SLOTS:
		if equipped_info(slot).get("perk", &"") == perk:
			return true
	return false


## HOVER: the floor hazards (lava pools, steam vents, shock panels) skip this body.
func hovers(body: Node) -> bool:
	return body != null and body.is_in_group("player") and has_perk(&"hover")


## DOUBLE DASH: boosts on top of the usual one.
func extra_boosts() -> int:
	return int(add("boosts"))


## The level-up upgrades every run starts with at LV 1 (Upgrades.reset).
func starting_upgrades() -> Array[StringName]:
	var out: Array[StringName] = []
	for slot in SLOTS:
		var p := equipped_info(slot)
		if p.has("start"):
			out.append(p["start"])
	return out


## The BACKPACK's thruster flame: {color, scale}, or {} for the stock booster (keeps the Customize colour).
func flame() -> Dictionary:
	var p := equipped_info(&"backpack")
	if not p.has("flame"):
		return {}
	return {"color": p["flame"], "scale": float(p.get("flame_scale", 1.0))}


## SCRAPPER: a kill patches the armor while a melee weapon is in hand.
func _on_enemy_killed(_e: Node) -> void:
	if not has_perk(&"scrapper"):
		return
	var m := get_tree().get_first_node_in_group("player") as Mech
	if m and not m.dead and m.hp < m.max_hp and MeleeKit.has_weapon(m.weapon):
		m.heal(SCRAPPER_HEAL)  # (heal() applies the difficulty's healing factor)


# --- buying + equipping ----------------------------------------------------------------------------

## Pays the scrap, keeps the part and puts it on. False if it's owned, locked or too expensive.
func buy(id: StringName) -> bool:
	if not can_buy(id):
		return false
	Game.scrap -= cost(id)
	owned.append(id)
	equipped[_index[id]["slot"]] = id
	Game.save()
	changed.emit()
	return true


## Puts an owned part on (in its slot). False if it isn't owned.
func equip(id: StringName) -> bool:
	if not _index.has(id) or not owns(id):
		return false
	equipped[_index[id]["slot"]] = id
	Game.save()
	changed.emit()
	return true


# --- save ([parts] section; Game.save / Game._load call these) ------------------------------------------

func save_to(cfg: ConfigFile) -> void:
	var names: Array[String] = []
	for id in owned:
		names.append(String(id))
	cfg.set_value("parts", "owned", names)
	var on := {}
	for slot in SLOTS:
		on[String(slot)] = String(equipped_id(slot))
	cfg.set_value("parts", "equipped", on)


## A save without [parts] (or with unknown / unowned ids) gets the STOCK parts.
func load_from(cfg: ConfigFile) -> void:
	owned.assign([&"head_stock", &"arms_stock", &"legs_stock", &"backpack_stock"])
	for n in cfg.get_value("parts", "owned", []):
		var id := StringName(n)
		if _index.has(id) and not owned.has(id):
			owned.append(id)
	equipped.clear()
	var on: Dictionary = cfg.get_value("parts", "equipped", {})
	for slot in SLOTS:
		var id := StringName(on.get(String(slot), ""))
		equipped[slot] = id if _index.has(id) and owns(id) and _index[id]["slot"] == slot else stock_id(slot)
	changed.emit()
