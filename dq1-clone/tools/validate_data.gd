## Data integrity gate.
##
##   godot --headless --path . --script res://tools/validate_data.gd
##
## Catches the failures that are silent at runtime and expensive later:
## dangling ids, off-by-one tables, and maps where a warp cannot be walked to.
## Exits non-zero on any failure so it can gate CI.
extends SceneTree

var _failures: Array[String] = []
var _checks := 0


func _initialize() -> void:
	var db := GameDatabase.load_default()
	if db == null:
		printerr("[validate] cannot load %s" % GameDatabase.PATH)
		quit(1)
		return

	_check_level_curve(db)
	_check_spells(db)
	_check_items(db)
	_check_monsters(db)
	_check_encounter_tables(db)
	_check_shops(db)
	_check_maps(db)
	_check_new_game(db)

	print("[validate] %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr("  FAIL  %s" % failure)
	quit(1 if _failures.size() > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# --- 레벨 커브 ------------------------------------------------------------

func _check_level_curve(db: GameDatabase) -> void:
	var curve := db.level_curve
	_expect(curve != null, "level_curve missing")
	if curve == null:
		return

	var levels := curve.strength.size()
	_expect(levels > 1, "level curve has no levels")
	_expect(curve.agility.size() == levels, "agility table length != strength table")
	_expect(curve.max_hp.size() == levels, "max_hp table length != strength table")
	_expect(curve.max_mp.size() == levels, "max_mp table length != strength table")
	_expect(curve.required_exp.size() == levels - 1,
			"required_exp should have max_level-1 entries, has %d for %d levels"
			% [curve.required_exp.size(), levels])

	for i in range(1, curve.required_exp.size()):
		_expect(curve.required_exp[i] > curve.required_exp[i - 1],
				"required_exp not strictly increasing at index %d" % i)
	for i in range(1, levels):
		_expect(curve.max_hp[i] >= curve.max_hp[i - 1],
				"max_hp decreases at level %d" % (i + 1))
		_expect(curve.strength[i] >= curve.strength[i - 1],
				"strength decreases at level %d" % (i + 1))
		_expect(curve.agility[i] >= curve.agility[i - 1],
				"agility decreases at level %d" % (i + 1))
		_expect(curve.max_mp[i] >= curve.max_mp[i - 1],
				"max_mp decreases at level %d" % (i + 1))

	_expect(curve.level_for_exp(0) == 1, "level_for_exp(0) != 1")
	_expect(curve.level_for_exp(curve.required_exp[0]) == 2, "first level-up threshold wrong")
	_expect(curve.level_for_exp(999_999) == levels, "max exp does not reach max level")

	# A spell you cannot pay for is a spell you never cast.
	for spell in db.spells:
		if spell.learn_level <= 0:
			continue
		var mp_at_learn: int = curve.max_mp[spell.learn_level - 1]
		_expect(mp_at_learn >= spell.mp_cost,
				"%s learned at level %d but max MP there is %d < cost %d"
				% [spell.id, spell.learn_level, mp_at_learn, spell.mp_cost])


# --- 주문 / 아이템 / 몬스터 -----------------------------------------------

func _check_spells(db: GameDatabase) -> void:
	var seen_ids := {}
	var seen_levels := {}
	for spell in db.spells:
		_expect(spell.id != &"", "spell with empty id")
		_expect(not seen_ids.has(spell.id), "duplicate spell id %s" % spell.id)
		seen_ids[spell.id] = true
		_expect(spell.mp_cost >= 0, "%s has negative mp_cost" % spell.id)
		_expect(spell.learn_level >= 0 and spell.learn_level <= db.level_curve.max_level(),
				"%s learn_level %d out of range" % [spell.id, spell.learn_level])
		if spell.learn_level > 0:
			_expect(not seen_levels.has(spell.learn_level),
					"two spells learned at level %d" % spell.learn_level)
			seen_levels[spell.learn_level] = true
		if spell.kind == "damage" or spell.kind == "heal":
			_expect(spell.hero_power_min <= spell.hero_power_max,
					"%s hero power range inverted" % spell.id)
			_expect(spell.monster_power_min <= spell.monster_power_max,
					"%s monster power range inverted" % spell.id)
			_expect(spell.hero_power_max > 0 or spell.monster_power_max > 0,
					"%s is a %s spell with no power" % [spell.id, spell.kind])
		_expect(spell.usable_in_battle or spell.usable_in_field,
				"%s is usable nowhere" % spell.id)


func _check_items(db: GameDatabase) -> void:
	var seen := {}
	for item in db.items:
		_expect(item.id != &"", "item with empty id")
		_expect(not seen.has(item.id), "duplicate item id %s" % item.id)
		seen[item.id] = true
		_expect(item.sell_price <= item.buy_price,
				"%s sells for more than it costs" % item.id)
		_expect(item.buy_price >= 0, "%s has negative price" % item.id)
		if item.kind == "weapon":
			_expect(item.attack_bonus > 0, "weapon %s gives no attack" % item.id)
		if item.kind == "armor" or item.kind == "shield":
			_expect(item.defense_bonus > 0, "%s %s gives no defense" % [item.kind, item.id])


func _check_monsters(db: GameDatabase) -> void:
	var seen := {}
	for monster in db.monsters:
		_expect(monster.id != &"", "monster with empty id")
		_expect(not seen.has(monster.id), "duplicate monster id %s" % monster.id)
		seen[monster.id] = true
		_expect(monster.max_hp > 0, "%s has no HP" % monster.id)
		_expect(monster.strength > 0, "%s has no strength" % monster.id)
		_expect(monster.agility > 0, "%s has no agility" % monster.id)
		_expect(monster.gold_reward_min <= monster.gold_reward_max,
				"%s gold range inverted" % monster.id)
		if monster.transforms_into != &"":
			var next := db.monster(monster.transforms_into)
			_expect(next != null,
					"%s transforms into unknown monster %s"
					% [monster.id, monster.transforms_into])
			_expect(monster.transforms_into != monster.id,
					"%s transforms into itself" % monster.id)
			# A cycle here is an unwinnable fight that never reports an error.
			if next != null:
				var chain := {monster.id: true}
				var cursor := next
				while cursor != null and cursor.transforms_into != &"":
					if chain.has(cursor.id):
						break
					chain[cursor.id] = true
					cursor = db.monster(cursor.transforms_into)
				_expect(cursor == null or not chain.has(cursor.id),
						"%s starts a transformation cycle" % monster.id)
		_expect(not monster.actions.is_empty(), "%s has no actions" % monster.id)

		var total_weight := 0
		var has_always_available := false
		for action in monster.actions:
			_expect(action.weight > 0, "%s has a zero-weight action" % monster.id)
			total_weight += action.weight
			_expect(action.hp_threshold >= 0.0 and action.hp_threshold <= 1.0,
					"%s hp_threshold out of range" % monster.id)
			if action.hp_threshold >= 1.0:
				has_always_available = true
			if action.kind == "spell":
				var spell := db.spell(action.spell_id)
				_expect(spell != null,
						"%s references unknown spell %s" % [monster.id, action.spell_id])
				if spell != null:
					_expect(spell.usable_in_battle,
							"%s casts %s which is not a battle spell"
							% [monster.id, spell.id])
					_expect(monster.max_mp >= spell.mp_cost,
							"%s casts %s (cost %d) with only %d max MP"
							% [monster.id, spell.id, spell.mp_cost, monster.max_mp])
		_expect(total_weight > 0, "%s has no usable actions" % monster.id)
		# Without one unconditional action a healthy monster can end up with
		# nothing to do, which silently turns into a free turn for the player.
		_expect(has_always_available,
				"%s has no action available at full HP" % monster.id)


func _check_encounter_tables(db: GameDatabase) -> void:
	var seen := {}
	for table in db.encounter_tables:
		_expect(table.id != &"", "encounter table with empty id")
		_expect(not seen.has(table.id), "duplicate encounter table %s" % table.id)
		seen[table.id] = true
		_expect(not table.entries.is_empty(), "%s has no entries" % table.id)
		for entry in table.entries:
			_expect(db.monster(entry.monster_id) != null,
					"%s references unknown monster %s" % [table.id, entry.monster_id])
			_expect(entry.weight > 0, "%s has a zero-weight entry" % table.id)
			_expect(entry.tier > 0, "%s entry %s has tier 0" % [table.id, entry.monster_id])
			var monster := db.monster(entry.monster_id)
			if monster != null:
				_expect(not monster.is_boss,
						"%s puts boss %s in a random table" % [table.id, entry.monster_id])


# --- 맵 -------------------------------------------------------------------

func _check_maps(db: GameDatabase) -> void:
	var seen := {}
	for map in db.maps:
		_expect(map.id != &"", "map with empty id")
		_expect(not seen.has(map.id), "duplicate map id %s" % map.id)
		seen[map.id] = true
		_expect(map.width > 0 and map.height > 0, "%s has zero size" % map.id)
		_expect(map.tiles.size() == map.width * map.height,
				"%s tile count %d != %dx%d" % [map.id, map.tiles.size(), map.width, map.height])
		_expect(map.elevation.size() == map.tiles.size(),
				"%s elevation length != tile count" % map.id)

		for value in map.tiles:
			if value >= Terrain.Type.size():
				_failures.append("%s has unknown terrain id %d" % [map.id, value])
				break
		_checks += 1

		_expect(map.in_bounds(map.default_spawn), "%s spawn out of bounds" % map.id)
		_expect(Terrain.is_passable(map.tile_at(map.default_spawn)),
				"%s spawns on impassable %s"
				% [map.id, Terrain.type_name(map.tile_at(map.default_spawn))])

		if map.encounter_rate > 0:
			_expect(db.encounter_table(map.encounter_table_id) != null,
					"%s has encounters but no valid table (%s)"
					% [map.id, map.encounter_table_id])

		for warp in map.warps:
			_expect(map.in_bounds(warp.from_cell),
					"%s warp source %v out of bounds" % [map.id, warp.from_cell])
			_expect(Terrain.is_passable(map.tile_at(warp.from_cell)),
					"%s warp source %v is impassable" % [map.id, warp.from_cell])
			var destination := db.map(warp.to_map)
			_expect(destination != null,
					"%s warps to unknown map %s" % [map.id, warp.to_map])
			if destination != null:
				_expect(destination.in_bounds(warp.to_cell),
						"%s -> %s target %v out of bounds"
						% [map.id, warp.to_map, warp.to_cell])
				_expect(Terrain.is_passable(destination.tile_at(warp.to_cell)),
						"%s -> %s lands on impassable %s"
						% [map.id, warp.to_map, Terrain.type_name(destination.tile_at(warp.to_cell))])

		var chest_cells := {}
		for chest in map.chests:
			_expect(map.in_bounds(chest.cell),
					"%s chest at %v out of bounds" % [map.id, chest.cell])
			_expect(not chest_cells.has(chest.cell),
					"%s has two chests on %v" % [map.id, chest.cell])
			chest_cells[chest.cell] = true
			_expect(map.tile_at(chest.cell) == Terrain.Type.CHEST,
					"%s chest at %v is not drawn as a chest (%s)"
					% [map.id, chest.cell, Terrain.type_name(map.tile_at(chest.cell))])
			_expect(chest.gold > 0 or chest.item_id != &"",
					"%s chest at %v holds nothing" % [map.id, chest.cell])
			if chest.item_id != &"":
				_expect(db.item(chest.item_id) != null,
						"%s chest at %v holds unknown item %s"
						% [map.id, chest.cell, chest.item_id])

		if map.boss_monster != &"":
			var boss := db.monster(map.boss_monster)
			_expect(boss != null,
					"%s names unknown boss %s" % [map.id, map.boss_monster])
			_expect(boss == null or boss.is_boss,
					"%s uses non-boss %s as its boss" % [map.id, map.boss_monster])
			_expect(map.boss_flag != &"",
					"%s has a boss with no flag, so it would refight forever" % map.id)
			_expect(map.in_bounds(map.boss_cell),
					"%s boss cell %v out of bounds" % [map.id, map.boss_cell])
			_expect(Terrain.is_passable(map.tile_at(map.boss_cell)),
					"%s boss cell %v cannot be stepped on" % [map.id, map.boss_cell])

		for npc in map.npcs:
			_expect(map.in_bounds(npc.cell), "%s npc %s out of bounds" % [map.id, npc.id])
			_expect(Terrain.is_passable(map.tile_at(npc.cell)),
					"%s npc %s stands inside a wall" % [map.id, npc.id])
			_check_npc(db, map, npc)

		_check_reachability(map)


## Flood fill from the spawn. A warp you cannot walk to is a dead end that no
## amount of playtesting will reveal until someone tries that exact route.
##
## NPCs block movement, so they are walls here — and an NPC parked in a doorway
## can seal off half a town. That is exactly what this catches.
func _check_reachability(map: MapData) -> void:
	var reachable := {}
	var queue: Array[Vector2i] = [map.default_spawn]
	reachable[map.default_spawn] = true
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for direction in directions:
			var next: Vector2i = cell + direction
			if reachable.has(next):
				continue
			var terrain := map.tile_at(next)
			if terrain < 0 or not Terrain.is_passable(terrain):
				continue
			if map.npc_at(next) != null:
				continue
			reachable[next] = true
			queue.append(next)

	for warp in map.warps:
		_expect(reachable.has(warp.from_cell),
				"%s: warp at %v is unreachable from the spawn" % [map.id, warp.from_cell])

	for chest in map.chests:
		_expect(reachable.has(chest.cell),
				"%s: chest at %v is unreachable" % [map.id, chest.cell])
	if map.boss_monster != &"":
		_expect(reachable.has(map.boss_cell),
				"%s: the boss at %v cannot be walked to" % [map.id, map.boss_cell])

	# You cannot stand on an NPC, so "reachable" means standing next to one.
	for npc in map.npcs:
		var adjacent := false
		for direction in directions:
			if reachable.has(npc.cell + direction):
				adjacent = true
				break
		_expect(adjacent, "%s: npc %s at %v cannot be talked to" % [map.id, npc.id, npc.cell])


func _check_npc(db: GameDatabase, map: MapData, npc: NpcPlacement) -> void:
	_expect(not npc.dialogue.is_empty(), "%s: npc %s has nothing to say" % [map.id, npc.id])

	var has_fallback := false
	for entry in npc.dialogue:
		_expect(entry.lines.size() > 0,
				"%s: npc %s has an empty dialogue entry" % [map.id, npc.id])
		if entry.required_flag == &"" and entry.forbidden_flag == &"":
			has_fallback = true
	# Without an unconditional entry an NPC can end up mute once flags move on.
	_expect(has_fallback,
			"%s: npc %s has no unconditional line" % [map.id, npc.id])

	if npc.role == "shop":
		_expect(db.shop(npc.shop_id) != null,
				"%s: shop npc %s points at unknown shop %s" % [map.id, npc.id, npc.shop_id])
	if npc.role == "inn":
		_expect(npc.inn_price > 0, "%s: inn %s charges nothing" % [map.id, npc.id])


func _check_shops(db: GameDatabase) -> void:
	var seen := {}
	var allowed := {
		"weapon": ["weapon"],
		"armor": ["armor", "shield"],
		"item": ["consumable"],
	}
	for shop in db.shops:
		_expect(shop.id != &"", "shop with empty id")
		_expect(not seen.has(shop.id), "duplicate shop id %s" % shop.id)
		seen[shop.id] = true
		_expect(not shop.stock.is_empty(), "%s sells nothing" % shop.id)
		for item_id in shop.stock:
			var item := db.item(item_id)
			_expect(item != null, "%s stocks unknown item %s" % [shop.id, item_id])
			if item == null:
				continue
			_expect(item.buy_price > 0,
					"%s stocks %s which is free" % [shop.id, item_id])
			_expect(allowed[shop.kind].has(item.kind),
					"%s (%s shop) stocks a %s" % [shop.id, shop.kind, item.kind])


# --- 새 게임 --------------------------------------------------------------

func _check_new_game(db: GameDatabase) -> void:
	_expect(db.map(db.start_map) != null, "start_map %s does not exist" % db.start_map)
	_expect(db.start_gold >= 0, "negative start_gold")
	for id in [db.start_weapon, db.start_armor, db.start_shield]:
		if id != &"":
			_expect(db.item(id) != null, "start equipment %s does not exist" % id)
