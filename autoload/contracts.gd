extends Node
## CONTRACTS (autoload; shown in Hangar > CONTRACTS, ui/contracts_panel.gd): 40 goals in 5 rows of 8, like
## Halls of Torment's quest board, Hades' Fated List and Antimatter Dimensions' achievement rows.
##   - Each contract follows one lifetime number (`stat`, see value()) and completes on its own when it
##     reaches `goal`: a CONTRACT COMPLETE toast mid-run and a line on the results screen.
##   - It's then CLAIMED in the Hangar for its row's scrap reward (ROWS). Claiming all 8 of a row switches on
##     that row's permanent bonus: +5% scrap / +5% damage / +1 reroll a run / +5% XP / +10% scrap.
##   - Two contracts unlock things (`unlock`): "Gold Rush" opens the Hangar's Salvager Beacon row
##     (Game.HANGAR "lock"), "Jackpot" puts the SALVAGE PROTOCOL card into the level-up pool. Three more open
##     mech parts (Parts.LIST "contract"): Campaigner the Hover Skirt, Survivor the Twin Booster, Tank Buster
##     the Missile Rack.
## Counters (kills, bosses, Gold Salvagers...) only move in real runs (Game.scrap_enabled). The others read
## the save (waves beaten, Endless best, weapons, mastery, Hangar, Threat), so an existing save finds its
## finished contracts ready to claim. Progress lives in Game (contract_stats / contracts_done /
## contracts_claimed) so it saves with everything else.

## A contract reached its goal (the HUD toasts it during a run; the Hangar refreshes).
signal contract_done(id: StringName)
signal contract_claimed(id: StringName, reward: int)

## Rows: name, scrap reward per contract, and the permanent bonus for claiming all 8.
const ROWS: Array[Dictionary] = [
	{"name": "ROOKIE", "reward": 400, "bonus": "+5% scrap"},
	{"name": "PILOT", "reward": 900, "bonus": "+5% damage"},
	{"name": "VETERAN", "reward": 2000, "bonus": "+1 level-up reroll every run"},
	{"name": "ACE", "reward": 4000, "bonus": "+5% XP"},
	{"name": "LEGEND", "reward": 8000, "bonus": "+10% scrap"},
]
const PER_ROW := 8
## id, row, title, text, stat (see value()), goal, and optionally `unlock` (what finishing it opens).
const LIST: Array[Dictionary] = [
	# ROOKIE
	{"id": &"first_blood", "row": 0, "title": "First Blood", "text": "Destroy 100 robots", "stat": "kills", "goal": 100},
	{"id": &"wave_breaker", "row": 0, "title": "Wave Breaker", "text": "Beat 15 waves", "stat": "waves", "goal": 15},
	{"id": &"gearing_up", "row": 0, "title": "Gearing Up", "text": "Buy 5 Hangar upgrade levels", "stat": "hangar_levels", "goal": 5},
	{"id": &"armed_up", "row": 0, "title": "Armed Up", "text": "Unlock 4 weapons", "stat": "unlocked", "goal": 4},
	{"id": &"boss_breaker", "row": 0, "title": "Boss Breaker", "text": "Destroy 3 bosses", "stat": "bosses", "goal": 3},
	{"id": &"field_promotion", "row": 0, "title": "Field Promotion", "text": "Reach pilot level 8 in a run", "stat": "best_level", "goal": 8},
	{"id": &"combo_online", "row": 0, "title": "Combo Online", "text": "Take a gold COMBO card", "stat": "combos", "goal": 1},
	{"id": &"gold_rush", "row": 0, "title": "Gold Rush", "text": "Shoot down a Gold Salvager", "stat": "salvagers", "goal": 1,
		"unlock": "Hangar: Salvager Beacon"},
	# PILOT
	{"id": &"sharpshooter", "row": 1, "title": "Sharpshooter", "text": "Destroy 300 robots with the Beam Rifle", "stat": "w:blaster", "goal": 300},
	{"id": &"blademaster", "row": 1, "title": "Blademaster", "text": "Destroy 300 robots with melee weapons", "stat": "kills_melee", "goal": 300},
	{"id": &"survivor", "row": 1, "title": "Survivor", "text": "Reach Endless wave 15", "stat": "endless_best", "goal": 15,
		"unlock": "Part: Twin Booster"},
	{"id": &"campaigner", "row": 1, "title": "Campaigner", "text": "Clear 3 different arenas", "stat": "arenas", "goal": 3,
		"unlock": "Part: Hover Skirt"},
	{"id": &"hard_target", "row": 1, "title": "Hard Target", "text": "Clear an arena on Hard or Extreme", "stat": "diff_clears:2", "goal": 1},
	{"id": &"specialist", "row": 1, "title": "Specialist", "text": "Reach mastery LV 5 with a weapon", "stat": "mastery_best", "goal": 5},
	{"id": &"elite_hunter", "row": 1, "title": "Elite Hunter", "text": "Destroy 40 gold elites", "stat": "kills_elite", "goal": 40},
	{"id": &"jackpot", "row": 1, "title": "Jackpot", "text": "Bank 5,000 scrap from one run", "stat": "best_run_scrap", "goal": 5000,
		"unlock": "Level-up card: Salvage Protocol"},
	# VETERAN
	{"id": &"lancer_down", "row": 2, "title": "Lancer Down", "text": "Destroy 100 Lancers", "stat": "k:Lancer", "goal": 100},
	{"id": &"tank_buster", "row": 2, "title": "Tank Buster", "text": "Destroy 60 Heavy Tanks", "stat": "k:HeavyTank", "goal": 60,
		"unlock": "Part: Missile Rack"},
	{"id": &"hit_and_run", "row": 2, "title": "Hit and Run", "text": "Clear an arena with the ARROWHEAD", "stat": "clear_c:striker", "goal": 1},
	{"id": &"iron_wall", "row": 2, "title": "Iron Wall", "text": "Clear an arena with the RAMPART", "stat": "clear_c:bulwark", "goal": 1},
	{"id": &"endurance", "row": 2, "title": "Endurance", "text": "Reach Endless wave 25", "stat": "endless_best", "goal": 25},
	{"id": &"twist_rider", "row": 2, "title": "Twist Rider", "text": "Beat 15 waves during Endless twists", "stat": "twist_waves", "goal": 15},
	{"id": &"collector", "row": 2, "title": "Collector", "text": "Unlock 9 weapons", "stat": "unlocked", "goal": 9},
	{"id": &"frenzy_feeder", "row": 2, "title": "Frenzy Feeder", "text": "Earn 3,000 scrap from Gold Salvagers", "stat": "gold_scrap", "goal": 3000},
	# ACE
	{"id": &"extreme_clear", "row": 3, "title": "Extreme Clear", "text": "Clear an arena on Extreme", "stat": "diff_clears:3", "goal": 1},
	{"id": &"threat_rising", "row": 3, "title": "Threat Rising", "text": "Win at THREAT 1", "stat": "threat_best", "goal": 1},
	{"id": &"weapon_master", "row": 3, "title": "Weapon Master", "text": "Master a weapon (mastery LV 10)", "stat": "mastered", "goal": 1},
	{"id": &"boss_slayer", "row": 3, "title": "Boss Slayer", "text": "Destroy 25 bosses", "stat": "bosses", "goal": 25},
	{"id": &"ace_pilot", "row": 3, "title": "Ace Pilot", "text": "Reach pilot level 20 in a run", "stat": "best_level", "goal": 20},
	{"id": &"over_the_max", "row": 3, "title": "Over the Max", "text": "Reach MK III on a Hangar upgrade", "stat": "hangar_mk_best", "goal": 2},
	{"id": &"annihilator", "row": 3, "title": "Annihilator", "text": "Destroy 5,000 robots", "stat": "kills", "goal": 5000},
	{"id": &"bounty_hunter", "row": 3, "title": "Bounty Hunter", "text": "Collect 3 Threat bounties", "stat": "bounties", "goal": 3},
	# LEGEND
	{"id": &"full_arsenal", "row": 4, "title": "Full Arsenal", "text": "Unlock all 13 weapons", "stat": "unlocked", "goal": 13},
	{"id": &"grand_campaign", "row": 4, "title": "Grand Campaign", "text": "Clear all 6 arenas on Extreme", "stat": "diff_clears:3", "goal": 6},
	{"id": &"danger_close", "row": 4, "title": "Danger Close", "text": "Win at THREAT 5", "stat": "threat_best", "goal": 5},
	{"id": &"endless_legend", "row": 4, "title": "Endless Legend", "text": "Reach Endless wave 40", "stat": "endless_best", "goal": 40},
	{"id": &"triple_master", "row": 4, "title": "Triple Master", "text": "Master 3 weapons", "stat": "mastered", "goal": 3},
	{"id": &"salvage_king", "row": 4, "title": "Salvage King", "text": "Shoot down 25 Gold Salvagers", "stat": "salvagers", "goal": 25},
	{"id": &"apex_predator", "row": 4, "title": "Apex Predator", "text": "Win at THREAT 10", "stat": "threat_best", "goal": 10},
	{"id": &"tycoon", "row": 4, "title": "Tycoon", "text": "Earn 250,000 scrap in total", "stat": "scrap_total", "goal": 250000},
]

## Contracts completed during the current run (the results screen lists them).
var completed_run: Array[StringName] = []
var _index := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c: Dictionary in LIST:
		_index[c["id"]] = c
	Combat.enemy_killed.connect(_on_kill)
	Game.salvager_caught.connect(func(_prize: StringName, _amount: float) -> void: _add_run("salvagers"))
	Game.arena_won.connect(_on_arena_won)
	Game.wave_won.connect(_on_wave_won)
	Game.run_banked.connect(_on_banked)
	Game.threat_won.connect(func(_t: int, _b: int, _o: bool) -> void: check())
	Game.mastery_up.connect(func(_id: StringName, _l: int) -> void: check())
	Game.weapon_unlocked.connect(func(_n: Array[String]) -> void: check())
	Game.hangar_bought.connect(func(_id: StringName) -> void: check())
	Upgrades.upgrade_applied.connect(_on_upgrade)
	Upgrades.xp_changed.connect(_on_xp)
	# An existing save: whatever is already finished is ready to claim (no toasts).
	if check(false):
		Game.save()


## A new run: forget the last run's completions.
func start_run() -> void:
	completed_run.clear()


# --- lookups ---------------------------------------------------------------------------------------------

func info(id: StringName) -> Dictionary:
	return _index.get(id, {}) if not _index.is_empty() else _find(id)


func _find(id: StringName) -> Dictionary:
	for c: Dictionary in LIST:
		if c["id"] == id:
			return c
	return {}


func reward(id: StringName) -> int:
	var c := info(id)
	return int(c.get("reward", ROWS[int(c.get("row", 0))]["reward"])) if not c.is_empty() else 0


func is_done(id: StringName) -> bool:
	return Game.contracts_done.has(id)


func is_claimed(id: StringName) -> bool:
	return Game.contracts_claimed.has(id)


## Done but not claimed yet.
func is_ready(id: StringName) -> bool:
	return is_done(id) and not is_claimed(id)


func ready_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Dictionary in LIST:
		if is_ready(c["id"]):
			out.append(c["id"])
	return out


func done_count() -> int:
	var n := 0
	for c: Dictionary in LIST:
		if is_done(c["id"]):
			n += 1
	return n


func row_ids(row: int) -> Array[StringName]:
	var out: Array[StringName] = []
	for c: Dictionary in LIST:
		if int(c["row"]) == row:
			out.append(c["id"])
	return out


## Every contract of the row claimed: its permanent bonus is on.
func row_complete(row: int) -> bool:
	for c: Dictionary in LIST:
		if int(c["row"]) == row and not Game.contracts_claimed.has(c["id"]):
			return false
	return true


## [current (capped at the goal), goal].
func progress(id: StringName) -> Vector2i:
	var c := info(id)
	if c.is_empty():
		return Vector2i.ZERO
	var goal := int(c["goal"])
	return Vector2i(goal if is_done(id) else mini(value(c["stat"]), goal), goal)


func fraction(id: StringName) -> float:
	var p := progress(id)
	return 1.0 if p.y <= 0 else clampf(float(p.x) / p.y, 0.0, 1.0)


## The `n` unfinished contracts closest to done (results screen "NEXT UP").
func closest(n: int) -> Array[StringName]:
	var open: Array[StringName] = []
	for c: Dictionary in LIST:
		if not is_done(c["id"]):
			open.append(c["id"])
	open.sort_custom(func(a: StringName, b: StringName) -> bool:
		var fa := fraction(a)
		var fb := fraction(b)
		return fa > fb if not is_equal_approx(fa, fb) else int(info(a)["row"]) < int(info(b)["row"]))
	return open.slice(0, n)


## The number a contract's `stat` follows.
func value(stat: String) -> int:
	match stat:
		"waves":
			return Game.waves_beaten
		"endless_best":
			return Game.endless_best
		"arenas":
			return Game.cleared.size()
		"unlocked":
			return Game.unlocked.size()
		"threat_best":
			return Game.threat_best
		"bounties":
			return Game.bounties.size()
		"mastery_best":
			var best := 0
			for w: Dictionary in Game.WEAPONS:
				best = maxi(best, Game.mastery_level(w["id"]))
			return best
		"mastered":
			var n := 0
			for w: Dictionary in Game.WEAPONS:
				if Game.is_mastered(w["id"]):
					n += 1
			return n
		"hangar_levels":
			var total := 0
			for id: StringName in Game.HANGAR:
				total += int(Game.hangar.get(id, 0))
			return total
		"hangar_mk_best":
			var mk := 0
			for id: StringName in Game.HANGAR:
				mk = maxi(mk, Game.hangar_mk(id))
			return mk
	if stat.begins_with("diff_clears:"):
		var need := int(stat.get_slice(":", 1))
		var n := 0
		for k in Game.arena_best_diff:
			if int(Game.arena_best_diff[k]) >= need:
				n += 1
		return n
	return int(Game.contract_stats.get(stat, 0))


# --- progress --------------------------------------------------------------------------------------------

## Marks every contract that has reached its goal as done. `announce`: emit contract_done (toasts) and list
## it for this run's results. Returns true when anything new was finished.
func check(announce := true) -> bool:
	var any := false
	for c: Dictionary in LIST:
		var id: StringName = c["id"]
		if Game.contracts_done.has(id) or value(c["stat"]) < int(c["goal"]):
			continue
		Game.contracts_done.append(id)
		any = true
		if announce:
			if Game.scrap_enabled:
				completed_run.append(id)
			contract_done.emit(id)
	return any


## Pays the contract's reward into the Hangar bank (done, unclaimed contracts only). Returns the scrap paid.
func claim(id: StringName) -> int:
	if not is_ready(id):
		return 0
	var r := reward(id)
	Game.contracts_claimed.append(id)
	Game.scrap += r
	Game.save()
	contract_claimed.emit(id, r)
	return r


func claim_all() -> int:
	var total := 0
	for id in ready_ids():
		total += claim(id)
	return total


func _add(stat: String, n := 1) -> void:
	Game.contract_stats[stat] = int(Game.contract_stats.get(stat, 0)) + n


## Counts only in real runs (not the ranges or the tutorial).
func _add_run(stat: String, n := 1) -> void:
	if not Game.scrap_enabled:
		return
	_add(stat, n)
	check()


func _on_kill(e: Node) -> void:
	if not Game.scrap_enabled or not (e is Enemy):
		return
	_add("kills")
	_add("w:" + String(Game.weapon))
	if Game.is_melee(Game.weapon):
		_add("kills_melee")
	if (e as Enemy).elite:
		_add("kills_elite")
	if e.is_in_group("boss"):
		_add("bosses")
	var kind := String(e.get_script().get_global_name()) if e.get_script() else ""
	if kind != "":
		_add("k:" + kind)
	check()


func _on_arena_won(_index_: int) -> void:
	if Game.scrap_enabled:
		_add("clear_c:" + String(Game.chassis))
	check()


func _on_wave_won() -> void:
	if Game.scrap_enabled and Game.is_endless() and Game.endless_twist != &"":
		_add("twist_waves")
	check()


func _on_banked(amount: int, parts: Dictionary) -> void:
	_add("scrap_total", amount)
	_add("gold_scrap", int(parts.get(&"gold", 0)))
	Game.contract_stats["best_run_scrap"] = maxi(int(Game.contract_stats.get("best_run_scrap", 0)), amount)
	check()


func _on_upgrade(id: StringName) -> void:
	if Game.scrap_enabled and Upgrades.is_combo(id):
		_add_run("combos")


func _on_xp() -> void:
	if Game.scrap_enabled and Upgrades.level > int(Game.contract_stats.get("best_level", 0)):
		Game.contract_stats["best_level"] = Upgrades.level
		check()


# --- row bonuses (read by Game.scrap_mult, Upgrades.damage_mult / add_xp / reset) ------------------------

func scrap_mult() -> float:
	return 1.0 + (0.05 if row_complete(0) else 0.0) + (0.1 if row_complete(4) else 0.0)


func damage_mult() -> float:
	return 1.05 if row_complete(1) else 1.0


func bonus_rerolls() -> int:
	return 1 if row_complete(2) else 0


func xp_mult() -> float:
	return 1.05 if row_complete(3) else 1.0
