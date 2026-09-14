## A treasure chest sitting on a map tile. Opening it is remembered with a
## story flag, so a reloaded save cannot farm the same chest twice.
class_name ChestPlacement
extends Resource

@export var cell: Vector2i = Vector2i.ZERO
@export var item_id: StringName = &""
@export var gold: int = 0


func flag_for(map_id: StringName) -> StringName:
	return StringName("chest_%s_%d_%d" % [map_id, cell.x, cell.y])
