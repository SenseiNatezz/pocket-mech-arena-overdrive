class_name ArmoryPage
extends Control
## Main menu ARMORY: every primary weapon in the game as a card (Higgsfield weapon art) in a 7-column grid
## (5 columns, detail panel below, when the screen is portrait - see _relayout()),
## plus a detail panel with the selected weapon displayed on a rack, its type, description, stat bars
## (damage / speed / range) and unlock progress. Weapons unlock by beating waves (Game.waves_beaten);
## pressing an unlocked card equips it. Works with mouse, touch and keyboard/gamepad focus.
## WEAPON MASTERY (Game.mastery_*): every unlocked card shows its mastery as ten gold pips + "MASTERY n"
## (a MASTERED weapon gets a gold frame and star), and the detail panel adds the level, its damage bonus,
## the progress to the next level and the next perk. The ARMORY MASTERY POOL strip (PoolBar; under the grid,
## or under the title in portrait) shows the shared pool every weapon's mastery fills, and its checkpoints.
## START MODE (`start_mode = true` before adding it): the loadout screen before every New Game / Endless
## run - pick a starting weapon, then START MISSION (or press the chosen card again) emits start_pressed.
## It also holds the THREAT picker (ThreatBar: Extreme only; a one-line hint on the other difficulties).
## THREAT TIERS: a weapon that has won at a THREAT tier shows "THREAT n" (its best) on its card.

signal back_pressed
signal start_pressed

const CYAN := Color(0.35, 0.75, 1.0)
const GOLD := Color(1.0, 0.82, 0.3)
## Boss of each Game.ARENAS level (same order; for "or defeat VULCAN" on boss-unlock weapon cards).
const ARENA_BOSSES: Array[String] = ["WARDEN", "RONIN", "SERAPH", "WARDEN MK-II", "SHOGUN", "VULCAN", "SCARAB", "ZENITH"]
## Landscape: cards per row and their width (7 x 106 px fits 13+ weapons in two rows beside the panel).
const COLS := 7
const CARD_W := 106.0
## Portrait: card width.
const PORTRAIT_CARD_W := 126.0
## Portrait (phones held upright): cards per row.
const PORTRAIT_COLS := 5
const MASTERY_PIPS := preload("res://ui/mastery_pips.gd")

var _cards: Array[Card] = []
var _title: Label
var _sub: Label
var _grid: GridContainer
var _back: TitleButton
var _portrait := false
var _detail: Control
var _desc: Label
var _selected := &"blaster"
var _equip_btn: TitleButton
var _counter: Label
var start_mode := false
var _threat: ThreatBar
## ARMORY MASTERY POOL strip (the Armory, not the Loadout) - it takes the THREAT picker's spot.
var _pool: PoolBar
const THREAT_BAR_H := 56.0
const THREAT_BAR_H_PORTRAIT := 42.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.04, 0.93)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	_title = _label("LOADOUT" if start_mode else "ARMORY", 40, Color.WHITE)
	add_child(_title)
	_sub = _label("Pick the weapon you start this mission with, then press START MISSION." if start_mode
		else "Beat waves to unlock weapons; kills with a weapon raise its MASTERY. Press a weapon to equip it.", 15,
		Color(0.7, 0.85, 1.0, 0.85))
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_sub)
	_counter = _label("", 20, GOLD)
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_counter)

	_grid = GridContainer.new()
	_grid.add_theme_constant_override("v_separation", 14)
	add_child(_grid)
	for w in Game.WEAPONS:
		var c := Card.new(w)
		c.pressed.connect(_on_card_pressed.bind(c.id))
		c.focus_entered.connect(_select.bind(c.id))
		_grid.add_child(c)
		_cards.append(c)

	# Detail panel (right in landscape, below the grid in portrait).
	_detail = Control.new()
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail.draw.connect(_draw_detail)
	add_child(_detail)
	_desc = _label("", 15, Color(0.8, 0.9, 1.0))
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(_desc)
	_equip_btn = TitleButton.new("Equip", Vector2(320, 48))
	_equip_btn.pressed.connect(func() -> void:
		if start_mode and Game.is_unlocked(_selected):
			Game.equip(_selected)
			start_pressed.emit()
		else:
			_on_card_pressed(_selected))
	add_child(_equip_btn)
	_back = TitleButton.new("Back", Vector2(320, 48))
	_back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(_back)
	if start_mode:
		_threat = ThreatBar.new(self)
		add_child(_threat)
	else:
		_pool = PoolBar.new()
		add_child(_pool)
	# Phones can rotate: re-lay out for portrait / landscape.
	get_viewport().size_changed.connect(_relayout, CONNECT_DEFERRED)
	var layout := get_node_or_null("/root/Layout")
	if layout:
		layout.changed.connect(func(_p: bool) -> void: _relayout())
	_relayout()
	refresh()


## Landscape (1280 wide): 7-column grid, tall detail panel on the right, buttons under it.
## Portrait (720 wide): 5-column grid, a wide two-column detail panel below it, buttons side by side at
## the bottom.
func _relayout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_portrait = vp.x < vp.y
	if _portrait:
		var w := vp.x - 48.0
		_title.position = Vector2(24, 18)
		_counter.add_theme_font_size_override("font_size", 17)
		_counter.position = Vector2(24, 30)
		_counter.size = Vector2(w, 30)
		_sub.add_theme_font_size_override("font_size", 14)
		_sub.position = Vector2(26, 72)
		_sub.size = Vector2(w - 4, 36)
		_grid.columns = PORTRAIT_COLS
		_set_card_width(PORTRAIT_CARD_W)
		_grid.add_theme_constant_override("h_separation", 10)
		_grid.reset_size()
		var gw := PORTRAIT_COLS * 126.0 + (PORTRAIT_COLS - 1) * 10.0
		_grid.position = Vector2(roundf((vp.x - gw) / 2), 112)
		var top := _grid.position.y + _grid.get_combined_minimum_size().y + 18.0
		var bw := (w - 12.0) / 2
		_equip_btn.custom_minimum_size = Vector2(bw, 52)
		_back.custom_minimum_size = Vector2(bw, 52)
		_equip_btn.reset_size()
		_back.reset_size()
		_equip_btn.position = Vector2(24, vp.y - 72)
		_back.position = Vector2(24 + bw + 12, vp.y - 72)
		# (Loadout: the THREAT picker / Armory: the MASTERY POOL strip takes the instruction line's place under
		# the title - the space between the grid and the buttons is all the detail panel's)
		var strip: Control = _threat if _threat else _pool
		if strip:
			_sub.visible = false
			strip.position = Vector2(24, 66)
			strip.size = Vector2(w, THREAT_BAR_H_PORTRAIT)
		# The panel hugs its content (~280 px) and sits centred in the space between grid and buttons.
		var room := maxf(vp.y - 86 - top, 256)
		var dh := minf(room, 284.0)
		_detail.position = Vector2(24, roundf(top + (room - dh) / 2))
		_detail.size = Vector2(w, dh)
		var oy := maxf(0.0, (_detail.size.y - 256) / 2)
		_desc.add_theme_font_size_override("font_size", 14)
		_desc.position = Vector2(336, 14 + oy)
		_desc.size = Vector2(w - 352, 118)
	else:
		_title.position = Vector2(48, 22)
		_counter.add_theme_font_size_override("font_size", 20)
		_counter.position = Vector2(300, 38)
		_counter.size = Vector2(566, 30)
		_sub.add_theme_font_size_override("font_size", 15)
		_sub.position = Vector2(52, 74)
		_sub.size = Vector2(800, 24)
		_grid.columns = COLS
		_set_card_width(CARD_W)
		_grid.add_theme_constant_override("h_separation", 12)
		_grid.position = Vector2(48, 112)
		_detail.position = Vector2(880, 24)
		_detail.size = Vector2(360, 672)
		_desc.add_theme_font_size_override("font_size", 15)
		_place_desc()
		for b in [_equip_btn, _back]:
			b.custom_minimum_size = Vector2(320, 48)
			b.reset_size()
		_equip_btn.position = Vector2(900, 580)
		_back.position = Vector2(900, 638)
		# (Loadout: the THREAT picker / Armory: the MASTERY POOL strip, under the weapon grid)
		var strip: Control = _threat if _threat else _pool
		if strip:
			_sub.visible = true
			strip.position = Vector2(48, 654)
			strip.size = Vector2(816, THREAT_BAR_H)
	_detail.queue_redraw()
	if _threat:
		_threat.queue_redraw()
	if _pool:
		_pool.queue_redraw()


func _set_card_width(w: float) -> void:
	for c in _cards:
		c.custom_minimum_size = Vector2(w, 262)
		c.size = c.custom_minimum_size
	_grid.reset_size()


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
	_place_desc()
	if start_mode:
		_equip_btn.label_text = "START MISSION" if Game.is_unlocked(id) else "Locked"
	else:
		_equip_btn.label_text = "Equipped" if id == Game.weapon else ("Equip" if Game.is_unlocked(id) else "Locked")
	_equip_btn.queue_redraw()
	_detail.queue_redraw()
	if _threat:
		_threat.refresh()
	if _pool:
		_pool.queue_redraw()


## The weapon whose details are showing (the THREAT picker shows its bounty).
func selected_weapon() -> StringName:
	return _selected


## Landscape: an unlocked weapon's description sits under its mastery block (locked weapons have none).
func _place_desc() -> void:
	if _portrait:
		return
	var unlocked := Game.is_unlocked(_selected)
	_desc.position = Vector2(20, 330 if unlocked else 290)
	_desc.size = Vector2(320, 120 if unlocked else 140)


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
	if _portrait:
		_draw_detail_wide(d, w, unlocked, font)
		return
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
	# Weapon mastery (unlocked weapons; the description moves down under it, see _place_desc).
	if unlocked:
		_draw_mastery(d, font, 20.0, 288.0, d.size.x - 40.0, true)
	# Stat bars.
	var names := ["DAMAGE", "SPEED", "RANGE"]
	for i in 3:
		var y := (462.0 if unlocked else 440.0) + i * 32.0
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


## Portrait detail panel (wide and short): rack, name, type and unlock progress on the left; the
## description label (_desc) and stat bars on the right. Content is centred vertically in tall panels.
func _draw_detail_wide(d: Control, w: Dictionary, unlocked: bool, font: Font) -> void:
	var oy := maxf(0.0, (d.size.y - 256) / 2)
	var rack := Rect2(16, 14 + oy, 300, 150)
	d.draw_rect(rack, Color(0.04, 0.1, 0.2, 0.9))
	for i in 5:
		d.draw_line(Vector2(rack.position.x, rack.end.y - 16 - i * 3), Vector2(rack.end.x, rack.end.y - 16 - i * 3),
			Color(CYAN, 0.05 + 0.03 * i), 1.0)
	d.draw_circle(rack.get_center(), 70.0, Color(CYAN, 0.06))
	var tex: Texture2D = load("res://assets/hq/weapons/%s.png" % w["icon"])
	var ts := tex.get_size()
	var k := minf((rack.size.x - 30) / ts.y, (rack.size.y - 24) / ts.x)
	d.draw_set_transform(rack.get_center(), PI / 2, Vector2(k, k))
	d.draw_texture(tex, -ts / 2, Color.WHITE if unlocked else Color(0.1, 0.12, 0.16))
	d.draw_set_transform(Vector2.ZERO)
	if not unlocked:
		_draw_lock(d, rack.get_center(), 1.2)
	d.draw_string(font, Vector2(18, 192 + oy), String(w["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 300, 21,
		Color.WHITE)
	var kind := "MELEE" if w.get("melee", false) else "RANGED"
	d.draw_string(font, Vector2(18, 214 + oy), kind + ("   //   EQUIPPED" if _selected == Game.weapon else ""),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GOLD if _selected == Game.weapon else CYAN)
	var need := int(w["waves"])
	if not unlocked and need > 0:
		var f := clampf(Game.waves_beaten / float(need), 0.0, 1.0)
		d.draw_rect(Rect2(18, 228 + oy, 296, 8), Color(0.15, 0.2, 0.3, 0.8))
		d.draw_rect(Rect2(18, 228 + oy, 296 * f, 8), GOLD)
	if unlocked:
		_draw_mastery(d, font, 18.0, 236.0 + oy, 296.0, false)
	var names := ["DAMAGE", "SPEED", "RANGE"]
	for i in 3:
		var y := 148.0 + oy + i * 30.0
		d.draw_string(font, Vector2(336, y + 12), names[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.85, 1.0))
		for s in 5:
			var on: bool = s < int(w["stats"][i])
			d.draw_rect(Rect2(420 + s * 44, y, 38, 13), Color(CYAN, 0.9) if on else Color(0.15, 0.2, 0.3, 0.7))


## Detail panel mastery block for the selected weapon: "MASTERY 3 / 10" (or MASTERED) with its damage bonus
## on the right, the ten pips under it (title baseline at `y`), and - `perk_line` - the progress to the
## next level and the next perk.
func _draw_mastery(d: Control, font: Font, x: float, y: float, w: float, perk_line: bool) -> void:
	var ml := Game.mastery_level(_selected)
	var mastered := Game.is_mastered(_selected)
	if mastered:
		MASTERY_PIPS.draw_star(d, Vector2(x + 7, y - 6), 7.0, GOLD)
	d.draw_string(font, Vector2(x + (18.0 if mastered else 0.0), y), "MASTERED" if mastered
		else "MASTERY %d / %d" % [ml, Game.MASTERY_MAX], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)
	d.draw_string(font, Vector2(x, y), "+%d%% DAMAGE" % roundi(Game.MASTERY_DAMAGE * ml * 100.0), HORIZONTAL_ALIGNMENT_RIGHT,
		w, 13, Color(1.0, 0.9, 0.6) if ml > 0 else Color(0.6, 0.66, 0.78))
	MASTERY_PIPS.draw_pips(d, Rect2(x, y + 7.0, w, 8.0), ml, Game.mastery_fraction(_selected))
	if not perk_line:
		return
	var txt := "Every perk earned: +20% damage, FINISHER, gold badge"
	if not mastered:
		var p := Game.mastery_progress(_selected)
		# (the Mastery Pool's last checkpoint gives every weapon FINISHER early)
		txt = "%d / %d to LV %d  -  %s" % [p.x, p.y, ml + 1, "FINISHER at LV %d" % Game.MASTERY_FINISHER_LEVEL
			if ml < Game.MASTERY_FINISHER_LEVEL and not Game.pool_reached(3) else "MASTERED at LV %d" % Game.MASTERY_MAX]
	d.draw_string(font, Vector2(x, y + 33.0), txt, HORIZONTAL_ALIGNMENT_LEFT, w, 12, Color(0.9, 0.86, 0.7))


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
		draw_circle(art.get_center(), minf(56.0, size.x / 2.0 - 6.0), Color(edge, 0.07 + 0.08 * _hl))
		var ts := tex.get_size()
		var k := minf(art.size.x / ts.x, art.size.y / ts.y)
		var dst := Rect2(art.get_center() - ts * k / 2, ts * k)
		draw_texture_rect(tex, dst, false, Color.WHITE if unlocked else Color(0.09, 0.1, 0.14))
		var font := get_theme_default_font()
		var kind := "MELEE" if info.get("melee", false) else "RANGED"
		# (narrow cards: the equipped one says just EQUIPPED, there's no room for both)
		if not (equipped and size.x < 120.0):
			draw_string(font, Vector2(10, 18), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(edge, 0.9))
		if equipped:
			draw_string(font, Vector2(0, 18), "EQUIPPED", HORIZONTAL_ALIGNMENT_CENTER if size.x < 120.0 else HORIZONTAL_ALIGNMENT_RIGHT,
				size.x if size.x < 120.0 else size.x - 10, 11, GOLD)
		# THREAT TIERS: the highest tier this weapon has won at.
		var tb := Game.weapon_threat_best(id)
		if unlocked and tb > 0:
			draw_string(font, Vector2(0, 33 if equipped or size.x < 120.0 else 18), "THREAT %d" % tb, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 10, 10,
				Game.THREAT_COLOR)
		if not unlocked:
			ArmoryPage._draw_lock(self, art.get_center())
		# Name (+ progress when locked).
		var name_col := Color.WHITE.lerp(Color(0.8, 0.88, 1.0), 1.0 - _hl) if unlocked else Color(0.6, 0.65, 0.75)
		var name_size := 14 if String(info["name"]).length() <= 13 else 12
		if size.x < 120.0 and String(info["name"]).length() > 15:
			name_size = 11 if String(info["name"]).length() <= 17 else 10
		draw_string(font, Vector2(0, 224), info["name"], HORIZONTAL_ALIGNMENT_CENTER, size.x, name_size, name_col)
		# Weapon mastery: ten pips (gold = levels earned, the next one filling) and "MASTERY n"; a MASTERED
		# weapon gets a gold inner frame and a starred "MASTERED".
		if unlocked:
			var ml := Game.mastery_level(id)
			var mastered := Game.is_mastered(id)
			MASTERY_PIPS.draw_pips(self, Rect2(14, 233, size.x - 28, 6), ml, Game.mastery_fraction(id))
			var mtxt := "MASTERED" if mastered else "MASTERY %d" % ml
			draw_string(font, Vector2(0, 254), mtxt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 11,
				GOLD if mastered else Color(1.0, 0.86, 0.5, 0.9 if ml > 0 else 0.5))
			if mastered:
				draw_rect(r.grow(-4.0), Color(GOLD, 0.75), false, 1.5)
				var tw := font.get_string_size(mtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
				MASTERY_PIPS.draw_star(self, Vector2(size.x / 2.0 - tw / 2.0 - 9.0, 250.0), 5.0, GOLD)
		if not unlocked:
			var need := int(info["waves"])
			var f := clampf(Game.waves_beaten / float(need), 0.0, 1.0)
			# Boss-unlock weapons (beat_arena) also say which boss drops them, on a second line.
			var boss := ArmoryPage.ARENA_BOSSES[int(info["beat_arena"])] if info.has("beat_arena") else ""
			var by := 230.0 if boss != "" else 236.0
			draw_rect(Rect2(14, by, size.x - 28, 6), Color(0.15, 0.2, 0.3, 0.9))
			draw_rect(Rect2(14, by, (size.x - 28) * f, 6), GOLD)
			draw_string(font, Vector2(0, by + 18), "%d / %d waves" % [mini(Game.waves_beaten, need), need],
				HORIZONTAL_ALIGNMENT_CENTER, size.x, 11, Color(1.0, 0.8, 0.5))
			if boss != "":
				draw_string(font, Vector2(0, by + 30), "or defeat %s" % boss, HORIZONTAL_ALIGNMENT_CENTER, size.x, 10,
					Color(1.0, 0.62, 0.4))


## THREAT picker (Loadout screen; Game.THREAT_TIERS): "<  THREAT 3  >" with the newest condition, the scrap
## bonus and the selected weapon's one-time bounty at that tier. On Extreme before THREAT 1 is open it says
## how to open it; on the other difficulties it's a dim one-line hint. Arrows: mouse / touch / focus + accept.
class ThreatBar:
	extends Control
	var page: ArmoryPage
	var _left: Button
	var _right: Button
	const LABEL_W := 150.0

	func _init(p: ArmoryPage) -> void:
		page = p
		mouse_filter = Control.MOUSE_FILTER_PASS
		_left = _arrow(-1)
		_right = _arrow(1)
		resized.connect(_place)

	func _arrow(dir: int) -> Button:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_ALL
		b.custom_minimum_size = Vector2(40, 40)
		b.size = Vector2(40, 40)
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
		b.draw.connect(func() -> void:
			var can := Game.threat + dir >= 0 and Game.threat + dir <= Game.threat_unlocked
			var col := Game.THREAT_COLOR if can else Color(0.4, 0.3, 0.3)
			if b.has_focus() or b.is_hovered():
				b.draw_rect(Rect2(Vector2.ZERO, b.size), Color(col, 0.18))
				b.draw_rect(Rect2(Vector2.ZERO, b.size), Color(1, 1, 1, 0.8), false, 1.5)
			var c := b.size / 2.0
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(9 * dir, 0), c + Vector2(-7 * dir, -11),
				c + Vector2(-7 * dir, 11)]), col))
		b.focus_entered.connect(b.queue_redraw)
		b.focus_exited.connect(b.queue_redraw)
		b.mouse_entered.connect(b.grab_focus)
		b.pressed.connect(step.bind(dir))
		add_child(b)
		return b

	func _place() -> void:
		_left.position = Vector2(8, (size.y - 40.0) / 2.0)
		_right.position = Vector2(48 + LABEL_W, (size.y - 40.0) / 2.0)

	func active() -> bool:
		return Game.is_extreme() and Game.threat_unlocked > 0

	func refresh() -> void:
		_left.visible = active()
		_right.visible = active()
		queue_redraw()
		_left.queue_redraw()
		_right.queue_redraw()

	func step(dir: int) -> void:
		var t := clampi(Game.threat + dir, 0, Game.threat_unlocked)
		if t == Game.threat:
			Sfx.play(&"select", -14.0, 0.0)
			return
		Game.set_threat(t)
		Sfx.play(&"select", -6.0, 0.0)
		refresh()

	func _draw() -> void:
		var font := get_theme_default_font()
		var r := Rect2(Vector2.ZERO, size)
		var tc := Game.THREAT_COLOR
		# (portrait: a shorter bar, so the two text lines sit closer)
		var compact := size.y < 50.0
		var y1 := 18.0 if compact else 23.0
		var y2 := 35.0 if compact else 44.0
		if not Game.is_extreme():
			draw_rect(r, Color(0.05, 0.05, 0.08, 0.6))
			_fit(font, Vector2(14, size.y / 2.0 + 5.0), "THREAT TIERS: on EXTREME, win a run to open THREAT 1  (more scrap, weapon bounties)",
				size.x - 28.0, 13, Color(0.75, 0.6, 0.55, 0.85))
			return
		draw_rect(r, Color(0.13, 0.035, 0.02, 0.9))
		draw_rect(r, Color(tc, 0.75), false, 2.0)
		draw_rect(Rect2(0, 0, 4, size.y), tc)
		if Game.threat_unlocked <= 0:
			_fit(font, Vector2(16, y1), "THREAT TIERS LOCKED", size.x - 32.0, 15 if compact else 17, tc)
			_fit(font, Vector2(16, y2), "Win a run on Extreme (beat an arena's boss, or reach Endless wave %d) to open THREAT 1." %
				Game.THREAT_ENDLESS_WAVE, size.x - 32.0, 12 if compact else 13, Color(1.0, 0.85, 0.75))
			return
		var t := Game.threat
		var head := "THREAT %d" % t if t > 0 else "THREAT OFF"
		draw_string_outline(font, Vector2(48, size.y / 2.0 + 8.0), head, HORIZONTAL_ALIGNMENT_CENTER, LABEL_W, 22, 5, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(48, size.y / 2.0 + 8.0), head, HORIZONTAL_ALIGNMENT_CENTER, LABEL_W, 22,
			tc if t > 0 else Color(0.85, 0.7, 0.65))
		var x := 48.0 + LABEL_W + 52.0
		var w := size.x - x - 12.0
		var line1 := "Plain Extreme: no extra conditions."
		if t > 0:
			var tier: Dictionary = Game.THREAT_TIERS[t - 1]
			line1 = "%s: %s%s" % [tier["name"], tier["desc"], "   (+%d earlier)" % (t - 1) if t > 1 else ""]
		_fit(font, Vector2(x, y1), line1, w, 13 if compact else 14, Color(1.0, 0.86, 0.8))
		var wid := page.selected_weapon() if page else Game.weapon
		var wname := String(Game.weapon_info(wid)["name"]).to_upper()
		var parts: Array[String] = []
		if t > 0:
			parts.append("SCRAP +%d%%" % roundi(Game.THREAT_SCRAP * t * 100.0))
			parts.append(("%s BOUNTY CLAIMED" % wname) if Game.bounty_claimed(wid, t)
				else "%s BOUNTY +%s" % [wname, Game.fmt_int(Game.BOUNTY_SCRAP * t)])
		else:
			parts.append("Pick a THREAT for more scrap and weapon bounties")
		if t >= Game.threat_unlocked and t < Game.THREAT_MAX:
			parts.append("WIN TO OPEN THREAT %d" % (t + 1))
		_fit(font, Vector2(x, y2), "   -   ".join(parts), w, 12 if compact else 13, Color(1.0, 0.82, 0.3))

	## Draws `text` at `pos`, shrinking the font until it fits `w`.
	func _fit(font: Font, pos: Vector2, text: String, w: float, fs: int, col: Color) -> void:
		while fs > 9 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
			fs -= 1
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## ARMORY MASTERY POOL strip (the Armory page; Game.mastery_pool): "MASTERY POOL  7,420 / 20,000 (37%)", the
## next checkpoint's perk on the right, and a gold bar with the four checkpoints (diamonds, lit once
## reached; in landscape their perks sit under them).
class PoolBar:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var font := get_theme_default_font()
		var g := ArmoryPage.GOLD
		var compact := size.y < 50.0
		var frac := Game.pool_fraction()
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.075, 0.06, 0.025, 0.9))
		draw_rect(Rect2(Vector2.ZERO, size), Color(g, 0.7), false, 2.0)
		draw_rect(Rect2(0, 0, 4, size.y), g)
		# Title + amount on the left, the next checkpoint on the right.
		var y1 := 17.0 if compact else 20.0
		var head := "MASTERY POOL"
		var hfs := 14 if compact else 15
		draw_string(font, Vector2(14, y1), head, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs, g)
		var x := 14.0 + font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, hfs).x + 12.0
		var amt := "%s / %s  (%d%%)" % [Game.fmt_int(Game.mastery_pool), Game.fmt_int(Game.POOL_MAX), floori(frac * 100.0)]
		var afs := 12 if compact else 13
		draw_string(font, Vector2(x, y1), amt, HORIZONTAL_ALIGNMENT_LEFT, -1, afs, Color(1.0, 0.92, 0.7))
		x += font.get_string_size(amt, HORIZONTAL_ALIGNMENT_LEFT, -1, afs).x + 16.0
		var n := Game.pool_checkpoints_reached()
		var nxt := "EVERY CHECKPOINT REACHED"
		if n < Game.POOL_CHECKPOINTS.size():
			var c: Dictionary = Game.POOL_CHECKPOINTS[n]
			nxt = "NEXT AT %d%%: %s" % [roundi(float(c["at"]) * 100.0), c["short"]]
		var nfs := afs
		while nfs > 9 and font.get_string_size(nxt, HORIZONTAL_ALIGNMENT_LEFT, -1, nfs).x > size.x - 14.0 - x:
			nfs -= 1
		draw_string(font, Vector2(x, y1), nxt, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 14.0 - x, nfs, Color(1.0, 0.85, 0.45))
		# The bar, with a diamond per checkpoint.
		var bx := 14.0
		var bw := size.x - 28.0
		var by := y1 + 7.0 if compact else 27.0
		var bh := 8.0
		draw_rect(Rect2(bx, by, bw, bh), Color(0.18, 0.14, 0.06, 0.95))
		if frac > 0.0:
			draw_rect(Rect2(bx, by, bw * frac, bh), g)
			draw_rect(Rect2(bx, by, bw * frac, 2.0), Color(1, 1, 1, 0.3))
		for i in Game.POOL_CHECKPOINTS.size():
			var cp: Dictionary = Game.POOL_CHECKPOINTS[i]
			var on := Game.pool_reached(i)
			var c := Vector2(bx + bw * float(cp["at"]), by + bh / 2.0)
			var d := PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)])
			draw_colored_polygon(d, g.lightened(0.35) if on else Color(0.3, 0.26, 0.18))
			var ring := d.duplicate()
			ring.append(d[0])
			draw_polyline(ring, Color(0.15, 0.1, 0.02) if on else Color(g, 0.6), 1.5, true)
			if not compact:
				var label := String(cp["short"])
				var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
				var lx := clampf(c.x - lw / 2.0, bx, bx + bw - lw)
				draw_string(font, Vector2(lx, by + bh + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
					g if on else Color(0.75, 0.68, 0.5, 0.75))
