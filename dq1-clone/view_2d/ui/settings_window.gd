## Volume and window mode. Rows are adjusted with left/right, like the rest of
## the menus are driven with up/down.
class_name SettingsWindow
extends DQWindow

signal closed()

enum Row { MUSIC, SOUND, TEXT, LANG, VIEW, SCREEN, BACK }

const ROWS := ["SET_MUSIC", "SET_SOUND", "SET_TEXT", "SET_LANG", "SET_VIEW",
		"SET_SCREEN", "SET_BACK"]
const BAR_SEGMENTS := 10
const STEP := 0.1

var _index := 0
var _open := false


func _ready() -> void:
	hide()
	set_process_unhandled_input(false)


func open_settings() -> void:
	_index = 0
	size = Vector2(196, PAD.y * 2.0 + LINE_HEIGHT * ROWS.size())
	show()
	queue_redraw()
	_open = true
	set_process_unhandled_input(true)
	await closed
	_open = false
	set_process_unhandled_input(false)
	hide()


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey) or not event.pressed:
		return

	var close := ""
	var handled := true
	match event.keycode:
		KEY_UP, KEY_W:
			_index = wrapi(_index - 1, 0, ROWS.size())
			sfx("sfx_cursor")
		KEY_DOWN, KEY_S:
			_index = wrapi(_index + 1, 0, ROWS.size())
			sfx("sfx_cursor")
		KEY_LEFT, KEY_A:
			_adjust(-1)
		KEY_RIGHT, KEY_D:
			_adjust(1)
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z:
			if _index == Row.BACK:
				close = "sfx_confirm"
			else:
				_adjust(1)
		KEY_ESCAPE, KEY_X, KEY_BACKSPACE:
			close = "sfx_cancel"
		_:
			handled = false

	# Same order as CommandWindow, for the same reason: `closed` resumes the
	# caller inside this call, and that caller can leave the tree.
	if handled:
		get_viewport().set_input_as_handled()
		queue_redraw()
	if close != "":
		sfx(close)
		closed.emit()


func _adjust(direction: int) -> void:
	if not is_inside_tree():
		return
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return
	match _index:
		Row.MUSIC:
			settings.set_music_volume(settings.music_volume + direction * STEP)
		Row.SOUND:
			settings.set_sfx_volume(settings.sfx_volume + direction * STEP)
			sfx("sfx_cursor")
		Row.TEXT:
			settings.cycle_text_speed(direction)
			sfx("sfx_cursor")
		Row.LANG:
			settings.cycle_language(direction)
			sfx("sfx_confirm")
		Row.VIEW:
			settings.cycle_view_mode(direction)
			sfx("sfx_confirm")
		Row.SCREEN:
			settings.set_fullscreen(not settings.fullscreen)
			sfx("sfx_confirm")


func _draw() -> void:
	super()
	var settings := get_node_or_null("/root/GameSettings") if is_inside_tree() else null
	for i in ROWS.size():
		if i == _index:
			draw_cursor(i)
		draw_text(i, Loc.t(ROWS[i]), BORDER, CommandWindow.TEXT_INDENT)
		if settings == null:
			continue
		match i:
			Row.MUSIC:
				_draw_bar(i, settings.music_volume)
			Row.SOUND:
				_draw_bar(i, settings.sfx_volume)
			Row.TEXT:
				draw_text_right(i, settings.text_speed_name())
			Row.LANG:
				draw_text_right(i, settings.language_name())
			Row.VIEW:
				draw_text_right(i, settings.view_name())
			Row.SCREEN:
				draw_text_right(i, Loc.t("SET_FULL" if settings.fullscreen else "SET_WINDOW"))


## Ten boxes, filled up to the current level. Drawn rather than typed, for
## the same reason as the cursor.
func _draw_bar(row: int, value: float) -> void:
	var filled := int(round(value * BAR_SEGMENTS))
	var box := Vector2(8.0, 8.0)
	var gap := 2.0
	var width := BAR_SEGMENTS * box.x + (BAR_SEGMENTS - 1) * gap
	var left := size.x - PAD.x - width
	var top := PAD.y + LINE_HEIGHT * (row + 0.5) - box.y * 0.5
	for i in BAR_SEGMENTS:
		var at := Rect2(Vector2(left + i * (box.x + gap), top), box)
		if i < filled:
			draw_rect(at, BORDER)
		else:
			draw_rect(at.grow(-0.5), BORDER, false, 1.0)
