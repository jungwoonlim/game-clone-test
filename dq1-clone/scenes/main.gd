## Wires core/ to view_2d/. The only place the two meet.
##
## core resolves a turn instantly; everything here is about performing that
## result at a pace a person can read.
extends Node2D

enum Mode { FIELD, BUSY }

const DIRECTIONS := {
	"ui_left": Vector2i.LEFT,
	"ui_right": Vector2i.RIGHT,
	"ui_up": Vector2i.UP,
	"ui_down": Vector2i.DOWN,
}
const HP_BAR_WIDTH := 120.0

@onready var _field: Node2D = $FieldView
@onready var _status: StatusWindow = $UI/Status
@onready var _place: Label = $UI/Place
@onready var _message: MessageWindow = $UI/Message
@onready var _command: CommandWindow = $UI/Command
@onready var _submenu: CommandWindow = $UI/SubCommand
@onready var _battle: Control = $UI/Battle
@onready var _battle_name: Label = $UI/Battle/MonsterName
@onready var _portrait: Control = $UI/Battle/Portrait
@onready var _hp_fill: ColorRect = $UI/Battle/HpFill
@onready var _hp_text: Label = $UI/Battle/HpText
@onready var _detail: DetailWindow = $UI/Detail

var _session: GameSession
var _mode := Mode.FIELD
var _monster_name := ""
var _monster_max_hp := 1
var _monster_hp := 0
var _awaiting_key := false


func _ready() -> void:
	_session = GameSession.create_new(randi())
	if _session == null:
		_message.push("No database. Run tools/build_data.gd.")
		return

	_session.encounter_started.connect(_on_encounter_started)
	_session.hero_died.connect(_on_hero_died)
	_session.world.map_changed.connect(_on_map_changed)
	_session.world.terrain_damaged.connect(_on_terrain_damaged)

	_battle.visible = false
	_on_map_changed(_session.world.map.id, _session.world.cell)
	_message.push("Arrow keys to walk.")
	_refresh_status()


func _process(_delta: float) -> void:
	if _session == null or _mode != Mode.FIELD or _field.is_walking():
		return
	for action in DIRECTIONS:
		if Input.is_action_pressed(action):
			_step(DIRECTIONS[action])
			return


func _step(direction: Vector2i) -> void:
	_message.dismiss()
	_field.face_hero(direction)
	if _session.try_move(direction):
		_field.walk_hero(_session.world.cell, direction)
		_refresh_sight()
	_refresh_status()


func _refresh_sight() -> void:
	_field.set_sight(_session.world.cell, _session.world.sight_radius())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# Any key both fast-forwards the typewriter and dismisses a "press any key".
	_message.request_skip()
	_awaiting_key = false

	if _mode == Mode.FIELD and not _field.is_walking() \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_ENTER
				or event.keycode == KEY_KP_ENTER or event.keycode == KEY_Z):
		_open_field_menu()


# --- 필드 메뉴 ------------------------------------------------------------

func _open_field_menu() -> void:
	_mode = Mode.BUSY
	var pick := await _command.open_menu(
			["TALK", "TAKE", "STATUS", "SPELL", "ITEM", "EQUIP"])
	match pick:
		0:
			await _do_talk()
		1:
			await _do_take()
		2:
			await _do_status()
		3:
			await _do_field_spell()
		4:
			await _do_use_item()
		5:
			await _do_equip()
	_mode = Mode.FIELD


func _do_talk() -> void:
	var npc := _session.npc_in_front()
	if npc == null:
		await _message.play("There is no one there.")
		return

	var entry := _session.talk_to(npc)
	if entry != null:
		for line in entry.lines:
			await _message.play(line)

	match npc.role:
		"shop":
			await _do_shop(npc)
		"inn":
			await _do_inn(npc)
		"king":
			await _do_king()


func _do_status() -> void:
	var hero := _session.hero
	_detail.show_rows([
		["LEVEL", str(hero.level)],
		["EXP", str(hero.total_exp)],
		["NEXT", _exp_to_next_text()],
		["STRENGTH", str(hero.strength)],
		["AGILITY", str(hero.agility)],
		["ATTACK", str(hero.attack_power(_session.db))],
		["DEFENCE", str(hero.defense_power(_session.db))],
		["WEAPON", _item_name(hero.weapon_id)],
		["ARMOUR", _item_name(hero.armor_id)],
		["SHIELD", _item_name(hero.shield_id)],
	])
	await _wait_for_key("")
	_detail.hide()


func _exp_to_next_text() -> String:
	var remaining := _session.db.level_curve.exp_to_next(_session.hero.total_exp)
	return "-" if remaining < 0 else str(remaining)


func _item_name(id: StringName) -> String:
	var item := _session.db.item(id)
	return item.display_name if item != null else "none"


# --- 상점 / 여관 / 왕 ------------------------------------------------------

func _do_shop(npc: NpcPlacement) -> void:
	var shop := _session.db.shop(npc.shop_id)
	if shop == null:
		return
	while true:
		var pick := await _submenu.open_menu(["BUY", "SELL"])
		if pick < 0:
			await _message.play("Come again.")
			return
		if pick == 0:
			await _shop_buy(shop)
		else:
			await _shop_sell()


func _shop_buy(shop: ShopData) -> void:
	var labels: Array[String] = []
	var prices: Array[String] = []
	var affordable: Array[bool] = []
	for id in shop.stock:
		var item := _session.db.item(id)
		labels.append(item.display_name)
		prices.append("%d G" % item.buy_price)
		affordable.append(_session.hero.gold >= item.buy_price)

	var pick := await _submenu.open_menu(labels, prices, affordable)
	if pick < 0:
		return
	var chosen_id: StringName = shop.stock[pick]
	var item := _session.db.item(chosen_id)
	match _session.buy(chosen_id):
		TownServices.Result.OK:
			await _message.play("%s. A fine choice." % item.display_name)
		TownServices.Result.NOT_ENOUGH_GOLD:
			await _message.play("Thou hast not enough gold.")
		TownServices.Result.INVENTORY_FULL:
			await _message.play("Thou canst carry no more.")
		_:
			await _message.play("I cannot sell thee that.")
	_refresh_status()


func _shop_sell() -> void:
	var bag := _session.hero.inventory
	if bag.is_empty():
		await _message.play("Thou hast nothing to sell.")
		return

	var labels: Array[String] = []
	var prices: Array[String] = []
	for id in bag:
		var item := _session.db.item(id)
		labels.append(item.display_name)
		prices.append("%d G" % item.sell_price)

	var pick := await _submenu.open_menu(labels, prices)
	if pick < 0:
		return
	var chosen_id: StringName = bag[pick]
	var item := _session.db.item(chosen_id)
	if _session.sell(chosen_id) == TownServices.Result.OK:
		await _message.play("%d gold for the %s." % [item.sell_price, item.display_name])
	_refresh_status()


func _do_inn(npc: NpcPlacement) -> void:
	await _message.play("A night's rest is %d gold. Stay?" % npc.inn_price)
	var pick := await _submenu.open_menu(["YES", "NO"])
	if pick != 0:
		await _message.play("Fare thee well.")
		return
	match _session.rest(npc.inn_price):
		TownServices.Result.OK:
			await _message.play("Good morning. Thou seemest well.")
		TownServices.Result.NOT_ENOUGH_GOLD:
			await _message.play("Thou hast not enough gold.")
		TownServices.Result.ALREADY_FULL_HEALTH:
			await _message.play("Thou needest no rest.")
	_refresh_status()


func _do_king() -> void:
	if _session.save_game() == OK:
		await _message.play("Thy deeds are recorded.")
	else:
		await _message.play("The scribe has lost his quill.")


# --- 주문 / 도구 / 장비 (필드) ---------------------------------------------

func _do_field_spell() -> void:
	var spells: Array[SpellData] = []
	for spell in _session.db.spells_up_to_level(_session.hero.level):
		if spell.usable_in_field:
			spells.append(spell)
	if spells.is_empty():
		await _message.play("Thou knowest no such spell.")
		return

	var labels: Array[String] = []
	var costs: Array[String] = []
	var affordable: Array[bool] = []
	for spell in spells:
		labels.append(spell.display_name)
		costs.append("%d MP" % spell.mp_cost)
		affordable.append(_session.hero.mp >= spell.mp_cost)

	var pick := await _submenu.open_menu(labels, costs, affordable)
	if pick < 0:
		return

	var spell := spells[pick]
	var outcome: Dictionary = _session.cast_in_field(spell.id)
	await _message.play("%s!" % spell.display_name)
	match int(outcome["result"]):
		GameSession.FieldSpell.OK:
			if spell.kind == "heal":
				await _message.play("Thy wounds close. +%d HP" % outcome["amount"])
		GameSession.FieldSpell.NO_MP:
			await _message.play("Thy magic is spent.")
		GameSession.FieldSpell.NOT_HERE:
			await _message.play("Nothing happens here.")
		GameSession.FieldSpell.NO_EFFECT:
			await _message.play("Nothing happens.")
		_:
			await _message.play("Nothing happens.")
	_refresh_status()


func _do_use_item() -> void:
	var usable: Array[ItemData] = []
	for id in _session.hero.inventory:
		var item := _session.db.item(id)
		if item != null and item.kind == "consumable":
			usable.append(item)
	if usable.is_empty():
		await _message.play("Thou carriest nothing useful.")
		return

	var labels: Array[String] = []
	for item in usable:
		labels.append(item.display_name)
	var pick := await _submenu.open_menu(labels)
	if pick < 0:
		return

	var outcome: Dictionary = _session.use_item_in_field(usable[pick].id)
	match String(outcome["effect"]):
		"heal":
			await _message.play("%s. +%d HP" % [usable[pick].display_name, outcome["amount"]])
		"light":
			await _message.play("The torch flares. The dark draws back.")
			_refresh_sight()
		_:
			await _message.play("Nothing happens.")
	_refresh_status()


func _do_take() -> void:
	var result: Dictionary = _session.open_chest_here()
	if not result["found"]:
		await _message.play("There is nothing here.")
		return
	if result["empty"]:
		await _message.play("The chest is empty.")
		return
	if result["full"]:
		await _message.play("Thou canst carry no more.")
		return

	# The lid is part of the tilemap, so an opened chest has to be repainted.
	_field.set_cell_terrain(_session.world.cell, Terrain.Type.FLOOR)
	if int(result["gold"]) > 0:
		await _message.play("%d gold!" % result["gold"])
	if StringName(result["item"]) != &"":
		var item := _session.db.item(result["item"])
		await _message.play("Thou hast found a %s!" % item.display_name)
	_refresh_status()


func _do_equip() -> void:
	var gear: Array[ItemData] = []
	for id in _session.hero.inventory:
		var item := _session.db.item(id)
		if item != null and (item.kind == "weapon" or item.kind == "armor"
				or item.kind == "shield"):
			gear.append(item)
	if gear.is_empty():
		await _message.play("Thou hast nothing to equip.")
		return

	var labels: Array[String] = []
	var kinds: Array[String] = []
	for item in gear:
		labels.append(item.display_name)
		kinds.append(item.kind.to_upper())
	var pick := await _submenu.open_menu(labels, kinds)
	if pick < 0:
		return

	if _session.equip(gear[pick].id) == TownServices.Result.OK:
		await _message.play("Thou art now armed with the %s." % gear[pick].display_name)
	_refresh_status()


# --- 전투 ----------------------------------------------------------------

func _on_encounter_started(monster_id: StringName) -> void:
	_run_battle(monster_id)


## The whole fight, from "a monster draws near" to the result screen.
func _run_battle(monster_id: StringName) -> void:
	var data := _session.db.monster(monster_id)
	if data == null:
		return

	_mode = Mode.BUSY
	var is_boss_fight := data.is_boss
	_monster_name = data.display_name
	_monster_max_hp = data.max_hp
	_monster_hp = data.max_hp
	_battle_name.text = _monster_name
	_portrait.reset_presentation()
	_portrait.set_monster(data)
	_battle.visible = true
	_message.clear()
	_refresh_status()

	await _play(_session.begin_battle(monster_id))

	while _session.in_battle():
		var command := await _ask_command()
		if command.is_empty():
			continue
		await _play(_session.battle_command(command[0], command[1]))

	if not _session.hero.is_alive():
		await _handle_death()
	else:
		await _wait_for_key("")
		if is_boss_fight:
			await _play_victory()

	_battle.visible = false
	_message.clear()
	_mode = Mode.FIELD


## Returns [command, argument], or [] when the player backed out and should be
## asked again.
func _ask_command() -> Array:
	var pick := await _command.open_menu(
			["FIGHT", "SPELL", "ITEM", "RUN"], [], [], false)
	match pick:
		0:
			return [BattleState.Command.ATTACK, &""]
		1:
			return await _ask_spell()
		2:
			return await _ask_item()
		3:
			return [BattleState.Command.FLEE, &""]
	return []


func _ask_spell() -> Array:
	var spells: Array[SpellData] = []
	for spell in _session.db.spells_up_to_level(_session.hero.level):
		if spell.usable_in_battle:
			spells.append(spell)
	if spells.is_empty():
		await _message.play("You know no spells.")
		return []

	var labels: Array[String] = []
	var costs: Array[String] = []
	var affordable: Array[bool] = []
	for spell in spells:
		labels.append(spell.display_name)
		costs.append("%d MP" % spell.mp_cost)
		affordable.append(_session.hero.mp >= spell.mp_cost)

	var pick := await _submenu.open_menu(labels, costs, affordable)
	if pick < 0:
		return []
	return [BattleState.Command.SPELL, spells[pick].id]


func _ask_item() -> Array:
	var usable: Array[ItemData] = []
	for id in _session.hero.inventory:
		var item := _session.db.item(id)
		if item != null and item.kind == "consumable":
			usable.append(item)
	if usable.is_empty():
		await _message.play("You carry nothing useful.")
		return []

	var labels: Array[String] = []
	for item in usable:
		labels.append(item.display_name)
	var pick := await _submenu.open_menu(labels)
	if pick < 0:
		return []
	return [BattleState.Command.ITEM, usable[pick].id]


## Performs an already-resolved turn, one event at a time.
func _play(events: Array[BattleEvent]) -> void:
	for event in events:
		_apply_effect(event)
		var line := BattleText.describe(event, "You", _monster_name)
		if line != "":
			await _message.play(line)
		_refresh_status()


func _apply_effect(event: BattleEvent) -> void:
	match event.kind:
		BattleEvent.Kind.DAMAGE:
			if event.by_hero:
				_monster_hp = maxi(0, _monster_hp - event.amount)
				_portrait.play_hit()
			else:
				_shake_screen()
		BattleEvent.Kind.HEAL:
			if not event.by_hero:
				_monster_hp = mini(_monster_max_hp, _monster_hp + event.amount)
		BattleEvent.Kind.MONSTER_TRANSFORMED:
			_adopt_current_monster()
		BattleEvent.Kind.MONSTER_DEFEATED:
			_portrait.play_defeat()
	_refresh_battle_hp()


## A boss's second form is a different monster: new name, new HP, new portrait.
func _adopt_current_monster() -> void:
	if _session.battle == null or _session.battle.monster.monster == null:
		return
	var data := _session.battle.monster.monster
	_monster_name = data.display_name
	_monster_max_hp = data.max_hp
	_monster_hp = _session.battle.monster.hp
	_battle_name.text = _monster_name
	_portrait.reset_presentation()
	_portrait.set_monster(data)


func _shake_screen() -> void:
	var tween := create_tween()
	tween.tween_property(_battle, "position", Vector2(3, 0), 0.04)
	tween.tween_property(_battle, "position", Vector2.ZERO, 0.1)


func _play_victory() -> void:
	_battle.visible = false
	_message.clear()
	await _message.play("The Dragonlord is no more.")
	await _message.play("The Light returns to Alefgard.")
	await _message.play("Thy quest is at an end.")
	await _wait_for_key("")


func _handle_death() -> void:
	await _message.play("Thou art dead.")
	await _wait_for_key("")
	var lost := _session.respawn()
	_battle.visible = false
	_message.clear()
	await _message.play("You lose %d gold and wake at the castle." % lost)
	_refresh_status()


func _wait_for_key(prompt: String) -> void:
	if prompt != "":
		_message.push(prompt)
	await get_tree().create_timer(0.25).timeout
	_awaiting_key = true
	while _awaiting_key:
		await get_tree().process_frame


# --- 필드 ----------------------------------------------------------------

func _on_hero_died() -> void:
	# Battle deaths are handled inside _run_battle; this is the swamp case.
	if _mode == Mode.FIELD:
		_mode = Mode.BUSY
		_handle_death_on_field()


func _handle_death_on_field() -> void:
	await _handle_death()
	_mode = Mode.FIELD


func _on_map_changed(map_id: StringName, cell: Vector2i) -> void:
	var map := _session.db.map(map_id)
	_field.render_map(map)
	# Chests you have already emptied stay open across visits.
	for chest in map.chests:
		if _session.is_chest_open(map_id, chest):
			_field.set_cell_terrain(chest.cell, Terrain.Type.FLOOR)
	_field.snap_hero(cell)
	_refresh_sight()
	_place.text = map.display_name
	_message.push("- %s -" % map.display_name)


func _on_terrain_damaged(amount: int) -> void:
	_message.push("The swamp burns! -%d HP" % amount)


func _refresh_status() -> void:
	var hero := _session.hero
	_status.set_values(hero.level, hero.hp, hero.max_hp, hero.mp, hero.max_mp, hero.gold)
	_refresh_battle_hp()


func _refresh_battle_hp() -> void:
	if not _battle.visible:
		return
	_hp_text.text = "HP %d/%d" % [_monster_hp, _monster_max_hp]
	var ratio := float(_monster_hp) / float(maxi(_monster_max_hp, 1))
	_hp_fill.size.x = HP_BAR_WIDTH * clampf(ratio, 0.0, 1.0)
