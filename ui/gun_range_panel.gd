extends CanvasLayer
## Weapon Range overlay (see environment/gun_range.gd):
##   weapon bar  every weapon's Higgsfield art with its hotkey; click/tap a slot to switch
##   spawn panel SPAWN ENEMY buttons for every enemy type, SPAWN BOSS (Warden / Ronin / Seraph) + CLEAR
## Layouts, re-applied live when the input device, window size or orientation (Layout.changed) changes:
##   desktop   weapon bar bottom centre (+ key hints), spawn panel down the right side
##   touch     weapon bar sized to fit between the two thumb sticks, above the pause button; the spawn
##             panel folds into a SPAWN toggle under the status card (a compact 2-column grid), so
##             nothing covers the touch buttons
##   portrait  weapon bar as a 3-column grid bottom-left, above the move stick and left of the portrait
##             ability buttons (x 16..238, clear of NOVA at x 258; bottom edge vp.y - 310); compact SPAWN
##             toggle as on touch
## Keyboard hotkeys are handled by the range.

const GOLD := Color(1.0, 0.82, 0.3)
const CYAN := Color(0.35, 0.75, 1.0)
const SLOT := Vector2(62, 88)
const SLOT_GAP := 6
## Touch: the thumb-stick zones (from ui/touch_controls.tscn) the weapon bar must fit between, and the
## height kept clear above the bottom edge for the pause button.
const TOUCH_LEFT_STICK_RIGHT := 290.0
const TOUCH_RIGHT_STICK_LEFT := 490.0
const TOUCH_PAUSE_CLEAR := 70.0
## Portrait: weapon grid columns, slot size and where it sits (clear of the portrait touch layout).
const PORTRAIT_COLS := 3
const PORTRAIT_SLOT := Vector2(70, 94)
const PORTRAIT_BAR_BOTTOM := 310.0

var gun_range: Node
var _slots: Array[Button] = []
var _keys: Array[Label] = []
var _name: Label
var _hint: Label
var _bar: GridContainer
var _panel: PanelContainer
var _grid: GridContainer
var _heads: Array[Label] = []
var _boss_btns: Array[Button] = []
var _toggle: Button
var _spawn_open := false
var _touch := false
var _portrait := false


func _ready() -> void:
	layer = 9
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Weapon bar.
	_bar = GridContainer.new()
	_bar.add_theme_constant_override("h_separation", SLOT_GAP)
	_bar.add_theme_constant_override("v_separation", SLOT_GAP)
	root.add_child(_bar)
	var ids: Array[StringName] = gun_range.weapon_ids()
	for i in ids.size():
		var b := _slot(ids[i], i)
		_bar.add_child(b)
		_slots.append(b)
	_name = _label("", 22, Color.WHITE)
	_name.size = Vector2(600, 30)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_name)
	_hint = _label("WEAPON RANGE  -  every weapon unlocked, you can't be destroyed   //   1-9, 0, - / WHEEL / TAB: switch weapon",
		13, Color(0.75, 0.88, 1.0, 0.85))
	_hint.size = Vector2(800, 24)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hint)

	# Spawn panel (+ the touch toggle that shows / hides it).
	_toggle = _button("SPAWN  +", _toggle_spawn, GOLD)
	_toggle.custom_minimum_size = Vector2(150, 36)
	root.add_child(_toggle)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _box(Color(0.02, 0.05, 0.12, 0.8), CYAN))
	root.add_child(_panel)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_panel.add_child(_grid)
	_heads.append(_head("SPAWN ENEMY"))
	for k in gun_range.ENEMY_KINDS:
		_grid.add_child(_button(k[1], func() -> void: gun_range.spawn_enemy(k[0])))
	_heads.append(_head("SPAWN BOSS"))
	for k in gun_range.BOSS_KINDS:
		var b := _button(k[1], func() -> void: gun_range.spawn_boss(k[0]), k[2].lightened(0.35))
		b.set_meta("name", k[1])
		_grid.add_child(b)
		_boss_btns.append(b)
	_grid.add_child(_button("CLEAR ALL", gun_range.clear_enemies, Color(1.0, 0.55, 0.45)))

	_spawn_open = OS.get_cmdline_user_args().has("--spawn-open")  # debug: screenshots of the open grid
	Controls.device_changed.connect(func(_d: int) -> void: _relayout())
	get_viewport().size_changed.connect(_relayout, CONNECT_DEFERRED)
	var layout := get_node_or_null("/root/Layout")
	if layout:
		layout.changed.connect(func(_p: bool) -> void: _relayout())
	_relayout()
	refresh()


func _head(txt: String) -> Label:
	var l := _label(txt, 16, GOLD)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grid.add_child(l)
	return l


func _toggle_spawn() -> void:
	_spawn_open = not _spawn_open
	_relayout()


## Places everything for the current device + screen size (see the header comment).
func _relayout() -> void:
	_touch = Controls.device == Controls.Device.TOUCH
	var vp := get_viewport().get_visible_rect().size
	_portrait = vp.x < vp.y
	# Touch screens and portrait both use the compact spawn toggle (no side panel).
	var compact := _touch or _portrait
	var n := _slots.size()
	var slot := SLOT
	var cols := n
	var bar_bottom := vp.y - 14.0
	if _portrait:
		slot = PORTRAIT_SLOT
		cols = PORTRAIT_COLS
		bar_bottom = vp.y - PORTRAIT_BAR_BOTTOM
	elif _touch:
		var avail := (vp.x - TOUCH_RIGHT_STICK_LEFT) - TOUCH_LEFT_STICK_RIGHT - 20.0
		var w := clampf((avail - (n - 1) * SLOT_GAP) / n, 36.0, 62.0)
		slot = Vector2(w, roundf(w * 1.35))
		bar_bottom = vp.y - TOUCH_PAUSE_CLEAR
	for i in n:
		_slots[i].custom_minimum_size = slot
		_keys[i].visible = not compact
	_bar.columns = cols
	_bar.size = Vector2.ZERO
	var rows := ceili(n / float(cols))
	var bar_w := cols * (slot.x + SLOT_GAP) - SLOT_GAP
	var bar_h := rows * (slot.y + SLOT_GAP) - SLOT_GAP
	var bar_x := vp.x / 2 - bar_w / 2
	if _portrait:
		bar_x = 16.0
	elif _touch:
		# Centre between the sticks (not the screen) so it never slides under the aim stick.
		bar_x = TOUCH_LEFT_STICK_RIGHT + ((vp.x - TOUCH_RIGHT_STICK_LEFT) - TOUCH_LEFT_STICK_RIGHT) / 2 - bar_w / 2
	_bar.position = Vector2(bar_x, bar_bottom - bar_h)
	if _portrait:
		# Weapon name left-aligned just above the grid.
		_name.add_theme_font_size_override("font_size", 16)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_name.size = Vector2(bar_w + 40, 26)
		_name.position = Vector2(bar_x, _bar.position.y - 30.0)
	else:
		_name.add_theme_font_size_override("font_size", 18 if _touch else 22)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.size = Vector2(600, 30)
		_name.position = Vector2(bar_x + bar_w / 2 - _name.size.x / 2, _bar.position.y - (30.0 if _touch else 64.0))
	_hint.visible = not compact
	_hint.position = Vector2(vp.x / 2 - _hint.size.x / 2, _bar.position.y - 30.0)

	_toggle.visible = compact
	_toggle.text = "SPAWN  -" if _spawn_open else "SPAWN  +"
	_toggle.position = Vector2(16, 116)
	_panel.visible = not compact or _spawn_open
	_grid.columns = 2 if compact else 1
	for h in _heads:
		h.visible = not compact
	for b in _boss_btns:
		b.text = ("Boss: %s" if compact else "%s") % b.get_meta("name")
	for c in _grid.get_children():
		if c is Button:
			c.custom_minimum_size = Vector2(150, 34) if compact else Vector2(160, 31)
	_panel.size = Vector2.ZERO
	_panel.position = Vector2(16, 158) if compact else Vector2(vp.x - 196, 64)


func _label(txt: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _box(bg: Color, edge: Color, width := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = edge
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	return sb


func _button(txt: String, action: Callable, col := Color(0.85, 0.93, 1.0)) -> Button:
	var b := Button.new()
	b.text = txt
	b.custom_minimum_size = Vector2(160, 31)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _box(Color(0.04, 0.1, 0.2, 0.9), Color(CYAN, 0.5), 1))
	b.add_theme_stylebox_override("hover", _box(Color(0.08, 0.2, 0.4, 0.95), CYAN, 1))
	b.add_theme_stylebox_override("pressed", _box(Color(0.15, 0.3, 0.55, 1.0), Color.WHITE, 1))
	b.pressed.connect(action)
	b.pressed.connect(func() -> void: Sfx.play(&"select", -8.0))
	return b


func _slot(id: StringName, index: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = SLOT
	b.focus_mode = Control.FOCUS_NONE
	b.set_meta("id", id)
	b.pressed.connect(func() -> void: gun_range.select_weapon(id))
	var icon := TextureRect.new()
	icon.texture = load("res://assets/hq/weapons/%s.png" % Game.weapon_info(id)["icon"])
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 6
	icon.offset_right = -6
	icon.offset_top = 5
	icon.offset_bottom = -5
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)
	var key := _label(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-"][index] if index < 11 else "", 13, GOLD)
	key.position = Vector2(5, 1)
	b.add_child(key)
	_keys.append(key)
	return b


## Highlights the current weapon's slot and shows its name + type.
func refresh() -> void:
	var cur: StringName = gun_range.mech.weapon if gun_range.mech else Game.weapon
	for b in _slots:
		var on: bool = b.get_meta("id") == cur
		var bg := Color(0.1, 0.16, 0.28, 0.95) if on else Color(0.02, 0.05, 0.12, 0.75)
		for s in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(s, _box(bg.lightened(0.1 if s == "hover" else 0.0), GOLD if on else Color(CYAN, 0.45), 3 if on else 1))
	var w := Game.weapon_info(cur)
	_name.text = "%s   //   %s" % [String(w["name"]).to_upper(), "MELEE" if w.get("melee", false) else "RANGED"]
