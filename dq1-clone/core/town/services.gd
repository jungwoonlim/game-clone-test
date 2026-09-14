## Shops, the inn, and putting equipment on.
##
## Pure functions over a Hero and the database; no UI, no scenes. Equipped gear
## is NOT in the inventory — equipping moves an item out of the bag and the
## piece it replaces back in, which keeps the bag count honest.
class_name TownServices
extends RefCounted

enum Result {
	OK,
	NOT_ENOUGH_GOLD,
	INVENTORY_FULL,
	NOT_IN_STOCK,
	NOT_OWNED,
	NOT_EQUIPPABLE,
	ALREADY_FULL_HEALTH,
	UNKNOWN_ITEM,
}


static func buy(hero: Hero, db: GameDatabase, item_id: StringName) -> Result:
	var item := db.item(item_id)
	if item == null:
		return Result.UNKNOWN_ITEM
	if hero.gold < item.buy_price:
		return Result.NOT_ENOUGH_GOLD
	if not hero.has_room():
		return Result.INVENTORY_FULL
	hero.gold -= item.buy_price
	hero.add_item(item_id)
	return Result.OK


static func sell(hero: Hero, db: GameDatabase, item_id: StringName) -> Result:
	var item := db.item(item_id)
	if item == null:
		return Result.UNKNOWN_ITEM
	if not hero.remove_item(item_id):
		return Result.NOT_OWNED
	hero.gold += item.sell_price
	return Result.OK


## Swaps the item into its slot, returning whatever was there to the bag.
static func equip(hero: Hero, db: GameDatabase, item_id: StringName) -> Result:
	var item := db.item(item_id)
	if item == null:
		return Result.UNKNOWN_ITEM
	if item.kind != "weapon" and item.kind != "armor" and item.kind != "shield":
		return Result.NOT_EQUIPPABLE
	if not hero.has_item(item_id):
		return Result.NOT_OWNED

	hero.remove_item(item_id)
	var previous := hero.equipped_id(item.kind)
	hero.set_equipped(item.kind, item_id)
	if previous != &"":
		# The bag just freed a slot, so this always fits.
		hero.add_item(previous)
	return Result.OK


static func rest(hero: Hero, price: int) -> Result:
	if hero.gold < price:
		return Result.NOT_ENOUGH_GOLD
	if hero.hp >= hero.max_hp and hero.mp >= hero.max_mp:
		return Result.ALREADY_FULL_HEALTH
	hero.gold -= price
	hero.restore_fully()
	return Result.OK


## Consumables used outside battle. Returns HP restored, or -1 if unusable.
##
## A herb at full HP is unusable, not a no-op: healing nothing and swallowing
## the herb anyway is the one outcome the player never intends. Field Heal
## already refuses the same way rather than spending the MP.
static func use_item(hero: Hero, db: GameDatabase, item_id: StringName) -> int:
	var item := db.item(item_id)
	if item == null or item.kind != "consumable" or item.effect_id != &"heal_hp":
		return -1
	if not hero.has_item(item_id):
		return -1
	if hero.hp >= hero.max_hp:
		return -1
	var healed := mini(item.effect_power, hero.max_hp - hero.hp)
	hero.hp += healed
	hero.remove_item(item_id)
	return healed
