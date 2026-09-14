## Save and restore. Only core state is written — nothing about the view.
##
## Takes and returns plain values rather than a GameSession, so the save layer
## and the session do not have to know about each other.
class_name SaveGame
extends RefCounted

const PATH := "user://dq1_clone_save.cfg"


static func has_save() -> bool:
	return FileAccess.file_exists(PATH)


static func erase() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


static func save(hero: Hero, flags: Dictionary, map_id: StringName,
		cell: Vector2i, steps: int) -> Error:
	var config := ConfigFile.new()

	config.set_value("hero", "level", hero.level)
	config.set_value("hero", "total_exp", hero.total_exp)
	config.set_value("hero", "gold", hero.gold)
	config.set_value("hero", "hp", hero.hp)
	config.set_value("hero", "mp", hero.mp)
	config.set_value("hero", "weapon", String(hero.weapon_id))
	config.set_value("hero", "armor", String(hero.armor_id))
	config.set_value("hero", "shield", String(hero.shield_id))

	var bag := PackedStringArray()
	for id in hero.inventory:
		bag.append(String(id))
	config.set_value("hero", "inventory", bag)

	var set_flags := PackedStringArray()
	for key in flags:
		if flags[key]:
			set_flags.append(String(key))
	config.set_value("progress", "flags", set_flags)

	config.set_value("world", "map", String(map_id))
	config.set_value("world", "cell_x", cell.x)
	config.set_value("world", "cell_y", cell.y)
	config.set_value("world", "steps", steps)

	return config.save(PATH)


## Returns {} when there is nothing to load, otherwise
## { map: StringName, cell: Vector2i, steps: int, flags: Dictionary }.
static func load_into(hero: Hero, db: GameDatabase) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return {}

	# Stats come from the curve, not the file: if the curve is retuned, an old
	# save should follow the new numbers rather than keep stale ones.
	hero.total_exp = int(config.get_value("hero", "total_exp", 0))
	hero.apply_level(db.level_curve, db.level_curve.level_for_exp(hero.total_exp), true)
	hero.gold = int(config.get_value("hero", "gold", 0))
	hero.hp = clampi(int(config.get_value("hero", "hp", hero.max_hp)), 1, hero.max_hp)
	hero.mp = clampi(int(config.get_value("hero", "mp", hero.max_mp)), 0, hero.max_mp)
	hero.weapon_id = StringName(config.get_value("hero", "weapon", ""))
	hero.armor_id = StringName(config.get_value("hero", "armor", ""))
	hero.shield_id = StringName(config.get_value("hero", "shield", ""))

	hero.inventory.clear()
	for id in config.get_value("hero", "inventory", PackedStringArray()):
		hero.inventory.append(StringName(id))

	var flags := {}
	for key in config.get_value("progress", "flags", PackedStringArray()):
		flags[StringName(key)] = true

	return {
		"map": StringName(config.get_value("world", "map", "")),
		"cell": Vector2i(int(config.get_value("world", "cell_x", 0)),
				int(config.get_value("world", "cell_y", 0))),
		"steps": int(config.get_value("world", "steps", 0)),
		"flags": flags,
	}
