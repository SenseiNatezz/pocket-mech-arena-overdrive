class_name PartsPanel
extends VBoxContainer
## Hangar > PARTS tab (ui/hangar_page.gd): build the mech from autoload/parts.gd's parts, one row per slot.
##   header  "PARTS   5 / 16 OWNED" and a line on how it works
##   slots   "HEAD  -  SENSORS" with the part that's on it, then the slot's part cards: name, its state on the
##           right (EQUIPPED / EQUIP / a scrap price / LOCKED), a line of flavour, the perk in gold, and the stat
##           changes against the part that's on now (green = better, red = worse; the part that's on shows
##           what it changes from STOCK). A locked part names the contract that opens it.
## Pressing a card buys it and puts it on, or puts an owned part on. Cards are focusable buttons (mouse, touch,
## keyboard / gamepad); 4 across in landscape, 2 in portrait (set_layout).

## A part was bought or put on (the Hangar refreshes its scrap total).
signal changed

const GOLD := Color(1.0, 0.82, 0.3)
const CYAN := Color(0.35, 0.75, 1.0)
const GREEN := Color(0.45, 1.0, 0.6)
const RED := Color(1.0, 0.48, 0.42)
const CARD_H := 188.0

var _head: Label
var _headers: Array[SlotHeader] = []
var _grids: Array[GridContainer] = []
var _cards := {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_head = _label("", 20, Color.WHITE)
	add_child(_head)
	var sub := _label("Build your mech. Every part trades a strength for a weakness, and most add a perk. Buying a part puts it on; swap between the parts you own any time. Each slot starts with a free STOCK part.",
		14, Color(0.7, 0.85, 1.0, 0.85))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(sub)
	for slot in Parts.SLOTS:
		var header := SlotHeader.new(slot)
		add_child(header)
		_headers.append(header)
		var grid := GridContainer.new()
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		add_child(grid)
		_grids.append(grid)
		for id in Parts.slot_ids(slot):
			var card := PartCard.new(id)
			card.pressed.connect(_on_card.bind(id))
			grid.add_child(card)
			_cards[id] = card
	refresh()


## Column width + card columns (4 in landscape, 2 in portrait).
func set_layout(width: float, cols: int) -> void:
	var cw := (width - 10.0 * (cols - 1)) / cols
	for g in _grids:
		g.columns = cols
	for h in _headers:
		h.custom_minimum_size = Vector2(width, 34)
	for c: PartCard in _cards.values():
		c.custom_minimum_size = Vector2(cw, CARD_H)


func refresh() -> void:
	_head.text = "PARTS   %d / %d OWNED" % [Parts.owned_count(), Parts.LIST.size()]
	for h in _headers:
		h.queue_redraw()
	for c: PartCard in _cards.values():
		c.queue_redraw()


## The part that's on in the first slot (HEAD) - for focus when the tab opens.
func first_focus() -> Control:
	return _cards[Parts.equipped_id(Parts.SLOTS[0])]


func _on_card(id: StringName) -> void:
	var card: PartCard = _cards[id]
	if Parts.is_equipped(id):
		Sfx.play(&"select", -14.0, 0.0)
		return
	if Parts.owns(id):
		Parts.equip(id)
		Sfx.play(&"select", -5.0, 0.0)
		card.pop("EQUIPPED")
	elif Parts.buy(id):
		Sfx.play(&"coin", -3.0, 0.0)
		Sfx.play(&"levelup", -8.0, 0.0)
		card.pop("BOUGHT")
	else:
		Sfx.play(&"select", -14.0, 0.0)
		card.shake()
		return
	refresh()
	changed.emit()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## "HEAD  -  SENSORS" on the left, "ON: LONGSIGHT OPTICS" on the right, over a thin rule.
class SlotHeader:
	extends Control
	var slot: StringName

	func _init(s: StringName) -> void:
		slot = s
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 34)

	func _draw() -> void:
		var font := get_theme_default_font()
		var head := "%s  -  %s" % [Parts.SLOT_NAMES[slot], String(Parts.SLOT_ROLES[slot]).to_upper()]
		draw_string_outline(font, Vector2(0, 22), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, 22), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, PartsPanel.CYAN)
		var on: Dictionary = Parts.equipped_info(slot)
		var stock := Parts.equipped_id(slot) == Parts.stock_id(slot)
		draw_string(font, Vector2(0, 22), "ON:  " + String(on.get("name", "")).to_upper(), HORIZONTAL_ALIGNMENT_RIGHT, size.x, 13,
			Color(0.75, 0.85, 1.0, 0.8) if stock else PartsPanel.GREEN)
		draw_line(Vector2(0, 30), Vector2(size.x, 30), Color(PartsPanel.CYAN, 0.25), 1.0)


## One part as a focusable card (see the class doc above). pop() floats "BOUGHT" / "EQUIPPED" up from it;
## shake() wobbles it when the scrap isn't there or it's locked.
class PartCard:
	extends Button
	var id: StringName
	var _hl := 0.0
	var _pop := 0.0
	var _pop_text := ""
	var _shake := 0.0

	func _init(pid: StringName) -> void:
		id = pid
		text = ""
		flat = true
		focus_mode = Control.FOCUS_ALL
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(grab_focus)

	func pop(what: String) -> void:
		_pop = 1.0
		_pop_text = what

	func shake() -> void:
		_shake = 1.0

	func _process(delta: float) -> void:
		var target := 1.0 if has_focus() else 0.0
		var animating := _pop > 0.0 or _shake > 0.0 or not is_equal_approx(_hl, target)
		_hl = move_toward(_hl, target, delta * 7.0)
		_pop = move_toward(_pop, 0.0, delta * 1.3)
		_shake = move_toward(_shake, 0.0, delta * 3.5)
		if animating:
			queue_redraw()

	func _draw() -> void:
		var p := Parts.info(id)
		var font := get_theme_default_font()
		var on := Parts.is_equipped(id)
		var own := Parts.owns(id)
		var locked := not own and Parts.is_locked(id)
		var afford := not own and not locked and Game.scrap >= Parts.cost(id)
		if _shake > 0.0:
			draw_set_transform(Vector2(sin(_shake * 40.0) * 6.0 * _shake, 0))
		var r := Rect2(Vector2.ZERO, size)
		var edge := PartsPanel.GREEN if on else (PartsPanel.CYAN if own else (PartsPanel.GOLD if afford
			else Color(0.5, 0.55, 0.65)))
		var bg := Color(0.03, 0.08, 0.06, 0.94) if on else Color(0.04, 0.07, 0.13, 0.95)
		draw_rect(r, bg.lerp(Color(0.06, 0.13, 0.25, 0.95), _hl * 0.5))
		draw_rect(r, Color(edge, 0.4 + 0.5 * _hl), false, 2.0 if on or _hl > 0.5 else 1.0)
		draw_rect(Rect2(0, 0, 4, size.y), Color(edge, 0.9))
		# Name + state (EQUIPPED / EQUIP / price / LOCKED) on the right.
		var state := ""
		var state_col := edge
		var sw := 0.0
		if on:
			state = "EQUIPPED"
		elif own:
			state = "EQUIP"
		elif locked:
			state = "LOCKED"
		else:
			state = Game.fmt_int(Parts.cost(id))
			state_col = PartsPanel.GOLD if afford else Color(0.8, 0.62, 0.45, 0.75)
		sw = font.get_string_size(state, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var sx := size.x - sw - 12.0
		draw_string(font, Vector2(sx, 23), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, state_col)
		if on:
			draw_polyline(PackedVector2Array([Vector2(sx - 18, 17), Vector2(sx - 13, 22), Vector2(sx - 5, 12)]),
				PartsPanel.GREEN, 2.5, true)
			sw += 20.0
		elif locked:
			ArmoryPage._draw_lock(self, Vector2(sx - 12.0, 17.0), 0.45)
			sw += 22.0
		elif not own:
			_nut(Vector2(sx - 11.0, 18.0), 6.0, state_col)
			sw += 20.0
		var name_col := Color.WHITE if own or afford else Color(0.78, 0.82, 0.9)
		draw_string(font, Vector2(16, 23), String(p["name"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - sw - 36.0, 16,
			name_col)
		# Flavour (wraps to 2 lines on narrow cards); each block below starts under the one before it.
		var tw := size.x - 28.0
		var y := _block(font, 41.0, p["desc"], tw, Color(0.65, 0.75, 0.9, 0.85)) + 21.0
		# The perk (gold keyword, what it does under it).
		var perk := Parts.perk_line(id)
		if not perk.is_empty():
			_diamond(Vector2(20, y - 4), 4.0, PartsPanel.GOLD)
			draw_string(font, Vector2(30, y), perk[0], HORIZONTAL_ALIGNMENT_LEFT, size.x - 40.0, 12, PartsPanel.GOLD)
			y = _block(font, y + 15.0, perk[1], tw, Color(1.0, 0.92, 0.75, 0.9)) + 21.0
		# Stat changes: against the part that's on (or, for the part that's on, against STOCK).
		var deltas := Parts.deltas(id)
		var stock := id == Parts.stock_id(p["slot"])
		var caption := "VS STOCK" if on else "IF YOU EQUIP IT"
		if deltas.is_empty():
			caption = "THE BASELINE: NO BONUSES, NO DRAWBACKS" if stock and on else "NO STAT CHANGES"
		draw_string(font, Vector2(16, y), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28.0, 10, Color(0.6, 0.7, 0.85, 0.7))
		var x := 16.0
		y += 16.0
		for d: Array in deltas:
			var t := "%s%d%% %s" % ["+" if d[1] > 0.0 else "-", roundi(absf(d[1]) * 100.0), d[0]]
			var iw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			if x > 16.0 and x + iw > size.x - 12.0:
				x = 16.0
				y += 15.0
			draw_string(font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PartsPanel.GREEN if d[2] else PartsPanel.RED)
			x += iw + 14.0
		# What opens a locked part (bottom of the card, up to 2 lines).
		if locked:
			var c := Contracts.info(p["contract"])
			var lock := "Opens with the contract %s: %s." % [String(c.get("title", "")).to_upper(), String(c.get("text", "")).to_lower()]
			var lh := font.get_multiline_string_size(lock, HORIZONTAL_ALIGNMENT_LEFT, tw, 11, 2).y
			_block(font, size.y - 10.0 - (lh - font.get_height(11)), lock, tw, Color(0.7, 0.8, 0.95, 0.85))
		# BOUGHT / EQUIPPED floating up.
		if _pop > 0.0:
			var py := size.y * 0.55 - (1.0 - _pop) * 30.0
			draw_string_outline(font, Vector2(0, py), _pop_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, 6, Color(0, 0, 0, _pop))
			draw_string(font, Vector2(0, py), _pop_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, Color(0.7, 1.0, 0.8, _pop))
		draw_set_transform(Vector2.ZERO)

	## Up to 2 wrapped lines of 11 px text whose first baseline is `y`; returns the last line's baseline.
	func _block(font: Font, y: float, text: String, width: float, col: Color) -> float:
		draw_multiline_string(font, Vector2(16, y), text, HORIZONTAL_ALIGNMENT_LEFT, width, 11, 2, col)
		var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, 11, 2).y
		return y + h - font.get_height(11)

	func _nut(c: Vector2, rad: float, col: Color) -> void:
		var hex := PackedVector2Array()
		for i in 6:
			hex.append(c + Vector2.from_angle(i * TAU / 6.0) * rad)
		draw_colored_polygon(hex, col)
		draw_circle(c, rad * 0.38, Color(0.35, 0.22, 0.04, col.a))

	func _diamond(c: Vector2, rad: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -rad), c + Vector2(rad, 0), c + Vector2(0, rad),
			c + Vector2(-rad, 0)]), col)
