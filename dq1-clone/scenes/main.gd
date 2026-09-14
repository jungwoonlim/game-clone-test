## Wires core/ to view_2d/. The only place the two meet.
##
## Everything here is presentation and input routing: it asks the session to do
## things and turns the events it gets back into text and sprites.
extends Node2D

const DIRECTIONS := {
	"ui_left": Vector2i.LEFT,
	"ui_right": Vector2i.RIGHT,
	"ui_up": Vector2i.UP,
	"ui_down": Vector2i.DOWN,
}

@onready var _field: Node2D = $FieldView
@onready var _log: Control = $UI/MessageLog
@onready var _status: Control = $UI/Status
@onready var _status_text: Label = $UI/Status/Text
@onready var _place_text: Label = $UI/Place
@onready var _battle_panel: Control = $UI/Battle
@onready var _battle_title: Label = $UI/Battle/Title
@onready var _battle_hp: Label = $UI/Battle/MonsterHp
@onready var _battle_hint: Label = $UI/Battle/Hint
@onready var _battle_portrait: Control = $UI/Battle/Portrait
@onready var _battle_hp_fill: ColorRect = $UI/Battle/HpFill

var _session: GameSession
var _monster_name: String = ""
var _monster_max_hp: int = 1
var _monster_hp: int = 0
var _awaiting_dismiss := false
var _hero_down := false


func _ready() -> void:
	_session = GameSession.create_new(randi())
	if _session == null:
		_log.push("No database. Run tools/build_data.gd.")
		return

	_session.encounter_started.connect(_on_encounter_started)
	_session.hero_died.connect(_on_hero_died)
	_session.world.map_changed.connect(_on_map_changed)
	_session.world.moved.connect(_on_moved)
	_session.world.move_blocked.connect(_on_move_blocked)
	_session.world.terrain_damaged.connect(_on_terrain_damaged)

	_battle_panel.visible = false
	_on_map_changed(_session.world.map.id, _session.world.cell)
	_log.push("Press arrow keys to walk.")
	_refresh_status()


func _process(_delta: float) -> void:
	if _session == null or _awaiting_dismiss or _session.in_battle() or _hero_down:
		return
	if _field.is_walking():
		return
	for action in DIRECTIONS:
		if Input.is_action_pressed(action):
			_step(DIRECTIONS[action])
			return


func _step(direction: Vector2i) -> void:
	_field.face_hero(direction)
	if _session.try_move(direction):
		# try_move may have warped us; walk_hero is told the resulting cell.
		_field.walk_hero(_session.world.cell, direction)
	_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if _session == null or not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if _hero_down:
		var lost := _session.respawn()
		_hero_down = false
		_battle_panel.visible = false
		_log.push("You lose %d gold and wake at the castle." % lost)
		_refresh_status()
		return

	if _awaiting_dismiss:
		_awaiting_dismiss = false
		_battle_panel.visible = false
		_log.clear()
		_refresh_status()
		return

	if not _session.in_battle():
		return

	match event.keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			_run_command(BattleState.Command.ATTACK)
		KEY_H:
			_run_command(BattleState.Command.SPELL, &"heal")
		KEY_J:
			_run_command(BattleState.Command.SPELL, &"hurt")
		KEY_F:
			_run_command(BattleState.Command.FLEE)


func _run_command(command: BattleState.Command, argument: StringName = &"") -> void:
	_show_events(_session.battle_command(command, argument))


# --- 전투 ----------------------------------------------------------------

func _on_encounter_started(monster_id: StringName) -> void:
	var data := _session.db.monster(monster_id)
	if data == null:
		return
	_monster_name = data.display_name
	_monster_max_hp = data.max_hp
	_monster_hp = data.max_hp

	_log.clear()
	_battle_panel.visible = true
	_battle_title.text = _monster_name
	_battle_portrait.set_monster(data)
	_battle_hint.text = "SPACE attack    H heal    J hurt    F flee"
	_show_events(_session.begin_battle(monster_id))


func _show_events(events: Array[BattleEvent]) -> void:
	for event in events:
		var line := BattleText.describe(event, "You", _monster_name)
		if line != "":
			_log.push(line)
		if event.kind == BattleEvent.Kind.DAMAGE and event.by_hero:
			_monster_hp = maxi(0, _monster_hp - event.amount)
		if event.kind == BattleEvent.Kind.HEAL and not event.by_hero:
			_monster_hp = mini(_monster_max_hp, _monster_hp + event.amount)

	_refresh_status()
	if not _session.in_battle() and _battle_panel.visible and not _hero_down:
		_battle_hint.text = "Press any key"
		_awaiting_dismiss = true


func _on_hero_died() -> void:
	_hero_down = true
	_awaiting_dismiss = false
	_battle_hint.text = "Press any key"
	_log.push("You have fallen...")


# --- 필드 ----------------------------------------------------------------

func _on_map_changed(map_id: StringName, cell: Vector2i) -> void:
	var map := _session.db.map(map_id)
	_field.render_map(map)
	_field.snap_hero(cell)
	_place_text.text = map.display_name
	_log.push("- %s -" % map.display_name)


func _on_moved(_cell: Vector2i, _terrain: int) -> void:
	_refresh_status()


func _on_move_blocked(_cell: Vector2i) -> void:
	pass


func _on_terrain_damaged(amount: int) -> void:
	_log.push("The swamp burns! -%d HP" % amount)


func _refresh_status() -> void:
	var hero := _session.hero
	_status_text.text = "LV %d\nHP %d/%d\nMP %d/%d\nG  %d" % [
		hero.level, hero.hp, hero.max_hp, hero.mp, hero.max_mp, hero.gold]
	if _battle_panel.visible:
		_battle_hp.text = "HP %d/%d" % [_monster_hp, _monster_max_hp]
		var ratio := float(_monster_hp) / float(maxi(_monster_max_hp, 1))
		_battle_hp_fill.size.x = 120.0 * clampf(ratio, 0.0, 1.0)
