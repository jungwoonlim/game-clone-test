## The player character: stats, equipment, inventory, progress.
##
## Named `total_exp` rather than `exp` on purpose — `exp` is a built-in GDScript
## math function and shadowing it is a trap waiting to happen.
class_name Hero
extends RefCounted

var display_name: String = "Hero"

var level: int = 1
var total_exp: int = 0
var gold: int = 0

var strength: int = 0
var agility: int = 0
var max_hp: int = 1
var max_mp: int = 0
var hp: int = 1
var mp: int = 0

const INVENTORY_MAX := 10

var weapon_id: StringName = &""
var armor_id: StringName = &""
var shield_id: StringName = &""
var inventory: Array[StringName] = []


static func create_new(db: GameDatabase) -> Hero:
	var hero := Hero.new()
	hero.gold = db.start_gold
	hero.weapon_id = db.start_weapon
	hero.armor_id = db.start_armor
	hero.shield_id = db.start_shield
	hero.apply_level(db.level_curve, 1, true)
	return hero


## Sets the stats for `new_level` from the curve. Current HP/MP keep their
## value unless `restore` is set, so a level-up does not silently heal.
func apply_level(curve: LevelCurve, new_level: int, restore: bool = false) -> void:
	var clamped := clampi(new_level, 1, curve.max_level())
	var previous_max_hp := max_hp
	var previous_max_mp := max_mp

	level = clamped
	strength = curve.strength[clamped - 1]
	agility = curve.agility[clamped - 1]
	max_hp = curve.max_hp[clamped - 1]
	max_mp = curve.max_mp[clamped - 1]

	if restore:
		hp = max_hp
		mp = max_mp
	else:
		# A level-up grants the difference, it does not top you up.
		hp = clampi(hp + maxi(0, max_hp - previous_max_hp), 1, max_hp)
		mp = clampi(mp + maxi(0, max_mp - previous_max_mp), 0, max_mp)


# --- 소지품 ---------------------------------------------------------------

func has_room() -> bool:
	return inventory.size() < INVENTORY_MAX


func add_item(id: StringName) -> bool:
	if not has_room():
		return false
	inventory.append(id)
	return true


func remove_item(id: StringName) -> bool:
	var index := inventory.find(id)
	if index < 0:
		return false
	inventory.remove_at(index)
	return true


func has_item(id: StringName) -> bool:
	return inventory.has(id)


func equipped_id(kind: String) -> StringName:
	match kind:
		"weapon":
			return weapon_id
		"armor":
			return armor_id
		"shield":
			return shield_id
	return &""


func set_equipped(kind: String, id: StringName) -> void:
	match kind:
		"weapon":
			weapon_id = id
		"armor":
			armor_id = id
		"shield":
			shield_id = id


func attack_power(db: GameDatabase) -> int:
	var weapon := db.item(weapon_id)
	return Formulas.attack_power(strength, weapon.attack_bonus if weapon else 0)


func defense_power(db: GameDatabase) -> int:
	var armor := db.item(armor_id)
	var shield := db.item(shield_id)
	return Formulas.defense_power(
			agility,
			armor.defense_bonus if armor else 0,
			shield.defense_bonus if shield else 0)


func hurt_reduction(db: GameDatabase) -> float:
	var armor := db.item(armor_id)
	return armor.hurt_reduction if armor else 0.0


func blocks_terrain_damage(db: GameDatabase) -> bool:
	var armor := db.item(armor_id)
	return armor.blocks_terrain_damage if armor else false


func is_alive() -> bool:
	return hp > 0


func restore_fully() -> void:
	hp = max_hp
	mp = max_mp


func to_battle_actor(db: GameDatabase) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = display_name
	actor.is_hero = true
	actor.max_hp = max_hp
	actor.hp = hp
	actor.max_mp = max_mp
	actor.mp = mp
	actor.attack_power = attack_power(db)
	actor.defense_power = defense_power(db)
	actor.agility = agility
	actor.hurt_reduction = hurt_reduction(db)
	# The hero has no innate sleep resistance; Stopspell is a coin flip. [PICKED]
	actor.resist_sleep = 0
	actor.resist_stopspell = 128
	actor.known_spells = db.spells_up_to_level(level)
	return actor


## Copies the mutable battle results (HP/MP) back onto the hero.
func absorb_battle_actor(actor: BattleActor) -> void:
	hp = clampi(actor.hp, 0, max_hp)
	mp = clampi(actor.mp, 0, max_mp)
