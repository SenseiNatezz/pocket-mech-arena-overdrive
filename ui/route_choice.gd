class_name RouteChoice
extends CanvasLayer
## ROUTE CHOICE: shown when a Campaign lead-in sector is clear (ScenicArena._sector_cleared). Two doors, each
## the next sector's map (its key art), the TWIST it plays under and the route's DEAL (Game.route_options);
## picking one emits `picked(route)` and Game.next_sector takes it from there. The game is paused meanwhile.
## Mouse / touch (tap a door), keyboard (1 / 2, left / right + accept) and gamepad all work; doors ignore
## presses for ARM_TIME after appearing. Side by side on landscape screens, stacked on portrait ones.
## Automated runs (Controls.ignore_real_input) take door A by themselves after AUTO_PICK seconds.
## CHAOS RIFT (Game.route_options sometimes adds it): a third, purple door - its curse, the blessing after and
## its HP toll; sealed when the pilot can't spare the HP. Three doors sit side by side / stacked the same way.

signal picked(route: Dictionary)

const ARM_TIME := 0.6
const AUTO_PICK := 1.2
const PANEL := Color(0.03, 0.06, 0.13, 0.96)
const EDGE := Color(0.3, 0.6, 1.0)
const GOLD := Color(1.0, 0.82, 0.3)
const TEXT := Color(0.86, 0.92, 1.0)

var _routes: Array[Dictionary] = []
var _doors: Array[Button] = []
var _root: Control
var _box: BoxContainer
var _title: Label
var _sub: Label
var _hint: Label
var _t := 0.0
var _open := false
var _done := false
## Doors that can't be taken (a CHAOS RIFT the pilot can't pay for).
var _sealed: Array[int] = []


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.04, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_title = Label.new()
	_title.text = "CHOOSE YOUR ROUTE"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.display_label(_title, 40, Color.WHITE)
	_root.add_child(_title)
	_sub = _label("", 18, Color(0.7, 0.85, 1.0))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_sub)
	_hint = _label("", 15, Color(0.75, 0.85, 1.0, 0.75))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)
	get_viewport().size_changed.connect(_layout, CONNECT_DEFERRED)
	visible = false


## Shows the doors for `routes` (from Game.route_options()); waits for an open level-up menu to close first.
func open(routes: Array[Dictionary]) -> void:
	_routes = routes
	if _routes.is_empty():
		_done = true
		picked.emit.call_deferred({})
		return
	_open = true


func _show() -> void:
	visible = true
	get_tree().paused = true
	add_to_group("modal_overlay")  # (the HUD's pause key leaves it alone)
	_t = 0.0
	var n := Game.campaign_sector + 1
	_sub.text = "Sector %d / %d is next%s" % [n, Game.CAMPAIGN_SECTORS,
		"  -  the %s waits there" % String(Game.ARENAS[Game.arena_index]["name"]) if n == Game.CAMPAIGN_SECTORS else ""]
	_hint.text = "Tap a door  //  %s  //  arrows + confirm" % " / ".join(range(1, _routes.size() + 1).map(func(k: int) -> String:
		return str(k)))
	for i in _routes.size():
		var d := _door(i, _routes[i])
		_doors.append(d)
	_layout()
	Sfx.play(&"select", -6.0)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box_style(edge: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(8)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 14
	return s


## One door: the map's key art, its name, then the twist and the deal.
func _door(i: int, r: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var twist: Dictionary = Game.TWISTS.get(r.get("twist", &""), {})
	var deal: Dictionary = Game.SECTOR_DEALS.get(r.get("deal", &""), {})
	var curse: Dictionary = Game.CHAOS_CURSES.get(r.get("curse", &""), {})
	var chaos := not curse.is_empty()
	var accent: Color = Game.CHAOS_COLOR if chaos else twist.get("color", EDGE)
	var edge := Game.CHAOS_COLOR if chaos else EDGE
	b.add_theme_stylebox_override("normal", _box_style(Color(edge, 0.75 if chaos else 0.55), 3 if chaos else 2))
	b.add_theme_stylebox_override("hover", _box_style(accent, 3))
	b.add_theme_stylebox_override("focus", _box_style(Color.WHITE, 3))
	b.add_theme_stylebox_override("pressed", _box_style(GOLD, 4))
	b.add_theme_stylebox_override("disabled", _box_style(Color(edge, 0.3), 2))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 12
	v.offset_bottom = -14
	b.add_child(v)
	var kicker := _label("CHAOS RIFT" if chaos else "DOOR %s" % ["A", "B", "C"][mini(i, 2)], 14,
		Game.CHAOS_COLOR.lightened(0.3) if chaos else GOLD)
	kicker.add_theme_font_override("font", UiFont.tracked(UiFont.BOLD, 3))
	v.add_child(kicker)
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = _map_art(String(r.get("scene", "")))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	if chaos:
		art.modulate = Color(0.85, 0.55, 1.15)  # (the map seen through the rift)
	v.add_child(art)
	var name_l := Label.new()
	name_l.text = String(r.get("name", "")).to_upper()
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.display_label(name_l, 26, Color.WHITE, Game.CHAOS_COLOR.darkened(0.3) if chaos else UiFont.SHADOW)
	v.add_child(name_l)
	if chaos:
		# The rift's deal: a curse for the first waves, then a blessing for the run - and HP to get in.
		v.add_child(_tag(String(curse["name"]), "%s For the first %d waves." % [curse["desc"], Game.CHAOS_CURSE_WAVES],
			Game.CHAOS_COLOR.lightened(0.25)))
		var mech := get_tree().get_first_node_in_group("player") as Mech
		var frac := mech.hp / maxf(mech.max_hp, 1.0) if mech else 1.0
		if frac <= Game.CHAOS_HP_COST + 0.05:
			_sealed.append(i)
			v.add_child(_tag("SEALED  -  NEEDS %d%% HP" % roundi((Game.CHAOS_HP_COST + 0.05) * 100.0),
				"The rift takes %d%% of your HP to get through." % roundi(Game.CHAOS_HP_COST * 100.0), Color(1.0, 0.4, 0.4)))
		else:
			v.add_child(_tag("THEN A BLESSING  -  TOLL %d%% HP" % roundi(Game.CHAOS_HP_COST * 100.0),
				"Pick 1 of 3 blessings that last the rest of the run.", Color(0.5, 0.75, 1.0)))
	if not twist.is_empty():
		v.add_child(_tag("TWIST: %s" % twist["name"], String(twist["desc"]), twist["color"]))
	if not deal.is_empty():
		v.add_child(_tag(String(deal["name"]), String(deal["desc"]), deal["color"]))
	# The sector's BONUS OBJECTIVE (Game.OBJECTIVES).
	var goal: Dictionary = Game.OBJECTIVES.get(r.get("objective", &""), {})
	if not goal.is_empty():
		v.add_child(_tag("BONUS: %s" % goal["name"], String(goal["desc"]), goal["color"]))
	b.pressed.connect(_choose.bind(i))

	return b


## A rule line: its name in its colour, the description under it.
func _tag(head: String, desc: String, col: Color) -> Control:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	var h := _label(head, 17, col)
	h.add_theme_font_override("font", UiFont.XBOLD)
	v.add_child(h)
	var d := _label(desc, 15, TEXT)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)
	return v


## The map's intro key art (or its painted map) from the arena scene, without building the scene.
static func _map_art(scene: String) -> Texture2D:
	var ps := load(scene) as PackedScene if scene != "" else null
	if ps == null:
		return null
	var st := ps.get_state()
	var tex: Texture2D = null
	for i in st.get_node_property_count(0):
		match st.get_node_property_name(0, i):
			&"intro_texture":
				return st.get_node_property_value(0, i)
			&"map_texture":
				tex = st.get_node_property_value(0, i)
	return tex


func _layout() -> void:
	if not visible:
		return
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.x < vp.y
	if _box == null or (_box is VBoxContainer) != portrait:
		var old := _box
		_box = VBoxContainer.new() if portrait else HBoxContainer.new()
		_box.add_theme_constant_override("separation", 16 if portrait else 28)
		_root.add_child(_box)
		for d in _doors:
			if d.get_parent():
				d.reparent(_box, false)
			else:
				_box.add_child(d)
		if old:
			old.queue_free()
	# (portrait: below the HUD status card)
	var top := 108.0 if portrait else maxf(24.0, vp.y * 0.06)
	_title.position = Vector2(0, top)
	_title.size = Vector2(vp.x, 50)
	_sub.position = Vector2(0, top + 54)
	_sub.size = Vector2(vp.x, 26)
	var area_top := top + 92.0
	var area_bottom := vp.y - 46.0
	# Doors sized to what's on them (key art, name, three rule lines), smaller if the screen is short.
	var w: float
	var h: float
	var art_h: float
	var n := maxi(_doors.size(), 2)
	if portrait:
		w = minf(vp.x - 32.0, 520.0)
		h = minf((area_bottom - area_top - 16.0 * (n - 1)) / n, 390.0)
		art_h = clampf(h - 262.0, 50.0 if n < 3 else 36.0, 120.0)
	else:
		# (three doors are narrower, so their rule lines wrap more: taller doors, the key art takes the squeeze)
		w = minf((vp.x - 80.0 - 28.0 * (n - 2)) / n, 430.0)
		h = minf(area_bottom - area_top, 410.0 if n < 3 else 520.0)
		art_h = clampf(h - (262.0 if n < 3 else 368.0), 56.0, 150.0)
	for d in _doors:
		d.custom_minimum_size = Vector2(w, h)
		var art := d.find_child("Art", true, false) as TextureRect
		if art:
			art.custom_minimum_size = Vector2(0, art_h)
	_box.reset_size()
	var sz := _box.get_combined_minimum_size()
	_box.position = Vector2((vp.x - sz.x) / 2.0, area_top + maxf(0.0, (area_bottom - area_top - sz.y) / 2.0))
	_hint.position = Vector2(0, vp.y - 36.0)
	_hint.size = Vector2(vp.x, 24)
	if not _doors.is_empty() and get_viewport().gui_get_focus_owner() == null:
		_doors[0].grab_focus()


func _process(delta: float) -> void:
	if _done:
		return
	if _open and not visible:
		if Upgrades.choosing or Upgrades.pending > 0:
			return  # (a level-up is being picked first)
		_show()
		return
	if not visible:
		return
	_t += delta
	for i in _doors.size():
		_doors[i].disabled = _t < ARM_TIME or _sealed.has(i)
	if Controls.ignore_real_input and _t >= AUTO_PICK:
		_choose(0)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _done or _t < ARM_TIME:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_1, KEY_KP_1:
				_choose(0)
				get_viewport().set_input_as_handled()
			KEY_2, KEY_KP_2:
				_choose(1)
				get_viewport().set_input_as_handled()
			KEY_3, KEY_KP_3:
				_choose(2)
				get_viewport().set_input_as_handled()


func _choose(i: int) -> void:
	if _done or i >= _routes.size() or _sealed.has(i):
		return
	_done = true
	Sfx.play(&"shield", -6.0)
	var d := _doors[i]
	var tw := create_tween()
	tw.tween_property(d, "modulate", Color(1.6, 1.5, 1.2), 0.12)
	tw.tween_property(_root, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		remove_from_group("modal_overlay")
		get_tree().paused = false
		picked.emit(_routes[i])
		queue_free())
