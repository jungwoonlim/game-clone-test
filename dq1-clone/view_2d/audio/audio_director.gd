## Plays the generated sounds. Autoloaded as `AudioDirector`.
##
## Buses are built in code rather than shipped as a bus layout, so there is one
## less binary resource to keep in sync with the settings screen.
extends Node

const AUDIO_DIR := "res://assets/audio"
const SFX_VOICES := 8
## Same sound twice inside this window is a stutter, not an effect.
const RETRIGGER_GUARD := 0.04

var _streams: Dictionary = {}
var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _current_bgm := ""
var _last_played: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_buses()

	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)

	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = "SFX"
		add_child(voice)
		_voices.append(voice)

	_load_streams()


func _build_buses() -> void:
	for name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, "Master")


func _load_streams() -> void:
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		push_warning("AudioDirector: %s is missing. Run tools/build_audio.gd." % AUDIO_DIR)
		return
	for file in dir.get_files():
		# Exported projects rename .tres to .remap; strip either.
		var name := file.get_basename()
		if file.ends_with(".remap"):
			name = file.replace(".remap", "").get_basename()
		if _streams.has(name):
			continue
		var stream := load("%s/%s.tres" % [AUDIO_DIR, name])
		if stream is AudioStream:
			_streams[name] = stream


func has_sound(name: String) -> bool:
	return _streams.has(name)


func sound_count() -> int:
	return _streams.size()


## Fire-and-forget. Unknown names are ignored so callers never have to guard.
func sfx(name: String) -> void:
	var stream: AudioStream = _streams.get(name)
	if stream == null or _voices.is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(name, -1.0)) < RETRIGGER_GUARD:
		return
	_last_played[name] = now

	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.play()


func play_bgm(name: String) -> void:
	if name == _current_bgm and _music.playing:
		return
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		return
	_current_bgm = name
	_music.stream = stream
	_music.play()


func stop_bgm() -> void:
	_current_bgm = ""
	_music.stop()


func current_bgm() -> String:
	return _current_bgm


func apply_volumes(music: float, sfx_level: float) -> void:
	_set_bus("Music", music)
	_set_bus("SFX", sfx_level)


func _set_bus(name: String, level: float) -> void:
	var index := AudioServer.get_bus_index(name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, level <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(level, 0.0001, 1.0)))
