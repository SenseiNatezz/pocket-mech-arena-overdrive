extends RefCounted
## Simple vector glyphs for upgrades (level-up cards, pause menu). `s` = half-size in pixels.


static func draw(ci: CanvasItem, id: StringName, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.14)
	match id:
		&"target_lock":
			ci.draw_arc(c, s * 0.7, 0, TAU, 32, col, w, true)
			ci.draw_circle(c, s * 0.14, col)
			for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * s * 0.4, c + d * s, col, w)
		&"multishot":
			for a in [-0.45, 0.0, 0.45]:
				var d := Vector2.UP.rotated(a)
				ci.draw_line(c + Vector2(0, s * 0.7), c + Vector2(0, s * 0.7) + d * s * 1.5, col, w * 1.3)
				ci.draw_circle(c + Vector2(0, s * 0.7) + d * s * 1.5, w * 1.1, col.lightened(0.4))
		&"shield":
			var hex := PackedVector2Array()
			for i in 7:
				hex.append(c + Vector2.from_angle(TAU * i / 6.0 + PI / 6) * s * 0.9)
			ci.draw_colored_polygon(hex.slice(0, 6), Color(col, 0.25))
			ci.draw_polyline(hex, col, w, true)
		&"pierce":
			for x in [-0.35, 0.35]:
				ci.draw_line(c + Vector2(x * s, -s * 0.7), c + Vector2(x * s, s * 0.7), Color(col, 0.55), w * 1.4)
			ci.draw_line(c + Vector2(-s, 0), c + Vector2(s * 0.7, 0), col, w * 1.2)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s, 0), c + Vector2(s * 0.55, -s * 0.3),
				c + Vector2(s * 0.55, s * 0.3)]), col)
		&"rapid":
			for k in [-0.45, 0.2]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(k * s, -s * 0.7), c + Vector2((k + 0.45) * s, 0),
					c + Vector2(k * s, s * 0.7)]), col, w * 1.3, true)
		&"power":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.15, -s), c + Vector2(-s * 0.55, s * 0.12),
				c + Vector2(-s * 0.05, s * 0.12), c + Vector2(-s * 0.2, s), c + Vector2(s * 0.55, -s * 0.15),
				c + Vector2(s * 0.05, -s * 0.15)]), col)
		&"armor":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.75, -s * 0.7), c + Vector2(s * 0.75, -s * 0.7),
				c + Vector2(s * 0.75, s * 0.1), c + Vector2(0, s * 0.9), c + Vector2(-s * 0.75, s * 0.1)]), Color(col, 0.35))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.75, -s * 0.7), c + Vector2(s * 0.75, -s * 0.7),
				c + Vector2(s * 0.75, s * 0.1), c + Vector2(0, s * 0.9), c + Vector2(-s * 0.75, s * 0.1),
				c + Vector2(-s * 0.75, -s * 0.7)]), col, w, true)
			ci.draw_line(c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.35), col, w * 1.3)
			ci.draw_line(c + Vector2(-s * 0.35, -s * 0.05), c + Vector2(s * 0.35, -s * 0.05), col, w * 1.3)
		&"thrusters":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.6), c + Vector2(s * 0.4, -s * 0.6),
				c + Vector2(s * 0.25, 0), c + Vector2(-s * 0.25, 0)]), col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, s * 0.05), c + Vector2(s * 0.3, s * 0.05),
				c + Vector2(0, s)]), Color(1.0, 0.7, 0.3))
		&"blades":
			ci.draw_arc(c, s * 0.7, 0, TAU, 32, Color(col, 0.4), w * 0.7, true)
			for i in 3:
				var a := TAU * i / 3.0
				var p := c + Vector2.from_angle(a) * s * 0.7
				var t := Vector2.from_angle(a + PI / 2)
				var o := Vector2.from_angle(a)
				ci.draw_colored_polygon(PackedVector2Array([p + t * s * 0.6, p + o * s * 0.22, p - t * s * 0.35,
					p - o * s * 0.22]), col)
		&"explosive":
			var star := PackedVector2Array()
			for i in 16:
				star.append(c + Vector2.from_angle(TAU * i / 16.0) * s * (0.95 if i % 2 == 0 else 0.45))
			ci.draw_colored_polygon(star, col)
			ci.draw_circle(c, s * 0.3, Color(1.0, 0.95, 0.7))
		&"salvage", &"field_repair":
			ci.draw_rect(Rect2(c - Vector2(s * 0.22, s * 0.8), Vector2(s * 0.44, s * 1.6)), col)
			ci.draw_rect(Rect2(c - Vector2(s * 0.8, s * 0.22), Vector2(s * 1.6, s * 0.44)), col)
		&"heat_sink":
			ci.draw_arc(c + Vector2(0, s * 0.45), s * 0.35, 0, TAU, 24, col, w, true)
			ci.draw_circle(c + Vector2(0, s * 0.45), s * 0.22, Color(1.0, 0.5, 0.2))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.13, -s * 0.9), Vector2(s * 0.26, s * 1.1)), col, false, w)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.05, -s * 0.3), Vector2(s * 0.1, s * 0.6)), Color(1.0, 0.5, 0.2))
		&"salvage_protocol":
			# A gold scrap nut with a rising chevron (more scrap).
			var nut := PackedVector2Array()
			for i in 6:
				nut.append(c + Vector2(0, s * 0.18) + Vector2.from_angle(i * TAU / 6.0) * s * 0.62)
			ci.draw_colored_polygon(nut, col)
			ci.draw_circle(c + Vector2(0, s * 0.18), s * 0.22, Color(0.3, 0.2, 0.04))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.55), c + Vector2(0, -s * 0.98),
				c + Vector2(s * 0.5, -s * 0.55)]), Color(1.0, 0.97, 0.75), w * 1.4, true)
		&"magnet":
			ci.draw_arc(c + Vector2(0, -s * 0.05), s * 0.6, 0, PI, 20, col, w * 2.2, true)
			for x in [-0.6, 0.6]:
				ci.draw_line(c + Vector2(x * s, -s * 0.05), c + Vector2(x * s, -s * 0.7), col, w * 2.2)
				ci.draw_line(c + Vector2(x * s, -s * 0.55), c + Vector2(x * s, -s * 0.85), Color(1, 1, 1, 0.9), w * 2.2)
		&"crit":
			# Crosshair with a "x2" spark: a four-point star inside a broken ring.
			for k in 4:
				var a := PI / 4 + k * PI / 2
				ci.draw_arc(c, s * 0.8, a - 0.5, a + 0.5, 10, col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.6), c + Vector2(s * 0.14, -s * 0.14),
				c + Vector2(s * 0.6, 0), c + Vector2(s * 0.14, s * 0.14), c + Vector2(0, s * 0.6),
				c + Vector2(-s * 0.14, s * 0.14), c + Vector2(-s * 0.6, 0), c + Vector2(-s * 0.14, -s * 0.14)]), col)
		&"drones":
			for p: Vector2 in [Vector2(-0.45, 0.3), Vector2(0.45, 0.3), Vector2(0, -0.45)]:
				var q := c + p * s
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -s * 0.32), q + Vector2(s * 0.22, 0),
					q + Vector2(0, s * 0.22), q + Vector2(-s * 0.22, 0)]), Color(col, 0.35))
				ci.draw_polyline(PackedVector2Array([q + Vector2(0, -s * 0.32), q + Vector2(s * 0.22, 0),
					q + Vector2(0, s * 0.22), q + Vector2(-s * 0.22, 0), q + Vector2(0, -s * 0.32)]), col, w * 0.8, true)
				ci.draw_circle(q, s * 0.07, Color(1, 1, 1, 0.9))
		&"missile_pod":
			for x in [-0.4, 0.4]:
				var b := c + Vector2(x * s, s * 0.15)
				ci.draw_colored_polygon(PackedVector2Array([b + Vector2(0, -s * 0.85), b + Vector2(s * 0.16, -s * 0.5),
					b + Vector2(s * 0.16, s * 0.35), b + Vector2(-s * 0.16, s * 0.35), b + Vector2(-s * 0.16, -s * 0.5)]), col)
				ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-s * 0.12, s * 0.38), b + Vector2(s * 0.12, s * 0.38),
					b + Vector2(0, s * 0.8)]), Color(1.0, 0.75, 0.3))
		&"chain":
			var bolt := PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.5), c + Vector2(-s * 0.15, -s * 0.1),
				c + Vector2(-s * 0.35, s * 0.15), c + Vector2(s * 0.3, s * 0.05), c + Vector2(s * 0.1, s * 0.35),
				c + Vector2(s * 0.8, s * 0.6)])
			ci.draw_polyline(bolt, Color(col, 0.35), w * 3.0, true)
			ci.draw_polyline(bolt, col.lightened(0.3), w * 1.2, true)
			ci.draw_circle(c + Vector2(-s * 0.8, -s * 0.5), s * 0.16, col)
			ci.draw_circle(c + Vector2(s * 0.8, s * 0.6), s * 0.16, col)
		&"boost_burst":
			ci.draw_arc(c, s * 0.85, 0, TAU, 32, Color(col, 0.5), w, true)
			ci.draw_arc(c, s * 0.55, 0, TAU, 28, col, w * 1.2, true)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.2, s * 0.35), c + Vector2(0, -s * 0.4),
				c + Vector2(s * 0.2, s * 0.35)]), col.lightened(0.3))
		&"reactive":
			var hex := PackedVector2Array()
			for i in 7:
				hex.append(c + Vector2.from_angle(TAU * i / 6.0) * s * 0.55)
			ci.draw_colored_polygon(hex.slice(0, 6), Color(col, 0.35))
			ci.draw_polyline(hex, col, w, true)
			for i in 6:
				var d := Vector2.from_angle(TAU * i / 6.0 + PI / 6)
				ci.draw_line(c + d * s * 0.65, c + d * s * 0.95, col, w * 1.2)
		&"cryo":
			for k in 3:
				var d := Vector2.from_angle(k * PI / 3)
				ci.draw_line(c - d * s * 0.85, c + d * s * 0.85, col, w * 1.2)
				for sgn: float in [-1.0, 1.0]:
					var e := c + d * s * 0.55 * sgn
					ci.draw_line(e, e + (d * sgn).rotated(0.7) * s * 0.25, col, w)
					ci.draw_line(e, e + (d * sgn).rotated(-0.7) * s * 0.25, col, w)
		&"redline":
			ci.draw_arc(c + Vector2(0, s * 0.25), s * 0.75, PI * 1.05, TAU * 0.975, 24, Color(1, 1, 1, 0.35), w, true)
			ci.draw_arc(c + Vector2(0, s * 0.25), s * 0.75, PI * 1.6, TAU * 0.975, 12, col, w * 1.6, true)
			ci.draw_line(c + Vector2(0, s * 0.25), c + Vector2(0, s * 0.25) + Vector2.from_angle(-0.5) * s * 0.7,
				Color(1, 1, 1, 0.95), w * 1.2)
			ci.draw_circle(c + Vector2(0, s * 0.25), s * 0.12, col)
		&"od_core":
			ci.draw_circle(c, s * 0.45, Color(col, 0.35))
			ci.draw_arc(c, s * 0.45, 0, TAU, 24, col, w, true)
			for i in 8:
				var d := Vector2.from_angle(TAU * i / 8.0)
				ci.draw_line(c + d * s * 0.6, c + d * s * (0.95 if i % 2 == 0 else 0.8), col, w)
			ci.draw_circle(c, s * 0.18, Color(1, 1, 1, 0.95))
		&"thermal":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.9), c + Vector2(s * 0.5, -s * 0.05),
				c + Vector2(s * 0.42, s * 0.5), c + Vector2(0, s * 0.85), c + Vector2(-s * 0.42, s * 0.5),
				c + Vector2(-s * 0.5, -s * 0.05)]), Color(col, 0.85))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.2), c + Vector2(s * 0.24, s * 0.3),
				c + Vector2(0, s * 0.6), c + Vector2(-s * 0.24, s * 0.3)]), Color(1.0, 0.9, 0.5))
		_:
			ci.draw_circle(c, s * 0.5, col)
