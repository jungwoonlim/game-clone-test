## Checks everything M6 added: generated audio, generated art, settings
## persistence and the title screen.
##
##   godot --headless --path . --script res://tools/test_presentation.gd
##
## The load-bearing check here is the sound-name sweep: a typo in a
## `sfx("sfx_atack")` call is silent at runtime and invisible in a screenshot,
## so every name referenced in the view scripts is resolved against the files
## that actually exist.
extends SceneTree

const ART_DIR := "res://assets/art"
const AUDIO_DIR := "res://assets/audio"
const SCRIPT_DIRS := ["res://scenes", "res://view_2d"]

var _failures: Array[String] = []
var _checks := 0
var _db: GameDatabase


var _frames := 0
var _started := false


## Autoloads are attached after _initialize, so the checks wait a frame.
func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3 or _started:
		return false
	_started = true
	_run()
	return false


func _run() -> void:
	_db = GameDatabase.load_default()
	_test_audio_files()
	_test_sound_references()
	_test_art_sheets()
	_test_settings_round_trip()
	await _test_title_screen()
	await _test_continue_from_save()

	print("[presentation] %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr("  FAIL  %s" % failure)
	quit(1 if _failures.size() > 0 else 0)


## CONTINUE has to actually resume: the title only sets a flag, and main is
## what has to honour it.
func _test_continue_from_save() -> void:
	SaveGame.erase()
	var seeded := GameSession.create_new(1, _db)
	Progression.award(seeded.hero, _db, 2500, 640)
	seeded.set_flag(&"heard_quest")
	seeded.world.enter_map(&"field", Vector2i(28, 26))
	_check(seeded.save_game() == OK, "could not write a save to resume from")

	Boot.continue_from_save = true
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var session: GameSession = main.get("_session")
	_check(session != null, "the game scene made no session")
	if session != null:
		_check(session.hero.level == seeded.hero.level,
				"resumed at level %d, saved at %d"
				% [session.hero.level, seeded.hero.level])
		_check(session.hero.gold == seeded.hero.gold, "resumed with the wrong gold")
		_check(session.world.map.id == &"field", "resumed on the wrong map")
		_check(session.world.cell == Vector2i(28, 26), "resumed in the wrong place")
	_check(not Boot.continue_from_save, "the continue flag was not cleared")

	main.queue_free()
	SaveGame.erase()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# --- 오디오 ---------------------------------------------------------------

func _audio_names() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		return names
	for file in dir.get_files():
		if file.ends_with(".tres"):
			names.append(file.get_basename())
	return names


## Silence and clipping both sound like a bug and neither shows up anywhere
## else, so each stream is measured rather than merely loaded.
func _test_audio_files() -> void:
	var names := _audio_names()
	_check(names.size() >= 20, "only %d audio streams; run build_audio.gd" % names.size())

	for name in names:
		var stream: AudioStreamWAV = load("%s/%s.tres" % [AUDIO_DIR, name])
		_check(stream != null, "%s did not load" % name)
		if stream == null:
			continue
		_check(stream.get_length() > 0.01, "%s is empty" % name)
		_check(stream.data.size() > 0, "%s carries no samples" % name)

		var peak := 0.0
		var energy := 0.0
		var count := stream.data.size() / 2
		for i in count:
			var sample := float(stream.data.decode_s16(i * 2)) / 32768.0
			peak = maxf(peak, absf(sample))
			energy += sample * sample
		var rms: float = sqrt(energy / maxf(float(count), 1.0))
		_check(peak > 0.05, "%s is silent (peak %.3f)" % [name, peak])
		_check(peak <= 1.0, "%s clips (peak %.3f)" % [name, peak])
		_check(rms > 0.005, "%s is almost silent (rms %.4f)" % [name, rms])

		if name.begins_with("bgm_"):
			_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
					"%s does not loop" % name)
			_check(stream.get_length() > 2.0,
					"%s is only %.1fs long" % [name, stream.get_length()])


## Sweeps the view scripts for sound names and resolves every one.
func _test_sound_references() -> void:
	var available := {}
	for name in _audio_names():
		available[name] = true

	var pattern := RegEx.new()
	pattern.compile("\"((?:sfx|bgm)_[a-z0-9_]+)\"")

	var referenced := {}
	for dir_path in SCRIPT_DIRS:
		for path in _scripts_in(dir_path):
			var text := FileAccess.get_file_as_string(path)
			for match in pattern.search_all(text):
				referenced[match.get_string(1)] = path

	_check(referenced.size() > 10,
			"only %d sound references found; the sweep is not working"
			% referenced.size())
	for name in referenced:
		_check(available.has(name),
				"%s references missing sound \"%s\"" % [referenced[name], name])


func _scripts_in(path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append("%s/%s" % [path, file])
	for sub in dir.get_directories():
		out.append_array(_scripts_in("%s/%s" % [path, sub]))
	return out


## Reads through the import pipeline, the way the game does.
func _sheet(path: String) -> Image:
	var texture: Texture2D = load(path)
	return texture.get_image() if texture != null else null


# --- 아트 -----------------------------------------------------------------

func _test_art_sheets() -> void:
	var monsters := _sheet("%s/monsters.png" % ART_DIR)
	_check(monsters != null, "monsters.png is missing; run build_sprites.gd")
	if monsters != null:
		_check(monsters.get_height() == 24, "monster sheet is %d tall" % monsters.get_height())
		_check(monsters.get_width() == 24 * _db.monsters.size(),
				"monster sheet has %d columns for %d monsters"
				% [monsters.get_width() / 24, _db.monsters.size()])

	# Every monster must map to a column, or it draws as nothing at all.
	var columns: Dictionary = load("res://view_2d/ui/monster_sprite.gd").COLUMNS
	for monster in _db.monsters:
		_check(columns.has(monster.id),
				"%s has no sprite column" % monster.id)

	var hero := _sheet("%s/hero.png" % ART_DIR)
	_check(hero != null, "hero.png is missing")
	if hero != null:
		_check(hero.get_width() == 32 and hero.get_height() == 64,
				"hero sheet is %dx%d, expected 32x64 (2 frames x 4 facings)"
				% [hero.get_width(), hero.get_height()])

	var npcs := _sheet("%s/npcs.png" % ART_DIR)
	_check(npcs != null, "npcs.png is missing")
	if npcs != null:
		_check(npcs.get_width() == 64 and npcs.get_height() == 16,
				"npc sheet is %dx%d, expected 64x16" % [npcs.get_width(), npcs.get_height()])

	var tiles := _sheet("res://view_2d/field/terrain_tiles.png")
	_check(tiles != null, "terrain_tiles.png is missing")
	if tiles != null:
		_check(tiles.get_width() == 16 * Terrain.Type.size(),
				"tile atlas has %d tiles for %d terrain types"
				% [tiles.get_width() / 16, Terrain.Type.size()])

	# Every map's tiles must exist in the atlas.
	for map in _db.maps:
		var highest := 0
		for value in map.tiles:
			highest = maxi(highest, value)
		_check(highest < Terrain.Type.size(),
				"%s uses terrain id %d which has no tile" % [map.id, highest])


# --- 설정 / 타이틀 --------------------------------------------------------

func _test_settings_round_trip() -> void:
	var settings := root.get_node_or_null("GameSettings")
	_check(settings != null, "GameSettings autoload is missing")
	if settings == null:
		return

	var music: float = settings.music_volume
	var sfx: float = settings.sfx_volume
	var full: bool = settings.fullscreen

	settings.set_music_volume(0.35)
	settings.set_sfx_volume(0.15)
	settings.set_fullscreen(not full)
	settings.load_settings()
	_check(is_equal_approx(settings.music_volume, 0.35),
			"music volume did not persist (%.2f)" % settings.music_volume)
	_check(is_equal_approx(settings.sfx_volume, 0.15),
			"sfx volume did not persist (%.2f)" % settings.sfx_volume)
	_check(settings.fullscreen == (not full), "window mode did not persist")

	# Volumes must actually reach the mixer, not just the config file.
	settings.set_music_volume(0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),
			"music at zero did not mute the bus")
	settings.set_music_volume(1.0)
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")),
			"music bus stayed muted")

	settings.set_music_volume(music)
	settings.set_sfx_volume(sfx)
	settings.set_fullscreen(full)


func _test_title_screen() -> void:
	SaveGame.erase()
	var title: Node = load("res://scenes/title.tscn").instantiate()
	root.add_child(title)
	await process_frame
	await process_frame

	var menu: CommandWindow = title.get_node("Menu")
	_check(menu.is_open(), "the title menu never opened")
	var labels: Array = menu.get("_labels")
	var enabled: Array = menu.get("_enabled")
	_check(labels.size() == 4, "title menu has %d entries" % labels.size())
	_check(labels[0] == "CONTINUE", "the first title entry is %s" % labels[0])
	_check(enabled.size() > 0 and not enabled[0],
			"CONTINUE is selectable with no save file")

	var director := root.get_node_or_null("AudioDirector")
	_check(director != null and director.current_bgm() == "bgm_town",
			"the title screen plays no music")

	title.queue_free()
