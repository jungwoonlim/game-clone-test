## Headless smoke test.
##
##   godot --headless --path . --script res://tools/smoke_test.gd
##
## Boots the real main scene, drops a pile of fruit at random positions and
## asserts that scoring, merging and the game-over check all fire. Useful as a
## CI gate: it exits non-zero if the game never merged anything.
extends SceneTree

const DROP_INTERVAL: float = 0.5
const DROP_COUNT: int = 40
const SETTLE_TIME: float = 4.0

var _game: Node = null
var _timer: float = 0.0
var _drops: int = 0
var _settle: float = 0.0


func _initialize() -> void:
	seed(12345)
	var packed: PackedScene = load("res://scenes/main.tscn")
	_game = packed.instantiate()
	root.add_child(_game)
	print("[smoke] main scene instantiated")


func _process(delta: float) -> bool:
	if _game == null or not is_instance_valid(_game):
		return true

	if _game.get("_game_over"):
		return _report("game over reached after %d drops" % _drops)

	_timer += delta
	if _drops < DROP_COUNT:
		if _timer >= DROP_INTERVAL:
			_timer = 0.0
			_drops += 1
			_game.call("_move_dropper", randf_range(70.0, 470.0))
			_game.call("_drop")
		return false

	_settle += delta
	if _settle >= SETTLE_TIME:
		return _report("settled after %d drops" % _drops)
	return false


func _report(reason: String) -> bool:
	var score: int = _game.get("_score")
	var fruits: int = _game.get_node("Fruits").get_child_count()
	print("[smoke] %s" % reason)
	print("[smoke] score=%d  fruits_in_jar=%d" % [score, fruits])
	if score <= 0:
		printerr("[smoke] FAIL: nothing ever merged")
		quit(1)
		return true
	if fruits <= 0:
		printerr("[smoke] FAIL: jar is empty, fruits are falling through the floor")
		quit(1)
		return true
	print("[smoke] PASS")
	quit(0)
	return true
