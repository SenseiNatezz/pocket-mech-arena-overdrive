extends CanvasLayer
## In-game HUD + menus. Everything here is built in code:
##   top-left   HP, heat (with Cone/Nova cost ticks), overdrive, repair kits, boost cooldown dial
##   top-center objective, wave/zone banners, boss health bar
##   top-right  arena name, time, kills
##   panels     pause (resume / restart / screen shake / main menu), game over, victory
## Talks to the arena through its signals (objective_changed, banner, boss_started, ...).

var mech: Mech
var arena: Node
var boss: Node
var _bars: Control
var _objective: Label
var _banner: Label
var _banner_tw: Tween
var _pause_panel: Control
var _over_panel: Control
var _win_panel: Control
var _win_stats: Label
var _next_btn: Button
var _shake_btn: Button
var _t := 0.0
var _hp_shown := 1.0
var _ended := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_bars = Control.new()
	_bars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars.draw.connect(_draw_bars)
	root.add_child(_bars)

	_objective = _label(18, Color(0.85, 0.95, 1.0))
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.position = Vector2(-300, 14)
	_objective.size = Vector2(600, 30)
	root.add_child(_objective)

	_banner = _label(46, Color.WHITE)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(-500, -150)
	_banner.size = Vector2(1000, 70)
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	_pause_panel = _panel("PAUSED", [["RESUME", _resume], ["RESTART ARENA", _restart], ["SCREEN SHAKE: ON", _toggle_shake],
		["MAIN MENU", _to_menu]], true)
	_shake_btn = _pause_panel.find_child("Btn2", true, false) as Button
	_over_panel = _panel("MECH DESTROYED", [["RETRY", _restart], ["MAIN MENU", _to_menu]])
	_win_panel = _panel("ARENA CLEARED", [["NEXT ARENA", _next], ["PLAY AGAIN", _restart], ["MAIN MENU", _to_menu]])
	_next_btn = _win_panel.find_child("Btn0", true, false) as Button
	_win_stats = _label(18, Color(0.8, 0.9, 1.0))
	_win_panel.get_node("Box/VBox").add_child(_win_stats)
	_win_panel.get_node("Box/VBox").move_child(_win_stats, 1)
	for p in [_pause_panel, _over_panel, _win_panel]:
		root.add_child(p)
		p.hide()
	_hook_scene.call_deferred()


func _hook_scene() -> void:
	mech = get_tree().get_first_node_in_group("player") as Mech
	if mech:
		mech.died.connect(func() -> void: get_tree().create_timer(1.6).timeout.connect(_show_game_over))
	arena = get_tree().get_first_node_in_group("arena")
	if arena:
		arena.objective_changed.connect(func(t: String) -> void: _objective.text = t)
		arena.banner.connect(show_banner)
		arena.boss_started.connect(func(b: Node) -> void: boss = b)
		arena.arena_cleared.connect(_show_victory)
		show_banner(arena.arena_name.to_upper(), Color(0.5, 0.9, 1.0))


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(title: String, buttons: Array, with_help := false) -> Control:
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.05, 0.72)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	var box := PanelContainer.new()
	box.name = "Box"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.08, 0.13, 0.95)
	sb.border_color = Color(0.35, 0.8, 1.0, 0.8)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", sb)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	shade.add_child(box)
	var v := VBoxContainer.new()
	v.name = "VBox"
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(380, 0)
	box.add_child(v)
	v.add_child(_label(34, Color(0.6, 0.9, 1.0)))
	(v.get_child(0) as Label).text = title
	for i in buttons.size():
		var b := MenuButtonFactory.make(buttons[i][0])
		b.name = "Btn%d" % i
		b.pressed.connect(buttons[i][1])
		v.add_child(b)
	if with_help:
		var help := _label(13, Color(1, 1, 1, 0.6))
		help.text = "KB/Mouse: WASD move, mouse aim, LMB fire, RMB scatter, Space boost,\nE nova, Q cone, F repair, Shift overdrive, R use\n" \
			+ "Gamepad: sticks move/aim, RT fire, LT scatter, LB boost,\nY nova, RB cone, B repair, R3 overdrive, A use"
		v.add_child(help)
	return shade


func show_banner(text: String, color := Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	if _banner_tw:
		_banner_tw.kill()
	_banner.scale = Vector2(1.3, 1.3)
	_banner.pivot_offset = _banner.size / 2
	_banner_tw = create_tween()
	_banner_tw.set_parallel()
	_banner_tw.tween_property(_banner, "modulate:a", 1.0, 0.15)
	_banner_tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_property(_banner, "modulate:a", 0.0, 0.5).set_delay(1.6)


# --- menus ---------------------------------------------------------------------------------------------

## Polled (not event-based) so the on-screen PAUSE button, which uses Input.action_press, works too.
func _check_pause() -> void:
	if Input.is_action_just_pressed("pause") and not _ended:
		if get_tree().paused:
			_resume()
		else:
			_pause()


func _pause() -> void:
	get_tree().paused = true
	_shake_btn.text = "SCREEN SHAKE: %s" % ("ON" if Game.screen_shake else "OFF")
	_pause_panel.show()
	(_pause_panel.find_child("Btn0", true, false) as Button).grab_focus()


func _resume() -> void:
	_pause_panel.hide()
	get_tree().paused = false


func _toggle_shake() -> void:
	Game.set_screen_shake(not Game.screen_shake)
	_shake_btn.text = "SCREEN SHAKE: %s" % ("ON" if Game.screen_shake else "OFF")


func _restart() -> void:
	if arena:
		Game.restart_arena()
	else:
		Game.to_test_range()


func _to_menu() -> void:
	Game.to_menu()


func _next() -> void:
	Game.next_arena()


func _show_game_over() -> void:
	if _ended:
		return
	_ended = true
	_pause_panel.hide()
	_over_panel.show()
	(_over_panel.find_child("Btn0", true, false) as Button).grab_focus()
	get_tree().paused = true


func _show_victory() -> void:
	if _ended:
		return
	_ended = true
	_win_stats.text = "Time %s    Kills %d" % [_fmt_time(Game.run_time), Game.kills]
	_next_btn.visible = Game.has_next_arena()
	_win_panel.show()
	(_win_panel.find_child("Btn0" if _next_btn.visible else "Btn1", true, false) as Button).grab_focus()
	Sfx.play(&"levelup", -2.0, 0.0)
	get_tree().paused = true


func _fmt_time(t: float) -> String:
	return "%d:%02d" % [int(t) / 60, int(t) % 60]


# --- bars ----------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_check_pause()
	_t += delta
	if mech:
		_hp_shown = lerpf(_hp_shown, mech.hp / mech.max_hp, 1.0 - exp(-6.0 * delta))
	_bars.queue_redraw()


func _draw_bars() -> void:
	var c := _bars
	var font := ThemeDB.fallback_font
	var vp := c.size
	if mech:
		var hp_frac := mech.hp / mech.max_hp
		# Low-HP warning vignette.
		if hp_frac < 0.3 and not mech.dead:
			var a := (0.3 - hp_frac) / 0.3 * (0.35 + 0.2 * sin(_t * 6.0))
			for i in 6:
				c.draw_rect(Rect2(Vector2.ZERO, vp).grow(-i * 8), Color(1, 0.05, 0.05, a * (1.0 - i / 6.0) * 0.5), false, 8.0)
		var x := 20.0
		var y := 18.0
		c.draw_rect(Rect2(x - 8, y - 8, 360, 128), Color(0.02, 0.04, 0.08, 0.55))
		# HP.
		_text(font, Vector2(x, y + 15), "HP", 14, Color(0.7, 1.0, 0.8))
		var bar := Rect2(x + 44, y, 250, 20)
		c.draw_rect(bar, Color(0, 0, 0, 0.6))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * _hp_shown, bar.size.y)), Color(1.0, 0.35, 0.3))
		var hp_col := Color(0.35, 1.0, 0.5) if hp_frac > 0.3 else Color(1.0, 0.4, 0.3)
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * hp_frac, bar.size.y)), hp_col)
		for i in range(1, 10):
			c.draw_line(bar.position + Vector2(bar.size.x * i / 10.0, 0), bar.position + Vector2(bar.size.x * i / 10.0, bar.size.y), Color(0, 0, 0, 0.35), 1.0)
		c.draw_rect(bar, Color(1, 1, 1, 0.5), false, 1.5)
		_text(font, Vector2(bar.end.x + 8, y + 15), str(ceili(mech.hp)), 14, Color.WHITE)
		# Heat.
		y += 32
		_text(font, Vector2(x, y + 13), "HEAT", 12, Color(1.0, 0.7, 0.4))
		bar = Rect2(x + 44, y, 250, 14)
		c.draw_rect(bar, Color(0, 0, 0, 0.6))
		var heat_frac := mech.heat / mech.heat_max
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * heat_frac, bar.size.y)), Color(1.0, 0.45, 0.1).lerp(Color(1, 0.85, 0.3), heat_frac))
		# Cost ticks: CONE label sits left of its tick, NOVA right of its tick (they're close together).
		for m in [[mech.cone_cost, "CONE", -32.0], [mech.nova_cost, "NOVA", 4.0]]:
			var mx: float = bar.position.x + bar.size.x * m[0] / mech.heat_max
			var ok: bool = mech.heat >= m[0]
			c.draw_line(Vector2(mx, bar.position.y - 3), Vector2(mx, bar.end.y + 3), Color(1, 1, 1, 0.9 if ok else 0.4), 2.0)
			_text(font, Vector2(mx + m[2], bar.end.y + 13), m[1], 10, Color(1.0, 0.8, 0.4) if ok else Color(1, 1, 1, 0.35))
		c.draw_rect(bar, Color(1, 1, 1, 0.4), false, 1.0)
		# Overdrive.
		y += 34
		var od_active := mech.overdrive_left > 0.0
		var od_ready := mech.overdrive_meter >= 100.0
		_text(font, Vector2(x, y + 13), "O.D.", 12, Color(1.0, 0.85, 0.3))
		bar = Rect2(x + 44, y, 250, 14)
		c.draw_rect(bar, Color(0, 0, 0, 0.6))
		var od_frac := mech.overdrive_left / mech.overdrive_time if od_active else mech.overdrive_meter / 100.0
		var od_col := Color(1.0, 0.85, 0.25)
		if od_ready and not od_active:
			od_col = od_col.lerp(Color.WHITE, 0.5 + 0.5 * sin(_t * 10.0))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * od_frac, bar.size.y)), od_col)
		c.draw_rect(bar, Color(1, 1, 1, 0.4), false, 1.0)
		if od_ready and not od_active:
			_text(font, Vector2(bar.end.x + 8, y + 12), "READY", 11, od_col)
		elif od_active:
			_text(font, Vector2(bar.end.x + 8, y + 12), "%.1fs" % mech.overdrive_left, 11, od_col)
		# Repair kits + boost dial.
		y += 28
		_text(font, Vector2(x, y + 13), "KITS", 12, Color(0.6, 1.0, 0.7))
		for i in mech.repair_charges_max:
			var r := Rect2(x + 44 + i * 24, y, 18, 18)
			c.draw_rect(r, Color(0.35, 1.0, 0.5) if i < mech.repair_charges else Color(1, 1, 1, 0.1))
			c.draw_rect(r, Color(1, 1, 1, 0.5), false, 1.5)
			if i < mech.repair_charges:
				c.draw_rect(Rect2(r.position + Vector2(7, 3), Vector2(4, 12)), Color(0.05, 0.3, 0.1))
				c.draw_rect(Rect2(r.position + Vector2(3, 7), Vector2(12, 4)), Color(0.05, 0.3, 0.1))
		var boost := mech.boost_ready_fraction()
		var bc := Vector2(x + 250, y + 9)
		_text(font, Vector2(x + 180, y + 13), "BOOST", 12, Color(0.6, 0.9, 1.0))
		c.draw_circle(bc, 11, Color(0, 0, 0, 0.5))
		c.draw_arc(bc, 11, -PI / 2, -PI / 2 + TAU * boost, 28, Color(0.4, 0.9, 1.0) if boost >= 1.0 else Color(1.0, 0.6, 0.2), 4.0, true)
	# Boss bar.
	if is_instance_valid(boss) and not boss.dead:
		var w := minf(vp.x * 0.5, 640.0)
		var bar := Rect2(vp.x / 2 - w / 2, 160.0 if Controls.device == Controls.Device.TOUCH else 70.0, w, 16)
		var col: Color = boss.get("accent")
		_text(font, Vector2(bar.position.x, bar.position.y - 8), "%s  -  PHASE %d" % [boss.get("boss_name"), boss.get("phase")], 16, col.lightened(0.3))
		c.draw_rect(bar.grow(3), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(boss.hp / boss.max_hp, 0.0, 1.0), bar.size.y)), col)
		for k in [0.66, 0.33]:
			c.draw_line(bar.position + Vector2(bar.size.x * k, 0), bar.position + Vector2(bar.size.x * k, bar.size.y), Color(1, 1, 1, 0.7), 2.0)
		c.draw_rect(bar, Color(1, 1, 1, 0.6), false, 1.5)
	# Run info (top-right, below the touch buttons' row when they're visible).
	var info := "%s   %s   KILLS %d" % [arena.arena_name.to_upper() if arena else "TEST RANGE", _fmt_time(Game.run_time), Game.kills]
	var iy := 134.0 if Controls.device == Controls.Device.TOUCH else 28.0
	c.draw_string_outline(font, Vector2(vp.x - 420, iy), info, HORIZONTAL_ALIGNMENT_RIGHT, 400, 14, 5, Color(0, 0, 0, 0.8))
	c.draw_string(font, Vector2(vp.x - 420, iy), info, HORIZONTAL_ALIGNMENT_RIGHT, 400, 14, Color(0.8, 0.9, 1.0))


func _text(font: Font, pos: Vector2, s: String, size: int, col: Color) -> void:
	_bars.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.8))
	_bars.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
