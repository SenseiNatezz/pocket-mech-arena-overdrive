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
		&"magnet":
			ci.draw_arc(c + Vector2(0, -s * 0.05), s * 0.6, 0, PI, 20, col, w * 2.2, true)
			for x in [-0.6, 0.6]:
				ci.draw_line(c + Vector2(x * s, -s * 0.05), c + Vector2(x * s, -s * 0.7), col, w * 2.2)
				ci.draw_line(c + Vector2(x * s, -s * 0.55), c + Vector2(x * s, -s * 0.85), Color(1, 1, 1, 0.9), w * 2.2)
		_:
			ci.draw_circle(c, s * 0.5, col)
