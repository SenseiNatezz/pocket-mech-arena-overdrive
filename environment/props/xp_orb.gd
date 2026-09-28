extends Node2D
## XP shard dropped by defeated enemies (spawned by the Upgrades autoload). Pops out, then homes in on
## the player once they're within the magnet range (bigger with the Scavenger upgrade). At the end of a
## wave every shard is vacuumed up so no XP is lost.

const MAGNET_RANGE := 160.0
const COLLECT_RANGE := 30.0
const COLOR := Color(0.35, 1.0, 0.8)

var value := 1.0
## Initial pop velocity (decays quickly).
var pop := Vector2.ZERO
## Set by Upgrades.vacuum(): fly to the player from anywhere.
var vacuum := false
var _t := 0.0
var _speed := 0.0


func _ready() -> void:
	add_to_group("xp_orbs")
	z_index = 1
	_t = randf() * 3.0
	if Time.get_ticks_msec() < Upgrades.vacuum_until_ms:
		vacuum = true


func _process(delta: float) -> void:
	_t += delta
	position += pop * delta
	pop = pop.lerp(Vector2.ZERO, 1.0 - exp(-6.0 * delta))
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech and not mech.dead:
		var d := global_position.distance_to(mech.global_position)
		if d < COLLECT_RANGE:
			Upgrades.add_xp(value)
			Combat.spark(global_position, COLOR, 0.6)
			Sfx.play(&"pickup", -20.0, 0.15)
			queue_free()
			return
		if vacuum or (d < MAGNET_RANGE * Upgrades.magnet_mult() and _t > 0.35):
			_speed = minf(_speed + delta * 2600.0, 1400.0)
			global_position = global_position.move_toward(mech.global_position, _speed * delta)
	queue_redraw()


func _draw() -> void:
	var bob := sin(_t * 6.0) * 2.5
	var s := 5.0 + minf(value, 6.0) * 0.8
	draw_circle(Vector2(0, 6), s * 0.8, Color(0, 0, 0, 0.25))
	draw_circle(Vector2(0, bob), s * 2.2, Color(COLOR, 0.18))
	var diamond := PackedVector2Array([Vector2(0, -s * 1.4), Vector2(s, 0), Vector2(0, s * 1.4), Vector2(-s, 0)])
	for i in diamond.size():
		diamond[i] += Vector2(0, bob)
	draw_colored_polygon(diamond, COLOR)
	draw_colored_polygon(PackedVector2Array([diamond[0], diamond[1], Vector2(0, bob)]), COLOR.lightened(0.6))
