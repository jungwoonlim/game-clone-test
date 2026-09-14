## The single entry point into core/.
##
## Owns the database, the hero, the world and the current battle, and is the
## only place that stitches them together. Both the field view and the headless
## tools drive the game through this, so they exercise identical code paths.
class_name GameSession
extends RefCounted

const REPEL_DURATION := 64
const RADIANT_RADIUS := 3
const RADIANT_DURATION := 80
const TORCH_DURATION := 120

enum FieldSpell { OK, NOT_KNOWN, NO_MP, NOT_HERE, NO_EFFECT }

signal encounter_started(monster_id: StringName)
signal battle_finished(result: int)
signal hero_died()

var db: GameDatabase
var hero: Hero
var world: WorldState
var rng: Rng
var battle: BattleState = null
## Story flags, set by dialogue and events. Only true values are saved.
var flags: Dictionary = {}
## Set while a set-piece fight is in progress, so winning can record it.
var _pending_boss_flag: StringName = &""


static func create_new(seed_value: int = 0, database: GameDatabase = null) -> GameSession:
	var session := GameSession.new()
	session.db = database if database != null else GameDatabase.load_default()
	if session.db == null:
		push_error("GameSession: no database. Run tools/build_data.gd first.")
		return null
	session.rng = Rng.new(seed_value)
	session.hero = Hero.create_new(session.db)
	session.world = WorldState.new(session.db, session.hero, session.rng)
	session.world.encounter_started.connect(session._on_encounter_started)
	session.world.hero_collapsed.connect(session._on_hero_collapsed)
	session.world.map_changed.connect(session._on_map_changed)
	session.world.enter_map(session.db.start_map)
	return session


func in_battle() -> bool:
	return battle != null and not battle.is_over()


# --- 전투 -----------------------------------------------------------------

## Builds the battle and returns its opening events (including a monster's
## free action if it won initiative).
func begin_battle(monster_id: StringName) -> Array[BattleEvent]:
	var data := db.monster(monster_id)
	if data == null:
		return []
	battle = BattleState.new(
			hero.to_battle_actor(db), BattleActor.from_monster(data), rng, db)
	var events := battle.start()
	_sync_after(events)
	return events


func battle_command(command: BattleState.Command,
		argument: StringName = &"") -> Array[BattleEvent]:
	if battle == null or battle.is_over():
		return []
	var events := battle.resolve_turn(command, argument)
	# BattleState heals from the item but has no bag to take it out of, so the
	# session is what actually spends it.
	if command == BattleState.Command.ITEM:
		for event in events:
			if event.kind == BattleEvent.Kind.ITEM_USED:
				hero.remove_item(argument)
				break
	_sync_after(events)
	return events


## Pulls HP/MP back onto the hero and, when the fight just ended, applies the
## rewards — appending the level-up events so the view gets one ordered stream.
func _sync_after(events: Array[BattleEvent]) -> void:
	if battle == null:
		return
	hero.absorb_battle_actor(battle.hero)
	if not battle.is_over():
		return

	if battle.result == BattleState.Result.HERO_WON:
		if _pending_boss_flag != &"":
			set_flag(_pending_boss_flag)
			_refresh_boss_availability()
		var gained := Progression.award(hero, db, battle.exp_reward, battle.gold_reward)
		for level in gained["levels"]:
			events.append(BattleEvent.new(BattleEvent.Kind.LEVEL_UP, true, level))
		for spell in gained["spells"]:
			events.append(BattleEvent.new(
					BattleEvent.Kind.SPELL_LEARNED, true, 0, spell.display_name))

	var finished_result := battle.result
	_pending_boss_flag = &""
	battle = null
	battle_finished.emit(finished_result)
	if finished_result == BattleState.Result.HERO_DIED:
		hero_died.emit()


# --- 필드 -----------------------------------------------------------------

func try_move(direction: Vector2i) -> bool:
	if in_battle():
		return false
	return world.try_move(direction)


## Death: half the gold is gone and you wake up where you last saved.
func respawn() -> int:
	var lost := Progression.apply_death(hero)
	world.repel_steps = 0
	world.light_steps = 0
	world.light_bonus = 0
	world.enter_map(db.start_map)
	return lost


# --- 마을 -----------------------------------------------------------------

func has_flag(flag: StringName) -> bool:
	return flag != &"" and flags.get(flag, false)


func set_flag(flag: StringName) -> void:
	if flag != &"":
		flags[flag] = true


func npc_in_front() -> NpcPlacement:
	return world.npc_in_front()


## Picks the first dialogue entry whose flags match, and applies its set_flag.
func talk_to(npc: NpcPlacement) -> DialogueEntry:
	if npc == null:
		return null
	for entry in npc.dialogue:
		if entry.required_flag != &"" and not has_flag(entry.required_flag):
			continue
		if entry.forbidden_flag != &"" and has_flag(entry.forbidden_flag):
			continue
		set_flag(entry.set_flag)
		return entry
	return null


func buy(item_id: StringName) -> TownServices.Result:
	return TownServices.buy(hero, db, item_id)


func sell(item_id: StringName) -> TownServices.Result:
	return TownServices.sell(hero, db, item_id)


func equip(item_id: StringName) -> TownServices.Result:
	return TownServices.equip(hero, db, item_id)


func rest(price: int) -> TownServices.Result:
	return TownServices.rest(hero, price)


## Returns { effect: "heal" | "light" | "none", amount: int }.
func use_item_in_field(item_id: StringName) -> Dictionary:
	var item := db.item(item_id)
	if item == null or not hero.has_item(item_id):
		return {"effect": "none", "amount": 0}

	if item.effect_id == &"light":
		if not world.map.is_dungeon:
			return {"effect": "none", "amount": 0}
		world.light_bonus = maxi(world.light_bonus, item.effect_power)
		world.light_steps = TORCH_DURATION
		hero.remove_item(item_id)
		return {"effect": "light", "amount": TORCH_DURATION}

	var healed := TownServices.use_item(hero, db, item_id)
	if healed < 0:
		return {"effect": "none", "amount": 0}
	return {"effect": "heal", "amount": healed}


## Opens whatever the party is standing on.
## Returns { found, empty, full, item, gold }.
func open_chest_here() -> Dictionary:
	var result := {"found": false, "empty": false, "full": false,
			"item": &"", "gold": 0}
	var chest := world.map.chest_at(world.cell)
	if chest == null:
		return result
	result["found"] = true

	var flag := chest.flag_for(world.map.id)
	if has_flag(flag):
		result["empty"] = true
		return result
	if chest.item_id != &"" and not hero.has_room():
		result["full"] = true
		return result

	set_flag(flag)
	hero.gold += chest.gold
	if chest.item_id != &"":
		hero.add_item(chest.item_id)
	result["item"] = chest.item_id
	result["gold"] = chest.gold
	return result


func is_chest_open(map_id: StringName, chest: ChestPlacement) -> bool:
	return has_flag(chest.flag_for(map_id))


# --- 필드 주문 ------------------------------------------------------------

## Returns { result: FieldSpell, amount: int }.
func cast_in_field(spell_id: StringName) -> Dictionary:
	var spell := db.spell(spell_id)
	if spell == null or not spell.usable_in_field:
		return {"result": FieldSpell.NOT_KNOWN, "amount": 0}
	if spell.learn_level <= 0 or hero.level < spell.learn_level:
		return {"result": FieldSpell.NOT_KNOWN, "amount": 0}
	if hero.mp < spell.mp_cost:
		return {"result": FieldSpell.NO_MP, "amount": 0}

	var amount := 0
	match spell.id:
		&"heal", &"healmore":
			if hero.hp >= hero.max_hp:
				return {"result": FieldSpell.NO_EFFECT, "amount": 0}
			amount = mini(rng.range_i(spell.hero_power_min, spell.hero_power_max),
					hero.max_hp - hero.hp)
			hero.hp += amount
		&"repel":
			world.repel_steps = REPEL_DURATION
			amount = REPEL_DURATION
		&"radiant":
			if not world.map.is_dungeon:
				return {"result": FieldSpell.NOT_HERE, "amount": 0}
			world.light_bonus = RADIANT_RADIUS
			world.light_steps = RADIANT_DURATION
			amount = RADIANT_DURATION
		&"return":
			world.enter_map(db.start_map)
		&"outside":
			if not world.map.is_dungeon or world.map.warps.is_empty():
				return {"result": FieldSpell.NOT_HERE, "amount": 0}
			var exit: WarpPoint = world.map.warps[0]
			world.enter_map(exit.to_map, exit.to_cell)
		_:
			return {"result": FieldSpell.NO_EFFECT, "amount": 0}

	hero.mp -= spell.mp_cost
	return {"result": FieldSpell.OK, "amount": amount}


# --- 세이브 ---------------------------------------------------------------

func save_game() -> Error:
	return SaveGame.save(hero, flags, world.map.id, world.cell, world.steps)


func has_save() -> bool:
	return SaveGame.has_save()


## Overwrites this session with the saved one. False when there is no save.
func load_game() -> bool:
	var data := SaveGame.load_into(hero, db)
	if data.is_empty():
		return false
	flags = data["flags"]
	world.steps = data["steps"]
	var map_id: StringName = data["map"]
	if db.map(map_id) == null:
		map_id = db.start_map
	world.enter_map(map_id, data["cell"])
	_refresh_boss_availability()
	return true


func _on_encounter_started(monster_id: StringName) -> void:
	var map := world.map
	if map != null and map.boss_monster == monster_id and map.boss_cell == world.cell:
		_pending_boss_flag = map.boss_flag
	encounter_started.emit(monster_id)


func _on_map_changed(_map_id: StringName, _cell: Vector2i) -> void:
	_refresh_boss_availability()


func _refresh_boss_availability() -> void:
	var map := world.map
	world.boss_available = map != null and map.boss_monster != &"" \
			and not has_flag(map.boss_flag)


func _on_hero_collapsed() -> void:
	hero_died.emit()
