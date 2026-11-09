extends Node2D
## SCRAP CHIP: the gold scrap a destroyed robot drops in a real run (spawned by Game._drop_scrap). The
## scrap is already credited to Game.run_scrap when the robot dies, so nothing is ever lost; the chip only
## carries it to the mech. It pops out, then flies to the mech ON ITS OWN from anywhere on the map (no
## pickup chore), and the HUD's scrap counter rolls up the moment it lands (Game.land_scrap).

const GOLD := Color(1.0, 0.8, 0.28)
const DARK := Color(0.42, 0.27, 0.05)
const COLLECT_RANGE := 30.0
## Seconds before a chip starts homing (so the pop spray reads first).
const HOME_DELAY := 0.4
## A chip still out after this long lands anyway (it never strands scrap off the counter).
const MAX_LIFE := 6.0

var value := 1.0
## Initial pop velocity (decays quickly).
var pop := Vector2.ZERO
## Game._scrap_epoch when it dropped (a chip from a finished run doesn't touch the new run's counter).
var epoch := 0
var _t := 0.0
var _speed := 0.0
var _spin := 0.0
var _landed := false


func _ready() -> void:
	add_to_group("scrap_chips")
	z_index = 1
	_spin = randf() * TAU


func _process(delta: float) -> void:
	_t += delta
	_spin += delta * (5.0 + pop.length() * 0.03)
	position += pop * delta
	pop = pop.lerp(Vector2.ZERO, 1.0 - exp(-5.0 * delta))
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech and not mech.dead:
		if global_position.distance_to(mech.global_position) < COLLECT_RANGE and _t > 0.15:
			_land(true)
			return
		if _t > HOME_DELAY:
			_speed = minf(_speed + delta * 2200.0, 1500.0)
			global_position = global_position.move_toward(mech.global_position, _speed * delta)
	if _t > MAX_LIFE:
		_land(false)
		return
	queue_redraw()


func _land(at_mech: bool) -> void:
	if _landed:
		return
	_landed = true
	Game.land_scrap(value, epoch)
	if at_mech:
		Combat.spark(global_position, GOLD, 0.55)
		Sfx.play(&"coin", -21.0, 0.08)
	queue_free()


## (freed with the scene: the run is over, so just take it off the in-flight count)
func _exit_tree() -> void:
	if not _landed:
		_landed = true
		Game.land_scrap(value, epoch)


## A little gold hex nut, spinning as it flies.
func _draw() -> void:
	var bob := sin(_t * 7.0) * 2.0
	var s := 6.5 + minf(value / 12.0, 3.0) * 0.9
	draw_circle(Vector2(0, 6), s * 0.75, Color(0, 0, 0, 0.25))
	var c := Vector2(0, bob)
	draw_circle(c, s * 2.1, Color(GOLD, 0.2))
	var hex := PackedVector2Array()
	for i in 6:
		hex.append(c + Vector2.from_angle(_spin + i * TAU / 6.0) * s)
	draw_colored_polygon(hex, GOLD)
	# One lit facet and a darker one, so the spin reads.
	draw_colored_polygon(PackedVector2Array([c, hex[0], hex[1]]), GOLD.lightened(0.45))
	draw_colored_polygon(PackedVector2Array([c, hex[3], hex[4]]), GOLD.darkened(0.25))
	var ring := hex.duplicate()
	ring.append(hex[0])
	draw_polyline(ring, DARK, 1.2, true)
	draw_circle(c, s * 0.36, DARK)
