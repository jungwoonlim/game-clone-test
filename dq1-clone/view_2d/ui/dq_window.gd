## The black box with a white border that every Dragon Quest menu lives in.
##
## Subclasses call super() from _draw() to get the frame, then draw their
## contents on top.
class_name DQWindow
extends Control

const FILL := Color(0.03, 0.04, 0.09, 0.96)
const BORDER := Color(0.95, 0.95, 0.90)
const FONT_SIZE := 9
const PAD := Vector2(8, 6)
const LINE_HEIGHT := 13.0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, FILL)
	draw_rect(rect.grow(-1.0), BORDER, false, 2.0)


func font() -> Font:
	return ThemeDB.fallback_font


## Baseline for line `index`, counting from the top padding.
func line_origin(index: int) -> Vector2:
	return Vector2(PAD.x, PAD.y + LINE_HEIGHT * (index + 1) - 3.0)


func draw_text(index: int, text: String, color: Color = BORDER, offset_x: float = 0.0) -> void:
	draw_string(font(), line_origin(index) + Vector2(offset_x, 0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


func draw_text_right(index: int, text: String, color: Color = BORDER) -> void:
	draw_string(font(), Vector2(PAD.x, line_origin(index).y), text,
			HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD.x * 2.0, FONT_SIZE, color)
