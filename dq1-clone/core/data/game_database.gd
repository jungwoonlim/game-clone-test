## Every piece of static game data, in one resource.
##
## Loading a single .tres instead of scanning directories keeps this working
## identically in the editor, in headless tools and in an exported build.
## Regenerate with tools/build_data.gd; after that the .tres files are the
## source of truth and can be edited in the inspector.
class_name GameDatabase
extends Resource

const PATH := "res://core/data/database.tres"

@export var monsters: Array[MonsterData] = []
@export var spells: Array[SpellData] = []
@export var items: Array[ItemData] = []
@export var maps: Array[MapData] = []
@export var encounter_tables: Array[EncounterTable] = []
@export var level_curve: LevelCurve = null

@export_group("New game")
@export var start_map: StringName = &""
@export var start_gold: int = 0
@export var start_weapon: StringName = &""
@export var start_armor: StringName = &""
@export var start_shield: StringName = &""

var _monster_index: Dictionary = {}
var _spell_index: Dictionary = {}
var _item_index: Dictionary = {}
var _map_index: Dictionary = {}
var _encounter_index: Dictionary = {}
var _indexed := false


static func load_default() -> GameDatabase:
	var db: GameDatabase = load(PATH)
	if db != null:
		db.build_index()
	return db


func build_index() -> void:
	_monster_index.clear()
	_spell_index.clear()
	_item_index.clear()
	_map_index.clear()
	_encounter_index.clear()
	for m in monsters:
		_monster_index[m.id] = m
	for s in spells:
		_spell_index[s.id] = s
	for i in items:
		_item_index[i.id] = i
	for m in maps:
		_map_index[m.id] = m
	for t in encounter_tables:
		_encounter_index[t.id] = t
	_indexed = true


func _ensure_index() -> void:
	if not _indexed:
		build_index()


func monster(id: StringName) -> MonsterData:
	_ensure_index()
	return _monster_index.get(id)


func spell(id: StringName) -> SpellData:
	_ensure_index()
	return _spell_index.get(id)


func item(id: StringName) -> ItemData:
	_ensure_index()
	return _item_index.get(id)


func map(id: StringName) -> MapData:
	_ensure_index()
	return _map_index.get(id)


func encounter_table(id: StringName) -> EncounterTable:
	_ensure_index()
	return _encounter_index.get(id)


## Spells the hero knows at `level`, in learning order.
func spells_up_to_level(level: int) -> Array[SpellData]:
	var out: Array[SpellData] = []
	for s in spells:
		if s.learn_level > 0 and s.learn_level <= level:
			out.append(s)
	out.sort_custom(func(a: SpellData, b: SpellData) -> bool:
		return a.learn_level < b.learn_level)
	return out


## Spells whose learn level is exactly `level`.
func spells_learned_at(level: int) -> Array[SpellData]:
	var out: Array[SpellData] = []
	for s in spells:
		if s.learn_level == level:
			out.append(s)
	return out
