## A combatant. The hero and monsters use the same shape so the battle loop
## does not have to special-case either side.
class_name BattleActor
extends RefCounted

## The data id this actor was built from — what battle events name.
var id: StringName = &""
var display_name: String = ""
var is_hero: bool = false

var max_hp: int = 1
var hp: int = 1
var max_mp: int = 0
var mp: int = 0

var attack_power: int = 0
var defense_power: int = 0
var agility: int = 0

var resist_sleep: int = 0
var resist_stopspell: int = 0
var hurt_reduction: float = 0.0

var can_be_critical: bool = true
var can_flee_from: bool = true

## Set for monsters; null for the hero.
var monster: MonsterData = null
## Set for the hero; empty for monsters.
var known_spells: Array[SpellData] = []
## Snapshot of the hero's bag, so the battle can tell a herb it actually has
## from one it was merely asked to use. Kept in step as items are spent.
var carried_items: Array[StringName] = []

var asleep: bool = false
var sleep_guaranteed_left: int = 0
var spell_sealed: bool = false


static func from_monster(data: MonsterData) -> BattleActor:
	var a := BattleActor.new()
	a.id = data.id
	a.display_name = data.display_name
	a.is_hero = false
	a.max_hp = data.max_hp
	a.hp = data.max_hp
	a.max_mp = data.max_mp
	a.mp = data.max_mp
	a.attack_power = data.strength
	a.defense_power = Formulas.monster_defense(data.agility)
	a.agility = data.agility
	a.resist_sleep = data.resist_sleep
	a.resist_stopspell = data.resist_stopspell
	a.hurt_reduction = data.resist_hurt
	a.can_be_critical = data.can_be_critical
	a.can_flee_from = data.can_flee_from
	a.monster = data
	return a


func is_alive() -> bool:
	return hp > 0


func hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(hp) / float(max_hp)


## Returns the damage actually dealt.
func take_damage(amount: int) -> int:
	var dealt := clampi(amount, 0, hp)
	hp -= dealt
	return dealt


## Returns the HP actually restored.
func restore_hp(amount: int) -> int:
	var healed := clampi(amount, 0, max_hp - hp)
	hp += healed
	return healed


func carries_item(id: StringName) -> bool:
	return carried_items.has(id)


## Takes one off the snapshot. False when there was none to take.
func consume_item(id: StringName) -> bool:
	var index := carried_items.find(id)
	if index < 0:
		return false
	carried_items.remove_at(index)
	return true


func knows_spell(id: StringName) -> bool:
	for s in known_spells:
		if s.id == id:
			return true
	return false


func spell_by_id(id: StringName) -> SpellData:
	for s in known_spells:
		if s.id == id:
			return s
	return null


func apply_sleep() -> void:
	asleep = true
	sleep_guaranteed_left = Formulas.SLEEP_GUARANTEED_TURNS
