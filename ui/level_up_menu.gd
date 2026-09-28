extends CanvasLayer
## Level-up menu (created by the HUD): pauses the game and offers 3 compact upgrade cards from
## Upgrades.roll_choices(). Short, wide cards (icon left, name + description right) under a light shade.
## PLACEMENT: every time it opens it looks at what's on screen (the HUD status card / run info / boss
## bar, the mech, other overlays like the Weapon Range weapon bar + spawn panel) and
## sits in the free band that covers the least of them (preferring the upper half).
## Mouse, touch (tap a card) and keyboard/gamepad (left/right + accept) all work. Several level-ups in
## a row open one after another. Cards ignore presses for a moment after appearing so a held fire
## button / thumb can't pick one by accident. Automated runs (Controls.ignore_real_input) pick the
## first card by themselves.

signal closed

const UpgradeIcons := preload("res://ui/upgrade_icons.gd")
const ARM_TIME := 0.35
const CARD_SIZE := Vector2(270, 104)
## Covering the mech counts this many times more than covering other UI.
const MECH_WEIGHT := 3.0


class UpgradeCard:
	extends Button
	var id := &""
	var armed := false
	var _hl := 0.0
	var _t := 0.0
	var _desc: Label

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_ALL
		custom_minimum_size = CARD_SIZE
		pivot_offset = CARD_SIZE / 2
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())
		mouse_entered.connect(func() -> void:
			if armed:
				grab_focus())
		_desc = Label.new()
		_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_desc.position = Vector2(86, 54)
		_desc.size = Vector2(CARD_SIZE.x - 94, 46)
		_desc.add_theme_font_size_override("font_size", 12)
		_desc.add_theme_constant_override("line_spacing", -2)
		_desc.add_theme_color_override("font_color", Color(0.82, 0.88, 0.96))
		_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_desc)

	func setup(upgrade: StringName) -> void:
		id = upgrade
		_desc.text = Upgrades.describe(id)
		queue_redraw()

	func _process(delta: float) -> void:
		_t += delta
		var target := 1.0 if has_focus() or (armed and is_hovered()) else 0.0
		_hl = move_toward(_hl, target, delta * 8.0)
		scale = Vector2.ONE * (1.0 + 0.03 * _hl)
		queue_redraw()

	func _draw() -> void:
		var col := Upgrades.color(id)
		var r := Rect2(Vector2.ZERO, size)
		# Glow when highlighted.
		if _hl > 0.01:
			for i in 3:
				draw_rect(r.grow(3 + i * 4), Color(col, 0.16 * _hl / (i + 1)), false, 4.0)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.04, 0.06, 0.12, 0.96).lerp(Color(col.darkened(0.75), 0.97), 0.35 + 0.3 * _hl)
		bg.border_color = Color(col, 0.55 + 0.45 * _hl)
		bg.set_border_width_all(2 + int(_hl * 2.0))
		bg.set_corner_radius_all(10)
		draw_style_box(bg, r)
		draw_rect(Rect2(8, 8, 3, size.y - 16), Color(col, 0.7))
		# Icon (left).
		var c := Vector2(46, size.y / 2)
		draw_circle(c, 31, Color(col, 0.12 + 0.08 * sin(_t * 3.0)))
		draw_circle(c, 25, Color(0.02, 0.03, 0.07, 0.9))
		draw_arc(c, 25, 0, TAU, 40, Color(col, 0.9), 2.0, true)
		UpgradeIcons.draw(self, id, c, 15.0, col.lightened(0.25))
		# Name + NEW / level pips (right).
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(86, 28), Upgrades.display_name(id), HORIZONTAL_ALIGNMENT_LEFT, size.x - 94, 17,
			Color.WHITE)
		var have := Upgrades.level_of(id)
		var mx := Upgrades.max_level(id)
		if id == Upgrades.FIELD_REPAIR:
			draw_string(font, Vector2(86, 46), "INSTANT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 1.0, 0.6))
		elif have == 0:
			draw_string(font, Vector2(86, 46), "NEW!", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.45, 1.0, 0.6))
		else:
			for i in mx:
				var p := Vector2(92 + i * 13.0, 42)
				if i < have:
					draw_circle(p, 4.0, col)
				elif i == have:
					draw_circle(p, 4.0, Color(col.lightened(0.5), 0.5 + 0.5 * sin(_t * 8.0)))
				else:
					draw_arc(p, 3.5, 0, TAU, 16, Color(1, 1, 1, 0.3), 1.5, true)


var _root: Control
var _box: VBoxContainer
var _title: Label
var _sub: Label
var _row: HBoxContainer
var _cards: Array[UpgradeCard] = []
var _arm_t := 0.0
var _auto_t := -1.0


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.02, 0.06, 0.3)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 5)
	_root.add_child(_box)
	# One header line: LEVEL UP!  LEVEL 2 - choose an upgrade.
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 14)
	_box.add_child(head)
	_title = _label("LEVEL UP!", 24, Color(0.45, 1.0, 0.8))
	head.add_child(_title)
	_sub = _label("", 15, Color(0.8, 0.9, 1.0))
	head.add_child(_sub)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 12)
	_box.add_child(_row)
	for i in 3:
		var card := UpgradeCard.new()
		card.pressed.connect(_on_card_pressed.bind(card))
		_row.add_child(card)
		_cards.append(card)
	var hint := _label("Click / tap a card   -   Arrows + Enter   -   D-pad + A", 11, Color(1, 1, 1, 0.5))
	_box.add_child(hint)
	Upgrades.level_up_ready.connect(open)
	if Upgrades.pending > 0:
		open.call_deferred()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 7)
	return l


func is_open() -> bool:
	return visible


func open() -> void:
	if Upgrades.pending <= 0:
		return
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech == null or mech.dead:
		return
	Upgrades.choosing = true
	get_tree().paused = true
	visible = true
	_deal()


## Shows a fresh set of 3 cards (animated in).
func _deal() -> void:
	var choices := Upgrades.roll_choices(3)
	_sub.text = "LEVEL %d   -   choose an upgrade%s" % [Upgrades.level - Upgrades.pending + 1,
		"   (%d more after this)" % (Upgrades.pending - 1) if Upgrades.pending > 1 else ""]
	_arm_t = ARM_TIME
	for i in _cards.size():
		var card := _cards[i]
		card.visible = i < choices.size()
		if not card.visible:
			continue
		card.setup(choices[i])
		card.armed = false
		card.modulate.a = 0.0
		var tw := card.create_tween().set_parallel()
		tw.tween_property(card, "modulate:a", 1.0, 0.2).set_delay(i * 0.07)
		tw.tween_property(card, "position:y", 0.0, 0.25).from(24.0).set_delay(i * 0.07) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_place()
	_title.pivot_offset = _title.size / 2
	_title.scale = Vector2(1.25, 1.25)
	_title.create_tween().tween_property(_title, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	_auto_t = 0.5 if Controls.ignore_real_input else -1.0


# --- placement ------------------------------------------------------------------------------------------

## Puts the menu (centred horizontally) at the height where it covers the least of what's on screen.
func _place() -> void:
	var vp := get_viewport().get_visible_rect().size
	var size := _box.get_combined_minimum_size()
	_box.size = size
	var x := roundf(vp.x / 2 - size.x / 2)
	var reserved := _reserved_rects(vp)
	var best_y := 8.0
	var best_score := INF
	var prefer := vp.y * 0.3
	var y := 8.0
	while y <= vp.y - size.y - 8.0:
		var r := Rect2(x, y, size.x, size.y)
		var score := 0.0
		for item: Array in reserved:
			var hit := r.intersection(item[0])
			score += hit.get_area() * item[1]
		# Ties (e.g. several spots covering nothing) go to the one nearest the upper third.
		score += absf(y + size.y / 2 - prefer) * 0.01
		if score < best_score:
			best_score = score
			best_y = y
		y += 4.0
	_box.position = Vector2(x, best_y)


## [rect, weight] for everything the menu should avoid, in screen coordinates.
func _reserved_rects(vp: Vector2) -> Array:
	var out := []
	var touch := Controls.device == Controls.Device.TOUCH
	# HUD: status card (top-left) and run info (top-right).
	out.append([Rect2(0, 0, 392, 124 if touch else 132), 1.0])
	out.append([Rect2(vp.x - 440, 108 if touch else 0, 440, 56 if touch else 62), 1.0])
	var hud := get_parent()
	if hud and is_instance_valid(hud.get("boss")) and not hud.boss.dead:
		var w := minf(vp.x * 0.5, 640.0)
		out.append([Rect2(vp.x / 2 - w / 2, (160.0 if touch else 132.0) - 26.0, w, 48), 1.0])
	# The mech.
	var mech := get_tree().get_first_node_in_group("player") as Node2D
	if mech:
		var p := mech.get_global_transform_with_canvas().origin
		out.append([Rect2(p - Vector2(80, 80), Vector2(160, 160)), MECH_WEIGHT])
	# Visible controls on other overlay layers (the Weapon Range weapon bar + spawn panel, ...).
	for layer_node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		var cl := layer_node as CanvasLayer
		# (Touch sticks / buttons hide themselves while the game is paused, i.e. while this menu is up.)
		if cl == self or cl == hud or not cl.visible or cl.name == "TouchControls":
			continue
		for c in cl.find_children("*", "Control", true, false):
			var ctrl := c as Control
			if not ctrl.is_visible_in_tree() or ctrl.modulate.a < 0.05:
				continue
			var r := ctrl.get_global_rect()
			if r.size.x >= vp.x * 0.9 and r.size.y >= vp.y * 0.9:
				continue  # full-screen roots
			if ctrl is Label and (ctrl as Label).text.is_empty():
				continue
			out.append([r, 1.0])
	return out


func _process(delta: float) -> void:
	if not visible:
		return
	if _arm_t > 0.0:
		_arm_t -= delta
		if _arm_t <= 0.0:
			for c in _cards:
				c.armed = true
			_cards[0].grab_focus()
	if _auto_t > 0.0:
		_auto_t -= delta
		if _auto_t <= 0.0:
			pick(_cards[0].id)


func _on_card_pressed(card: UpgradeCard) -> void:
	if card.armed:
		pick(card.id)


## Takes an upgrade, then deals the next set of cards or closes.
func pick(id: StringName) -> void:
	Upgrades.apply(id)
	Sfx.play(&"shield", -4.0, 0.0)
	if Upgrades.pending > 0:
		_deal()
	else:
		close()


func close() -> void:
	visible = false
	Upgrades.choosing = false
	get_tree().paused = false
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech:
		mech.grant_invuln(0.8)
	closed.emit()
