class_name LobbyWidgets
extends RefCounted
## The title lobby's pieces (ui/main_menu.gd lays them out; ui/lobby_kit.gd draws the look):
##   Tile        square nav button: icon + label, optional gold badge (ARMORY / HANGAR / CUSTOMIZE / RANGE)
##   Card        operation card: real arena art behind a dark fade, kicker + title + info, arena pips or a
##               progress bar (CAMPAIGN / ENDLESS); short ones are the arena rows of the Select Arena page
##   Launch      the big gold call to action (LAUNCH + what it starts), hazard stripes, flowing chevrons
##   Upgrade     the "next Hangar upgrade" strip: scrap progress toward the cheapest upgrade
##   IconButton  small square icon button (settings, exit) that shows its name when focused
##   Chips       the resource chips in the top-right corner (scrap, best wave, weapons)
##   Unit        the mech's name plate: MOBILE UNIT / NIMBUS-07, chassis, equipped weapon + mastery
##   Frame       the glass console behind a sub-page (title header + back hint)
## Buttons light up on focus and hovering grabs focus, so mouse, touch and keyboard / gamepad all work.
## Everything slides in on entrance: `slide` 1 = shifted by `slide_from` and invisible, 0 = in place.


## Shared button behaviour: focus highlight (eased), hover grabs focus, click sound, entrance slide.
class Base extends Button:
	var slide := 0.0:
		set(v):
			slide = v
			modulate.a = 1.0 - v
			position = home + slide_from * v
	var slide_from := Vector2(90, 0)
	## Where the layout put it (position = home + the entrance offset).
	var home := Vector2.ZERO
	## Focus highlight, eased 0..1.
	var hl := 0.0
	var t := 0.0
	## Redraw every frame (idle animation), not just while the highlight changes.
	var animated := false

	func _init() -> void:
		text = ""
		flat = true
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(grab_focus)
		pressed.connect(func() -> void: Sfx.play(&"select", -8.0))
		for s in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(s, StyleBoxEmpty.new())

	## The layout's placement (top-left corner + size).
	func place(r: Rect2) -> void:
		home = r.position
		size = r.size
		position = home + slide_from * slide

	func _process(delta: float) -> void:
		t += delta
		var target := 1.0 if has_focus() else 0.0
		if not is_equal_approx(hl, target):
			hl = move_toward(hl, target, delta * 7.0)
			queue_redraw()
		elif animated and is_visible_in_tree():
			queue_redraw()

	func pressing() -> bool:
		return button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))


## Square nav tile: an icon over a label; the icon lifts and the frame glows when focused.
class Tile extends Base:
	var label := ""
	var glyph := &""
	## Gold badge text in the top-right corner ("" = none); it pulses.
	var badge := "":
		set(v):
			badge = v
			animated = v != ""
			queue_redraw()
	## Customize: the player's colours on the fan deck. Armory: the two crossed weapon arts.
	var colors: Array[Color] = []
	var arts: Array[Texture2D] = []

	func _init(txt: String, ic: StringName) -> void:
		super()
		label = txt
		glyph = ic
		slide_from = Vector2(-80, 0)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		LobbyKit.panel(self, r, 12.0, minf(hl + (0.35 if pressing() else 0.0), 1.2))
		var ir := minf(size.x, size.y) * 0.23
		var c := Vector2(size.x / 2.0, size.y * 0.43 - 3.0 * hl)
		var col := LobbyKit.DIM.lerp(Color.WHITE, 0.3 + 0.7 * hl)
		# a soft light behind the icon when focused
		if hl > 0.01:
			LobbyKit.glow_dot(self, c, ir * 2.6, Color(LobbyKit.CYAN, 0.22 * hl))
		match glyph:
			&"armory":
				LobbyKit.crossed(self, c, ir * 1.45, arts)
			&"paint":
				LobbyKit.fan(self, c, ir * 0.95, colors)
			_:
				LobbyKit.icon(self, glyph, c, ir, col, t)
		var fs := LobbyKit.fit(LobbyKit.SEMI, label, 15, size.x - 14.0)
		LobbyKit.text(self, LobbyKit.SEMI, Vector2(0, size.y - 14.0), label, fs, LobbyKit.TEXT.lerp(Color.WHITE, hl),
			HORIZONTAL_ALIGNMENT_CENTER, size.x)
		if hl > 0.01:
			var bw := (size.x - 44.0) * hl
			draw_rect(Rect2((size.x - bw) / 2.0, size.y - 7.0, bw, 2.0), Color(LobbyKit.CYAN, hl))
		if badge != "":
			LobbyKit.badge(self, Vector2(size.x - 9.0, 7.0), badge, t)


## Operation card. Tall (> 80 px): kicker, big title, info line, then arena pips or a progress bar, and a gold
## play disc on the right when focused. Short: an arena row (number box, name, CLEARED / NEXT tag).
class Card extends Base:
	var kicker := ""
	var title := ""
	var info := ""
	var art: Texture2D
	var art_focus := Vector2(0.5, 0.5)
	## One pip per arena, lit = cleared (empty = no pips).
	var pips: Array[bool] = []
	## Progress bar 0..1 under the info (< 0 = no bar) and its caption ("" = none).
	var progress := -1.0
	var progress_text := ""
	var accent := LobbyKit.CYAN
	## Row tag on the right ("" = none) and its colour.
	var tag := ""
	var tag_color := LobbyKit.GOLD

	func _init() -> void:
		super()
		animated = true

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var tall := size.y > 80.0
		var cut := 16.0 if tall else 10.0
		var pts := LobbyKit.shape(r, cut)
		var lit := clampf(hl + (0.3 if pressing() else 0.0), 0.0, 1.2)
		LobbyKit.shadow(self, pts)
		if lit > 0.01:
			LobbyKit.glow(self, pts, LobbyKit.GOLD, lit)
		# The art: dimmed at rest, brighter with a slow push-in when focused.
		LobbyKit.art(self, r, cut, art, art_focus, 1.0 + 0.07 * hl + 0.015 * sin(t * 0.5),
			Color(0.68, 0.73, 0.82).lerp(Color(1, 1, 1), 0.6 * hl))
		# A dark fade from the left so the text reads.
		LobbyKit.fill_h(self, r, cut, [[0.0, Color(LobbyKit.INK, 0.93)], [0.3 if tall else 0.26, Color(LobbyKit.INK, 0.8)],
			[0.66, Color(LobbyKit.INK, 0.16 - 0.1 * hl)], [1.0, Color(LobbyKit.INK, 0.0)]])
		_shine(pts)
		LobbyKit.frame(self, r, cut, LobbyKit.CYAN.lerp(LobbyKit.GOLD, hl), hl)
		if tall:
			_draw_tall()
		else:
			_draw_row()

	## A light band sweeping across every 6 s.
	func _shine(pts: PackedVector2Array) -> void:
		var cycle := fmod(t + get_instance_id() % 5, 6.0)
		if cycle > 0.9:
			return
		var x := lerpf(-80.0, size.x + 80.0, cycle / 0.9)
		var band := PackedVector2Array([Vector2(x - 30, size.y), Vector2(x + 10, 0), Vector2(x + 40, 0), Vector2(x, size.y)])
		for piece in Geometry2D.intersect_polygons(pts, band):
			draw_colored_polygon(piece, Color(1, 1, 1, 0.07 + 0.05 * hl))

	func _draw_tall() -> void:
		var x := 20.0
		draw_rect(Rect2(0, 16, 3, 30), accent)
		var kf := LobbyKit.tracked(LobbyKit.COND_B, 3)
		LobbyKit.text(self, kf, Vector2(x, 31), kicker, 14, accent)
		var tfs := LobbyKit.fit(LobbyKit.HEAD, title, 30, size.x - x - 60.0, 18)
		UiFont.draw_display(self, Vector2(x - 1, 67), title, tfs, Color.WHITE)
		var ifs := LobbyKit.fit(LobbyKit.COND, info, 18, size.x - x - 24.0, 13)
		LobbyKit.text(self, LobbyKit.COND, Vector2(x, 91), info, ifs, LobbyKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		var y := size.y - 22.0
		if not pips.is_empty():
			for i in pips.size():
				var c := Vector2(x + 6.0 + i * 20.0, y)
				var d := PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)])
				if pips[i]:
					LobbyKit.glow_dot(self, c, 13.0, Color(LobbyKit.GOLD, 0.35))
					draw_colored_polygon(d, LobbyKit.GOLD_HI)
				else:
					draw_colored_polygon(d, Color(0.02, 0.05, 0.12, 0.85))
				draw_polyline(LobbyKit.closed(d), Color(LobbyKit.GOLD if pips[i] else LobbyKit.DIM, 0.9), 1.2, true)
			var done := pips.count(true)
			LobbyKit.text(self, LobbyKit.COND_B, Vector2(x + pips.size() * 20.0 + 6.0, y + 5.0), "%d / %d CLEARED" % [done, pips.size()],
				14, Color(LobbyKit.DIM, 0.95))
		elif progress >= 0.0 or progress_text != "":
			# (a short card - Large text on a wide screen - has no room for it under the info line)
			if progress_text != "" and y - 3.0 - 12.0 > 91.0 + 6.0:
				var pfs := LobbyKit.fit(LobbyKit.COND_B, progress_text, 14, size.x - x - 70.0, 11)
				LobbyKit.text(self, LobbyKit.COND_B, Vector2(x, y - 3.0), progress_text, pfs, Color(LobbyKit.DIM, 0.95))
			if progress >= 0.0:
				LobbyKit.bar(self, Rect2(x, y + 3.0, minf(size.x * 0.55, size.x - x - 70.0), 5.0), progress, accent)
		# Gold play disc (slides in when focused).
		if hl > 0.01:
			var c := Vector2(size.x - 40.0 + 12.0 * (1.0 - hl), size.y / 2.0 + 6.0)
			var rr := 19.0 * (0.6 + 0.4 * hl)
			LobbyKit.glow_dot(self, c, rr * 2.2, Color(LobbyKit.GOLD, 0.45 * hl))
			draw_circle(c, rr, Color(LobbyKit.GOLD_HI, hl))
			draw_arc(c, rr, 0.0, TAU, 32, Color(1, 0.97, 0.85, hl), 1.5, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -8) * (rr / 19.0), c + Vector2(9, 0) * (rr / 19.0),
				c + Vector2(-5, 8) * (rr / 19.0)]), Color(LobbyKit.NAVY, hl))

	func _draw_row() -> void:
		var box := Rect2(10, (size.y - 30.0) / 2.0, 30, 30)
		draw_rect(box, Color(0.02, 0.05, 0.12, 0.9))
		draw_rect(box, Color(LobbyKit.CYAN.lerp(LobbyKit.GOLD, hl), 0.8), false, 1.5)
		LobbyKit.text(self, LobbyKit.HEAD, Vector2(box.position.x, box.end.y - 8.0), kicker, 17, Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		var tw := LobbyKit.width_of(LobbyKit.COND_B, tag, 13) + 16.0 if tag != "" else 0.0
		var x := box.end.x + 12.0
		var fs := LobbyKit.fit(LobbyKit.SEMI, title, 19, size.x - x - tw - 22.0, 13)
		LobbyKit.text(self, LobbyKit.SEMI, Vector2(x + 4.0 * hl, size.y / 2.0 + 7.0), title, fs, LobbyKit.TEXT.lerp(Color.WHITE, hl),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		if tag != "":
			var tr := Rect2(size.x - tw - 14.0, (size.y - 20.0) / 2.0, tw, 20.0)
			draw_rect(tr, Color(tag_color, 0.2))
			draw_rect(tr, Color(tag_color, 0.85), false, 1.2)
			LobbyKit.text(self, LobbyKit.COND_B, Vector2(tr.position.x, tr.end.y - 5.0), tag, 13, tag_color.lightened(0.3),
				HORIZONTAL_ALIGNMENT_CENTER, tr.size.x)


## The gold call to action: LAUNCH + what it starts. Breathing glow, hazard stripes at the left end, a light
## sweep every few seconds and chevrons flowing to the right.
class Launch extends Base:
	var title := "LAUNCH"
	var sub := ""

	func _init() -> void:
		super()
		animated = true

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var cut := 20.0
		var pts := LobbyKit.shape(r, cut)
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		var press := pressing()
		LobbyKit.shadow(self, pts, 1.3)
		LobbyKit.glow(self, pts, LobbyKit.GOLD_HI, 0.55 + 0.35 * pulse + 0.4 * hl)
		var lift := 0.1 * hl + (0.14 if press else 0.0)
		LobbyKit.fill_v(self, pts, r, LobbyKit.GOLD_HI.lightened(lift), LobbyKit.GOLD_LO.lightened(lift))
		# Hazard stripes (navy) across the left end, like a launch catapult.
		var sw := 60.0
		for i in 7:
			var x := -24.0 + i * 16.0
			var stripe := PackedVector2Array([Vector2(x, size.y), Vector2(x + size.y * 0.5, 0), Vector2(x + size.y * 0.5 + 8.0, 0),
				Vector2(x + 8.0, size.y)])
			for piece in Geometry2D.intersect_polygons(pts, stripe):
				for clipped in Geometry2D.intersect_polygons(piece, PackedVector2Array([Vector2(0, 0), Vector2(sw, 0),
						Vector2(sw, size.y), Vector2(0, size.y)])):
					draw_colored_polygon(clipped, Color(LobbyKit.NAVY, 0.82))
		draw_line(Vector2(sw, 6), Vector2(sw, size.y - 6), Color(LobbyKit.NAVY, 0.5), 2.0)
		# Sheen along the top and a darker lip along the bottom.
		draw_line(Vector2(sw + 4, 2.5), Vector2(size.x - cut - 2, 2.5), Color(1, 1, 1, 0.5), 2.0)
		draw_line(Vector2(cut + 2, size.y - 2.5), Vector2(size.x - 3, size.y - 2.5), Color(0.45, 0.25, 0.0, 0.45), 2.0)
		# Light sweep every 3.4 s.
		var cycle := fmod(t, 3.4)
		if cycle < 0.75:
			var x := lerpf(-80.0, size.x + 80.0, cycle / 0.75)
			var band := PackedVector2Array([Vector2(x - 26, size.y), Vector2(x + 14, 0), Vector2(x + 44, 0), Vector2(x + 4, size.y)])
			for piece in Geometry2D.intersect_polygons(pts, band):
				draw_colored_polygon(piece, Color(1, 1, 1, 0.4))
		draw_polyline(LobbyKit.closed(pts), Color(1.0, 0.97, 0.82, 0.95), 1.5 + hl, true)
		# Title + what it starts.
		var x := sw + 18.0
		var tfs := LobbyKit.fit(LobbyKit.HEAD, title, 42 if size.y >= 88.0 else 36, size.x - x - 110.0, 22)
		LobbyKit.text(self, LobbyKit.HEAD, Vector2(x, size.y * 0.5 + 9.0), title, tfs, LobbyKit.NAVY)
		var sfs := LobbyKit.fit(LobbyKit.COND_B, sub, 17, size.x - x - 30.0, 11)
		LobbyKit.text(self, LobbyKit.COND_B, Vector2(x + 1, size.y * 0.5 + 31.0), sub, sfs, Color(LobbyKit.NAVY, 0.78))
		# Chevrons flowing right.
		var cx := size.x - 96.0
		for i in 3:
			var f := fmod(t * 1.6 + i / 3.0, 1.0)
			var a := sin(f * PI)
			var p := Vector2(cx + f * 46.0, size.y * 0.5 - 6.0)
			draw_polyline(PackedVector2Array([p + Vector2(-7, -13), p + Vector2(7, 0), p + Vector2(-7, 13)]),
				Color(LobbyKit.NAVY, 0.85 * a), 4.0, true)


## The next Hangar upgrade: what it is, its cost and a scrap bar toward it. Glows gold when one is affordable.
class Upgrade extends Base:
	var item := ""
	var cost := 0
	var have := 0
	## How many Hangar upgrades the player can afford right now.
	var ready_count := 0

	func _init() -> void:
		super()
		animated = true

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var is_ready := ready_count > 0
		var accent := LobbyKit.GOLD if is_ready else LobbyKit.CYAN
		var idle := (0.3 + 0.25 * sin(t * 4.0)) if is_ready else 0.0
		LobbyKit.panel(self, r, 12.0, clampf(maxf(hl, idle) + (0.3 if pressing() else 0.0), 0.0, 1.2), accent)
		var box := Rect2(12, (size.y - 38.0) / 2.0, 38, 38)
		draw_rect(box, Color(accent, 0.16 + 0.1 * hl))
		draw_rect(box, Color(accent, 0.75), false, 1.5)
		LobbyKit.icon(self, &"wrench", box.get_center(), 13.0, accent.lightened(0.35), t)
		var x := box.end.x + 12.0
		var kicker := ("UPGRADE READY" + ("  x%d" % ready_count if ready_count > 1 else "")) if is_ready else "NEXT HANGAR UPGRADE"
		LobbyKit.text(self, LobbyKit.tracked(LobbyKit.COND_B, 2), Vector2(x, 21), kicker, 13, accent.lightened(0.15))
		var cost_txt := Game.fmt_int(cost)
		var cw := LobbyKit.width_of(LobbyKit.COND_XB, cost_txt, 20)
		var fs := LobbyKit.fit(LobbyKit.SEMI, item, 17, size.x - x - cw - 50.0, 12)
		LobbyKit.text(self, LobbyKit.SEMI, Vector2(x, 41), item, fs, LobbyKit.TEXT.lerp(Color.WHITE, hl))
		var right := size.x - 16.0
		LobbyKit.text(self, LobbyKit.COND_XB, Vector2(right - cw, 40), cost_txt, 20, LobbyKit.GOLD if is_ready else LobbyKit.TEXT)
		LobbyKit.nut(self, Vector2(right - cw - 13.0, 33.0), 7.0, t * 1.2)
		LobbyKit.bar(self, Rect2(x, size.y - 12.0, size.x - x - 16.0, 4.0), float(have) / maxf(cost, 1), accent)


## Small square icon button (settings, exit); its name appears under it when focused.
class IconButton extends Base:
	var glyph := &""
	var tip := ""

	func _init(ic: StringName, tp: String) -> void:
		super()
		glyph = ic
		tip = tp
		slide_from = Vector2(0, -50)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		LobbyKit.panel(self, r, 9.0, clampf(hl + (0.35 if pressing() else 0.0), 0.0, 1.2))
		LobbyKit.icon(self, glyph, size / 2.0, size.y * 0.28, LobbyKit.DIM.lerp(Color.WHITE, 0.35 + 0.65 * hl), t * hl * 2.0)
		if hl > 0.01:
			LobbyKit.text(self, LobbyKit.COND_B, Vector2(-30, size.y + 17.0), tip, 13, Color(LobbyKit.TEXT, hl),
				HORIZONTAL_ALIGNMENT_CENTER, size.x + 60.0, 4)


## The resource chips in the top-right corner, right-aligned in the control: a slanted plate per item with an
## icon box, a small label and a big value. items = [{icon, label, value, color}].
class Chips extends Control:
	const H := 42.0
	const GAP := 10.0
	var items: Array[Dictionary] = []
	var home := Vector2.ZERO
	var slide := 0.0:
		set(v):
			slide = v
			modulate.a = 1.0 - v
			position = home + Vector2(0, -50) * v
	var _t := 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func place(r: Rect2) -> void:
		home = r.position
		size = r.size
		position = home + Vector2(0, -50) * slide

	## The width all the chips need.
	func needed_width() -> float:
		var w := 0.0
		for it in items:
			w += _chip_w(it) + GAP
		return maxf(w - GAP, 0.0)

	func _chip_w(it: Dictionary) -> float:
		return 50.0 + maxf(LobbyKit.width_of(LobbyKit.tracked(LobbyKit.COND_B, 1), it["label"], 11),
			LobbyKit.width_of(LobbyKit.COND_XB, it["value"], 22)) + 18.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var x := size.x
		for i in range(items.size() - 1, -1, -1):
			var it: Dictionary = items[i]
			var w := _chip_w(it)
			x -= w
			_chip(x, w, it)
			x -= GAP

	func _chip(x: float, w: float, it: Dictionary) -> void:
		var s := 9.0
		var col: Color = it["color"]
		var plate := PackedVector2Array([Vector2(x + s, 0), Vector2(x + w, 0), Vector2(x + w - s, H), Vector2(x, H)])
		var shadow := PackedVector2Array()
		for p in plate:
			shadow.append(p + Vector2(0, 4))
		draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
		draw_polygon(plate, PackedColorArray([Color(0.07, 0.13, 0.26, 0.86), Color(0.07, 0.13, 0.26, 0.86),
			Color(0.012, 0.025, 0.07, 0.92), Color(0.012, 0.025, 0.07, 0.92)]))
		var box := PackedVector2Array([Vector2(x + s, 0), Vector2(x + s + 36, 0), Vector2(x + 36, H), Vector2(x, H)])
		draw_colored_polygon(box, Color(col, 0.2))
		draw_line(Vector2(x + s + 36, 0), Vector2(x + 36, H), Color(col, 0.55), 1.0, true)
		draw_polyline(LobbyKit.closed(plate), Color(col, 0.55), 1.0, true)
		draw_line(Vector2(x + s + 2, 1.5), Vector2(x + w - 2, 1.5), Color(1, 1, 1, 0.1), 1.0)
		var ic := Vector2(x + 22.0, H / 2.0)
		if it["icon"] == &"nut":
			LobbyKit.nut(self, ic, 9.5, _t * 1.2)
		else:
			LobbyKit.icon(self, it["icon"], ic, 9.5, col.lightened(0.3), _t)
		var tx := x + 48.0
		LobbyKit.text(self, LobbyKit.tracked(LobbyKit.COND_B, 1), Vector2(tx, 15.0), it["label"], 11, Color(LobbyKit.DIM, 0.95))
		LobbyKit.text(self, LobbyKit.COND_XB, Vector2(tx, 36.0), it["value"], 22, Color.WHITE.lerp(col, 0.25))


## The mech's name plate (bottom left in landscape): MOBILE UNIT / the selected frame's name (`mech_name`), its
## role on the tag (`chassis`, e.g. STANDARD FRAME), and the equipped
## weapon's art, name and mastery bar.
class Unit extends Control:
	var chassis := ""
	## The mech's display name (the selected chassis' "name": NIMBUS-07, ARROWHEAD...).
	var mech_name := "NIMBUS-07"
	var chassis_color := LobbyKit.CYAN
	var weapon := ""
	var weapon_art: Texture2D
	var mastery := 0
	var mastery_f := 0.0
	var mastered := false
	var home := Vector2.ZERO
	var slide := 0.0:
		set(v):
			slide = v
			modulate.a = 1.0 - v
			position = home + Vector2(-80, 0) * v

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func place(r: Rect2) -> void:
		home = r.position
		size = r.size
		position = home + Vector2(-80, 0) * slide
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		LobbyKit.panel(self, r, 14.0)
		draw_rect(Rect2(0, 14, 3, 40), LobbyKit.GOLD)
		var uf := LobbyKit.tracked(LobbyKit.COND_B, 3)
		LobbyKit.text(self, uf, Vector2(16, 23), "MOBILE UNIT", 13, LobbyKit.CYAN)
		# chassis tag (top right)
		var cfs := 13
		var cw := LobbyKit.width_of(LobbyKit.COND_B, chassis, cfs) + 14.0
		var tag := Rect2(size.x - cw - 22.0, 10, cw, 19)
		draw_rect(tag, Color(chassis_color, 0.16))
		draw_rect(tag, Color(chassis_color, 0.8), false, 1.0)
		LobbyKit.text(self, LobbyKit.COND_B, Vector2(tag.position.x, tag.end.y - 5.0), chassis, cfs, chassis_color.lightened(0.25),
			HORIZONTAL_ALIGNMENT_CENTER, tag.size.x)
		var nfs := LobbyKit.fit(LobbyKit.HEAD, mech_name, 26, size.x - 40.0, 16)
		UiFont.draw_display(self, Vector2(15, 55), mech_name, nfs, Color.WHITE)
		draw_line(Vector2(16, 64), Vector2(size.x - 16, 64), Color(LobbyKit.CYAN, 0.25), 1.0)
		# equipped weapon: art lying flat (muzzle / tip to the right), name, mastery
		var wy := 64.0 + (size.y - 64.0) / 2.0
		if weapon_art:
			var ts := weapon_art.get_size()
			var s := minf(88.0 / ts.y, 26.0 / ts.x)
			draw_set_transform(Vector2(56, wy), PI / 2.0, Vector2(s, s))
			draw_texture(weapon_art, -ts / 2.0)
			draw_set_transform(Vector2.ZERO)
		var x := 108.0
		var wfs := LobbyKit.fit(LobbyKit.SEMI, weapon, 15, size.x - x - 16.0, 11)
		LobbyKit.text(self, LobbyKit.SEMI, Vector2(x, wy - 3.0), weapon, wfs, LobbyKit.TEXT)
		var mtxt := "MASTERED" if mastered else "MASTERY LV %d" % mastery
		var mcol := LobbyKit.GOLD if mastered or mastery > 0 else LobbyKit.DIM
		LobbyKit.text(self, LobbyKit.COND_B, Vector2(x, wy + 17.0), mtxt, 13, mcol)
		var bx := x + LobbyKit.width_of(LobbyKit.COND_B, mtxt, 13) + 10.0
		LobbyKit.bar(self, Rect2(bx, wy + 8.0, size.x - bx - 16.0, 5.0), 1.0 if mastered else mastery_f, LobbyKit.GOLD, 0)


## The glass console behind a sub-page: a title header with a gold accent and a back hint, the page's buttons
## sit in a VBox below it (ui/main_menu.gd sizes it to the page).
class Frame extends Control:
	const HEADER := 54.0
	const PAD := 20.0
	var title := ""

	func _init(txt: String) -> void:
		title = txt
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		LobbyKit.panel(self, r, 18.0, 0.0, LobbyKit.CYAN, 1.05)
		LobbyKit.fill_h(self, Rect2(0, 0, size.x, HEADER), 0.0, [[0.0, Color(0.12, 0.26, 0.5, 0.45)], [0.7, Color(0.12, 0.26, 0.5, 0.08)],
			[1.0, Color(0.12, 0.26, 0.5, 0.0)]])
		draw_rect(Rect2(0, 13, 4, 28), LobbyKit.GOLD)
		var tfs := LobbyKit.fit(LobbyKit.HEAD, title, 22, size.x - 2.0 * PAD - 120.0, 14)
		UiFont.draw_display(self, Vector2(PAD, 37), title, tfs, Color.WHITE)
		var hint := "ESC  BACK"
		LobbyKit.text(self, LobbyKit.tracked(LobbyKit.COND_B, 2), Vector2(size.x - PAD - 18.0 - LobbyKit.width_of(
			LobbyKit.tracked(LobbyKit.COND_B, 2), hint, 12), 33), hint, 12, Color(LobbyKit.DIM, 0.8))
		draw_line(Vector2(PAD, HEADER), Vector2(size.x - PAD, HEADER), Color(LobbyKit.CYAN, 0.35), 1.0)
		for i in 3:
			draw_rect(Rect2(size.x - PAD - 6.0 - i * 9.0, HEADER - 3.0, 5, 5), Color(LobbyKit.CYAN, 0.6 - i * 0.15))
