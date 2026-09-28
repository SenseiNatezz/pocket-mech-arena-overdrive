extends CanvasLayer
## Tutorial UI (environment/tutorial.gd): the current step card at the top of the screen (step count,
## title, device-specific instructions, progress bar, check mark when done), a SKIP button, and the
## "TRAINING COMPLETE" screen with where-to-go-next buttons. Instructions switch live when the player
## changes device (keyboard/mouse <-> gamepad <-> touch).

const WIDTH := 500.0
const TEAL := Color(0.35, 1.0, 0.8)

var tutorial: Node
var _card: PanelContainer
var _count: Label
var _title: Label
var _text: Label
var _bar: Control
var _done_t := 0.0
var _finish: Control
var _shown_device := -1


func _ready() -> void:
	layer = 11
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", _box(Color(0.02, 0.05, 0.11, 0.86), Color(TEAL, 0.55)))
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.offset_left = -WIDTH / 2
	_card.offset_right = WIDTH / 2
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	_count = _label(13, TEAL)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top.add_child(_count)
	var skip := Button.new()
	skip.text = "SKIP TUTORIAL"
	skip.focus_mode = Control.FOCUS_NONE
	skip.add_theme_font_size_override("font_size", 12)
	skip.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 0.8))
	skip.add_theme_stylebox_override("normal", _box(Color(0.05, 0.1, 0.2, 0.8), Color(0.4, 0.6, 0.9, 0.5), 4))
	skip.add_theme_stylebox_override("hover", _box(Color(0.1, 0.2, 0.35, 0.9), Color(0.5, 0.85, 1.0, 0.8), 4))
	skip.add_theme_stylebox_override("pressed", _box(Color(0.15, 0.3, 0.45, 0.9), Color(0.6, 0.9, 1.0), 4))
	skip.pressed.connect(func() -> void:
		Game.finish_tutorial()
		Game.to_menu())
	top.add_child(skip)
	_title = _label(26, Color.WHITE)
	v.add_child(_title)
	_text = _label(17, Color(0.85, 0.92, 1.0))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH - 32, 46)
	v.add_child(_text)
	_bar = Control.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	v.add_child(_bar)
	_card.hide()


func _box(bg: Color, border: Color, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(pad)
	return s


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## New step: fill in the card and slide it in.
func show_step() -> void:
	_done_t = 0.0
	_count.text = "TRAINING   %d / %d" % [tutorial.step + 1, tutorial.STEPS.size()]
	_title.text = tutorial.STEPS[tutorial.step][1]
	_title.add_theme_color_override("font_color", Color.WHITE)
	_text.text = tutorial.step_text()
	_shown_device = Controls.device
	_card.show()
	_card.modulate.a = 0.0
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(_card, "modulate:a", 1.0, 0.25)
	tw.tween_property(_card, "offset_top", _top_y(), 0.3).from(_top_y() - 30.0).set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


func step_complete() -> void:
	_done_t = 1.0
	_title.text = "%s  -  DONE!" % tutorial.STEPS[tutorial.step][1]
	_title.add_theme_color_override("font_color", TEAL)


## Below the objective line; on touch screens below the top row of ability buttons.
func _top_y() -> float:
	return 116.0 if Controls.device == Controls.Device.TOUCH else 48.0


func _process(delta: float) -> void:
	if not _card.visible or tutorial == null:
		return
	if Controls.device != _shown_device and tutorial.step >= 0 and tutorial.step < tutorial.STEPS.size():
		_shown_device = Controls.device
		_text.text = tutorial.step_text()
		_card.offset_top = _top_y()
	_done_t = maxf(_done_t - delta, 0.0)
	_bar.queue_redraw()


func _draw_bar() -> void:
	var r := Rect2(Vector2(0, 2), Vector2(_bar.size.x, 6))
	_bar.draw_rect(r, Color(0, 0, 0, 0.6))
	var p: float = tutorial.progress if tutorial else 0.0
	var col := TEAL.lerp(Color.WHITE, _done_t * 0.6)
	_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * p, r.size.y)), col)
	_bar.draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0)


## Training complete: where to go next.
func show_finished() -> void:
	_card.hide()
	_finish = ColorRect.new()
	(_finish as ColorRect).color = Color(0.0, 0.02, 0.06, 0.6)
	_finish.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_finish)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", _box(Color(0.03, 0.06, 0.12, 0.96), Color(TEAL, 0.8), 28))
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_finish.add_child(box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(400, 0)
	box.add_child(v)
	var t := _label(36, TEAL)
	t.text = "TRAINING COMPLETE!"
	v.add_child(t)
	var s := _label(17, Color(0.85, 0.92, 1.0))
	s.text = "You're ready, pilot. Where to next?"
	v.add_child(s)
	var first: Button = null
	for entry in [["PLAY THE CAMPAIGN", func() -> void: Game.start_arena(Game.continue_index())],
			["ENDLESS MODE", func() -> void: Game.start_endless()],
			["WEAPON RANGE", Game.to_gun_range], ["MAIN MENU", Game.to_menu]]:
		var b := MenuButtonFactory.make(entry[0])
		b.pressed.connect(entry[1])
		v.add_child(b)
		if first == null:
			first = b
	first.grab_focus()
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.3)
