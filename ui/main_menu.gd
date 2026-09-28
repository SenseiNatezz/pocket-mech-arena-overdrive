extends Control
## Title screen: an animated hero scene (ui/title_scene.gd: the player's mech hovering on a holo-pedestal
## in front of Earth, Higgsfield art) on the left, and the POCKET MECH ARENA logo (with a glint) + menu
## in a column on the right:
##   primary   NEW GAME | CONTINUE | ENDLESS MODE          (big)
##   secondary ARMORY | WEAPON RANGE | CUSTOMIZE | SETTINGS | EXIT   (2-column grid)
##   footer    best endless wave // weapons unlocked // difficulty
## The scene is sized from the screen HEIGHT (the mech is never cut off, head to feet) and the mech
## always stands clear of the menu column.
## Pages: 0 main, 1 continue (arena select), 2 settings, 3 armory (ui/armory_page.gd: weapon cards, unlock
## progress, equip), 4 difficulty picker (New Game / Endless Mode go through it first), 5 first-run tutorial
## offer, 6 loadout (starting-weapon picker after the difficulty; ArmoryPage in start mode).
## Works with mouse, touch (taps) and keyboard/gamepad (focus + ui_accept, ui_cancel = back).

const SHINE := preload("res://ui/logo_shine.gdshader")
const LOGO := preload("res://assets/hq/title_logo.png")
## Right-hand menu column width and its margin from the screen edge.
const COL_W := 460.0
const COL_MARGIN := 56.0
## Portrait: the pages start this far above the bottom edge (the tallest, Continue, just fits).
const PORTRAIT_PAGES_H := 480.0
const ARMORY_PAGE := 3
const DIFFICULTY_PAGE := 4
## First run: offered before the difficulty picker until the tutorial is played or skipped.
const TUTORIAL_PAGE := 5
## Loadout: choose the starting weapon before every New Game / Endless run (after the difficulty).
const LOADOUT_PAGE := 6

var _scene: TitleScene
var _logo: TextureRect
var _shade: Control
var _col: Control
var _footer: Label
var _pages: Array[Control] = []
var _page := 0
var _continue_btn: TitleButton
var _endless_btn: TitleButton
var _shake_btn: TitleButton
var _vol_btn: TitleButton
var _music_btn: TitleButton
var _sfx_btn: TitleButton
var _armory: ArmoryPage
var _loadout: ArmoryPage
var _diff_btn: TitleButton
var _diff_btns: Array[TitleButton] = []
var _diff_info: Label
## What the difficulty picker starts once a difficulty is chosen (New Game or Endless Mode).
var _diff_then: Callable
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Animated hero scene: space backdrop, the player's mech on a holo-pedestal (ui/title_scene.gd).
	_scene = TitleScene.new()
	add_child(_scene)
	# Darkening behind the menu column (a smooth gradient toward the right edge) so it reads clearly.
	_shade = Control.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.draw.connect(_draw_shade)
	add_child(_shade)

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

	var col := Control.new()
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	add_child(col)
	_col = col

	# Main page: three big mode buttons, then a 2-column grid of the rest.
	var main := _page_box(col, 10)
	var big := Vector2(COL_W, 52)
	_btn(main, "New Game", _pick_difficulty.bind(Game.new_game), big)
	_continue_btn = _btn(main, "Continue", _show.bind(1), big)
	_endless_btn = _btn(main, "Endless Mode", _pick_difficulty.bind(func() -> void: Game.start_endless()), big)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	main.add_child(grid)
	var small := Vector2((COL_W - 12.0) / 2.0, 42)
	for entry in [["Armory", _show.bind(ARMORY_PAGE)], ["Weapon Range", Game.to_gun_range],
			["Customize", Game.to_customize], ["Settings", _show.bind(2)]]:
		var b := TitleButton.new(entry[0], small)
		b.pressed.connect(entry[1])
		grid.add_child(b)
	if OS.get_name() != "Web":
		var quit := TitleButton.new("Exit", small)
		quit.pressed.connect(get_tree().quit)
		grid.add_child(quit)

	_footer = Label.new()
	_footer.anchor_top = 1.0
	_footer.anchor_bottom = 1.0
	_footer.offset_top = -40.0
	_footer.offset_bottom = -14.0
	_footer.add_theme_font_size_override("font_size", 14)
	_footer.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.85))
	_footer.add_theme_color_override("font_outline_color", Color(0, 0.02, 0.08, 0.9))
	_footer.add_theme_constant_override("outline_size", 5)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_footer)

	# Continue: arena select (first uncleared arena is focused).
	var cont := _page_box(col)
	for i in Game.ARENAS.size():
		var tag := "  [CLEARED]" if Game.cleared.has(i) else ""
		_btn(cont, "Arena %d: %s%s" % [i + 1, Game.ARENAS[i]["name"], tag], Game.start_arena.bind(i), Vector2(COL_W, 50))
	_btn(cont, "Back", _show.bind(0), Vector2(COL_W, 50))

	# Settings.
	var settings := _page_box(col, 6)
	_diff_btn = _btn(settings, "", func() -> void:
		Game.set_difficulty((Game.difficulty + 1) % Game.DIFFICULTIES.size())
		_refresh(), Vector2(COL_W, 42))
	_shake_btn = _btn(settings, "", func() -> void:
		Game.set_screen_shake(not Game.screen_shake)
		_refresh(), Vector2(COL_W, 42))
	_vol_btn = _btn(settings, "", func() -> void:
		Game.set_volume(Game.master_volume + 0.2 if Game.master_volume < 0.99 else 0.0)
		_refresh(), Vector2(COL_W, 42))
	_music_btn = _btn(settings, "", func() -> void:
		Game.set_music_volume(Game.music_volume + 0.1 if Game.music_volume < 0.99 else 0.0)
		_refresh(), Vector2(COL_W, 42))
	_sfx_btn = _btn(settings, "", func() -> void:
		Game.set_sfx_volume(Game.sfx_volume + 0.1 if Game.sfx_volume < 0.99 else 0.0)
		Sfx.play(&"pickup", -6.0)
		_refresh(), Vector2(COL_W, 42))
	_btn(settings, "Tutorial", Game.to_tutorial, Vector2(COL_W, 42))
	var help := _heading(settings, "Keyboard/Mouse, gamepad and touch supported.\nPause in-game (Esc / Start / II) to see controls.")
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.75))
	_btn(settings, "Back", _show.bind(0), Vector2(COL_W, 42))

	# Armory: full-screen weapon cards (ui/armory_page.gd).
	_armory = ArmoryPage.new()
	_armory.back_pressed.connect(_show.bind(0))
	add_child(_armory)
	_pages.append(_armory)

	# Difficulty picker.
	var pick := _page_box(col, 8)
	_heading(pick, "SELECT DIFFICULTY")
	for i in Game.DIFFICULTIES.size():
		var d: Dictionary = Game.DIFFICULTIES[i]
		var b := _btn(pick, d["name"], _on_difficulty_chosen.bind(i), Vector2(COL_W, 44))
		b.focus_entered.connect(_show_difficulty_info.bind(i))
		_diff_btns.append(b)
	_diff_info = _heading(pick, "")
	_diff_info.add_theme_font_size_override("font_size", 15)
	_diff_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_info.custom_minimum_size = Vector2(COL_W, 56)
	_btn(pick, "Back", _show.bind(0), Vector2(COL_W, 44))

	# First-run tutorial offer (New Game / Endless before the tutorial has been played or skipped).
	var tut := _page_box(col, 10)
	_heading(tut, "NEW PILOT?")
	var tut_info := _heading(tut, "Learn to move, fight, dash and level up in a quick 2-minute training mission.")
	tut_info.add_theme_font_size_override("font_size", 15)
	tut_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_info.custom_minimum_size = Vector2(COL_W, 44)
	_btn(tut, "Play Tutorial", Game.to_tutorial, Vector2(COL_W, 50))
	_btn(tut, "Skip - I know how to play", func() -> void:
		Game.finish_tutorial()
		_show(DIFFICULTY_PAGE), Vector2(COL_W, 50))
	_btn(tut, "Back", _show.bind(0), Vector2(COL_W, 50))

	# Loadout (weapon cards in start mode).
	_loadout = ArmoryPage.new()
	_loadout.start_mode = true
	_loadout.back_pressed.connect(_show.bind(DIFFICULTY_PAGE))
	_loadout.start_pressed.connect(func() -> void:
		if _diff_then.is_valid():
			_diff_then.call())
	add_child(_loadout)
	_pages.append(_loadout)

	Layout.changed.connect(_apply_layout)
	_apply_layout(Layout.portrait)
	_refresh()
	_show(0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu-page="):
			_show(int(a.trim_prefix("--menu-page=")))
	# Fade in from black.
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
	Sfx.warm_up()


func _page_box(parent: Control, separation := 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	v.anchor_bottom = 1.0
	v.anchor_right = 1.0
	parent.add_child(v)
	_pages.append(v)
	return v


## Landscape: the menu column hugs the right edge, pages start at 42% height, the mech stands left.
## Portrait: logo on top, the mech in the middle, the column centred at the bottom.
func _apply_layout(portrait: bool) -> void:
	_col.anchor_left = 0.5 if portrait else 1.0
	_col.anchor_right = _col.anchor_left
	_col.offset_left = -COL_W / 2.0 if portrait else -COL_W - COL_MARGIN
	_col.offset_right = _col.offset_left + COL_W
	for v in _col.get_children():
		(v as Control).anchor_top = 1.0 if portrait else 0.42
		(v as Control).offset_top = -PORTRAIT_PAGES_H if portrait else 0.0
	_footer.anchor_left = 0.0 if portrait else 1.0
	_footer.anchor_right = 1.0
	_footer.offset_left = 20.0 if portrait else -COL_W - COL_MARGIN - 200.0
	_footer.offset_right = -20.0 if portrait else -COL_MARGIN
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if portrait else HORIZONTAL_ALIGNMENT_RIGHT
	_scene.bg_focus = 0.3 if portrait else 0.0
	if not portrait:
		_scene.mech_height = 0.0
		_scene.feet_y = 0.0


func _btn(page: VBoxContainer, label: String, action: Callable, min_size := Vector2(COL_W, 56)) -> TitleButton:
	var b := TitleButton.new(label, min_size)
	b.pressed.connect(action)
	page.add_child(b)
	return b


func _heading(page: VBoxContainer, txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	l.add_theme_color_override("font_outline_color", Color(0, 0.02, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	page.add_child(l)
	return l


func _show(which: int) -> void:
	_page = which
	for i in _pages.size():
		_pages[i].visible = i == which
	_footer.visible = which == 0
	_logo.visible = which != ARMORY_PAGE and which != LOADOUT_PAGE
	var focus: Control = null
	if which == 1:
		focus = _pages[1].get_child(mini(Game.continue_index(), Game.ARENAS.size() - 1))
	elif which == ARMORY_PAGE:
		_armory.focus_equipped()
	elif which == LOADOUT_PAGE:
		_loadout.focus_equipped()
	elif which == DIFFICULTY_PAGE:
		focus = _diff_btns[Game.difficulty]
		_show_difficulty_info(Game.difficulty)
	else:
		for c in _pages[which].get_children():
			if c is Button:
				focus = c
				break
	if focus:
		focus.grab_focus()


func _refresh() -> void:
	var got := 0
	for w in Game.WEAPONS:
		if Game.is_unlocked(w["id"]):
			got += 1
	_footer.text = "BEST ENDLESS WAVE %d   //   WEAPONS %d / %d   //   %s" % [Game.endless_best, got,
		Game.WEAPONS.size(), Game.difficulty_name().to_upper()]
	_shake_btn.label_text = "Screen Shake: %s" % ("On" if Game.screen_shake else "Off")
	_vol_btn.label_text = "Master Volume: %d%%" % roundi(Game.master_volume * 100.0)
	_music_btn.label_text = "Music: %d%%" % roundi(Game.music_volume * 100.0)
	_sfx_btn.label_text = "Sound FX: %d%%" % roundi(Game.sfx_volume * 100.0)
	_diff_btn.label_text = "Difficulty: %s" % Game.difficulty_name()
	_continue_btn.label_text = "Continue" + ("  (Arena %d, %s)" % [Game.continue_index() + 1, Game.difficulty_name()] if Game.has_progress() else "")
	_endless_btn.label_text = "Endless Mode" + ("  (Best: wave %d)" % Game.endless_best if Game.endless_best > 0 else "")
	for b in [_diff_btn, _shake_btn, _vol_btn, _music_btn, _sfx_btn, _continue_btn, _endless_btn]:
		b.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _page != 0 and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_show(0)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport_rect().size
	var logo_aspect := float(LOGO.get_width()) / LOGO.get_height()
	# Logo glint: a 1.1 s sweep every 5 s.
	var cycle := fmod(_t + 3.5, 5.0)
	(_logo.material as ShaderMaterial).set_shader_parameter("sweep", -0.4 + cycle / 1.1 * 2.0 if cycle < 1.1 else -1.0)
	_shade.queue_redraw()
	if Layout.portrait:
		# Logo across the top; the mech stands between it and the buttons, centred.
		var pw := minf(minf(vp.x - 60.0, 640.0), vp.y * 0.19 * logo_aspect)
		var ph := pw / logo_aspect
		_logo.position = Vector2((vp.x - pw) / 2.0, vp.y * 0.025 + sin(_t * 0.8) * 2.0)
		_logo.size = Vector2(pw, ph)
		var feet := vp.y - PORTRAIT_PAGES_H - 56.0
		_scene.feet_y = feet
		_scene.mech_height = minf(feet - (_logo.position.y + ph * 0.8), (vp.x - 80.0) / 0.745)
		_scene.mech_center_x = vp.x / 2.0
		return
	# Logo: top of the menu column, as big as fits above the buttons (which start at 42% height).
	var col_x := vp.x - COL_MARGIN - COL_W
	var lh := minf(vp.y * 0.36, COL_W / logo_aspect)
	var lw := lh * logo_aspect
	_logo.position = Vector2(col_x + (COL_W - lw) / 2.0, vp.y * 0.035 + sin(_t * 0.8) * 2.0)
	_logo.size = Vector2(lw, lh)
	# The mech stands on the left, clear of the menu column, leaving the station and sunrise in view.
	var half_w := vp.y * 0.64 * 0.745 / 2.0
	_scene.mech_center_x = minf(half_w + vp.y * 0.09, col_x - half_w - 20.0)


## Menu backdrop: a horizontal gradient from clear (middle of the screen) to deep navy (right edge),
## plus a solid fill past the art's right edge on very wide screens.
func _draw_shade() -> void:
	var vp := _shade.size
	var clear := Color(0.01, 0.02, 0.06, 0.0)
	var dark := Color(0.01, 0.02, 0.06, 0.62)
	if Layout.portrait:  # vertical: clear at the pedestal, dark under the buttons
		var y0 := vp.y - PORTRAIT_PAGES_H - 40.0
		var y1 := vp.y - PORTRAIT_PAGES_H + 60.0
		_shade.draw_polygon(PackedVector2Array([Vector2(0, y0), Vector2(vp.x, y0), Vector2(vp.x, y1), Vector2(0, y1)]),
			PackedColorArray([clear, clear, dark, dark]))
		_shade.draw_rect(Rect2(0, y1, vp.x, vp.y - y1), dark)
		return
	var x0 := maxf(vp.x - COL_W - COL_MARGIN * 2.0 - 260.0, vp.x * 0.35)
	_shade.draw_polygon(PackedVector2Array([Vector2(x0, 0), Vector2(vp.x, 0), Vector2(vp.x, vp.y), Vector2(x0, vp.y)]),
		PackedColorArray([clear, dark, dark, clear]))




# --- difficulty -------------------------------------------------------------------------------------

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
