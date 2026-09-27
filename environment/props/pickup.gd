extends Node2D
## Pickup dropped by crates. Drifts toward the player when close and is collected on contact.
##   health    +25 HP          heat      +35 heat
##   repair    +1 repair charge overdrive +35 overdrive meter

const MAGNET_RANGE := 150.0
const COLLECT_RANGE := 34.0

var kind := &"health"
var _t := 0.0
var _life := 20.0

const COLORS := {&"health": Color(0.4, 1.0, 0.5), &"heat": Color(1.0, 0.55, 0.15), &"repair": Color(0.3, 0.9, 1.0),
	&"overdrive": Color(1.0, 0.85, 0.25)}
const LABELS := {&"health": "+HP", &"heat": "HEAT", &"repair": "+KIT", &"overdrive": "OD"}


func _process(delta: float) -> void:
	_t += delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech and not mech.dead:
		var d := global_position.distance_to(mech.global_position)
		if d < COLLECT_RANGE:
			_collect(mech)
			return
		if d < MAGNET_RANGE:
			global_position = global_position.move_toward(mech.global_position, delta * (500.0 - d * 2.0))
	visible = _life > 4.0 or int(_life * 8.0) % 2 == 0
	queue_redraw()


func _collect(mech: Mech) -> void:
	match kind:
		&"health": mech.heal(25.0)
		&"heat": mech.add_heat(35.0)
		&"repair": mech.add_repair_charge()
		&"overdrive": mech.add_overdrive(35.0)
	Combat.shockwave(global_position, 50.0, COLORS[kind], 0.25)
	Sfx.play(&"select", -6.0)
	queue_free()


func _draw() -> void:
	var c: Color = COLORS[kind]
	var bob := sin(_t * 5.0) * 3.0
	draw_circle(Vector2(0, 8), 10, Color(0, 0, 0, 0.3))
	draw_circle(Vector2(0, bob - 4), 18, Color(c, 0.2))
	draw_circle(Vector2(0, bob - 4), 11, c.darkened(0.2))
	draw_circle(Vector2(0, bob - 4), 7, c.lightened(0.4))
	var font := ThemeDB.fallback_font
	draw_string_outline(font, Vector2(-20, bob - 22), LABELS[kind], HORIZONTAL_ALIGNMENT_CENTER, 40, 11, 3, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-20, bob - 22), LABELS[kind], HORIZONTAL_ALIGNMENT_CENTER, 40, 11, c.lightened(0.5))
