## The bottom message window: types text out a character at a time and keeps
## the last few lines on screen.
##
## This is where core's "resolve the turn instantly, replay it slowly" split
## finally pays off — the battle already happened, this just performs it.
class_name MessageWindow
extends DQWindow

const MAX_LINES := 4
## Fallback when the settings autoload is absent (tool runs).
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


## An empty message window is not a message window — it is a black box sitting
## over the map for no reason. Clearing takes the frame away with the text.
func clear() -> void:
	_lines.clear()
	_partial = ""
	hide()
	queue_redraw()


## Hidden while walking so it never covers the party — in a dark dungeon the
## window would otherwise sit right on top of the only lit tiles.
##
## It forgets what it was saying as well as hiding: a conversation ends when
## the player walks away from it. Merely hiding left the old lines in place,
## so the next unrelated line — a place name, a swamp burn — came back up
## underneath somebody else's half of a conversation from two rooms ago.
func dismiss() -> void:
	clear()


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
	var speed := _chars_per_second()
	var elapsed := 0.0
	while _partial.length() < text.length():
		await get_tree().process_frame
		if _skip:
			break
		elapsed += get_process_delta_time()
		var count := mini(text.length(), int(elapsed * speed))
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


func _chars_per_second() -> float:
	var settings := get_node_or_null("/root/GameSettings") if is_inside_tree() else null
	return settings.chars_per_second() if settings != null else CHARS_PER_SECOND


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _trim() -> void:
	while _lines.size() > MAX_LINES:
		_lines.pop_front()


## What is on screen right now, oldest first.
##
## A line being typed takes the last row, so once the window is full the
## committed lines have to scroll up to make room — otherwise the new line is
## drawn straight on top of the last old one.
func visible_lines() -> Array[String]:
	if _partial == "":
		return _lines.duplicate()
	var kept := _lines
	if kept.size() >= MAX_LINES:
		kept = kept.slice(kept.size() - (MAX_LINES - 1))
	var shown := kept.duplicate()
	shown.append(_partial)
	return shown


func _draw() -> void:
	super()
	var index := 0
	for line in visible_lines():
		draw_text(index, line)
		index += 1
