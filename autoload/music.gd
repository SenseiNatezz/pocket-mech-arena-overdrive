extends Node
## Music (autoload): background tracks (Higgsfield / Sonilo, assets/audio/music/*.mp3) on the "Music"
## bus, crossfading when the situation changes:
##   menu      main menu, customize screen
##   training  tutorial, weapon range, test range
##   combat    campaign arenas and endless
##   boss      from an arena's boss_started until no boss is left (endless boss waves too)
##   victory / defeat   short stings on arena clear / mech destroyed (the loop fades out under them)
## Loops crossfade into their own start near the end, so the seam isn't heard. While the game is
## paused the music ducks. On the web, nothing starts until the first click / tap / key (browsers
## block audio before that).
## ADAPTIVE COMBAT MUSIC: in arenas the combat track is one of three intensity layers -
##   combat_low   tense, sparse build-up (between waves, a few stragglers)
##   combat       the main battle track
##   combat_high  all-out climax (big waves, elites, low armor)
## picked from an intensity score (robots alive, elites, the pilot's armor), moving up quickly and back
## down only after it has stayed calm for a while. During lulls a low-pass filter muffles the music,
## opening up as the fight heats up; radio callouts duck it a little.

const DIR := "res://assets/audio/music/"
const FADE := 1.6
const LOOP_FADE := 3.0
const PAUSE_DUCK_DB := -8.0
const RADIO_DUCK_DB := -5.0
## Per-track level (dB) so every track sits at the same loudness (measured from the files).
const GAIN := {&"boss": -7.2, &"combat": -7.2, &"combat_low": -6.0, &"combat_high": -7.8, &"defeat": 2.4,
	&"menu": -5.7, &"training": -6.6, &"victory": -3.9}
const STINGS := [&"victory", &"defeat"]
const LAYERS := [&"combat_low", &"combat", &"combat_high"]
## Intensity score thresholds for the mid / high layers, and how long a calmer score has to hold
## before the music steps back down.
const MID_AT := 3.0
const HIGH_AT := 11.0
const STEP_DOWN_AFTER := 7.0
const MIN_HOLD := 3.0
## Low-pass cutoff (Hz) when everything is calm vs in the thick of it.
const MUFFLED_HZ := 1600.0
const OPEN_HZ := 20000.0

var track := &""
var _players: Array[AudioStreamPlayer] = []
var _active := 0
var _streams := {}
var _scene: Node
var _unlocked := true
var _duck := 0.0
var _boss_check := 0.0
## Adaptive combat: on in arenas; current score, the layer it wants, and how long it's wanted lower.
var _adaptive := false
var _intensity := 0.0
var _calm_t := 0.0
var _since_change := 99.0
var _score_t := 0.0
var _lpf: AudioEffectLowPassFilter
var _cutoff := OPEN_HZ


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 3:
		var p := AudioStreamPlayer.new()
		p.bus = &"Music"
		p.volume_db = -80.0
		add_child(p)
		_players.append(p)
	for name: StringName in GAIN:
		var path := DIR + String(name) + ".mp3"
		if ResourceLoader.exists(path):
			_streams[name] = load(path)
	_unlocked = not OS.has_feature("web")
	# Low-pass on the Music bus (fully open unless an arena lull muffles it).
	var bus := AudioServer.get_bus_index(&"Music")
	if bus != -1:
		_lpf = AudioEffectLowPassFilter.new()
		_lpf.cutoff_hz = OPEN_HZ
		AudioServer.add_bus_effect(bus, _lpf)


func _input(event: InputEvent) -> void:
	if not _unlocked and (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) \
			and event.is_pressed():
		_unlocked = true
		_scene = null  # re-evaluate the current scene now that audio is allowed


## Crossfades to `name` (no-op if it's already playing). Stings play once over a fading loop.
func play(name: StringName) -> void:
	if name == track or not _streams.has(name) or not _unlocked:
		return
	track = name
	var old := _players[_active]
	var next_i := (_active + 1) % 2
	if name in STINGS:
		next_i = 2
	else:
		_active = next_i
	var p := _players[next_i]
	p.stream = _streams[name]
	p.volume_db = -40.0
	p.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "volume_db", _level(name), FADE * (0.3 if name in STINGS else 1.0))
	if old.playing and old != p:
		tw.tween_property(old, "volume_db", -60.0, FADE if name not in STINGS else 0.6)
		tw.chain().tween_callback(old.stop)


func stop() -> void:
	track = &""
	for p in _players:
		if p.playing:
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, FADE)
			tw.tween_callback(p.stop)


func _level(name: StringName) -> float:
	return GAIN.get(name, -6.0) + _duck


## Arena intensity: robots alive (elites count triple), plus a push when the pilot's armor is low.
func _score() -> float:
	var s := 0.0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e is Enemy and not e.dead and not e.is_in_group("boss"):
			s += 3.0 if e.elite else 1.0
	var mech := get_tree().get_first_node_in_group("player") as Mech
	if mech and not mech.dead and mech.hp < mech.max_hp * 0.35:
		s += 6.0
	return s


## Picks the combat layer: up right away, down only after STEP_DOWN_AFTER s of calmer play.
func _update_adaptive(delta: float) -> void:
	_score_t -= delta
	if _score_t <= 0.0:
		_score_t = 0.5
		_intensity = _score()
	if track not in LAYERS:
		return
	_since_change += delta
	var want: StringName = &"combat_high" if _intensity >= HIGH_AT else (&"combat" if _intensity >= MID_AT else &"combat_low")
	if LAYERS.find(want) > LAYERS.find(track):
		# (no flip-flopping: a layer plays at least MIN_HOLD s before stepping up again)
		if _since_change < MIN_HOLD:
			return
		_calm_t = 0.0
		_since_change = 0.0
		play(want)
	elif LAYERS.find(want) < LAYERS.find(track):
		_calm_t += delta
		if _calm_t >= STEP_DOWN_AFTER:
			_calm_t = 0.0
			_since_change = 0.0
			play(want)
	else:
		_calm_t = 0.0


func _process(delta: float) -> void:
	var scene := get_tree().current_scene
	if scene != _scene and scene != null and scene.is_node_ready():
		_scene = scene
		_on_scene(scene)
	if _adaptive and not get_tree().paused:
		_update_adaptive(delta)
	# Lulls muffle the music (low-pass), which opens up as the fight builds.
	if _lpf:
		var target := OPEN_HZ
		if _adaptive and track == &"combat_low":
			target = lerpf(MUFFLED_HZ, 6000.0, clampf(_intensity / MID_AT, 0.0, 1.0))
		_cutoff = lerpf(_cutoff, target, 1.0 - exp(-2.5 * delta))
		_lpf.cutoff_hz = _cutoff
	# Duck while paused (menus, level-up cards) and under radio callouts.
	var want := PAUSE_DUCK_DB if get_tree().paused else (RADIO_DUCK_DB if Radio.is_speaking() else 0.0)
	if not is_equal_approx(_duck, want):
		var before := _duck
		_duck = move_toward(_duck, want, delta * 20.0)
		var p := _players[_active]
		if p.playing and track not in STINGS:
			p.volume_db += _duck - before
	# Seamless-ish loop: crossfade the active track into a fresh copy of itself near its end.
	var cur := _players[_active]
	if cur.playing and track not in STINGS and cur.stream:
		var left := cur.stream.get_length() - cur.get_playback_position()
		if left < LOOP_FADE:
			var t := track
			track = &""
			play(t)
	# Boss music ends when the boss does.
	if track == &"boss":
		_boss_check -= delta
		if _boss_check <= 0.0:
			_boss_check = 0.5
			var alive := false
			for b in get_tree().get_nodes_in_group("boss"):
				if not b.get("dead"):
					alive = true
			if not alive:
				play(&"combat")


func _on_scene(scene: Node) -> void:
	_adaptive = scene.is_in_group("arena")
	_calm_t = 0.0
	if scene.is_in_group("arena"):
		play(&"combat")
		if scene.has_signal("boss_started"):
			scene.boss_started.connect(func(_b: Node) -> void: play(&"boss"))
		if scene.has_signal("arena_cleared"):
			scene.arena_cleared.connect(func() -> void: play(&"victory"))
		var mech := get_tree().get_first_node_in_group("player") as Mech
		if mech:
			mech.died.connect(func() -> void: play(&"defeat"))
	elif scene.name in ["Tutorial", "GunRange", "TestRange"]:
		play(&"training")
	else:
		play(&"menu")
