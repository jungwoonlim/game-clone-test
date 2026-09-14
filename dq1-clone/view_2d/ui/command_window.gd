## A vertical menu. Opened with await, returns the chosen index or -1.
##
##   var pick := await window.open_menu(["FIGHT", "SPELL"])
class_name CommandWindow
extends DQWindow

signal chosen(index: int)

const CURSOR := "▶"
const DISABLED := Color(0.45, 0.45, 0.42)

var _labels: Array[String] = []
var _suffixes: Array[String] = []
var _enabled: Array[bool] = []
var _index := 0
var _open := false
var _cancellable := true


func _ready() -> void:
	hide()
	set_process_unhandled_input(false)


## Sizes itself to its contents and waits for a choice.
## `suffixes` are right-aligned (MP costs, prices); `enabled` greys entries out.
func open_menu(labels: Array[String], suffixes: Array[String] = [],
		enabled: Array[bool] = [], cancellable: bool = true) -> int:
	_labels = labels
	_suffixes = suffixes
	_enabled = enabled
	_cancellable = cancellable
	_index = _first_enabled()

	size = Vector2(_measure_width(), PAD.y * 2.0 + LINE_HEIGHT * labels.size())
	show()
	queue_redraw()
	_open = true
	set_process_unhandled_input(true)

	var result: int = await chosen

	_open = false
	set_process_unhandled_input(false)
	hide()
	return result


func is_open() -> bool:
	return _open


func _first_enabled() -> int:
	for i in _labels.size():
		if _is_enabled(i):
			return i
	return 0


func _is_enabled(index: int) -> bool:
	return index >= _enabled.size() or _enabled[index]


func _measure_width() -> float:
	var widest := 0.0
	for i in _labels.size():
		var text: String = _labels[i]
		if i < _suffixes.size() and _suffixes[i] != "":
			text += "   " + _suffixes[i]
		widest = maxf(widest, font().get_string_size(
				text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	return widest + PAD.x * 2.0 + 14.0


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey) or not event.pressed:
		return

	var handled := true
	match event.keycode:
		KEY_UP, KEY_W:
			_move(-1)
		KEY_DOWN, KEY_S:
			_move(1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z:
			if _is_enabled(_index):
				chosen.emit(_index)
		KEY_ESCAPE, KEY_X, KEY_BACKSPACE:
			if _cancellable:
				chosen.emit(-1)
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()


## Skips over greyed-out entries so the cursor never rests on a dead option.
func _move(step: int) -> void:
	if _labels.is_empty():
		return
	var next := _index
	for attempt in _labels.size():
		next = wrapi(next + step, 0, _labels.size())
		if _is_enabled(next):
			break
	_index = next
	queue_redraw()


func _draw() -> void:
	super()
	for i in _labels.size():
		var color := BORDER if _is_enabled(i) else DISABLED
		if i == _index:
			draw_text(i, CURSOR, color)
		draw_text(i, _labels[i], color, 12.0)
		if i < _suffixes.size() and _suffixes[i] != "":
			draw_text_right(i, _suffixes[i], color)
