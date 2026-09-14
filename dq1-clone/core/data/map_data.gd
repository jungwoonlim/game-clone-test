## A single map: terrain grid, warps, NPCs and encounter settings.
class_name MapData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export var width: int = 0
@export var height: int = 0

## width*height terrain type ids (see Terrain.Type).
@export var tiles: PackedByteArray = PackedByteArray()

## width*height height values. Unused by the 2D renderer — it exists so the
## 2.5D remake does not require re-authoring every map. See docs/04.
@export var elevation: PackedByteArray = PackedByteArray()

@export_group("Encounters")
@export var encounter_table_id: StringName = &""
## Base chance out of 256, before the terrain multiplier.
@export_range(0, 255) var encounter_rate: int = 0

@export_group("Dungeon")
@export var is_dungeon: bool = false
## Visible radius in tiles. 0 means the whole map is lit. Used from M5.
@export var base_sight_radius: int = 0

@export_group("Contents")
@export var warps: Array[WarpPoint] = []
@export var npcs: Array[NpcPlacement] = []
@export var chests: Array[ChestPlacement] = []

@export_group("Boss")
## Stepping here starts a fixed fight, once. (-1,-1) means the map has no boss.
@export var boss_cell: Vector2i = Vector2i(-1, -1)
@export var boss_monster: StringName = &""
## Set once the boss is beaten, so the fight never repeats.
@export var boss_flag: StringName = &""

## Where the party appears when the game starts on this map.
@export var default_spawn: Vector2i = Vector2i.ZERO


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func tile_at(cell: Vector2i) -> int:
	if not in_bounds(cell):
		return -1
	return tiles[cell.y * width + cell.x]


func elevation_at(cell: Vector2i) -> int:
	if not in_bounds(cell) or elevation.size() != tiles.size():
		return 0
	return elevation[cell.y * width + cell.x]


func warp_at(cell: Vector2i) -> WarpPoint:
	for warp in warps:
		if warp.from_cell == cell:
			return warp
	return null


func chest_at(cell: Vector2i) -> ChestPlacement:
	for chest in chests:
		if chest.cell == cell:
			return chest
	return null


func npc_at(cell: Vector2i) -> NpcPlacement:
	for npc in npcs:
		if npc.cell == cell:
			return npc
	return null
