class_name ControlsPage
extends Control
## Main menu > Settings > CONTROLS: rebind the keyboard / mouse controls (Controls.REBINDABLE).
## Press an action, then the new key or mouse button (Esc cancels). A key another action already used
## is swapped over to it, so nothing is ever left unbound. Arrow keys keep moving the mech, and gamepads
## keep the standard layout (Steam Input can remap those). Bindings are saved with the settings.

signal back_pressed

var _grid: GridContainer
var _btns := {}
var _hint: Label
var _back: TitleButton
## The action waiting for a new key (&"" = none).
var _waiting := &""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.04, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	center.add_child(col)
	var title := _label("CONTROLS", 40, Color.WHITE)
	UiFont.page_title(title, 36)
	col.add_child(title)
	_hint = _label("", 15, Color(0.7, 0.85, 1.0, 0.85))
	col.add_child(_hint)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_grid)
	for r: Array in Controls.REBINDABLE:
		var b := TitleButton.new("", Vector2(360, 44))
		b.pressed.connect(_start.bind(r[0]))
		_grid.add_child(b)
		_btns[r[0]] = b
	var note := _label("Arrow keys always move too. Gamepads use the standard layout (remap them with Steam Input).",
		13, Color(0.7, 0.85, 1.0, 0.6))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(360, 0)
	col.add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var reset := TitleButton.new("Reset to defaults", Vector2(240, 46))
	reset.pressed.connect(func() -> void:
		_waiting = &""
		Controls.reset_bindings()
		Game.save()
		refresh())
	row.add_child(reset)
	_back = TitleButton.new("Back", Vector2(240, 46))
	_back.pressed.connect(func() -> void:
		_waiting = &""
		back_pressed.emit())
	row.add_child(_back)
	Layout.changed.connect(func(_p: bool) -> void: _relayout())
	_relayout()
	refresh()


## Two columns of actions on landscape screens, one on portrait / narrow ones.
func _relayout() -> void:
	_grid.columns = 1 if Layout.portrait or get_viewport_rect().size.x < 800.0 else 2


func refresh() -> void:
	for r: Array in Controls.REBINDABLE:
		var b: TitleButton = _btns[r[0]]
		var key := "press a key..." if _waiting == r[0] else Controls.key_name(r[0])
		b.label_text = "%s:   %s" % [r[1], key]
		b.queue_redraw()
	_hint.text = "Press the new key or mouse button   (Esc cancels)" if _waiting != &"" \
		else "Choose an action to change its key."


func focus_default() -> void:
	_waiting = &""
	refresh()
	(_btns[Controls.REBINDABLE[0][0]] as Control).grab_focus()


func _start(action: StringName) -> void:
	_waiting = action
	refresh()


func _input(event: InputEvent) -> void:
	if _waiting == &"" or not is_visible_in_tree():
		return
	var bound: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			_cancel()
			return
		if k.keycode == KEY_F11:
			return  # (fullscreen toggle)
		var e := InputEventKey.new()
		e.physical_keycode = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		bound = e
	elif event is InputEventMouseButton and event.pressed:
		var idx := (event as InputEventMouseButton).button_index
		if idx in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]:
			var e := InputEventMouseButton.new()
			e.button_index = idx
			e.pressed = true
			bound = e
	elif event is InputEventJoypadButton and event.pressed:
		_cancel()
		return
	if bound == null:
		return
	get_viewport().set_input_as_handled()
	Controls.rebind(_waiting, bound)
	Game.save()
	Sfx.play(&"select", -8.0)
	var b: TitleButton = _btns[_waiting]
	_waiting = &""
	refresh()
	b.grab_focus()


func _cancel() -> void:
	get_viewport().set_input_as_handled()
	var b: TitleButton = _btns[_waiting]
	_waiting = &""
	refresh()
	b.grab_focus()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0.02, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	return l
