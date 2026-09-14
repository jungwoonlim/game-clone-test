## Boots the real main scene and plays it the way a person would.
##
##   godot --headless --path . --script res://tools/smoke_view.gd
##
## The UI is asynchronous — it awaits menu choices and typewriter timers — so
## this drives it frame by frame rather than calling into it. That is the only
## way to catch a flow that deadlocks waiting for input that never comes.
extends SceneTree

enum Phase { BOOT, SHOP, EQUIP, INN, KING, LEAVE_TOWN, FIND_FIGHT, FIGHT,
	DUNGEON, BOSS, DONE }

const FRAME_BUDGET := 60000

var _main: Node = null
var _phase := Phase.BOOT
var _frames := 0
var _phase_frames := 0
var _started := false
## Answers fed to whichever menu is open, in order.
var _answers: Array = []
## Used once _answers runs dry. -1 backs out; the battle menu cannot be
## cancelled, so during a fight this has to be a real choice or the flow spins.
var _default_answer := -1
var _menu_picks := 0
var _gold_before := 0
var _failures: Array[String] = []
var _checks := 0
var _saved_rate := 0


func _initialize() -> void:
	# Message timers are real-time; run the clock fast.
	Engine.time_scale = 8.0
	SaveGame.erase()
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	_phase_frames += 1
	if _frames > FRAME_BUDGET:
		_failures.append("ran out of frames in phase %s" % Phase.keys()[_phase])
		return _finish()
	if _frames < 4:
		return false

	var message: MessageWindow = _main.get("_message")
	if message.is_typing():
		message.request_skip()
	if _main.get("_awaiting_key"):
		_main.set("_awaiting_key", false)
	if _answer_open_menu():
		return false

	match _phase:
		Phase.BOOT:
			_boot()
		Phase.SHOP:
			_town_step(Phase.EQUIP, Vector2i(6, 10), Vector2i.UP, [0, 0, 0, -1], _after_shop)
		Phase.EQUIP:
			_town_step(Phase.INN, Vector2i(6, 10), Vector2i.UP, [5, 0], _after_equip)
		Phase.INN:
			if not _started:
				_session().hero.hp = 1  # give the innkeeper something to heal
			_town_step(Phase.KING, Vector2i(21, 19), Vector2i.UP, [0, 0], _after_inn)
		Phase.KING:
			_town_step(Phase.LEAVE_TOWN, Vector2i(16, 3), Vector2i.UP, [0], _after_king)
		Phase.LEAVE_TOWN:
			_leave_town()
		Phase.FIND_FIGHT:
			_find_fight()
		Phase.FIGHT:
			_fight()
		Phase.DUNGEON:
			_dungeon()
		Phase.BOSS:
			_boss()
		Phase.DONE:
			return _finish()
	return false


func _session() -> GameSession:
	return _main.get("_session")


func _is_field() -> bool:
	return int(_main.get("_mode")) == 0


func _advance(phase: Phase) -> void:
	_phase = phase
	_phase_frames = 0
	_started = false


## Answers whichever window is waiting on a choice.
func _answer_open_menu() -> bool:
	var command: CommandWindow = _main.get("_command")
	var submenu: CommandWindow = _main.get("_submenu")
	var target: CommandWindow = null
	if submenu.is_open():
		target = submenu
	elif command.is_open():
		target = command
	if target == null:
		return false

	var answer := _default_answer
	if not _answers.is_empty():
		answer = int(_answers.pop_front())
	target.chosen.emit(answer)
	_menu_picks += 1
	return true


# --- 단계 -----------------------------------------------------------------

func _boot() -> void:
	_check(_session() != null, "main scene did not create a session")
	if _session() == null:
		_advance(Phase.DONE)
		return
	_check(_session().world.map.id == &"town", "did not start in town")
	_advance(Phase.SHOP)


## Stands the party in front of an NPC, opens the field menu, feeds it answers,
## then runs `verify` once the menu flow has returned control.
func _town_step(next: Phase, cell: Vector2i, facing: Vector2i, answers: Array,
		verify: Callable) -> void:
	if not _started:
		_started = true
		_session().world.cell = cell
		_session().world.facing = facing
		_gold_before = _session().hero.gold
		_answers = answers.duplicate()
		_main.call("_open_field_menu")
		return
	if _phase_frames > 3000:
		_failures.append("town step %s never returned to the field"
				% Phase.keys()[_phase])
		_advance(Phase.DONE)
		return
	if _is_field() and _phase_frames > 4:
		verify.call()
		_advance(next)


func _after_shop() -> void:
	var hero := _session().hero
	_check(hero.gold < _gold_before, "buying spent no gold")
	_check(hero.has_item(&"w_club"), "the bought club is not in the bag")


func _after_equip() -> void:
	_check(_session().hero.weapon_id == &"w_club", "the club never got equipped")
	_check(not _session().hero.has_item(&"w_club"), "equipped gear is still in the bag")


func _after_inn() -> void:
	_check(_session().hero.gold < _gold_before, "the inn charged nothing")
	_check(_session().hero.hp == _session().hero.max_hp, "the inn did not heal")


func _after_king() -> void:
	_check(SaveGame.has_save(), "talking to the King wrote no save file")
	_check(_session().has_flag(&"heard_quest"), "the King set no quest flag")


func _leave_town() -> void:
	if not _started:
		_started = true
		_session().world.enter_map(&"town", Vector2i(16, 20))
		return
	if _session().world.map.id == &"field":
		_saved_rate = _session().db.map(&"field").encounter_rate
		_session().db.map(&"field").encounter_rate = 200
		_advance(Phase.FIND_FIGHT)
		return
	if _phase_frames > 900:
		_failures.append("walking south never left town")
		_advance(Phase.DONE)
		return
	if _is_field():
		_main.call("_step", Vector2i.DOWN)


func _find_fight() -> void:
	if not _is_field():
		_check(_main.get("_battle").visible, "battle screen did not open")
		# Set this BEFORE the next frame: the answerer runs first and would
		# otherwise cancel a menu that cannot be cancelled.
		_default_answer = 0  # always FIGHT
		_advance(Phase.FIGHT)
		return
	if _phase_frames > 4000:
		_failures.append("no encounter in 4000 frames at rate 200")
		_session().db.map(&"field").encounter_rate = _saved_rate
		_advance(Phase.DONE)
		return
	_main.call("_step", Vector2i.RIGHT if _phase_frames % 2 == 0 else Vector2i.LEFT)


## Driven entirely through the command window, like a player pressing FIGHT.
## _default_answer is already 0 here, set by _find_fight before the answerer
## got a chance to cancel a menu that cannot be cancelled.
func _fight() -> void:
	if _is_field():
		_check(not _main.get("_battle").visible, "battle screen stayed open")
		_session().db.map(&"field").encounter_rate = _saved_rate
		_default_answer = -1
		_advance(Phase.DUNGEON)
		return
	if _phase_frames > 20000:
		_failures.append("battle never finished (deadlocked waiting for input?)")
		_advance(Phase.DONE)


## Walk into the dark, grab a chest, confirm the torch and the darkness work.
func _dungeon() -> void:
	if not _started:
		_started = true
		var chest := _session().db.map(&"dungeon").chests[0]
		_session().world.enter_map(&"dungeon", chest.cell)
		_check(_session().world.sight_radius() > 0, "the dungeon is fully lit")
		_gold_before = _session().hero.gold
		_answers = [1]  # TAKE
		_main.call("_open_field_menu")
		return
	if _phase_frames > 3000:
		_failures.append("opening a chest never returned to the field")
		_advance(Phase.DONE)
		return
	if _is_field() and _phase_frames > 4:
		_check(_session().hero.gold > _gold_before, "the chest paid nothing")
		_advance(Phase.BOSS)


## The end of the vertical slice: step onto the throne and win.
func _boss() -> void:
	if not _started:
		_started = true
		var hero := _session().hero
		hero.apply_level(_session().db.level_curve, 30, true)
		hero.weapon_id = &"w_blade"
		hero.armor_id = &"a_plate"
		hero.shield_id = &"s_large"
		var map := _session().db.map(&"dungeon_b2")
		_session().world.enter_map(&"dungeon_b2", map.boss_cell + Vector2i.LEFT)
		_default_answer = 0  # always FIGHT
		_main.call("_step", Vector2i.RIGHT)
		return
	if _phase_frames > 30000:
		_failures.append("the boss fight never resolved")
		_advance(Phase.DONE)
		return
	if _is_field() and _phase_frames > 4:
		_check(_session().has_flag(&"dragonlord_defeated"),
				"beating the boss recorded no flag")
		_check(_session().hero.is_alive(), "a level 30 hero lost to the Dragonlord")
		_default_answer = -1
		_advance(Phase.DONE)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> bool:
	SaveGame.erase()
	print("[smoke-view] %d checks, %d menu picks, %d failures" % [
		_checks, _menu_picks, _failures.size()])
	for failure in _failures:
		printerr("  FAIL  %s" % failure)
	quit(1 if _failures.size() > 0 else 0)
	return true
