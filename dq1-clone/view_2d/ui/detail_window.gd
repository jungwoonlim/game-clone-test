## A two-column info box (STATUS, and anything else that is a list of
## label/value pairs). Sizes itself to its contents.
class_name DetailWindow
extends DQWindow

var _rows: Array = []


func _ready() -> void:
	hide()


## `rows` is an array of [left, right] string pairs.
func show_rows(rows: Array) -> void:
	_rows = rows
	var widest := 0.0
	for row in rows:
		var text: String = "%s      %s" % [row[0], row[1]]
		widest = maxf(widest, font().get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	size = Vector2(widest + PAD.x * 2.0, PAD.y * 2.0 + LINE_HEIGHT * rows.size())
	show()
	queue_redraw()


func _draw() -> void:
	super()
	for i in _rows.size():
		draw_text(i, str(_rows[i][0]))
		draw_text_right(i, str(_rows[i][1]))
