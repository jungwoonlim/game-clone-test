## Equipment and consumables.
class_name ItemData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_enum("weapon", "armor", "shield", "consumable", "key") var kind: String = "consumable"

@export_group("Shop")
@export var buy_price: int = 0
@export var sell_price: int = 0

@export_group("Equipment bonuses")
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
## Fraction of incoming Hurt-family damage ignored while equipped.
@export_range(0.0, 1.0) var hurt_reduction: float = 0.0
## Cancels terrain damage (swamp) while equipped.
@export var blocks_terrain_damage: bool = false

@export_group("Consumable")
@export var effect_id: StringName = &""
@export var effect_power: int = 0
