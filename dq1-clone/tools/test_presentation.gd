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
const STRINGS_CSV := "res://assets/i18n/strings.csv"
const LOCALES := ["en", "ko"]

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
	_test_message_window()
	_test_text_speed()
	_test_battle_backdrop()
	_test_translation_table()
	_test_every_key_is_referenced()
	_test_names_are_translated()
	_test_josa()
	_test_font_covers_every_character()
	await _test_overlapping_flows()
	_test_message_window_forgets()
	await _test_system_menu()

	print("[presentation] %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr("  FAIL  %s" % failure)
	quit(1 if _failures.size() > 0 else 0)


## The window must never draw two lines on the same row. A full log plus a
## line being typed is exactly the case that used to overlap.
func _test_message_window() -> void:
	var window: MessageWindow = load("res://view_2d/ui/message_window.gd").new()
	for i in MessageWindow.MAX_LINES + 3:
		window.push("line %d" % i)
	_check(window.visible_lines().size() == MessageWindow.MAX_LINES,
			"a full log shows %d rows, expected %d"
			% [window.visible_lines().size(), MessageWindow.MAX_LINES])

	window.set("_partial", "typing...")
	var shown := window.visible_lines()
	_check(shown.size() == MessageWindow.MAX_LINES,
			"log plus a typing line shows %d rows, expected %d"
			% [shown.size(), MessageWindow.MAX_LINES])
	_check(shown[shown.size() - 1] == "typing...",
			"the line being typed is not on the last row")
	_check(not shown.slice(0, shown.size() - 1).has("typing..."),
			"the typing line is duplicated among the committed lines")

	window.clear()
	_check(window.visible_lines().is_empty(), "clear left rows behind")
	window.free()


## The intro, a menu, a battle and a death all run as concurrent coroutines.
## Each used to return control with `_mode = FIELD`, so whichever finished
## first unlocked the field while the others were still running — two field
## menus ended up open at once. Control must come back only when the last
## flow is done.
func _test_overlapping_flows() -> void:
	Boot.continue_from_save = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	_check(bool(main.call("is_busy")), "the opening lines did not take control")

	# Open a menu on top of the intro, then close it.
	main.call("_open_field_menu")
	await process_frame
	var command: CommandWindow = main.get("_command")
	_check(command.is_open(), "the field menu did not open over the intro")
	command.chosen.emit(-1)
	await process_frame
	await process_frame
	_check(bool(main.call("is_busy")),
			"closing the menu unlocked the field while the intro was still running")

	# Let everything drain; the field should come back exactly once.
	var message: MessageWindow = main.get("_message")
	var guard := 0
	while bool(main.call("is_busy")) and guard < 4000:
		guard += 1
		if message.is_typing():
			message.request_skip()
		main.set("_awaiting_key", false)
		await process_frame
	_check(guard < 4000, "the field never came back")
	_check(not bool(main.call("is_busy")), "still busy after everything finished")

	main.queue_free()
	await process_frame


func _test_text_speed() -> void:
	var settings := root.get_node_or_null("GameSettings")
	if settings == null:
		return
	var original: int = settings.text_speed
	var seen := {}
	for i in 3:
		settings.text_speed = i
		seen[settings.text_speed_name()] = settings.chars_per_second()
	_check(seen.size() == 3, "text speeds are not distinct: %s" % [seen])
	_check(float(seen["FAST"]) > float(seen["SLOW"]),
			"FAST is not faster than SLOW")

	settings.cycle_text_speed(1)
	settings.save_settings()
	var cycled: int = settings.text_speed
	settings.load_settings()
	_check(settings.text_speed == cycled, "text speed did not persist")
	settings.text_speed = original
	settings.save_settings()


## Every terrain must produce a backdrop; a missing branch draws nothing and
## the battle window ends up floating on a blank rectangle.
func _test_battle_backdrop() -> void:
	var backdrop: Control = load("res://view_2d/ui/battle_backdrop.gd").new()
	backdrop.size = Vector2(512, 384)
	var grounds := {}
	for terrain in Terrain.Type.values():
		backdrop.set_terrain(terrain)
		grounds[terrain] = backdrop.get("_ground")
		_check(backdrop.get("_ground") != null, "%s has no backdrop ground"
				% Terrain.type_name(terrain))
	var distinct := {}
	for value in grounds.values():
		distinct[str(value)] = true
	_check(distinct.size() >= 4,
			"only %d distinct backdrops across %d terrain types"
			% [distinct.size(), grounds.size()])
	backdrop.free()


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


## Walking away ends the conversation. Leaving the lines behind is what put
## a shopkeeper's goodbye above a swamp message two maps later.
func _test_message_window_forgets() -> void:
	var window: MessageWindow = load("res://view_2d/ui/message_window.gd").new()
	window.push("one")
	window.push("two")
	_check(window.visible_lines().size() == 2, "the window did not take the lines")
	window.dismiss()
	_check(window.visible_lines().is_empty(),
			"dismissing left %d lines behind" % window.visible_lines().size())
	_check(not window.visible, "an emptied message window is still on screen")
	window.free()


## There was no way to leave the game except closing the window. SYSTEM is
## the last entry of the field menu and ESCAPE opens it directly.
func _test_system_menu() -> void:
	Boot.continue_from_save = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var command: CommandWindow = main.get("_command")
	main.call("_open_field_menu")
	await process_frame
	var labels: Array = command.get("_labels")
	_check(labels.size() == 7, "the field menu has %d entries" % labels.size())
	_check(labels.size() == 7 and labels[6] == Loc.t("MENU_SYSTEM"),
			"the last field menu entry is %s" % labels[-1])
	command.chosen.emit(-1)
	await process_frame

	# ESCAPE reaches the same menu without going through the field menu.
	main.call("_open_system_menu")
	await process_frame
	var submenu: CommandWindow = main.get("_submenu")
	_check(submenu.is_open(), "ESCAPE did not open the system menu")
	var options: Array = submenu.get("_labels")
	_check(options.size() == 3, "the system menu has %d entries" % options.size())

	# Leaving asks first, and starts on the answer that keeps the game.
	submenu.chosen.emit(1)
	await process_frame
	var message: MessageWindow = main.get("_message")
	var guard := 0
	while not submenu.is_open() and guard < 4000:
		guard += 1
		if message.is_typing():
			message.request_skip()
		await process_frame
	_check(guard < 4000, "the title confirmation never asked")
	if submenu.is_open():
		_check(int(submenu.get("_index")) == 0,
				"the confirmation starts on the answer that leaves")
		_check(submenu.get("_labels")[0] == Loc.t("MENU_NO"),
				"the confirmation's first answer is %s" % submenu.get("_labels")[0])
		submenu.chosen.emit(0)
	await process_frame

	main.queue_free()
	await process_frame


# --- 번역 -----------------------------------------------------------------

## The one thing a translation table must never do is show the player a key.
## Every row has to exist in every language, and the two languages have to
## agree on which placeholders the sentence takes — a {gold} that survives
## into Korean as {money} prints the braces to the screen.
func _test_translation_table() -> void:
	var table := _string_table()
	_check(table.size() > 150, "the string table has only %d rows" % table.size())

	var placeholder := RegEx.new()
	placeholder.compile("\\{([a-z_]+)\\}")

	for key in table:
		var slots := {}
		for locale in LOCALES:
			var text: String = table[key][locale]
			_check(text != "", "%s has no %s text" % [key, locale])
			var found := []
			for match in placeholder.search_all(text):
				found.append(match.get_string(1))
			found.sort()
			slots[locale] = found
		_check(slots["en"] == slots["ko"],
				"%s takes %s in English but %s in Korean"
				% [key, slots["en"], slots["ko"]])


## The other direction: a key spelled wrong in the code is silent until a
## player walks into that line. This resolves every literal in the view
## against the table, the way the sound sweep does for sfx names.
func _test_every_key_is_referenced() -> void:
	var table := _string_table()
	var pattern := RegEx.new()
	pattern.compile("\"([A-Z][A-Z0-9_]{3,})\"")

	var referenced := {}
	for dir_path in SCRIPT_DIRS:
		for path in _scripts_in(dir_path):
			var text := FileAccess.get_file_as_string(path)
			for match in pattern.search_all(text):
				var key := match.get_string(1)
				# Only strings that look like table keys; enum names and
				# node paths share the shape but never the prefix.
				if _is_key_like(key):
					referenced[key] = path

	_check(referenced.size() > 60,
			"only %d translation keys found; the sweep is not working"
			% referenced.size())
	for key in referenced:
		_check(_resolves(table, key),
				"%s uses missing translation key \"%s\"" % [referenced[key], key])

	# The two keys that code assembles rather than writes out: the equipment
	# kind comes off the item data, so all three have to be there.
	for kind in ["WEAPON", "ARMOR", "SHIELD"]:
		_check(table.has("KIND_" + kind), "KIND_%s is missing" % kind)


## A key is present if it is in the table, or if it is the base of a
## second-person/third-person pair that BattleText picks between.
func _resolves(table: Dictionary, key: String) -> bool:
	if table.has(key):
		return true
	return table.has(key + "_YOU") and table.has(key + "_IT")


## Data names come from the id, so a new monster with no row in the table
## would fall back to its English display_name and never be translated.
func _test_names_are_translated() -> void:
	var table := _string_table()
	var groups := {
		"ITEM_": _db.items, "MONSTER_": _db.monsters,
		"SPELL_": _db.spells, "MAP_": _db.maps,
	}
	for prefix in groups:
		for entry in groups[prefix]:
			var key: String = prefix + String(entry.id).to_upper()
			_check(table.has(key), "%s has no name row (%s)" % [entry.id, key])

	# NPC dialogue is stored as keys too, so the same hole exists there.
	for map in _db.maps:
		for npc in map.npcs:
			for entry in npc.dialogue:
				for line in entry.lines:
					_check(table.has(String(line)),
							"%s says missing line \"%s\"" % [npc.id, line])


## Korean postpositions are chosen from the word in front of them, so the
## marker has to survive formatting and then disappear. A `#` on screen is
## the failure this catches.
func _test_josa() -> void:
	TranslationServer.set_locale("ko")
	var cases := [
		["MSG_FOUND_ITEM", {"item": Loc.t("ITEM_HERB")}, "약초를"],
		["MSG_FOUND_ITEM", {"item": Loc.t("ITEM_W_SWORD")}, "강철검을"],
		["BT_BATTLE_START", {"monster": Loc.t("MONSTER_M_SLIME")}, "슬라임이"],
		["BT_BATTLE_START", {"monster": Loc.t("MONSTER_M_GHOST")}, "고스트가"],
	]
	for case in cases:
		var text := Loc.t(case[0], case[1])
		_check(text.contains(case[2]),
				"%s read \"%s\", expected to contain \"%s\"" % [case[0], text, case[2]])

	# Nothing in either language may leak a marker.
	for locale in LOCALES:
		TranslationServer.set_locale(locale)
		for key in _string_table():
			_check(not Loc.t(key).contains(Loc.JOSA_MARK),
					"%s leaves a josa marker in %s" % [key, locale])
	TranslationServer.set_locale("en")


## Noto Sans KR's Korean subset has no geometric shapes, so ▶ ■ □ were being
## drawn by whatever CJK font the player's machine happened to have. They
## looked right here and would have been empty boxes on a clean install. Every
## character the game can put on screen has to be in the font we ship.
func _test_font_covers_every_character() -> void:
	var theme: Theme = load("res://assets/theme/dq_theme.tres")
	_check(theme != null and theme.default_font != null, "the project theme has no font")
	if theme == null or theme.default_font == null:
		return
	var font := theme.default_font

	var missing := {}
	for key in _string_table():
		for locale in LOCALES:
			var text: String = _string_table()[key][locale]
			for i in text.length():
				var code := text.unicode_at(i)
				if not font.has_char(code):
					missing["%s U+%04X" % [text[i], code]] = key
	for entry in missing:
		_check(false, "the font has no glyph for %s (%s)" % [entry, missing[entry]])
	_check(missing.is_empty(), "%d characters have no glyph" % missing.size())

	# The numbers and units the windows print without going through the table.
	for character in "0123456789/+-. HPMG":
		_check(font.has_char(character.unicode_at(0)),
				"the font has no glyph for %s" % character)


## A key is a table key when it is one of the prefixes the table uses. This
## keeps the sweep from tripping over enum names and Godot constants.
func _is_key_like(key: String) -> bool:
	# A bare prefix is the front half of a key the code builds from an id.
	if key.ends_with("_"):
		return false
	for prefix in ["MENU_", "MSG_", "BT_", "STAT_", "SET_", "TITLE_", "SYS_",
			"FMT_", "QUEST_", "KIND_", "ITEM_", "MONSTER_", "SPELL_", "MAP_",
			"NPC_"]:
		if key.begins_with(prefix):
			return true
	return false


var _table_cache := {}

## { key: { "en": text, "ko": text } }, read from the CSV the importer reads.
func _string_table() -> Dictionary:
	if not _table_cache.is_empty():
		return _table_cache
	var file := FileAccess.open(STRINGS_CSV, FileAccess.READ)
	if file == null:
		return _table_cache
	var header := file.get_csv_line()
	var columns := {}
	for i in header.size():
		columns[header[i]] = i
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < header.size() or row[0] == "":
			continue
		var entry := {}
		for locale in LOCALES:
			entry[locale] = row[columns[locale]]
		_table_cache[row[0]] = entry
	return _table_cache


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

	_test_language_setting(settings)


## The language is the one setting a player sees before they can find the
## settings menu, so its default is part of what the game is.
func _test_language_setting(settings: Node) -> void:
	var chosen: int = settings.language

	# Korean is the default. The game shipped English-first once, and anybody
	# whose machine was not set to Korean got an English title screen.
	_check(settings.LOCALES[settings.DEFAULT_LANGUAGE] == "ko",
			"the default language is %s" % settings.LOCALES[settings.DEFAULT_LANGUAGE])

	# The file stores the locale code. Storing the index meant reordering
	# LOCALES would quietly switch a saved language to a different one.
	for locale in LOCALES:
		settings.language = settings.LOCALES.find(locale)
		settings.save_settings()
		var config := ConfigFile.new()
		_check(config.load(settings.PATH) == OK, "the settings file did not save")
		_check(config.get_value("text", "language", null) == locale,
				"%s was stored as %s" % [locale, config.get_value("text", "language", null)])
		settings.language = -1
		settings.load_settings()
		_check(settings.LOCALES[settings.language] == locale,
				"%s did not survive a reload" % locale)
		_check(TranslationServer.get_locale() == locale,
				"loading %s left the server on %s" % [locale, TranslationServer.get_locale()])

	settings.language = chosen
	settings.save_settings()


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
	_check(labels[0] == Loc.t("TITLE_CONTINUE"),
			"the first title entry is %s" % labels[0])
	_check(enabled.size() > 0 and not enabled[0],
			"CONTINUE is selectable with no save file")

	var director := root.get_node_or_null("AudioDirector")
	_check(director != null and director.current_bgm() == "bgm_town",
			"the title screen plays no music")

	title.queue_free()
