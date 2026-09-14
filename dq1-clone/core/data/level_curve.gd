## Level progression, stored as absolute values per level rather than as
## per-level gains. The original game uses a lookup table and so do we: it is
## what the source data actually is, and it makes verification a direct compare.
class_name LevelCurve
extends Resource

## Cumulative EXP needed to REACH level index+2. Length = max_level - 1.
@export var required_exp: Array[int] = []

## Absolute stat at level index+1. Length = max_level.
@export var strength: Array[int] = []
@export var agility: Array[int] = []
@export var max_hp: Array[int] = []
@export var max_mp: Array[int] = []


func max_level() -> int:
	return strength.size()


## Highest level whose EXP requirement is met.
func level_for_exp(total_exp: int) -> int:
	var level := 1
	for i in required_exp.size():
		if total_exp >= required_exp[i]:
			level = i + 2
		else:
			break
	return level


## EXP still needed to reach the next level, or -1 at max level.
func exp_to_next(total_exp: int) -> int:
	var level := level_for_exp(total_exp)
	if level >= max_level():
		return -1
	return required_exp[level - 1] - total_exp
