class_name TitleButton
extends Button
## Title-screen menu button in the style of the key art: dark glass panel with chamfered corners, a
## thin cyan frame, a chevron on the right and a bright glowing highlight when focused or hovered.
## Draws everything itself (text included), so it looks identical on every platform.

const CYAN := Color(0.35, 0.75, 1.0)
const CUT := 14.0

var label_text := ""
var _hl := 0.0


func _init(txt := "", min_size := Vector2(400, 58)) -> void:
	label_text = txt
	text = ""
	flat = true
	custom_minimum_size = min_size
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(grab_focus)
	pressed.connect(func() -> void: Sfx.play(&"select", -8.0))
	for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(s, StyleBoxEmpty.new())


func _process(delta: float) -> void:
	var target := 1.0 if has_focus() else 0.0
	if not is_equal_approx(_hl, target):
		_hl = move_toward(_hl, target, delta * 7.0)
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(w - CUT, 0), Vector2(w, CUT), Vector2(w, h),
		Vector2(CUT, h), Vector2(0, h - CUT)])
	var closed := shape.duplicate()
	closed.append(shape[0])
	# Outer glow when highlighted.
	if _hl > 0.01:
		for i in 3:
			var g := PackedVector2Array()
			for p in closed:
				g.append(p + (p - Vector2(w, h) / 2).normalized() * (3 + i * 3))
			draw_polyline(g, Color(CYAN, 0.18 * _hl / (i + 1)), 4.0, true)
	var base := Color(0.02, 0.05, 0.12, 0.78).lerp(Color(0.05, 0.16, 0.36, 0.9), _hl)
	if button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		base = base.lightened(0.15)
	draw_colored_polygon(shape, base)
	# Inner sheen along the top.
	draw_line(Vector2(6, 4), Vector2(w - CUT - 2, 4), Color(1, 1, 1, 0.06 + 0.08 * _hl), 2.0)
	draw_polyline(closed, Color(CYAN, 0.45 + 0.55 * _hl), 1.5 + 1.0 * _hl, true)
	# Chamfer accent lines.
	draw_line(Vector2(w - CUT - 20, -3), Vector2(w + 3, CUT + 20), Color(CYAN, 0.25 + 0.5 * _hl), 1.0, true)
	draw_line(Vector2(-3, h - CUT - 20), Vector2(CUT + 20, h + 3), Color(CYAN, 0.25 + 0.5 * _hl), 1.0, true)
	# Left marker chevron (slides in when highlighted).
	if _hl > 0.01:
		var x := -6.0 + 16.0 * _hl
		draw_colored_polygon(PackedVector2Array([Vector2(x, h * 0.25), Vector2(x + 10, h * 0.5), Vector2(x, h * 0.75),
			Vector2(x + 4, h * 0.5)]), Color(0.6, 0.9, 1.0, _hl))
	# Text.
	var font := get_theme_default_font()
	var fs := 24 if h >= 52 else 20
	# Long labels on narrow buttons shrink to fit (text area = width minus the chevron margins).
	while fs > 14 and font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 96:
		fs -= 1
	var ty := h / 2 + fs * 0.36
	var tc := Color(0.78, 0.86, 0.95).lerp(Color.WHITE, _hl)
	if disabled:
		tc = Color(0.5, 0.55, 0.6)
	draw_string(font, Vector2(34 + 6 * _hl, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, w - 90, fs, tc)
	# Right chevron(s): single when idle, double when highlighted.
	var cx := w - 40
	var cc := Color(CYAN.lightened(0.3), 0.6 + 0.4 * _hl)
	draw_polyline(PackedVector2Array([Vector2(cx, h * 0.38), Vector2(cx + 7, h * 0.5), Vector2(cx, h * 0.62)]), cc, 2.0, true)
	if _hl > 0.01:
		var off := -9.0 * _hl
		draw_polyline(PackedVector2Array([Vector2(cx + off, h * 0.38), Vector2(cx + off + 7, h * 0.5),
			Vector2(cx + off, h * 0.62)]), Color(cc, cc.a * _hl), 2.0, true)
