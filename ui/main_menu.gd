extends Control
## Main menu: drifting parallax city background, the mech, and menus built in code.
##   PLAY -> Arena 1  |  ARENA SELECT  |  TEST RANGE  |  SETTINGS  |  QUIT
## Works with mouse, touch (taps) and keyboard/gamepad (focus + ui_accept).

const SKYLINE := preload("res://environment/parallax_skyline.gd")
const FRAMES := preload("res://assets/sprites/gundam_frames.tres")

var _main: VBoxContainer
var _arenas: VBoxContainer
var _settings: VBoxContainer
var _shake_btn: Button
var _vol_label: Label
var _mech: AnimatedSprite2D
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := Node2D.new()
	bg.set_script(SKYLINE)
	bg.set("drift", Vector2(-40, 25))
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.06, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_mech = AnimatedSprite2D.new()
	_mech.sprite_frames = FRAMES
	_mech.play(&"boost")
	_mech.scale = Vector2.ONE * 1.1
	add_child(_mech)

	var title := Label.new()
	title.text = "POCKET MECH ARENA"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.05, 0.15, 0.3))
	title.add_theme_constant_override("outline_size", 14)
	title.position = Vector2(60, 60)
	add_child(title)
	var sub := Label.new()
	sub.text = "URAGUN VERSION  //  twin-stick mech combat"
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(1.0, 0.55, 0.3))
	sub.position = Vector2(66, 142)
	add_child(sub)

	var holder := MarginContainer.new()
	holder.anchor_left = 1.0
	holder.anchor_right = 1.0
	holder.anchor_top = 0.5
	holder.anchor_bottom = 0.5
	holder.offset_left = -460.0
	holder.offset_right = -60.0
	holder.offset_top = -110.0
	holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(holder)

	_main = _column(holder)
	_add(_main, "PLAY", func() -> void: Game.start_arena(0))
	_add(_main, "ARENA SELECT", _show.bind(1))
	_add(_main, "TEST RANGE", Game.to_test_range)
	_add(_main, "SETTINGS", _show.bind(2))
	if OS.get_name() != "Web":
		_add(_main, "QUIT", get_tree().quit)

	_arenas = _column(holder)
	for i in Game.ARENAS.size():
		var done := " (cleared)" if Game.cleared.has(i) else ""
		_add(_arenas, "%d. %s%s" % [i + 1, Game.ARENAS[i]["name"].to_upper(), done], Game.start_arena.bind(i))
	_add(_arenas, "BACK", _show.bind(0))

	_settings = _column(holder)
	_shake_btn = _add(_settings, "", func() -> void:
		Game.set_screen_shake(not Game.screen_shake)
		_refresh_settings())
	var vol := HBoxContainer.new()
	vol.add_theme_constant_override("separation", 10)
	var minus := MenuButtonFactory.make("-", Vector2(64, 52))
	minus.pressed.connect(func() -> void:
		Game.set_volume(Game.master_volume - 0.1)
		_refresh_settings())
	var plus := MenuButtonFactory.make("+", Vector2(64, 52))
	plus.pressed.connect(func() -> void:
		Game.set_volume(Game.master_volume + 0.1)
		_refresh_settings())
	_vol_label = Label.new()
	_vol_label.custom_minimum_size = Vector2(190, 52)
	_vol_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vol_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vol_label.add_theme_font_size_override("font_size", 20)
	vol.add_child(minus)
	vol.add_child(_vol_label)
	vol.add_child(plus)
	_settings.add_child(vol)
	var help := Label.new()
	help.text = "Keyboard/Mouse, gamepad and touch are all supported.\nPause in-game (Esc / Start / II) to see the controls."
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_settings.add_child(help)
	_add(_settings, "BACK", _show.bind(0))
	_refresh_settings()
	_show(0)
	Sfx.warm_up()


func _column(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	parent.add_child(v)
	return v


func _add(col: VBoxContainer, text: String, action: Callable) -> Button:
	var b := MenuButtonFactory.make(text, Vector2(380, 56))
	b.pressed.connect(action)
	col.add_child(b)
	return b


func _show(which: int) -> void:
	var cols := [_main, _arenas, _settings]
	for i in cols.size():
		cols[i].visible = i == which
	(cols[which].get_child(0) as Control).grab_focus()


func _refresh_settings() -> void:
	_shake_btn.text = "SCREEN SHAKE: %s" % ("ON" if Game.screen_shake else "OFF")
	_vol_label.text = "VOLUME %d%%" % roundi(Game.master_volume * 100.0)


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport_rect().size
	_mech.position = Vector2(vp.x * 0.3, vp.y * 0.62 + sin(_t * 1.6) * 12.0)
	_mech.rotation = 0.35 + sin(_t * 0.8) * 0.05
	if Input.is_action_just_pressed("pause") and not _main.visible:
		_show(0)
