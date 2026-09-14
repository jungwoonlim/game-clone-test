## Stepping onto `from_cell` moves the party to `to_cell` on `to_map`.
class_name WarpPoint
extends Resource

@export var from_cell: Vector2i = Vector2i.ZERO
@export var to_map: StringName = &""
@export var to_cell: Vector2i = Vector2i.ZERO
