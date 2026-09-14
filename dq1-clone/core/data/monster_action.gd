## One entry in a monster's behaviour table.
class_name MonsterAction
extends Resource

@export_enum("attack", "spell", "flee") var kind: String = "attack"
## Only for kind == "spell".
@export var spell_id: StringName = &""
## Relative pick weight among the eligible actions.
@export var weight: int = 1
## Only eligible while the monster's HP ratio is at or below this.
## 1.0 means "always eligible".
@export_range(0.0, 1.0) var hp_threshold: float = 1.0
