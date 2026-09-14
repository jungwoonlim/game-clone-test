## Synthesises every sound in the game.
##
##   godot --headless --path . --script res://tools/build_audio.gd
##
## No audio files ship with this project — the sound effects and music are
## generated here as square/triangle/noise waves and saved as AudioStreamWAV
## resources. Saving as .tres rather than .wav keeps the loop points inside the
## resource, so music loops without an import step.
extends SceneTree

const SFX_RATE := 22050
## Music is deliberately lo-fi: at 11 kHz the square waves alias the way an
## NES does, and the files stay small enough to keep in git.
const BGM_RATE := 11025
const OUT_DIR := "res://assets/audio"

const SEMITONES := {
	"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
	"F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
}

var _noise_rng := RandomNumberGenerator.new()


func _initialize() -> void:
	_noise_rng.seed = 20260914
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var count := 0
	for entry in _sfx_definitions():
		_save(_to_stream(entry[1].call(), SFX_RATE, false), entry[0])
		count += 1
	for entry in _bgm_definitions():
		_save(_to_stream(entry[1].call(), BGM_RATE, true), entry[0])
		count += 1

	print("[audio] wrote %d streams to %s" % [count, OUT_DIR])
	quit(0)


func _save(stream: AudioStreamWAV, name: String) -> void:
	var path := "%s/%s.tres" % [OUT_DIR, name]
	stream.take_over_path(path)
	var err := ResourceSaver.save(stream, path)
	if err != OK:
		printerr("[audio] failed to write %s (err=%d)" % [path, err])
		quit(1)


# --- 신디사이저 -----------------------------------------------------------

func _buffer(seconds: float, rate: int) -> PackedFloat32Array:
	var buffer := PackedFloat32Array()
	buffer.resize(maxi(1, int(seconds * rate)))
	return buffer


## A pulse wave with a pitch glide and an exponential decay. `duty` at 0.5 is a
## hollow square; 0.125 is the thin, reedy voice NES leads use.
func _pulse(buffer: PackedFloat32Array, rate: int, start: float, duration: float,
		freq_from: float, freq_to: float, volume: float, duty: float = 0.5,
		decay: float = 3.0) -> void:
	var first := int(start * rate)
	var length := int(duration * rate)
	var phase := 0.0
	for i in length:
		var index := first + i
		if index < 0 or index >= buffer.size():
			continue
		var t := float(i) / float(maxi(length, 1))
		var freq: float = lerpf(freq_from, freq_to, t)
		phase = fmod(phase + freq / float(rate), 1.0)
		var envelope: float = exp(-decay * t)
		buffer[index] += (1.0 if phase < duty else -1.0) * volume * envelope


func _triangle(buffer: PackedFloat32Array, rate: int, start: float, duration: float,
		freq_from: float, freq_to: float, volume: float, decay: float = 3.0) -> void:
	var first := int(start * rate)
	var length := int(duration * rate)
	var phase := 0.0
	for i in length:
		var index := first + i
		if index < 0 or index >= buffer.size():
			continue
		var t := float(i) / float(maxi(length, 1))
		var freq: float = lerpf(freq_from, freq_to, t)
		phase = fmod(phase + freq / float(rate), 1.0)
		buffer[index] += (4.0 * absf(phase - 0.5) - 1.0) * volume * exp(-decay * t)


## White noise through a one-pole lowpass, which is what makes it read as a
## thud or a hiss rather than a click.
func _noise(buffer: PackedFloat32Array, rate: int, start: float, duration: float,
		volume: float, decay: float = 6.0, smooth: float = 0.0) -> void:
	var first := int(start * rate)
	var length := int(duration * rate)
	var previous := 0.0
	for i in length:
		var index := first + i
		if index < 0 or index >= buffer.size():
			continue
		var t := float(i) / float(maxi(length, 1))
		var sample := _noise_rng.randf_range(-1.0, 1.0)
		previous = lerpf(sample, previous, smooth)
		buffer[index] += previous * volume * exp(-decay * t)


func _to_stream(buffer: PackedFloat32Array, rate: int, looping: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buffer.size() * 2)
	for i in buffer.size():
		# Soft clip so stacked voices distort gently instead of wrapping.
		var value: float = clampf(buffer[i], -1.0, 1.0)
		value = value - (value * value * value) / 3.0
		bytes.encode_s16(i * 2, int(clampf(value * 1.5, -1.0, 1.0) * 30000.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = bytes
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buffer.size()
	return stream


func _freq(note: String) -> float:
	if note == "-":
		return 0.0
	var letter := note.substr(0, note.length() - 1)
	var octave := int(note.substr(note.length() - 1, 1))
	var midi: int = SEMITONES[letter] + (octave + 1) * 12
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


# --- 효과음 ---------------------------------------------------------------

func _sfx_definitions() -> Array:
	return [
		["sfx_cursor", _sfx_cursor],
		["sfx_confirm", _sfx_confirm],
		["sfx_cancel", _sfx_cancel],
		["sfx_text", _sfx_text],
		["sfx_step_blocked", _sfx_blocked],
		["sfx_attack", _sfx_attack],
		["sfx_critical", _sfx_critical],
		["sfx_hurt", _sfx_hurt],
		["sfx_spell", _sfx_spell],
		["sfx_heal", _sfx_heal],
		["sfx_defeat_monster", _sfx_defeat_monster],
		["sfx_level_up", _sfx_level_up],
		["sfx_gold", _sfx_gold],
		["sfx_chest", _sfx_chest],
		["sfx_stairs", _sfx_stairs],
		["sfx_encounter", _sfx_encounter],
		["sfx_boss", _sfx_boss],
		["sfx_death", _sfx_death],
		["sfx_victory", _sfx_victory],
	]


func _sfx_cursor() -> PackedFloat32Array:
	var b := _buffer(0.06, SFX_RATE)
	_pulse(b, SFX_RATE, 0.0, 0.05, 900.0, 900.0, 0.35, 0.5, 8.0)
	return b


func _sfx_confirm() -> PackedFloat32Array:
	var b := _buffer(0.14, SFX_RATE)
	_pulse(b, SFX_RATE, 0.0, 0.05, _freq("E5"), _freq("E5"), 0.35, 0.5, 6.0)
	_pulse(b, SFX_RATE, 0.05, 0.08, _freq("B5"), _freq("B5"), 0.35, 0.5, 5.0)
	return b


func _sfx_cancel() -> PackedFloat32Array:
	var b := _buffer(0.14, SFX_RATE)
	_pulse(b, SFX_RATE, 0.0, 0.05, _freq("A4"), _freq("A4"), 0.32, 0.5, 6.0)
	_pulse(b, SFX_RATE, 0.05, 0.08, _freq("D4"), _freq("D4"), 0.32, 0.5, 6.0)
	return b


func _sfx_text() -> PackedFloat32Array:
	var b := _buffer(0.022, SFX_RATE)
	_pulse(b, SFX_RATE, 0.0, 0.018, 1500.0, 1500.0, 0.16, 0.25, 14.0)
	return b


func _sfx_blocked() -> PackedFloat32Array:
	var b := _buffer(0.09, SFX_RATE)
	_noise(b, SFX_RATE, 0.0, 0.08, 0.22, 14.0, 0.7)
	return b


func _sfx_attack() -> PackedFloat32Array:
	var b := _buffer(0.2, SFX_RATE)
	_noise(b, SFX_RATE, 0.0, 0.12, 0.5, 16.0, 0.35)
	_pulse(b, SFX_RATE, 0.0, 0.12, 320.0, 90.0, 0.3, 0.25, 9.0)
	return b


func _sfx_critical() -> PackedFloat32Array:
	var b := _buffer(0.4, SFX_RATE)
	_noise(b, SFX_RATE, 0.0, 0.2, 0.6, 9.0, 0.25)
	_pulse(b, SFX_RATE, 0.0, 0.25, 200.0, 1400.0, 0.4, 0.5, 3.0)
	_pulse(b, SFX_RATE, 0.2, 0.18, 1400.0, 700.0, 0.3, 0.125, 5.0)
	return b


func _sfx_hurt() -> PackedFloat32Array:
	var b := _buffer(0.3, SFX_RATE)
	_pulse(b, SFX_RATE, 0.0, 0.26, 420.0, 70.0, 0.42, 0.5, 5.0)
	_noise(b, SFX_RATE, 0.0, 0.08, 0.3, 18.0, 0.4)
	return b


func _sfx_spell() -> PackedFloat32Array:
	var b := _buffer(0.42, SFX_RATE)
	var notes := ["C5", "E5", "G5", "C6"]
	for i in notes.size():
		_pulse(b, SFX_RATE, i * 0.07, 0.12, _freq(notes[i]), _freq(notes[i]),
				0.3, 0.125, 7.0)
	_noise(b, SFX_RATE, 0.24, 0.16, 0.18, 10.0, 0.6)
	return b


func _sfx_heal() -> PackedFloat32Array:
	var b := _buffer(0.5, SFX_RATE)
	var notes := ["G4", "C5", "E5", "G5"]
	for i in notes.size():
		_triangle(b, SFX_RATE, i * 0.08, 0.22, _freq(notes[i]), _freq(notes[i]),
				0.45, 4.0)
	return b


func _sfx_defeat_monster() -> PackedFloat32Array:
	var b := _buffer(0.55, SFX_RATE)
	_pulse(b, SFX_RATE, 0.0, 0.5, 700.0, 60.0, 0.38, 0.25, 3.0)
	_noise(b, SFX_RATE, 0.0, 0.3, 0.25, 7.0, 0.5)
	return b


func _sfx_level_up() -> PackedFloat32Array:
	var b := _buffer(0.95, SFX_RATE)
	var notes := ["C5", "E5", "G5", "C6", "G5", "C6"]
	var times := [0.0, 0.1, 0.2, 0.3, 0.45, 0.55]
	for i in notes.size():
		_pulse(b, SFX_RATE, times[i], 0.3, _freq(notes[i]), _freq(notes[i]),
				0.32, 0.5, 3.0)
		_triangle(b, SFX_RATE, times[i], 0.3, _freq(notes[i]) * 0.5,
				_freq(notes[i]) * 0.5, 0.25, 3.0)
	return b


func _sfx_gold() -> PackedFloat32Array:
	var b := _buffer(0.22, SFX_RATE)
	_pulse(b, SFX_RATE, 0.0, 0.08, 1800.0, 1800.0, 0.24, 0.125, 9.0)
	_pulse(b, SFX_RATE, 0.06, 0.12, 2400.0, 2400.0, 0.22, 0.125, 8.0)
	return b


func _sfx_chest() -> PackedFloat32Array:
	var b := _buffer(0.6, SFX_RATE)
	_noise(b, SFX_RATE, 0.0, 0.12, 0.3, 12.0, 0.6)
	var notes := ["E5", "G5", "C6"]
	for i in notes.size():
		_pulse(b, SFX_RATE, 0.12 + i * 0.1, 0.26, _freq(notes[i]), _freq(notes[i]),
				0.3, 0.25, 3.5)
	return b


func _sfx_stairs() -> PackedFloat32Array:
	var b := _buffer(0.3, SFX_RATE)
	_pulse(b, SFX_RATE, 0.0, 0.26, 300.0, 900.0, 0.3, 0.25, 4.0)
	return b


func _sfx_encounter() -> PackedFloat32Array:
	var b := _buffer(0.6, SFX_RATE)
	for i in 3:
		_pulse(b, SFX_RATE, i * 0.13, 0.11, 900.0, 1500.0, 0.34, 0.5, 5.0)
	_noise(b, SFX_RATE, 0.38, 0.2, 0.3, 8.0, 0.4)
	return b


func _sfx_boss() -> PackedFloat32Array:
	var b := _buffer(1.5, SFX_RATE)
	_noise(b, SFX_RATE, 0.0, 1.2, 0.45, 1.6, 0.9)
	_pulse(b, SFX_RATE, 0.0, 1.1, 180.0, 45.0, 0.4, 0.5, 1.4)
	_triangle(b, SFX_RATE, 0.3, 0.9, 90.0, 40.0, 0.5, 1.2)
	return b


func _sfx_death() -> PackedFloat32Array:
	var b := _buffer(1.6, SFX_RATE)
	var notes := ["G4", "F4", "D#4", "C4"]
	for i in notes.size():
		_pulse(b, SFX_RATE, i * 0.3, 0.5, _freq(notes[i]), _freq(notes[i]),
				0.35, 0.5, 2.2)
		_triangle(b, SFX_RATE, i * 0.3, 0.5, _freq(notes[i]) * 0.5,
				_freq(notes[i]) * 0.5, 0.3, 2.0)
	return b


func _sfx_victory() -> PackedFloat32Array:
	var b := _buffer(2.4, SFX_RATE)
	var notes := ["C5", "C5", "C5", "C5", "G#4", "A#4", "C5", "A#4", "C5"]
	var times := [0.0, 0.13, 0.26, 0.42, 0.62, 0.78, 0.94, 1.2, 1.4]
	var lengths := [0.12, 0.12, 0.12, 0.18, 0.15, 0.15, 0.2, 0.18, 0.9]
	for i in notes.size():
		_pulse(b, SFX_RATE, times[i], lengths[i], _freq(notes[i]), _freq(notes[i]),
				0.32, 0.5, 2.0)
		_triangle(b, SFX_RATE, times[i], lengths[i], _freq(notes[i]) * 0.5,
				_freq(notes[i]) * 0.5, 0.28, 2.0)
	return b


# --- 음악 -----------------------------------------------------------------

func _bgm_definitions() -> Array:
	return [
		["bgm_town", _bgm_town],
		["bgm_field", _bgm_field],
		["bgm_dungeon", _bgm_dungeon],
		["bgm_battle", _bgm_battle],
		["bgm_boss", _bgm_boss],
	]


## Renders a melody over a two-note-per-bar bass line. Melody entries are
## [note, beats]; `roots` is one note per four-beat bar.
func _compose(melody: Array, roots: Array, beat: float, duty: float) -> PackedFloat32Array:
	var total := 0.0
	for entry in melody:
		total += float(entry[1]) * beat
	var buffer := _buffer(total, BGM_RATE)

	var cursor := 0.0
	for entry in melody:
		var length: float = float(entry[1]) * beat
		if entry[0] != "-":
			var freq := _freq(entry[0])
			# Held slightly short so repeated notes articulate.
			_pulse(buffer, BGM_RATE, cursor, length * 0.92, freq, freq, 0.26, duty, 1.1)
		cursor += length

	for bar in roots.size():
		var root := _freq(roots[bar]) * 0.5
		for half in 2:
			var at: float = (bar * 4 + half * 2) * beat
			_triangle(buffer, BGM_RATE, at, beat * 1.8, root, root, 0.34, 1.0)
	return buffer


func _bgm_town() -> PackedFloat32Array:
	var melody := [
		["C5", 1], ["E5", 1], ["G5", 1], ["E5", 1],
		["F5", 2], ["E5", 2],
		["D5", 1], ["F5", 1], ["A5", 1], ["F5", 1],
		["G5", 2], ["C5", 2],
	]
	return _compose(melody, ["C3", "F3", "D3", "G3"], 0.26, 0.5)


func _bgm_field() -> PackedFloat32Array:
	var melody := [
		["D5", 1], ["D5", 1], ["F5", 1], ["A5", 1],
		["G5", 2], ["F5", 2],
		["E5", 1], ["E5", 1], ["G5", 1], ["A#5", 1],
		["A5", 2], ["D5", 2],
		["F5", 1], ["A5", 1], ["D6", 1], ["A5", 1],
		["G5", 2], ["E5", 2],
		["F5", 1], ["E5", 1], ["D5", 1], ["C5", 1],
		["D5", 4],
	]
	return _compose(melody, ["D3", "A#2", "C3", "D3", "D3", "C3", "A#2", "D3"], 0.22, 0.5)


func _bgm_dungeon() -> PackedFloat32Array:
	var melody := [
		["A4", 2], ["A#4", 2],
		["A4", 2], ["G4", 2],
		["F4", 2], ["G4", 2],
		["A4", 3], ["-", 1],
	]
	return _compose(melody, ["A2", "A2", "F2", "A2"], 0.34, 0.125)


func _bgm_battle() -> PackedFloat32Array:
	var melody := [
		["E5", 1], ["E5", 1], ["G5", 1], ["E5", 1],
		["B5", 2], ["A5", 1], ["G5", 1],
		["F#5", 1], ["F#5", 1], ["A5", 1], ["F#5", 1],
		["E5", 2], ["B4", 2],
		["E5", 1], ["E5", 1], ["G5", 1], ["B5", 1],
		["D6", 2], ["B5", 2],
		["A5", 1], ["G5", 1], ["F#5", 1], ["E5", 1],
		["E5", 4],
	]
	return _compose(melody, ["E3", "E3", "D3", "E3", "E3", "G3", "A3", "E3"], 0.15, 0.5)


func _bgm_boss() -> PackedFloat32Array:
	var melody := [
		["C5", 2], ["G4", 2],
		["G#4", 2], ["G4", 2],
		["C5", 1], ["C5", 1], ["D#5", 1], ["D5", 1],
		["C5", 2], ["G4", 2],
		["C5", 2], ["G4", 2],
		["A#4", 2], ["G#4", 2],
		["G4", 1], ["G#4", 1], ["A#4", 1], ["C5", 1],
		["C5", 4],
	]
	return _compose(melody, ["C2", "C2", "G#2", "C2", "C2", "A#2", "G#2", "C2"], 0.17, 0.5)
