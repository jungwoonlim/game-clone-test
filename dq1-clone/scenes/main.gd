## Wires core/ to view_2d/. The only place the two meet.
##
## core resolves a turn instantly; everything here is about performing that
## result at a pace a person can read.
##
## Deliberately `extends Node` and holds the field view as a plain `Node`: the
## same script drives scenes/main.tscn (2D) and scenes/main_3d.tscn (2.5D),
## because both field views expose the same handful of methods.
extends Node

const DIRECTIONS := {
	"ui_left": Vector2i.LEFT,
	"ui_right": Vector2i.RIGHT,
	"ui_up": Vector2i.UP,
	"ui_down": Vector2i.DOWN,
}
const HP_BAR_WIDTH := 120.0

@onready var _field: Node = $FieldView
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
@onready var _settings: SettingsWindow = $UI/Settings
@onready var _backdrop: Control = $UI/Battle/Backdrop
@onready var _flash_rect: ColorRect = $UI/Flash

var _session: GameSession
## Several flows run as concurrent coroutines — the intro, a menu, a battle,
## a death. Each used to hand control back with `_mode = FIELD`, so whichever
## finished first unlocked the field while the others were still running. A
## depth counter means control returns only when the last one is done.
var _busy_depth := 0
var _monster_name := ""
var _monster_max_hp := 1
var _monster_hp := 0
var _awaiting_key := false
var _booted := false


func _ready() -> void:
	_session = GameSession.create_new(randi())
	if _session == null:
		_message.push(Loc.t("MSG_NO_DATABASE"))
		return

	_session.encounter_started.connect(_on_encounter_started)
	_session.hero_died.connect(_on_hero_died)
	_session.world.map_changed.connect(_on_map_changed)
	_session.world.terrain_damaged.connect(_on_terrain_damaged)

	_battle.visible = false
	if Boot.continue_from_save and _session.has_save():
		_session.load_game()
	Boot.continue_from_save = false

	_on_map_changed(_session.world.map.id, _session.world.cell)
	_booted = true
	_refresh_status()
	_intro()


## Opening lines. Written so a first-time player knows where to go without
## being told anything outside the game.
func _intro() -> void:
	_enter_busy()
	if not _session.has_flag(&"hint_start"):
		_session.set_flag(&"hint_start")
		await _message.play(Loc.t("MSG_INTRO_1"))
		await _message.play(Loc.t("MSG_INTRO_2"))
	await _message.play(Loc.t("MSG_INTRO_3"))
	_exit_busy()


## True while any flow owns the screen: the intro, a menu, a battle, a death.
func is_busy() -> bool:
	return _busy_depth > 0


func _enter_busy() -> void:
	_busy_depth += 1


func _exit_busy() -> void:
	_busy_depth = maxi(0, _busy_depth - 1)


func _sfx(name: String) -> void:
	if not is_inside_tree():
		return
	var director := get_node_or_null("/root/AudioDirector")
	if director != null:
		director.sfx(name)


func _bgm(name: String) -> void:
	if not is_inside_tree():
		return
	var director := get_node_or_null("/root/AudioDirector")
	if director != null:
		director.play_bgm(name)


## Derived from the map rather than a lookup table, so a new map gets sensible
## music without anyone remembering to register it.
func _map_bgm() -> String:
	var map := _session.world.map
	if map == null:
		return "bgm_town"
	if map.is_dungeon:
		return "bgm_dungeon"
	if map.encounter_rate <= 0:
		return "bgm_town"
	return "bgm_field"


## The one line that tells a new player what to do next.
func _quest_line() -> String:
	if not _session.has_flag(&"heard_quest"):
		return Loc.t("QUEST_KING")
	if not _session.has_flag(&"dragonlord_defeated"):
		return Loc.t("QUEST_CAVE")
	return Loc.t("QUEST_RETURN")


func _process(_delta: float) -> void:
	if _session == null or is_busy() or _field.is_walking():
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
	else:
		_sfx("sfx_step_blocked")
	_refresh_status()


func _refresh_sight() -> void:
	_field.set_sight(_session.world.cell, _session.world.sight_radius())


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# Any key both fast-forwards the typewriter and dismisses a "press any key".
	_message.request_skip()
	_awaiting_key = false

	if is_busy() or _field.is_walking():
		return
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER \
			or event.keycode == KEY_KP_ENTER or event.keycode == KEY_Z:
		_open_field_menu()
	elif event.keycode == KEY_ESCAPE:
		_open_system_menu()


# --- 시스템 메뉴 ----------------------------------------------------------

## ESCAPE reaches it directly, because that is the key a player already tries
## when they want out.
func _open_system_menu() -> void:
	_enter_busy()
	_message.clear()
	await _do_system_menu()
	_exit_busy()


## Every way out of the game lives here. Until this existed the only way to
## stop playing was to close the window, and there was no way back to the
## title screen at all.
func _do_system_menu() -> void:
	var pick := await _submenu.open_menu([
		Loc.t("SYS_SETTINGS"), Loc.t("SYS_TITLE"), Loc.t("SYS_QUIT")])
	match pick:
		0:
			await _settings.open_settings()
			_relabel()
		1:
			if await _confirm("MSG_CONFIRM_TITLE"):
				get_tree().change_scene_to_file("res://scenes/title.tscn")
		2:
			if await _confirm("MSG_CONFIRM_QUIT"):
				get_tree().quit()


## Both ways out throw away everything since the last visit to the King, so
## both say so and both start on NO.
func _confirm(key: String) -> bool:
	await _message.play(Loc.t(key))
	await _message.play(Loc.t("MSG_UNSAVED"))
	var pick := await _submenu.open_menu([Loc.t("MENU_NO"), Loc.t("MENU_YES")])
	return pick == 1


## Switching language mid-game changes text that is already on screen.
func _relabel() -> void:
	_message.clear()
	_place.text = Loc.map_name(_session.world.map)
	_status.queue_redraw()


# --- 필드 메뉴 ------------------------------------------------------------

func _open_field_menu() -> void:
	_enter_busy()
	# A menu opens a new conversation; whatever the last one said is done.
	_message.clear()
	var pick := await _command.open_menu([
		Loc.t("MENU_TALK"), Loc.t("MENU_TAKE"), Loc.t("MENU_STATUS"),
		Loc.t("MENU_SPELL"), Loc.t("MENU_ITEM"), Loc.t("MENU_EQUIP"),
		Loc.t("MENU_SYSTEM"),
	])
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
		6:
			await _do_system_menu()
	_exit_busy()


func _do_talk() -> void:
	var npc := _session.npc_in_front()
	if npc == null:
		await _message.play(Loc.t("MSG_NO_ONE"))
		return

	var entry := _session.talk_to(npc)
	if entry != null:
		for line in entry.lines:
			await _message.play(Loc.t(line))

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
		[Loc.t("STAT_QUEST"), _quest_line()],
		[Loc.t("STAT_LEVEL"), str(hero.level)],
		[Loc.t("STAT_EXP"), str(hero.total_exp)],
		[Loc.t("STAT_NEXT"), _exp_to_next_text()],
		[Loc.t("STAT_STRENGTH"), str(hero.strength)],
		[Loc.t("STAT_AGILITY"), str(hero.agility)],
		[Loc.t("STAT_ATTACK"), str(hero.attack_power(_session.db))],
		[Loc.t("STAT_DEFENCE"), str(hero.defense_power(_session.db))],
		[Loc.t("STAT_WEAPON"), _item_name(hero.weapon_id)],
		[Loc.t("STAT_ARMOUR"), _item_name(hero.armor_id)],
		[Loc.t("STAT_SHIELD"), _item_name(hero.shield_id)],
	])
	await _wait_for_key("")
	_detail.hide()


func _exp_to_next_text() -> String:
	var remaining := _session.db.level_curve.exp_to_next(_session.hero.total_exp)
	return "-" if remaining < 0 else str(remaining)


func _item_name(id: StringName) -> String:
	var item := _session.db.item(id)
	return Loc.item_name(item) if item != null else Loc.t("STAT_NONE")


# --- 상점 / 여관 / 왕 ------------------------------------------------------

func _do_shop(npc: NpcPlacement) -> void:
	var shop := _session.db.shop(npc.shop_id)
	if shop == null:
		return
	while true:
		var pick := await _submenu.open_menu([Loc.t("MENU_BUY"), Loc.t("MENU_SELL")])
		if pick < 0:
			await _message.play(Loc.t("MSG_SHOP_BYE"))
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
		labels.append(Loc.item_name(item))
		prices.append(Loc.t("FMT_GOLD", {"gold": item.buy_price}))
		affordable.append(_session.hero.gold >= item.buy_price)

	var pick := await _submenu.open_menu(labels, prices, affordable)
	if pick < 0:
		return
	var chosen_id: StringName = shop.stock[pick]
	var item := _session.db.item(chosen_id)
	match _session.buy(chosen_id):
		TownServices.Result.OK:
			await _message.play(Loc.t("MSG_SHOP_BOUGHT", {"item": Loc.item_name(item)}))
		TownServices.Result.NOT_ENOUGH_GOLD:
			await _message.play(Loc.t("MSG_NOT_ENOUGH_GOLD"))
		TownServices.Result.INVENTORY_FULL:
			await _message.play(Loc.t("MSG_BAG_FULL"))
		_:
			await _message.play(Loc.t("MSG_CANNOT_SELL"))
	_refresh_status()


func _shop_sell() -> void:
	var bag := _session.hero.inventory
	if bag.is_empty():
		await _message.play(Loc.t("MSG_NOTHING_TO_SELL"))
		return

	var labels: Array[String] = []
	var prices: Array[String] = []
	for id in bag:
		var item := _session.db.item(id)
		labels.append(Loc.item_name(item))
		prices.append(Loc.t("FMT_GOLD", {"gold": item.sell_price}))

	var pick := await _submenu.open_menu(labels, prices)
	if pick < 0:
		return
	var chosen_id: StringName = bag[pick]
	var item := _session.db.item(chosen_id)
	if _session.sell(chosen_id) == TownServices.Result.OK:
		await _message.play(Loc.t("MSG_SHOP_SOLD",
				{"gold": item.sell_price, "item": Loc.item_name(item)}))
	_refresh_status()


func _do_inn(npc: NpcPlacement) -> void:
	await _message.play(Loc.t("MSG_INN_OFFER", {"gold": npc.inn_price}))
	var pick := await _submenu.open_menu([Loc.t("MENU_YES"), Loc.t("MENU_NO")])
	if pick != 0:
		await _message.play(Loc.t("MSG_INN_DECLINE"))
		return
	match _session.rest(npc.inn_price):
		TownServices.Result.OK:
			await _message.play(Loc.t("MSG_INN_MORNING"))
		TownServices.Result.NOT_ENOUGH_GOLD:
			await _message.play(Loc.t("MSG_NOT_ENOUGH_GOLD"))
		TownServices.Result.ALREADY_FULL_HEALTH:
			await _message.play(Loc.t("MSG_INN_NO_NEED"))
	_refresh_status()


func _do_king() -> void:
	if _session.save_game() == OK:
		_sfx("sfx_confirm")
		await _message.play(Loc.t("MSG_SAVED"))
	else:
		await _message.play(Loc.t("MSG_SAVE_FAILED"))


# --- 주문 / 도구 / 장비 (필드) ---------------------------------------------

func _do_field_spell() -> void:
	var spells: Array[SpellData] = []
	for spell in _session.db.spells_up_to_level(_session.hero.level):
		if spell.usable_in_field:
			spells.append(spell)
	if spells.is_empty():
		await _message.play(Loc.t("MSG_NO_SPELLS"))
		return

	var labels: Array[String] = []
	var costs: Array[String] = []
	var affordable: Array[bool] = []
	for spell in spells:
		labels.append(Loc.spell_name(spell))
		costs.append(Loc.t("FMT_MP", {"mp": spell.mp_cost}))
		affordable.append(_session.hero.mp >= spell.mp_cost)

	var pick := await _submenu.open_menu(labels, costs, affordable)
	if pick < 0:
		return

	var spell := spells[pick]
	var outcome: Dictionary = _session.cast_in_field(spell.id)
	await _message.play(Loc.t("MSG_SPELL_CAST", {"spell": Loc.spell_name(spell)}))
	match int(outcome["result"]):
		GameSession.FieldSpell.OK:
			if spell.kind == "heal":
				await _message.play(Loc.t("MSG_HEALED", {"amount": outcome["amount"]}))
		GameSession.FieldSpell.NO_MP:
			await _message.play(Loc.t("MSG_NO_MP"))
		GameSession.FieldSpell.NOT_HERE:
			await _message.play(Loc.t("MSG_NOT_HERE"))
		_:
			await _message.play(Loc.t("MSG_NOTHING_HAPPENS"))
	_refresh_status()


func _do_use_item() -> void:
	var usable: Array[ItemData] = []
	for id in _session.hero.inventory:
		var item := _session.db.item(id)
		if item != null and item.kind == "consumable":
			usable.append(item)
	if usable.is_empty():
		await _message.play(Loc.t("MSG_NO_ITEMS"))
		return

	var labels: Array[String] = []
	for item in usable:
		labels.append(Loc.item_name(item))
	var pick := await _submenu.open_menu(labels)
	if pick < 0:
		return

	var outcome: Dictionary = _session.use_item_in_field(usable[pick].id)
	match String(outcome["effect"]):
		"heal":
			await _message.play(Loc.t("MSG_ITEM_HEALED", {
				"item": Loc.item_name(usable[pick]), "amount": outcome["amount"]}))
		"light":
			await _message.play(Loc.t("MSG_TORCH"))
			_refresh_sight()
		_:
			await _message.play(Loc.t("MSG_NOTHING_HAPPENS"))
	_refresh_status()


func _do_take() -> void:
	var result: Dictionary = _session.open_chest_here()
	if not result["found"]:
		await _message.play(Loc.t("MSG_NOTHING_HERE"))
		return
	if result["empty"]:
		await _message.play(Loc.t("MSG_CHEST_EMPTY"))
		return
	if result["full"]:
		await _message.play(Loc.t("MSG_BAG_FULL"))
		return

	# The lid is part of the tilemap, so an opened chest has to be repainted.
	_field.set_cell_terrain(_session.world.cell, Terrain.Type.FLOOR)
	_sfx("sfx_chest")
	if int(result["gold"]) > 0:
		await _message.play(Loc.t("MSG_FOUND_GOLD", {"gold": result["gold"]}))
	if StringName(result["item"]) != &"":
		var item := _session.db.item(result["item"])
		await _message.play(Loc.t("MSG_FOUND_ITEM", {"item": Loc.item_name(item)}))
	_refresh_status()


func _do_equip() -> void:
	var gear: Array[ItemData] = []
	for id in _session.hero.inventory:
		var item := _session.db.item(id)
		if item != null and (item.kind == "weapon" or item.kind == "armor"
				or item.kind == "shield"):
			gear.append(item)
	if gear.is_empty():
		await _message.play(Loc.t("MSG_NO_GEAR"))
		return

	var labels: Array[String] = []
	var kinds: Array[String] = []
	for item in gear:
		labels.append(Loc.item_name(item))
		kinds.append(Loc.t("KIND_" + item.kind.to_upper()))
	var pick := await _submenu.open_menu(labels, kinds)
	if pick < 0:
		return

	if _session.equip(gear[pick].id) == TownServices.Result.OK:
		await _message.play(Loc.t("MSG_EQUIPPED", {"item": Loc.item_name(gear[pick])}))
	_refresh_status()


# --- 전투 ----------------------------------------------------------------

func _on_encounter_started(monster_id: StringName) -> void:
	_run_battle(monster_id)


## The whole fight, from "a monster draws near" to the result screen.
func _run_battle(monster_id: StringName) -> void:
	var data := _session.db.monster(monster_id)
	if data == null:
		return

	_enter_busy()
	var is_boss_fight := data.is_boss
	_sfx("sfx_boss" if is_boss_fight else "sfx_encounter")
	await _encounter_transition()
	_bgm("bgm_boss" if is_boss_fight else "bgm_battle")
	_backdrop.set_terrain(_session.world.terrain_here())
	_monster_name = Loc.monster_name(data)
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
		var before := _stat_snapshot()
		var events := _session.battle_command(command[0], command[1])
		await _play(events)
		await _report_level_gains(before, events)

	var won_boss := false
	if not _session.hero.is_alive():
		await _handle_death()
	else:
		await _wait_for_key("")
		if is_boss_fight:
			won_boss = true
			await _play_victory()

	_battle.visible = false
	_message.clear()
	# The victory theme has to survive the walk home; anything else and the
	# dungeon loop stomps it a frame later.
	if not won_boss:
		_bgm(_map_bgm())
	if _session.hero.is_alive() \
			and float(_session.hero.hp) / float(maxi(_session.hero.max_hp, 1)) < 0.25:
		await _message.play(Loc.t("MSG_WOUNDED"))
	_exit_busy()


## Returns [command, argument], or [] when the player backed out and should be
## asked again.
func _ask_command() -> Array:
	var pick := await _command.open_menu(
			[Loc.t("MENU_FIGHT"), Loc.t("MENU_SPELL"),
			Loc.t("MENU_ITEM"), Loc.t("MENU_RUN")], [], [], false)
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
		await _message.play(Loc.t("MSG_NO_SPELLS_BATTLE"))
		return []

	var labels: Array[String] = []
	var costs: Array[String] = []
	var affordable: Array[bool] = []
	for spell in spells:
		labels.append(Loc.spell_name(spell))
		costs.append(Loc.t("FMT_MP", {"mp": spell.mp_cost}))
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
		await _message.play(Loc.t("MSG_NO_ITEMS_BATTLE"))
		return []

	var labels: Array[String] = []
	for item in usable:
		labels.append(item.display_name)
	var pick := await _submenu.open_menu(labels)
	if pick < 0:
		return []
	return [BattleState.Command.ITEM, usable[pick].id]


## Performs an already-resolved turn, one event at a time.
##
## "You attack!" and "Slime takes 4 damage." are two events but one sentence;
## reading them as separate lines doubles the waiting for no information.
func _play(events: Array[BattleEvent]) -> void:
	var index := 0
	while index < events.size():
		var event := events[index]
		_apply_effect(event)
		var line := BattleText.describe(event, _monster_name, _session.db)

		if index + 1 < events.size() and _merges(event, events[index + 1]):
			var follow := events[index + 1]
			var tail := BattleText.describe(follow, _monster_name, _session.db)
			if line.length() + tail.length() <= 62:
				_apply_effect(follow)
				line = "%s  %s" % [line, tail]
				index += 1

		if line != "":
			await _message.play(line)
		_refresh_status()
		index += 1


func _merges(event: BattleEvent, next: BattleEvent) -> bool:
	var opener := event.kind == BattleEvent.Kind.ATTACK \
			or event.kind == BattleEvent.Kind.CRITICAL \
			or event.kind == BattleEvent.Kind.SPELL_CAST
	var result := next.kind == BattleEvent.Kind.DAMAGE \
			or next.kind == BattleEvent.Kind.NO_DAMAGE \
			or next.kind == BattleEvent.Kind.HEAL
	return opener and result and event.by_hero == next.by_hero


func _stat_snapshot() -> Dictionary:
	var hero := _session.hero
	return {
		"STAT_STRENGTH": hero.strength, "STAT_AGILITY": hero.agility,
		"STAT_MAX_HP": hero.max_hp, "STAT_MAX_MP": hero.max_mp,
	}


## "Level 5!" says nothing about what got better. This does.
func _report_level_gains(before: Dictionary, events: Array[BattleEvent]) -> void:
	var levelled := false
	for event in events:
		if event.kind == BattleEvent.Kind.LEVEL_UP:
			levelled = true
			break
	if not levelled:
		return

	var after := _stat_snapshot()
	var parts: Array[String] = []
	for key in after:
		var gain: int = int(after[key]) - int(before[key])
		if gain > 0:
			parts.append(Loc.t("FMT_GAIN", {"stat": Loc.t(key), "amount": gain}))
	if not parts.is_empty():
		await _message.play("  ".join(parts))


## One branch per kind. `match` stops at the first hit, so a duplicated case
## further down is dead code — which is how the monster's self-heal stopped
## showing on the HP bar and the defeat fade stopped playing.
func _apply_effect(event: BattleEvent) -> void:
	match event.kind:
		BattleEvent.Kind.ATTACK:
			_sfx("sfx_attack")
		BattleEvent.Kind.CRITICAL:
			_sfx("sfx_critical")
			_flash(Color(1, 1, 1, 0.45), 0.14)
		BattleEvent.Kind.SPELL_CAST:
			_sfx("sfx_spell")
		BattleEvent.Kind.LEVEL_UP:
			_sfx("sfx_level_up")
		BattleEvent.Kind.GOLD_GAINED:
			_sfx("sfx_gold")
		BattleEvent.Kind.HERO_DEFEATED:
			_sfx("sfx_death")
		BattleEvent.Kind.MONSTER_TRANSFORMED:
			_sfx("sfx_boss")
			_flash(Color(0.9, 0.3, 0.3, 0.6), 0.35)
			_adopt_current_monster()
		BattleEvent.Kind.MONSTER_DEFEATED:
			_sfx("sfx_defeat_monster")
			_portrait.play_defeat()
		BattleEvent.Kind.DAMAGE:
			if event.by_hero:
				_monster_hp = maxi(0, _monster_hp - event.amount)
				_portrait.play_hit()
				_popup(str(event.amount), _monster_anchor(), Color(1, 0.86, 0.5))
			else:
				_sfx("sfx_hurt")
				_shake_screen()
				_popup(str(event.amount), _hero_anchor(), Color(1, 0.45, 0.45))
		BattleEvent.Kind.HEAL:
			_sfx("sfx_heal")
			if event.by_hero:
				_popup("+%d" % event.amount, _hero_anchor(), Color(0.55, 1.0, 0.65))
			else:
				_monster_hp = mini(_monster_max_hp, _monster_hp + event.amount)
				_popup("+%d" % event.amount, _monster_anchor(), Color(0.55, 1.0, 0.65))
		BattleEvent.Kind.ITEM_USED:
			_popup("+%d" % event.amount, _hero_anchor(), Color(0.55, 1.0, 0.65))
	_refresh_battle_hp()


func _monster_anchor() -> Vector2:
	return _portrait.position + _portrait.size * 0.5


## The party has no sprite in battle, so their numbers land under the window
## on the side the status box is on.
func _hero_anchor() -> Vector2:
	return Vector2(84, 236)


func _popup(text: String, at: Vector2, color: Color) -> void:
	if _battle.visible:
		FloatingNumber.spawn(_battle, text, at, color)


func _flash(color: Color, duration: float) -> void:
	_flash_rect.color = color
	_flash_rect.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_flash_rect, "modulate:a", 0.0, duration)


## Two quick blinks before the battle window drops in.
func _encounter_transition() -> void:
	for i in 2:
		_flash(Color(1, 1, 1, 0.8), 0.09)
		await get_tree().create_timer(0.11).timeout


## A boss's second form is a different monster: new name, new HP, new portrait.
func _adopt_current_monster() -> void:
	if _session.battle == null or _session.battle.monster.monster == null:
		return
	var data := _session.battle.monster.monster
	_monster_name = Loc.monster_name(data)
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
	_bgm("bgm_town")
	_sfx("sfx_victory")
	await _message.play(Loc.t("MSG_VICTORY_1"))
	await _message.play(Loc.t("MSG_VICTORY_2"))
	await _message.play(Loc.t("MSG_VICTORY_3"))
	await _wait_for_key("")


func _handle_death() -> void:
	await _message.play(Loc.t("MSG_DEAD"))
	await _wait_for_key("")
	var lost := _session.respawn()
	_battle.visible = false
	_message.clear()
	await _message.play(Loc.t("MSG_RESPAWN", {"gold": lost}))
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
	if not is_busy():
		_handle_death_on_field()


func _handle_death_on_field() -> void:
	_enter_busy()
	await _handle_death()
	_exit_busy()


func _on_map_changed(map_id: StringName, cell: Vector2i) -> void:
	var map := _session.db.map(map_id)
	_field.render_map(map)
	# Chests you have already emptied stay open across visits.
	for chest in map.chests:
		if _session.is_chest_open(map_id, chest):
			_field.set_cell_terrain(chest.cell, Terrain.Type.FLOOR)
	_field.snap_hero(cell)
	_refresh_sight()
	var place := Loc.map_name(map)
	_place.text = place
	# A new map is a new context: the old map's chatter goes with it.
	_message.clear()
	_message.push(Loc.t("FMT_PLACE", {"place": place}))
	if _booted:
		_sfx("sfx_stairs")
	_bgm(_map_bgm())
	_first_visit_hints(map)


## Said once, then remembered in the save so it never nags.
func _first_visit_hints(map: MapData) -> void:
	if map.id == &"field" and not _session.has_flag(&"hint_field"):
		_session.set_flag(&"hint_field")
		_message.push(Loc.t("MSG_HINT_FIELD"))
	elif map.is_dungeon and not _session.has_flag(&"hint_dungeon"):
		_session.set_flag(&"hint_dungeon")
		_message.push(Loc.t("MSG_HINT_DUNGEON"))


func _on_terrain_damaged(amount: int) -> void:
	_message.push(Loc.t("MSG_SWAMP", {"amount": amount}))


func _refresh_status() -> void:
	var hero := _session.hero
	_status.set_values(hero.level, hero.hp, hero.max_hp, hero.mp, hero.max_mp, hero.gold)
	_refresh_battle_hp()


func _refresh_battle_hp() -> void:
	if not _battle.visible:
		return
	_hp_text.text = Loc.t("FMT_HP", {"hp": _monster_hp, "max": _monster_max_hp})
	var ratio := float(_monster_hp) / float(maxi(_monster_max_hp, 1))
	_hp_fill.size.x = HP_BAR_WIDTH * clampf(ratio, 0.0, 1.0)
