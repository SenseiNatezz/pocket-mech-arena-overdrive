class_name LobbyKit
extends RefCounted
## The title lobby's look (ui/main_menu.gd builds the screen, ui/lobby_widgets.gd has the pieces): fonts,
## colours, the cut-corner glass panel, real art clipped into a panel, gradients, progress bars, badges and the
## vector icons. All drawn in code (the only textures are the game's own art), so it stays sharp at any size.
## Fonts: Chakra Petch (titles, buttons) + Barlow Condensed (labels, numbers), SIL OFL (assets/fonts/OFL.txt).

const HEAD := preload("res://assets/fonts/ChakraPetch-Bold.ttf")
const SEMI := preload("res://assets/fonts/ChakraPetch-SemiBold.ttf")
const COND := preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const COND_B := preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
const COND_XB := preload("res://assets/fonts/BarlowCondensed-ExtraBold.ttf")
const GLOW := preload("res://assets/fx/glow.tres")

const CYAN := Color(0.35, 0.78, 1.0)
const GOLD := Color(1.0, 0.8, 0.3)
const GOLD_HI := Color(1.0, 0.87, 0.45)
const GOLD_LO := Color(0.88, 0.56, 0.12)
const NAVY := Color(0.04, 0.06, 0.13)
const INK := Color(0.012, 0.025, 0.07)
const TEXT := Color(0.9, 0.95, 1.0)
const DIM := Color(0.6, 0.72, 0.86)

static var _tracked := {}


## `font` with `px` extra pixels between letters (small caps labels).
static func tracked(font: Font, px: int) -> Font:
	var key := "%d:%d" % [font.get_instance_id(), px]
	if not _tracked.has(key):
		var v := FontVariation.new()
		v.base_font = font
		v.spacing_glyph = px
		_tracked[key] = v
	return _tracked[key]


# --- shapes -------------------------------------------------------------------------------------------------

## The lobby's panel shape: a box with its top-right and bottom-left corners cut off by `cut`.
static func shape(r: Rect2, cut: float) -> PackedVector2Array:
	var p := r.position
	var s := r.size
	return PackedVector2Array([p, p + Vector2(s.x - cut, 0), p + Vector2(s.x, cut), p + s, p + Vector2(cut, s.y),
		p + Vector2(0, s.y - cut)])


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var c := pts.duplicate()
	c.append(pts[0])
	return c


## `pts` grown outward by `d` pixels (mitred corners), for glows.
static func grown(pts: PackedVector2Array, d: float) -> PackedVector2Array:
	var g := Geometry2D.offset_polygon(pts, d, Geometry2D.JOIN_MITER)
	return g[0] if not g.is_empty() else pts


## Fills `pts` (inside the box `r`) top to bottom from `top` to `bottom`. The colours follow y exactly, so the
## cut corners need no extra vertices.
static func fill_v(ci: CanvasItem, pts: PackedVector2Array, r: Rect2, top: Color, bottom: Color) -> void:
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)))
	ci.draw_polygon(pts, cols)


## Fills the cut-corner box left to right through `stops` ([[x fraction, Color], ...], sorted, with 0 and 1):
## vertical strips between the stops whose ends follow the cut corners.
static func fill_h(ci: CanvasItem, r: Rect2, cut: float, stops: Array) -> void:
	var w := r.size.x
	var xs: Array[float] = []
	for s in stops:
		xs.append(float(s[0]) * w)
	for k in [cut, w - cut]:
		if k > 0.0 and k < w and not xs.has(k):
			xs.append(k)
	xs.sort()
	for i in xs.size() - 1:
		var x0 := xs[i]
		var x1 := xs[i + 1]
		if x1 - x0 < 0.01:
			continue
		var c0 := _stop(stops, x0 / w)
		var c1 := _stop(stops, x1 / w)
		ci.draw_polygon(PackedVector2Array([
			r.position + Vector2(x0, _cut_top(x0, w, cut)), r.position + Vector2(x1, _cut_top(x1, w, cut)),
			r.position + Vector2(x1, _cut_bottom(x1, r.size.y, cut)), r.position + Vector2(x0, _cut_bottom(x0, r.size.y, cut))]),
			PackedColorArray([c0, c1, c1, c0]))


static func _cut_top(x: float, w: float, cut: float) -> float:
	return maxf(0.0, x - (w - cut))


static func _cut_bottom(x: float, h: float, cut: float) -> float:
	return h - maxf(0.0, cut - x)


static func _stop(stops: Array, f: float) -> Color:
	for i in stops.size() - 1:
		var a: float = stops[i][0]
		var b: float = stops[i + 1][0]
		if f <= b:
			return (stops[i][1] as Color).lerp(stops[i + 1][1], clampf((f - a) / maxf(b - a, 0.0001), 0.0, 1.0))
	return stops[-1][1]


## `tex` scaled to cover the cut-corner box `r` and clipped to it. `focus` picks the part of the art that shows
## (0.5, 0.5 = the middle), `zoom` > 1 crops in.
static func art(ci: CanvasItem, r: Rect2, cut: float, tex: Texture2D, focus := Vector2(0.5, 0.5), zoom := 1.0,
		mod := Color.WHITE) -> void:
	if tex == null:
		return
	var ts := tex.get_size()
	var k := maxf(r.size.x / ts.x, r.size.y / ts.y) * zoom
	var view := r.size / k
	var origin := ((ts - view) * focus).clamp(Vector2.ZERO, (ts - view).max(Vector2.ZERO))
	var pts := shape(r, cut)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append((origin + (p - r.position) / k) / ts)
	ci.draw_colored_polygon(pts, mod, uvs, tex)


# --- panels -------------------------------------------------------------------------------------------------

## The glass panel: a soft shadow, a dark-blue gradient body (lighter when highlighted), a sheen line along the
## top, a thin frame and two corner ticks. `hl` 0..1 = highlighted (focus / hover); `accent` = frame + glow.
static func panel(ci: CanvasItem, r: Rect2, cut: float, hl := 0.0, accent := CYAN, body := 1.0) -> void:
	var pts := shape(r, cut)
	shadow(ci, pts)
	if hl > 0.01:
		glow(ci, pts, accent, hl)
	var k := clampf(hl, 0.0, 1.0)
	fill_v(ci, pts, r, Color(0.07, 0.13, 0.26, 0.8 * body).lerp(Color(0.1, 0.24, 0.47, 0.92), k),
		Color(0.012, 0.025, 0.07, 0.88 * body).lerp(Color(0.03, 0.09, 0.21, 0.95), k))
	frame(ci, r, cut, accent, k)


## Two stacked drop shadows under `pts`.
static func shadow(ci: CanvasItem, pts: PackedVector2Array, a := 1.0) -> void:
	for i in 2:
		var off := Vector2(0, 3 + i * 4)
		var sh := PackedVector2Array()
		for p in pts:
			sh.append(p + off)
		ci.draw_colored_polygon(sh, Color(0, 0, 0, (0.26 - 0.11 * i) * a))


## A soft outer glow around `pts`: three widening rings.
static func glow(ci: CanvasItem, pts: PackedVector2Array, col: Color, k := 1.0) -> void:
	for i in 3:
		ci.draw_polyline(closed(grown(pts, 2.0 + i * 3.0)), Color(col, (0.32 - i * 0.09) * k), 3.0, true)


## The panel frame: a sheen line along the top, a thin outline and accent ticks on the two square corners.
static func frame(ci: CanvasItem, r: Rect2, cut: float, accent: Color, hl := 0.0) -> void:
	var p := r.position
	var s := r.size
	ci.draw_line(p + Vector2(4, 1.5), p + Vector2(s.x - cut - 2, 1.5), Color(1, 1, 1, 0.08 + 0.1 * hl), 1.5)
	ci.draw_polyline(closed(shape(r, cut)), Color(accent, 0.3 + 0.6 * hl), 1.0 + 1.2 * hl, true)
	var t := 9.0 + 7.0 * hl
	var c := Color(accent.lightened(0.25), 0.7 + 0.3 * hl)
	ci.draw_polyline(PackedVector2Array([p + Vector2(0, t), p, p + Vector2(t, 0)]), c, 2.0)
	ci.draw_polyline(PackedVector2Array([p + s - Vector2(0, t), p + s, p + s - Vector2(t, 0)]), c, 2.0)


# --- text, bars, badges -------------------------------------------------------------------------------------

## A string with an optional dark outline. `align` + `width` as in draw_string.
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, fs: int, col: Color,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0) -> void:
	if outline > 0:
		ci.draw_string_outline(font, pos, s, align, width, fs, outline, Color(0, 0.01, 0.04, 0.75 * col.a))
	ci.draw_string(font, pos, s, align, width, fs, col)


## The largest size <= `fs` (down to `min_fs`) at which `s` fits in `width` pixels.
static func fit(font: Font, s: String, fs: int, width: float, min_fs := 10) -> int:
	while fs > min_fs and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	return fs


static func width_of(font: Font, s: String, fs: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x


## A slim progress bar: dark track, `col` fill with a bright leading edge, optional segment ticks.
static func bar(ci: CanvasItem, r: Rect2, f: float, col: Color, segments := 0) -> void:
	ci.draw_rect(r, Color(0, 0.02, 0.06, 0.8))
	var w := r.size.x * clampf(f, 0.0, 1.0)
	if w > 0.5:
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), col)
		ci.draw_rect(Rect2(r.position, Vector2(w, maxf(1.0, r.size.y * 0.4))), Color(1, 1, 1, 0.28))
		if w > 3.0:
			ci.draw_rect(Rect2(r.position + Vector2(w - 2.0, 0), Vector2(2.0, r.size.y)), col.lightened(0.65))
	for i in range(1, segments):
		var x := r.position.x + r.size.x * i / segments
		ci.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0.02, 0.06, 0.95), 1.0)
	ci.draw_rect(r, Color(col, 0.35), false, 1.0)


## A pulsing gold notification badge centred on `c` (a circle, or a pill for longer text).
static func badge(ci: CanvasItem, c: Vector2, s: String, t: float) -> void:
	var fs := 15
	var tw := width_of(COND_XB, s, fs)
	var r := 11.0
	var half := maxf(0.0, (tw - 10.0) / 2.0)
	var k := 1.0 + 0.07 * sin(t * 5.0)
	glow_dot(ci, c, 26.0 * k, Color(GOLD, 0.4))
	var pill := PackedVector2Array()
	for i in 13:
		pill.append(c + Vector2(half, 0) + Vector2.from_angle(-PI / 2 + PI * i / 12.0) * r * k)
	for i in 13:
		pill.append(c - Vector2(half, 0) + Vector2.from_angle(PI / 2 + PI * i / 12.0) * r * k)
	ci.draw_colored_polygon(pill, GOLD_HI)
	ci.draw_polyline(closed(pill), Color(1, 0.97, 0.85), 1.5, true)
	text(ci, COND_XB, c + Vector2(-tw / 2.0, 5.5), s, fs, NAVY)


## A soft additive-looking glow dot (the shared glow texture, tinted).
static func glow_dot(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_texture_rect(GLOW, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


# --- icons --------------------------------------------------------------------------------------------------

## Vector icons about 2 * r across, centred on `c`: gear, power, wrench, hangar (gear + wrench), target, trophy,
## sword, nut (scrap), chevron.
static func icon(ci: CanvasItem, id: StringName, c: Vector2, r: float, col: Color, t := 0.0) -> void:
	var w := maxf(1.8, r * 0.17)
	match id:
		&"gear":
			gear(ci, c, r, col, t * 0.25)
		&"power":
			ci.draw_arc(c + Vector2(0, r * 0.08), r * 0.72, -PI / 2 + 0.62, -PI / 2 + TAU - 0.62, 28, col, w * 1.2, true)
			ci.draw_line(c + Vector2(0, -r * 0.95), c + Vector2(0, -r * 0.05), col, w * 1.2, true)
		&"wrench":
			wrench(ci, c, r, col)
		&"hangar":
			gear(ci, c + Vector2(-r * 0.3, r * 0.22), r * 0.68, Color(col, col.a * 0.55), t * 0.25)
			wrench(ci, c + Vector2(r * 0.12, -r * 0.08), r * 0.95, col)
		&"target":
			ci.draw_arc(c, r * 0.8, 0.0, TAU, 40, col, w, true)
			ci.draw_arc(c, r * 0.4, 0.0, TAU, 28, Color(col, col.a * 0.8), w * 0.8, true)
			ci.draw_circle(c, r * 0.12, col)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * r * 0.58, c + d * r * 1.12, col, w, true)
		&"trophy":
			var cup := PackedVector2Array([c + Vector2(-0.56, -0.82) * r, c + Vector2(0.56, -0.82) * r,
				c + Vector2(0.5, -0.3) * r, c + Vector2(0.24, 0.06) * r, c + Vector2(-0.24, 0.06) * r,
				c + Vector2(-0.5, -0.3) * r])
			ci.draw_colored_polygon(cup, col)
			ci.draw_arc(c + Vector2(-0.56, -0.5) * r, r * 0.24, PI * 0.5, PI * 1.5, 12, col, w, true)
			ci.draw_arc(c + Vector2(0.56, -0.5) * r, r * 0.24, -PI * 0.5, PI * 0.5, 12, col, w, true)
			ci.draw_rect(Rect2(c + Vector2(-0.1, 0.04) * r, Vector2(0.2, 0.42) * r), col)
			ci.draw_rect(Rect2(c + Vector2(-0.44, 0.44) * r, Vector2(0.88, 0.2) * r), col)
		&"sword":
			var d := Vector2(1, -1).normalized()
			var n := Vector2(d.y, -d.x)
			var guard := c - d * r * 0.3
			ci.draw_colored_polygon(PackedVector2Array([guard + n * r * 0.13, c + d * r * 0.72 + n * r * 0.1,
				c + d * r * 0.98, c + d * r * 0.72 - n * r * 0.1, guard - n * r * 0.13]), col)
			ci.draw_line(guard + n * r * 0.38, guard - n * r * 0.38, col, w * 1.2, true)
			ci.draw_line(guard, c - d * r * 0.78, col, w * 1.1, true)
			ci.draw_circle(c - d * r * 0.86, r * 0.11, col)
		&"nut":
			nut(ci, c, r, t)
		&"chevron":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.35, -0.7) * r, c + Vector2(0.35, 0) * r,
				c + Vector2(-0.35, 0.7) * r]), col, w * 1.3, true)


## A cog: eight teeth and a dark hub.
static func gear(ci: CanvasItem, c: Vector2, r: float, col: Color, spin := 0.0) -> void:
	var pts := PackedVector2Array()
	for k in 8:
		var a := spin + TAU * k / 8.0
		for p: Vector2 in [Vector2(a - 0.3, 0.74), Vector2(a - 0.15, 1.0), Vector2(a + 0.15, 1.0), Vector2(a + 0.3, 0.74)]:
			pts.append(c + Vector2.from_angle(p.x) * r * p.y)
	ci.draw_colored_polygon(pts, col)
	ci.draw_circle(c, r * 0.36, Color(0.02, 0.05, 0.12, col.a))
	ci.draw_arc(c, r * 0.36, 0.0, TAU, 20, Color(col, col.a * 0.6), 1.2, true)


## An open-end wrench leaning 45 degrees, jaw at the top right.
static func wrench(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var d := Vector2(1, -1).normalized()
	var head := c + d * r * 0.5
	ci.draw_line(c - d * r * 0.9, head - d * r * 0.18, col, r * 0.26, true)
	ci.draw_circle(c - d * r * 0.9, r * 0.15, col)
	var ang := d.angle()
	ci.draw_arc(head, r * 0.26, ang + 0.8, ang + TAU - 0.8, 18, col, r * 0.22, true)


## The scrap icon: a gold hex nut (same as the chips robots drop and the HUD ticker).
static func nut(ci: CanvasItem, p: Vector2, r: float, spin := 0.0) -> void:
	var dark := Color(0.42, 0.27, 0.05)
	var hex := PackedVector2Array()
	for i in 6:
		hex.append(p + Vector2.from_angle(spin + i * TAU / 6.0) * r)
	ci.draw_colored_polygon(hex, GOLD)
	ci.draw_colored_polygon(PackedVector2Array([p, hex[0], hex[1]]), GOLD.lightened(0.45))
	ci.draw_colored_polygon(PackedVector2Array([p, hex[3], hex[4]]), GOLD.darkened(0.25))
	ci.draw_polyline(closed(hex), dark, 1.2, true)
	ci.draw_circle(p, r * 0.36, dark)


## Two weapon arts crossed in an X (the Armory tile): `arts` = [left-leaning, right-leaning].
static func crossed(ci: CanvasItem, c: Vector2, r: float, arts: Array[Texture2D]) -> void:
	for i in mini(arts.size(), 2):
		var tex := arts[i]
		if tex == null:
			continue
		var ts := tex.get_size()
		var s := minf(r * 2.3 / ts.y, r * 0.75 / ts.x)
		ci.draw_set_transform(c, -0.72 if i == 0 else 0.72, Vector2(s, s))
		ci.draw_texture(tex, -ts / 2.0)
	ci.draw_set_transform(Vector2.ZERO)


## A paint fan deck in the player's colours (the Customize tile): three chips fanned from a pivot below.
static func fan(ci: CanvasItem, c: Vector2, r: float, cols: Array[Color]) -> void:
	var pivot := c + Vector2(0, r * 0.95)
	for i in cols.size():
		var a := (float(i) - (cols.size() - 1) / 2.0) * 0.5
		var u := Vector2.UP.rotated(a)
		var n := Vector2(-u.y, u.x)
		var b := pivot + u * r * 0.15
		var tip := pivot + u * r * 1.85
		var chip := PackedVector2Array([b - n * r * 0.26, b + n * r * 0.26, tip + n * r * 0.3, tip - n * r * 0.3])
		ci.draw_colored_polygon(chip, cols[i])
		ci.draw_colored_polygon(PackedVector2Array([tip - n * r * 0.3, tip + n * r * 0.3, tip + n * r * 0.29 - u * r * 0.22,
			tip - n * r * 0.29 - u * r * 0.22]), Color(1, 1, 1, 0.3))
		ci.draw_polyline(closed(chip), Color(0.01, 0.02, 0.06, 0.9), 1.5, true)
	ci.draw_circle(pivot + Vector2(0, -r * 0.02), r * 0.1, Color(0.85, 0.9, 1.0))
