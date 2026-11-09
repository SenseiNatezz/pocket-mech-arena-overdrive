extends RefCounted
## Weapon mastery drawn as ten pips, one per level (Game.MASTERY_MAX): earned levels gold, the level being
## worked on filling with progress, the rest dark. The LV 5 (FINISHER) and LV 10 (MASTERED) pips get a
## light frame so the perk levels stand out. Shared by the HUD's MASTERY UP toast and the Armory
## (preload it and call the static draw_pips()).

const GOLD := Color(1.0, 0.82, 0.3)
const EMPTY := Color(0.12, 0.15, 0.22, 0.9)


static func draw_pips(ci: CanvasItem, r: Rect2, level: int, frac: float) -> void:
	var n := Game.MASTERY_MAX
	var gap := 2.0 if r.size.x > 60.0 else 1.0
	var w := (r.size.x - gap * (n - 1)) / n
	for i in n:
		var pr := Rect2(r.position.x + i * (w + gap), r.position.y, w, r.size.y)
		ci.draw_rect(pr, EMPTY)
		if i < level:
			ci.draw_rect(pr, GOLD)
			ci.draw_rect(Rect2(pr.position, Vector2(pr.size.x, maxf(1.0, pr.size.y * 0.3))), Color(1, 1, 1, 0.25))
		elif i == level and frac > 0.0:
			ci.draw_rect(Rect2(pr.position, Vector2(pr.size.x * clampf(frac, 0.0, 1.0), pr.size.y)), Color(GOLD, 0.6))
		if i + 1 == Game.MASTERY_FINISHER_LEVEL or i + 1 == n:
			ci.draw_rect(pr.grow(1.0), Color(1.0, 0.95, 0.75, 0.95 if i < level else 0.4), false, 1.0)


## Five-point star (the MASTERED badge), filled as triangles from the centre.
static func draw_star(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		pts.append(p + Vector2.from_angle(-PI / 2 + i * PI / 5.0) * (r if i % 2 == 0 else r * 0.45))
	for i in 10:
		ci.draw_colored_polygon(PackedVector2Array([p, pts[i], pts[(i + 1) % 10]]), col)
