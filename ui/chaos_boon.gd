class_name ChaosBoon
extends CanvasLayer
## CHAOS BLESSING pick (Hades' Chaos boons): opened by environment/chaos_rift.gd when a CHAOS RIFT sector's
## curse lifts. Three blessings from Game.roll_chaos_blessings(), each rolled COMMON / RARE / EPIC (Hades'
## white / blue / purple) - the rarity sets how strong it is. The one picked is kept for the rest of the run
## (Game.take_chaos_blessing); one already owned comes back a rarity higher. The game is paused meanwhile.
## Mouse / touch (tap a card), keyboard (1 / 2 / 3, arrows + accept) and gamepad all work; cards ignore presses
## for ARM_TIME after appearing. Side by side on landscape screens, stacked on portrait ones.
## Automated runs (Controls.ignore_real_input) take the first card by themselves after AUTO_PICK seconds.

signal chosen(id: StringName, rarity: int)

const ARM_TIME := 0.6
const AUTO_PICK := 1.2
const PANEL := Color(0.05, 0.02, 0.1, 0.97)
const TEXT := Color(0.88, 0.86, 1.0)

var _offers: Array[Dictionary] = []
var _cards: Array[Button] = []
var _root: Control
var _box: BoxContainer
var _title: Label
var _sub: Label
var _hint: Label
var _t := 0.0
var _open := false
var _done := false


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.0, 0.08, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_title = Label.new()
	_title.text = "CHAOS BLESSING"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.display_label(_title, 40, Color.WHITE, Game.CHAOS_COLOR.darkened(0.25))
	_root.add_child(_title)
	_sub = _label("The curse is lifted. Choose a blessing - it lasts for the rest of the run.", 18,
		Game.CHAOS_COLOR.lightened(0.45))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_sub)
	_hint = _label("Tap a blessing  //  1 / 2 / 3  //  arrows + confirm", 15, Color(0.85, 0.8, 1.0, 0.75))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)
	get_viewport().size_changed.connect(_layout, CONNECT_DEFERRED)
	visible = false


## Rolls the three blessings and shows them as soon as no level-up pick is open.
func open() -> void:
	_offers = Game.roll_chaos_blessings(3)
	if _offers.is_empty():
		_done = true
		queue_free()
		return
	_open = true


func _show() -> void:
	visible = true
	get_tree().paused = true
	add_to_group("modal_overlay")  # (the HUD's pause key and level-up menu wait for it)
	_t = 0.0
	for i in _offers.size():
		_cards.append(_card(i, _offers[i]))
	_layout()
	Sfx.play(&"levelup", -5.0, 0.0)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box_style(edge: Color, width: int, fill := PANEL) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(10)
	s.shadow_color = Color(edge, 0.35)
	s.shadow_size = 10 if width > 2 else 4
	return s


## One blessing: its rarity ribbon, name, what it does at this rarity and how long it lasts.
func _card(i: int, offer: Dictionary) -> Button:
	var id: StringName = offer["id"]
	var rarity: int = offer["rarity"]
	var info: Dictionary = Game.CHAOS_BLESSINGS[id]
	var rc: Color = Game.CHAOS_RARITY[rarity]["color"]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var fill := PANEL.lerp(rc.darkened(0.8), 0.25)
	b.add_theme_stylebox_override("normal", _box_style(Color(rc, 0.7), 2, fill))
	b.add_theme_stylebox_override("hover", _box_style(rc, 3, fill))
	b.add_theme_stylebox_override("focus", _box_style(rc.lightened(0.4), 4, fill))
	b.add_theme_stylebox_override("pressed", _box_style(Color.WHITE, 4, fill))
	b.add_theme_stylebox_override("disabled", _box_style(Color(rc, 0.5), 2, fill))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 14
	v.offset_bottom = -14
	b.add_child(v)
	# Rarity ribbon: "RARE", with "UPGRADE" when the pilot already has this blessing.
	var have := Game.chaos_blessings.has(id)
	var ribbon := PanelContainer.new()
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(rc, 0.9)
	rs.set_corner_radius_all(4)
	rs.content_margin_left = 10
	rs.content_margin_right = 10
	rs.content_margin_top = 2
	rs.content_margin_bottom = 2
	ribbon.add_theme_stylebox_override("panel", rs)
	var rl := _label(String(Game.CHAOS_RARITY[rarity]["name"]) + ("  -  UPGRADE" if have else ""), 15, Color(0.05, 0.02, 0.1))
	rl.add_theme_constant_override("outline_size", 0)
	rl.add_theme_font_override("font", UiFont.tracked(UiFont.XBOLD, 3))
	ribbon.add_child(rl)
	var rib_row := HBoxContainer.new()
	rib_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib_row.add_child(ribbon)
	v.add_child(rib_row)
	var name_l := Label.new()
	name_l.text = String(info["name"])
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiFont.display_label(name_l, 26, Color.WHITE, rc.darkened(0.35))
	v.add_child(name_l)
	var eff := _label(Game.chaos_blessing_text(id, rarity), 21, rc.lightened(0.35))
	eff.add_theme_font_override("font", UiFont.XBOLD)
	eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(eff)
	var lore := _label(String(info["lore"]), 15, TEXT)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lore)
	if have:
		var was := int(Game.chaos_blessings[id])
		var up := _label("You have it at %s - this makes it %s." % [String(Game.CHAOS_RARITY[was]["name"]).capitalize(),
			String(Game.CHAOS_RARITY[rarity]["name"]).capitalize()], 14, Color(rc.lightened(0.3), 0.9))
		up.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(up)
	b.pressed.connect(_choose.bind(i))
	return b


func _layout() -> void:
	if not visible:
		return
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.x < vp.y
	if _box == null or (_box is VBoxContainer) != portrait:
		var old := _box
		_box = VBoxContainer.new() if portrait else HBoxContainer.new()
		_box.add_theme_constant_override("separation", 14 if portrait else 24)
		_root.add_child(_box)
		for c in _cards:
			if c.get_parent():
				c.reparent(_box, false)
			else:
				_box.add_child(c)
		if old:
			old.queue_free()
	var top := 108.0 if portrait else maxf(24.0, vp.y * 0.08)
	_title.position = Vector2(0, top)
	_title.size = Vector2(vp.x, 50)
	_sub.position = Vector2(24, top + 54)
	_sub.size = Vector2(vp.x - 48, 26)
	var area_top := top + 100.0
	var area_bottom := vp.y - 46.0
	var n := maxi(_cards.size(), 1)
	# (a card for a blessing the pilot already has carries one more line: what it upgrades from)
	var extra := 36.0 if _offers.any(func(o: Dictionary) -> bool: return Game.chaos_blessings.has(o["id"])) else 0.0
	var w: float
	var h: float
	if portrait:
		w = minf(vp.x - 32.0, 520.0)
		h = minf((area_bottom - area_top - 14.0 * (n - 1)) / n, 190.0 + extra)
	else:
		w = minf((vp.x - 80.0 - 24.0 * (n - 1)) / n, 340.0)
		h = minf(area_bottom - area_top, 215.0 + extra)
	for c in _cards:
		c.custom_minimum_size = Vector2(w, h)
	_box.reset_size()
	var sz := _box.get_combined_minimum_size()
	_box.position = Vector2((vp.x - sz.x) / 2.0, area_top + maxf(0.0, (area_bottom - area_top - sz.y) / 2.0))
	_hint.position = Vector2(0, vp.y - 36.0)
	_hint.size = Vector2(vp.x, 24)
	if not _cards.is_empty() and get_viewport().gui_get_focus_owner() == null:
		_cards[0].grab_focus()


func _process(delta: float) -> void:
	if _done:
		return
	if _open and not visible:
		if Upgrades.choosing:
			return  # (a level-up is being picked first)
		_show()
		return
	if not visible:
		return
	_t += delta
	for c in _cards:
		c.disabled = _t < ARM_TIME
	if Controls.ignore_real_input and _t >= AUTO_PICK:
		_choose(0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _done or _t < ARM_TIME:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		var i := [KEY_1, KEY_2, KEY_3].find(k)
		if i < 0:
			i = [KEY_KP_1, KEY_KP_2, KEY_KP_3].find(k)
		if i >= 0:
			_choose(i)
			get_viewport().set_input_as_handled()


func _choose(i: int) -> void:
	if _done or i >= _offers.size():
		return
	_done = true
	var offer := _offers[i]
	Game.take_chaos_blessing(offer["id"], offer["rarity"])
	Sfx.play(&"shield", -5.0)
	var c := _cards[i]
	var tw := create_tween()
	tw.tween_property(c, "modulate", Color(1.7, 1.4, 1.9), 0.12)
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		remove_from_group("modal_overlay")
		get_tree().paused = false
		chosen.emit(offer["id"], offer["rarity"])
		# (CHAOS ARSENAL's free cards: the level-up menu opens now that this one is gone)
		if Upgrades.pending > 0 and not Upgrades.choosing:
			Upgrades.level_up_ready.emit()
		queue_free())
