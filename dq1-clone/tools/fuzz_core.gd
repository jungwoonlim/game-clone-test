## Random-action fuzzer for core/.
##
##   godot --headless --path . --script res://tools/fuzz_core.gd
##   godot --headless --path . --script res://tools/fuzz_core.gd -- 500 400
##
## The other suites walk the paths a player is meant to walk. This one mashes
## buttons: it buys things it cannot afford, equips herbs, casts spells it does
## not know, sells equipped gear, saves mid-dungeon, dies, and loads — then
## checks a list of things that must be true no matter what happened.
##
## Failures print the seed and the action index, so any finding replays.
extends SceneTree

const DEFAULT_SESSIONS := 200
const DEFAULT_ACTIONS := 250
const TURN_CAP := 600

var _db: GameDatabase
var _failures: Array[String] = []
var _checks := 0
var _actions_run := 0


func _initialize() -> void:
	_db = GameDatabase.load_default()
	if _db == null:
		printerr("[fuzz] no database")
		quit(1)
		return

	var args := OS.get_cmdline_user_args()
	var sessions := int(args[0]) if args.size() > 0 else DEFAULT_SESSIONS
	var actions := int(args[1]) if args.size() > 1 else DEFAULT_ACTIONS

	var started := Time.get_ticks_msec()
	for index in sessions:
		_run_session(index + 1, actions)
		if _failures.size() > 12:
			break
	var elapsed := (Time.get_ticks_msec() - started) / 1000.0

	print("[fuzz] %d sessions x %d actions (%d applied) in %.1fs, %d invariant checks"
			% [sessions, actions, _actions_run, elapsed, _checks])
	print("[fuzz] %d failures" % _failures.size())
	for failure in _failures:
		printerr("  FAIL  %s" % failure)
	SaveGame.erase()
	quit(1 if _failures.size() > 0 else 0)


func _fail(seed_value: int, step: int, action: String, message: String) -> void:
	var line := "seed %d step %d (%s): %s" % [seed_value, step, action, message]
	if not _failures.has(line):
		_failures.append(line)


# --- 세션 -----------------------------------------------------------------

func _run_session(seed_value: int, actions: int) -> void:
	var session := GameSession.create_new(seed_value, _db)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 13

	_seed_value = seed_value
	_saved = {}
	for step in actions:
		_step = step
		var action := _apply_action(session, rng)
		_actions_run += 1
		_check_invariants(session, seed_value, step, action)
		if not _failures.is_empty() and _failures.size() > 12:
			return


func _apply_action(session: GameSession, rng: RandomNumberGenerator) -> String:
	var roll := rng.randi_range(0, 15)

	if session.in_battle():
		# Inside a fight, only battle commands are reachable.
		var command := rng.randi_range(0, 3)
		match command:
			0:
				session.battle_command(BattleState.Command.ATTACK)
				return "battle attack"
			1:
				session.battle_command(BattleState.Command.SPELL, _random_spell(rng))
				return "battle spell"
			2:
				session.battle_command(BattleState.Command.ITEM, _random_item(rng))
				return "battle item"
			_:
				session.battle_command(BattleState.Command.FLEE)
				return "battle flee"

	match roll:
		0, 1, 2, 3:
			session.try_move(_random_direction(rng))
			return "move"
		4:
			session.begin_battle(_random_monster(rng))
			return "begin battle"
		5:
			_checked_buy(session, _random_item(rng), rng)
			return "buy"
		6:
			_checked_sell(session, _random_item(rng), rng)
			return "sell"
		7:
			_checked_equip(session, _random_item(rng), rng)
			return "equip"
		8:
			session.rest(rng.randi_range(0, 200))
			return "rest"
		9:
			session.cast_in_field(_random_spell(rng))
			return "field spell"
		10:
			session.use_item_in_field(_random_item(rng))
			return "use item"
		11:
			# Only a save that actually succeeded is something load must match.
			if session.save_game() == OK:
				_saved = _snapshot(session)
			return "save"
		12:
			_checked_load(session)
			return "load"
		13:
			_checked_respawn(session)
			return "respawn"
		14:
			_checked_chest(session)
			return "open chest"
		_:
			_teleport(session, rng)
			return "teleport"


# --- 보존 법칙 ------------------------------------------------------------
#
# Owning the same item twice is legal — one worn, one in the bag — so "equipped
# is never in the bag" is not the invariant. What must hold is that these
# operations neither duplicate nor destroy anything.

var _seed_value := 0
var _step := 0
var _saved: Dictionary = {}


## Every item the party owns, bag and slots together.
func _owned(hero: Hero) -> Dictionary:
	var counts := {}
	for id in hero.inventory:
		counts[id] = int(counts.get(id, 0)) + 1
	for kind in ["weapon", "armor", "shield"]:
		var equipped := hero.equipped_id(kind)
		if equipped != &"":
			counts[equipped] = int(counts.get(equipped, 0)) + 1
	return counts


func _delta(before: Dictionary, after: Dictionary, id: StringName) -> int:
	return int(after.get(id, 0)) - int(before.get(id, 0))


func _same_owned(before: Dictionary, after: Dictionary) -> bool:
	if before.size() != after.size():
		return false
	for id in before:
		if before[id] != after.get(id, 0):
			return false
	return true


func _checked_buy(session: GameSession, id: StringName, _rng: RandomNumberGenerator) -> void:
	var before := _owned(session.hero)
	var gold := session.hero.gold
	var result := session.buy(id)
	var after := _owned(session.hero)
	var item := _db.item(id)

	if result == TownServices.Result.OK:
		_expect(_delta(before, after, id) == 1, _seed_value, _step, "buy",
				"buying %s added %d copies" % [id, _delta(before, after, id)])
		_expect(session.hero.gold == gold - item.buy_price, _seed_value, _step, "buy",
				"buying %s cost %d, priced %d" % [id, gold - session.hero.gold, item.buy_price])
	else:
		_expect(_same_owned(before, after), _seed_value, _step, "buy",
				"a refused purchase of %s changed the bag" % id)
		_expect(session.hero.gold == gold, _seed_value, _step, "buy",
				"a refused purchase of %s cost gold" % id)


func _checked_sell(session: GameSession, id: StringName, _rng: RandomNumberGenerator) -> void:
	var before := _owned(session.hero)
	var gold := session.hero.gold
	var result := session.sell(id)
	var after := _owned(session.hero)
	var item := _db.item(id)

	if result == TownServices.Result.OK:
		_expect(_delta(before, after, id) == -1, _seed_value, _step, "sell",
				"selling %s removed %d copies" % [id, -_delta(before, after, id)])
		_expect(session.hero.gold == gold + item.sell_price, _seed_value, _step, "sell",
				"selling %s paid %d, priced %d" % [id, session.hero.gold - gold, item.sell_price])
	else:
		_expect(_same_owned(before, after), _seed_value, _step, "sell",
				"a refused sale of %s changed the bag" % id)
		_expect(session.hero.gold == gold, _seed_value, _step, "sell",
				"a refused sale of %s paid gold" % id)


func _checked_equip(session: GameSession, id: StringName, _rng: RandomNumberGenerator) -> void:
	var before := _owned(session.hero)
	var gold := session.hero.gold
	var result := session.equip(id)
	var after := _owned(session.hero)

	_expect(_same_owned(before, after), _seed_value, _step, "equip",
			"equipping %s changed what the party owns (%s -> %s)" % [id, before, after])
	_expect(session.hero.gold == gold, _seed_value, _step, "equip",
			"equipping %s moved gold" % id)
	if result == TownServices.Result.OK:
		var item := _db.item(id)
		_expect(session.hero.equipped_id(item.kind) == id, _seed_value, _step, "equip",
				"equip reported OK but %s is not in the %s slot" % [id, item.kind])


## Everything a save is supposed to carry.
func _snapshot(session: GameSession) -> Dictionary:
	var hero := session.hero
	return {
		"level": hero.level, "exp": hero.total_exp, "gold": hero.gold,
		"hp": hero.hp, "mp": hero.mp,
		"weapon": hero.weapon_id, "armor": hero.armor_id, "shield": hero.shield_id,
		"bag": hero.inventory.duplicate(), "flags": session.flags.duplicate(),
		"map": session.world.map.id, "cell": session.world.cell,
		"steps": session.world.steps,
	}


func _checked_load(session: GameSession) -> void:
	var loaded := session.load_game()
	if not loaded or _saved.is_empty():
		return
	var now := _snapshot(session)
	for key in _saved:
		var before = _saved[key]
		var after = now[key]
		var same: bool = str(before) == str(after)
		_expect(same, _seed_value, _step, "load",
				"%s did not survive save/load (%s -> %s)" % [key, before, after])


## Death costs exactly half the gold, rounded down, and nothing else.
func _checked_respawn(session: GameSession) -> void:
	var gold := session.hero.gold
	var owned := _owned(session.hero)
	var exp_before := session.hero.total_exp
	var lost := session.respawn()
	_expect(lost == gold / 2, _seed_value, _step, "respawn",
			"death took %d of %d gold" % [lost, gold])
	_expect(session.hero.gold == gold - lost, _seed_value, _step, "respawn",
			"gold after death is %d, expected %d" % [session.hero.gold, gold - lost])
	_expect(_same_owned(owned, _owned(session.hero)), _seed_value, _step,
			"respawn", "death changed the bag")
	_expect(session.hero.total_exp == exp_before, _seed_value, _step, "respawn",
			"death changed experience")
	_expect(session.hero.hp == session.hero.max_hp, _seed_value, _step, "respawn",
			"respawn did not restore HP")


## A chest pays out once. Ever.
func _checked_chest(session: GameSession) -> void:
	var gold := session.hero.gold
	var owned := _owned(session.hero)
	var result: Dictionary = session.open_chest_here()
	var paid := session.hero.gold - gold

	if bool(result["empty"]) or bool(result["full"]) or not bool(result["found"]):
		_expect(paid == 0, _seed_value, _step, "open chest",
				"a chest that gave nothing still paid %d gold" % paid)
		_expect(_same_owned(owned, _owned(session.hero)), _seed_value, _step,
				"open chest", "a chest that gave nothing still changed the bag")
		return

	_expect(paid == int(result["gold"]), _seed_value, _step, "open chest",
			"chest reported %d gold but paid %d" % [result["gold"], paid])
	# Second opening must be inert.
	var again: Dictionary = session.open_chest_here()
	_expect(bool(again["empty"]), _seed_value, _step, "open chest",
			"the same chest opened twice")
	_expect(session.hero.gold == gold + paid, _seed_value, _step, "open chest",
			"reopening a chest paid again")


func _random_direction(rng: RandomNumberGenerator) -> Vector2i:
	return [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][rng.randi_range(0, 3)]


func _random_item(rng: RandomNumberGenerator) -> StringName:
	if rng.randi_range(0, 9) == 0:
		return &"not_a_real_item"
	return _db.items[rng.randi_range(0, _db.items.size() - 1)].id


func _random_spell(rng: RandomNumberGenerator) -> StringName:
	if rng.randi_range(0, 9) == 0:
		return &"not_a_real_spell"
	return _db.spells[rng.randi_range(0, _db.spells.size() - 1)].id


func _random_monster(rng: RandomNumberGenerator) -> StringName:
	return _db.monsters[rng.randi_range(0, _db.monsters.size() - 1)].id


## Drops the party somewhere legal on a random map, to reach corners of the
## world a random walk would take forever to find.
func _teleport(session: GameSession, rng: RandomNumberGenerator) -> void:
	var map: MapData = _db.maps[rng.randi_range(0, _db.maps.size() - 1)]
	for attempt in 40:
		var cell := Vector2i(rng.randi_range(0, map.width - 1),
				rng.randi_range(0, map.height - 1))
		if Terrain.is_passable(map.tile_at(cell)) and map.npc_at(cell) == null:
			session.world.enter_map(map.id, cell)
			return
	session.world.enter_map(map.id)


# --- 불변식 ---------------------------------------------------------------

func _expect(condition: bool, seed_value: int, step: int, action: String,
		message: String) -> void:
	_checks += 1
	if not condition:
		_fail(seed_value, step, action, message)


func _check_invariants(session: GameSession, seed_value: int, step: int,
		action: String) -> void:
	var hero := session.hero
	var curve := _db.level_curve

	_expect(hero.hp >= 0 and hero.hp <= hero.max_hp, seed_value, step, action,
			"hp %d outside 0..%d" % [hero.hp, hero.max_hp])
	_expect(hero.mp >= 0 and hero.mp <= hero.max_mp, seed_value, step, action,
			"mp %d outside 0..%d" % [hero.mp, hero.max_mp])
	_expect(hero.gold >= 0, seed_value, step, action, "gold went negative (%d)" % hero.gold)
	_expect(hero.inventory.size() <= Hero.INVENTORY_MAX, seed_value, step, action,
			"bag holds %d items" % hero.inventory.size())
	_expect(hero.total_exp >= 0 and hero.total_exp <= Progression.max_exp(_db),
			seed_value, step, action, "total_exp %d out of range" % hero.total_exp)

	# The level must always be the one the EXP total buys.
	_expect(hero.level == curve.level_for_exp(hero.total_exp), seed_value, step, action,
			"level %d but %d exp buys level %d"
			% [hero.level, hero.total_exp, curve.level_for_exp(hero.total_exp)])
	_expect(hero.max_hp == curve.max_hp[hero.level - 1], seed_value, step, action,
			"max_hp %d does not match the curve at level %d" % [hero.max_hp, hero.level])
	_expect(hero.strength == curve.strength[hero.level - 1], seed_value, step, action,
			"strength drifted from the curve at level %d" % hero.level)

	# Equipped gear lives in its slot, never also in the bag.
	for kind in ["weapon", "armor", "shield"]:
		var equipped := hero.equipped_id(kind)
		if equipped == &"":
			continue
		var item := _db.item(equipped)
		_expect(item != null, seed_value, step, action,
				"%s slot holds unknown item %s" % [kind, equipped])
		if item != null:
			_expect(item.kind == kind, seed_value, step, action,
					"%s slot holds a %s (%s)" % [kind, item.kind, equipped])

	for id in hero.inventory:
		_expect(_db.item(id) != null, seed_value, step, action,
				"bag holds unknown item %s" % id)

	# The party is always standing somewhere it could have walked to.
	var map := session.world.map
	_expect(map != null, seed_value, step, action, "no current map")
	if map != null:
		var cell := session.world.cell
		_expect(map.in_bounds(cell), seed_value, step, action,
				"standing outside %s at %v" % [map.id, cell])
		if map.in_bounds(cell):
			_expect(Terrain.is_passable(map.tile_at(cell)), seed_value, step, action,
					"standing on impassable %s in %s"
					% [Terrain.type_name(map.tile_at(cell)), map.id])
			_expect(map.npc_at(cell) == null, seed_value, step, action,
					"standing on top of npc %s" % map.npc_at(cell))

	if session.battle != null:
		var battle := session.battle
		_expect(battle.monster.hp >= 0 and battle.monster.hp <= battle.monster.max_hp,
				seed_value, step, action, "monster hp %d outside 0..%d"
				% [battle.monster.hp, battle.monster.max_hp])
		_expect(battle.hero.hp >= 0, seed_value, step, action, "battle hero hp negative")
		_expect(battle.hero.mp >= 0, seed_value, step, action, "battle hero mp negative")
		_expect(battle.turn <= TURN_CAP, seed_value, step, action,
				"battle ran %d turns" % battle.turn)
		_expect(not battle.is_over(), seed_value, step, action,
				"a finished battle is still attached to the session")
