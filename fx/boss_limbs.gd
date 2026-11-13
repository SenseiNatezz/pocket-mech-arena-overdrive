class_name BossLimbs
extends Node2D
## A boss towers over the pilot, so its arms / legs / wings should cover the mech when it walks under them,
## while the core stays below the mech (so saber hits on the core still show). The boss draws its whole
## sprite as usual under the mech (z 0); this child draws the same sprite again ABOVE the mech (z 3), but
## only the part outside a hole round the core, as a ring of textured quads.
## The boss calls paint() from inside its own _draw (WardenBoss.note_body), straight onto this node's canvas
## item, so the copy always matches the frame's shake / turn exactly.

const SEGMENTS := 48


func _ready() -> void:
	z_as_relative = false
	z_index = 3  # just above the mech (2)


## Draws the outer part of `tex` (drawn by the boss with transform `xf`, centred) in `col`, leaving a hole of
## `inner` boss pixels round the core.
func paint(tex: Texture2D, xf: Transform2D, col: Color, inner: float) -> void:
	var rid := get_canvas_item()
	RenderingServer.canvas_item_clear(rid)
	if tex == null or col.a <= 0.01 or not visible:
		return
	var size := tex.get_size()
	var half := size / 2.0
	var sc := (absf(xf.get_scale().x) + absf(xf.get_scale().y)) / 2.0
	var r0 := inner / maxf(sc, 0.01)
	var r1 := half.length() + 2.0
	if r0 >= r1:
		return
	RenderingServer.canvas_item_add_set_transform(rid, xf)
	var cols := PackedColorArray([col, col, col, col])
	for i in SEGMENTS:
		var d0 := Vector2.from_angle(TAU * i / SEGMENTS)
		var d1 := Vector2.from_angle(TAU * (i + 1) / SEGMENTS)
		var pts := PackedVector2Array([d0 * r0, d0 * r1, d1 * r1, d1 * r0])
		var uvs := PackedVector2Array()
		for p in pts:
			uvs.append((p + half) / size)
		RenderingServer.canvas_item_add_polygon(rid, pts, cols, uvs, tex.get_rid())
	RenderingServer.canvas_item_add_set_transform(rid, Transform2D.IDENTITY)


func clear() -> void:
	RenderingServer.canvas_item_clear(get_canvas_item())
