## One thing an NPC can say, gated on story flags.
##
## Not a full branching tree — a prioritised list. The first entry whose flags
## match is the one that plays, so "before you have the key" and "after" are
## just two entries in order.
class_name DialogueEntry
extends Resource

## Only usable while this flag is set. Empty means "no requirement".
@export var required_flag: StringName = &""
## Skipped once this flag is set.
@export var forbidden_flag: StringName = &""
@export var lines: PackedStringArray = PackedStringArray()
## Set when this entry plays.
@export var set_flag: StringName = &""
