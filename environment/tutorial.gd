extends Node2D
## TUTORIAL: a guided first mission on a space station training deck above Earth (painted Higgsfield
## map assets/hq/tutorial_space.png, traced in environment/arenas/layouts/tutorial_space_layout.gd;
## the mech starts on the launch pad = world origin). Main menu Settings > Tutorial, and offered
## to new pilots before their first New Game / Endless run). One step at a time, each with prompts for
## the device in use (keyboard/mouse, gamepad or touch) and a progress bar:
##   move -> aim & attack -> boost -> scatter shot -> heat attacks -> beam cannon -> real enemies + XP
##   -> level-up pick -> repair kit -> overdrive -> done (play the campaign / endless / main menu)
## The mech can't be destroyed here, and nothing records waves or unlocks.

const DUMMY := preload("res://enemies/training_dummy.gd")
const CHASER := preload("res://enemies/chaser.tscn")
const PANEL := preload("res://ui/tutorial_panel.gd")
const MAP := preload("res://assets/hq/tutorial_space.png")
const LAYOUT := preload("res://environment/arenas/layouts/tutorial_space_layout.gd")
## Pause between a finished step and the next one (the panel shows a check mark meanwhile).
const STEP_GAP := 1.1
const MIN_HP := 25.0

## [id, title, keyboard/mouse, gamepad, touch]. "%s" is never used; texts are shown as written.
const STEPS := [
	[&"move", "MOVE", "Move your mech with  W A S D  (or the arrow keys).",
		"Move your mech with the  LEFT STICK.", "Drag the  LEFT thumb stick  to move."],
	[&"attack", "AIM & ATTACK", "Aim with the  MOUSE  and hold  LEFT CLICK  to attack. Destroy the 3 target drones.",
		"Aim with the  RIGHT STICK  and hold  RT  to attack. Destroy the 3 target drones.",
		"Push the  RIGHT stick  toward a target to aim and attack. Destroy the 3 target drones."],
	[&"boost", "BOOST DASH", "Press  SPACE  to dash. You can't be hit while dashing - dash twice.",
		"Press  LB  to dash. You can't be hit while dashing - dash twice.",
		"Tap  BOOST  to dash. You can't be hit while dashing - dash twice."],
	[&"scatter", "SCATTER SHOT", "RIGHT CLICK  fires a wide scatter blast - perfect up close. Try it.",
		"LT  fires a wide scatter blast - perfect up close. Try it.",
		"ALT FIRE  shoots a wide scatter blast - perfect up close. Try it."],
	[&"heat", "HEAT ATTACKS", "Damage you deal builds HEAT. Spend it:  E = Heat Nova,  Q = Magma Cone. Use two.",
		"Damage you deal builds HEAT. Spend it:  Y = Heat Nova,  RB = Magma Cone. Use two.",
		"Damage you deal builds HEAT. Spend it with  NOVA  and  CONE. Use two."],
	[&"beam", "BEAM CANNON", "Press  C  (or middle click) to charge the Beam Cannon. It pierces everything in a line.",
		"Press  X  to charge the Beam Cannon. It pierces everything in a line.",
		"Tap  BEAM  to charge the Beam Cannon. It pierces everything in a line."],
	[&"fight", "REAL ENEMIES", "Scrap Hounds incoming! Destroy them - they drop green XP shards.",
		"Scrap Hounds incoming! Destroy them - they drop green XP shards.",
		"Scrap Hounds incoming! Destroy them - they drop green XP shards."],
	[&"level", "LEVEL UP", "XP fills the ring around your level. Every level-up lets you pick an upgrade - choose one!",
		"XP fills the ring around your level. Every level-up lets you pick an upgrade - choose one!",
		"XP fills the ring around your level. Every level-up lets you pick an upgrade - tap one!"],
	[&"repair", "REPAIR KIT", "You're damaged! Press  F  to use a repair kit (repair stations refill them).",
		"You're damaged! Press  B  to use a repair kit (repair stations refill them).",
		"You're damaged! Tap  REPAIR  to use a repair kit (repair stations refill them)."],
	[&"overdrive", "OVERDRIVE", "Dealing damage charges OVERDRIVE. It's full - press  SHIFT  for a burst of speed and power!",
		"Dealing damage charges OVERDRIVE. It's full - click the  RIGHT STICK (R3)  for speed and power!",
		"Dealing damage charges OVERDRIVE. It's full - tap  OVERDRIVE  for speed and power!"],
]

var panel: CanvasLayer
var step := -1
var progress := 0.0
var finished := false
var _gap := 0.0
var _last_pos := Vector2.ZERO
var _moved := 0.0
var _targets: Array[Node2D] = []
var _enemies: Array[Enemy] = []
var _count := 0
var _was_boosting := false
var _last_heat := 0.0
var _kits := 0
var deck: PaintedDeck

@onready var mech: Mech = $Mech


func _ready() -> void:
	deck = PaintedDeck.new(LAYOUT, 1.5)  # same scale as the level maps
	var cam := mech.get_node("Camera2D") as Camera2D
	deck.build(self, MAP, cam)
	mech.global_position = Vector2.ZERO
	cam.reset_smoothing()
	var station := get_node_or_null("RepairStation") as Node2D
	if station:
		station.global_position = deck.map_to_world(deck.layout.repair_station)
	panel = PANEL.new()
	panel.tutorial = self
	add_child(panel)
	_last_pos = mech.global_position
	_begin.call_deferred(0)


func step_id() -> StringName:
	return STEPS[step][0] if step >= 0 and step < STEPS.size() else &"done"


## Instruction text for the current step and the device being used right now.
func step_text() -> String:
	if step < 0 or step >= STEPS.size():
		return ""
	var s: Array = STEPS[step]
	match Controls.device:
		Controls.Device.GAMEPAD: return s[3]
		Controls.Device.TOUCH: return s[4]
	return s[2]


func _begin(i: int) -> void:
	step = i
	progress = 0.0
	_count = 0
	if step >= STEPS.size():
		_finish()
		return
	match step_id():
		&"move":
			_moved = 0.0
			_last_pos = mech.global_position
		&"attack":
			for off in [Vector2(340, -160), Vector2(420, 20), Vector2(330, 190)]:
				_targets.append(_dummy(_near(off), 60.0))
		&"boost":
			_was_boosting = false
		&"heat":
			mech.heat = mech.heat_max
			_last_heat = mech.heat
			for a in 4:
				_targets.append(_dummy(_near(Vector2.from_angle(a * TAU / 4.0 + 0.4) * 150.0), 400.0))
		&"beam":
			mech.beam.state = BeamCannon.State.READY
			mech.beam.cooldown_left = 0.0
			for k in 3:
				_targets.append(_dummy(_near(Vector2(260 + k * 140, 0).rotated(mech.aim_dir.angle())), 400.0))
		&"fight":
			for k in 3:
				var e: Enemy = CHASER.instantiate()
				e.max_hp = 40.0
				e.damage_mult = 0.5
				e.position = _near(Vector2.from_angle(k * TAU / 3.0 + 0.3) * 460.0)
				add_child(e)
				_enemies.append(e)
		&"level":
			if Upgrades.level < 2:
				Upgrades.add_xp(Upgrades.xp_to_next() - Upgrades.xp + 0.01)
		&"repair":
			mech.repair_charges = mech.repair_charges_max
			mech.hp = maxf(mech.max_hp * 0.45, MIN_HP)
			_kits = mech.repair_charges
			mech.stats_changed.emit()
		&"overdrive":
			mech.overdrive_left = 0.0
			mech.overdrive_meter = 100.0
			mech.stats_changed.emit()
	panel.show_step()


func _physics_process(delta: float) -> void:
	# The mech can't be destroyed in training.
	if mech.hp < MIN_HP and not mech.dead:
		mech.hp = MIN_HP
	if finished or step < 0:
		return
	if _gap > 0.0:
		_gap -= delta
		if _gap <= 0.0:
			_begin(step + 1)
		return
	progress = clampf(_progress(delta), 0.0, 1.0)
	if progress >= 1.0:
		_complete_step()


func _progress(_delta: float) -> float:
	match step_id():
		&"move":
			if not mech.is_falling():
				_moved += mech.global_position.distance_to(_last_pos)
			_last_pos = mech.global_position
			return _moved / 500.0
		&"attack":
			return _destroyed() / 3.0
		&"boost":
			var boosting := mech.boost_cooldown_left > 0.0 and mech.boost_ready_fraction() < 0.2
			if boosting and not _was_boosting:
				_count += 1
			_was_boosting = boosting
			return _count / 2.0
		&"scatter":
			if Input.is_action_just_pressed("fire_secondary"):
				_count += 1
			return float(_count)
		&"heat":
			# Spending shows up as a sudden drop; refill so the second attack is always affordable.
			if mech.heat < _last_heat - 20.0:
				_count += 1
				mech.heat = mech.heat_max
			_last_heat = mech.heat
			return _count / 2.0
		&"beam":
			return 1.0 if mech.beam.state == BeamCannon.State.FIRE else 0.0
		&"fight":
			var dead := 0
			for e in _enemies:
				if not is_instance_valid(e) or e.dead:
					dead += 1
			if dead < 3:
				return dead / 3.0
			# All down: pull the XP shards in, and move on once they've been collected.
			Upgrades.vacuum()
			return 1.0 if get_tree().get_nodes_in_group("xp_orbs").is_empty() else 0.99
		&"level":
			return 1.0 if Upgrades.level >= 2 and not Upgrades.choosing and Upgrades.pending == 0 else 0.0
		&"repair":
			return 1.0 if mech.repair_charges < _kits else 0.0
		&"overdrive":
			return 1.0 if mech.overdrive_left > 0.0 else 0.0
	return 0.0


func _destroyed() -> int:
	var n := 0
	for t in _targets:
		if not is_instance_valid(t) or t.get("hp") <= 0.0:
			n += 1
	return n


func _complete_step() -> void:
	progress = 1.0
	_gap = STEP_GAP
	Sfx.play(&"levelup", -10.0, 0.0)
	panel.step_complete()
	# Clear out this step's targets so the next one starts clean.
	for t in _targets:
		if is_instance_valid(t):
			Combat.shockwave(t.global_position, 60.0, Color(0.5, 0.9, 1.0), 0.25)
			t.queue_free()
	_targets.clear()
	if step_id() == &"fight":
		Upgrades.vacuum()


func _finish() -> void:
	finished = true
	Game.finish_tutorial()
	mech.hp = mech.max_hp
	mech.stats_changed.emit()
	panel.show_finished()


## A tutorial target drone that stays down once destroyed.
func _dummy(pos: Vector2, hp: float) -> Node2D:
	var d := Area2D.new()
	d.set_script(DUMMY)
	d.set("max_hp", hp)
	d.set("respawn_time", 9999.0)
	d.position = pos
	add_child(d)
	Combat.shockwave(pos, 70.0, Color(0.4, 0.9, 1.0), 0.35)
	return d


## A point near the mech, kept on open deck (pulled toward the launch pad if it would land off it).
func _near(offset: Vector2) -> Vector2:
	return deck.clamp_to_deck(mech.global_position + offset)
