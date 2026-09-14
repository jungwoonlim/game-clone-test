class_name EncounterEntry
extends Resource

@export var monster_id: StringName = &""
@export var weight: int = 1
## Repel keeps out monsters whose tier is below the hero's level.
## This is the tier used for that comparison.
@export var tier: int = 1
