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
## 0 slow, 1 normal, 2 fast. Reading speed is personal; DQ has had this since
## the NES and it is the cheapest accessibility win available.
var text_speed: int = 1

## 0 = the 2D renderer, 1 = the 2.5D one. The same controller and the same UI
## drive both; this only decides which scene the title screen opens.
var view_mode: int = 0

## Index into LOCALES. Applied to the TranslationServer on load, so the very
## first frame the title screen draws is already in the right language.
var language: int = DEFAULT_LANGUAGE

const LOCALES := ["ko", "en"]
const LOCALE_KEYS := ["SET_LANG_KO", "SET_LANG_EN"]
## This is a Korean game that also ships English, not the other way round, so
## the first run is Korean and nothing about the machine changes that. Reading
## the OS language was tried first and put an English title screen in front of
## anyone whose desktop was not set to Korean — which is most desktops, and is
## not what the game is for. English is one keypress away in the settings.
const DEFAULT_LANGUAGE := 0

const VIEW_NAMES := ["2D", "2.5D"]
const VIEW_SCENES := ["res://scenes/main.tscn", "res://scenes/main_3d.tscn"]
const TEXT_SPEED_NAMES := ["SET_SLOW", "SET_NORMAL", "SET_FAST"]
const TEXT_SPEED_CPS := [45.0, 90.0, 200.0]


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		music_volume = clampf(float(config.get_value("audio", "music", 0.7)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx", 0.8)), 0.0, 1.0)
		fullscreen = bool(config.get_value("video", "fullscreen", false))
		text_speed = clampi(int(config.get_value("text", "speed", 1)), 0, 2)
		view_mode = clampi(int(config.get_value("video", "view_mode", 0)), 0, 1)
		language = _stored_language(config)
	apply()


## The file stores the locale code, not its position in LOCALES — reordering
## that array must not silently switch somebody's language on them.
## Two things this has to survive. A missing key: ConfigFile reads a `null`
## default as "there is no default" and pushes an error, so the default here is
## a real string. And a value left by an older build, which stored the index
## rather than the code — anything that is not one of our locale strings is
## treated as absent rather than converted, because converting it is both
## meaningless and, on Godot 4.7, an error in itself.
func _stored_language(config: ConfigFile) -> int:
	var stored = config.get_value("text", "language", "")
	if stored is String or stored is StringName:
		var found: int = LOCALES.find(String(stored))
		if found >= 0:
			return found
	return DEFAULT_LANGUAGE


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("text", "speed", text_speed)
	config.set_value("video", "view_mode", view_mode)
	config.set_value("text", "language", LOCALES[clampi(language, 0, LOCALES.size() - 1)])
	config.save(PATH)


## Pushes the current values at the audio server and the window.
func apply() -> void:
	TranslationServer.set_locale(LOCALES[clampi(language, 0, LOCALES.size() - 1)])
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


func view_name() -> String:
	return VIEW_NAMES[clampi(view_mode, 0, 1)]


func view_scene() -> String:
	return VIEW_SCENES[clampi(view_mode, 0, 1)]


func cycle_view_mode(direction: int) -> void:
	view_mode = wrapi(view_mode + direction, 0, VIEW_NAMES.size())
	apply()
	save_settings()


func language_name() -> String:
	return TranslationServer.translate(LOCALE_KEYS[clampi(language, 0, LOCALES.size() - 1)])


func cycle_language(direction: int) -> void:
	language = wrapi(language + direction, 0, LOCALES.size())
	apply()
	save_settings()


func chars_per_second() -> float:
	return TEXT_SPEED_CPS[clampi(text_speed, 0, 2)]


func text_speed_name() -> String:
	return TranslationServer.translate(TEXT_SPEED_NAMES[clampi(text_speed, 0, 2)])


func cycle_text_speed(direction: int) -> void:
	text_speed = wrapi(text_speed + direction, 0, TEXT_SPEED_NAMES.size())
	apply()
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()
	save_settings()
