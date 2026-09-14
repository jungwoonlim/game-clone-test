## Regenerates the screenshots in docs/.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --script res://tools/capture_screens.gd -- ko
##
## Drives the real scenes rather than mocking them up, so a shot that looks
## wrong is the game looking wrong. Each step arranges the state, lets the
## view settle, and saves the viewport.
extends SceneTree

const OUT_DIR := "res://docs"
const SETTLE_FRAMES := 14

var _main: Node
var _steps: Array = []
var _step := 0
var _wait := 0
var _saved: Array[String] = []


func _initialize() -> void:
	Engine.time_scale = 8.0
	SaveGame.erase()
	Boot.continue_from_save = false
	_steps = _plan()


func _locale() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.length() == 2:
			return argument
	return "ko"


## Each entry is [name, setup]. `name` is "" for a setup-only step.
func _plan() -> Array:
	return [
		["", _set_language],
		["", _open.bind("res://scenes/title.tscn")],
		["screenshot-title", _noop],
		["", _open_settings],
		["screenshot-settings", _noop],
		["", _open.bind("res://scenes/main.tscn")],
		["", _outfit],
		["", _menu],
		["screenshot-town", _noop],
		["", _pick_field_menu.bind(6)],
		["screenshot-system", _noop],
		["", _cancel_submenu],
		["", _go.bind(&"field", Vector2i(20, 22))],
		["screenshot-field", _noop],
		["", _go.bind(&"dungeon", Vector2i(5, 5))],
		["screenshot-dungeon", _noop],
		["", _fight.bind(&"m_scorpion")],
		["screenshot-battle", _noop],
		["", _hurt],
		["screenshot-damage", _noop],
		["", _fight.bind(&"m_dragonlord")],
		["screenshot-boss", _noop],
		["", _open.bind("res://scenes/main_3d.tscn")],
		["", _outfit],
		["screenshot-3d-town", _noop],
		["", _go.bind(&"field", Vector2i(20, 22))],
		["screenshot-3d-field", _noop],
		["", _go.bind(&"dungeon", Vector2i(5, 5))],
		["screenshot-3d-dungeon", _noop],
		["", _fight.bind(&"m_wraith")],
		["screenshot-3d-battle", _noop],
	]


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	if _step >= _steps.size():
		print("[capture] %d screenshots: %s" % [_saved.size(), ", ".join(_saved)])
		return true

	var entry: Array = _steps[_step]
	_step += 1
	var setup: Callable = entry[1]
	setup.call()
	if entry[0] != "":
		_save(entry[0])
	_wait = SETTLE_FRAMES
	return false


# --- 단계 -----------------------------------------------------------------

func _noop() -> void:
	pass


func _set_language() -> void:
	Loc.force_locale(root, _locale())


func _open(path: String) -> void:
	if _main != null:
		_main.free()
	_main = load(path).instantiate()
	root.add_child(_main)


func _open_settings() -> void:
	_main.get_node("Menu").chosen.emit(2)


## A party worth photographing: gear on, spells known, money in the purse.
func _outfit() -> void:
	var session = _main.get("_session")
	session.hero.apply_level(session.db.level_curve, 12, true)
	session.hero.gold = 640
	for id in [&"w_sword", &"a_leather", &"s_small", &"herb", &"torch"]:
		session.hero.add_item(id)
	for id in [&"w_sword", &"a_leather", &"s_small"]:
		session.equip(id)
	session.world.encounters_enabled = false
	_main.call("_refresh_status")


func _menu() -> void:
	_main.call("_open_field_menu")


func _pick_field_menu(index: int) -> void:
	_main.get("_command").chosen.emit(index)


func _cancel_submenu() -> void:
	_main.get("_submenu").chosen.emit(-1)


func _go(map_id: StringName, cell: Vector2i) -> void:
	var session = _main.get("_session")
	session.world.enter_map(map_id, cell)
	_main.call("_refresh_status")


func _fight(monster_id: StringName) -> void:
	_main.call("_run_battle", monster_id)


## Mid-fight, with the damage on screen. The monster in that shot is picked
## to survive one hit — a corpse is a worse illustration of "damage".
func _hurt() -> void:
	var session = _main.get("_session")
	if session.battle == null:
		return
	_main.call("_play", session.battle.resolve_turn(BattleState.Command.ATTACK))


func _save(name: String) -> void:
	var image := root.get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	if image.save_png(path) != OK:
		printerr("[capture] could not write %s" % path)
		return
	_saved.append(name)
