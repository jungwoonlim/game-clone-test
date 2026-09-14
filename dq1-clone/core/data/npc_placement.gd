## An NPC standing on a map. NPCs block movement, so "the tile you are facing"
## is always an unambiguous target for TALK.
class_name NpcPlacement
extends Resource

@export var id: StringName = &""
@export var cell: Vector2i = Vector2i.ZERO
@export_enum("villager", "shop", "inn", "king") var role: String = "villager"

@export_group("Dialogue")
## Checked in order; the first entry whose flags match is the one that plays.
@export var dialogue: Array[DialogueEntry] = []

@export_group("Services")
## For role == "shop".
@export var shop_id: StringName = &""
## For role == "inn".
@export var inn_price: int = 0
