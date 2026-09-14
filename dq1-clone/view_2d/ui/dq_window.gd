## The black box with a white border that every Dragon Quest menu lives in.
##
## Subclasses call super() from _draw() to get the frame, then draw their
## contents on top.
class_name DQWindow
extends Control

const FILL := Color(0.03, 0.04, 0.09, 0.96)
const BORDER := Color(0.95, 0.95, 0.90)
## Sized for Hangul: below 11px the jamo of a syllable run into each other.
## The Latin text grew with it rather than keeping two sets of metrics.
const FONT_SIZE := 11
const PAD := Vector2(8, 6)
const LINE_HEIGHT := 15.0


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, FILL)
	draw_rect(rect.grow(-1.0), BORDER, false, 2.0)


## Every window can make a noise; the director is absent in some tool runs.
func sfx(name: String) -> void:
	if not is_inside_tree():
		return
	var director := get_node_or_null("/root/AudioDirector")
	if director != null:
		director.sfx(name)


## The project theme's font — Noto Sans KR, so Korean and the box-drawing
## glyphs in the settings bars both have shapes. Falls back on its own outside
## a tree, which is where the headless tools run.
func font() -> Font:
	return get_theme_default_font()


## Baseline for line `index`, counting from the top padding.
func line_origin(index: int) -> Vector2:
	return Vector2(PAD.x, PAD.y + LINE_HEIGHT * (index + 1) - 3.0)


func draw_text(index: int, text: String, color: Color = BORDER, offset_x: float = 0.0) -> void:
	draw_string(font(), line_origin(index) + Vector2(offset_x, 0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)


## The menu cursor and the settings bars used to be typed characters — ▶, ■,
## □. None of them are in Noto Sans KR: they were coming from whatever CJK
## font the machine happened to have, and turned into empty boxes the moment
## the game stopped asking the system for help. Shapes have no such problem,
## and land on exact pixels at this size where a glyph would not.
func draw_cursor(index: int, color: Color = BORDER) -> void:
	var middle := PAD.y + LINE_HEIGHT * (index + 0.5)
	draw_colored_polygon([
		Vector2(PAD.x + 1.0, middle - 4.0),
		Vector2(PAD.x + 7.0, middle),
		Vector2(PAD.x + 1.0, middle + 4.0),
	], color)


func draw_text_right(index: int, text: String, color: Color = BORDER) -> void:
	draw_string(font(), Vector2(PAD.x, line_origin(index).y), text,
			HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD.x * 2.0, FONT_SIZE, color)
