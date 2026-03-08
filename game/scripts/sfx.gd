## Procedural audio engine — generates all game sounds at runtime.
##
## No external audio files. Every SFX is synthesized from sine waves and noise
## bursts via AudioStreamWAV. Manages SFX and Ambience audio buses with
## dynamic ducking on heavy impacts. Includes ambient drone, cinematic sounds,
## and UI feedback tones with pitch randomization for variety.
class_name SFX
extends Node

# Audio bus indices (set up in _ensure_buses)
static var _buses_ready: bool = false
static var _last_tick_msec: int = 0
const TICK_COOLDOWN_MS: int = 40  # prevent overlapping ticks in rapid fire

# Ambient drone player (singleton, looping)
static var _drone_player: AudioStreamPlayer = null

static func _ensure_buses() -> void:
	if _buses_ready:
		return
	_buses_ready = true
	# Create SFX bus
	if AudioServer.get_bus_index("SFX") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")
	# Create Ambience bus
	if AudioServer.get_bus_index("Ambience") == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, "Ambience")
		AudioServer.set_bus_send(idx, "Master")

static func _make_player(parent: Node) -> AudioStreamPlayer:
	_ensure_buses()
	var p = AudioStreamPlayer.new()
	p.bus = "SFX"
	p.pitch_scale = randf_range(0.85, 1.15)
	parent.add_child(p)
	return p

static func _gen_wav(samples: PackedFloat32Array, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	var data = PackedByteArray()
	data.resize(samples.size() * 2)
	for i in range(samples.size()):
		var val = clampi(int(samples[i] * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, val)
	wav.data = data
	return wav

static func _sine(freq: float, duration: float, volume: float = 0.5, sr: int = 22050) -> PackedFloat32Array:
	var count = int(sr * duration)
	var buf = PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t = float(i) / float(sr)
		var env = 1.0 - (t / duration)  # linear fade
		buf[i] = sin(t * freq * TAU) * volume * env
	return buf

static func _noise_burst(duration: float, volume: float = 0.3, sr: int = 22050) -> PackedFloat32Array:
	var count = int(sr * duration)
	var buf = PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t = float(i) / float(sr)
		var env = 1.0 - (t / duration)
		buf[i] = randf_range(-1.0, 1.0) * volume * env
	return buf

static func play_correct(parent: Node) -> void:
	# Ascending two-note chime: C5 -> E5
	var buf = _sine(523.0, 0.12, 0.4)
	buf.append_array(_sine(659.0, 0.2, 0.5))
	var p = _make_player(parent)
	p.stream = _gen_wav(buf)
	p.play()
	p.finished.connect(p.queue_free)

static func play_wrong(parent: Node) -> void:
	# Descending buzz: E4 -> C4 with slight distortion
	var buf = _sine(330.0, 0.15, 0.5)
	buf.append_array(_sine(220.0, 0.25, 0.4))
	var p = _make_player(parent)
	p.stream = _gen_wav(buf)
	p.play()
	p.finished.connect(p.queue_free)

static func play_streak(parent: Node) -> void:
	# Quick ascending arpeggio: C5 -> E5 -> G5 -> C6
	var buf = _sine(523.0, 0.08, 0.35)
	buf.append_array(_sine(659.0, 0.08, 0.4))
	buf.append_array(_sine(784.0, 0.08, 0.45))
	buf.append_array(_sine(1047.0, 0.18, 0.5))
	var p = _make_player(parent)
	p.stream = _gen_wav(buf)
	p.play()
	p.finished.connect(p.queue_free)

static func play_liquidated(parent: Node) -> void:
	# Deep descending tone with rumble
	var sr = 22050
	var duration = 0.8
	var count = int(sr * duration)
	var buf = PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t = float(i) / float(sr)
		var freq = lerpf(300.0, 60.0, t / duration)
		var env = 1.0 - (t / duration) * 0.5
		buf[i] = sin(t * freq * TAU) * 0.5 * env + randf_range(-0.15, 0.15) * env
	var p = _make_player(parent)
	p.stream = _gen_wav(buf, sr)
	p.play()
	p.finished.connect(p.queue_free)

static func play_swipe(parent: Node) -> void:
	# Quick whoosh (filtered noise)
	var buf = _noise_burst(0.15, 0.2)
	var p = _make_player(parent)
	p.stream = _gen_wav(buf)
	p.play()
	p.finished.connect(p.queue_free)

static func play_round_complete(parent: Node) -> void:
	# Triumphant three-note: G4 -> B4 -> D5 -> G5
	var buf = _sine(392.0, 0.1, 0.35)
	buf.append_array(_sine(494.0, 0.1, 0.4))
	buf.append_array(_sine(587.0, 0.1, 0.45))
	buf.append_array(_sine(784.0, 0.25, 0.5))
	var p = _make_player(parent)
	p.stream = _gen_wav(buf)
	p.play()
	p.finished.connect(p.queue_free)

static func play_tick(parent: Node) -> void:
	# Short click for timer warning — with cooldown to prevent clipping
	var now = Time.get_ticks_msec()
	if now - _last_tick_msec < TICK_COOLDOWN_MS:
		return
	_last_tick_msec = now
	var buf = _sine(880.0, 0.03, 0.3)
	var p = _make_player(parent)
	p.stream = _gen_wav(buf)
	p.play()
	p.finished.connect(p.queue_free)

static func play_hover_tick(parent: Node) -> void:
	# Soft UI hover tick — 1200Hz sine, very short — with cooldown
	var now = Time.get_ticks_msec()
	if now - _last_tick_msec < TICK_COOLDOWN_MS:
		return
	_last_tick_msec = now
	var buf = _sine(1200.0, 0.02, 0.15)
	var p = _make_player(parent)
	p.stream = _gen_wav(buf)
	p.play()
	p.finished.connect(p.queue_free)

static func play_card_lock(parent: Node) -> void:
	# Snap/lock sound — 880Hz tone + noise burst + 1100Hz overtone
	var sr = 22050
	var base = _sine(880.0, 0.06, 0.4, sr)
	var burst = _noise_burst(0.04, 0.25, sr)
	var overtone = _sine(1100.0, 0.08, 0.3, sr)
	# Mix base and burst (overlay noise on tone)
	var mix_len = mini(base.size(), burst.size())
	for i in range(mix_len):
		base[i] = clampf(base[i] + burst[i], -1.0, 1.0)
	base.append_array(overtone)
	var p = _make_player(parent)
	p.stream = _gen_wav(base, sr)
	p.play()
	p.finished.connect(p.queue_free)

static func play_heavy_impact(parent: Node) -> void:
	# Low thud + distorted rumble — fast decay
	var sr = 22050
	var duration = 0.35
	var count = int(sr * duration)
	var buf = PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t = float(i) / float(sr)
		var env = pow(1.0 - (t / duration), 2.0)  # fast exponential decay
		var low = sin(t * 80.0 * TAU) * 0.6
		var rumble = randf_range(-0.4, 0.4)
		var sub = sin(t * 45.0 * TAU) * 0.3
		buf[i] = clampf((low + rumble + sub) * env, -1.0, 1.0)
	var p = _make_player(parent)
	p.stream = _gen_wav(buf, sr)
	p.play()
	p.finished.connect(p.queue_free)
	# Duck ambience on heavy impacts
	duck_ambience(parent)

# === AMBIENT DRONE ===

static func start_drone(parent: Node) -> void:
	_ensure_buses()
	if _drone_player and is_instance_valid(_drone_player):
		return
	# Generate a looping low-frequency drone: layered sub-bass + slow LFO modulated noise
	var sr = 22050
	var duration = 4.0  # 4 second loop
	var count = int(sr * duration)
	var buf = PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t = float(i) / float(sr)
		# Sub bass: 40Hz fundamental + 60Hz harmonic
		var sub = sin(t * 40.0 * TAU) * 0.25 + sin(t * 60.0 * TAU) * 0.12
		# Slow LFO modulated filtered noise (spaceship hum)
		var lfo = sin(t * 0.3 * TAU) * 0.5 + 0.5
		var noise_val = sin(t * 120.0 * TAU + sin(t * 0.7 * TAU) * 3.0) * 0.06
		# Crossfade at loop boundaries for seamless loop
		var fade = 1.0
		if t < 0.05:
			fade = t / 0.05
		elif t > duration - 0.05:
			fade = (duration - t) / 0.05
		buf[i] = clampf((sub + noise_val * lfo) * fade, -1.0, 1.0)
	var wav = _gen_wav(buf, sr)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = count
	_drone_player = AudioStreamPlayer.new()
	_drone_player.bus = "Ambience"
	_drone_player.stream = wav
	_drone_player.volume_db = -8.0
	parent.add_child(_drone_player)
	_drone_player.play()

# === AUDIO DUCKING ===

static func duck_ambience(parent: Node) -> void:
	_ensure_buses()
	var bus_idx = AudioServer.get_bus_index("Ambience")
	if bus_idx < 0:
		return
	var original = AudioServer.get_bus_volume_db(bus_idx)
	var target = original - 15.0
	# Quick duck down, slow fade back
	var tw = parent.create_tween()
	tw.tween_method(func(v: float): AudioServer.set_bus_volume_db(bus_idx, v),
		original, target, 0.05)
	tw.tween_interval(0.3)
	tw.tween_method(func(v: float): AudioServer.set_bus_volume_db(bus_idx, v),
		target, original, 2.0)

# === CINEMATIC INTRO SOUNDS ===

static func play_type_tick(parent: Node) -> void:
	# Ultra-short click for terminal typing — with cooldown
	var now = Time.get_ticks_msec()
	if now - _last_tick_msec < TICK_COOLDOWN_MS:
		return
	_last_tick_msec = now
	var buf = _sine(2400.0, 0.008, 0.2)
	var p = _make_player(parent)
	p.pitch_scale = randf_range(0.9, 1.3)
	p.stream = _gen_wav(buf)
	p.play()
	p.finished.connect(p.queue_free)

static func play_cash_register(parent: Node) -> void:
	# Bright "ka-ching" — rising arpeggio + noise snap
	var sr = 22050
	var snap = _noise_burst(0.02, 0.35, sr)
	var tone1 = _sine(1200.0, 0.06, 0.4, sr)
	var tone2 = _sine(1600.0, 0.06, 0.45, sr)
	var tone3 = _sine(2000.0, 0.1, 0.5, sr)
	snap.append_array(tone1)
	snap.append_array(tone2)
	snap.append_array(tone3)
	var p = _make_player(parent)
	p.stream = _gen_wav(snap, sr)
	p.play()
	p.finished.connect(p.queue_free)

static func play_bass_drop(parent: Node) -> void:
	# Sub-bass hit with white noise burst — cinematic impact
	var sr = 22050
	var duration = 0.5
	var count = int(sr * duration)
	var buf = PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t = float(i) / float(sr)
		var env = pow(1.0 - (t / duration), 3.0)
		var sub = sin(t * 35.0 * TAU) * 0.7
		var mid = sin(t * 100.0 * TAU) * 0.3 * maxf(1.0 - t * 8.0, 0.0)
		var noise_val = randf_range(-0.3, 0.3) * maxf(1.0 - t * 5.0, 0.0)
		buf[i] = clampf((sub + mid + noise_val) * env, -1.0, 1.0)
	var p = _make_player(parent)
	p.pitch_scale = 1.0
	p.stream = _gen_wav(buf, sr)
	p.play()
	p.finished.connect(p.queue_free)
	duck_ambience(parent)
