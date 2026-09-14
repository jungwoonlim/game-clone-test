## Placeholder hero, drawn in code so the project needs no character art yet.
## Replaced by a Sprite2D + AnimatedSprite2D in M6.
extends Node2D

const BODY := Color("3f6fd0")
const TRIM := Color("e8d24a")
const SKIN := Color("f0c8a0")
const OUTLINE := Color("1a1a22")

var facing: Vector2i = Vector2i.DOWN


func set_facing(direction: Vector2i) -> void:
	if direction != Vector2i.ZERO and direction != facing:
		facing = direction
		queue_redraw()


func _draw() -> void:
	# Drawn around the tile centre, 16x16 tiles.
	draw_rect(Rect2(-5, -7, 10, 14), OUTLINE)
	draw_rect(Rect2(-4, -6, 8, 5), SKIN)
	draw_rect(Rect2(-4, -1, 8, 8), BODY)
	draw_rect(Rect2(-4, 5, 8, 2), TRIM)

	# Eyes, so the facing direction reads at a glance.
	if facing == Vector2i.DOWN:
		draw_rect(Rect2(-3, -5, 2, 2), OUTLINE)
		draw_rect(Rect2(1, -5, 2, 2), OUTLINE)
	elif facing == Vector2i.UP:
		draw_rect(Rect2(-4, -6, 8, 5), Color("c8a070"))
	elif facing == Vector2i.LEFT:
		draw_rect(Rect2(-4, -5, 2, 2), OUTLINE)
	else:
		draw_rect(Rect2(2, -5, 2, 2), OUTLINE)
