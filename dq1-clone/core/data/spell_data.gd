## One spell. Power is stored per caster because the original game gives
## monsters different ranges than the hero for the same named spell.
class_name SpellData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var mp_cost: int = 0
@export_enum("damage", "heal", "sleep", "stopspell", "field") var kind: String = "damage"
## 0 means monsters-only (the hero never learns it).
@export var learn_level: int = 0

@export_group("Power (hero casting)")
@export var hero_power_min: int = 0
@export var hero_power_max: int = 0

@export_group("Power (monster casting)")
@export var monster_power_min: int = 0
@export var monster_power_max: int = 0

@export_group("Usable in")
@export var usable_in_battle: bool = true
@export var usable_in_field: bool = false
