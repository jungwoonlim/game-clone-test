## Title screen. Owns nothing but the choice of what happens next.
extends Control

@onready var _menu: CommandWindow = $Menu
@onready var _settings: SettingsWindow = $Settings
@onready var _save_note: Label = $SaveNote


func _ready() -> void:
	var director := get_node_or_null("/root/AudioDirector")
	if director != null:
		director.play_bgm("bgm_town")
	_refresh_save_note()
	_run_menu()


func _refresh_save_note() -> void:
	_save_note.text = "" if SaveGame.has_save() else "no journal recorded yet"


func _run_menu() -> void:
	while true:
		var has_save := SaveGame.has_save()
		var pick := await _menu.open_menu(
				["CONTINUE", "NEW QUEST", "SETTINGS", "QUIT"],
				[], [has_save, true, true, true], false)
		match pick:
			0:
				_begin(true)
				return
			1:
				_begin(false)
				return
			2:
				await _settings.open_settings()
				_refresh_save_note()
			3:
				get_tree().quit()
				return


func _begin(from_save: bool) -> void:
	Boot.continue_from_save = from_save
	get_tree().change_scene_to_file("res://scenes/main.tscn")
