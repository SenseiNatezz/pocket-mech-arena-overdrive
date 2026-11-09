class_name ContractsPanel
extends VBoxContainer
## Hangar > CONTRACTS tab (ui/hangar_page.gd): the 40 contracts of autoload/contracts.gd in their 5 rows.
##   header   "CONTRACTS  12 / 40 DONE" and a gold CLAIM ALL (+scrap) button while any are ready
##   rows     "ROW 1  -  ROOKIE   5 / 8 CLAIMED" with the row's permanent bonus (lit once all 8 are claimed),
##            then its contract cards: title, reward, what it asks, what it unlocks, and a progress bar
##            (blue = in progress, pulsing gold CLAIM = done, green CLAIMED). Pressing a ready card claims it.
## Cards are focusable buttons, so mouse, touch and keyboard / gamepad all work; 2 columns in landscape,
## 1 in portrait (set_layout).

## Scrap was claimed (the Hangar refreshes its scrap total).
signal claimed(total: int)

const GOLD := Color(1.0, 0.82, 0.3)
const CYAN := Color(0.35, 0.75, 1.0)
const GREEN := Color(0.45, 1.0, 0.6)
const CARD_H := 86.0

var _head: Label
var _claim_all: Button
var _headers: Array[RowHeader] = []
var _grids: Array[GridContainer] = []
var _cards := {}


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	_head = _label("", 20, Color.WHITE)
	_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_head)
	_claim_all = Button.new()
	_claim_all.custom_minimum_size = Vector2(230, 42)
	_claim_all.focus_mode = Control.FOCUS_ALL
	_claim_all.add_theme_font_size_override("font_size", 15)
	_claim_all.add_theme_color_override("font_color", Color(0.16, 0.1, 0.0))
	_claim_all.add_theme_color_override("font_hover_color", Color(0.1, 0.06, 0.0))
	_claim_all.add_theme_color_override("font_focus_color", Color(0.1, 0.06, 0.0))
	_claim_all.add_theme_stylebox_override("normal", HangarPage._box(GOLD.darkened(0.05), GOLD.lightened(0.3)))
	_claim_all.add_theme_stylebox_override("hover", HangarPage._box(GOLD.lightened(0.15), Color.WHITE))
	_claim_all.add_theme_stylebox_override("pressed", HangarPage._box(GOLD.lightened(0.3), Color.WHITE))
	_claim_all.add_theme_stylebox_override("focus", HangarPage._box(Color(0, 0, 0, 0), Color.WHITE, 2))
	_claim_all.mouse_entered.connect(_claim_all.grab_focus)
	_claim_all.pressed.connect(_on_claim_all)
	top.add_child(_claim_all)
	var sub := _label("Contracts finish on their own as you play. Claim their scrap here, and claim all 8 in a row to switch on its permanent bonus.",
		14, Color(0.7, 0.85, 1.0, 0.85))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(sub)
	for r in Contracts.ROWS.size():
		var header := RowHeader.new(r)
		add_child(header)
		_headers.append(header)
		var grid := GridContainer.new()
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		add_child(grid)
		_grids.append(grid)
		for id in Contracts.row_ids(r):
			var card := ContractCard.new(id)
			card.pressed.connect(_on_card.bind(id))
			grid.add_child(card)
			_cards[id] = card
	Contracts.contract_done.connect(func(_id: StringName) -> void: refresh())
	refresh()


## Column width + card columns (2 in landscape, 1 in portrait).
func set_layout(width: float, cols: int) -> void:
	var cw := (width - 10.0 * (cols - 1)) / cols
	for g in _grids:
		g.columns = cols
	for h in _headers:
		h.custom_minimum_size = Vector2(width, 34)
	for c: ContractCard in _cards.values():
		c.custom_minimum_size = Vector2(cw, CARD_H)


func refresh() -> void:
	var ready := Contracts.ready_ids()
	var total := 0
	for id in ready:
		total += Contracts.reward(id)
	_head.text = "CONTRACTS   %d / %d DONE" % [Contracts.done_count(), Contracts.LIST.size()]
	_claim_all.visible = not ready.is_empty()
	_claim_all.text = "CLAIM ALL  +%s" % Game.fmt_int(total)
	for h in _headers:
		h.queue_redraw()
	for c: ContractCard in _cards.values():
		c.queue_redraw()


## The first card with scrap waiting (or the first card) - for focus when the tab opens.
func first_focus() -> Control:
	if _claim_all.visible:
		return _claim_all
	for c: ContractCard in _cards.values():
		if not Contracts.is_claimed(c.id):
			return c
	return _cards.values()[0]


func _on_card(id: StringName) -> void:
	if not Contracts.is_ready(id):
		Sfx.play(&"select", -14.0, 0.0)
		return
	var got := Contracts.claim(id)
	(_cards[id] as ContractCard).flash(got)
	Sfx.play(&"coin", -3.0, 0.0)
	Sfx.play(&"levelup", -9.0, 0.0)
	refresh()
	claimed.emit(got)


func _on_claim_all() -> void:
	var ids := Contracts.ready_ids()
	var got := Contracts.claim_all()
	for id in ids:
		(_cards[id] as ContractCard).flash(Contracts.reward(id))
	Sfx.play(&"coin", -2.0, 0.0)
	Sfx.play(&"levelup", -6.0, 0.0)
	refresh()
	(_cards[ids[0]] as ContractCard).grab_focus() if not ids.is_empty() else null
	claimed.emit(got)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## "ROW 1  -  ROOKIE    5 / 8 CLAIMED" on the left, the row's permanent bonus on the right (gold + ACTIVE once
## every contract of the row is claimed), over a thin rule.
class RowHeader:
	extends Control
	var row := 0

	func _init(r: int) -> void:
		row = r
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, 34)

	func _draw() -> void:
		var font := get_theme_default_font()
		var info: Dictionary = Contracts.ROWS[row]
		var ids := Contracts.row_ids(row)
		var n := 0
		for id in ids:
			if Contracts.is_claimed(id):
				n += 1
		var complete := n == ids.size()
		var head := "ROW %d  -  %s" % [row + 1, info["name"]]
		draw_string_outline(font, Vector2(0, 22), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, 22), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ContractsPanel.CYAN)
		var hw := font.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(hw + 14.0, 22), "%d / %d CLAIMED" % [n, ids.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			ContractsPanel.GREEN if complete else Color(0.7, 0.8, 0.95))
		var bonus := "ROW BONUS: %s%s" % [info["bonus"], "  -  ACTIVE" if complete else ""]
		draw_string(font, Vector2(0, 22), bonus, HORIZONTAL_ALIGNMENT_RIGHT, size.x, 13,
			ContractsPanel.GOLD if complete else Color(0.85, 0.8, 0.65, 0.65))
		draw_line(Vector2(0, 30), Vector2(size.x, 30), Color(ContractsPanel.CYAN, 0.25), 1.0)


## One contract as a focusable card (see the class doc above). `flash` plays the claim pop ("+900" rising).
class ContractCard:
	extends Button
	var id: StringName
	var _hl := 0.0
	var _t := 0.0
	var _pop := 0.0
	var _pop_amount := 0

	func _init(cid: StringName) -> void:
		id = cid
		text = ""
		flat = true
		focus_mode = Control.FOCUS_ALL
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(grab_focus)

	func flash(amount: int) -> void:
		_pop = 1.0
		_pop_amount = amount

	func _process(delta: float) -> void:
		_t += delta
		var target := 1.0 if has_focus() else 0.0
		var animating := Contracts.is_ready(id) or _pop > 0.0 or not is_equal_approx(_hl, target)
		_hl = move_toward(_hl, target, delta * 7.0)
		_pop = move_toward(_pop, 0.0, delta * 1.2)
		if animating:
			queue_redraw()

	func _draw() -> void:
		var c := Contracts.info(id)
		var font := get_theme_default_font()
		var done := Contracts.is_done(id)
		var got := Contracts.is_claimed(id)
		var ready := done and not got
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		var r := Rect2(Vector2.ZERO, size)
		var edge := ContractsPanel.GOLD if ready else (ContractsPanel.GREEN if got else ContractsPanel.CYAN)
		var bg := Color(0.04, 0.07, 0.13, 0.95)
		if ready:
			bg = Color(0.1, 0.075, 0.02, 0.95).lerp(Color(0.18, 0.13, 0.03, 0.95), pulse)
		elif got:
			bg = Color(0.03, 0.08, 0.06, 0.92)
		draw_rect(r, bg.lerp(Color(0.06, 0.13, 0.25, 0.95), _hl * 0.5))
		draw_rect(r, Color(edge, 0.4 + 0.45 * maxf(_hl, pulse if ready else 0.0)), false, 2.0 if ready or _hl > 0.5 else 1.0)
		draw_rect(Rect2(0, 0, 4, size.y), Color(edge, 0.9))
		# Title + reward (a gold nut and "+900") on the right.
		var title_col := Color(0.75, 0.9, 0.8) if got else Color.WHITE
		var rw := "+" + Game.fmt_int(Contracts.reward(id))
		var rww := font.get_string_size(rw, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		draw_string(font, Vector2(16, 24), String(c["title"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, size.x - rww - 60, 16, title_col)
		var gold_a := 0.45 if got else 1.0
		draw_string(font, Vector2(size.x - rww - 12.0, 24), rw, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ContractsPanel.GOLD, gold_a))
		_nut(Vector2(size.x - rww - 24.0, 19.0), 6.5, Color(ContractsPanel.GOLD, gold_a))
		# What it asks, and what it unlocks.
		draw_string(font, Vector2(16, 44), c["text"], HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 13, Color(0.75, 0.84, 0.96))
		if c.has("unlock"):
			draw_string(font, Vector2(16, 61), "UNLOCKS  " + String(c["unlock"]).to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
				size.x - 28, 11, Color(0.45, 0.95, 1.0, 0.95 if not done else 0.6))
		# Progress bar + count / CLAIM / CLAIMED.
		var bar := Rect2(16, size.y - 16, size.x - 136, 7)
		var f := Contracts.fraction(id)
		draw_rect(bar, Color(0.12, 0.17, 0.26, 0.9))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * f, bar.size.y)),
			ContractsPanel.GREEN.darkened(0.2) if got else (ContractsPanel.GOLD if done else ContractsPanel.CYAN))
		var tx := bar.end.x + 10.0
		if ready:
			draw_string(font, Vector2(tx, size.y - 8), "CLAIM", HORIZONTAL_ALIGNMENT_LEFT, -1, 16,
				ContractsPanel.GOLD.lerp(Color.WHITE, pulse * 0.5))
		elif got:
			draw_polyline(PackedVector2Array([Vector2(tx, size.y - 14), Vector2(tx + 5, size.y - 9), Vector2(tx + 13, size.y - 19)]),
				ContractsPanel.GREEN, 2.5, true)
			draw_string(font, Vector2(tx + 18, size.y - 9), "CLAIMED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, ContractsPanel.GREEN)
		else:
			var p := Contracts.progress(id)
			draw_string(font, Vector2(tx, size.y - 9), "%s / %s" % [Game.fmt_int(p.x), Game.fmt_int(p.y)],
				HORIZONTAL_ALIGNMENT_LEFT, size.x - tx - 8, 12, Color(0.8, 0.88, 1.0))
		# Claim pop: "+900" rising and fading.
		if _pop > 0.0:
			var py := size.y * 0.5 - (1.0 - _pop) * 30.0
			draw_string_outline(font, Vector2(0, py), rw, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, 6, Color(0, 0, 0, _pop))
			draw_string(font, Vector2(0, py), rw, HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(1.0, 0.92, 0.5, _pop))

	func _nut(p: Vector2, rad: float, col: Color) -> void:
		var hex := PackedVector2Array()
		for i in 6:
			hex.append(p + Vector2.from_angle(i * TAU / 6.0) * rad)
		draw_colored_polygon(hex, col)
		draw_circle(p, rad * 0.38, Color(0.35, 0.22, 0.04, col.a))
