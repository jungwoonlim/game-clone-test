## Draws the people standing on the current map.
##
## NPCs block movement, so if they are not drawn the player walks into an
## invisible wall. Colour-coded by role until real sprites land in M6.
extends Node2D

const TILE := 16

const ROLE_COLORS := {
	"villager": Color("3f9f5a"),
	"shop": Color("3f6fd0"),
	"inn": Color("9b5ec0"),
	"king": Color("d8a92a"),
}

var _npcs: Array[NpcPlacement] = []


func set_npcs(npcs: Array[NpcPlacement]) -> void:
	_npcs = npcs
	queue_redraw()


func _draw() -> void:
	for npc in _npcs:
		var center := Vector2(npc.cell.x * TILE + TILE / 2.0, npc.cell.y * TILE + TILE / 2.0)
		var body: Color = ROLE_COLORS.get(npc.role, Color("808080"))
		draw_rect(Rect2(center + Vector2(-5, -7), Vector2(10, 14)), Color(0.1, 0.1, 0.13))
		draw_rect(Rect2(center + Vector2(-4, -6), Vector2(8, 5)), Color("f0c8a0"))
		draw_rect(Rect2(center + Vector2(-4, -1), Vector2(8, 8)), body)
		draw_rect(Rect2(center + Vector2(-3, -5), Vector2(2, 2)), Color(0.15, 0.1, 0.1))
		draw_rect(Rect2(center + Vector2(1, -5), Vector2(2, 2)), Color(0.15, 0.1, 0.1))
		if npc.role == "king":
			# A crown, so the save point is obvious from across the room.
			draw_rect(Rect2(center + Vector2(-5, -10), Vector2(10, 3)), Color("e8c84a"))
