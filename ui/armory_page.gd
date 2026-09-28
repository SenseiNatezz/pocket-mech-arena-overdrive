class_name ArmoryPage
extends Control
## Main menu ARMORY: every primary weapon in the game as a card (Higgsfield weapon art) in a 6-column grid,
## plus a detail panel with the selected weapon displayed on a rack, its type, description, stat bars
## (damage / speed / range) and unlock progress. Weapons unlock by beating waves (Game.waves_beaten);
## pressing an unlocked card equips it. Works with mouse, touch and keyboard/gamepad focus.
## START MODE (`start_mode = true` before adding it): the loadout screen before every New Game / Endless
## run - pick a starting weapon, then START MISSION (or press the chosen card again) emits start_pressed.

signal back_pressed
signal start_pressed

const CYAN := Color(0.35, 0.75, 1.0)
const GOLD := Color(1.0, 0.82, 0.3)
const COLS := 6

var _cards: Array[Card] = []
var _detail: Control
var _desc: Label
var _selected := &"blaster"
var _equip_btn: TitleButton
var _counter: Label
var start_mode := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.04, 0.93)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var title := _label("LOADOUT" if start_mode else "ARMORY", 40, Color.WHITE)
	title.position = Vector2(48, 22)
	add_child(title)
	var sub := _label("Pick the weapon you start this mission with, then press START MISSION." if start_mode
		else "Beat waves in any mode to unlock new weapons. Press a weapon to equip it.", 15, Color(0.7, 0.85, 1.0, 0.85))
	sub.position = Vector2(52, 74)
	add_child(sub)
	_counter = _label("", 20, GOLD)
	_counter.position = Vector2(300, 38)
	_counter.size = Vector2(566, 30)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_counter)

	var grid := GridContainer.new()
	grid.columns = COLS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 14)
	grid.position = Vector2(48, 112)
	add_child(grid)
	for w in Game.WEAPONS:
		var c := Card.new(w)
		c.pressed.connect(_on_card_pressed.bind(c.id))
		c.focus_entered.connect(_select.bind(c.id))
		grid.add_child(c)
		_cards.append(c)

	# Detail panel (right).
	_detail = Control.new()
	_detail.position = Vector2(880, 24)
	_detail.size = Vector2(360, 672)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.draw.connect(_draw_detail)
	add_child(_detail)
	_desc = _label("", 15, Color(0.8, 0.9, 1.0))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.position = Vector2(20, 290)
	_desc.size = Vector2(320, 140)
	_detail.add_child(_desc)
	_equip_btn = TitleButton.new("Equip", Vector2(320, 48))
	_equip_btn.position = Vector2(900, 580)
	_equip_btn.pressed.connect(func() -> void:
		if start_mode and Game.is_unlocked(_selected):
			Game.equip(_selected)
			start_pressed.emit()
		else:
			_on_card_pressed(_selected))
	add_child(_equip_btn)
	var back := TitleButton.new("Back", Vector2(320, 48))
	back.position = Vector2(900, 638)
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)
	refresh()


func _label(txt: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0.02, 0.08, 0.9))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Focus the equipped weapon's card (called when the page opens).
func focus_equipped() -> void:
	refresh()
	for c in _cards:
		if c.id == Game.weapon:
			c.grab_focus()
	_select(Game.weapon)


func refresh() -> void:
	var total := Game.WEAPONS.size()
	var have := 0
	for w in Game.WEAPONS:
		if Game.is_unlocked(w["id"]):
			have += 1
	_counter.text = "WAVES BEATEN: %d     %d / %d UNLOCKED" % [Game.waves_beaten, have, total]
	for c in _cards:
		c.queue_redraw()
	_select(_selected)


func _select(id: StringName) -> void:
	_selected = id
	var w := Game.weapon_info(id)
	var status := ""
	if id == Game.weapon:
		status = ""
	elif Game.is_unlocked(id):
		status = "Ready to equip"
	else:
		status = "LOCKED  -  " + Game.unlock_text(id)
	_desc.text = "%s\n\n%s" % [w["desc"], status]
	_desc.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0) if Game.is_unlocked(id) else Color(1.0, 0.75, 0.55))
	if start_mode:
		_equip_btn.label_text = "START MISSION" if Game.is_unlocked(id) else "Locked"
	else:
		_equip_btn.label_text = "Equipped" if id == Game.weapon else ("Equip" if Game.is_unlocked(id) else "Locked")
	_equip_btn.queue_redraw()
	_detail.queue_redraw()


func _on_card_pressed(id: StringName) -> void:
	# Start mode: pressing the weapon that's already chosen starts the mission (keyboard / gamepad flow).
	if start_mode and id == Game.weapon and Game.is_unlocked(id):
		start_pressed.emit()
		return
	_select(id)
	if not Game.is_unlocked(id):
		Sfx.play(&"hurt", -14.0, 0.0)
		return
	Game.equip(id)
	Sfx.play(&"levelup", -10.0, 0.0)
	refresh()


func _draw_detail() -> void:
	var d := _detail
	var w := Game.weapon_info(_selected)
	var unlocked := Game.is_unlocked(_selected)
	var font := d.get_theme_default_font()
	# Panel.
	d.draw_rect(Rect2(Vector2.ZERO, d.size), Color(0.02, 0.05, 0.12, 0.85))
	d.draw_rect(Rect2(Vector2.ZERO, d.size), Color(CYAN, 0.6), false, 2.0)
	# Weapon on a lit display rack (art turned to lie horizontally).
	var rack := Rect2(16, 16, d.size.x - 32, 180)
	d.draw_rect(rack, Color(0.04, 0.1, 0.2, 0.9))
	for i in 5:
		d.draw_line(Vector2(rack.position.x, rack.end.y - 20 - i * 3), Vector2(rack.end.x, rack.end.y - 20 - i * 3),
			Color(CYAN, 0.05 + 0.03 * i), 1.0)
	d.draw_circle(rack.get_center(), 90.0, Color(CYAN, 0.06))
	var tex: Texture2D = load("res://assets/hq/weapons/%s.png" % w["icon"])
	var ts := tex.get_size()
	var k := minf((rack.size.x - 30) / ts.y, (rack.size.y - 30) / ts.x)
	d.draw_set_transform(rack.get_center(), PI / 2, Vector2(k, k))
	d.draw_texture(tex, -ts / 2, Color.WHITE if unlocked else Color(0.1, 0.12, 0.16))
	d.draw_set_transform(Vector2.ZERO)
	if not unlocked:
		_draw_lock(d, rack.get_center(), 1.4)
	# Name + type.
	d.draw_string(font, Vector2(20, 236), String(w["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	var kind := "MELEE" if w.get("melee", false) else "RANGED"
	d.draw_string(font, Vector2(20, 262), kind + ("   //   EQUIPPED" if _selected == Game.weapon else ""),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, GOLD if _selected == Game.weapon else CYAN)
	# Stat bars.
	var names := ["DAMAGE", "SPEED", "RANGE"]
	for i in 3:
		var y := 440.0 + i * 32.0
		d.draw_string(font, Vector2(20, y + 13), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.85, 1.0))
		for s in 5:
			var r := Rect2(110 + s * 46, y, 40, 14)
			var on: bool = s < int(w["stats"][i])
			d.draw_rect(r, Color(CYAN, 0.9) if on else Color(0.15, 0.2, 0.3, 0.7))
	# Unlock progress.
	var need := int(w["waves"])
	if not unlocked and need > 0:
		var f := clampf(Game.waves_beaten / float(need), 0.0, 1.0)
		d.draw_rect(Rect2(20, 540, 320, 10), Color(0.15, 0.2, 0.3, 0.8))
		d.draw_rect(Rect2(20, 540, 320 * f, 10), GOLD)


static func _draw_lock(ci: CanvasItem, c: Vector2, s := 1.0) -> void:
	ci.draw_arc(c + Vector2(0, -10) * s, 13.0 * s, PI, TAU, 16, Color(0.85, 0.9, 1.0, 0.9), 4.0 * s, true)
	ci.draw_rect(Rect2(c + Vector2(-18, -10) * s, Vector2(36, 28) * s), Color(0.85, 0.9, 1.0, 0.9))
	ci.draw_circle(c + Vector2(0, 3) * s, 4.0 * s, Color(0.05, 0.08, 0.14))


## One weapon card in the grid.
class Card extends Button:
	var id := &""
	var info: Dictionary
	var tex: Texture2D
	var _hl := 0.0

	func _init(w: Dictionary) -> void:
		info = w
		id = w["id"]
		tex = load("res://assets/hq/weapons/%s.png" % w["icon"])
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = Vector2(126, 262)
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
		var unlocked := Game.is_unlocked(id)
		var equipped := id == Game.weapon
		var r := Rect2(Vector2.ZERO, size)
		var edge := GOLD if equipped else (CYAN if unlocked else Color(0.45, 0.5, 0.6))
		if _hl > 0.0:
			draw_rect(r.grow(4.0 * _hl), Color(edge, 0.25 * _hl), false, 6.0)
		draw_rect(r, Color(0.02, 0.05, 0.12, 0.85).lerp(Color(0.05, 0.14, 0.3, 0.92), _hl))
		draw_rect(r, Color(edge, 0.55 + 0.45 * _hl), false, 2.0)
		# Art.
		var art := Rect2(10, 26, size.x - 20, 176)
		draw_circle(art.get_center(), 56.0, Color(edge, 0.07 + 0.08 * _hl))
		var ts := tex.get_size()
		var k := minf(art.size.x / ts.x, art.size.y / ts.y)
		var dst := Rect2(art.get_center() - ts * k / 2, ts * k)
		draw_texture_rect(tex, dst, false, Color.WHITE if unlocked else Color(0.09, 0.1, 0.14))
		var font := get_theme_default_font()
		var kind := "MELEE" if info.get("melee", false) else "RANGED"
		draw_string(font, Vector2(10, 18), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(edge, 0.9))
		if equipped:
			draw_string(font, Vector2(0, 18), "EQUIPPED", HORIZONTAL_ALIGNMENT_RIGHT, size.x - 10, 11, GOLD)
		if not unlocked:
			ArmoryPage._draw_lock(self, art.get_center())
		# Name (+ progress when locked).
		var name_col := Color.WHITE.lerp(Color(0.8, 0.88, 1.0), 1.0 - _hl) if unlocked else Color(0.6, 0.65, 0.75)
		var name_size := 14 if String(info["name"]).length() <= 13 else 12
		draw_string(font, Vector2(0, 224), info["name"], HORIZONTAL_ALIGNMENT_CENTER, size.x, name_size, name_col)
		if not unlocked:
			var need := int(info["waves"])
			var f := clampf(Game.waves_beaten / float(need), 0.0, 1.0)
			draw_rect(Rect2(14, 236, size.x - 28, 6), Color(0.15, 0.2, 0.3, 0.9))
			draw_rect(Rect2(14, 236, (size.x - 28) * f, 6), GOLD)
			draw_string(font, Vector2(0, 256), "%d / %d waves" % [mini(Game.waves_beaten, need), need],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(1.0, 0.8, 0.5))
