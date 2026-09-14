## An NPC standing on a map. Dialogue itself lands in M4.
class_name NpcPlacement
extends Resource

@export var id: StringName = &""
@export var cell: Vector2i = Vector2i.ZERO
@export_enum("villager", "shop_weapon", "shop_armor", "shop_item", "inn", "king") var role: String = "villager"
@export var dialogue_key: String = ""
