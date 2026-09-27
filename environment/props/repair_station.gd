extends Node2D
## Repair station: stand near it and press USE to refill all repair charges and restore some HP.
## Recharges for `cooldown` seconds after use. Works with the mech's generic "interactable" contract:
## `prompt_text`, `can_interact(mech)`, `interact(mech)`.

@export var cooldown := 25.0
@export var heal_fraction := 0.35

var prompt_text := "Repair station"
var _cooldown_left := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("interactable")
	z_index = -5


func can_interact(mech: Node) -> bool:
	return _cooldown_left <= 0.0 and (mech.repair_charges < mech.repair_charges_max or mech.hp < mech.max_hp)


func interact(mech: Node) -> void:
	if not can_interact(mech):
		return
	mech.repair_charges = mech.repair_charges_max
	mech.heal(mech.max_hp * heal_fraction)
	_cooldown_left = cooldown
	Combat.shockwave(global_position, 120.0, Color(0.4, 1.0, 0.6))
	Combat.burst(global_position, Color(0.5, 1.0, 0.7), 260.0, 0.8)
	Sfx.play(&"levelup", -6.0, 0.0)


func _process(delta: float) -> void:
	_t += delta
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	prompt_text = "Repair (refill kits + HP)" if _cooldown_left <= 0.0 else "Recharging..."
	queue_redraw()


func _draw() -> void:
	var is_ready := _cooldown_left <= 0.0
	var glow := Color(0.3, 1.0, 0.55) if is_ready else Color(0.45, 0.5, 0.55)
	# Pad.
	draw_circle(Vector2(4, 6), 46, Color(0, 0, 0, 0.3))
	draw_circle(Vector2.ZERO, 46, Color(0.2, 0.22, 0.26))
	draw_circle(Vector2.ZERO, 40, Color(0.13, 0.15, 0.18))
	draw_arc(Vector2.ZERO, 46, 0, TAU, 48, Color(0.5, 0.52, 0.58), 3.0, true)
	for i in 8:
		var a := i * TAU / 8 + _t * (0.6 if is_ready else 0.1)
		draw_line(Vector2.from_angle(a) * 32, Vector2.from_angle(a) * 39, Color(glow, 0.8), 3.0)
	# Holographic cross.
	var bob := sin(_t * 3.0) * 3.0
	var cross := Color(glow, 0.55 + 0.25 * sin(_t * 5.0)) if is_ready else Color(glow, 0.3)
	draw_rect(Rect2(-6, -20 + bob, 12, 32), cross)
	draw_rect(Rect2(-16, -10 + bob, 32, 12), cross)
	draw_circle(Vector2(0, -4 + bob), 30, Color(glow, 0.08))
	if not is_ready:
		draw_arc(Vector2.ZERO, 52, -PI / 2, -PI / 2 + TAU * (1.0 - _cooldown_left / cooldown), 48, Color(0.3, 1.0, 0.55, 0.8), 4.0, true)
