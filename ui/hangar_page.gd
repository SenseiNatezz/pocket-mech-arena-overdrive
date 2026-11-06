class_name HangarPage
extends Control
## Main menu HANGAR (permanent progression, see Game.HANGAR / Game.CHASSIS): spend the SCRAP earned in
## runs on mech chassis and permanent upgrades. One scrolling column, so it works in landscape and
## portrait alike, with mouse, touch and keyboard / gamepad focus.
##   MECH CHASSIS  three frames as cards (big mech art at the frames' real relative sizes), SELECT / BUY;
##                 cards grow to fit each frame's ability text
##   UPGRADES      each permanent upgrade (Game.HANGAR, any count) with its level pips and an UPGRADE
##                 (cost) button, 2 columns in landscape / 1 in portrait

signal back_pressed

const GOLD := Color(1.0, 0.82, 0.3)
const CYAN := Color(0.35, 0.75, 1.0)
const MECH_FRAMES := preload("res://assets/sprites/gundam_frames.tres")

var _scrap_label: Label
var _scroll: ScrollContainer
var _column: VBoxContainer
var _chassis_grid: GridContainer
var _upgrade_grid: GridContainer
var _chassis_btns := {}
var _upgrade_rows := {}
var _back: TitleButton
var _flash := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.04, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(center)
	_column = VBoxContainer.new()
	_column.add_theme_constant_override("separation", 10)
	center.add_child(_column)

	var head := HBoxContainer.new()
	_column.add_child(head)
	var title := _label("HANGAR", 40, Color.WHITE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_scrap_label = _label("", 24, GOLD)
	head.add_child(_scrap_label)
	var sub := _label("Earn SCRAP in every run (more on harder difficulties). Spend it here on new mech frames and permanent upgrades.",
		15, Color(0.7, 0.85, 1.0, 0.85))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(sub)

	_column.add_child(_heading("MECH CHASSIS"))
	_chassis_grid = GridContainer.new()
	_chassis_grid.add_theme_constant_override("h_separation", 12)
	_chassis_grid.add_theme_constant_override("v_separation", 12)
	_column.add_child(_chassis_grid)
	for c in Game.CHASSIS:
		var card := ChassisCard.new(c)
		card.pressed.connect(_on_chassis.bind(c["id"]))
		_chassis_grid.add_child(card)
		_chassis_btns[c["id"]] = card

	_column.add_child(_heading("PERMANENT UPGRADES"))
	_upgrade_grid = GridContainer.new()
	_upgrade_grid.add_theme_constant_override("h_separation", 12)
	_upgrade_grid.add_theme_constant_override("v_separation", 10)
	_column.add_child(_upgrade_grid)
	for id: StringName in Game.HANGAR:
		var row := UpgradeRow.new(id)
		row.buy.pressed.connect(_on_buy.bind(id))
		_upgrade_grid.add_child(row)
		_upgrade_rows[id] = row

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_column.add_child(gap)
	_back = TitleButton.new("Back", Vector2(320, 50))
	_back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back.pressed.connect(func() -> void: back_pressed.emit())
	_column.add_child(_back)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	_column.add_child(pad)

	get_viewport().size_changed.connect(_relayout, CONNECT_DEFERRED)
	Layout.changed.connect(func(_p: bool) -> void: _relayout())
	_relayout()
	refresh()


## Column width follows the screen: 3 chassis across and 2 upgrade columns in landscape, 1 upgrade column
## (chassis still 3 across, narrower) in portrait.
func _relayout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var w := minf(vp.x - 40.0, 1100.0)
	_column.custom_minimum_size = Vector2(w, 0)
	_chassis_grid.columns = 3
	var cw := (w - 24.0) / 3.0
	var ch := 0.0
	for card: ChassisCard in _chassis_btns.values():
		ch = maxf(ch, card.needed_height(cw))
	for card: ChassisCard in _chassis_btns.values():
		card.custom_minimum_size = Vector2(cw, ch)
	_upgrade_grid.columns = 1 if vp.x < 900.0 else 2
	var uw := w if _upgrade_grid.columns == 1 else (w - 12.0) / 2.0
	for row: UpgradeRow in _upgrade_rows.values():
		row.custom_minimum_size = Vector2(uw, 74)
	# (the centring container spans the scroll area's width)
	_scroll.get_child(0).custom_minimum_size = Vector2(vp.x, 0)


func refresh() -> void:
	_scrap_label.text = "%d SCRAP" % Game.scrap
	for id in _chassis_btns:
		_chassis_btns[id].refresh()
	for id in _upgrade_rows:
		_upgrade_rows[id].refresh()


## Focus the selected chassis (menu opens the page).
func focus_default() -> void:
	(_chassis_btns.get(Game.chassis, _back) as Control).grab_focus()
	_scroll.scroll_vertical = 0


func _on_chassis(id: StringName) -> void:
	if Game.chassis == id:
		return
	var owned := Game.owns_chassis(id)
	if Game.pick_chassis(id):
		Sfx.play(&"levelup" if not owned else &"select", -6.0, 0.0)
	else:
		Sfx.play(&"select", -14.0, 0.0)
		_scrap_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
		create_tween().tween_callback(func() -> void: _scrap_label.add_theme_color_override("font_color", GOLD)).set_delay(0.4)
	refresh()


func _on_buy(id: StringName) -> void:
	if Game.buy_hangar(id):
		Sfx.play(&"levelup", -6.0, 0.0)
	else:
		Sfx.play(&"select", -14.0, 0.0)
	refresh()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _heading(text: String) -> Label:
	var l := _label(text, 18, CYAN)
	l.add_theme_constant_override("outline_size", 4)
	return l


static func _box(bg: Color, border: Color, width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	return s


## A chassis as a big button: the mech art (cropped to the sprite, lit, on a glow pad in the frame's
## colour; the biggest frame fills PREVIEW_H and the others keep their real relative size), name, stats,
## ability, description and the SELECT / SELECTED / BUY line.
class ChassisCard:
	extends Button
	const PREVIEW_H := 176.0
	var info: Dictionary
	var _tex: Texture2D
	## The opaque part of the sprite frame (the frame itself has a lot of empty margin).
	var _used: Rect2

	func _init(c: Dictionary) -> void:
		info = c
		focus_mode = Control.FOCUS_ALL
		text = ""
		_tex = HangarPage.MECH_FRAMES.get_frame_texture(&"idle", 0)
		_used = Rect2(Vector2.ZERO, _tex.get_size())
		var img := _tex.get_image()
		if img:
			var r := img.get_used_rect()
			if r.size.x > 0 and r.size.y > 0:
				_used = Rect2(r)
		var col: Color = c["color"]
		add_theme_stylebox_override("normal", HangarPage._box(Color(0.04, 0.07, 0.13, 0.95), Color(col, 0.35)))
		add_theme_stylebox_override("hover", HangarPage._box(Color(0.06, 0.1, 0.18, 0.95), Color(col, 0.8)))
		add_theme_stylebox_override("pressed", HangarPage._box(Color(0.08, 0.13, 0.22, 0.95), col))
		add_theme_stylebox_override("focus", HangarPage._box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.9), 2))
		mouse_entered.connect(grab_focus)

	func refresh() -> void:
		queue_redraw()

	func _draw() -> void:
		var col: Color = info["color"]
		var w := size.x
		var selected: bool = Game.chassis == info["id"]
		var owned := Game.owns_chassis(info["id"])
		var font := get_theme_default_font()
		if selected:
			draw_rect(Rect2(Vector2.ZERO, size), Color(col, 0.08))
			draw_rect(Rect2(Vector2.ZERO, size), Color(col, 0.9), false, 2.0)
		# Mech preview: a soft glow pad + floor ring in the frame's colour, then the lit sprite.
		var mh := minf((PREVIEW_H - 14.0) * float(info["scale"]) / _max_scale(), w - 30.0)
		var s := mh / _used.size.y
		var c := Vector2(w / 2.0, 12.0 + PREVIEW_H / 2.0)
		var pad := minf(PREVIEW_H * 0.5, w * 0.46)
		for i in 4:
			draw_circle(c, pad * (1.0 - i * 0.2), Color(col, 0.05 + 0.035 * i))
		draw_arc(c, pad * 0.98, 0.0, TAU, 48, Color(col, 0.35 if owned else 0.15), 2.0, true)
		var art := Rect2(c - _used.size * s / 2.0, _used.size * s)
		draw_texture_rect_region(_tex, art.grow(0), _used, Color(1.35, 1.35, 1.4) if owned else Color(0.5, 0.53, 0.6))
		var y := 12.0 + PREVIEW_H + 22.0
		draw_string(font, Vector2(10, y), String(info["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, w - 20, 18, col.lightened(0.2))
		y += 22.0
		var stats := "HP %d%%   SPEED %d%%   BOOST %s" % [roundi(float(info["hp"]) * 100.0), roundi(float(info["speed"]) * 100.0),
			"FAST" if float(info["boost_cd"]) < 1.0 else ("SLOW" if float(info["boost_cd"]) > 1.0 else "STD")]
		var fs := 12
		while fs > 8 and font.get_string_size(stats, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 16:
			fs -= 1
		draw_string(font, Vector2(8, y), stats, HORIZONTAL_ALIGNMENT_CENTER, w - 16, fs, Color(0.8, 0.88, 1.0))
		y += 8.0
		for line in _wrap(font, String(info["ability"]), w - 24.0, 13):
			y += 17.0
			draw_string(font, Vector2(12, y), line, HORIZONTAL_ALIGNMENT_CENTER, w - 24, 13, Color(1.0, 0.9, 0.6))
		for line in _wrap(font, String(info["desc"]), w - 24.0, 12):
			y += 16.0
			draw_string(font, Vector2(12, y), line, HORIZONTAL_ALIGNMENT_CENTER, w - 24, 12, Color(0.7, 0.78, 0.9))
		var foot := "SELECTED" if selected else ("SELECT" if owned else "BUY  %d SCRAP" % int(info["cost"]))
		var fcol := col if selected else (Color.WHITE if owned else (HangarPage.GOLD if Game.scrap >= int(info["cost"]) else Color(1, 0.45, 0.4)))
		draw_rect(Rect2(10, size.y - 38, w - 20, 28), Color(fcol, 0.14))
		draw_string(font, Vector2(10, size.y - 18), foot, HORIZONTAL_ALIGNMENT_CENTER, w - 20, 15, fcol)

	## Card height that fits this frame's text at card width `w` (the Hangar uses the tallest of the three).
	func needed_height(w: float) -> float:
		var font := get_theme_default_font()
		var lines := _wrap(font, String(info["ability"]), w - 24.0, 13).size() * 17.0 \
			+ _wrap(font, String(info["desc"]), w - 24.0, 12).size() * 16.0
		return 12.0 + PREVIEW_H + 22.0 + 30.0 + lines + 56.0

	static func _max_scale() -> float:
		var m := 1.0
		for ch: Dictionary in Game.CHASSIS:
			m = maxf(m, float(ch["scale"]))
		return m

	static func _wrap(font: Font, text: String, width: float, fs: int) -> PackedStringArray:
		var out := PackedStringArray()
		var line := ""
		for word in text.split(" "):
			var test := word if line == "" else line + " " + word
			if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = test
		if line != "":
			out.append(line)
		return out


## One permanent upgrade: name, what a level does, level pips, and the UPGRADE (cost) button.
class UpgradeRow:
	extends PanelContainer
	var id: StringName
	var buy: Button
	var _name: Label
	var _desc: Label
	var _pips: Label

	func _init(upgrade_id: StringName) -> void:
		id = upgrade_id
		add_theme_stylebox_override("panel", HangarPage._box(Color(0.04, 0.07, 0.13, 0.95), Color(0.3, 0.5, 0.75, 0.35)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		add_child(h)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		h.add_child(v)
		var info: Dictionary = Game.HANGAR[id]
		_name = Label.new()
		_name.text = String(info["name"])
		_name.add_theme_font_size_override("font_size", 17)
		v.add_child(_name)
		_desc = Label.new()
		_desc.text = String(info["desc"])
		_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc.add_theme_font_size_override("font_size", 12)
		_desc.add_theme_color_override("font_color", Color(0.7, 0.8, 0.92))
		v.add_child(_desc)
		_pips = Label.new()
		_pips.add_theme_font_size_override("font_size", 13)
		_pips.add_theme_color_override("font_color", HangarPage.GOLD)
		v.add_child(_pips)
		buy = Button.new()
		buy.custom_minimum_size = Vector2(150, 44)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.focus_mode = Control.FOCUS_ALL
		buy.add_theme_font_size_override("font_size", 14)
		buy.add_theme_stylebox_override("normal", HangarPage._box(Color(0.1, 0.3, 0.6, 0.9), Color(0.45, 0.75, 1.0)))
		buy.add_theme_stylebox_override("hover", HangarPage._box(Color(0.14, 0.38, 0.72, 0.95), Color(0.6, 0.9, 1.0)))
		buy.add_theme_stylebox_override("pressed", HangarPage._box(Color(0.2, 0.45, 0.8, 1.0), Color.WHITE))
		buy.add_theme_stylebox_override("focus", HangarPage._box(Color(0, 0, 0, 0), Color.WHITE, 2))
		buy.add_theme_stylebox_override("disabled", HangarPage._box(Color(0.06, 0.08, 0.12, 0.9), Color(0.3, 0.35, 0.45, 0.5)))
		buy.mouse_entered.connect(buy.grab_focus)
		h.add_child(buy)

	func refresh() -> void:
		var info: Dictionary = Game.HANGAR[id]
		var lv := Game.hangar_level(id)
		var mx := int(info["max"])
		_pips.text = "■ ".repeat(lv) + "□ ".repeat(mx - lv) + "  LV %d / %d" % [lv, mx]
		var cost := Game.hangar_cost(id)
		if cost < 0:
			buy.text = "MAXED"
			buy.disabled = true
		else:
			buy.text = "UPGRADE  %d" % cost
			buy.disabled = false
			buy.add_theme_color_override("font_color", Color.WHITE if Game.scrap >= cost else Color(1, 0.55, 0.5))
