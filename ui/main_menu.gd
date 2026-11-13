extends Control
## Title screen + lobby (redesigned 2026-11-08 from real game lobbies: Apex Legends, Brawl Stars, Mech Arena,
## Mecha BREAK, Gundam Breaker 4). Over the animated hero scene (ui/title_scene.gd: NIMBUS-07 on its
## holo-pedestal under the gold halo, standing between the two columns):
##   top left      the POCKET MECH ARENA logo (glint; slams in on the first visit)
##   top right     resource chips (scrap, best Endless wave, weapons unlocked) + SETTINGS / EXIT buttons
##   left column   nav tiles ARMORY (equipped weapon crossed with another) / HANGAR (gold badge = upgrades you
##                 can afford) / CUSTOMIZE (a fan deck in your colours) / WEAPON RANGE, and the MOBILE UNIT name
##                 plate (chassis, equipped weapon + its mastery)
##   right column  SELECT OPERATION: CAMPAIGN (next arena's real art, arena pips) and ENDLESS (best wave, next
##                 weapon unlock) cards, the next Hangar upgrade (scrap bar toward it) and the gold LAUNCH
##                 button (continues the campaign; New Game the first time)
## Portrait: logo on top, the mech in the middle, then the tiles in a row, the two cards side by side, the
## upgrade strip and LAUNCH at the bottom (no name plate).
## Sub-pages open in a glass console on the right (portrait: at the bottom) while the mech glides aside:
##   1 select arena (New Game + an art row per arena), 2 settings, 4 difficulty, 5 first-run tutorial offer.
## Full-screen pages: 3 armory (ui/armory_page.gd), 6 loadout (starting weapon, after the difficulty),
## 7 hangar (ui/hangar_page.gd), 8 controls (from Settings).
## Mouse, touch and keyboard / gamepad all work (focus + ui_accept, ui_cancel = back). The look is in
## ui/lobby_kit.gd + ui/lobby_widgets.gd; `-- --menu-page=N` opens page N (captures).

const SHINE := preload("res://ui/logo_shine.gdshader")
const LOGO := preload("res://assets/hq/title_logo.png")
## Card art: crops of the real arena maps (art_src/menu/make_menu_thumbs.py), in Game.ARENAS order.
const ARENA_ART: Array[Texture2D] = [preload("res://assets/hq/menu/arena_0.jpg"), preload("res://assets/hq/menu/arena_1.jpg"),
	preload("res://assets/hq/menu/arena_2.jpg"), preload("res://assets/hq/menu/arena_3.jpg"),
	preload("res://assets/hq/menu/arena_4.jpg"), preload("res://assets/hq/menu/arena_5.jpg"),
	preload("res://assets/hq/menu/arena_6.jpg"), preload("res://assets/hq/menu/arena_7.jpg")]
const ENDLESS_ART := preload("res://assets/hq/menu/endless.jpg")
## Screen margin, and the landscape columns' widths (left: logo / tiles / name plate; right: operations).
const M := 28.0
const LEFT_W := 280.0
const RIGHT_W := 396.0
## Width of a sub-page's buttons (its console adds LobbyWidgets.Frame.PAD on each side).
const COL_W := 460.0
const ARMORY_PAGE := 3
const DIFFICULTY_PAGE := 4
## First run: offered before the difficulty picker until the tutorial is played or skipped.
const TUTORIAL_PAGE := 5
## Loadout: choose the starting weapon before every New Game / Endless run (after the difficulty).
const LOADOUT_PAGE := 6
## Hangar: spend scrap on chassis and permanent upgrades (ui/hangar_page.gd).
const HANGAR_PAGE := 7
## Settings > Controls: key rebinding (ui/controls_page.gd).
const CONTROLS_PAGE := 8
## Settings > Save Backup: copy the save as a code / load one (Game.export_save_code / read_save_code).
const BACKUP_PAGE := 9

var _scene: TitleScene
var _logo: TextureRect
var _logo_rect := Rect2()
var _shade: Control
var _lobby: Control
var _chips: LobbyWidgets.Chips
var _settings_btn: LobbyWidgets.IconButton
var _exit_btn: LobbyWidgets.IconButton
## ARMORY, HANGAR, CUSTOMIZE, WEAPON RANGE.
var _tiles: Array[LobbyWidgets.Tile] = []
var _unit: LobbyWidgets.Unit
var _campaign: LobbyWidgets.Card
var _endless: LobbyWidgets.Card
var _upgrade: LobbyWidgets.Upgrade
var _launch: LobbyWidgets.Launch
var _pages: Array[Control] = []
## Console pages: page index -> the VBox holding its buttons.
var _boxes := {}
var _page := 0
## The lobby button to give focus back to when a sub-page closes.
var _lobby_focus: Control
var _arena_btns: Array[LobbyWidgets.Card] = []
var _shake_btn: TitleButton
var _vol_btn: TitleButton
var _music_btn: TitleButton
var _sfx_btn: TitleButton
var _armory: ArmoryPage
var _loadout: ArmoryPage
var _hangar: HangarPage
var _radio_btn: TitleButton
var _zoom_btn: TitleButton
var _text_btn: TitleButton
var _dyncam_btn: TitleButton
var _rumble_btn: TitleButton
var _numbers_btn: TitleButton
var _full_btn: TitleButton
var _autofire_btn: TitleButton
var _layout_btn: TitleButton
var _controls: ControlsPage
var _backup_info: Label
var _backup_confirm: TitleButton
## The decoded backup waiting for "Replace My Save" (read_save_code()), {} = none.
var _backup_pending := {}
## Web app (PWA): shown when a newer version of the game has been downloaded in the background.
var _update_btn: TitleButton
var _diff_btn: TitleButton
var _diff_btns: Array[TitleButton] = []
var _diff_info: Label
## What the difficulty picker starts once a difficulty is chosen (New Game or Endless Mode).
var _diff_then: Callable
var _weapon_art := {}
var _t := 0.0
var _last_size := Vector2.ZERO
## The mech glides (x, height, feet) toward where this page wants it.
var _mech := Vector3(-1, 0, 0)
var _mech_to := Vector3.ZERO
## Shade: where the right column / console starts (landscape x) or the bottom block starts (portrait y).
var _shade_edge := 0.0
## "SELECT OPERATION" caption position (left end of its baseline).
var _ops_caption := Vector2.ZERO


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Every TitleButton drawn while the title screen is up (sub-pages, Armory, Hangar...) uses the lobby look.
	TitleButton.lobby_style = true

	# Animated hero scene: space backdrop, the player's mech on a holo-pedestal (ui/title_scene.gd).
	_scene = TitleScene.new()
	add_child(_scene)
	# Darkening of the backdrop behind the columns so they read clearly (under the mech, not over it).
	_shade = Control.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.draw.connect(_draw_shade)
	_scene.add_backdrop_layer(_shade)

	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A light glint sweeps across the logo every few seconds.
	var shine := ShaderMaterial.new()
	shine.shader = SHINE
	_logo.material = shine
	add_child(_logo)

	# 0: the lobby.
	_lobby = Control.new()
	_lobby.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lobby.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lobby.draw.connect(_draw_lobby)
	add_child(_lobby)
	_pages.append(_lobby)
	_build_lobby()

	# 1: select arena (the next one is focused): New Game, then a row per arena with its map art.
	var cont := _page_box("SELECT ARENA", 8)
	_btn(cont, "New Game  (from Arena 1)", _pick_difficulty.bind(Game.new_game), Vector2(COL_W, 46))
	for i in Game.ARENAS.size():
		var row := LobbyWidgets.Card.new()
		row.custom_minimum_size = Vector2(COL_W, 48)
		row.kicker = str(i + 1)
		row.title = String(Game.ARENAS[i]["name"]).to_upper()
		row.art = _arena_art(i)
		row.pressed.connect(Game.start_arena.bind(i))
		cont.add_child(row)
		_arena_btns.append(row)
	_btn(cont, "Back", _show.bind(0), Vector2(COL_W, 46))

	# 2: settings, a 2-column grid of toggles / cycles (touch options only where there's a touch screen,
	# Fullscreen and Controls only where there's a keyboard).
	var settings := _page_box("SETTINGS", 8)
	_diff_btn = _btn(settings, "", func() -> void:
		Game.set_difficulty((Game.difficulty + 1) % Game.DIFFICULTIES.size())
		_refresh(), Vector2(COL_W, 42))
	var sgrid := GridContainer.new()
	sgrid.columns = 2
	sgrid.add_theme_constant_override("h_separation", 12)
	sgrid.add_theme_constant_override("v_separation", 8)
	settings.add_child(sgrid)
	var cell := Vector2((COL_W - 12.0) / 2.0, 40)
	_shake_btn = _grid_btn(sgrid, func() -> void: Game.set_screen_shake(not Game.screen_shake), cell)
	_vol_btn = _grid_btn(sgrid, func() -> void:
		Game.set_volume(Game.master_volume + 0.2 if Game.master_volume < 0.99 else 0.0), cell)
	_music_btn = _grid_btn(sgrid, func() -> void:
		Game.set_music_volume(Game.music_volume + 0.1 if Game.music_volume < 0.99 else 0.0), cell)
	_sfx_btn = _grid_btn(sgrid, func() -> void:
		Game.set_sfx_volume(Game.sfx_volume + 0.1 if Game.sfx_volume < 0.99 else 0.0)
		Sfx.play(&"pickup", -6.0), cell)
	_radio_btn = _grid_btn(sgrid, func() -> void:
		Game.radio_voice = not Game.radio_voice
		Game.save(), cell)
	_zoom_btn = _grid_btn(sgrid, func() -> void: Game.set_camera_zoom((Game.camera_zoom + 1) % Game.CAMERA_ZOOMS.size()), cell)
	_text_btn = _grid_btn(sgrid, func() -> void: Game.set_text_size((Game.text_size + 1) % Game.TEXT_SIZES.size()), cell)
	_dyncam_btn = _grid_btn(sgrid, func() -> void:
		Game.dynamic_camera = not Game.dynamic_camera
		Game.save(), cell)
	_numbers_btn = _grid_btn(sgrid, func() -> void:
		Game.damage_numbers = not Game.damage_numbers
		Game.save(), cell)
	if not OS.has_feature("web") and not OS.has_feature("mobile"):
		_rumble_btn = _grid_btn(sgrid, func() -> void:
			Game.rumble = not Game.rumble
			Game.save()
			if Game.rumble:
				for pad in Input.get_connected_joypads():
					Input.start_joy_vibration(pad, 0.4, 0.6, 0.25), cell)
	if Game.can_fullscreen():
		_full_btn = _grid_btn(sgrid, func() -> void: Game.set_fullscreen(not Game.is_fullscreen()), cell)
	if Controls.touch_active:
		_autofire_btn = _grid_btn(sgrid, func() -> void:
			Game.auto_fire = not Game.auto_fire
			Game.save(), cell)
		_layout_btn = _grid_btn(sgrid, func() -> void:
			Game.touch_simple = not Game.touch_simple
			Game.save(), cell)
	if not OS.has_feature("mobile"):
		var keys := TitleButton.new("Controls", cell)
		keys.pressed.connect(_show.bind(CONTROLS_PAGE))
		sgrid.add_child(keys)
	var tut_btn := TitleButton.new("Tutorial", cell)
	tut_btn.pressed.connect(Game.to_tutorial)
	sgrid.add_child(tut_btn)
	var backup_btn := TitleButton.new("Save Backup", cell)
	backup_btn.pressed.connect(_show.bind(BACKUP_PAGE))
	sgrid.add_child(backup_btn)
	var help := _heading(settings, "F11: fullscreen.  Pause in-game (Esc / Start / II) to see the controls.")
	help.add_theme_font_size_override("font_size", 15)
	help.add_theme_color_override("font_color", Color(LobbyKit.DIM, 0.9))
	_btn(settings, "Back", _show.bind(0), Vector2(COL_W, 42))

	# 3: Armory, full-screen weapon cards (ui/armory_page.gd).
	_armory = ArmoryPage.new()
	_armory.back_pressed.connect(_show.bind(0))
	add_child(_armory)
	_pages.append(_armory)

	# 4: difficulty picker.
	var pick := _page_box("SELECT DIFFICULTY", 8)
	for i in Game.DIFFICULTIES.size():
		var d: Dictionary = Game.DIFFICULTIES[i]
		var b := _btn(pick, d["name"], _on_difficulty_chosen.bind(i), Vector2(COL_W, 44))
		b.focus_entered.connect(_show_difficulty_info.bind(i))
		_diff_btns.append(b)
	_diff_info = _heading(pick, "")
	_diff_info.custom_minimum_size = Vector2(COL_W, 58)
	_btn(pick, "Back", _show.bind(0), Vector2(COL_W, 44))

	# 5: first-run tutorial offer (New Game / Endless before the tutorial has been played or skipped).
	var tut := _page_box("NEW PILOT?", 10)
	var tut_info := _heading(tut, "Learn to move, fight, dash and level up in a quick 2-minute training mission.")
	tut_info.custom_minimum_size = Vector2(COL_W, 50)
	_btn(tut, "Play Tutorial", Game.to_tutorial, Vector2(COL_W, 48))
	_btn(tut, "Skip - I know how to play", func() -> void:
		Game.finish_tutorial()
		_show(DIFFICULTY_PAGE), Vector2(COL_W, 48))
	_btn(tut, "Back", _show.bind(0), Vector2(COL_W, 48))

	# 6: loadout (weapon cards in start mode).
	_loadout = ArmoryPage.new()
	_loadout.start_mode = true
	_loadout.back_pressed.connect(_show.bind(DIFFICULTY_PAGE))
	_loadout.start_pressed.connect(func() -> void:
		if _diff_then.is_valid():
			_diff_then.call())
	add_child(_loadout)
	_pages.append(_loadout)
	# 7: Hangar, full-screen scrap shop (chassis + permanent upgrades).
	_hangar = HangarPage.new()
	_hangar.back_pressed.connect(func() -> void:
		_refresh()
		_show(0))
	add_child(_hangar)
	_pages.append(_hangar)
	# 8: Controls, key rebinding (back to Settings).
	_controls = ControlsPage.new()
	_controls.back_pressed.connect(_show.bind(2))
	add_child(_controls)
	_pages.append(_controls)
	# 9: Save Backup (from Settings).
	var bk := _page_box("SAVE BACKUP", 10)
	var bk_help := _heading(bk, "Your progress is saved on this device only. Copy your save code and keep it somewhere "
		+ "safe (Notes, a message to yourself), then load it on another phone, PC or browser to bring your scrap, "
		+ "mechs, weapons and campaign along.")
	bk_help.add_theme_font_size_override("font_size", 16)
	_btn(bk, "Copy Save Code", _backup_copy, Vector2(COL_W, 46))
	_btn(bk, "Load Save Code", _backup_load, Vector2(COL_W, 46))
	_backup_info = _heading(bk, "")
	_backup_info.add_theme_font_size_override("font_size", 16)
	_backup_info.add_theme_color_override("font_color", LobbyKit.GOLD)
	_backup_confirm = _btn(bk, "Replace My Save", _backup_apply, Vector2(COL_W, 46))
	_backup_confirm.visible = false
	_btn(bk, "Back", _show.bind(2), Vector2(COL_W, 42))

	# WEB APP UPDATE: the home-screen app (PWA) caches the game for offline play, so a new release would
	# only load on the launch after next; this button swaps it in straight away.
	_update_btn = TitleButton.new("UPDATE READY - TAP TO RESTART", Vector2(340, 44))
	_update_btn.visible = false
	_update_btn.pressed.connect(func() -> void:
		_update_btn.label_text = "UPDATING..."
		JavaScriptBridge.pwa_update())
	add_child(_update_btn)
	if OS.has_feature("web"):
		JavaScriptBridge.pwa_update_available.connect(_show_update_btn)
		if JavaScriptBridge.pwa_needs_update():
			_show_update_btn.call_deferred()
	Layout.changed.connect(func(_portrait: bool) -> void: _layout())
	_refresh()
	_show(0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu-page="):
			_show(int(a.trim_prefix("--menu-page=")))
	# Fade in from black.
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
	_entrance()
	Sfx.warm_up()


func _exit_tree() -> void:
	TitleButton.lobby_style = false


## The lobby's widgets (placed by _layout, filled in by _refresh_lobby).
func _build_lobby() -> void:
	_chips = LobbyWidgets.Chips.new()
	_lobby.add_child(_chips)
	_settings_btn = LobbyWidgets.IconButton.new(&"gear", "SETTINGS")
	_settings_btn.pressed.connect(_show.bind(2))
	_lobby.add_child(_settings_btn)
	if OS.get_name() != "Web":
		_exit_btn = LobbyWidgets.IconButton.new(&"power", "EXIT")
		_exit_btn.pressed.connect(get_tree().quit)
		_lobby.add_child(_exit_btn)
	for entry: Array in [["ARMORY", &"armory", _show.bind(ARMORY_PAGE)], ["HANGAR", &"hangar", _show.bind(HANGAR_PAGE)],
			["CUSTOMIZE", &"paint", Game.to_customize], ["WEAPON RANGE", &"target", Game.to_gun_range]]:
		var tile := LobbyWidgets.Tile.new(entry[0], entry[1])
		tile.pressed.connect(entry[2])
		_lobby.add_child(tile)
		_tiles.append(tile)
	_unit = LobbyWidgets.Unit.new()
	_lobby.add_child(_unit)
	_campaign = LobbyWidgets.Card.new()
	_campaign.pressed.connect(_show.bind(1))
	_lobby.add_child(_campaign)
	_endless = LobbyWidgets.Card.new()
	_endless.art = ENDLESS_ART
	_endless.art_focus = Vector2(0.6, 0.5)
	_endless.accent = Color(1.0, 0.56, 0.3)
	_endless.pressed.connect(_pick_difficulty.bind(func() -> void: Game.start_endless()))
	_lobby.add_child(_endless)
	_upgrade = LobbyWidgets.Upgrade.new()
	_upgrade.pressed.connect(_show.bind(HANGAR_PAGE))
	_lobby.add_child(_upgrade)
	_launch = LobbyWidgets.Launch.new()
	_launch.pressed.connect(_on_launch)
	_lobby.add_child(_launch)


## LAUNCH: straight into the next campaign arena once there's progress; the first time it's a New Game
## (tutorial offer / difficulty / loadout first).
func _on_launch() -> void:
	if Game.has_progress():
		Game.start_arena(Game.continue_index())
	else:
		_pick_difficulty(Game.new_game)


## Entrance: the logo slams in (the first time per launch, timed to the mech dropping onto its pedestal), then
## the chips drop in from the top, the left column slides in from the left and the operations from the right.
func _entrance() -> void:
	var first := _scene.intro_active()
	if first:
		_logo.scale = Vector2(1.35, 1.35)
		_logo.modulate.a = 0.0
		var lt := create_tween().set_parallel()
		lt.tween_property(_logo, "scale", Vector2.ONE, 0.55).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		lt.tween_property(_logo, "modulate:a", 1.0, 0.25).set_delay(0.3)
	var order: Array = [_chips, _settings_btn, _exit_btn]
	order.append_array(_tiles)
	order.append_array([_unit, _campaign, _endless, _upgrade, _launch])
	var i := 0
	for w in order:
		if w == null:
			continue
		w.slide = 1.0
		w.create_tween().tween_property(w, "slide", 0.0, 0.4).set_delay((0.75 if first else 0.1) + i * 0.05) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		i += 1


## A sub-page: a glass console titled `title` with a VBox for its buttons. Returns the VBox.
func _page_box(title: String, separation := 10) -> VBoxContainer:
	var f := LobbyWidgets.Frame.new(title)
	add_child(f)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.position = Vector2(LobbyWidgets.Frame.PAD, LobbyWidgets.Frame.HEADER + 14.0)
	f.add_child(v)
	_boxes[_pages.size()] = v
	_pages.append(f)
	return v


func _btn(page: VBoxContainer, label: String, action: Callable, min_size := Vector2(COL_W, 50)) -> TitleButton:
	var b := TitleButton.new(label, min_size)
	b.pressed.connect(action)
	page.add_child(b)
	return b


## Settings grid cell: runs `action`, then refreshes every label (they show the current values).
func _grid_btn(grid: GridContainer, action: Callable, min_size: Vector2) -> TitleButton:
	var b := TitleButton.new("", min_size)
	b.pressed.connect(func() -> void:
		action.call()
		_refresh())
	grid.add_child(b)
	return b


func _heading(page: VBoxContainer, txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_override("font", LobbyKit.COND)
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", LobbyKit.TEXT)
	l.add_theme_color_override("font_outline_color", Color(0, 0.02, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(COL_W, 0)
	page.add_child(l)
	return l


func _show(which: int) -> void:
	if _page == 0 and which != 0:
		var focused := get_viewport().gui_get_focus_owner()
		if focused and _lobby.is_ancestor_of(focused):
			_lobby_focus = focused
	_page = which
	for i in _pages.size():
		_pages[i].visible = i == which
	_logo.visible = which in [0, 1, 2, DIFFICULTY_PAGE, TUTORIAL_PAGE, BACKUP_PAGE]
	_layout()
	if _boxes.has(which):
		# Consoles fade in.
		_pages[which].modulate.a = 0.0
		_pages[which].create_tween().tween_property(_pages[which], "modulate:a", 1.0, 0.18)
	var focus: Control = null
	match which:
		0:
			focus = _lobby_focus if is_instance_valid(_lobby_focus) and _lobby_focus.is_visible_in_tree() else _launch
		1:
			focus = _arena_btns[mini(Game.continue_index(), _arena_btns.size() - 1)]
		2:
			_refresh()
			focus = _diff_btn
		ARMORY_PAGE:
			_armory.focus_equipped()
		LOADOUT_PAGE:
			_loadout.focus_equipped()
		HANGAR_PAGE:
			_hangar.refresh()
			_hangar.focus_default()
		CONTROLS_PAGE:
			_controls.focus_default()
		BACKUP_PAGE:
			_backup_reset("")
		DIFFICULTY_PAGE:
			focus = _diff_btns[Game.difficulty]
			_show_difficulty_info(Game.difficulty)
		_:
			if _boxes.has(which):
				for c in (_boxes[which] as Control).get_children():
					if c is Button:
						focus = c
						break
	if focus:
		focus.grab_focus()


func _refresh() -> void:
	_radio_btn.label_text = "Radio Voice: %s" % ("On" if Game.radio_voice else "Off")
	_shake_btn.label_text = "Screen Shake: %s" % ("On" if Game.screen_shake else "Off")
	_vol_btn.label_text = "Volume: %d%%" % roundi(Game.master_volume * 100.0)
	_music_btn.label_text = "Music: %d%%" % roundi(Game.music_volume * 100.0)
	_sfx_btn.label_text = "Sound FX: %d%%" % roundi(Game.sfx_volume * 100.0)
	_diff_btn.label_text = "Difficulty: %s" % Game.difficulty_name()
	_zoom_btn.label_text = "Camera: %s" % Game.CAMERA_ZOOMS[Game.camera_zoom]["name"]
	_text_btn.label_text = "Text Size: %s" % Game.TEXT_SIZES[Game.text_size]["name"]
	_dyncam_btn.label_text = "Dynamic Camera: %s" % ("On" if Game.dynamic_camera else "Off")
	_numbers_btn.label_text = "Damage Numbers: %s" % ("On" if Game.damage_numbers else "Off")
	if _rumble_btn:
		_rumble_btn.label_text = "Rumble: %s" % ("On" if Game.rumble else "Off")
	if _full_btn:
		_full_btn.label_text = "Fullscreen: %s" % ("On" if Game.is_fullscreen() else "Off")
	if _autofire_btn:
		_autofire_btn.label_text = "Auto-Fire: %s" % ("On" if Game.auto_fire else "Off")
		_layout_btn.label_text = "Touch: %s" % ("Simple" if Game.touch_simple else "Full")
	for b in [_diff_btn, _shake_btn, _vol_btn, _music_btn, _sfx_btn, _radio_btn, _zoom_btn, _full_btn, _autofire_btn,
			_layout_btn, _dyncam_btn, _numbers_btn, _rumble_btn]:
		if b:
			b.queue_redraw()
	_refresh_lobby()


## Fills the lobby in from the save: chips, cards, LAUNCH, the next upgrade, tile badges / art, name plate.
func _refresh_lobby() -> void:
	var got := 0
	for w in Game.WEAPONS:
		if Game.is_unlocked(w["id"]):
			got += 1
	_chips.items = [
		{"icon": &"nut", "label": "SCRAP", "value": Game.fmt_int(Game.scrap), "color": LobbyKit.GOLD},
		{"icon": &"trophy", "label": "BEST WAVE", "value": str(Game.endless_best) if Game.endless_best > 0 else "-",
			"color": LobbyKit.CYAN},
		{"icon": &"sword", "label": "WEAPONS", "value": "%d / %d" % [got, Game.WEAPONS.size()], "color": LobbyKit.CYAN},
	]
	var n := Game.ARENAS.size()
	var next := Game.continue_index()
	var next_name := String(Game.ARENAS[next]["name"]).to_upper()
	_campaign.kicker = "STORY CAMPAIGN"
	_campaign.title = "CAMPAIGN"
	if Game.cleared.size() >= n:
		_campaign.info = "ALL %d ARENAS CLEARED  ·  REPLAY ANY ARENA" % n
	elif Game.has_progress():
		_campaign.info = "NEXT: ARENA %d  ·  %s" % [next + 1, next_name]
	else:
		_campaign.info = "%d ARENAS  ·  A BOSS GUARDS EACH ONE" % n
	_campaign.art = _arena_art(next)
	var pips: Array[bool] = []
	for i in n:
		pips.append(Game.cleared.has(i))
	_campaign.pips = pips
	_endless.kicker = "SURVIVAL MODE"
	_endless.title = "ENDLESS"
	_endless.info = ("BEST: WAVE %d" % Game.endless_best if Game.endless_best > 0 else "HOW LONG CAN YOU LAST?") \
		+ "  ·  BOSS EVERY %d WAVES" % Game.ENDLESS_BOSS_EVERY
	var unlock := _next_unlock()
	if unlock.is_empty():
		_endless.progress = 1.0
		_endless.progress_text = "ALL %d WEAPONS UNLOCKED" % Game.WEAPONS.size()
	else:
		var need := int(unlock["waves"])
		_endless.progress = clampf(float(Game.waves_beaten) / maxf(need, 1.0), 0.0, 1.0)
		_endless.progress_text = "NEXT UNLOCK: %s  ·  %d / %d WAVES" % [String(unlock["name"]).to_upper(),
			mini(Game.waves_beaten, need), need]
	_launch.title = "LAUNCH"
	if Game.has_progress():
		_launch.sub = "CONTINUE  ·  ARENA %d: %s  ·  %s" % [next + 1, next_name, Game.difficulty_name().to_upper()]
	else:
		_launch.sub = "NEW GAME  ·  ARENA 1: %s" % String(Game.ARENAS[0]["name"]).to_upper()
	var up := _next_upgrade()
	_upgrade.visible = not up.is_empty()
	if not up.is_empty():
		_upgrade.item = up["name"]
		_upgrade.cost = up["cost"]
		_upgrade.have = Game.scrap
		_upgrade.ready_count = up["ready"]
	# Hangar badge: things you can afford + finished contracts waiting to be claimed (Hangar > CONTRACTS).
	var affordable := int(up.get("ready", 0)) + Contracts.ready_ids().size()
	_tiles[1].badge = str(affordable) if affordable > 0 else ""
	# Armory: the equipped weapon crossed with a contrasting one. Customize: body / trim / energy colours.
	var w := Game.weapon_info(Game.weapon)
	var arts: Array[Texture2D] = [_weapon_tex(&"sword" if not w.get("melee", false) else &"blaster"), _weapon_tex(Game.weapon)]
	_tiles[0].arts = arts
	var cols: Array[Color] = [Game.BODY[clampi(int(Game.look.get("body", 0)), 0, Game.BODY.size() - 1)]["color"],
		Game.armor()["color"], Game.energy_color()]
	_tiles[2].colors = cols
	var ch := Game.chassis_info()
	# The selected frame: its name as the title (NIMBUS-07, ARROWHEAD...), its role on the tag.
	_unit.chassis = String(ch.get("role", ch["name"])).to_upper()
	_unit.mech_name = String(ch["name"]).to_upper()
	_unit.chassis_color = ch["color"]
	_unit.weapon = String(w["name"]).to_upper()
	_unit.weapon_art = _weapon_tex(Game.weapon)
	_unit.mastery = Game.mastery_level(Game.weapon)
	_unit.mastery_f = Game.mastery_fraction(Game.weapon)
	_unit.mastered = Game.is_mastered(Game.weapon)
	_unit.queue_redraw()
	for i in _arena_btns.size():
		var row := _arena_btns[i]
		if Game.cleared.has(i):
			row.tag = "CLEARED"
			row.tag_color = LobbyKit.GOLD
		elif i == next:
			row.tag = "NEXT"
			row.tag_color = LobbyKit.CYAN
		else:
			row.tag = ""
	for t in _tiles:
		t.queue_redraw()
	_layout()


## The next weapon that unlocks from waves beaten ({} once every weapon is unlocked).
func _next_unlock() -> Dictionary:
	var best := {}
	for w in Game.WEAPONS:
		if Game.is_unlocked(w["id"]):
			continue
		if best.is_empty() or int(w["waves"]) < int(best["waves"]):
			best = w
	return best


## The cheapest thing the Hangar sells next (an upgrade or MK level, or a chassis) and how many things are
## affordable right now: {name, cost, ready} ({} if there's nothing left to buy).
func _next_upgrade() -> Dictionary:
	var best := {}
	var n_ready := 0
	for id: StringName in Game.HANGAR:
		var c := Game.hangar_cost(id)
		if c < 0 or Game.hangar_locked(id):
			continue
		if c <= Game.scrap:
			n_ready += 1
		if best.is_empty() or c < int(best["cost"]):
			var info: Dictionary = Game.HANGAR[id]
			var raw := int(Game.hangar.get(id, 0))
			var lvl := ("LV %d" % (raw + 1)) if raw < int(info["max"]) else Game.hangar_mk_name(id, 1)
			best = {"name": "%s  %s" % [String(info["name"]).to_upper(), lvl], "cost": c}
	for ch in Game.CHASSIS:
		if Game.owns_chassis(ch["id"]):
			continue
		var c := Game.chassis_cost(ch["id"])
		if c <= Game.scrap:
			n_ready += 1
		if best.is_empty() or c < int(best["cost"]):
			best = {"name": "%s CHASSIS" % String(ch["name"]).to_upper(), "cost": c}
	if not best.is_empty():
		best["ready"] = n_ready
	return best


func _arena_art(i: int) -> Texture2D:
	return ARENA_ART[clampi(i, 0, ARENA_ART.size() - 1)]


func _weapon_tex(id: StringName) -> Texture2D:
	if not _weapon_art.has(id):
		_weapon_art[id] = load("res://assets/hq/weapons/%s.png" % Game.weapon_info(id)["icon"])
	return _weapon_art[id]


# --- layout -------------------------------------------------------------------------------------------------

## Places everything for the current screen size, orientation and page.
func _layout() -> void:
	var vp := size
	if vp.x < 2.0 or vp.y < 2.0 or _launch == null:
		return
	var console := _console_rect(vp)
	if Layout.portrait:
		_layout_portrait(vp, console)
	else:
		_layout_landscape(vp, console)
	_scene.bg_focus = 0.3 if Layout.portrait else 0.0
	_shade.queue_redraw()
	_lobby.queue_redraw()
	if _update_btn:
		_update_btn.position = Vector2((vp.x - _update_btn.size.x) / 2.0, vp.y * (0.36 if Layout.portrait else 0.02) + 70.0)


## The console of the current sub-page (sized to its buttons), or an empty rect on other pages.
func _console_rect(vp: Vector2) -> Rect2:
	var out := Rect2()
	for idx in _boxes:
		var f: Control = _pages[idx]
		var v: VBoxContainer = _boxes[idx]
		var inner := v.get_combined_minimum_size()
		v.size = Vector2(COL_W, inner.y)
		var fs := Vector2(COL_W + 2.0 * LobbyWidgets.Frame.PAD, LobbyWidgets.Frame.HEADER + 14.0 + inner.y + LobbyWidgets.Frame.PAD)
		var pos := Vector2((vp.x - fs.x) / 2.0, vp.y - M - fs.y) if Layout.portrait \
			else Vector2(vp.x - M - fs.x, clampf((vp.y - fs.y) / 2.0 + 30.0, 74.0, maxf(74.0, vp.y - M - fs.y)))
		f.position = pos
		f.size = fs
		f.queue_redraw()
		if idx == _page:
			out = Rect2(pos, fs)
	return out


func _layout_landscape(vp: Vector2, console: Rect2) -> void:
	var la := float(LOGO.get_width()) / LOGO.get_height()
	var lh := clampf(vp.y * 0.26, 150.0, 250.0)
	_logo_rect = Rect2(M - 6.0, 10.0, lh * la, lh)
	# Top right: settings / exit, the chips left of them.
	var bs := 46.0
	var x := vp.x - M - bs
	if _exit_btn:
		_exit_btn.place(Rect2(x, 16.0, bs, bs))
		x -= bs + 10.0
	_settings_btn.place(Rect2(x, 16.0, bs, bs))
	var cw := _chips.needed_width()
	_chips.place(Rect2(x - 16.0 - cw, 18.0, cw, LobbyWidgets.Chips.H))
	# Left column: 2 x 2 tiles under the logo, the name plate at the bottom.
	var tw := (LEFT_W - 12.0) / 2.0
	var th := 100.0
	var ty := _logo_rect.end.y + 12.0
	for i in _tiles.size():
		_tiles[i].place(Rect2(M + (i % 2) * (tw + 12.0), ty + floorf(i / 2.0) * (th + 12.0), tw, th))
	_unit.visible = true
	_unit.place(Rect2(M, vp.y - M - 118.0, LEFT_W, 118.0))
	# Right column, bottom up: LAUNCH, upgrade strip, ENDLESS, CAMPAIGN.
	var x0 := vp.x - M - RIGHT_W
	var y := vp.y - M - 92.0
	_launch.place(Rect2(x0, y, RIGHT_W, 92.0))
	if _upgrade.visible:
		y -= 12.0 + 62.0
		_upgrade.place(Rect2(x0, y, RIGHT_W, 62.0))
	var ch := clampf((y - 12.0 - 120.0) / 2.0 - 12.0, 112.0, 150.0)
	y -= 12.0 + ch
	_endless.place(Rect2(x0, y, RIGHT_W, ch))
	y -= 12.0 + ch
	_campaign.place(Rect2(x0, y, RIGHT_W, ch))
	_ops_caption = Vector2(x0 + 2.0, y - 11.0)
	_link_focus(false)
	# The mech: between the columns in the lobby, left of the console on a sub-page.
	var aspect := TitleScene.art_aspect()
	var left := M + LEFT_W
	if _page == 0 or console.size.x <= 0.0:
		_mech_to = Vector3((left + x0) / 2.0, minf(vp.y * TitleScene.HERO_H, (x0 - left - 30.0) / aspect),
			vp.y * TitleScene.HERO_FEET)
		_shade_edge = x0
	else:
		var h := minf(vp.y * TitleScene.HERO_H, (console.position.x - 40.0) / aspect)
		var half := h * aspect / 2.0
		_mech_to = Vector3(clampf(console.position.x * 0.5, half + 10.0, console.position.x - half - 24.0), h,
			vp.y * TitleScene.HERO_FEET)
		_shade_edge = console.position.x


func _layout_portrait(vp: Vector2, console: Rect2) -> void:
	var la := float(LOGO.get_width()) / LOGO.get_height()
	var lw := minf(vp.x - 120.0, 450.0)
	_logo_rect = Rect2((vp.x - lw) / 2.0, 66.0, lw, lw / la)
	var bs := 44.0
	var x := vp.x - M - bs
	if _exit_btn:
		_exit_btn.place(Rect2(x, 12.0, bs, bs))
		x -= bs + 8.0
	_settings_btn.place(Rect2(x, 12.0, bs, bs))
	var cw := _chips.needed_width()
	_chips.place(Rect2(maxf(M, x - 12.0 - cw), 13.0, cw, LobbyWidgets.Chips.H))
	# Bottom up: LAUNCH, upgrade strip, the two cards, the tiles.
	var w := vp.x - 2.0 * M
	var y := vp.y - M - 96.0
	_launch.place(Rect2(M, y, w, 96.0))
	if _upgrade.visible:
		y -= 12.0 + 62.0
		_upgrade.place(Rect2(M, y, w, 62.0))
	var cw2 := (w - 12.0) / 2.0
	y -= 12.0 + 150.0
	_campaign.place(Rect2(M, y, cw2, 150.0))
	_endless.place(Rect2(M + cw2 + 12.0, y, cw2, 150.0))
	_ops_caption = Vector2(M + 2.0, y - 11.0)
	var tw := (w - 36.0) / 4.0
	y -= 36.0 + 96.0
	for i in _tiles.size():
		_tiles[i].place(Rect2(M + i * (tw + 12.0), y, tw, 96.0))
	_unit.visible = false
	_link_focus(true)
	# The mech: between the logo and the tiles (lobby) or the console (sub-page), centred.
	var bottom := (y - 30.0) if _page == 0 or console.size.x <= 0.0 else console.position.y - 24.0
	var top := _logo_rect.end.y - _logo_rect.size.y * 0.12
	var aspect := TitleScene.art_aspect()
	_mech_to = Vector3(vp.x / 2.0, clampf(bottom - top, 180.0, (vp.x - 60.0) / aspect), bottom)
	_shade_edge = y if _page == 0 or console.size.x <= 0.0 else console.position.y


## Keyboard / gamepad focus between the lobby's widgets: every side of every widget is set explicitly (a
## neighbour, or null = stay put), so focus never wanders off the layout.
func _link_focus(portrait: bool) -> void:
	var t := _tiles
	var up_of_launch: Control = _upgrade if _upgrade.visible else (_campaign if portrait else _endless)
	var below_cards: Control = _upgrade if _upgrade.visible else _launch
	var top_right: Control = _exit_btn if _exit_btn else null
	if portrait:
		for i in t.size():
			_nav(t[i], t[i - 1] if i > 0 else null, _settings_btn, t[i + 1] if i < t.size() - 1 else null,
				_campaign if i < 2 else _endless)
		_nav(_campaign, null, t[0], _endless, below_cards)
		_nav(_endless, _campaign, t[3], null, below_cards)
		_nav(_upgrade, null, _campaign, null, _launch)
		_nav(_launch, null, up_of_launch, null, null)
		_nav(_settings_btn, null, null, top_right, t[3])
		if _exit_btn:
			_nav(_exit_btn, _settings_btn, null, null, t[3])
		return
	_nav(t[0], null, null, t[1], t[2])
	_nav(t[1], t[0], null, _campaign, t[3])
	_nav(t[2], null, t[0], t[3], null)
	_nav(t[3], t[2], t[1], _endless, null)
	_nav(_campaign, t[1], _settings_btn, null, _endless)
	_nav(_endless, t[3], _campaign, null, below_cards)
	_nav(_upgrade, t[3], _endless, null, _launch)
	_nav(_launch, t[3], up_of_launch, null, null)
	_nav(_settings_btn, t[1], null, top_right, _campaign)
	if _exit_btn:
		_nav(_exit_btn, _settings_btn, null, null, _campaign)


## Sets all four focus neighbours of `c` (null = no move that way).
func _nav(c: Control, left: Control, up: Control, right: Control, down: Control) -> void:
	var sides := [[SIDE_LEFT, left], [SIDE_TOP, up], [SIDE_RIGHT, right], [SIDE_BOTTOM, down]]
	for s in sides:
		var target: Control = s[1]
		c.set_focus_neighbor(s[0], c.get_path_to(target) if target else NodePath("."))



func _show_update_btn() -> void:
	_update_btn.visible = true
	_update_btn.move_to_front()
	_layout()

# --- Settings > Save Backup ------------------------------------------------------------------------------

func _backup_reset(msg: String) -> void:
	_backup_pending = {}
	_backup_confirm.visible = false
	_backup_info.text = msg
	_layout()


## Copies the save code. Desktop: straight to the clipboard. Web: the clipboard too where the browser
## allows it, plus a native text box holding the code (long-press > Copy works there on phones).
func _backup_copy() -> void:
	var code := Game.export_save_code()
	DisplayServer.clipboard_set(code)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.prompt('Your save code - select it all and copy it:', %s)" % JSON.stringify(code))
		_backup_reset("Save code ready (%d characters). Keep it somewhere safe." % code.length())
	else:
		_backup_reset("Save code copied to the clipboard (%d characters). Paste it somewhere safe." % code.length())
	Sfx.play(&"pickup", -6.0)


## Reads a save code (desktop: from the clipboard; web: a native paste box), shows what's in it and waits
## for "Replace My Save".
func _backup_load() -> void:
	var code := ""
	if OS.has_feature("web"):
		var got: Variant = JavaScriptBridge.eval("window.prompt('Paste your save code here:', '')")
		code = str(got) if got != null else ""
	else:
		code = DisplayServer.clipboard_get()
	_backup_check(code)


## Shows what a pasted code holds (or why it's refused) and arms "Replace My Save".
func _backup_check(code: String) -> void:
	if code.strip_edges().is_empty():
		_backup_reset("No code found. Copy your save code first, then press Load Save Code." if not OS.has_feature("web") else "")
		return
	var info := Game.read_save_code(code)
	if info.is_empty():
		_backup_reset("That isn't a Pocket Mech Arena save code. Check you copied all of it (it starts with PMA1:).")
		return
	_backup_reset("Found a save with %s scrap, %d / %d weapons, %d / %d arenas cleared, %d mech%s, best wave %d.
Loading it REPLACES your current progress on this device." % [
		Game.fmt_int(info["scrap"]), info["weapons"], Game.WEAPONS.size(), info["cleared"], Game.ARENAS.size(),
		info["mechs"], "" if info["mechs"] == 1 else "s", info["best_wave"]])
	_backup_pending = info
	_backup_confirm.visible = true
	_backup_confirm.grab_focus()
	_layout()


func _backup_apply() -> void:
	if _backup_pending.is_empty():
		return
	_backup_confirm.visible = false
	_backup_info.text = "Loading your save - the game restarts..."
	Game.import_save(_backup_pending["text"])
	_backup_pending = {}

func _unhandled_input(event: InputEvent) -> void:
	if _page != 0 and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_show(0)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	if size != _last_size:
		_last_size = size
		_layout()
	# Logo glint: a 1.1 s sweep every 5 s, and a gentle bob.
	var cycle := fmod(_t + 3.5, 5.0)
	(_logo.material as ShaderMaterial).set_shader_parameter("sweep", -0.4 + cycle / 1.1 * 2.0 if cycle < 1.1 else -1.0)
	_logo.position = _logo_rect.position + Vector2(0, sin(_t * 0.8) * 2.0)
	_logo.size = _logo_rect.size
	_logo.pivot_offset = _logo.size / 2.0
	# The mech glides to where this page wants it (it starts there).
	if _mech.x < 0.0:
		if _mech_to.y > 0.0:
			_mech = _mech_to
	else:
		_mech = _mech.lerp(_mech_to, 1.0 - exp(-6.0 * delta))
	if _mech.x >= 0.0:
		_scene.mech_center_x = _mech.x
		_scene.mech_height = _mech.y
		_scene.feet_y = _mech.z
	_lobby.queue_redraw()


## The "SELECT OPERATION" caption over the cards (fades in with them).
func _draw_lobby() -> void:
	var a := _campaign.modulate.a if _campaign else 0.0
	if a <= 0.01:
		return
	var f := LobbyKit.tracked(LobbyKit.COND_B, 3)
	var p := _ops_caption
	LobbyKit.text(_lobby, f, p, "SELECT OPERATION", 14, Color(LobbyKit.CYAN.lightened(0.2), 0.95 * a), HORIZONTAL_ALIGNMENT_LEFT,
		-1, 5)
	var w := LobbyKit.width_of(f, "SELECT OPERATION", 14)
	var end_x := _campaign.home.x + _campaign.size.x if not Layout.portrait else _endless.home.x + _endless.size.x
	_lobby.draw_line(p + Vector2(w + 12.0, -5.0), Vector2(end_x - 22.0, p.y - 5.0), Color(LobbyKit.CYAN, 0.35 * a), 1.0)
	for i in 3:
		_lobby.draw_rect(Rect2(end_x - 16.0 + i * 6.0, p.y - 7.5, 4, 4), Color(LobbyKit.CYAN, (0.8 - i * 0.2) * a))


## Darkening behind the UI: the left and right edges (landscape: behind the columns / console), a band along
## the top for the chips and along the bottom; portrait: the top and everything below the mech.
func _draw_shade() -> void:
	var vp := _shade.size
	var dark := Color(0.005, 0.012, 0.04, 0.0)
	if Layout.portrait:
		_band(Rect2(0, 0, vp.x, 150), Color(dark, 0.55), Color(dark, 0.0), true)
		_band(Rect2(0, _shade_edge - 110.0, vp.x, 140.0), Color(dark, 0.0), Color(dark, 0.7), true)
		_shade.draw_rect(Rect2(0, _shade_edge + 30.0, vp.x, vp.y - _shade_edge - 30.0), Color(dark, 0.7))
		return
	_band(Rect2(0, 0, M + LEFT_W + 110.0, vp.y), Color(dark, 0.55), Color(dark, 0.0), false)
	_band(Rect2(_shade_edge - 170.0, 0, 210.0, vp.y), Color(dark, 0.0), Color(dark, 0.6), false)
	_shade.draw_rect(Rect2(_shade_edge + 40.0, 0, vp.x - _shade_edge - 40.0, vp.y), Color(dark, 0.6))
	_band(Rect2(0, 0, vp.x, 110), Color(dark, 0.4), Color(dark, 0.0), true)
	_band(Rect2(0, vp.y - 180.0, vp.x, 180.0), Color(dark, 0.0), Color(dark, 0.45), true)


## A gradient-filled rect: `a` at the top (vertical) / left edge, `b` at the bottom / right.
func _band(r: Rect2, a: Color, b: Color, vertical: bool) -> void:
	var cols := PackedColorArray([a, b, b, a]) if not vertical else PackedColorArray([a, a, b, b])
	_shade.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), cols)


# --- difficulty ---------------------------------------------------------------------------------------------

## New Game / Endless Mode: choose a difficulty first, then `then` starts the run.
func _pick_difficulty(then: Callable) -> void:
	_diff_then = then
	_show(DIFFICULTY_PAGE if Game.tutorial_done else TUTORIAL_PAGE)


func _on_difficulty_chosen(i: int) -> void:
	Game.set_difficulty(i)
	_refresh()
	_show(LOADOUT_PAGE)


func _show_difficulty_info(i: int) -> void:
	var d: Dictionary = Game.DIFFICULTIES[i]
	var more := "" if i == 1 else "\n%s%d%% enemies   //   %s%d%% enemy damage" % [
		"+" if d["count"] >= 1.0 else "", roundi((d["count"] - 1.0) * 100.0),
		"+" if d["damage"] >= 1.0 else "", roundi((d["damage"] - 1.0) * 100.0)]
	_diff_info.text = d["desc"] + more
	_diff_info.add_theme_color_override("font_color", d["color"])
