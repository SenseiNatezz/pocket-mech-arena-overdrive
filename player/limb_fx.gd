extends Node2D
## LIMB DAMAGE + SALVAGE on the mech's body (autoload/salvage.gd), drawn in code over the sprite:
## - damaged limbs spit sparks now and then, broken ones constantly (with black smoke puffs)
## - every bolted-on robot piece is a small armour plate in that robot's colour, riveted onto its slot
##   (head, the two shoulders / forearms, the legs, the backpack behind the shoulders).

var mech: Mech
var _t := 0.0
var _spark_t := {&"head": 0.5, &"arms": 0.7, &"legs": 0.9, &"backpack": 1.1}

## Where each slot sits on the body (x is mirrored for the second arm / leg), at body scale 1.
const SPOTS := {
	&"head": [Vector2(0, -24)],
	&"arms": [Vector2(-14, -8), Vector2(14, -8)],
	&"legs": [Vector2(-6, 12), Vector2(6, 12)],
	&"backpack": [Vector2(-7, -16), Vector2(7, -16)],
}


func _ready() -> void:
	z_index = 2
	Salvage.changed.connect(queue_redraw)


func _scale() -> float:
	return mech.body.scale.x if mech and mech.body else 1.0


func _process(delta: float) -> void:
	if not mech or mech.dead or not mech.visible:
		return
	_t += delta
	for s in Salvage.SLOTS:
		var f := float(Salvage.integrity[s])
		if f >= Salvage.DAMAGED:
			continue
		_spark_t[s] -= delta
		if _spark_t[s] > 0.0:
			continue
		var broken := f <= 0.0
		_spark_t[s] = randf_range(0.15, 0.35) if broken else randf_range(0.6, 1.3)
		var spot: Vector2 = (SPOTS[s] as Array).pick_random() * _scale()
		var at := mech.global_position + spot
		Combat.spark(at, Color(1.0, 0.75, 0.3), 0.45 if broken else 0.3)
		if broken and randf() < 0.5:
			Combat.burst(at, Color(0.12, 0.12, 0.14, 0.8), 60.0, 0.6)
	if not Salvage.bolted.is_empty():
		queue_redraw()


func _draw() -> void:
	if not mech or Salvage.bolted.is_empty():
		return
	var k := _scale()
	var seen := {}
	for p in Salvage.bolted:
		var slot: StringName = p["slot"]
		var i: int = seen.get(slot, 0)
		seen[slot] = i + 1
		var spots: Array = SPOTS[slot]
		var at: Vector2 = spots[i % spots.size()] * k + Vector2(0, -3.5 * k) * float(i / spots.size())
		var tint: Color = Enemy.DEBRIS_TINTS.get(p.get("from", &""), Color(0.7, 0.45, 0.3))
		var ring: Color = Salvage.SLOT_COLORS[slot]
		var r := Rect2(at - Vector2(3.5, 2.5) * k, Vector2(7, 5) * k)
		draw_rect(r.grow(1.0), Color(0, 0, 0, 0.55))
		draw_rect(r, tint)
		draw_rect(Rect2(r.position, Vector2(r.size.x, 1.5 * k)), tint.lightened(0.35))
		draw_rect(r, Color(ring, 0.6 + 0.25 * sin(_t * 3.0 + i)), false, 1.0)
		draw_circle(r.position + Vector2(1.5, r.size.y - 1.5), 0.7 * k, Color(0.15, 0.15, 0.15))
		draw_circle(r.end - Vector2(1.5, 1.5), 0.7 * k, Color(0.15, 0.15, 0.15))
