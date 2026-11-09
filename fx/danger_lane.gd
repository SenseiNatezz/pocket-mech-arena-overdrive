class_name DangerLane
## Attack warnings for dashes and charges (Warden ram, Ronin / Shogun dash-slash, Blade Striker dash),
## drawn in code - instead of a flat translucent bar: just the lane's two thin edge lines, chevrons
## marching along it toward where the attack will go, a timing sweep that runs from the attacker to the
## end as the wind-up runs out (the attack lands when it gets there), and a bracket at the far end.
##   DangerLane.draw(ci, from, to, half_width, k, t, col)
##     ci = the attacker (draws in its local space), from / to = lane start / end (local), k = wind-up
##     progress 0..1, t = a running clock (seconds) for the chevrons and the blink, col = warning colour.

static func draw(ci: CanvasItem, from: Vector2, to: Vector2, half_w: float, k: float, t: float, col: Color) -> void:
	var len := from.distance_to(to)
	if len < 4.0:
		return
	var d := (to - from) / len
	var n := d.orthogonal() * half_w
	var blink := 0.75 + 0.25 * sin(t * 18.0)
	# Edge lines, fading out toward the far end; brighter on the part the timing sweep has passed.
	var seg := 12
	for i in seg:
		var a := float(i) / seg
		var b := float(i + 1) / seg
		var passed := a < k
		var alpha := (0.75 - 0.45 * a) * blink * (1.0 if passed else 0.55)
		var w := 2.2 if passed else 1.4
		for s in [-1.0, 1.0]:
			ci.draw_line(from + d * len * a + n * s, from + d * len * b + n * s, Color(col, alpha), w, true)
	# Chevrons marching toward the target.
	var gap := clampf(half_w * 1.6, 34.0, 120.0)
	var cw := half_w * 0.62
	var ch := minf(cw * 0.7, gap * 0.45)
	var off := fmod(t * gap * 2.2, gap)
	var x := off + gap * 0.5
	while x < len - ch:
		var p := from + d * x
		var fade := clampf(x / (gap * 0.8), 0.0, 1.0) * clampf((len - x) / (gap * 1.2), 0.0, 1.0)
		var a := (0.5 + 0.35 * (1.0 if x / len < k else 0.0)) * fade
		var tip := p + d * ch
		var thick := d * clampf(ch * 0.45, 3.0, 9.0)
		ci.draw_colored_polygon(PackedVector2Array([p - d.orthogonal() * cw, tip, p + d.orthogonal() * cw,
			p + d.orthogonal() * cw - thick, tip - thick, p - d.orthogonal() * cw - thick]), Color(col.lightened(0.15), a))
		x += gap
	# Timing sweep: a bright bar across the lane moving from the attacker to the end.
	var sp := from + d * len * clampf(k, 0.0, 1.0)
	ci.draw_line(sp - n * 1.15, sp + n * 1.15, Color(col.lightened(0.4), 0.85 * blink), 3.0, true)
	# End bracket.
	var e := to
	ci.draw_line(e - n * 1.2, e + n * 1.2, Color(col, 0.8 * blink), 2.5, true)
	ci.draw_line(e - n * 1.2, e - n * 1.2 - d * 14.0, Color(col, 0.8 * blink), 2.5, true)
	ci.draw_line(e + n * 1.2, e + n * 1.2 - d * 14.0, Color(col, 0.8 * blink), 2.5, true)
