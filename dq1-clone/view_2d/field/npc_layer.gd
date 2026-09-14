## Draws the people standing on the current map.
##
## NPCs block movement, so if they are not drawn the player walks into an
## invisible wall.
extends Node2D

const TILE := ArtSpec.TILE
## Column order is the sheet's; ArtSpec is where that order is written down.
const COLUMNS := {"villager": 0, "shop": 1, "inn": 2, "king": 3}

var _npcs: Array[NpcPlacement] = []
var _texture: Texture2D = load(ArtSpec.sheet(&"npcs")["path"])


func set_npcs(npcs: Array[NpcPlacement]) -> void:
	_npcs = npcs
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	for npc in _npcs:
		var column: int = COLUMNS.get(npc.role, 0)
		draw_texture_rect_region(_texture,
				Rect2(npc.cell.x * TILE, npc.cell.y * TILE - 2, TILE, TILE),
				Rect2(column * TILE, 0, TILE, TILE))
