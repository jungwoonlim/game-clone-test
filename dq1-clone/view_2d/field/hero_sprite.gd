## The party sprite, read out of the generated sheet.
##
## The sheet is 2 frames wide by 4 directions tall; facing up deliberately has
## no face, which is how direction reads at sixteen pixels.
extends Node2D

const SIZE := ArtSpec.TILE

## Row order is the sheet's, and the sheet's order is written down once in
## ArtSpec — not here and in the generator and in a comment.
const ROWS := {
	Vector2i.DOWN: 0,
	Vector2i.UP: 1,
	Vector2i.LEFT: 2,
	Vector2i.RIGHT: 3,
}

var facing: Vector2i = Vector2i.DOWN

var _texture: Texture2D = load(ArtSpec.sheet(&"hero")["path"])
var _frame := 0


func set_facing(direction: Vector2i) -> void:
	if direction != Vector2i.ZERO and direction != facing:
		facing = direction
		queue_redraw()


## Called once per step so the legs alternate.
func advance_step() -> void:
	_frame = 1 - _frame
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return
	var row: int = ROWS.get(facing, 0)
	draw_texture_rect_region(_texture,
			Rect2(-SIZE / 2.0, -SIZE / 2.0 - 2.0, SIZE, SIZE),
			Rect2(_frame * SIZE, row * SIZE, SIZE, SIZE))
