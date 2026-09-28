extends Control
## Gundam Customization screen (layout from the user's design):
##   left   ARMOR PAINT / ENERGY COLOR / BOOSTER COLOR swatches, in-game PREVIEW thumbnails,
##          RESET TO DEFAULT, BACK, APPLY
##   right  showcase Gundam on a pedestal (live recolor), CURRENT SETUP panel
##   bottom controls: drag = rotate, wheel = zoom, right/middle drag = move, R = reset view, F = randomize
## Choices stay pending until APPLY (saved and used in battle); BACK discards them.

const BG := preload("res://assets/hq/customize_bg.jpg")
## 360-degree turntable: a dense 2D frame sequence cut from a Higgsfield turntable video
## (assets/hq/turntable/frame_NNN.png, tools/build_turntable.gd). Frame 0 = front, then turning
## clockwise seen from above. Frames are shown one at a time (no crossfade = no ghosting).
const TURNTABLE_DIR := "res://assets/hq/turntable/"
## Drag sensitivity (radians per pixel) and keyboard step (15 degrees).
const DRAG_SPEED := 0.006
const STEP := TAU / 24.0
## Canvas point under the feet (all frames share the same canvas and baseline).
const FEET := Vector2(280, 548)
const SHOWCASE_SHADER := preload("res://shaders/showcase_recolor.gdshader")
const FLASH_SHADER := preload("res://shaders/hit_flash.gdshader")
const FRAMES := preload("res://assets/sprites/gundam_frames.tres")
const GLOW := preload("res://assets/fx/glow.tres")

const CYAN := Color(0.35, 0.75, 1.0)
const PANEL_BG := Color(0.02, 0.05, 0.11, 0.82)
const PANEL_EDGE := Color(0.3, 0.5, 0.75, 0.45)
const MECH_POS := Vector2(960, 300)
const FEET_Y := 500.0
const MECH_SCALE := 0.79

class Swatch:
	extends Button
	var color := Color.WHITE
	var selected := false
	var _pulse := 0.0

	func _init(c: Color) -> void:
		color = c
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(60, 60)
		for s in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(grab_focus)

	func _process(delta: float) -> void:
		_pulse += delta
		queue_redraw()

	func _draw() -> void:
		var c := size / 2
		var r := 22.0
		if selected:
			for i in 4:
				draw_circle(c, r + 4 + i * 3, Color(color.lightened(0.3), 0.12 - i * 0.025))
		draw_circle(c + Vector2(0, 2), r, Color(0, 0, 0, 0.5))
		draw_circle(c, r, color)
		draw_circle(c + Vector2(-6, -7), r * 0.35, Color(1, 1, 1, 0.18))
		draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.9) if selected else Color(1, 1, 1, 0.22), 3.0 if selected else 1.5, true)
		if has_focus():
			draw_arc(c, r + 6, _pulse * 2.0, _pulse * 2.0 + TAU * 0.8, 40, Color(CYAN, 0.9), 2.0, true)

var _look := {}
var _swatches := {"armor": [], "energy": [], "booster": []}
var _art: TextureRect
var _mech: Sprite2D
var _mech_next: Sprite2D
## Turntable frames load on demand and only the most recent VIEW_CACHE stay in memory: the frames are
## lossy WebP (small download, works on every platform) and all 192 at once would need ~240 MB of
## texture memory - too much for phones.
const VIEW_CACHE := 48
var _view_paths: PackedStringArray = []
var _view_cache := {}
var _idle_t := 0.0
var _spin_speed := 0.6
var _shown_rot := 0.0
var _spin_vel := 0.0
var _demo := OS.get_cmdline_user_args().has("--spin-demo")
var _mech_mat := ShaderMaterial.new()
var _stage: Node2D
var _thumbs: Array[AnimatedSprite2D] = []
var _thumb_mats: Array[ShaderMaterial] = []
var _setup_values: Array[Label] = []
var _setup_dots: Array[ColorRect] = []
var _status: Label
var _rot := 0.0
var _zoom := 1.0
var _offset := Vector2.ZERO
var _dragging := 0
var _t := 0.0
var _flash := 0.0


func _ready() -> void:
	# The layout is designed at 1280x720 and kept centered, so wider/taller windows just show more of
	# the space backdrop (which fills the whole window from its own layer behind the UI).
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(1280, 720)
	_look = Game.look.duplicate()

	var backdrop := CanvasLayer.new()
	backdrop.layer = -1
	add_child(backdrop)
	_art = TextureRect.new()
	_art.texture = BG
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(_art)

	# Showcase stage (pedestal, booster glow, the Gundam).
	_stage = Node2D.new()
	_stage.draw.connect(_draw_stage)
	add_child(_stage)
	_mech_mat.shader = SHOWCASE_SHADER
	var n := 0
	while ResourceLoader.exists(TURNTABLE_DIR + "frame_%03d.png" % n):
		_view_paths.append(TURNTABLE_DIR + "frame_%03d.png" % n)
		n += 1
	_mech = Sprite2D.new()
	_mech_next = Sprite2D.new()
	for s: Sprite2D in [_mech, _mech_next]:
		s.centered = false
		s.offset = -FEET
		s.material = _mech_mat
		_stage.add_child(s)

	# Title.
	var title := _label("CUSTOMIZE", 58, Color(0.93, 0.96, 1.0), Vector2(60, 14))
	title.add_theme_color_override("font_outline_color", Color(0.93, 0.96, 1.0))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_shadow_color", Color(0.3, 0.6, 1.0, 0.45))
	title.add_theme_constant_override("shadow_offset_y", 3)
	_label("P E R S O N A L I Z E   Y O U R   M E C H", 15, Color(0.4, 0.8, 0.95), Vector2(64, 88))

	# Left panel.
	_panel(Rect2(40, 118, 480, 540), PANEL_BG)
	_swatch_section("ARMOR PAINT", "armor", Game.ARMOR, 130)
	_swatch_section("ENERGY COLOR", "energy", Game.ENERGY, 222)
	_swatch_section("BOOSTER COLOR", "booster", Game.BOOSTER, 314)
	_panel(Rect2(56, 408, 448, 128), Color(0.03, 0.07, 0.15, 0.85))
	_label("PREVIEW", 13, Color(0.7, 0.8, 0.9), Vector2(68, 413))
	var anims: Array[StringName] = [&"idle", &"dash", &"fire", &"bank_left"]
	for i in 4:
		var box := Panel.new()
		box.position = Vector2(64 + i * 110, 434)
		box.size = Vector2(102, 96)
		box.clip_contents = true
		box.add_theme_stylebox_override("panel", _box(Color(0.05, 0.1, 0.2, 0.9), Color(0.3, 0.5, 0.75, 0.5), 6))
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(box)
		var glow := Sprite2D.new()
		glow.texture = GLOW
		glow.position = Vector2(51, 56)
		glow.scale = Vector2.ONE * 0.9
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		glow.material = add
		glow.name = "Glow"
		box.add_child(glow)
		var s := AnimatedSprite2D.new()
		s.sprite_frames = FRAMES
		s.play(anims[i])
		s.frame = i * 2
		s.position = Vector2(51, 50)
		s.scale = Vector2.ONE * 0.4
		s.rotation = [0.0, -0.5, 0.35, 0.8][i]
		var m := ShaderMaterial.new()
		m.shader = FLASH_SHADER
		s.material = m
		box.add_child(s)
		_thumbs.append(s)
		_thumb_mats.append(m)

	var reset := _button("RESET TO DEFAULT", Rect2(56, 546, 448, 40), false)
	reset.pressed.connect(func() -> void:
		_look = Game.DEFAULT_LOOK.duplicate()
		_refresh()
		_status_msg("Reset to default (press APPLY to save)"))
	var back := _button("BACK", Rect2(56, 596, 216, 50), false)
	back.pressed.connect(_back)
	var apply := _button("APPLY", Rect2(288, 596, 216, 50), true)
	apply.pressed.connect(_apply)

	# Current setup.
	_panel(Rect2(700, 552, 540, 112), PANEL_BG)
	_label("CURRENT SETUP", 20, Color(0.93, 0.96, 1.0), Vector2(720, 556))
	var names := ["ARMOR PAINT", "ENERGY COLOR", "BOOSTER COLOR"]
	for i in 3:
		var y := 588 + i * 25
		var dot := ColorRect.new()
		dot.position = Vector2(722, y + 5)
		dot.size = Vector2(14, 14)
		add_child(dot)
		_setup_dots.append(dot)
		_label(names[i], 15, Color(0.75, 0.83, 0.92), Vector2(746, y))
		var v := _label("", 15, Color(0.93, 0.96, 1.0), Vector2(1080, y))
		_setup_values.append(v)

	# Controls bar.
	_panel(Rect2(40, 672, 1200, 40), Color(0.02, 0.05, 0.11, 0.8))
	var hints := [["DRAG", "ROTATE (Q/E STEP)"], ["WHEEL", "ZOOM"], ["R-DRAG", "MOVE"], ["R", "RESET VIEW"], ["F", "RANDOMIZE"]]
	for i in hints.size():
		var x := 70 + i * 236
		var key := _label(hints[i][0], 12, Color(0.85, 0.92, 1.0), Vector2(x, 682))
		key.add_theme_stylebox_override("normal", _box(Color(0.08, 0.14, 0.26), Color(0.4, 0.6, 0.85, 0.7), 4, 6))
		_label(hints[i][1], 15, Color(0.8, 0.88, 0.96), Vector2(x + 74, 681))

	_status = _label("", 14, Color(0.5, 1.0, 0.7), Vector2(720, 520))
	_refresh()
	_swatches["armor"][_look["armor"]].grab_focus()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--look="):
			var v := a.trim_prefix("--look=").split(",")
			_look = {"armor": int(v[0]), "energy": int(v[1]), "booster": int(v[2])}
			_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)


# --- building helpers ----------------------------------------------------------------------------------

func _box(bg: Color, border: Color, radius := 8, pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


func _panel(r: Rect2, bg: Color) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _box(bg, PANEL_EDGE, 10))
	add_child(p)
	return p


func _label(txt: String, fs: int, col: Color, pos: Vector2) -> Label:
	var l := Label.new()
	l.text = txt
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _swatch_section(title: String, key: String, options: Array[Dictionary], y: float) -> void:
	_panel(Rect2(56, y, 448, 86), Color(0.03, 0.07, 0.15, 0.85))
	_label(title, 18, Color(0.9, 0.94, 1.0), Vector2(72, y + 4))
	for i in options.size():
		var s := Swatch.new(options[i]["color"])
		s.position = Vector2(66 + i * 84, y + 26)
		s.size = Vector2(60, 60)
		s.tooltip_text = options[i]["name"]
		s.pressed.connect(func() -> void:
			_look[key] = i
			Sfx.play(&"select", -8.0)
			_refresh())
		add_child(s)
		_swatches[key].append(s)


func _button(txt: String, r: Rect2, primary: bool) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = r.position
	b.size = r.size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 22 if r.size.y >= 48 else 17)
	var base := Color(0.1, 0.4, 0.95) if primary else Color(0.03, 0.07, 0.16, 0.9)
	var edge := Color(0.45, 0.75, 1.0) if primary else Color(0.3, 0.5, 0.8, 0.7)
	b.add_theme_stylebox_override("normal", _box(base, edge, 6))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.12), CYAN, 6))
	b.add_theme_stylebox_override("focus", _box(Color(0, 0, 0, 0), Color(0.6, 0.9, 1.0), 6))
	b.add_theme_stylebox_override("pressed", _box(base.lightened(0.25), CYAN, 6))
	b.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0) if primary else Color(0.75, 0.83, 0.92))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.mouse_entered.connect(b.grab_focus)
	add_child(b)
	return b


# --- state -------------------------------------------------------------------------------------------------

func _refresh() -> void:
	for key in _swatches:
		for i in _swatches[key].size():
			_swatches[key][i].selected = i == _look[key]
	var armor: Dictionary = Game.ARMOR[_look["armor"]]
	var energy: Color = Game.ENERGY[_look["energy"]]["color"]
	var booster: Color = Game.BOOSTER[_look["booster"]]["color"]
	_mech_mat.set_shader_parameter("armor_original", armor.get("none", false))
	_mech_mat.set_shader_parameter("armor_color", armor["color"])
	_mech_mat.set_shader_parameter("energy_color", energy)
	for i in _thumbs.size():
		Game.apply_armor(_thumb_mats[i], _look["armor"])
		var glow := _thumbs[i].get_parent().get_node("Glow") as Sprite2D
		glow.modulate = Color(booster, 0.35) if i != 2 else Color(energy, 0.45)
	var rows := [[armor["name"], armor["color"]], [Game.ENERGY[_look["energy"]]["name"], energy],
		[Game.BOOSTER[_look["booster"]]["name"], booster]]
	for i in 3:
		_setup_values[i].text = str(rows[i][0]).to_upper()
		_setup_dots[i].color = rows[i][1]
	_flash = 0.35


func _apply() -> void:
	Game.set_look(_look)
	Sfx.play(&"levelup", -6.0, 0.0)
	_status_msg("Applied! Your mech will deploy with this setup.")


func _back() -> void:
	Game.to_menu()


func _randomize() -> void:
	_look = {"armor": randi() % Game.ARMOR.size(), "energy": randi() % Game.ENERGY.size(),
		"booster": randi() % Game.BOOSTER.size()}
	Sfx.play(&"select", -6.0)
	_refresh()


## Turns the Gundam exactly one drawn angle (22.5 degrees) - for inspecting it part by part.
func _step(dir: int) -> void:
	_spin_vel = 0.0
	_idle_t = 0.0
	_rot = roundf(_rot / STEP) * STEP + dir * STEP


func _reset_view() -> void:
	_rot = 0.0
	_spin_vel = 0.0
	_idle_t = 0.0
	_zoom = 1.0
	_offset = Vector2.ZERO


func _status_msg(txt: String) -> void:
	_status.text = txt
	_status.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(_status, "modulate:a", 0.0, 0.6)


# --- input -------------------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_back()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			_reset_view()
		elif event.physical_keycode == KEY_F:
			_randomize()


func _input(event: InputEvent) -> void:
	var over_stage := false
	if event is InputEventMouse:
		var lp: Vector2 = event.position - position
		over_stage = lp.x > 560 and lp.y < 545
	if event is InputEventMouseButton:
		if event.pressed and over_stage:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_zoom = clampf(_zoom + 0.08, 0.6, 1.6)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_zoom = clampf(_zoom - 0.08, 0.6, 1.6)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_dragging = 1
				_spin_vel = 0.0
			elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
				_dragging = 2
		elif not event.pressed:
			_dragging = 0
	elif event is InputEventMouseMotion and _dragging != 0:
		if _dragging == 1:
			_rot += event.relative.x * DRAG_SPEED
			_spin_vel = clampf(lerpf(_spin_vel, event.relative.x * DRAG_SPEED / maxf(get_process_delta_time(), 0.001), 0.35), -6.0, 6.0)
			_idle_t = 0.0
		else:
			_offset = (_offset + event.relative).clamp(Vector2(-260, -160), Vector2(240, 160))


# --- showcase ------------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_flash = move_toward(_flash, 0.0, delta * 2.0)
	# Real turntable: 16 drawn angles of the Gundam; dragging spins it all the way around (360),
	# and it slowly turns by itself when left alone. Neighbouring angles blend briefly mid-turn.
	_idle_t += delta
	if _dragging != 1 and (_idle_t > 2.5 or _demo):
		_rot += delta * (1.05 if _demo else _spin_speed)
	if _demo and _t > 6.0 and _look["armor"] == 0:
		_look = {"armor": 1, "energy": 3, "booster": 3}
		_refresh()
	# Momentum after a flick, then ease the shown angle toward the target (fluid, no snapping).
	if _dragging != 1 and absf(_spin_vel) > 0.01:
		_rot += _spin_vel * delta
		_spin_vel = move_toward(_spin_vel, 0.0, delta * 3.5)
		_idle_t = 0.0
	# Follow the drag 1:1 while dragging (no trailing lag); ease only for keyboard steps.
	_shown_rot = _rot if _dragging == 1 else lerpf(_shown_rot, _rot, 1.0 - exp(-16.0 * delta))
	var count := _view_paths.size()
	# Video frames turn the front toward screen-left as they advance; drag right = front moves right.
	var i := roundi(fposmod(-_shown_rot / TAU, 1.0) * count) % count
	_mech.texture = _view(i)
	_mech_next.visible = false
	var s := MECH_SCALE * _zoom
	var feet := Vector2(MECH_POS.x, FEET_Y) + _offset + Vector2(0, sin(_t * 1.4) * 5.0)
	_mech.position = feet
	_mech.scale = Vector2(s, s)
	_mech_mat.set_shader_parameter("flash", _flash * 0.25)
	_stage.queue_redraw()
	position = ((get_viewport_rect().size - size) / 2.0).floor()
	_art.pivot_offset = _art.size / 2.0
	_art.scale = Vector2(1.02, 1.02)
	_art.position = Vector2(sin(_t * 0.08) * 5.0, 0)


func _draw_stage() -> void:
	var booster: Color = Game.BOOSTER[_look["booster"]]["color"]
	var c := Vector2(MECH_POS.x + _offset.x, 492 + _offset.y)
	var rx := 210.0 * _zoom
	var ry := 44.0 * _zoom
	# Pedestal: dark disc with thickness and a glowing rim in the booster color.
	for i in 14:
		_ellipse(c + Vector2(0, 16 * _zoom - i), rx, ry, Color(0.05, 0.06, 0.1, 1.0).lerp(Color(0.12, 0.14, 0.2), i / 14.0))
	_ellipse(c, rx, ry, Color(0.11, 0.13, 0.19))
	_ellipse(c, rx * 0.86, ry * 0.86, Color(0.08, 0.1, 0.15))
	_ellipse_ring(c, rx * 0.8, ry * 0.8, Color(booster, 0.85), 3.0)
	_ellipse_ring(c, rx * 0.8 + 5, ry * 0.8 + 3, Color(booster, 0.25), 6.0)
	_ellipse_ring(c, rx, ry, Color(0.5, 0.6, 0.8, 0.5), 1.5)
	# Booster glow behind the mech (the back thrusters).
	var back := Vector2(MECH_POS.x + _offset.x, MECH_POS.y + _offset.y - 20 * _zoom)
	for i in 5:
		_stage.draw_circle(back + Vector2(0, -i * 6), (150 - i * 22) * _zoom, Color(booster, 0.02 + i * 0.008))
	# Rising thruster particles.
	for i in 16:
		var k := fmod(_t * 0.5 + i * 0.137, 1.0)
		var x := sin(i * 12.9898) * 120.0 * _zoom
		var p := Vector2(c.x + x, c.y - 10 - k * 360 * _zoom)
		_stage.draw_circle(p, 2.5 * _zoom, Color(booster, (1.0 - k) * 0.8))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_stage.draw_colored_polygon(pts, col)


func _ellipse_ring(c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	for i in 49:
		var a := TAU * i / 48
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	_stage.draw_polyline(pts, col, w, true)


## Turntable frame `i`, loaded on first use; the oldest cached frame is dropped past VIEW_CACHE.
func _view(i: int) -> Texture2D:
	if not _view_cache.has(i):
		if _view_cache.size() >= VIEW_CACHE:
			_view_cache.erase(_view_cache.keys()[0])
		_view_cache[i] = load(_view_paths[i])
	return _view_cache[i]
