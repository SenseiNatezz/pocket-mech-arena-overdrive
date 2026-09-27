class_name MenuButtonFactory
## Shared look for menu buttons (main menu, pause, results). Works with mouse, touch and
## gamepad/keyboard focus (focused buttons glow cyan).


static func make(text: String, min_size := Vector2(340, 52)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.85, 0.93, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _box(Color(0.1, 0.14, 0.22, 0.95), Color(0.3, 0.45, 0.6)))
	b.add_theme_stylebox_override("hover", _box(Color(0.14, 0.24, 0.36, 0.98), Color(0.45, 0.85, 1.0)))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(0.45, 0.9, 1.0), 3))
	b.add_theme_stylebox_override("pressed", _box(Color(0.2, 0.4, 0.55, 1.0), Color(0.6, 0.95, 1.0)))
	b.pressed.connect(func() -> void: Sfx.play(&"select", -8.0))
	return b


static func _box(bg: Color, border: Color, width := 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	return s
