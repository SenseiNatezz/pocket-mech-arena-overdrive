extends Node
## MECH PARTS test. Run it in landscape, then with the phone layout:
##   godot --headless --path . res://environment/test_range.tscn -- --parts-test --temp-save
##   godot --headless --path . res://environment/test_range.tscn -- --parts-test --temp-save --portrait
## Parts (autoload/parts.gd): a fresh save wears the four STOCK parts (no multipliers, no perks, the mech exactly
## as before); buying costs scrap and puts the part on, locked parts wait for their contract, only owned parts go
## on, and it saves / loads in [parts] (a save from before parts gets STOCK). Every part's stats reach the run
## (HP, speed, dash, handling, gun fire rate vs melee speed, damage, crit, heat, pickup radius, scrap, ability
## cost) without changing what the level-up cards say; the perks work (STEADY, SCRAPPER, HOVER, DOUBLE DASH and
## the starting upgrades) and the BACKPACK changes the thruster flames. The Hangar's PARTS tab lists every part,
## buys / equips / refuses, moves focus with the keyboard and fits the screen.
## Prints PASS/FAIL per check; exit code 0 = all passed.

const MECH_SCENE := preload("res://player/mech.tscn")
const CHASER := preload("res://enemies/chaser.tscn")

var _fails := 0
var mech: Mech
## What a STOCK mech spawns with (see _stock_checks).
var _base := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Controls.ignore_real_input = true
	_run.call_deferred()


func _check(label: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + label)
	if not ok:
		_fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _near(a: float, b: float, eps := 0.002) -> bool:
	return absf(a - b) <= eps


## Puts exactly these parts on (owning them), STOCK in the other slots.
func _wear(ids: Array) -> void:
	for slot in Parts.SLOTS:
		Parts.equipped[slot] = Parts.stock_id(slot)
	for id: StringName in ids:
		if not Parts.owned.has(id):
			Parts.owned.append(id)
		Parts.equipped[Parts.info(id)["slot"]] = id


## A fresh mech spawned with the parts on now (what a run would start with), well away from everything.
func _probe() -> Mech:
	var m: Mech = MECH_SCENE.instantiate()
	m.position = mech.global_position + Vector2(0, 700)
	get_tree().current_scene.add_child(m)
	await _frames(2)
	return m


func _target(pos: Vector2) -> Enemy:
	var e: Enemy = CHASER.instantiate()
	e.max_hp = 30.0
	e.move_speed = 0.0
	e.contact_damage = 0.0
	e.set("lunge_range", 0.0)
	e.position = pos
	get_tree().current_scene.add_child(e)
	return e


func _run() -> void:
	await _frames(5)
	mech = get_tree().get_first_node_in_group("player") as Mech
	Game.scrap_enabled = false
	await _stock_checks()
	_shop_checks()
	_save_checks()
	await _stat_checks()
	await _perk_checks()
	await _ui_checks()
	_wear([])
	Upgrades.reset()
	print("PARTS TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)


func _all_stock() -> bool:
	for slot in Parts.SLOTS:
		if Parts.equipped_id(slot) != Parts.stock_id(slot):
			return false
	return true


# --- a fresh save: STOCK, and the mech exactly as before ----------------------------------------------

func _stock_checks() -> void:
	_check("a fresh save wears the four STOCK parts and owns only them (%d of %d parts)" % [Parts.owned_count(), Parts.LIST.size()],
		_all_stock() and Parts.owned_count() == 4 and Parts.LIST.size() == 16)
	var ones := true
	for s: Array in Parts.STATS:
		ones = ones and Parts.mult(s[0]) == 1.0
	for k in ["accel", "dash", "boost_cd"]:
		ones = ones and Parts.mult(k) == 1.0
	_check("...so every part multiplier is 1, with no crit, perk, spare boost, starting upgrade or flame change",
		ones and Parts.add("crit") == 0.0 and Parts.extra_boosts() == 0 and Parts.starting_upgrades().is_empty()
		and Parts.flame().is_empty() and not Parts.has_perk(&"hover") and not Parts.has_perk(&"steady")
		and not Parts.hovers(mech))
	var raw: Mech = MECH_SCENE.instantiate()
	var ch := Game.chassis_info()
	var p := await _probe()
	_base = {"hp": p.max_hp, "boost": p.boost_speed, "accel": p.acceleration, "flame": p.thrusters[0].modulate}
	_check("...and a mech spawns exactly as before (HP %.0f, boost %.0f, handling %.0f, no spare boost)" % [p.max_hp,
		p.boost_speed, p.acceleration],
		_near(p.max_hp, raw.max_hp * float(ch["hp"]) + Upgrades.max_hp_bonus()) and _near(p.boost_speed,
		raw.boost_speed * float(ch["boost_speed"])) and _near(p.acceleration, raw.acceleration)
		and p._boost_spares_max == 0 and p._boost_spare == 0 and p.thrusters[0].scale == Vector2.ONE)
	raw.free()
	# One boost, then nothing until the cooldown is done.
	p._try_boost(Vector2.RIGHT)
	var cd := p.boost_cooldown_left
	await _frames(14)
	p._try_boost(Vector2.RIGHT)
	_check("...with one boost and its cooldown, as before (%.2f s)" % cd,
		cd > 0.0 and p._boost_left <= 0.0 and p.boost_ready_fraction() < 1.0)
	p.queue_free()
	await _frames(1)


# --- buying, locks, equipping ------------------------------------------------------------------------

func _shop_checks() -> void:
	Game.scrap = 0
	_check("with no scrap the Sprinter Legs can't be bought", not Parts.buy(&"legs_sprint") and not Parts.owns(&"legs_sprint"))
	Game.scrap = 10000
	var price := Parts.cost(&"legs_sprint")
	var ok := Parts.buy(&"legs_sprint")
	_check("buying them costs %s scrap and puts them on (%s left)" % [Game.fmt_int(price), Game.fmt_int(Game.scrap)],
		ok and Game.scrap == 10000 - price and Parts.owns(&"legs_sprint") and Parts.equipped_id(&"legs") == &"legs_sprint")
	_check("...and they can't be bought twice", not Parts.buy(&"legs_sprint") and Game.scrap == 10000 - price)
	var c: StringName = Parts.info(&"legs_hover")["contract"]
	Game.contracts_done.erase(c)
	_check("the Hover Skirt waits for its contract (%s), scrap or not" % Contracts.info(c)["title"],
		Parts.is_locked(&"legs_hover") and not Parts.buy(&"legs_hover") and not Parts.owns(&"legs_hover"))
	Game.contracts_done.append(c)
	_check("...and once that's done it can be bought", not Parts.is_locked(&"legs_hover") and Parts.buy(&"legs_hover")
		and Parts.equipped_id(&"legs") == &"legs_hover")
	_check("an owned part goes back on for free; one you don't own doesn't", Parts.equip(&"legs_sprint")
		and Parts.equipped_id(&"legs") == &"legs_sprint" and not Parts.equip(&"head_hawk")
		and Parts.equipped_id(&"head") == &"head_stock")
	var named := 0
	for p: Dictionary in Parts.LIST:
		if p.has("contract") and String(Contracts.info(p["contract"]).get("unlock", "")).contains(p["name"]):
			named += 1
	_check("the 3 contract-locked parts are named on their contracts' cards (%d)" % named, named == 3)


# --- the [parts] save section ------------------------------------------------------------------------

func _save_checks() -> void:
	Game.save()
	var cfg := ConfigFile.new()
	var loaded := cfg.load(Game.save_path) == OK
	var owned_saved: Array = cfg.get_value("parts", "owned", [])
	var on_saved: Dictionary = cfg.get_value("parts", "equipped", {})
	_check("parts save in their own [parts] section (legs: %s)" % on_saved.get("legs", "?"),
		loaded and owned_saved.has("legs_sprint") and owned_saved.has("legs_hover") and on_saved.get("legs") == "legs_sprint")
	Parts.owned.assign([&"head_stock"])
	Parts.equipped[&"legs"] = &"legs_stock"
	Parts.load_from(cfg)
	_check("...and load back", Parts.owns(&"legs_hover") and Parts.equipped_id(&"legs") == &"legs_sprint"
		and Parts.owned_count() == 6)
	var old := ConfigFile.new()
	old.set_value("hangar", "scrap", 500)
	Parts.load_from(old)
	_check("a save from before parts gets the STOCK parts", _all_stock() and Parts.owned_count() == 4)
	var junk := ConfigFile.new()
	junk.set_value("parts", "owned", ["nope", "head_hawk"])
	junk.set_value("parts", "equipped", {"head": "nope", "legs": "head_hawk", "arms": "arms_gunner"})
	Parts.load_from(junk)
	_check("unknown, unowned or wrong-slot parts in a save fall back to STOCK", Parts.owns(&"head_hawk")
		and Parts.owned_count() == 5 and _all_stock())
	Parts.load_from(cfg)


# --- every part's stats reach the run ----------------------------------------------------------------

func _stat_checks() -> void:
	_wear([])
	Upgrades.reset()
	var speed0 := Upgrades.move_mult()
	var dmg0 := Upgrades.damage_mult()
	var scrap0 := Game.scrap_mult()
	var crit_card := Upgrades.describe(&"crit")
	var w0 := mech.weapon
	var melee_id: StringName = MeleeKit.WEAPONS.keys()[0]
	mech.weapon = &"blaster"
	var gun0 := mech._weapon_rate()
	mech.weapon = melee_id
	var melee0 := mech._weapon_rate()
	mech.weapon = w0

	# LEGS
	_wear([&"legs_sprint"])
	var p := await _probe()
	_check("SPRINTER LEGS: +12%% speed, +20%% dash, -15%% HP (boost %.0f -> %.0f, HP %.0f -> %.0f)" % [_base["boost"],
		p.boost_speed, _base["hp"], p.max_hp], _near(Upgrades.move_mult() / speed0, 1.12)
		and _near(p.boost_speed / _base["boost"], 1.2) and _near(p.max_hp / _base["hp"], 0.85))
	p.queue_free()
	_wear([&"legs_anchor"])
	p = await _probe()
	_check("ANCHOR LEGS: +25%% HP, -12%% speed, -15%% dash (HP %.0f)" % p.max_hp, _near(p.max_hp / _base["hp"], 1.25)
		and _near(Upgrades.move_mult() / speed0, 0.88) and _near(p.boost_speed / _base["boost"], 0.85))
	p.queue_free()
	_wear([&"legs_hover"])
	p = await _probe()
	_check("HOVER SKIRT: +8%% speed, -30%% handling (accel %.0f -> %.0f)" % [_base["accel"], p.acceleration],
		_near(p.acceleration / _base["accel"], 0.7) and _near(Upgrades.move_mult() / speed0, 1.08))
	p.queue_free()

	# HEAD
	_wear([&"head_hawk"])
	_check("LONGSIGHT OPTICS: +8 crit points (%.2f) - the Critical Targeting card still describes itself" %
		Upgrades.crit_chance(), _near(Upgrades.crit_chance(), 0.08) and Upgrades.describe(&"crit") == crit_card)
	_wear([&"head_hawk", &"legs_sprint"])
	p = await _probe()
	_check("parts stack across slots (Longsight + Sprinter: HP x%.3f)" % (p.max_hp / _base["hp"]),
		_near(p.max_hp / _base["hp"], 0.9 * 0.85))
	p.queue_free()
	_wear([&"head_dish"])
	_check("SALVAGE DISH: +60% pickup radius, +10% scrap, -8% damage", _near(Upgrades.magnet_mult(), 1.6)
		and _near(Game.scrap_mult() / scrap0, 1.1) and _near(Upgrades.damage_mult() / dmg0, 0.92))
	_wear([&"head_lock"])
	Upgrades.reset()
	_check("LOCK-ON HEAD: every run starts with TARGET LOCK LV 1, -6% damage", Upgrades.level_of(&"target_lock") == 1
		and _near(Upgrades.damage_mult() / dmg0, 0.94))

	# ARMS
	_wear([&"arms_gunner"])
	mech.weapon = &"blaster"
	var gun := mech._weapon_rate()
	mech.weapon = melee_id
	var melee := mech._weapon_rate()
	_check("GUNNER ARMS: +15% gun fire rate, melee untouched, -20% overdrive gain", _near(gun / gun0, 1.15)
		and _near(melee / melee0, 1.0) and _near(Upgrades.od_part_mult(), 0.8))
	_wear([&"arms_brawler"])
	melee = mech._weapon_rate()  # (still holding the melee weapon)
	mech.weapon = &"blaster"
	_check("BRAWLER ARMS: +20% melee speed, guns untouched", _near(melee / melee0, 1.2) and _near(mech._weapon_rate() / gun0, 1.0))
	_wear([&"arms_thermal"])
	mech._refresh_upgrade_stats()
	_check("REACTOR ARMS (old Thermal Arms id): +35% overdrive gain, +5% damage, -10% attack speed",
		_near(Upgrades.od_part_mult(), 1.35) and _near(mech._weapon_rate() / gun0, 0.9)
		and Parts.info(&"arms_thermal")["name"] == "Reactor Arms")
	mech.weapon = w0
	_wear([])
	mech._refresh_upgrade_stats()

	# BACKPACK
	_wear([&"backpack_twin"])
	_check("TWIN BOOSTER: +35% boost cooldown", _near(Upgrades.boost_cd_mult(), 1.35))
	_wear([&"backpack_missile"])
	Upgrades.reset()
	_check("MISSILE RACK: every run starts with MICRO-MISSILE POD LV 1, -8% speed",
		Upgrades.level_of(&"missile_pod") == 1 and _near(Upgrades.move_mult() / speed0, 0.92))
	_wear([&"backpack_assault"])
	Upgrades.reset()
	p = await _probe()
	_check("OVERBURN BOOSTER: IMPULSE BURST LV 1 every run, +15% dash, +25% cooldown, a bigger flame in its colour",
		Upgrades.level_of(&"boost_burst") == 1 and Upgrades.level_of(&"missile_pod") == 0
		and _near(p.boost_speed / _base["boost"], 1.15) and _near(Upgrades.boost_cd_mult(), 1.25)
		and _near(p.thrusters[0].scale.x, 1.45) and p.thrusters[0].modulate != _base["flame"])
	p.queue_free()
	_wear([])
	Upgrades.reset()
	_check("back on STOCK, runs start with no upgrades again", Upgrades.stacks.is_empty())
	await _frames(1)


# --- perks -------------------------------------------------------------------------------------------

func _perk_checks() -> void:
	# STEADY: the mech's own recoil (scatter shot, beam cannon) is gone.
	_wear([])
	mech._knockback = Vector2.ZERO
	mech.recoil(Vector2(100, 0))
	var kicked := mech._knockback.length()
	mech._knockback = Vector2.ZERO
	_wear([&"arms_gunner"])
	mech.recoil(Vector2(100, 0))
	_check("STEADY (Gunner Arms): no recoil from your own weapons (%.0f -> %.0f)" % [kicked, mech._knockback.length()],
		kicked > 50.0 and mech._knockback.length() == 0.0)
	mech._knockback = Vector2.ZERO

	# SCRAPPER: a kill repairs while a melee weapon is in hand.
	_wear([&"arms_brawler"])
	var w0 := mech.weapon
	mech.weapon = MeleeKit.WEAPONS.keys()[0]
	mech.hp = mech.max_hp - 20.0
	var hp0 := mech.hp
	var e := _target(mech.global_position + Vector2(700, 0))
	await _frames(2)
	e.take_damage(e.hp + 1.0, e.global_position, mech)
	await _frames(2)
	var healed := mech.hp - hp0
	mech.weapon = &"blaster"
	mech.hp = mech.max_hp - 20.0
	hp0 = mech.hp
	e = _target(mech.global_position + Vector2(-700, 0))
	await _frames(2)
	e.take_damage(e.hp + 1.0, e.global_position, mech)
	await _frames(2)
	_check("SCRAPPER (Brawler Arms): a kill repairs %.1f HP with a melee weapon in hand, none with a gun" % healed,
		_near(healed, Parts.SCRAPPER_HEAL * Game.diff("heal"), 0.01) and _near(mech.hp, hp0))
	mech.weapon = w0
	mech.hp = mech.max_hp

	# HOVER: lava pools burn the stock legs, not the skirt.
	_wear([])
	mech._invuln = 0.0
	var pool := LavaPool.spawn(mech.global_position, 120.0, 3.0, 40.0)
	await _frames(80)
	var burned := mech.max_hp - mech.hp
	pool.queue_free()
	_wear([&"legs_hover"])
	mech.hp = mech.max_hp
	mech._invuln = 0.0
	pool = LavaPool.spawn(mech.global_position, 120.0, 3.0, 40.0)
	await _frames(80)
	var hovered := mech.max_hp - mech.hp
	pool.queue_free()
	_check("HOVER (Hover Skirt): a lava pool burns the stock legs (-%.0f HP) but not the skirt (-%.0f)" % [burned, hovered],
		burned > 1.0 and hovered == 0.0 and Parts.hovers(mech))
	mech.hp = mech.max_hp

	# DOUBLE DASH: a second boost right away, then each cooldown gives one back.
	_wear([&"backpack_twin"])
	var p := await _probe()
	p._try_boost(Vector2.RIGHT)
	var first_cd := p.boost_cooldown_left
	await _frames(14)
	var ready_mid := p.boost_ready_fraction()
	p._try_boost(Vector2.RIGHT)
	var second := p._boost_left > 0.0 and p._boost_spare == 0
	await _frames(14)
	p._try_boost(Vector2.RIGHT)
	_check("DOUBLE DASH (Twin Booster): a second boost right after the first (dial full: %.1f), then none" % ready_mid,
		p._boost_spares_max == 1 and first_cd > 0.0 and ready_mid == 1.0 and second and p._boost_left <= 0.0)
	var waited := 0
	while p._boost_spare < 1 and waited < 300:
		await _frames(1)
		waited += 1
	_check("...and the cooldown gives the spare back first (after %.1f s), then recharges the other" % (waited / 60.0),
		p._boost_spare == 1 and p.boost_cooldown_left > 0.0 and p.boost_ready_fraction() == 1.0)
	p.queue_free()
	_wear([])
	await _frames(1)


# --- Hangar > PARTS ----------------------------------------------------------------------------------

func _ui_checks() -> void:
	_wear([])
	Parts.owned.assign([&"head_stock", &"arms_stock", &"legs_stock", &"backpack_stock"])
	Game.contracts_done.erase(Parts.info(&"backpack_missile")["contract"])
	Game.scrap = 0
	var page := HangarPage.new()
	get_tree().current_scene.add_child(page)
	await _frames(2)
	_check("the Hangar has UPGRADES / PARTS / CONTRACTS tabs, in that order (\"%s\")" % page._tab_btns[2].text,
		page._tab_btns.size() == 3 and page._tab_btns[2].text.begins_with("PARTS") and page._tab_btns[2].get_index() == 1
		and page._tab_btns[1].get_index() == 2)
	page._set_tab(2)
	page.focus_default()
	await _frames(2)
	var panel: PartsPanel = page._parts
	_check("the PARTS tab shows all %d parts in 4 slot rows, with the head that's on focused" % panel._cards.size(),
		panel.visible and not page._chassis_grid.visible and not page._contracts.visible
		and panel._cards.size() == Parts.LIST.size() and panel._grids.size() == 4
		and get_viewport().gui_get_focus_owner() == panel._cards[&"head_stock"])
	panel._on_card(&"head_dish")
	_check("pressing a part you can't afford does nothing (the card shakes)", not Parts.owns(&"head_dish")
		and panel._cards[&"head_dish"]._shake > 0.0)
	Game.scrap = 5000
	page.refresh()
	panel._on_card(&"head_dish")
	await _frames(2)
	_check("with the scrap it buys + equips, and the Hangar updates (\"%s\", \"%s\")" % [page._scrap_label.text,
		page._tab_btns[2].text], Parts.equipped_id(&"head") == &"head_dish"
		and Game.scrap == 5000 - Parts.cost(&"head_dish") and page._scrap_label.text == "%s SCRAP" % Game.fmt_int(Game.scrap)
		and page._tab_btns[2].text == "PARTS  5 / %d" % Parts.LIST.size())
	panel._on_card(&"head_stock")
	_check("pressing an owned part puts it back on for free", Parts.equipped_id(&"head") == &"head_stock"
		and Game.scrap == 5000 - Parts.cost(&"head_dish"))
	Game.scrap = 99999
	panel._on_card(&"backpack_missile")
	_check("a locked part stays locked, scrap or not", not Parts.owns(&"backpack_missile") and Game.scrap == 99999)
	_check("cards compare against the part that's on: Salvage Dish vs STOCK (%d stat lines)" % Parts.deltas(&"head_dish").size(),
		Parts.deltas(&"head_dish").size() == 3 and Parts.deltas(&"head_stock").is_empty())
	# Layout: every card on screen, 4 a row in landscape / 2 in portrait, and the 3 tabs fit.
	await _frames(2)
	var vp := get_viewport().get_visible_rect().size
	var narrow := vp.x < 900.0
	var inside := true
	for c: Control in panel._cards.values():
		var r := c.get_global_rect()
		inside = inside and r.position.x >= -0.5 and r.end.x <= vp.x + 0.5 and c.size.y >= PartsPanel.CARD_H - 0.5
	var tabs_fit := true
	for b in page._tab_btns:
		tabs_fit = tabs_fit and b.get_global_rect().end.x <= vp.x + 0.5
	_check("%s %dx%d: %d cards a row, every card and tab on screen" % ["portrait" if narrow else "landscape", vp.x, vp.y,
		panel._grids[0].columns], inside and tabs_fit and panel._grids[0].columns == (2 if narrow else 4))
	# Keyboard / gamepad: down from the first head card moves to a part card below it.
	var start: Control = panel._cards[&"head_stock"]
	start.grab_focus()
	await _frames(1)
	var ev := InputEventAction.new()
	ev.action = &"ui_down"
	ev.pressed = true
	get_viewport().push_input(ev)
	var up := InputEventAction.new()
	up.action = &"ui_down"
	up.pressed = false
	get_viewport().push_input(up)
	await _frames(2)
	var now := get_viewport().gui_get_focus_owner()
	_check("down from the first head card moves focus to the part below (%s)" % (now.get("id") if now else "nothing"),
		now is PartsPanel.PartCard and now != start and now.get_global_rect().position.y > start.get_global_rect().position.y)
	page.queue_free()
	await _frames(1)
