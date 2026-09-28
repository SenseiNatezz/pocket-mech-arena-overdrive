extends Node
## RETRY BOSS test:  godot --path . -- --arena=2 --boss-retry-test --temp-save --no-intro
## Reaches the boss, dies, presses RETRY BOSS and checks the arena reloads straight into the boss fight
## (no waves) with the level / upgrades / kills from when the boss appeared. Moves itself to the tree
## root so it survives the scene reload.

var _fails := 0


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


func _wait_until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return cond.call()


func _run() -> void:
	reparent(get_tree().root)
	await _frames(10)
	var arena := get_tree().current_scene
	var mech := get_tree().get_first_node_in_group("player") as Mech
	_check("a campaign arena with no boss checkpoint yet", arena is ScenicArena and not Game.can_retry_boss())
	# Some progress to carry: level 4 with two upgrades and a few kills.
	Upgrades.level = 4
	Upgrades.stacks = {&"power": 2, &"rapid": 1}
	Game.kills = 17
	mech._invuln = 1e9
	arena.debug_skip_to_boss()
	await _frames(5)
	_check("boss fight saves a checkpoint", Game.can_retry_boss() and Game.boss_checkpoint["level"] == 4)
	# Lose the fight.
	Upgrades.level = 6
	Upgrades.stacks = {}
	mech._invuln = 0.0
	mech.take_damage(99999.0, mech.global_position, null)
	var hud := arena.get_node("HUD")
	await _wait_until(func() -> bool: return hud._over_panel.visible, 5.0)
	_check("game over offers RETRY BOSS", hud._over_panel.visible and hud._retry_boss_btn.visible)
	hud._retry_boss()
	# Compare instance ids: the old scene is freed during the reload, so don't capture the node itself.
	var old_id := arena.get_instance_id()
	await _wait_until(func() -> bool: return get_tree().current_scene != null \
		and get_tree().current_scene.get_instance_id() != old_id and get_tree().current_scene.is_node_ready(), 10.0)
	var again := get_tree().current_scene
	_check("the same arena reloads in boss-retry mode", again is ScenicArena and Game.start_at_boss)
	_check("level + upgrades + kills restored (L%d, %s, %d kills)" % [Upgrades.level, Upgrades.stacks, Game.kills],
		Upgrades.level == 4 and Upgrades.level_of(&"power") == 2 and Upgrades.level_of(&"rapid") == 1 and Game.kills == 17)
	await _frames(5)
	(get_tree().get_first_node_in_group("player") as Mech)._invuln = 1e9
	var boss_in := await _wait_until(func() -> bool: return again.boss != null, 6.0)
	_check("the boss drops straight in", boss_in)
	_check("no waves were fought", again.zone.wave == 0 and again.zone.is_cleared)
	_check("still retryable after this attempt", Game.can_retry_boss())
	Game.start_arena(Game.arena_index)
	await _frames(2)
	_check("a fresh start of the arena clears the boss checkpoint", not Game.can_retry_boss())
	print("BOSS RETRY TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(0 if _fails == 0 else 1)
