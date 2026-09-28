extends Control
## Title screen: the POCKET MECH ARENA key art (Higgsfield render of the user's title design) with a
## slow cinematic drift, twinkling stars, and real menu buttons in the art's style:
##   NEW GAME | CONTINUE | ENDLESS MODE | ARMORY | WEAPON RANGE | GUNDAM CUSTOMIZATION | SETTINGS | EXIT
## Pages: 0 main, 1 continue (arena select), 2 settings, 3 armory (ui/armory_page.gd: weapon cards, unlock
## progress, equip), 4 difficulty picker (New Game / Endless Mode go through it first), 5 first-run tutorial
## offer, 6 loadout (starting-weapon picker after the difficulty; ArmoryPage in start mode).
## Works with mouse, touch (taps) and keyboard/gamepad (focus + ui_accept, ui_cancel = back).

const BG := preload("res://assets/hq/title_bg.jpg")
const ARMORY_PAGE := 3
const DIFFICULTY_PAGE := 4
## First run: offered before the difficulty picker until the tutorial is played or skipped.
const TUTORIAL_PAGE := 5
## Loadout: choose the starting weapon before every New Game / Endless run (after the difficulty).
const LOADOUT_PAGE := 6

var _art: TextureRect
var _stars: Node2D
var _star_pts: Array[Vector3] = []
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

	var black := ColorRect.new()
	black.color = Color(0.01, 0.01, 0.03)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	_art = TextureRect.new()
	_art.texture = BG
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Sized by hand in _process (cover the screen, but never crop the logo side - see there).
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	# Soft darkening behind the menu column so the buttons read clearly.
	var shade := Control.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.draw.connect(func() -> void:
		var h := shade.size.y
		for i in 24:
			var x := i * 22.0
			shade.draw_rect(Rect2(x, h * 0.38, 22, h * 0.62), Color(0, 0.01, 0.04, 0.34 * (1.0 - i / 24.0))))
	add_child(shade)
	_stars = Node2D.new()
	_stars.draw.connect(_draw_stars)
	add_child(_stars)
	for i in 70:
		_star_pts.append(Vector3(randf(), randf(), randf() * TAU))

	var col := Control.new()
	col.anchor_top = 0.0
	col.anchor_bottom = 1.0
	col.offset_left = 58
	col.offset_right = 470
	add_child(col)

	# Main page (slimmer buttons so all eight fit under the logo).
	var main := _page_box(col, 6)
	var big := Vector2(400, 41)
	_btn(main, "New Game", _pick_difficulty.bind(Game.new_game), big)
	_continue_btn = _btn(main, "Continue", _show.bind(1), big)
	_endless_btn = _btn(main, "Endless Mode", _pick_difficulty.bind(func() -> void: Game.start_endless()), big)
	_btn(main, "Armory", _show.bind(ARMORY_PAGE), big)
	_btn(main, "Weapon Range", Game.to_gun_range, big)
	_btn(main, "Mech Customization", Game.to_customize, big)
	_btn(main, "Settings", _show.bind(2), big)
	if OS.get_name() != "Web":
		_btn(main, "Exit", get_tree().quit, big)

	# Continue: arena select (first uncleared arena is focused).
	var cont := _page_box(col)
	for i in Game.ARENAS.size():
		var tag := "  [CLEARED]" if Game.cleared.has(i) else ""
		_btn(cont, "Arena %d: %s%s" % [i + 1, Game.ARENAS[i]["name"], tag], Game.start_arena.bind(i), Vector2(400, 50))
	_btn(cont, "Test Range", Game.to_test_range, Vector2(400, 50))
	_btn(cont, "Back", _show.bind(0), Vector2(400, 50))

	# Settings.
	var settings := _page_box(col, 6)
	_diff_btn = _btn(settings, "", func() -> void:
		Game.set_difficulty((Game.difficulty + 1) % Game.DIFFICULTIES.size())
		_refresh(), Vector2(400, 42))
	_shake_btn = _btn(settings, "", func() -> void:
		Game.set_screen_shake(not Game.screen_shake)
		_refresh(), Vector2(400, 42))
	_vol_btn = _btn(settings, "", func() -> void:
		Game.set_volume(Game.master_volume + 0.2 if Game.master_volume < 0.99 else 0.0)
		_refresh(), Vector2(400, 42))
	_music_btn = _btn(settings, "", func() -> void:
		Game.set_music_volume(Game.music_volume + 0.1 if Game.music_volume < 0.99 else 0.0)
		_refresh(), Vector2(400, 42))
	_sfx_btn = _btn(settings, "", func() -> void:
		Game.set_sfx_volume(Game.sfx_volume + 0.1 if Game.sfx_volume < 0.99 else 0.0)
		Sfx.play(&"pickup", -6.0)
		_refresh(), Vector2(400, 42))
	_btn(settings, "Tutorial", Game.to_tutorial, Vector2(400, 42))
	var help := _heading(settings, "Keyboard/Mouse, gamepad and touch supported.\nPause in-game (Esc / Start / II) to see controls.")
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.75))
	_btn(settings, "Back", _show.bind(0), Vector2(400, 42))

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
		var b := _btn(pick, d["name"], _on_difficulty_chosen.bind(i), Vector2(400, 44))
		b.focus_entered.connect(_show_difficulty_info.bind(i))
		_diff_btns.append(b)
	_diff_info = _heading(pick, "")
	_diff_info.add_theme_font_size_override("font_size", 15)
	_diff_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diff_info.custom_minimum_size = Vector2(400, 56)
	_btn(pick, "Back", _show.bind(0), Vector2(400, 44))

	# First-run tutorial offer (New Game / Endless before the tutorial has been played or skipped).
	var tut := _page_box(col, 10)
	_heading(tut, "NEW PILOT?")
	var tut_info := _heading(tut, "Learn to move, fight, dash and level up in a quick 2-minute training mission.")
	tut_info.add_theme_font_size_override("font_size", 15)
	tut_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_info.custom_minimum_size = Vector2(400, 44)
	_btn(tut, "Play Tutorial", Game.to_tutorial, Vector2(400, 50))
	_btn(tut, "Skip - I know how to play", func() -> void:
		Game.finish_tutorial()
		_show(DIFFICULTY_PAGE), Vector2(400, 50))
	_btn(tut, "Back", _show.bind(0), Vector2(400, 50))

	# Loadout (weapon cards in start mode).
	_loadout = ArmoryPage.new()
	_loadout.start_mode = true
	_loadout.back_pressed.connect(_show.bind(DIFFICULTY_PAGE))
	_loadout.start_pressed.connect(func() -> void:
		if _diff_then.is_valid():
			_diff_then.call())
	add_child(_loadout)
	_pages.append(_loadout)

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
	v.anchor_top = 0.42
	v.anchor_bottom = 1.0
	v.anchor_right = 1.0
	parent.add_child(v)
	_pages.append(v)
	return v


func _btn(page: VBoxContainer, label: String, action: Callable, min_size := Vector2(400, 56)) -> TitleButton:
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
	# Slow cinematic push-in / drift on the key art.
	var z := 1.03 + 0.025 * sin(_t * 0.12)
	# Cover the screen. The logo is painted on the art's left side, so on screens narrower than the art
	# (4:3 tablets, small browser windows) crop from the right instead of both sides; wider screens
	# (phones) crop top and bottom evenly.
	var vp := get_viewport_rect().size
	var aspect := float(BG.get_width()) / BG.get_height()
	_art.size = Vector2(maxf(vp.x, vp.y * aspect), maxf(vp.y, vp.x / aspect))
	var base := Vector2(0.0, (vp.y - _art.size.y) / 2.0)
	_art.pivot_offset = _art.size * Vector2(0.3, 0.55)
	_art.scale = Vector2(z, z)
	_art.position = base + Vector2(sin(_t * 0.07) * 6.0, cos(_t * 0.05) * 4.0)
	_stars.queue_redraw()


func _draw_stars() -> void:
	var vp := get_viewport_rect().size
	for s in _star_pts:
		var a := 0.5 + 0.5 * sin(_t * (1.2 + s.z) + s.z * 7.0)
		if a < 0.55:
			continue
		var p := Vector2(s.x * vp.x, s.y * vp.y * 0.75)
		var r := 1.0 + (a - 0.55) * 4.0
		_stars.draw_circle(p, r * 2.5, Color(0.6, 0.8, 1.0, (a - 0.55) * 0.35))
		_stars.draw_line(p - Vector2(r * 4, 0), p + Vector2(r * 4, 0), Color(0.8, 0.9, 1.0, (a - 0.55) * 0.9), 1.0, true)
		_stars.draw_line(p - Vector2(0, r * 4), p + Vector2(0, r * 4), Color(0.8, 0.9, 1.0, (a - 0.55) * 0.9), 1.0, true)


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
