extends Node
## Weapon Range MECH picker test (ui/gun_range_panel.gd + environment/gun_range.gd select_chassis):
##   godot --headless --path . -- --gun-range --temp-save --attach=res://tools/range_mech_test.gd [--touch] [--portrait]
## Picks RAVEN CLAW (phantom, not owned) from the picker, checks the reloaded range flies it with the same weapon,
## that the save would still write the Hangar chassis, then picks FROSTBLADE, then leaves to the menu and checks
## the real chassis is back. -> "RANGE MECH TEST OK (0 failed)"

static var _running := false
var _fails := 0


func _ready() -> void:
	if _running:
		queue_free()
		return
	_running = true
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _range() -> Node:
	return get_tree().current_scene


func _pick(id: StringName) -> void:
	var panel: CanvasLayer = _range().panel
	panel.call("_toggle_mech")
	await _frames(2)
	var btn: Button = null
	for b: Button in panel.get("_mech_btns"):
		if b.get_meta("id") == id:
			btn = b
	_check("picker has a %s button, visible once MECH is opened" % id, btn != null and btn.is_visible_in_tree())
	btn.emit_signal("pressed")
	await _frames(25)


func _run() -> void:
	reparent(get_tree().root)
	await _frames(10)
	var home: StringName = Game.chassis
	Game.range_chassis_restore = &""
	_range().select_weapon(&"sniper", false)
	await _frames(2)

	await _pick(&"phantom")
	var mech := get_tree().get_first_node_in_group("player") as Mech
	_check("the range reloaded with RAVEN CLAW", mech != null and mech._chassis_id == &"phantom")
	_check("the weapon carried over (sniper)", mech != null and mech.weapon == &"sniper")
	_check("own art, not the tinted NIMBUS sheet", mech != null and mech.walk_art == "raven" and mech._hover and String(mech._frames_gun.get_meta(&"sheet_dir", "")).contains("/mechs/raven"))
	_check("save() would still write the Hangar chassis (%s)" % home, Game.range_chassis_restore == home)
	var tog: Button = _range().panel.get("_mech_toggle")
	_check("toggle names the mech (%s)" % tog.text, tog.text.begins_with("MECH: RAVEN CLAW"))

	await _pick(&"duelist")
	mech = get_tree().get_first_node_in_group("player") as Mech
	_check("then FROSTBLADE", mech != null and mech._chassis_id == &"duelist")
	_check("restore still the Hangar chassis", Game.range_chassis_restore == home)

	Game.to_menu()
	await _frames(30)
	_check("leaving the range puts the Hangar chassis back (%s)" % Game.chassis, Game.chassis == home
		and Game.range_chassis_restore == &"")

	print("RANGE MECH TEST %s (%d failed)" % ["OK" if _fails == 0 else "FAILED", _fails])
	get_tree().quit(1 if _fails else 0)


func _check(what: String, ok: bool) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		_fails += 1
