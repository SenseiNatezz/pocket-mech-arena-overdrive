extends Node2D
## Repair station: stand near it and press USE to refill all repair charges and restore some HP.
## Recharges for `cooldown` seconds after use. Works with the mech's generic "interactable" contract:
## `prompt_text`, `can_interact(mech)`, `interact(mech)`.

const TEX := preload("res://assets/hq/repair_pad.png")
const SPRITE_SCALE := 0.56

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
	# HQ pad sprite; dimmed while recharging, with a pulsing hologram glow when ready.
	var half := TEX.get_size() / 2
	draw_set_transform(Vector2(5, 7), 0.0, Vector2.ONE * SPRITE_SCALE)
	draw_texture(TEX, -half, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * SPRITE_SCALE)
	draw_texture(TEX, -half, Color.WHITE if is_ready else Color(0.55, 0.6, 0.6))
	draw_set_transform(Vector2.ZERO)
	if is_ready:
		draw_circle(Vector2.ZERO, 26 + 4 * sin(_t * 4.0), Color(glow, 0.12 + 0.06 * sin(_t * 5.0)))
	else:
		draw_arc(Vector2.ZERO, 66, -PI / 2, -PI / 2 + TAU * (1.0 - _cooldown_left / cooldown), 48, Color(0.3, 1.0, 0.55, 0.8), 4.0, true)
