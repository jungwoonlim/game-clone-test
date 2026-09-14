## Stats and behaviour for one monster species.
class_name MonsterData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Stats")
@export var max_hp: int = 1
## Spell-casting monsters need a pool to spend; 0 for the rest.
@export var max_mp: int = 0
## Used directly as the monster's attack power.
@export var strength: int = 1
## Doubles as the monster's defence (see Formulas.monster_defense).
@export var agility: int = 1

@export_group("Rewards")
@export var exp_reward: int = 0
@export var gold_reward_min: int = 0
@export var gold_reward_max: int = 0

@export_group("Behaviour")
@export var actions: Array[MonsterAction] = []

@export_group("Resistances")
## 0 = no resistance, 255 = immune.
@export_range(0, 255) var resist_sleep: int = 0
@export_range(0, 255) var resist_stopspell: int = 0
## Fraction of Hurt-family damage ignored.
@export_range(0.0, 1.0) var resist_hurt: float = 0.0

@export_group("Rules")
@export var can_flee_from: bool = true
@export var can_be_critical: bool = true
## Bosses and set-piece fights.
@export var is_boss: bool = false
## When HP hits zero, become this monster at full health instead of dying.
@export var transforms_into: StringName = &""
