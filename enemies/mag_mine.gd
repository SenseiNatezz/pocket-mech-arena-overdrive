class_name MagMine
extends Node2D
## A magnetic mine dropped by the Mag Mine Drone (Orbital Dry Dock). Arms after ARM seconds (its light
## turns on), then when the mech comes within TRIGGER it blinks fast for FUSE seconds and blows (violet
## blast, hurts the player only). Fizzles out after LIFE seconds. Shots don't set it off - move away.

const VIOLET := Color(0.8, 0.35, 1.0)
const ARM := 0.8
const TRIGGER := 105.0
const FUSE := 0.5
const LIFE := 14.0
const BLAST_R := 125.0

var damage := 20.0
var source: Node = null
var _age := 0.0
var _fuse := -1.0


static func drop(pos: Vector2, dmg: float, from: Node) -> MagMine:
	var m := MagMine.new()
	m.global_position = pos
	m.damage = dmg
	m.source = from
	m.z_index = -5
	m.add_to_group("mag_mines")
	Combat.world().add_child(m)
	return m


func _physics_process(delta: float) -> void:
	_age += delta
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse <= 0.0:
			Combat.explode(global_position, BLAST_R, damage, source if is_instance_valid(source) else null, "player", VIOLET, 300.0)
			queue_free()
			return
	elif _age >= ARM:
		var p := get_tree().get_first_node_in_group("player") as Node2D
		if p and global_position.distance_to(p.global_position) < TRIGGER:
			_fuse = FUSE
			Sfx.play(&"charge", -12.0, 0.3)
	if _age >= LIFE and _fuse < 0.0:
		Combat.spark(global_position, VIOLET, 0.8)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var armed := _age >= ARM
	var blink := 0.0
	if _fuse >= 0.0:
		blink = 1.0 if fmod(_age * 14.0, 1.0) < 0.5 else 0.3
		draw_circle(Vector2.ZERO, BLAST_R, Color(VIOLET, 0.08 + 0.1 * (1.0 - _fuse / FUSE)))
		draw_arc(Vector2.ZERO, BLAST_R, 0, TAU, 40, Color(1.0, 0.35, 0.6, 0.85), 2.5, true)
	elif armed:
		blink = 0.55 + 0.45 * sin(_age * 5.0)
		draw_arc(Vector2.ZERO, TRIGGER, 0, TAU, 32, Color(VIOLET, 0.12), 1.5, true)
	# Body: a dark disc with four clamp teeth and the light in the middle.
	draw_circle(Vector2(3, 4), 15.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, 14.0, Color(0.12, 0.12, 0.16))
	for i in 4:
		var d := Vector2.from_angle(TAU * i / 4.0 + _age * 0.6)
		draw_line(d * 10.0, d * 19.0, Color(0.35, 0.35, 0.42), 4.0)
	draw_circle(Vector2.ZERO, 7.0, Color(0.25, 0.22, 0.3))
	if armed or _fuse >= 0.0:
		draw_circle(Vector2.ZERO, 5.0 + 3.0 * blink, Color(VIOLET.lerp(Color.WHITE, 0.3 * blink), 0.5 + 0.5 * blink))
