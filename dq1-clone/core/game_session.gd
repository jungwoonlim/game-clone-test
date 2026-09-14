## The single entry point into core/.
##
## Owns the database, the hero, the world and the current battle, and is the
## only place that stitches them together. Both the field view and the headless
## tools drive the game through this, so they exercise identical code paths.
class_name GameSession
extends RefCounted

signal encounter_started(monster_id: StringName)
signal battle_finished(result: int)
signal hero_died()

var db: GameDatabase
var hero: Hero
var world: WorldState
var rng: Rng
var battle: BattleState = null


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
		var gained := Progression.award(hero, db, battle.exp_reward, battle.gold_reward)
		for level in gained["levels"]:
			events.append(BattleEvent.new(BattleEvent.Kind.LEVEL_UP, true, level))
		for spell in gained["spells"]:
			events.append(BattleEvent.new(
					BattleEvent.Kind.SPELL_LEARNED, true, 0, spell.display_name))

	var finished_result := battle.result
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
## The save point is the start map until M4 lands.
func respawn() -> int:
	var lost := Progression.apply_death(hero)
	world.enter_map(db.start_map)
	return lost


func _on_encounter_started(monster_id: StringName) -> void:
	encounter_started.emit(monster_id)


func _on_hero_collapsed() -> void:
	hero_died.emit()
