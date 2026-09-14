## Volume and window mode. Rows are adjusted with left/right, like the rest of
## the menus are driven with up/down.
class_name SettingsWindow
extends DQWindow

signal closed()

const ROWS := ["MUSIC", "SOUND", "SCREEN", "BACK"]
const BAR_SEGMENTS := 10
const STEP := 0.1

var _index := 0
var _open := false


func _ready() -> void:
	hide()
	set_process_unhandled_input(false)


func open_settings() -> void:
	_index = 0
	size = Vector2(170, PAD.y * 2.0 + LINE_HEIGHT * ROWS.size())
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
			if _index == ROWS.size() - 1:
				sfx("sfx_confirm")
				closed.emit()
			else:
				_adjust(1)
		KEY_ESCAPE, KEY_X, KEY_BACKSPACE:
			sfx("sfx_cancel")
			closed.emit()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()
		queue_redraw()


func _adjust(direction: int) -> void:
	if not is_inside_tree():
		return
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return
	match _index:
		0:
			settings.set_music_volume(settings.music_volume + direction * STEP)
		1:
			settings.set_sfx_volume(settings.sfx_volume + direction * STEP)
			sfx("sfx_cursor")
		2:
			settings.set_fullscreen(not settings.fullscreen)
			sfx("sfx_confirm")


func _draw() -> void:
	super()
	var settings := get_node_or_null("/root/GameSettings") if is_inside_tree() else null
	for i in ROWS.size():
		if i == _index:
			draw_text(i, CommandWindow.CURSOR)
		draw_text(i, ROWS[i], BORDER, 12.0)
		if settings == null:
			continue
		match i:
			0:
				_draw_bar(i, settings.music_volume)
			1:
				_draw_bar(i, settings.sfx_volume)
			2:
				draw_text_right(i, "FULL" if settings.fullscreen else "WINDOW")


func _draw_bar(row: int, value: float) -> void:
	var filled := int(round(value * BAR_SEGMENTS))
	var text := ""
	for i in BAR_SEGMENTS:
		text += "■" if i < filled else "□"
	draw_text_right(row, text)
