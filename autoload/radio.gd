extends Node
## Radio (autoload): voiced callouts from mission control ("HALCYON", Higgsfield seed_audio voice lines in
## assets/audio/voice/*.mp3) played through a radio-filtered "Radio" bus, with a subtitle on the HUD
## (`line_started`). It listens to the game itself, so gameplay code rarely has to call it:
##   arena start, waves starting / cleared, the last robot of a wave, boss incoming / destroyed,
##   low armor, the first heavy tank / elite / shield commander of a run, overdrive, death, arena clear.
## Code calls say() for the rest (supply drops, combos, Last Stand).
## Lines never overlap: a global gap (GAP) and a per-line cooldown (REPEAT) keep it from nagging;
## `priority` lines (boss, death, Last Stand) cut in. Only in real arenas / Endless (not the ranges).

signal line_started(text: String, duration: float)

const DIR := "res://assets/audio/voice/"
## key -> [[file, subtitle], ...] (a random variant is picked).
const LINES := {
	&"start": [["start_1", "Halcyon to Pocket. You're on the ground. Weapons free."], ["start_2", "Pocket, comms are green. Clear the area."]],
	&"wave": [["wave_1", "Hostiles inbound. Stay sharp."], ["wave_2", "Here they come. Multiple contacts."], ["wave_3", "More robots warping in. Keep moving!"]],
	&"clear": [["clear_1", "Area clear. Catch your breath, pilot."], ["clear_2", "Wave down. Good work."]],
	&"last": [["last_1", "One hostile left. Follow your arrows."]],
	&"boss": [["boss_1", "Warning! Boss-class machine incoming!"], ["boss_2", "Massive signature! It's a boss, Pocket. Stay mobile!"]],
	&"boss_down": [["boss_down", "Boss down! Outstanding work, pilot."]],
	&"low_hp": [["low_hp_1", "Pocket, your armor is critical! Use a repair kit!"], ["low_hp_2", "You're taking heavy damage! Get clear!"]],
	&"tank": [["tank", "Heavy tank on the field. Hit the glowing vent on its back."]],
	&"elite": [["elite", "Elite signature detected. That one's tougher."]],
	&"bastion": [["bastion", "Shield commander spotted. Take it out first."]],
	&"supply": [["supply", "Supply drop inbound. Grab it!"]],
	&"combo": [["combo", "Combo systems online. Nice pairing."]],
	&"last_stand": [["last_stand", "Emergency power engaged! Get out of there!"]],
	&"death": [["death", "Pocket? Pocket, respond! Signal lost."]],
	&"arena_clear": [["arena_clear", "Arena secure. Mission accomplished."]],
	&"overdrive": [["overdrive", "Overdrive engaged. Light them up!"]],
	# Endless twists (ScenicArena._roll_twist).
	&"twist_storm": [["twist_storm", "Crystal storm incoming! Watch the sky!"]],
	&"twist_blackout": [["twist_blackout", "We're losing visibility. Stay sharp in the dark."]],
	&"twist_elite": [["twist_elite", "Elite signatures everywhere. Be careful, pilot."]],
	&"twist_gold": [["twist_gold", "Gold rush! Salvage is worth double out there!"]],
	&"twist_swarm": [["twist_swarm", "Massive swarm inbound. They're weak, but there are a lot of them!"]],
	&"twist_hyper": [["twist_hyper", "Reactor surge! Everything's moving faster!"]],
}
## Minimum seconds between any two lines, and before the same line can play again.
const GAP := 4.0
const REPEAT := {&"wave": 25.0, &"clear": 30.0, &"last": 45.0, &"low_hp": 30.0, &"overdrive": 40.0}
const DEFAULT_REPEAT := 20.0
## Said once per run only.
const ONCE := [&"tank", &"elite", &"bastion"]
const LOW_HP := 0.3

var enabled := true
var _player: AudioStreamPlayer
var _streams := {}
var _next_ok := 0.0
var _last_said := {}
var _said_once := {}
var _scene: Node
var _active := false
var _low_hp_armed := true
var _clock := 0.0
var _start_at := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus()
	_player = AudioStreamPlayer.new()
	_player.bus = &"Radio"
	add_child(_player)
	for key in LINES:
		for v: Array in LINES[key]:
			var path := DIR + String(v[0]) + ".mp3"
			if ResourceLoader.exists(path):
				_streams[v[0]] = load(path)
	get_tree().node_added.connect(_on_node_added)


## Radio bus: telephone-band EQ + a touch of grit, sent into SFX (so the SFX volume applies).
func _make_bus() -> void:
	if AudioServer.get_bus_index(&"Radio") != -1:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, &"Radio")
	AudioServer.set_bus_send(i, &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master")
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 320.0
	AudioServer.add_bus_effect(i, hp)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = 4200.0
	AudioServer.add_bus_effect(i, lp)
	var dist := AudioEffectDistortion.new()
	dist.mode = AudioEffectDistortion.MODE_CLIP
	dist.drive = 0.18
	dist.pre_gain = 2.0
	dist.post_gain = -2.0
	AudioServer.add_bus_effect(i, dist)
	AudioServer.set_bus_volume_db(i, 3.0)


## Plays a line for `key` if the radio is free (or `priority`) and it's not on cooldown. Returns true
## when a line started.
func say(key: StringName, priority := false) -> bool:
	if not enabled or not Game.radio_voice or not _active or not LINES.has(key):
		return false
	if key in ONCE and _said_once.has(key):
		return false
	if not priority:
		if _clock < _next_ok or _player.playing:
			return false
		if _clock < float(_last_said.get(key, -999.0)) + float(REPEAT.get(key, DEFAULT_REPEAT)):
			return false
	var options: Array = LINES[key]
	var v: Array = options.pick_random()
	var stream: AudioStream = _streams.get(v[0])
	var length := stream.get_length() if stream else 2.5
	if stream:
		_player.stream = stream
		_player.play()
	Sfx.play(&"select", -16.0, 0.0)  # radio click
	_last_said[key] = _clock
	_next_ok = _clock + length + GAP
	if key in ONCE:
		_said_once[key] = true
	line_started.emit(String(v[1]), length + 0.6)
	return true


func is_speaking() -> bool:
	return _player.playing


func _process(delta: float) -> void:
	if not get_tree().paused:
		_clock += delta
	var scene := get_tree().current_scene
	if scene != _scene and scene != null and scene.is_node_ready():
		_scene = scene
		_on_scene(scene)
	if not _active:
		return
	# Opening line, a moment after the arena starts.
	if _start_at >= 0.0 and _clock >= _start_at:
		_start_at = -1.0
		say(&"start", true)
	# Low armor (re-arms once the mech is patched up past 50%).
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech and not mech.dead:
		var f := mech.hp / maxf(mech.max_hp, 1.0)
		if f < LOW_HP and _low_hp_armed and say(&"low_hp", true):
			_low_hp_armed = false
		elif f > 0.5:
			_low_hp_armed = true


func _on_scene(scene: Node) -> void:
	_player.stop()
	_active = scene.is_in_group("arena")
	_said_once.clear()
	_last_said.clear()
	_next_ok = _clock + 1.5
	if not _active:
		return
	_start_at = _clock + 1.6
	if scene.has_signal("boss_started"):
		scene.boss_started.connect(func(_b: Node) -> void: say(&"boss", true))
	if scene.has_signal("arena_cleared"):
		scene.arena_cleared.connect(func() -> void: say(&"arena_clear", true))
	var zone = scene.get("zone")
	if zone:
		zone.wave_started.connect(func(i: int, _n: int) -> void:
			if i > 1 and not zone.is_boss_wave(i):
				say(&"wave"))
		zone.wave_cleared.connect(func(i: int, _n: int) -> void:
			# (an overlapped wave isn't clear yet - stragglers are still around)
			if not zone.is_boss_wave(i) and not zone.last_overlapped:
				get_tree().create_timer(0.8, false).timeout.connect(func() -> void: say(&"clear")))
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech:
		mech.died.connect(func() -> void: say(&"death", true))
	if not Combat.enemy_killed.is_connected(_on_kill):
		Combat.enemy_killed.connect(_on_kill)


func _on_kill(e: Node) -> void:
	if not _active or not is_instance_valid(e):
		return
	if e.is_in_group("boss"):
		get_tree().create_timer(1.8, false).timeout.connect(func() -> void: say(&"boss_down", true))
		return
	# The last robot of a wave (a decent-sized one) is left standing.
	var zone = _scene.get("zone") if is_instance_valid(_scene) else null
	if zone and zone.is_running and zone.alive_count() == 1 and zone.wave >= 2:
		say(&"last")


## First sightings: heavy tank, elite, shield commander (checked once the robot is set up).
func _on_node_added(n: Node) -> void:
	if _active and n is Enemy:
		_check_sighting.call_deferred(n)


func _check_sighting(e: Node) -> void:
	if not is_instance_valid(e) or not (e is Enemy):
		return
	if e.elite:
		say(&"elite")
	elif e is HeavyTank:
		say(&"tank")
	elif e is Bastion:
		say(&"bastion")
