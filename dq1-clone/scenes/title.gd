## Title screen. Owns nothing but the choice of what happens next.
extends Control

@onready var _menu: CommandWindow = $Menu
@onready var _settings: SettingsWindow = $Settings
@onready var _credits: CreditsWindow = $Credits
@onready var _save_note: Label = $SaveNote


func _ready() -> void:
	var director := get_node_or_null("/root/AudioDirector")
	if director != null:
		director.play_bgm("bgm_town")
	_refresh_save_note()
	_retitle()
	_run_menu()


func _refresh_save_note() -> void:
	_save_note.text = "" if SaveGame.has_save() else Loc.t("TITLE_NO_SAVE")


func _run_menu() -> void:
	while true:
		var has_save := SaveGame.has_save()
		var pick := await _menu.open_menu(
				[Loc.t("TITLE_CONTINUE"), Loc.t("TITLE_NEW"),
				Loc.t("TITLE_SETTINGS"), Loc.t("TITLE_CREDITS"),
				Loc.t("TITLE_QUIT")],
				[], [has_save, true, true, true, true], false)
		match pick:
			0:
				_begin(true)
				return
			1:
				_begin(false)
				return
			2:
				await _settings.open_settings()
				# The language may have just changed under the menu.
				_refresh_save_note()
				_retitle()
			3:
				await _credits.open_credits()
			4:
				get_tree().quit()
				return


## Redraws the parts of the title screen that are not the menu itself.
func _retitle() -> void:
	$Subtitle.text = Loc.t("TITLE_SUBTITLE")
	$Hint.text = Loc.t("TITLE_HINT")


## Which scene opens is a setting, not a build: the 2D and 2.5D views share the
## controller and the UI, so switching is a scene path.
func _begin(from_save: bool) -> void:
	Boot.continue_from_save = from_save
	var settings := get_node_or_null("/root/GameSettings")
	var scene: String = settings.view_scene() if settings != null \
			else "res://scenes/main.tscn"
	get_tree().change_scene_to_file(scene)
