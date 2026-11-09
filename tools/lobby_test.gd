extends Node
## Title lobby (ui/main_menu.gd) checks and captures. Attach to the main menu:
##   godot --headless --path . -- --temp-save --scrap=4200 --attach=res://tools/lobby_test.gd --lobby-nav-test [--portrait]
##       keyboard / gamepad navigation: walks a fixed route of ui_up / ui_left... presses from LAUNCH and checks
##       where focus lands each time -> "LOBBY NAV TEST OK" or the first wrong step. (Needs --scrap=4200 so the
##       upgrade strip shows.)
##   godot --headless --path . -- --temp-save --scrap=4200 --attach=res://tools/lobby_test.gd --lobby-flow-test
##       every lobby button opens its page (cards, tiles, settings, upgrade strip, Back), then LAUNCH on a fresh
##       save goes tutorial offer -> Skip -> difficulty -> loadout -> START into Arena 1 -> "LOBBY FLOW TEST OK"
##   godot --path . --resolution 1920x1080 -- --temp-save --attach=res://tools/lobby_test.gd [--lobby-progress]
##       [--lobby-focus=campaign|endless|upgrade|launch|tile0..3|settings_btn] --shot=out.png --shot-time=3.6
##       preview captures: --lobby-progress fakes 3 cleared arenas and a best Endless wave of 23 (in memory only,
##       nothing is saved); --lobby-focus highlights one widget.

const STEPS := ["ui_up", "ui_up", "ui_up", "ui_up", "ui_up", "ui_left", "ui_left", "ui_down", "ui_right", "ui_right",
	"ui_down", "ui_down", "ui_right", "ui_up", "ui_left", "ui_up", "ui_up", "ui_right", "ui_left", "ui_down"]
## Where focus should be after each step (starting on LAUNCH).
const LANDSCAPE := ["upgrade", "endless", "campaign", "settings_btn", "settings_btn", "tile1", "tile0", "tile2", "tile3",
	"endless", "upgrade", "launch", "launch", "upgrade", "tile3", "tile1", "tile1", "campaign", "tile1", "tile3"]
const PORTRAIT := ["upgrade", "campaign", "tile0", "settings_btn", "settings_btn", "settings_btn", "settings_btn", "tile3",
	"tile3", "tile3", "endless", "upgrade", "upgrade", "campaign", "campaign", "tile0", "settings_btn", "exit_btn",
	"settings_btn", "tile3"]


func _ready() -> void:
	var menu := get_parent()
	if not menu.has_method("_refresh_lobby"):
		# (--attach also fires in the arena the flow test starts; only the menu copy runs)
		queue_free()
		return
	var args := OS.get_cmdline_user_args()
	if args.has("--lobby-progress"):
		Game.cleared.clear()
		Game.cleared.append_array([0, 1, 2])
		Game.endless_best = 23
		menu.call("_refresh")
	if args.has("--lobby-nav-test"):
		_nav_test(menu)
		return
	if args.has("--lobby-flow-test"):
		_flow_test(menu)
		return
	for a in args:
		if a.begins_with("--lobby-focus="):
			await get_tree().create_timer(1.6).timeout
			_widget(menu, a.trim_prefix("--lobby-focus=")).grab_focus()


func _widget(menu: Node, key: String) -> Control:
	if key.begins_with("tile"):
		return (menu.get("_tiles") as Array)[int(key.trim_prefix("tile"))]
	return menu.get("_" + key)


func _flow_test(menu: Node) -> void:
	await get_tree().create_timer(2.5).timeout
	var fails: Array[String] = []
	# Each lobby button -> its page, then Back (ui_cancel) to the lobby.
	for c: Array in [["campaign", 1], ["endless", 4 if Game.tutorial_done else 5], ["tile0", 3], ["tile1", 7],
			["settings_btn", 2], ["upgrade", 7]]:
		_widget(menu, c[0]).emit_signal("pressed")
		await get_tree().process_frame
		var page := int(menu.get("_page"))
		if page != int(c[1]):
			fails.append("%s opened page %d, expected %d" % [c[0], page, c[1]])
		menu.call("_show", 0)
		await get_tree().process_frame
	# LAUNCH on a fresh save: the New Game flow.
	Game.cleared.clear()
	menu.call("_refresh")
	_widget(menu, "launch").emit_signal("pressed")
	await get_tree().process_frame
	if int(menu.get("_page")) == 5:
		for b in (menu.get("_boxes")[5] as Control).get_children():
			if b is TitleButton and (b as TitleButton).label_text.begins_with("Skip"):
				b.emit_signal("pressed")
		await get_tree().process_frame
	if int(menu.get("_page")) != 4:
		fails.append("LAUNCH (new game) reached page %d, expected the difficulty picker" % int(menu.get("_page")))
	(menu.get("_diff_btns") as Array)[1].emit_signal("pressed")
	await get_tree().process_frame
	if int(menu.get("_page")) != 6:
		fails.append("difficulty -> page %d, expected the loadout" % int(menu.get("_page")))
	print("LOBBY FLOW: pages checked, starting the run")
	# (out of the menu first: it's freed when the arena loads)
	var menu_id := menu.get_instance_id()
	reparent(get_tree().root)
	(menu.get("_loadout") as ArmoryPage).start_pressed.emit()
	var arena: Node = null
	for i in 240:
		await get_tree().process_frame
		var s := get_tree().current_scene
		if s and s.get_instance_id() != menu_id and s.is_in_group("arena"):
			arena = s
			break
	if arena == null:
		fails.append("LOBBY START didn't reach an arena")
	elif Game.arena_index != 0:
		fails.append("New Game started arena %d, expected 1" % (Game.arena_index + 1))
	print("LOBBY FLOW TEST OK" if fails.is_empty() else "LOBBY FLOW TEST FAILED: " + "; ".join(fails))
	get_tree().quit(0 if fails.is_empty() else 1)


func _nav_test(menu: Node) -> void:
	await get_tree().create_timer(2.5).timeout
	var names := {}
	for k in ["settings_btn", "exit_btn", "campaign", "endless", "upgrade", "launch"]:
		var w: Variant = menu.get("_" + k)
		if w:
			names[w] = k
	var tiles: Array = menu.get("_tiles")
	for i in tiles.size():
		names[tiles[i]] = "tile%d" % i
	var expect: Array = PORTRAIT if Layout.portrait else LANDSCAPE
	_widget(menu, "launch").grab_focus()
	await get_tree().process_frame
	var trace := "LOBBY NAV (%s): launch" % ("portrait" if Layout.portrait else "landscape")
	var failed := ""
	for i in STEPS.size():
		var s: String = STEPS[i]
		for pressed in [true, false]:
			var ev := InputEventAction.new()
			ev.action = s
			ev.pressed = pressed
			Input.parse_input_event(ev)
			await get_tree().process_frame
		var f := get_viewport().gui_get_focus_owner()
		var got: String = names.get(f, f.get_class() if f else "none")
		trace += "  %s>%s" % [s.trim_prefix("ui_"), got]
		if failed == "" and got != expect[i]:
			failed = "step %d (%s): focus on %s, expected %s" % [i + 1, s, got, expect[i]]
	print(trace)
	print("LOBBY NAV TEST OK" if failed == "" else "LOBBY NAV TEST FAILED: " + failed)
	get_tree().quit(0 if failed == "" else 1)
