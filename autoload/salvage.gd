extends Node
## SALVAGE COMBAT + LIMB DAMAGE (run state; reset with every fresh run by Upgrades.reset, carried across
## Campaign sectors because it lives here and not on the mech).
##
## LIMB DAMAGE: the mech has four limbs - the parts slots HEAD, ARMS, LEGS, BACKPACK (autoload/parts.gd). Every
## hit that gets through to HP also wears down one limb (hits from behind find the backpack). A limb at 0 is
## BROKEN until it is fixed:
##   HEAD     - sensors down: no critical hits, -10% damage
##   ARMS     - weapon arm wrecked: -35% attack speed, -15% damage
##   LEGS     - a leg is dragging: -25% move speed
##   BACKPACK - thrusters sputter: boost cooldown +60%
## A repair kit patches every limb up by KIT_REPAIR, and a salvaged piece fixes its own slot completely.
##
## SALVAGE: destroyed robots leave pieces of themselves behind (environment/props/salvage_piece.gd). Melee kills
## TEAR a piece off (MELEE_CHANCE), gun kills sometimes shake one loose (GUN_CHANCE), elites, rival pilots and
## bosses always drop one. Each robot type has its own piece (PIECES: a slot and a small stat). Grab it and it is
## BOLTED ON for the rest of the run (MAX_PER_SLOT per slot), and it fully repairs that limb. A piece for a full
## slot still repairs the limb and pays FULL_SLOT_SCRAP.
## The numbers reach the mech through Parts.mult / Parts.add, so every system that reads parts reads salvage too.

signal changed
## A limb just broke (HUD banner, sparks).
signal limb_broken(slot: StringName)
## A piece was grabbed: `piece` is its PIECES entry plus "bolted" (false = the slot was full).
signal salvaged(piece: Dictionary)

const SLOTS: Array[StringName] = [&"head", &"arms", &"legs", &"backpack"]
## Limb wear per hit: this many times the share of max HP the hit took.
const LIMB_SHARE := 1.6
## Where a hit from the front or side lands (weights). Hits from behind go to the backpack half the time.
const HIT_WEIGHTS := {&"head": 0.15, &"arms": 0.35, &"legs": 0.35, &"backpack": 0.15}
## A limb under this reads as DAMAGED (sparks, amber on the HUD).
const DAMAGED := 0.4
const KIT_REPAIR := 0.5
## What a BROKEN limb costs (same stat keys as parts; "crit" is additive, the rest multipliers).
const BROKEN := {
	&"head": {"crit": -1.0, "damage": -0.1},
	&"arms": {"rate": -0.35, "damage": -0.15},
	&"legs": {"speed": -0.25},
	&"backpack": {"boost_cd": 0.6},
}
const BROKEN_TEXT := {&"head": "SENSORS DOWN - NO CRITS", &"arms": "WEAPON ARM WRECKED", &"legs": "LEG DRAGGING - SLOWER",
	&"backpack": "THRUSTERS SPUTTERING"}

const MELEE_CHANCE := 0.35
const GUN_CHANCE := 0.07
const MAX_PER_SLOT := 3
const FULL_SLOT_SCRAP := 40.0
## Pieces lying on one map at once (more kills just don't drop).
const MAX_ON_MAP := 6

## Robot class -> its piece. stat: a parts stat key (multiplier, or "crit" = chance points).
const PIECES := {
	&"Chaser": {"name": "Chaser Servo Legs", "slot": &"legs", "stat": "speed", "amount": 0.05},
	&"Shooter": {"name": "Shooter Trigger Arm", "slot": &"arms", "stat": "fire_rate", "amount": 0.06},
	&"HeavyTank": {"name": "Tank Cannon Barrel", "slot": &"arms", "stat": "damage", "amount": 0.06},
	&"BladeStriker": {"name": "Striker Blade Arm", "slot": &"arms", "stat": "melee_rate", "amount": 0.08},
	&"AegisGuardian": {"name": "Aegis Sensor Dome", "slot": &"head", "stat": "crit", "amount": 0.03},
	&"Lancer": {"name": "Lancer Thruster", "slot": &"backpack", "stat": "boost_cd", "amount": -0.07},
	&"Hornet": {"name": "Hornet Wing Jets", "slot": &"backpack", "stat": "boost_cd", "amount": -0.07},
	&"Coil": {"name": "Coil Capacitor Arm", "slot": &"arms", "stat": "rate", "amount": 0.05},
	&"Widow": {"name": "Widow Optics", "slot": &"head", "stat": "crit", "amount": 0.04},
	&"Cinder": {"name": "Cinder Furnace Arm", "slot": &"arms", "stat": "damage", "amount": 0.05},
	&"Bastion": {"name": "Bastion Stabilizers", "slot": &"legs", "stat": "speed", "amount": 0.04},
	&"Tidebreaker": {"name": "Tidebreaker Hydraulics", "slot": &"legs", "stat": "speed", "amount": 0.05},
	&"MagmaCrawler": {"name": "Crawler Treads", "slot": &"legs", "stat": "speed", "amount": 0.05},
	&"Anvil": {"name": "Anvil Ram Arm", "slot": &"arms", "stat": "damage", "amount": 0.07},
	&"Slagspitter": {"name": "Slag Launcher", "slot": &"arms", "stat": "fire_rate", "amount": 0.06},
	&"DuneBurrower": {"name": "Burrower Drill Arm", "slot": &"arms", "stat": "melee_rate", "amount": 0.08},
	&"SandSkiff": {"name": "Skiff Fan Pack", "slot": &"backpack", "stat": "boost_cd", "amount": -0.06},
	&"Heliostat": {"name": "Heliostat Lens", "slot": &"head", "stat": "crit", "amount": 0.04},
	&"VoidSkimmer": {"name": "Skimmer Phase Coil", "slot": &"backpack", "stat": "boost_cd", "amount": -0.08},
	&"MagMineDrone": {"name": "Magnet Core", "slot": &"head", "stat": "magnet", "amount": 0.3},
	&"GravTug": {"name": "Tug Tractor Array", "slot": &"head", "stat": "magnet", "amount": 0.35},
	&"RivalMech": {"name": "Rival's Reactor Arm", "slot": &"arms", "stat": "damage", "amount": 0.1},
	&"WardenBoss": {"name": "Warden Core", "slot": &"arms", "stat": "damage", "amount": 0.12},
	&"RoninBoss": {"name": "Ronin Sword Arm", "slot": &"arms", "stat": "melee_rate", "amount": 0.15},
	&"ScarabBoss": {"name": "Scarab Carapace Legs", "slot": &"legs", "stat": "speed", "amount": 0.1},
	&"SeraphBoss": {"name": "Seraph Halo Sensor", "slot": &"head", "stat": "crit", "amount": 0.07},
	&"VulcanBoss": {"name": "Vulcan Autocannon", "slot": &"arms", "stat": "fire_rate", "amount": 0.12},
	&"ZenithBoss": {"name": "Zenith Wing Booster", "slot": &"backpack", "stat": "boost_cd", "amount": -0.15},
}
## Robots without a piece of their own drop scrap plating for a random slot.
const GENERIC := {
	&"head": {"name": "Salvaged Sensor", "slot": &"head", "stat": "crit", "amount": 0.02},
	&"arms": {"name": "Salvaged Arm Servo", "slot": &"arms", "stat": "damage", "amount": 0.04},
	&"legs": {"name": "Salvaged Leg Servo", "slot": &"legs", "stat": "speed", "amount": 0.03},
	&"backpack": {"name": "Salvaged Thruster", "slot": &"backpack", "stat": "boost_cd", "amount": -0.05},
}
## Never drop: swarms, props, the gold drone (it has its own prizes), training targets.
const NO_DROP := [&"ScrapMite", &"GoldSalvager", &"WarpTower", &"OutpostTurret", &"MagMine", &"LavaPool", &"EnergyWave"]
const STAT_NAMES := {"speed": "MOVE SPEED", "fire_rate": "GUN FIRE RATE", "melee_rate": "MELEE SPEED", "rate": "ATTACK SPEED",
	"damage": "DAMAGE", "crit": "CRIT", "boost_cd": "BOOST COOLDOWN", "magnet": "PICKUP RADIUS"}
const SLOT_COLORS := {&"head": Color(0.55, 0.9, 1.0), &"arms": Color(1.0, 0.62, 0.3), &"legs": Color(0.55, 1.0, 0.55),
	&"backpack": Color(0.85, 0.6, 1.0)}

const PIECE := preload("res://environment/props/salvage_piece.gd")

var integrity := {&"head": 1.0, &"arms": 1.0, &"legs": 1.0, &"backpack": 1.0}
## The pieces bolted on this run (PIECES entries + "from" = the robot class).
var bolted: Array[Dictionary] = []
## Off for tests that need a run without drops. (Ranges and the tutorial never drop: see _can_drop.)
var drops_enabled := true
## The robots the player's hits touched last: instance id -> true if that hit was a melee weapon.
var _last_hit := {}
var _map_id := 0
var _on_map := 0


func _ready() -> void:
	Combat.damage_dealt.connect(_on_damage_dealt)
	Combat.enemy_killed.connect(_on_enemy_killed)


## Fresh run: all limbs whole, nothing bolted on.
func reset() -> void:
	for s in SLOTS:
		integrity[s] = 1.0
	bolted.clear()
	_last_hit.clear()
	changed.emit()


# --- limbs ---------------------------------------------------------------------------------------------

func is_broken(slot: StringName) -> bool:
	return float(integrity.get(slot, 1.0)) <= 0.0


func any_damaged() -> bool:
	for s in SLOTS:
		if float(integrity[s]) < 1.0:
			return true
	return false


## A hit took `share` of max HP: wear one limb. `from_behind` = it came from behind the mech. Returns the slot.
func hit_limb(share: float, from_behind := false, slot := &"") -> StringName:
	if slot == &"":
		slot = _pick_limb(from_behind)
	var was := float(integrity[slot])
	integrity[slot] = maxf(was - share * LIMB_SHARE, 0.0)
	if was > 0.0 and float(integrity[slot]) <= 0.0:
		limb_broken.emit(slot)
	changed.emit()
	return slot


func _pick_limb(from_behind: bool) -> StringName:
	if from_behind and randf() < 0.5:
		return &"backpack"
	var r := randf()
	for s in SLOTS:
		r -= float(HIT_WEIGHTS[s])
		if r <= 0.0:
			return s
	return &"legs"


func repair(slot: StringName, amount := 1.0) -> void:
	integrity[slot] = minf(float(integrity[slot]) + amount, 1.0)
	changed.emit()


func repair_all(amount: float) -> void:
	for s in SLOTS:
		integrity[s] = minf(float(integrity[s]) + amount, 1.0)
	changed.emit()


## How many pieces are bolted into a slot.
func count(slot: StringName) -> int:
	var n := 0
	for p in bolted:
		if p["slot"] == slot:
			n += 1
	return n


# --- what it does to the mech (read by Parts.mult / Parts.add) -------------------------------------------

func mult(stat: String) -> float:
	var m := 1.0
	for p in bolted:
		if p["stat"] == stat and stat != "crit":
			m *= 1.0 + float(p["amount"])
	for s in SLOTS:
		if is_broken(s) and BROKEN[s].has(stat) and stat != "crit":
			m *= 1.0 + float(BROKEN[s][stat])
	return m


func add(stat: String) -> float:
	var v := 0.0
	for p in bolted:
		if p["stat"] == stat and stat == "crit":
			v += float(p["amount"])
	for s in SLOTS:
		if is_broken(s) and stat == "crit" and BROKEN[s].has("crit"):
			v += float(BROKEN[s]["crit"])
	return v


## "+6% GUN FIRE RATE", "-7% BOOST COOLDOWN", "+3 CRIT".
static func bonus_text(p: Dictionary) -> String:
	var a := float(p["amount"])
	if p["stat"] == "crit":
		return "+%d%% CRIT CHANCE" % roundi(a * 100.0)
	return "%s%d%% %s" % ["+" if a >= 0.0 else "-", roundi(absf(a) * 100.0), STAT_NAMES.get(p["stat"], String(p["stat"]).to_upper())]


# --- salvage drops -------------------------------------------------------------------------------------

func piece_for(robot_class: StringName) -> Dictionary:
	if PIECES.has(robot_class):
		return PIECES[robot_class]
	return GENERIC[SLOTS.pick_random()]


func _on_damage_dealt(_amount: float, source: Node, target: Node) -> void:
	if is_instance_valid(source) and source is Mech and is_instance_valid(target):
		_last_hit[target.get_instance_id()] = MeleeKit.has_weapon((source as Mech).weapon)


func _can_drop() -> bool:
	return drops_enabled and Game.scrap_enabled


func _on_enemy_killed(e: Node) -> void:
	var id := e.get_instance_id()
	if not _last_hit.has(id):
		return  # not the player's kill (hazards, other robots, the arena clearing itself)
	var melee: bool = _last_hit[id]
	_last_hit.erase(id)
	if not (e is Node2D) or not _can_drop():
		return
	var cls := StringName((e.get_script() as Script).get_global_name()) if e.get_script() else &""
	if NO_DROP.has(cls) or (e is Enemy and (e as Enemy).swarm):
		return
	var sure := e.is_in_group("boss") or cls == &"RivalMech" or (e is Enemy and (e as Enemy).elite)
	if not sure and randf() >= (MELEE_CHANCE if melee else GUN_CHANCE):
		return
	drop(cls, (e as Node2D).global_position, melee, e.is_in_group("boss"))


## Spawns the robot's piece on the map (bosses always get theirs onto the map even if it is crowded).
func drop(cls: StringName, pos: Vector2, torn := false, force := false) -> Node2D:
	var scene := get_tree().current_scene
	if scene and scene.get_instance_id() != _map_id:
		_map_id = scene.get_instance_id()
		_on_map = 0
	_on_map = get_tree().get_nodes_in_group("salvage_pieces").size()
	if _on_map >= MAX_ON_MAP and not force:
		return null
	var p: Node2D = PIECE.new()
	p.piece = piece_for(cls).duplicate()
	p.piece["from"] = cls
	p.tint = Enemy.DEBRIS_TINTS.get(cls, Color(0.7, 0.45, 0.3))
	p.torn = torn
	p.position = pos
	Combat.world().add_child.call_deferred(p)
	return p


## The mech grabbed a piece: bolt it on (or pay scrap if the slot is full) and fix that limb.
func collect(piece: Dictionary) -> void:
	var slot: StringName = piece["slot"]
	var out := piece.duplicate()
	out["bolted"] = count(slot) < MAX_PER_SLOT
	out["repaired"] = float(integrity[slot]) < 1.0
	integrity[slot] = 1.0
	if out["bolted"]:
		bolted.append(piece.duplicate())
	else:
		out["scrap"] = Game.earn_scrap(FULL_SLOT_SCRAP, &"kills")
	salvaged.emit(out)
	changed.emit()
