extends Node
## Preview captures of the GOLD SALVAGER, THREAT TIERS and CONTRACTS. Attach it and give it a file + mode:
##   arena: -- --arena=1 --no-intro --temp-save --difficulty=3 --threat=3 --attach=res://tools/goals_shots.gd
##          --goals-shot=C:/x/a.png --goals-mode=salvager | frenzy | pool | results
##   menu:  -- --temp-save --menu-page=7 (Hangar) | 6 (Loadout, add --difficulty=3 --threat=3) | 3 (Armory)
##          --attach=res://tools/goals_shots.gd --goals-shot=C:/x/m.png --goals-mode=contracts | loadout | armory
##          | parts (add --parts-scroll=PX to scroll the PARTS tab down)
## salvager: a Gold Salvager next to the mech, just spotted. frenzy: a SCRAP FRENZY running while a few robots
## pop into x7 scrap chips, with a CONTRACT COMPLETE toast. results: ARENA CLEARED with a THREAT win, its
## bounty and the CONTRACTS block. contracts: Hangar > CONTRACTS mid-progress. loadout: the THREAT picker.
## armory: weapon cards with THREAT badges. parts: Hangar > PARTS with a few parts bought (Sprinter Legs and
## the Twin Booster on, Gunner Arms owned), the Salvage Dish focused. Saves the PNG, then quits.

const CHASER := preload("res://enemies/chaser.tscn")
const SALVAGER := preload("res://enemies/gold_salvager.gd")

var _path := ""
var _mode := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--goals-shot="):
			_path = a.trim_prefix("--goals-shot=")
		elif a.begins_with("--goals-mode="):
			_mode = a.trim_prefix("--goals-mode=")
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	var scene := get_tree().current_scene
	_progress()
	if scene.name == "MainMenu":
		await _menu(scene)
	else:
		await _arena(scene)
	await RenderingServer.frame_post_draw
	if _path != "":
		get_viewport().get_texture().get_image().save_png(_path)
		print("screenshot saved: ", _path)
	get_tree().quit()


## A save part-way through: some contracts claimed, some ready, a few Threat bounties.
func _progress() -> void:
	Game.waves_beaten = maxi(Game.waves_beaten, 22)
	Game.check_unlocks()
	Game.new_unlocks.clear()
	Game.contract_stats.merge({"kills": 640, "bosses": 4, "salvagers": 1, "w:blaster": 212, "kills_melee": 96, "kills_elite": 17,
		"best_level": 12, "combos": 2, "best_run_scrap": 3900, "k:Lancer": 31, "k:HeavyTank": 22, "gold_scrap": 1150,
		"twist_waves": 6, "scrap_total": 41800}, true)
	Game.hangar.merge({&"frame": 3, &"calibration": 2}, true)
	Game.mastery.merge({&"blaster": 600, &"katana": 260}, true)
	Game.cleared.assign([0, 1])
	Game.arena_best_diff.merge({0: 2, 1: 1}, true)
	Game.bounties.merge({"blaster:1": true, "blaster:2": true, "katana:1": true}, true)
	Game.threat_best = maxi(Game.threat_best, 2)
	Game.threat_unlocked = maxi(Game.threat_unlocked, 3)
	Contracts.check(false)
	for id: StringName in [&"first_blood", &"wave_breaker", &"armed_up", &"boss_breaker", &"field_promotion"]:
		if Contracts.is_done(id) and not Contracts.is_claimed(id):
			Game.contracts_claimed.append(id)
	if Game.scrap < 1000:
		Game.scrap = 12450


func _menu(menu: Node) -> void:
	await _wait(1.2)
	match _mode:
		"contracts":
			var page := menu.get("_hangar") as HangarPage
			page.refresh()
			page._set_tab(1)
			page.focus_default()
			await _wait(0.6)
		"loadout":
			var lo := menu.get("_loadout") as ArmoryPage
			lo.focus_equipped()
			await _wait(0.4)
		"armory":
			var ar := menu.get("_armory") as ArmoryPage
			ar.refresh()
			await _wait(0.4)
		"parts":
			Game.contracts_done.append(&"survivor")
			for id: StringName in [&"arms_gunner", &"legs_sprint", &"backpack_twin"]:
				Parts.owned.append(id)
			Parts.equipped[&"legs"] = &"legs_sprint"
			Parts.equipped[&"backpack"] = &"backpack_twin"
			var hp := menu.get("_hangar") as HangarPage
			hp.refresh()
			hp._set_tab(2)
			await _wait(0.3)
			(hp._parts._cards[&"head_dish"] as Control).grab_focus()
			await _wait(0.4)
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--parts-scroll="):
					hp._scroll.scroll_vertical = int(a.trim_prefix("--parts-scroll="))
			await _wait(0.4)
	await _wait(0.3)


func _hud() -> Node:
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if n.get("_contract_toast") != null:
			return n
	return null


func _arena(arena: Node) -> void:
	await _wait(0.5)
	var mech := get_tree().get_first_node_in_group("player") as Mech
	mech._invuln = 1e9
	var hud := _hud()
	Upgrades.level = 7
	Upgrades.xp = 10.0
	Game.kills = 48
	Game.run_time = 131.0
	Game.earn_scrap(520.0, &"kills")
	Game.earn_scrap(150.0, &"waves")
	if hud:
		hud._scrap_seen = Game.run_scrap_landed()
		hud._scrap_shown = hud._scrap_seen
	# (after the arena's name banner has faded)
	await _wait(1.9)
	match _mode:
		"salvager":
			# (once the first wave's banner has gone, so the GOLD SALVAGER! callout shows)
			await _wait(3.4)
			var s: Enemy = SALVAGER.new()
			s.position = mech.global_position + Vector2(190, -40)
			s.max_hp = 360.0
			arena.world.add_child(s)
			await _wait(0.4)
			s.take_damage(110.0, s.global_position, mech)
			await _wait(0.12)
		"frenzy":
			Game.start_frenzy()
			hud._on_salvager_caught(&"frenzy", 0.0)
			await _wait(1.6)
			Game.frenzy_t = 13.4
			hud._on_contract_done(&"elite_hunter")
			await _burst(mech, [Vector2(150, -40), Vector2(120, 70), Vector2(-140, 50), Vector2(-60, -120)])
			await _wait(0.45)
		"pool":
			# A kill's mastery tips the Armory Mastery Pool over its 25% checkpoint.
			Game.mastery_pool = Game.pool_checkpoint_xp(1) - 1
			await _burst(mech, [Vector2(150, -40), Vector2(-140, 50)])
			await _wait(0.6)
		"results":
			Game.earn_scrap(420.0, &"boss")
			Game.credit_scrap(380.0, &"gold")
			Game.mastery[Game.weapon] = 640
			Contracts.completed_run.assign([&"boss_breaker", &"elite_hunter"])
			Game.mark_cleared()
			hud._show_victory()
			await _wait(2.8)


## Destroys fresh robots around the mech (scrap chips + XP shards).
func _burst(mech: Mech, offsets: Array) -> void:
	var bots: Array[Enemy] = []
	for o: Vector2 in offsets:
		var e: Enemy = CHASER.instantiate()
		e.move_speed = 0.0
		e.contact_damage = 0.0
		e.set("lunge_range", 0.0)
		e.position = mech.global_position + o
		get_tree().current_scene.add_child(e)
		bots.append(e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for e in bots:
		if is_instance_valid(e) and not e.dead:
			e.take_damage(e.hp + e.armor * maxi(e.armor_tier, 1), e.global_position, mech)
