## Who made what, read from assets/credits.csv.
##
## Free art packs are mostly free on a condition — CC-BY wants the author
## named where players can see it, and OFL wants the font's notice carried
## along. A licence table that lives only in docs/ satisfies neither. This is
## the same table, on screen.
class_name CreditsWindow
extends DQWindow

signal closed()

const ROWS_PER_PAGE := 4
const PATH := "res://assets/credits.csv"

var _entries: Array = []
var _page := 0
var _open := false


func _ready() -> void:
	hide()
	set_process_unhandled_input(false)


func open_credits() -> void:
	_entries = load_entries()
	_page = 0
	size = Vector2(384, PAD.y * 2.0 + LINE_HEIGHT * (ROWS_PER_PAGE * 3 + 1))
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


## [{what, source, author, license, url}], in file order.
static func load_entries() -> Array:
	var out: Array = []
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return out
	var header := file.get_csv_line()
	var columns := {}
	for i in header.size():
		columns[header[i]] = i
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() < header.size() or row[0] == "":
			continue
		var entry := {}
		for key in columns:
			entry[key] = row[columns[key]]
		out.append(entry)
	return out


func _pages() -> int:
	return maxi(1, int(ceil(float(_entries.size()) / float(ROWS_PER_PAGE))))


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey) or not event.pressed:
		return

	var close := false
	var handled := true
	match event.keycode:
		KEY_UP, KEY_W, KEY_LEFT, KEY_A:
			_page = wrapi(_page - 1, 0, _pages())
			sfx("sfx_cursor")
		KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_Z:
			if _page + 1 >= _pages():
				close = true
			else:
				_page += 1
				sfx("sfx_cursor")
		KEY_ESCAPE, KEY_X, KEY_BACKSPACE:
			close = true
		_:
			handled = false

	# Viewport first, signal last — the same order as every other window here,
	# and for the same reason: `closed` resumes a caller that may leave.
	if handled:
		get_viewport().set_input_as_handled()
		queue_redraw()
	if close:
		sfx("sfx_cancel")
		closed.emit()


func _draw() -> void:
	super()
	var line := 0
	draw_text(line, Loc.t("CREDITS_TITLE"), Color(0.96, 0.9, 0.62))
	draw_text_right(line, "%d / %d" % [_page + 1, _pages()])
	line += 1

	var start := _page * ROWS_PER_PAGE
	for i in range(start, mini(start + ROWS_PER_PAGE, _entries.size())):
		var entry: Dictionary = _entries[i]
		draw_text(line, String(entry.get("what", "")), BORDER)
		line += 1
		draw_text(line, String(entry.get("source", "")), DISABLED_TEXT, 10.0)
		draw_text_right(line, String(entry.get("license", "")), DISABLED_TEXT)
		line += 1
		var author := String(entry.get("author", ""))
		var url := String(entry.get("url", ""))
		draw_text(line, url if url != "" else author, DISABLED_TEXT, 10.0)
		line += 1


const DISABLED_TEXT := Color(0.62, 0.64, 0.7)
