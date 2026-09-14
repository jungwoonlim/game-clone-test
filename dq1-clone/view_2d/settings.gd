## Player settings: volumes and window mode, persisted to user://.
##
## Autoloaded as `GameSettings`. Nothing in core/ reads this — it is entirely
## about how the game presents itself.
extends Node

const PATH := "user://dq1_clone_settings.cfg"

signal changed()

var music_volume: float = 0.7
var sfx_volume: float = 0.8
var fullscreen: bool = false


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		music_volume = clampf(float(config.get_value("audio", "music", 0.7)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx", 0.8)), 0.0, 1.0)
		fullscreen = bool(config.get_value("video", "fullscreen", false))
	apply()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.save(PATH)


## Pushes the current values at the audio server and the window.
func apply() -> void:
	var director := get_node_or_null("/root/AudioDirector") if is_inside_tree() else null
	if director != null:
		director.apply_volumes(music_volume, sfx_volume)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(
				DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
				else DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	apply()
	save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	apply()
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()
	save_settings()
