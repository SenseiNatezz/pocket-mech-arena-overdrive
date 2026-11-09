class_name TitleButton
extends Button
## Menu button in the style of the key art: dark glass panel with chamfered corners, a thin cyan frame, a
## chevron on the right and a bright glowing highlight when focused or hovered.
## Draws everything itself (text included), so it looks identical on every platform.
## While the title screen is up (`lobby_style`, set by ui/main_menu.gd) it uses the lobby's look instead
## (ui/lobby_kit.gd: gradient glass panel, Chakra Petch caps), so the menu's pages match the lobby; in-game
## menus (level-up) keep the classic look.

const CYAN := Color(0.35, 0.75, 1.0)
const GOLD_HI := Color(1.0, 0.84, 0.4)
const GOLD_LO := Color(0.86, 0.55, 0.12)
const NAVY := Color(0.04, 0.06, 0.13)
const CUT := 14.0

static var lobby_style := false

var label_text := ""
## The title screen's call to action (New Game): a gold button that breathes a glow and catches a light
## sweep every few seconds, dark text.
var primary := false
## Entrance: 1 = off to the right and invisible, 0 = in place (the menu tweens it in).
var slide := 0.0:
	set(v):
		slide = v
		modulate.a = 1.0 - v
		queue_redraw()
var _hl := 0.0
var _t := 0.0


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
	_t += delta
	var target := 1.0 if has_focus() else 0.0
	if not is_equal_approx(_hl, target):
		_hl = move_toward(_hl, target, delta * 7.0)
		queue_redraw()
	elif primary and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_set_transform(Vector2(90.0 * slide, 0.0))
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(w - CUT, 0), Vector2(w, CUT), Vector2(w, h),
		Vector2(CUT, h), Vector2(0, h - CUT)])
	var closed := shape.duplicate()
	closed.append(shape[0])
	if primary:
		_draw_primary(shape, closed, w, h)
		return
	if lobby_style:
		_draw_lobby(w, h)
		return
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


## The lobby look: the shared glass panel (ui/lobby_kit.gd), a cyan marker when highlighted, Chakra Petch caps
## (shrunk to fit), chevrons on the right.
func _draw_lobby(w: float, h: float) -> void:
	var press := button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	LobbyKit.panel(self, Rect2(0, 0, w, h), 11.0, clampf(_hl + (0.35 if press else 0.0), 0.0, 1.2))
	if _hl > 0.01:
		var x := 6.0 + 6.0 * _hl
		draw_colored_polygon(PackedVector2Array([Vector2(x, h * 0.3), Vector2(x + 8, h * 0.5), Vector2(x, h * 0.7),
			Vector2(x + 3, h * 0.5)]), Color(LobbyKit.CYAN.lightened(0.4), _hl))
	var font := LobbyKit.SEMI
	var txt := label_text.to_upper()
	var fs := LobbyKit.fit(font, txt, 19 if h >= 44 else 16, w - 82.0, 11)
	var tc := LobbyKit.TEXT.lerp(Color.WHITE, _hl)
	if disabled:
		tc = Color(0.5, 0.55, 0.6)
	draw_string(font, Vector2(26 + 5 * _hl, h / 2 + fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, w - 70, fs, tc)
	var cx := w - 34
	var cc := Color(LobbyKit.CYAN.lightened(0.3), 0.55 + 0.45 * _hl)
	draw_polyline(PackedVector2Array([Vector2(cx, h * 0.38), Vector2(cx + 6, h * 0.5), Vector2(cx, h * 0.62)]), cc, 2.0, true)
	if _hl > 0.01:
		var off := -8.0 * _hl
		draw_polyline(PackedVector2Array([Vector2(cx + off, h * 0.38), Vector2(cx + off + 6, h * 0.5),
			Vector2(cx + off, h * 0.62)]), Color(cc, cc.a * _hl), 2.0, true)


## The gold call-to-action look: a breathing gold glow, a gold gradient fill, a bright frame, a light sweep
## every few seconds, dark text and chevrons.
func _draw_primary(shape: PackedVector2Array, closed: PackedVector2Array, w: float, h: float) -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.2)
	for i in 3:
		var g := PackedVector2Array()
		for p in closed:
			g.append(p + (p - Vector2(w, h) / 2).normalized() * (3 + i * 4))
		draw_polyline(g, Color(GOLD_HI, (0.16 + 0.14 * pulse + 0.2 * _hl) / (i + 1)), 4.0, true)
	var cols := PackedColorArray()
	for p in shape:
		cols.append(GOLD_HI.lerp(GOLD_LO, p.y / h).lightened(0.12 * _hl))
	if button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		for i in cols.size():
			cols[i] = cols[i].lightened(0.15)
	draw_polygon(shape, cols)
	draw_line(Vector2(6, 3), Vector2(w - CUT - 2, 3), Color(1, 1, 1, 0.35), 2.0)
	# Light sweep across it every 3.2 s.
	var cycle := fmod(_t, 3.2)
	if cycle < 0.7:
		var x := lerpf(-60.0, w + 60.0, cycle / 0.7)
		var band := PackedVector2Array([Vector2(x - 18, h), Vector2(x + 10, 0), Vector2(x + 34, 0), Vector2(x + 6, h)])
		for piece in Geometry2D.intersect_polygons(shape, band):
			draw_colored_polygon(piece, Color(1, 1, 1, 0.38))
	draw_polyline(closed, Color(1.0, 0.95, 0.75, 0.85), 1.5 + 1.0 * _hl, true)
	draw_line(Vector2(w - CUT - 20, -3), Vector2(w + 3, CUT + 20), Color(GOLD_HI, 0.5 + 0.4 * _hl), 1.0, true)
	draw_line(Vector2(-3, h - CUT - 20), Vector2(CUT + 20, h + 3), Color(GOLD_HI, 0.5 + 0.4 * _hl), 1.0, true)
	if _hl > 0.01:
		var mx := -6.0 + 16.0 * _hl
		draw_colored_polygon(PackedVector2Array([Vector2(mx, h * 0.25), Vector2(mx + 10, h * 0.5), Vector2(mx, h * 0.75),
			Vector2(mx + 4, h * 0.5)]), Color(NAVY, _hl))
	var font := get_theme_default_font()
	var fs := 27 if h >= 56 else 24
	while fs > 14 and font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 96:
		fs -= 1
	draw_string(font, Vector2(34 + 6 * _hl, h / 2 + fs * 0.36), label_text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, w - 90, fs, NAVY)
	var cx := w - 40
	for off in ([0.0, -9.0] if _hl > 0.01 else [0.0]):
		draw_polyline(PackedVector2Array([Vector2(cx + off, h * 0.36), Vector2(cx + off + 8, h * 0.5), Vector2(cx + off, h * 0.64)]),
			Color(NAVY, 0.9), 2.5, true)
