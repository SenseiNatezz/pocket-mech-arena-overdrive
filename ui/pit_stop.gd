class_name PitStop
extends CanvasLayer
## PIT STOP (Brotato's shop between waves): opens when a Campaign lead-in sector is clear (ScenicArena
## ._sector_cleared, real runs only), before the route doors. Four items for sale, paid with THIS RUN's scrap
## (Game.spend_scrap - whatever isn't spent still comes home): upgrade levels (the evolution's catalyst turns up
## more often) and a utility - FIELD REPAIR, a REPAIR KIT, an OVERDRIVE CELL (the next sector starts with a full
## meter) or a level-up REROLL charge. REROLL deals the unlocked items again (each reroll costs more this
## visit); LOCK keeps an item for the next pit stop. Prices are higher at the second pit stop of a level (sector 2
## pays far more) and follow the difficulty's scrap rate. CONTINUE (or Esc) moves on to the route doors.
## Pauses the game. Mouse / touch, keyboard and gamepad all work; automated runs (Controls.ignore_real_input)
## move on by themselves after AUTO_LEAVE seconds unless a test is driving it.

signal done

const SLOTS := 4
const ARM_TIME := 0.5
const AUTO_LEAVE := 1.4
## Prices (scrap) before the run / difficulty multiplier: an upgrade (+ per level it already has) and the rest.
## Tuned with the autopilot on Normal: a run has ~1,500 scrap at the first pit stop and ~6,000 at the second,
## so a full shelf costs about what sector 1 paid, and a little more of sector 2's haul (PRICE_STEP).
const PRICE_UPGRADE := 380.0
const PRICE_UPGRADE_LEVEL := 120.0
const PRICES := {&"repair": 240.0, &"kit": 300.0, &"overdrive": 260.0, &"reroll": 200.0}
const PRICE_STEP := 0.75
const REROLL_PRICE := 80.0
const REPAIR_SHARE := 0.35
const CATALYST_WEIGHT := 4.0
const UTILITIES := {
	&"repair": {"name": "Field Repair", "desc": "Repair 35% of your max HP now.", "color": Color(0.4, 1.0, 0.5)},
	&"kit": {"name": "Repair Kit", "desc": "One more repair kit (up to your max).", "color": Color(0.45, 1.0, 0.7)},
	&"overdrive": {"name": "Overdrive Cell", "desc": "Start the next sector with a full Overdrive meter.",
		"color": Color(1.0, 0.85, 0.3)},
	&"reroll": {"name": "Uplink Charge", "desc": "+1 level-up REROLL for this run.", "color": Color(0.5, 0.8, 1.0)},
}
const PANEL := Color(0.03, 0.06, 0.13, 0.97)
const GOLD := Color(1.0, 0.82, 0.3)
const TEXT := Color(0.86, 0.92, 1.0)

## [{kind, id, price, sold, locked}]
var items: Array[Dictionary] = []
var _cards: Array[ItemCard] = []
var _locks: Array[TitleButton] = []
var _slots: Array[VBoxContainer] = []
var _root: Control
var _grid: GridContainer
var _title: Label
var _sub: Label
var _scrap: Label
var _hint: Label
var _reroll_btn: TitleButton
var _go_btn: TitleButton
var _rerolls := 0
var _t := 0.0
var _open := false
var _shown := false
var _done := false
## Tests drive it themselves (no automatic leave): this one / every pit stop while `test_hold` is on.
var hold_open := false
static var test_hold := false


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.04, 0.76)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(shade)
	_title = Label.new()
	_title.text = "PIT STOP"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.display_label(_title, 40, Color.WHITE)
	_root.add_child(_title)
	_sub = _label("Spend this run's scrap  -  whatever you don't spend still comes home", 16, Color(0.7, 0.85, 1.0))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_sub)
	_scrap = _label("", 22, GOLD)
	_scrap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiFont.display_label(_scrap, 22, GOLD)
	_root.add_child(_scrap)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 12)
	_root.add_child(_grid)
	for i in SLOTS:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		_grid.add_child(v)
		_slots.append(v)
		var card := ItemCard.new()
		card.pressed.connect(_buy.bind(i))
		v.add_child(card)
		_cards.append(card)
		var lock := TitleButton.new("Lock", Vector2(120, 34))
		lock.pressed.connect(_toggle_lock.bind(i))
		v.add_child(lock)
		_locks.append(lock)
	_reroll_btn = TitleButton.new("", Vector2(240, 46))
	_reroll_btn.pressed.connect(_reroll)
	_root.add_child(_reroll_btn)
	_go_btn = TitleButton.new("Continue", Vector2(240, 46))
	_go_btn.primary = true
	_go_btn.pressed.connect(close)
	_root.add_child(_go_btn)
	_hint = _label("Tap an item to buy it   -   LOCK keeps it for the next pit stop", 14, Color(0.75, 0.85, 1.0, 0.7))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_hint)
	get_viewport().size_changed.connect(_layout, CONNECT_DEFERRED)
	visible = false


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Opens as soon as no level-up pick is waiting.
func open() -> void:
	_open = true


func _show() -> void:
	_shown = true
	visible = true
	get_tree().paused = true
	add_to_group("modal_overlay")  # (the HUD's pause key leaves it alone)
	_t = 0.0
	Game.pit_stops += 1
	items.clear()
	# Items locked at the last pit stop come first (still for sale if they still make sense).
	for it: Dictionary in Game.shop_locked:
		if items.size() < SLOTS and _still_valid(it):
			var copy := it.duplicate()
			copy["price"] = _price(copy)
			copy["locked"] = true
			copy["sold"] = false
			items.append(copy)
	Game.shop_locked.clear()
	_fill()
	_refresh()
	_layout()
	Sfx.play(&"select", -5.0)
	if Controls.ignore_real_input and not hold_open and not test_hold:
		get_tree().create_timer(AUTO_LEAVE, true, false, true).timeout.connect(close)


# --- stock -------------------------------------------------------------------------------------------

## Tops the shelf up to SLOTS items: upgrades from the deck (the evolution's catalyst weighted up) and one or
## two utilities.
func _fill() -> void:
	var utilities := 1 if randf() < 0.7 else 2
	var want_up := SLOTS - utilities
	var have_up := 0
	for it in items:
		if it["kind"] == &"upgrade":
			have_up += 1
	var pool := _upgrade_pool()
	while items.size() < SLOTS and have_up < want_up and not pool.is_empty():
		var id := _weighted_pick(pool)
		pool.erase(id)
		items.append({"kind": &"upgrade", "id": id})
		have_up += 1
	var utils := _utility_pool()
	while items.size() < SLOTS and not utils.is_empty():
		var k: StringName = utils.pick_random()
		utils.erase(k)
		items.append({"kind": k, "id": k})
	while items.size() < SLOTS and not pool.is_empty():
		var id := _weighted_pick(pool)
		pool.erase(id)
		items.append({"kind": &"upgrade", "id": id})
	for it in items:
		if not it.has("price"):
			it["price"] = _price(it)
			it["sold"] = false
			it["locked"] = false


func _upgrade_pool() -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in Upgrades.CATALOG:
		if Upgrades.is_available(id) and not _on_shelf(id):
			out.append(id)
	return out


func _utility_pool() -> Array[StringName]:
	var out: Array[StringName] = []
	for k: StringName in UTILITIES:
		if _on_shelf(k):
			continue
		var mech := _mech()
		if k == &"kit" and (mech == null or mech.repair_charges_max <= 0):
			continue  # (RAVEN CLAW carries no kits)
		if k == &"overdrive" and Game.carry_overdrive:
			continue
		out.append(k)
	return out


func _on_shelf(id: StringName) -> bool:
	for it in items:
		if it["id"] == id:
			return true
	return false


## The evolution's catalyst is CATALYST_WEIGHT times as likely as anything else.
func _weighted_pick(pool: Array[StringName]) -> StringName:
	var cat := Upgrades.evolve_catalyst()
	var total := 0.0
	for id in pool:
		total += _weight(id, cat)
	var r := randf() * total
	for id in pool:
		r -= _weight(id, cat)
		if r <= 0.0:
			return id
	return pool[-1]


func _weight(id: StringName, cat: StringName) -> float:
	return CATALYST_WEIGHT if id == cat and not Upgrades.is_evolved() and Upgrades.level_of(id) < Upgrades.evolve_need() else 1.0


func _still_valid(it: Dictionary) -> bool:
	if it.get("kind") == &"upgrade":
		return Upgrades.CATALOG.has(it.get("id", &"")) and Upgrades.is_available(it["id"])
	return UTILITIES.has(it.get("kind", &""))


## Scrap price of an item at this pit stop: the base, x (1 + PRICE_STEP per earlier pit stop this run) x the
## difficulty's scrap rate (harder difficulties pay more scrap, so they charge more).
func _price(it: Dictionary) -> int:
	var base: float
	if it["kind"] == &"upgrade":
		base = PRICE_UPGRADE + PRICE_UPGRADE_LEVEL * Upgrades.level_of(it["id"])
	else:
		base = float(PRICES.get(it["kind"], 150.0))
	return roundi(base * _mult() / 10.0) * 10


## (the pit stop after sector 2 charges PRICE_STEP more than the one after sector 1; a new level starts over)
func _mult() -> float:
	return (1.0 + PRICE_STEP * clampi(Game.campaign_sector - 1, 0, Game.CAMPAIGN_SECTORS)) * Game.diff("scrap")


func reroll_price() -> int:
	return roundi(REROLL_PRICE * (1 + _rerolls) * _mult() / 10.0) * 10


# --- actions -----------------------------------------------------------------------------------------

func _buy(i: int) -> void:
	if not _armed() or i >= items.size():
		return
	buy(i)


## Buys item `i` (tests call this directly). False if it's sold out or there isn't enough scrap.
func buy(i: int) -> bool:
	var it := items[i]
	if it["sold"] or not Game.spend_scrap(float(it["price"])):
		Sfx.play(&"deny", -8.0)
		if i < _cards.size():
			_cards[i].shake()
		return false
	it["sold"] = true
	it["locked"] = false
	var mech := _mech()
	match it["kind"]:
		&"upgrade":
			Upgrades.buy(it["id"])
		&"repair":
			if mech:
				mech.heal(mech.max_hp * REPAIR_SHARE)
		&"kit":
			if mech:
				mech.add_repair_charge()
		&"overdrive":
			Game.carry_overdrive = true
		&"reroll":
			Upgrades.rerolls += 1
	Sfx.play(&"coin", -3.0, 0.0)
	Sfx.play(&"levelup", -10.0, 0.0)
	if i < _cards.size():
		_cards[i].pop()
	_refresh()
	return true


func _toggle_lock(i: int) -> void:
	if not _armed() or i >= items.size() or items[i]["sold"]:
		return
	items[i]["locked"] = not items[i]["locked"]
	Sfx.play(&"select", -8.0)
	_refresh()


func _reroll() -> void:
	if not _armed():
		return
	reroll()


## Deals the unlocked, unsold items again for reroll_price(). False if the scrap isn't there.
func reroll() -> bool:
	if not Game.spend_scrap(float(reroll_price())):
		Sfx.play(&"deny", -8.0)
		return false
	_rerolls += 1
	var keep: Array[Dictionary] = []
	for it in items:
		if it["locked"] and not it["sold"]:
			keep.append(it)
	items = keep
	_fill()
	_refresh()
	Sfx.play(&"select", -5.0)
	for c in _cards:
		c.flash()
	return true


## Leaves: locked items are kept for the next pit stop, then the route doors.
func close() -> void:
	if _done:
		return
	_done = true
	Game.shop_locked.clear()
	for it in items:
		if it["locked"] and not it["sold"]:
			Game.shop_locked.append({"kind": it["kind"], "id": it["id"]})
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func() -> void:
		remove_from_group("modal_overlay")
		get_tree().paused = false
		done.emit()
		queue_free())


func _armed() -> bool:
	return _t >= ARM_TIME and not _done


func _mech() -> Mech:
	return get_tree().get_first_node_in_group("player") as Mech


# --- view --------------------------------------------------------------------------------------------

func _refresh() -> void:
	_scrap.text = "SCRAP  %s" % Game.fmt_int(floori(Game.run_scrap_landed()))
	for i in SLOTS:
		var has := i < items.size()
		_slots[i].visible = has
		if not has:
			continue
		var it := items[i]
		_cards[i].setup(it, Game.run_scrap_landed() + 0.5 >= float(it["price"]))
		_locks[i].label_text = "Locked" if it["locked"] else "Lock"
		_locks[i].modulate.a = 0.35 if it["sold"] else 1.0
		_locks[i].queue_redraw()
	_reroll_btn.label_text = "Reroll  (%s)" % Game.fmt_int(reroll_price())
	_reroll_btn.modulate.a = 1.0 if Game.run_scrap_landed() + 0.5 >= reroll_price() else 0.45
	_reroll_btn.queue_redraw()


func _layout() -> void:
	if not visible:
		return
	var vp := get_viewport().get_visible_rect().size
	var portrait := vp.x < vp.y
	var cols := 2 if portrait or vp.x < 1000.0 else 4
	_grid.columns = cols
	var cw := minf((vp.x - 48.0 - 16.0 * (cols - 1)) / cols, 280.0)
	var ch := 214.0 if not portrait else 230.0
	for i in SLOTS:
		_cards[i].custom_minimum_size = Vector2(cw, ch)
		_locks[i].custom_minimum_size = Vector2(cw, 34)
	# (landscape: under the HUD's objective line; portrait: under the status card)
	var top := 118.0 if portrait else maxf(54.0, vp.y * 0.075)
	_title.position = Vector2(0, top)
	_title.size = Vector2(vp.x, 50)
	_sub.position = Vector2(20, top + 50)
	_sub.size = Vector2(vp.x - 40, 24)
	_scrap.position = Vector2(0, top + 78)
	_scrap.size = Vector2(vp.x, 30)
	_grid.reset_size()
	var gs := _grid.get_combined_minimum_size()
	_grid.position = Vector2((vp.x - gs.x) / 2.0, top + 118.0)
	var by := _grid.position.y + gs.y + 18.0
	var bw := 240.0
	_reroll_btn.position = Vector2(vp.x / 2.0 - bw - 10.0, by)
	_go_btn.position = Vector2(vp.x / 2.0 + 10.0, by)
	_hint.position = Vector2(0, by + 56.0)
	_hint.size = Vector2(vp.x, 22)
	if get_viewport().gui_get_focus_owner() == null:
		_cards[0].grab_focus()


func _process(delta: float) -> void:
	if _done:
		return
	if _open and not _shown:
		if Upgrades.choosing or Upgrades.pending > 0:
			return  # (a level-up is being picked first)
		_show()
		return
	if not visible:
		return
	_t += delta
	for c in _cards:
		c.armed = _t >= ARM_TIME


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _done:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if _armed():
			close()


## One item on the shelf: its icon (the upgrade's glyph, or the utility's), name, level pips / NEW, what it
## does, the price on a gold plate (red when you can't afford it), LOCKED / SOLD marks, and "EVOLVES <weapon>"
## on the evolution's catalyst.
class ItemCard:
	extends Button
	const ICONS := preload("res://ui/upgrade_icons.gd")
	var item: Dictionary = {}
	var armed := false
	var _afford := true
	var _hl := 0.0
	var _t := 0.0
	var _pop := 0.0
	var _shake := 0.0
	var _flash := 0.0
	var _desc: Label

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(func() -> void:
			if armed:
				grab_focus())
		_desc = Label.new()
		_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc.add_theme_font_size_override("font_size", 13)
		_desc.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
		_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_desc)

	func setup(it: Dictionary, afford: bool) -> void:
		item = it
		_afford = afford
		if it["kind"] == &"upgrade":
			_desc.text = Upgrades.describe(it["id"])
		else:
			_desc.text = String(UTILITIES[it["kind"]]["desc"])
		queue_redraw()

	func pop() -> void:
		_pop = 1.0

	func shake() -> void:
		_shake = 1.0

	func flash() -> void:
		_flash = 1.0

	func _color() -> Color:
		if item.is_empty():
			return Color.WHITE
		return Upgrades.color(item["id"]) if item["kind"] == &"upgrade" else UTILITIES[item["kind"]]["color"]

	func _name() -> String:
		if item.is_empty():
			return ""
		return Upgrades.display_name(item["id"]) if item["kind"] == &"upgrade" else String(UTILITIES[item["kind"]]["name"])

	func _process(delta: float) -> void:
		_t += delta
		var target := 1.0 if has_focus() else 0.0
		_hl = move_toward(_hl, target, delta * 8.0)
		_pop = move_toward(_pop, 0.0, delta * 1.6)
		_shake = move_toward(_shake, 0.0, delta * 3.5)
		_flash = move_toward(_flash, 0.0, delta * 3.0)
		_desc.position = Vector2(14, 98)
		_desc.size = Vector2(size.x - 28, size.y - 98 - 44)
		queue_redraw()

	func _draw() -> void:
		if item.is_empty():
			return
		var sold: bool = item.get("sold", false)
		var col := _color()
		var font: Font = UiFont.BOLD
		if _shake > 0.0:
			draw_set_transform(Vector2(sin(_shake * 40.0) * 6.0 * _shake, 0))
		var r := Rect2(Vector2.ZERO, size)
		if _hl > 0.01:
			for i in 3:
				draw_rect(r.grow(3 + i * 4), Color(col, 0.14 * _hl / (i + 1)), false, 4.0)
		var bg := StyleBoxFlat.new()
		bg.bg_color = PANEL.lerp(Color(col.darkened(0.78), 0.97), 0.3 + 0.3 * _hl + 0.4 * _flash)
		bg.border_color = Color(col, 0.5 + 0.5 * _hl) if not item.get("locked", false) else GOLD
		bg.set_border_width_all(2 + int(_hl * 2.0) + (1 if item.get("locked", false) else 0))
		bg.set_corner_radius_all(10)
		draw_style_box(bg, r)
		# Icon + name + level / NEW.
		var c := Vector2(42, 46)
		draw_circle(c, 29, Color(col, 0.12 + 0.08 * sin(_t * 3.0)))
		draw_circle(c, 23, Color(0.02, 0.03, 0.07, 0.9))
		draw_arc(c, 23, 0, TAU, 40, Color(col, 0.9), 2.0, true)
		_icon(c, col)
		var nm := _name()
		draw_string(font, Vector2(78, 38), nm, HORIZONTAL_ALIGNMENT_LEFT, size.x - 88, LobbyKit.fit(font, nm, 17, size.x - 88, 11),
			Color.WHITE)
		if item["kind"] == &"upgrade":
			var id: StringName = item["id"]
			var have := Upgrades.level_of(id)
			if have == 0 and not sold:
				draw_string(font, Vector2(78, 58), "NEW!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.45, 1.0, 0.6))
			else:
				for i in Upgrades.max_level(id):
					var p := Vector2(84 + i * 13.0, 54)
					if i < have:
						draw_circle(p, 4.0, col)
					else:
						draw_arc(p, 3.5, 0, TAU, 16, Color(1, 1, 1, 0.3), 1.5, true)
			# The evolution's catalyst says so.
			if id == Upgrades.evolve_catalyst() and not Upgrades.is_evolved():
				var tag := "EVOLVES %s" % String(Game.weapon_info(Game.weapon)["name"]).to_upper()
				draw_string(font, Vector2(14, 86), tag, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28,
					LobbyKit.fit(font, tag, 12, size.x - 28, 8), Color(Upgrades.EVOLVE_COLOR, 0.75 + 0.25 * sin(_t * 5.0)))
		else:
			draw_string(font, Vector2(78, 58), "SUPPLY", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(col, 0.85))
		# Price plate (or SOLD).
		var plate := Rect2(12, size.y - 40, size.x - 24, 30)
		if sold:
			draw_rect(plate, Color(0.3, 1.0, 0.5, 0.14))
			UiFont.draw_display(self, Vector2(plate.position.x, plate.end.y - 7), "SOLD", 18, Color(0.5, 1.0, 0.6),
				HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, Color(0.05, 0.35, 0.15))
		else:
			var pc := GOLD if _afford else Color(1.0, 0.45, 0.4)
			draw_rect(plate, Color(pc, 0.14 + 0.1 * _hl))
			var txt := Game.fmt_int(int(item["price"]))
			var tw := UiFont.DISPLAY.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
			var cx := plate.position.x + plate.size.x / 2.0
			_nut(Vector2(cx - tw / 2.0 - 14.0, plate.position.y + 15.0), 7.0, pc)
			UiFont.draw_display(self, Vector2(cx - tw / 2.0 + 2.0, plate.end.y - 7), txt, 18, pc, HORIZONTAL_ALIGNMENT_LEFT,
				-1, Color(0.2, 0.12, 0.0))
			if item.get("locked", false):
				draw_string(font, Vector2(plate.end.x - 70, plate.position.y - 6), "LOCKED", HORIZONTAL_ALIGNMENT_RIGHT, 66, 11, GOLD)
		if sold:
			draw_rect(r, Color(0, 0, 0, 0.35))
		if _pop > 0.0:
			UiFont.draw_display(self, Vector2(0, size.y * 0.45 - (1.0 - _pop) * 30.0), "BOUGHT", 24, Color(0.7, 1.0, 0.8, _pop),
				HORIZONTAL_ALIGNMENT_CENTER, size.x, Color(0.05, 0.4, 0.2, _pop))
		draw_set_transform(Vector2.ZERO)

	func _icon(c: Vector2, col: Color) -> void:
		match item["kind"]:
			&"upgrade":
				ICONS.draw(self, item["id"], c, 14.0, col.lightened(0.25))
			&"repair":
				draw_rect(Rect2(c - Vector2(4, 13), Vector2(8, 26)), col)
				draw_rect(Rect2(c - Vector2(13, 4), Vector2(26, 8)), col)
			&"kit":
				draw_rect(Rect2(c - Vector2(13, 10), Vector2(26, 20)), Color(col, 0.3))
				draw_rect(Rect2(c - Vector2(13, 10), Vector2(26, 20)), col, false, 2.0)
				draw_rect(Rect2(c - Vector2(2.5, 7), Vector2(5, 14)), col)
				draw_rect(Rect2(c - Vector2(7, 2.5), Vector2(14, 5)), col)
			&"overdrive":
				draw_colored_polygon(PackedVector2Array([c + Vector2(3, -15), c + Vector2(-8, 2), c + Vector2(0, 2),
					c + Vector2(-3, 15), c + Vector2(8, -2), c + Vector2(0, -2)]), col)
			&"reroll":
				draw_arc(c, 11.0, 0.3, PI * 1.6, 20, col, 3.0, true)
				var tip := c + Vector2.from_angle(PI * 1.6) * 11.0
				draw_colored_polygon(PackedVector2Array([tip + Vector2(6, 2), tip + Vector2(-4, 5), tip + Vector2(0, -6)]), col)

	func _nut(p: Vector2, rad: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 6:
			pts.append(p + Vector2.from_angle(TAU * i / 6.0 + _t * 0.8) * rad)
		draw_colored_polygon(pts, col)
		draw_circle(p, rad * 0.42, Color(0.25, 0.16, 0.02))
