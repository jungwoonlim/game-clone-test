## The rules that make the renderer swappable, checked instead of trusted.
##
##   godot --headless --path . --script res://tools/test_architecture.gd
##
## Two claims run through this whole project: core/ never knows about a
## renderer, and the two field views are interchangeable. Both are easy to
## break with one careless line and neither shows up in a screenshot, so they
## are asserted here rather than left as a convention in a document.
extends SceneTree

const CORE_DIR := "res://core"
const FIELD_VIEWS := [
	"res://view_2d/field/field_view.gd",
	"res://view_3d/field/field_view_3d.gd",
]
const CONTROLLER := "res://scenes/main.gd"
const SCENES := ["res://scenes/main.tscn", "res://scenes/main_3d.tscn"]

## Rendering base classes. A core script extending any of these has stopped
## being renderer-free.
const VIEW_BASES := [
	"Node2D", "Node3D", "Control", "CanvasItem", "CanvasLayer",
	"Sprite2D", "Sprite3D", "TileMapLayer", "Camera2D", "Camera3D",
]

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_test_core_is_renderer_free()
	_test_field_views_match_controller()
	_test_scenes_share_controller_and_ui()

	print("[architecture] %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr("  FAIL  %s" % failure)
	quit(1 if _failures.size() > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _scripts_in(path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return out
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append("%s/%s" % [path, file])
	for sub in dir.get_directories():
		out.append_array(_scripts_in("%s/%s" % [path, sub]))
	return out


# --- 규칙 1: core는 렌더러를 모른다 ---------------------------------------

func _test_core_is_renderer_free() -> void:
	var scripts := _scripts_in(CORE_DIR)
	_check(scripts.size() > 10, "only %d scripts under core/" % scripts.size())

	var extends_pattern := RegEx.new()
	extends_pattern.compile("(?m)^extends\\s+(\\w+)")

	for path in scripts:
		var text := FileAccess.get_file_as_string(path)
		for forbidden in ["view_2d", "view_3d", "res://scenes"]:
			_check(not text.contains(forbidden),
					"%s mentions %s" % [path, forbidden])

		var found := extends_pattern.search(text)
		if found != null:
			_check(not VIEW_BASES.has(found.get_string(1)),
					"%s extends %s" % [path, found.get_string(1)])

		# Instantiating a rendering class is the same leak by another route.
		for base in VIEW_BASES:
			_check(not text.contains("%s.new()" % base),
					"%s constructs a %s" % [path, base])


# --- 규칙 2: 두 필드 뷰는 서로 대체 가능하다 ------------------------------

## Every `_field.something(...)` the controller calls must exist on both field
## views. This is what "swap the renderer" actually reduces to.
func _test_field_views_match_controller() -> void:
	var controller := FileAccess.get_file_as_string(CONTROLLER)
	var call_pattern := RegEx.new()
	call_pattern.compile("_field\\.(\\w+)\\s*\\(")

	var required := {}
	for found in call_pattern.search_all(controller):
		required[found.get_string(1)] = true
	_check(required.size() >= 5,
			"found only %d field-view calls in the controller" % required.size())

	for path in FIELD_VIEWS:
		var text := FileAccess.get_file_as_string(path)
		_check(text != "", "%s is missing" % path)
		for method in required:
			_check(text.contains("func %s(" % method),
					"%s does not implement %s(), which the controller calls"
					% [path, method])


# --- 규칙 3: 두 씬은 같은 컨트롤러와 같은 UI를 쓴다 -----------------------

func _test_scenes_share_controller_and_ui() -> void:
	for path in SCENES:
		var text := FileAccess.get_file_as_string(path)
		_check(text.contains(CONTROLLER),
				"%s does not use the shared controller" % path)
		_check(text.contains("res://view_2d/ui/game_ui.tscn"),
				"%s does not instance the shared UI" % path)
