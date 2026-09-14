## The bottom message window: types text out a character at a time and keeps
## the last few lines on screen.
##
## This is where core's "resolve the turn instantly, replay it slowly" split
## finally pays off — the battle already happened, this just performs it.
class_name MessageWindow
extends DQWindow

const MAX_LINES := 4
const CHARS_PER_SECOND := 90.0
const LINE_PAUSE := 0.22

var _lines: Array[String] = []
var _partial: String = ""
var _typing: bool = false
var _skip: bool = false


func is_typing() -> bool:
	return _typing


## Called when the player presses a key: finish the current line at once.
func request_skip() -> void:
	if _typing:
		_skip = true


func clear() -> void:
	_lines.clear()
	_partial = ""
	queue_redraw()


## Hidden while walking so it never covers the party — in a dark dungeon the
## window would otherwise sit right on top of the only lit tiles.
func dismiss() -> void:
	hide()


## Adds a line with no animation. For field chatter that should not block.
func push(text: String) -> void:
	if text == "":
		return
	_lines.append(text)
	_trim()
	show()
	queue_redraw()


## Types one line out, then pauses. Await it to pace a sequence of events.
func play(text: String) -> void:
	if text == "":
		return
	_typing = true
	_skip = false
	_partial = ""
	show()
	var elapsed := 0.0
	while _partial.length() < text.length():
		await get_tree().process_frame
		if _skip:
			break
		elapsed += get_process_delta_time()
		var count := mini(text.length(), int(elapsed * CHARS_PER_SECOND))
		if count != _partial.length():
			# One blip every few glyphs; per-character would be a buzz.
			if count / 3 != _partial.length() / 3:
				sfx("sfx_text")
			_partial = text.substr(0, count)
			queue_redraw()

	_partial = ""
	_typing = false
	_lines.append(text)
	_trim()
	queue_redraw()
	await _pause(LINE_PAUSE if not _skip else 0.05)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _trim() -> void:
	while _lines.size() > MAX_LINES:
		_lines.pop_front()


func _draw() -> void:
	super()
	var index := 0
	for line in _lines:
		draw_text(index, line)
		index += 1
	if _partial != "":
		if index >= MAX_LINES:
			# Scroll while typing so the in-progress line is always visible.
			index = MAX_LINES - 1
		draw_text(index, _partial)
