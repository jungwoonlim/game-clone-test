## Seeds every .tres in core/data/ and the terrain TileSet.
##
##   godot --headless --path . --script res://tools/build_tiles.gd
##   godot --headless --path . --import
##   godot --headless --path . --script res://tools/build_data.gd
##   godot --headless --path . --import
##
## Run once to create the dataset. After that the .tres files are the source of
## truth and can be edited in the inspector; re-running this OVERWRITES them.
extends SceneTree

const MAX_LEVEL := 30
const TILE_SIZE := 16

# Confirmed across sources; still flagged for ROM compare. See docs/06.
const REQUIRED_EXP := [
	7, 23, 47, 110, 220, 450, 800, 1300, 2000, 2900,
	4000, 5500, 7500, 10000, 13000, 16000, 19000, 22000, 26000, 30000,
	34000, 38000, 42000, 46000, 50000, 54000, 58000, 62000, 65535,
]

var _spells_by_id: Dictionary = {}


func _initialize() -> void:
	for dir in ["monsters", "spells", "items", "maps", "encounters"]:
		DirAccess.make_dir_recursive_absolute("res://core/data/%s" % dir)

	var curve := _build_level_curve()
	var spells := _build_spells()
	var items := _build_items()
	var monsters := _build_monsters()
	var tables := _build_encounter_tables()
	var maps := _build_maps()

	var db := GameDatabase.new()
	db.level_curve = curve
	db.spells = spells
	db.items = items
	db.monsters = monsters
	db.encounter_tables = tables
	db.maps = maps
	db.start_map = &"town"
	db.start_gold = 120
	db.start_weapon = &""
	db.start_armor = &""
	db.start_shield = &""
	_save(db, GameDatabase.PATH)

	_build_tileset()

	print("[build] %d monsters, %d spells, %d items, %d maps, %d tables" % [
		monsters.size(), spells.size(), items.size(), maps.size(), tables.size()])
	quit(0)


func _save(res: Resource, path: String) -> void:
	res.take_over_path(path)
	var err := ResourceSaver.save(res, path)
	if err != OK:
		printerr("[build] save failed: %s (err=%d)" % [path, err])
		quit(1)


# --- 레벨 커브 ------------------------------------------------------------

## Smooth placeholder curve. The real per-level values are unverified — see
## docs/06-VERIFICATION.md. Shaped to land near the original's level-30 totals.
func _build_level_curve() -> LevelCurve:
	var curve := LevelCurve.new()

	var exp_table: Array[int] = []
	for value in REQUIRED_EXP:
		exp_table.append(value)
	curve.required_exp = exp_table

	var strength: Array[int] = []
	var agility: Array[int] = []
	var hp: Array[int] = []
	var mp: Array[int] = []
	for i in MAX_LEVEL:
		var t := float(i) / float(MAX_LEVEL - 1)
		strength.append(_curve(4, 140, t, 1.35))
		agility.append(_curve(4, 130, t, 1.35))
		hp.append(_curve(15, 210, t, 1.25))
		# No MP until Heal is learned at level 3.
		mp.append(0 if i < 2 else _curve(0, 220, t, 1.45))
	curve.strength = strength
	curve.agility = agility
	curve.max_hp = hp
	curve.max_mp = mp

	_save(curve, "res://core/data/level_curve.tres")
	return curve


func _curve(from_value: int, to_value: int, t: float, power: float) -> int:
	return int(round(from_value + (to_value - from_value) * pow(t, power)))


# --- 주문 -----------------------------------------------------------------

func _build_spells() -> Array[SpellData]:
	# id, name, mp, kind, learn, hero min/max, monster min/max, battle, field
	var rows := [
		["heal", "Heal", 4, "heal", 3, 10, 17, 10, 17, true, true],
		["hurt", "Hurt", 2, "damage", 4, 3, 10, 5, 12, true, false],
		["sleep", "Sleep", 2, "sleep", 7, 0, 0, 0, 0, true, false],
		["radiant", "Radiant", 3, "field", 9, 0, 0, 0, 0, false, true],
		["stopspell", "Stopspell", 2, "stopspell", 10, 0, 0, 0, 0, true, false],
		["outside", "Outside", 6, "field", 12, 0, 0, 0, 0, false, true],
		["return", "Return", 8, "field", 13, 0, 0, 0, 0, false, true],
		["repel", "Repel", 2, "field", 15, 0, 0, 0, 0, false, true],
		["healmore", "Healmore", 10, "heal", 17, 85, 100, 85, 100, true, true],
		["hurtmore", "Hurtmore", 5, "damage", 19, 30, 45, 58, 65, true, false],
	]

	var out: Array[SpellData] = []
	for row in rows:
		var spell := SpellData.new()
		spell.id = StringName(row[0])
		spell.display_name = row[1]
		spell.mp_cost = row[2]
		spell.kind = row[3]
		spell.learn_level = row[4]
		spell.hero_power_min = row[5]
		spell.hero_power_max = row[6]
		spell.monster_power_min = row[7]
		spell.monster_power_max = row[8]
		spell.usable_in_battle = row[9]
		spell.usable_in_field = row[10]
		_save(spell, "res://core/data/spells/%s.tres" % row[0])
		out.append(spell)
		_spells_by_id[spell.id] = spell
	return out


# --- 아이템 ---------------------------------------------------------------

func _build_items() -> Array[ItemData]:
	# id, name, kind, buy, atk, def, hurt_reduction, blocks_terrain, effect, power
	var rows := [
		["w_club", "Club", "weapon", 10, 2, 0, 0.0, false, "", 0],
		["w_sword", "Sword", "weapon", 60, 7, 0, 0.0, false, "", 0],
		["w_blade", "Broad Blade", "weapon", 180, 15, 0, 0.0, false, "", 0],
		["a_clothes", "Clothes", "armor", 20, 0, 2, 0.0, false, "", 0],
		["a_leather", "Leather Armor", "armor", 70, 0, 4, 0.0, false, "", 0],
		["a_plate", "Plate Armor", "armor", 300, 0, 10, 0.333, true, "", 0],
		["s_small", "Small Shield", "shield", 90, 0, 4, 0.0, false, "", 0],
		["s_large", "Large Shield", "shield", 800, 0, 10, 0.0, false, "", 0],
		["herb", "Herb", "consumable", 24, 0, 0, 0.0, false, "heal_hp", 30],
		["torch", "Torch", "consumable", 8, 0, 0, 0.0, false, "light", 3],
	]

	var out: Array[ItemData] = []
	for row in rows:
		var item := ItemData.new()
		item.id = StringName(row[0])
		item.display_name = row[1]
		item.kind = row[2]
		item.buy_price = row[3]
		item.sell_price = int(row[3] / 2)
		item.attack_bonus = row[4]
		item.defense_bonus = row[5]
		item.hurt_reduction = row[6]
		item.blocks_terrain_damage = row[7]
		item.effect_id = StringName(row[8])
		item.effect_power = row[9]
		_save(item, "res://core/data/items/%s.tres" % row[0])
		out.append(item)
	return out


# --- 몬스터 ---------------------------------------------------------------

func _action(kind: String, weight: int, spell_id: String = "",
		hp_threshold: float = 1.0) -> MonsterAction:
	var action := MonsterAction.new()
	action.kind = kind
	action.weight = weight
	action.spell_id = StringName(spell_id)
	action.hp_threshold = hp_threshold
	return action


func _build_monsters() -> Array[MonsterData]:
	var out: Array[MonsterData] = []

	# id, name, hp, mp, str, agi, exp, gold_min, gold_max, sleep_res, stop_res
	#
	# EXP and gold are tuned against the original's EXP curve by
	# tools/simulate_balance.gd, not copied from the ROM. The first pass used
	# the original's tiny early-game rewards and the simulator reported ~8,900
	# battles to reach the boss — the curve assumes ~40 monsters across many
	# regions, and this slice has 8.
	var rows := [
		["m_slime", "Slime", 3, 0, 5, 3, 2, 2, 3, 0, 0],
		["m_slime_red", "Red Slime", 4, 0, 7, 3, 4, 3, 5, 0, 0],
		["m_drakee", "Drakee", 6, 0, 9, 6, 7, 5, 7, 0, 0],
		["m_ghost", "Ghost", 7, 0, 11, 8, 12, 8, 12, 32, 0],
		["m_magician", "Magician", 13, 30, 11, 12, 20, 12, 18, 0, 0],
		["m_scorpion", "Scorpion", 20, 20, 18, 16, 35, 16, 24, 64, 32],
		["m_wraith", "Wraith", 35, 40, 28, 22, 70, 34, 48, 96, 64],
		["m_dragonlord", "Dragonlord", 70, 60, 38, 36, 0, 0, 0, 255, 255],
	]

	var actions_by_id := {
		"m_magician": [_action("attack", 2), _action("spell", 2, "hurt")],
		"m_scorpion": [_action("attack", 3), _action("spell", 1, "sleep")],
		"m_wraith": [
			_action("attack", 3),
			_action("spell", 2, "hurt"),
			_action("spell", 2, "heal", 0.4),
		],
		"m_dragonlord": [
			_action("attack", 3),
			_action("spell", 2, "hurtmore"),
			_action("spell", 1, "stopspell", 0.7),
		],
	}

	for row in rows:
		var monster := MonsterData.new()
		monster.id = StringName(row[0])
		monster.display_name = row[1]
		monster.max_hp = row[2]
		monster.max_mp = row[3]
		monster.strength = row[4]
		monster.agility = row[5]
		monster.exp_reward = row[6]
		monster.gold_reward_min = row[7]
		monster.gold_reward_max = row[8]
		monster.resist_sleep = row[9]
		monster.resist_stopspell = row[10]

		var actions: Array[MonsterAction] = []
		if actions_by_id.has(row[0]):
			for action in actions_by_id[row[0]]:
				actions.append(action)
		else:
			actions.append(_action("attack", 1))
		monster.actions = actions

		if row[0] == "m_dragonlord":
			monster.is_boss = true
			monster.can_flee_from = false
			monster.can_be_critical = false

		_save(monster, "res://core/data/monsters/%s.tres" % row[0])
		out.append(monster)
	return out


# --- 인카운터 테이블 ------------------------------------------------------

func _entry(monster_id: String, weight: int, tier: int) -> EncounterEntry:
	var entry := EncounterEntry.new()
	entry.monster_id = StringName(monster_id)
	entry.weight = weight
	entry.tier = tier
	return entry


func _build_encounter_tables() -> Array[EncounterTable]:
	var specs := {
		# Weighted toward the weak end: with a single field table every monster
		# is everywhere, so the dangerous ones have to be rare instead of
		# distant. Regional tables replace this when the map grows (M5+).
		"et_field": [
			["m_slime", 40, 1], ["m_slime_red", 25, 2], ["m_drakee", 20, 3],
			["m_ghost", 10, 4], ["m_magician", 5, 5],
		],
		"et_dungeon": [
			["m_ghost", 20, 4], ["m_magician", 25, 5],
			["m_scorpion", 30, 6], ["m_wraith", 15, 7],
		],
	}

	var out: Array[EncounterTable] = []
	for id in specs:
		var table := EncounterTable.new()
		table.id = StringName(id)
		var entries: Array[EncounterEntry] = []
		for spec in specs[id]:
			entries.append(_entry(spec[0], spec[1], spec[2]))
		table.entries = entries
		_save(table, "res://core/data/encounters/%s.tres" % id)
		out.append(table)
	return out


# --- 맵 -------------------------------------------------------------------

func _blank(width: int, height: int, fill: int) -> PackedByteArray:
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	tiles.fill(fill)
	return tiles


func _rect(tiles: PackedByteArray, width: int, x0: int, y0: int, x1: int, y1: int,
		type: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			tiles[y * width + x] = type


func _warp(from_cell: Vector2i, to_map: String, to_cell: Vector2i) -> WarpPoint:
	var warp := WarpPoint.new()
	warp.from_cell = from_cell
	warp.to_map = StringName(to_map)
	warp.to_cell = to_cell
	return warp


func _npc(id: String, cell: Vector2i, role: String) -> NpcPlacement:
	var npc := NpcPlacement.new()
	npc.id = StringName(id)
	npc.cell = cell
	npc.role = role
	npc.dialogue_key = id
	return npc


func _build_maps() -> Array[MapData]:
	var out: Array[MapData] = []
	out.append(_build_town())
	out.append(_build_field())
	out.append(_build_dungeon())
	for map in out:
		_save(map, "res://core/data/maps/%s.tres" % map.id)
	return out


func _build_town() -> MapData:
	# 32x24 tiles is exactly one screen, so the camera never has to show
	# anything outside the map.
	var w := 32
	var h := 24
	var tiles := _blank(w, h, Terrain.Type.PLAIN)
	_rect(tiles, w, 0, 0, w - 1, 0, Terrain.Type.WALL)
	_rect(tiles, w, 0, h - 1, w - 1, h - 1, Terrain.Type.WALL)
	_rect(tiles, w, 0, 0, 0, h - 1, Terrain.Type.WALL)
	_rect(tiles, w, w - 1, 0, w - 1, h - 1, Terrain.Type.WALL)
	# Buildings.
	_rect(tiles, w, 4, 4, 9, 8, Terrain.Type.WALL)
	_rect(tiles, w, 18, 4, 24, 8, Terrain.Type.WALL)
	_rect(tiles, w, 4, 13, 9, 17, Terrain.Type.WALL)
	_rect(tiles, w, 18, 13, 24, 17, Terrain.Type.WALL)
	# Town gate.
	tiles[(h - 1) * w + 16] = Terrain.Type.DOOR

	var map := MapData.new()
	map.id = &"town"
	map.display_name = "Tantegel Town"
	map.width = w
	map.height = h
	map.tiles = tiles
	map.elevation = _blank(w, h, 0)
	map.encounter_rate = 0
	map.default_spawn = Vector2i(16, 20)

	var warps: Array[WarpPoint] = []
	warps.append(_warp(Vector2i(16, h - 1), "field", Vector2i(20, 23)))
	map.warps = warps

	var npcs: Array[NpcPlacement] = []
	npcs.append(_npc("shop_weapon", Vector2i(6, 9), "shop_weapon"))
	npcs.append(_npc("shop_armor", Vector2i(21, 9), "shop_armor"))
	npcs.append(_npc("shop_item", Vector2i(6, 18), "shop_item"))
	npcs.append(_npc("inn", Vector2i(21, 18), "inn"))
	npcs.append(_npc("king", Vector2i(16, 2), "king"))
	npcs.append(_npc("villager_a", Vector2i(13, 11), "villager"))
	npcs.append(_npc("villager_b", Vector2i(26, 12), "villager"))
	map.npcs = npcs
	return map


func _build_field() -> MapData:
	var w := 48
	var h := 36
	var tiles := _blank(w, h, Terrain.Type.GRASS)
	# Ocean border, two tiles thick.
	_rect(tiles, w, 0, 0, w - 1, 1, Terrain.Type.WATER)
	_rect(tiles, w, 0, h - 2, w - 1, h - 1, Terrain.Type.WATER)
	_rect(tiles, w, 0, 0, 1, h - 1, Terrain.Type.WATER)
	_rect(tiles, w, w - 2, 0, w - 1, h - 1, Terrain.Type.WATER)

	_rect(tiles, w, 6, 6, 14, 12, Terrain.Type.FOREST)
	_rect(tiles, w, 30, 20, 40, 28, Terrain.Type.FOREST)
	_rect(tiles, w, 24, 4, 32, 10, Terrain.Type.HILL)
	_rect(tiles, w, 8, 24, 16, 30, Terrain.Type.HILL)
	_rect(tiles, w, 18, 14, 23, 18, Terrain.Type.SWAMP)
	_rect(tiles, w, 26, 14, 31, 19, Terrain.Type.WATER)

	tiles[22 * w + 20] = Terrain.Type.TOWN
	tiles[10 * w + 36] = Terrain.Type.CAVE

	var map := MapData.new()
	map.id = &"field"
	map.display_name = "Alefgard"
	map.width = w
	map.height = h
	map.tiles = tiles
	map.elevation = _blank(w, h, 0)
	map.encounter_table_id = &"et_field"
	map.encounter_rate = 18
	map.default_spawn = Vector2i(20, 23)

	var warps: Array[WarpPoint] = []
	warps.append(_warp(Vector2i(20, 22), "town", Vector2i(16, 22)))
	warps.append(_warp(Vector2i(36, 10), "dungeon", Vector2i(5, 5)))
	map.warps = warps
	return map


func _build_dungeon() -> MapData:
	var w := 32
	var h := 24
	var tiles := _blank(w, h, Terrain.Type.WALL)
	# Four rooms...
	_rect(tiles, w, 2, 2, 8, 8, Terrain.Type.FLOOR)
	_rect(tiles, w, 20, 2, 29, 9, Terrain.Type.FLOOR)
	_rect(tiles, w, 3, 14, 11, 21, Terrain.Type.FLOOR)
	_rect(tiles, w, 20, 13, 29, 21, Terrain.Type.FLOOR)
	# ...joined in a ring, so no room is a dead end.
	_rect(tiles, w, 8, 5, 20, 5, Terrain.Type.FLOOR)
	_rect(tiles, w, 5, 8, 5, 14, Terrain.Type.FLOOR)
	_rect(tiles, w, 11, 17, 20, 17, Terrain.Type.FLOOR)
	_rect(tiles, w, 24, 9, 24, 13, Terrain.Type.FLOOR)
	# Way out.
	tiles[4 * w + 4] = Terrain.Type.STAIRS_UP

	var map := MapData.new()
	map.id = &"dungeon"
	map.display_name = "Erdrick's Cave"
	map.width = w
	map.height = h
	map.tiles = tiles
	map.elevation = _blank(w, h, 0)
	map.encounter_table_id = &"et_dungeon"
	map.encounter_rate = 26
	map.is_dungeon = true
	map.base_sight_radius = 3
	map.default_spawn = Vector2i(5, 5)

	var warps: Array[WarpPoint] = []
	warps.append(_warp(Vector2i(4, 4), "field", Vector2i(36, 11)))
	map.warps = warps
	return map


# --- 타일셋 ---------------------------------------------------------------

func _build_tileset() -> void:
	var texture: Texture2D = load("res://view_2d/field/terrain_tiles.png")
	if texture == null:
		printerr("[build] terrain_tiles.png missing. Run build_tiles.gd then --import.")
		quit(1)
		return

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for index in Terrain.Type.size():
		source.create_tile(Vector2i(index, 0))

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tileset.add_source(source, 0)
	_save(tileset, "res://view_2d/field/terrain_tileset.tres")
