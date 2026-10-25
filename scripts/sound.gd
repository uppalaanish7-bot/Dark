extends Node
## Original synthesized sword, flame and cathedral textures; no third-party audio.
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var voice_index: int = 0
var ambience: AudioStreamPlayer
const DURATIONS := {"sword": 0.25, "fire": 0.31, "fire_slash": 0.5, "ultimate": 1.45, "charge": 0.65, "enemy_cast": 0.34, "magic_hit": 0.3, "eruption": 0.48, "telegraph": 0.25, "boss_phase": 1.2, "boss_death": 1.7, "portal": 2.2, "hit": 0.09, "kill": 0.3, "dash": 0.27, "jump": 0.17, "hurt": 0.25, "wave": 0.85, "step": 0.07, "pickup": 0.4}

func _ready() -> void:
	for i in range(24):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for kind in DURATIONS:
		streams[kind] = synthesize(kind)
	for kind in ["lightning", "thunder", "meteor"]:
		streams[kind] = synthesize(kind)
	ambience = AudioStreamPlayer.new()
	ambience.name = "CathedralAir"
	ambience.stream = ambient_stream()
	ambience.volume_db = -31
	add_child(ambience)
	ambience.play()

func play(kind: String, volume: float = 0.0) -> void:
	if not streams.has(kind):
		return
	var voice: AudioStreamPlayer = voices[voice_index]
	voice_index = (voice_index + 1) % voices.size()
	voice.stream = streams[kind]
	voice.volume_db = volume - 12.0
	voice.pitch_scale = randf_range(0.96, 1.04)
	voice.play()

func synthesize(kind: String) -> AudioStreamWAV:
	var duration: float = DURATIONS.get(kind,0.38 if kind=="lightning" else 1.7)
	var samples: int = int(22050 * duration)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var phase: float = 0
	var low_noise: float = 0
	for i in range(samples):
		var t: float = float(i) / 22050.0
		var x: float = t / duration
		var noise: float = randf_range(-1, 1)
		low_noise = lerpf(low_noise, noise, 0.16)
		var frequency: float = 220
		var noisy: float = 0.1
		match kind:
			"lightning":
				frequency = 2300*(1-x)+80
				noisy = 0.9 if sin(t*140)>0 else 0.25
			"thunder", "meteor":
				frequency = 75*(1-x)+28
				noisy = 0.88
			"sword":
				frequency = lerpf(1900, 180, x)
				noisy = 0.82
			"fire", "enemy_cast":
				frequency = lerpf(420, 85, sqrt(x))
				noisy = 0.62
			"fire_slash":
				frequency = lerpf(980, 65, sqrt(x))
				noisy = 0.8
			"ultimate", "eruption", "boss_death":
				frequency = lerpf(125, 33, x)
				noisy = 0.58
			"charge":
				frequency = 110 + x * x * 620
				noisy = 0.18
			"telegraph":
				frequency = 580 + x * 180
				noisy = 0.0
			"magic_hit":
				frequency = 620 * (1 - x) + 80
				noisy = 0.68
			"boss_phase", "portal":
				frequency = 110 + floorf(x * 4) * 55
				noisy = 0.1
			"hit":
				frequency = 1350
				noisy = 0.42
			"kill": frequency = 520 + floorf(x * 3) * 190
			"dash":
				frequency = 180 + x * 430
				noisy = 0.8
			"jump": frequency = 250 + x * 320
			"hurt":
				frequency = 80
				noisy = 0.5
			"wave": frequency = 165 + floorf(x * 4) * 55
			"step":
				frequency = 85
				noisy = 0.85
			"pickup": frequency = 600 + x * 650
		phase += TAU * frequency / 22050.0
		var envelope: float = pow(1.0 - x, 2) * minf(t * 220, 1.0)
		if kind == "charge": envelope = sin(PI * x) * 0.7
		var harmonic: float = sin(phase) * 0.65 + sin(phase * 1.501) * 0.2 + sin(phase * 2) * 0.15
		var sample: float = (harmonic * (1.0 - noisy) + (noise * 0.3 + low_noise * 1.8) * noisy) * envelope * 0.7
		bytes.encode_s16(i * 2, int(clampf(sample, -1, 1) * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = bytes
	return wav

func ambient_stream() -> AudioStreamWAV:
	var samples: int = 22050 * 8
	var bytes := PackedByteArray()
	# Godot 4.7.2 decodes loop_end itself before wrapping the PCM cursor.
	# Store that endpoint too: without it Android reads past the allocation.
	bytes.resize((samples + 1) * 2)
	for i in range(samples):
		var t: float = float(i) / 22050.0
		# All frequencies complete whole cycles over the eight-second loop.
		var breath: float = 0.65 + sin(TAU * t / 8) * 0.25
		var sample: float = (sin(TAU * 55 * t) * 0.3 + sin(TAU * 82.5 * t) * 0.16 + sin(TAU * 110.125 * t) * 0.12 + sin(TAU * 164.875 * t) * 0.04) * breath
		bytes.encode_s16(i * 2, int(sample * 32767))
	# The endpoint is the first sample of the next exact eight-second loop.
	bytes.encode_s16(samples * 2, bytes.decode_s16(0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples
	return wav
