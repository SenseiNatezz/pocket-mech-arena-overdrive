extends Node
## Sound effects (autoload Sfx). Usage: Sfx.play(&"shoot", -12.0)
## Every sound is a real recording from assets/audio/sfx/<name>.wav when one exists (Higgsfield
## generated, trimmed + loudness-matched), otherwise a tiny built-in synth version - so the game never
## goes silent if a file is missing. All sounds play on the "SFX" bus (Settings > Sound FX volume).
## Rapid-fire sounds are capped to a few overlapping voices (the oldest one is restarted).

const RATE := 22050
const SFX_DIR := "res://assets/audio/sfx/"
## Recordings are normalised quieter than the old synth sounds; this lifts them to the same level so
## every existing Sfx.play(name, volume_db) call keeps its balance.
const FILE_GAIN_DB := 7.0
## Most copies of one sound playing at once (default MAX_VOICES).
const MAX_VOICES := 4
const VOICE_CAP := {&"shoot": 3, &"enemy_shoot": 4, &"hit": 3, &"select": 2, &"pickup": 3, &"missile": 3,
	&"explode": 4, &"saber": 3, &"dash": 2, &"alarm": 1, &"levelup": 1, &"charge": 2, &"laser": 1}

var _streams: Dictionary = {}
var _from_file: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 32:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_players.append(p)
	_build()
	for sound in _streams.keys():
		var path: String = SFX_DIR + String(sound) + ".wav"
		if ResourceLoader.exists(path):
			_streams[sound] = load(path)
			_from_file[sound] = true


func play(sound: StringName, volume_db := 0.0, pitch_jitter := 0.06) -> void:
	var stream: AudioStream = _streams.get(sound)
	if stream == null:
		return
	var player := _voice_for(sound)
	player.stream = stream
	player.set_meta("sound", sound)
	player.volume_db = volume_db + (FILE_GAIN_DB if _from_file.has(sound) else 0.0)
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.play()


## A player for `sound`: if that sound already has its full number of voices going, reuse the one
## that has played longest; otherwise any free player.
func _voice_for(sound: StringName) -> AudioStreamPlayer:
	var cap: int = VOICE_CAP.get(sound, MAX_VOICES)
	var same: Array[AudioStreamPlayer] = []
	for p in _players:
		if p.playing and p.get_meta("sound", &"") == sound:
			same.append(p)
	if same.size() >= cap:
		var oldest := same[0]
		for p in same:
			if p.get_playback_position() > oldest.get_playback_position():
				oldest = p
		oldest.stop()
		return oldest
	return _free_player()


## Plays every sound once, silently. Web builds register each sample with the browser on first
## play, which can stall a frame mid-fight; doing it during the intro avoids that.
func warm_up() -> void:
	for sound in _streams:
		play(sound, -80.0, 0.0)


func _free_player() -> AudioStreamPlayer:
	for i in _players.size():
		var p := _players[(_next + i) % _players.size()]
		if not p.playing:
			_next = (_next + i + 1) % _players.size()
			return p
	_next = (_next + 1) % _players.size()
	return _players[_next]


func _build() -> void:
	_streams[&"shoot"] = _synth(0.08, 1800, 520, 0.5, 0.3, 0.06, 0.5, 0.5, 2.0)
	_streams[&"enemy_shoot"] = _synth(0.12, 720, 300, 0.45, 0.6, 0.0, 0.0, 0.0, 1.5)
	_streams[&"hit"] = _synth(0.06, 320, 160, 0.25, 0.5, 0.6, 0.6, 0.3, 2.0)
	_streams[&"explode"] = _synth(0.55, 95, 40, 0.5, 0.0, 0.95, 0.35, 0.04, 1.6)
	_streams[&"big_explode"] = _synth(1.4, 70, 28, 0.6, 0.0, 1.0, 0.25, 0.02, 1.3)
	_streams[&"pickup"] = _synth(0.07, 900, 1650, 0.35, 0.0, 0.0, 0.0, 0.0, 1.0)
	_streams[&"dash"] = _synth(0.26, 220, 820, 0.1, 0.0, 0.75, 0.05, 0.45, 1.2, 0.03)
	_streams[&"hurt"] = _synth(0.24, 260, 90, 0.55, 0.8, 0.3, 0.3, 0.1, 1.4)
	_streams[&"shield"] = _synth(0.3, 600, 1400, 0.35, 0.0, 0.2, 0.3, 0.3, 1.5)
	_streams[&"missile"] = _synth(0.2, 420, 200, 0.2, 0.3, 0.5, 0.2, 0.1, 1.5)
	_streams[&"charge"] = _synth(1.1, 150, 950, 0.35, 0.4, 0.15, 0.1, 0.3, 0.0, 1.0)
	_streams[&"laser"] = _synth(1.2, 95, 80, 0.55, 0.7, 0.6, 0.3, 0.2, 0.35, 0.01)
	_streams[&"slam"] = _synth(0.45, 70, 35, 0.7, 0.2, 0.8, 0.25, 0.05, 1.8)
	_streams[&"select"] = _synth(0.07, 1250, 1250, 0.3, 0.5, 0.0, 0.0, 0.0, 1.0)
	# Beam Rifle: sharp electric zap sweeping down into a crackle.
	_streams[&"beam_rifle"] = _synth(0.55, 2600, 260, 0.38, 0.75, 0.7, 0.85, 0.25, 1.1)
	# Beam Saber: airy whoosh sweeping down with a bright metallic edge.
	_streams[&"saber"] = _synth(0.38, 1500, 380, 0.22, 0.2, 0.8, 0.25, 0.85, 1.3, 0.02)
	# Cryo Reactor: crackling freeze and a soft snow impact.
	_streams[&"freeze"] = _synth(0.4, 3200, 1600, 0.18, 0.35, 0.65, 0.9, 0.55, 1.1)
	_streams[&"snow_hit"] = _synth(0.2, 320, 120, 0.12, 0.0, 0.75, 0.25, 0.08, 1.4)
	var notes: Array[AudioStreamWAV] = []
	for f in [523.0, 659.0, 784.0, 1047.0]:
		notes.append(_synth(0.09, f, f, 0.4, 0.25, 0.0, 0.0, 0.0, 0.8))
	_streams[&"levelup"] = _join(notes)
	var alarm: Array[AudioStreamWAV] = []
	for i in 3:
		alarm.append(_synth(0.22, 760, 760, 0.4, 0.8, 0.0, 0.0, 0.0, 0.3))
		alarm.append(_synth(0.22, 540, 540, 0.4, 0.8, 0.0, 0.0, 0.0, 0.3))
	_streams[&"alarm"] = _join(alarm)


## One voice = pitch-swept tone (sine blended toward square) + low-passed noise, with a decay envelope.
func _synth(seconds: float, f0: float, f1: float, tone_vol: float, square_mix: float,
		noise_vol: float, lp0: float, lp1: float, decay_pow: float, attack := 0.004) -> AudioStreamWAV:
	var n := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		phase += TAU * lerpf(f0, f1, k) / RATE
		var s := sin(phase)
		var tone := lerpf(s, signf(s), square_mix) * tone_vol
		lp += (randf() * 2.0 - 1.0 - lp) * lerpf(lp0, lp1, k)
		var env := pow(1.0 - k, decay_pow) * minf(1.0, float(i) / (attack * RATE))
		data.encode_s16(i * 2, int(clampf((tone + lp * noise_vol) * env, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _join(parts: Array[AudioStreamWAV]) -> AudioStreamWAV:
	var data := PackedByteArray()
	for p in parts:
		data.append_array(p.data)
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
