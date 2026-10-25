extends SceneTree
## Offline native WAV decoding, including the Android crash's loop endpoint.
## Does not open the game or touch saves; Dummy audio requires no device.
const SOUND = preload("res://scripts/sound.gd")
const SAMPLE_RATE := 22050
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		failures.append(detail)
		push_error("AUDIO LOOP: " + detail)

func valid_buffer(buffer: PackedVector2Array) -> bool:
	for frame in buffer:
		if not frame.is_finite() or absf(frame.x) > 1.01 or absf(frame.y) > 1.01:
			return false
	return true

func run() -> void:
	var sound := SOUND.new()
	var durations: Dictionary = SOUND.DURATIONS.duplicate()
	durations.merge({"lightning": 0.38, "thunder": 1.7, "meteor": 1.7})
	check(durations.size() == 23, "All 23 authored sound effects are covered")
	var output_rate := AudioServer.get_mix_rate()
	for kind in durations:
		var wav: AudioStreamWAV = sound.synthesize(kind)
		var expected_frames := int(SAMPLE_RATE * float(durations[kind]))
		check(wav.format == AudioStreamWAV.FORMAT_16_BITS and not wav.stereo and wav.mix_rate == SAMPLE_RATE, kind + " retains mono PCM format")
		check(wav.data.size() == expected_frames * 2 and wav.loop_mode == AudioStreamWAV.LOOP_DISABLED, kind + " has exact nonlooping PCM bounds")
		check(is_finite(wav.get_length()) and absf(wav.get_length() - float(expected_frames) / SAMPLE_RATE) < 0.000001, kind + " retains authored duration")
		for pitch in [0.96, 1.04]:
			var playback := wav.instantiate_playback()
			playback.start()
			var remaining := ceili(wav.get_length() * output_rate / pitch) + 2048
			var valid := true
			var audible := false
			while playback.is_playing() and remaining > 0:
				var buffer := playback.mix_audio(pitch, mini(1024, remaining))
				valid = valid and valid_buffer(buffer)
				for frame in buffer:
					audible = audible or absf(frame.x) > 0.0001
				remaining -= 1024
			check(valid and audible and not playback.is_playing(), "%s decodes finite audible samples and ends at pitch %.2f" % [kind, pitch])
			playback.stop()
	var ambience: AudioStreamWAV = sound.ambient_stream()
	var loop_frames := SAMPLE_RATE * 8
	check(ambience.format == AudioStreamWAV.FORMAT_16_BITS and not ambience.stereo and ambience.mix_rate == SAMPLE_RATE, "Ambience retains mono PCM format")
	check(ambience.loop_mode == AudioStreamWAV.LOOP_FORWARD and ambience.loop_begin == 0 and ambience.loop_end == loop_frames, "Ambience keeps the exact eight-second loop period")
	check(ambience.data.size() == (loop_frames + 1) * 2, "Inclusive decoder endpoint lies inside the PCM allocation")
	if ambience.data.size() >= (loop_frames + 1) * 2:
		check(ambience.data.decode_s16(loop_frames * 2) == ambience.data.decode_s16(0), "Endpoint mirrors the first sample at the loop seam")
	var loop_playback := ambience.instantiate_playback()
	loop_playback.start(7.99)
	var remaining := output_rate * 24 + 2048
	var last_position := loop_playback.get_playback_position()
	var wraps := 0
	var valid := true
	var audible := false
	while remaining > 0:
		var buffer := loop_playback.mix_audio(1.0, mini(1024, remaining))
		valid = valid and not buffer.is_empty() and valid_buffer(buffer)
		for frame in buffer:
			audible = audible or absf(frame.x) > 0.0001
		var position := loop_playback.get_playback_position()
		if position < last_position: wraps += 1
		last_position = position
		remaining -= 1024
	check(valid and audible and wraps >= 3 and loop_playback.is_playing(), "Native WAV decoder crosses at least three loop seams with finite audible output")
	loop_playback.stop()
	sound.free()
	print("AUDIO_LOOP_VALIDATION: %d checks, %d failures; 23 effects at two pitches; %d native ambience wraps (offline decoding, not Android playback)" % [checks, failures.size(), wraps])
	quit(0 if failures.is_empty() else 1)
