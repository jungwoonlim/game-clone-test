## Where the party is and what happens when it walks.
##
## Emits signals; never touches a scene. The field view listens and animates.
class_name WorldState
extends RefCounted

signal moved(to_cell: Vector2i, terrain_type: int)
signal move_blocked(to_cell: Vector2i)
signal map_changed(map_id: StringName, cell: Vector2i)
signal terrain_damaged(amount: int)
signal encounter_started(monster_id: StringName)
signal hero_collapsed()

var map: MapData = null
var cell: Vector2i = Vector2i.ZERO
var steps: int = 0
var repel_steps: int = 0
## Switched off by tools that want to walk a map without being interrupted.
var encounters_enabled: bool = true

var _db: GameDatabase
var _hero: Hero
var _rng: Rng


func _init(db: GameDatabase, hero: Hero, rng: Rng) -> void:
	_db = db
	_hero = hero
	_rng = rng


func enter_map(map_id: StringName, at_cell: Vector2i = Vector2i(-1, -1)) -> bool:
	var target := _db.map(map_id)
	if target == null:
		return false
	map = target
	cell = at_cell if at_cell != Vector2i(-1, -1) else target.default_spawn
	map_changed.emit(map.id, cell)
	return true


func terrain_here() -> int:
	return map.tile_at(cell) if map != null else -1


## Attempts one grid step. Returns true when the party actually moved.
func try_move(direction: Vector2i) -> bool:
	if map == null:
		return false

	var target := cell + direction
	var terrain := map.tile_at(target)
	if terrain < 0 or not Terrain.is_passable(terrain):
		move_blocked.emit(target)
		return false

	cell = target
	steps += 1
	if repel_steps > 0:
		repel_steps -= 1
	moved.emit(cell, terrain)

	if _apply_terrain_damage(terrain):
		return true
	if _apply_warp():
		return true
	_roll_encounter(terrain)
	return true


## Returns true when the hero went down and nothing else should resolve.
func _apply_terrain_damage(terrain: int) -> bool:
	var damage := Terrain.damage_on_enter(terrain)
	if damage <= 0 or _hero.blocks_terrain_damage(_db):
		return false
	_hero.hp = maxi(0, _hero.hp - damage)
	terrain_damaged.emit(damage)
	if not _hero.is_alive():
		hero_collapsed.emit()
		return true
	return false


## Returns true when a warp fired. Stepping through a door never picks a fight.
func _apply_warp() -> bool:
	var warp := map.warp_at(cell)
	if warp == null:
		return false
	enter_map(warp.to_map, warp.to_cell)
	return true


func _roll_encounter(terrain: int) -> void:
	if not encounters_enabled:
		return
	if not EncounterResolver.triggers(map, terrain, _rng):
		return
	var table := _db.encounter_table(map.encounter_table_id)
	var monster_id := EncounterResolver.pick(
			table, _rng, repel_steps > 0, _hero.level)
	if monster_id == &"":
		return
	encounter_started.emit(monster_id)
