## Bottom message window. Keeps the last few lines, oldest first.
extends Control

const MAX_LINES := 4

@onready var _label: Label = $Text

var _lines: Array[String] = []


func clear() -> void:
	_lines.clear()
	_refresh()


func push(line: String) -> void:
	if line == "":
		return
	_lines.append(line)
	while _lines.size() > MAX_LINES:
		_lines.pop_front()
	_refresh()


func _refresh() -> void:
	if _label != null:
		_label.text = "\n".join(_lines)
