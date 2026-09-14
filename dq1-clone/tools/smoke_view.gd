## Boots the real main scene and drives it the way a player would.
##
##   godot --headless --path . --script res://tools/smoke_view.gd
##
## core/ is covered by test_core.gd; this checks that the wiring between core
## and view_2d actually holds together at runtime.
extends SceneTree

var _main: Node = null
var _frames := 0
var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false  # let _ready and the first draws settle

	var session: GameSession = _main.get("_session")
	_check(session != null, "main scene did not create a session")
	if session == null:
		return _finish()

	_check(session.world.map.id == &"town", "did not start in town")

	# Walk out of town the long way: straight down to the gate.
	for i in 40:
		_main.call("_step", Vector2i.DOWN)
		if session.world.map.id != &"town":
			break
	_check(session.world.map.id == &"field", "walking south never left town")

	# Wander the field and let encounters happen.
	var field := session.db.map(&"field")
	var saved_rate := field.encounter_rate
	field.encounter_rate = 160
	var battles := 0
	for i in 300:
		if session.in_battle() or _main.get("_awaiting_dismiss") or _main.get("_hero_down"):
			break
		_main.call("_step", Vector2i.RIGHT if i % 2 == 0 else Vector2i.LEFT)
		if session.in_battle():
			battles += 1
			break
	field.encounter_rate = saved_rate
	_check(battles > 0 or _main.get("_awaiting_dismiss"),
			"no encounter in 300 steps at rate 160")
	_check(_main.get("_battle_panel").visible, "battle panel did not open")

	# Fight it out with the same commands a player has.
	var guard := 0
	while session.in_battle() and guard < 200:
		guard += 1
		_main.call("_run_command", BattleState.Command.ATTACK, &"")
	_check(guard < 200, "battle never ended from the view layer")
	_check(not session.in_battle(), "session still reports an active battle")

	# Dismiss the result panel.
	_main.set("_awaiting_dismiss", false)
	_main.set("_hero_down", false)
	_main.get("_battle_panel").visible = false

	# Spells and fleeing route through the same path.
	session.hero.apply_level(session.db.level_curve, 12, true)
	_main.call("_on_encounter_started", &"m_magician")
	_main.call("_run_command", BattleState.Command.SPELL, &"hurt")
	_check(session.hero.mp < session.hero.max_mp, "casting Hurt did not spend MP")
	var flee_guard := 0
	while session.in_battle() and flee_guard < 100:
		flee_guard += 1
		_main.call("_run_command", BattleState.Command.FLEE, &"")
	_check(flee_guard < 100, "fleeing never resolved")

	return _finish()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> bool:
	print("[smoke-view] %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr("  FAIL  %s" % failure)
	quit(1 if _failures.size() > 0 else 0)
	return true
