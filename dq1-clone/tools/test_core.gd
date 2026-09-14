## Behavioural tests for core/. No editor, no rendering.
##
##   godot --headless --path . --script res://tools/test_core.gd
##
## The determinism test is the load-bearing one: if a battle is not perfectly
## reproducible from its seed, balance simulation and bug reproduction both stop
## being trustworthy.
extends SceneTree

var _failures: Array[String] = []
var _checks := 0
var _db: GameDatabase


func _initialize() -> void:
	_db = GameDatabase.load_default()
	if _db == null:
		printerr("[test] cannot load database")
		quit(1)
		return

	_test_rng_determinism()
	_test_battle_determinism()
	_test_formula_bounds()
	_test_progression()
	_test_level_stats_match_curve()
	_test_boss_rules()
	_test_sleep()
	_test_stopspell()
	_test_movement()
	_test_swamp_damage()
	_test_encounters()
	_test_repel()
	_test_map_round_trip()
	_test_death()
	_test_battle_text()

	print("[test] %d checks, %d failures" % [_checks, _failures.size()])
	for failure in _failures:
		printerr("  FAIL  %s" % failure)
	quit(1 if _failures.size() > 0 else 0)


func _test_battle_text() -> void:
	var monster_cast := BattleEvent.new(BattleEvent.Kind.SPELL_CAST, false, 0, "Hurt")
	var line := BattleText.describe(monster_cast, "You", "Magician")
	_check(line == "Magician casts Hurt!", "monster spell line reads: %s" % line)

	var hero_cast := BattleEvent.new(BattleEvent.Kind.SPELL_CAST, true, 0, "Hurt")
	_check(BattleText.describe(hero_cast, "You", "Magician") == "You cast Hurt!",
			"hero spell line reads: %s" % BattleText.describe(hero_cast, "You", "Magician"))

	# Damage names the target, which is the side that did NOT act.
	var hero_hits := BattleEvent.new(BattleEvent.Kind.DAMAGE, true, 4)
	_check(BattleText.describe(hero_hits, "You", "Magician") == "Magician takes 4 damage.",
			"hero damage line reads: %s" % BattleText.describe(hero_hits, "You", "Magician"))
	var monster_hits := BattleEvent.new(BattleEvent.Kind.DAMAGE, false, 11)
	_check(BattleText.describe(monster_hits, "You", "Magician") == "You take 11 damage.",
			"monster damage line reads: %s" % BattleText.describe(monster_hits, "You", "Magician"))

	# Every event kind must produce something; a silent kind is a dropped message.
	var silent: Array[String] = []
	for kind in BattleEvent.Kind.values():
		var event := BattleEvent.new(kind, true, 1, "Thing")
		if BattleText.describe(event, "You", "Slime") == "":
			silent.append(BattleEvent.Kind.keys()[kind])
	_check(silent.is_empty(), "no text for event kinds: %s" % [silent])


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# --- 결정성 ---------------------------------------------------------------

func _test_rng_determinism() -> void:
	var first: Array[int] = []
	var second: Array[int] = []
	var a := Rng.new(12345)
	var b := Rng.new(12345)
	for i in 500:
		first.append(a.range_i(0, 1000))
		second.append(b.range_i(0, 1000))
	_check(first == second, "Rng with the same seed produced different streams")

	var c := Rng.new(999)
	var different := false
	for i in 500:
		if c.range_i(0, 1000) != first[i]:
			different = true
			break
	_check(different, "Rng ignores its seed")


## Same seed + same commands must produce a byte-identical event stream, a
## thousand times over.
func _test_battle_determinism() -> void:
	var reference := _run_scripted_battle(4242)
	var identical := true
	for i in 999:
		if _run_scripted_battle(4242) != reference:
			identical = false
			break
	_check(identical, "battle is not reproducible from its seed")
	_check(_run_scripted_battle(4243) != reference, "battle ignores its seed")
	_check(reference.find("MONSTER_DEFEATED") >= 0 or reference.find("HERO_DEFEATED") >= 0,
			"scripted battle never ended")


func _run_scripted_battle(seed_value: int) -> String:
	var rng := Rng.new(seed_value)
	var hero := Hero.create_new(_db)
	hero.apply_level(_db.level_curve, 5, true)
	var battle := BattleState.new(
			hero.to_battle_actor(_db),
			BattleActor.from_monster(_db.monster(&"m_magician")),
			rng, _db)

	var log: Array[String] = []
	for event in battle.start():
		log.append(str(event))
	var guard := 0
	while not battle.is_over() and guard < 100:
		guard += 1
		for event in battle.resolve_turn(BattleState.Command.ATTACK):
			log.append(str(event))
	return "|".join(log)


# --- 공식 -----------------------------------------------------------------

func _test_formula_bounds() -> void:
	var rng := Rng.new(7)
	var within := true
	for i in 2000:
		var damage := Formulas.physical_damage(40, 10, rng)
		if damage < (30 / 4) or damage > (30 / 2):
			within = false
			break
	_check(within, "physical_damage left the (atk-def)/4..(atk-def)/2 band")

	var weak_ok := true
	for i in 2000:
		var damage := Formulas.physical_damage(12, 40, rng)
		if damage < 0 or damage > (13 / Formulas.WEAK_HIT_DIVISOR):
			weak_ok = false
			break
	_check(weak_ok, "weak-hit branch left its 0..(atk+1)/6 band")

	var crit_ok := true
	for i in 2000:
		var damage := Formulas.critical_damage(50, rng)
		if damage < 25 or damage > 50:
			crit_ok = false
			break
	_check(crit_ok, "critical_damage left the 50%..100% band")

	# 1/32 should land near 3% over a large sample.
	var crits := 0
	for i in 32000:
		if Formulas.rolls_critical(rng):
			crits += 1
	var rate := float(crits) / 32000.0
	_check(rate > 0.020 and rate < 0.045,
			"critical rate %.4f is nowhere near 1/32" % rate)

	_check(Formulas.defense_power(11, 2, 4) == 5 + 2 + 4, "defense_power composition wrong")
	_check(Formulas.monster_defense(9) == 4, "monster_defense should floor agility/2")
	_check(Formulas.apply_hurt_reduction(30, 0.333) == 20, "hurt reduction wrong")
	_check(Formulas.apply_hurt_reduction(30, 0.0) == 30, "hurt reduction with 0 changed damage")


# --- 성장 -----------------------------------------------------------------

func _test_progression() -> void:
	var hero := Hero.create_new(_db)
	_check(hero.level == 1, "new hero is not level 1")

	var result := Progression.award(hero, _db, _db.level_curve.required_exp[0], 10)
	_check(hero.level == 2, "hero did not reach level 2 on the exact threshold")
	_check(result["levels"] == [2], "level-up list wrong: %s" % [result["levels"]])
	_check(hero.gold == _db.start_gold + 10, "gold not awarded")

	# One huge award should cascade through every level at once.
	var jumper := Hero.create_new(_db)
	var big := Progression.award(jumper, _db, 999_999, 0)
	_check(jumper.level == _db.level_curve.max_level(),
			"massive EXP award did not reach max level")
	_check(big["spells"].size() == 10,
			"expected all 10 spells on a full cascade, got %d" % big["spells"].size())
	_check(jumper.total_exp == Progression.max_exp(_db), "total_exp not clamped")

	# Learning happens at the documented levels.
	var walker := Hero.create_new(_db)
	var learned_at := {}
	while walker.level < _db.level_curve.max_level():
		var before := walker.level
		var step := Progression.award(walker, _db, _db.level_curve.exp_to_next(walker.total_exp), 0)
		_check(walker.level > before, "award of exp_to_next did not level up from %d" % before)
		for spell in step["spells"]:
			learned_at[spell.id] = walker.level
	_check(learned_at.get(&"heal") == 3, "Heal not learned at level 3")
	_check(learned_at.get(&"hurtmore") == 19, "Hurtmore not learned at level 19")

	# A level-up grants the HP difference, it does not silently heal.
	var wounded := Hero.create_new(_db)
	wounded.hp = 1
	var before_max := wounded.max_hp
	wounded.apply_level(_db.level_curve, 2)
	_check(wounded.hp == 1 + (wounded.max_hp - before_max),
			"level-up healed the hero instead of granting the delta")


func _test_level_stats_match_curve() -> void:
	var hero := Hero.create_new(_db)
	var matches := true
	for level in range(1, _db.level_curve.max_level() + 1):
		hero.apply_level(_db.level_curve, level, true)
		if hero.strength != _db.level_curve.strength[level - 1] \
				or hero.max_hp != _db.level_curve.max_hp[level - 1]:
			matches = false
			break
	_check(matches, "hero stats drifted from the level curve")


# --- 전투 규칙 ------------------------------------------------------------

func _test_boss_rules() -> void:
	var rng := Rng.new(11)
	var hero := Hero.create_new(_db)
	hero.apply_level(_db.level_curve, 30, true)
	var boss := BattleActor.from_monster(_db.monster(&"m_dragonlord"))
	var battle := BattleState.new(hero.to_battle_actor(_db), boss, rng, _db)
	battle.start()

	var events := battle.resolve_turn(BattleState.Command.FLEE)
	var blocked := false
	for event in events:
		if event.kind == BattleEvent.Kind.FLEE_BLOCKED:
			blocked = true
	_check(blocked, "fleeing from the boss was allowed")
	_check(battle.result != BattleState.Result.HERO_FLED, "hero fled a boss fight")

	# 3000 swings at a boss should never produce a critical.
	var crit_seen := false
	for i in 3000:
		var fresh := BattleState.new(
				hero.to_battle_actor(_db),
				BattleActor.from_monster(_db.monster(&"m_dragonlord")),
				rng, _db)
		for event in fresh.resolve_turn(BattleState.Command.ATTACK):
			if event.kind == BattleEvent.Kind.CRITICAL and event.by_hero:
				crit_seen = true
		if crit_seen:
			break
	_check(not crit_seen, "hero landed a critical on a boss")


func _test_sleep() -> void:
	var rng := Rng.new(3)
	var hero := Hero.create_new(_db)
	hero.apply_level(_db.level_curve, 10, true)
	var actor := hero.to_battle_actor(_db)
	var target := BattleActor.from_monster(_db.monster(&"m_slime"))
	target.max_hp = 9999
	target.hp = 9999
	var battle := BattleState.new(actor, target, rng, _db)

	var applied := false
	var skipped_on_cast_turn := false
	for attempt in 20:
		for event in battle.resolve_turn(BattleState.Command.SPELL, &"sleep"):
			if event.kind == BattleEvent.Kind.SLEEP_APPLIED:
				applied = true
			if applied and event.kind == BattleEvent.Kind.SLEEP_SKIP and not event.by_hero:
				skipped_on_cast_turn = true
		if applied:
			break
	_check(applied, "Sleep never landed on a zero-resistance monster in 20 tries")
	_check(target.asleep, "monster is not marked asleep after SLEEP_APPLIED")
	_check(skipped_on_cast_turn, "monster still acted on the turn Sleep landed")

	# And it cannot act on the following turn either: it is still asleep, or it
	# spends that turn waking up. Either way the hero swings for free.
	var acted := false
	for event in battle.resolve_turn(BattleState.Command.ATTACK):
		if event.by_hero:
			continue
		if event.kind == BattleEvent.Kind.ATTACK \
				or event.kind == BattleEvent.Kind.CRITICAL \
				or event.kind == BattleEvent.Kind.SPELL_CAST:
			acted = true
	_check(not acted, "a sleeping monster acted on the turn after Sleep landed")

	var immune := BattleActor.from_monster(_db.monster(&"m_dragonlord"))
	_check(not Formulas.status_lands(immune.resist_sleep, rng),
			"a 255-resistance target was put to sleep")


func _test_stopspell() -> void:
	var rng := Rng.new(5)
	var hero := Hero.create_new(_db)
	hero.apply_level(_db.level_curve, 12, true)
	var caster := BattleActor.from_monster(_db.monster(&"m_magician"))
	caster.max_hp = 9999
	caster.hp = 9999
	caster.spell_sealed = true

	var battle := BattleState.new(hero.to_battle_actor(_db), caster, rng, _db)
	var cast_seen := false
	for turn in 40:
		for event in battle.resolve_turn(BattleState.Command.ATTACK):
			if event.kind == BattleEvent.Kind.SPELL_CAST and not event.by_hero:
				cast_seen = true
		if battle.is_over():
			break
	_check(not cast_seen, "a silenced monster still cast a spell")
	_check(caster.mp == caster.max_mp, "a silenced monster spent MP")


# --- 필드 -----------------------------------------------------------------

func _new_session(seed_value: int = 1) -> GameSession:
	var session := GameSession.create_new(seed_value, _db)
	session.world.encounters_enabled = false
	return session


func _test_movement() -> void:
	var session := _new_session()
	_check(session.world.map.id == &"town", "new game does not start in town")

	var start := session.world.cell
	_check(session.try_move(Vector2i.UP), "could not walk north from the town spawn")
	_check(session.world.cell == start + Vector2i.UP, "cell did not follow the move")
	_check(session.world.steps == 1, "step counter did not advance")

	# Walk into the town's west wall.
	session.world.cell = Vector2i(1, 8)
	var blocked := not session.try_move(Vector2i.LEFT)
	_check(blocked, "walked through a wall")
	_check(session.world.cell == Vector2i(1, 8), "position changed on a blocked move")

	# And into the ocean.
	session.world.enter_map(&"field", Vector2i(2, 8))
	_check(not session.try_move(Vector2i.LEFT), "walked into the sea")


func _test_swamp_damage() -> void:
	var session := _new_session()
	session.world.enter_map(&"field", Vector2i(18, 13))
	session.hero.hp = session.hero.max_hp
	var before := session.hero.hp
	_check(session.try_move(Vector2i.DOWN), "could not step into the swamp")
	_check(session.world.terrain_here() == Terrain.Type.SWAMP, "test did not land on swamp")
	_check(session.hero.hp == before - Terrain.SWAMP_DAMAGE,
			"swamp dealt %d damage, expected %d"
			% [before - session.hero.hp, Terrain.SWAMP_DAMAGE])

	# Plate armour cancels it.
	session.hero.armor_id = &"a_plate"
	session.world.enter_map(&"field", Vector2i(19, 13))
	before = session.hero.hp
	session.try_move(Vector2i.DOWN)
	_check(session.hero.hp == before, "plate armour did not block swamp damage")


func _test_encounters() -> void:
	var session := _new_session(77)
	session.world.encounters_enabled = true
	var field := _db.map(&"field")
	var saved_rate := field.encounter_rate
	field.encounter_rate = 200

	var seen: Array[StringName] = []
	session.encounter_started.connect(func(id: StringName) -> void: seen.append(id))
	session.world.enter_map(&"field", Vector2i(20, 23))
	for i in 400:
		session.world.cell = Vector2i(20, 23)
		session.try_move(Vector2i.RIGHT)
	field.encounter_rate = saved_rate

	_check(seen.size() > 0, "no encounter in 400 steps at rate 200")
	var table := _db.encounter_table(&"et_field")
	var allowed := {}
	for entry in table.entries:
		allowed[entry.monster_id] = true
	var all_allowed := true
	for id in seen:
		if not allowed.has(id):
			all_allowed = false
			break
	_check(all_allowed, "an encounter produced a monster outside et_field")

	# Town is safe.
	var town_session := _new_session(9)
	town_session.world.encounters_enabled = true
	var town_encounters := 0
	town_session.encounter_started.connect(func(_id: StringName) -> void: town_encounters += 1)
	for i in 300:
		town_session.try_move(Vector2i.UP if i % 2 == 0 else Vector2i.DOWN)
	_check(town_encounters == 0, "monsters attacked inside the town")


func _test_repel() -> void:
	var rng := Rng.new(2)
	var table := _db.encounter_table(&"et_field")
	# et_field tops out at tier 5; a level-30 hero repels tiers up to 6.
	_check(EncounterResolver.repel_tier_ceiling(30) >= 5,
			"repel ceiling at level 30 does not cover the field table")
	_check(EncounterResolver.pick(table, rng, true, 30) == &"",
			"Repel did not suppress every weak monster")
	_check(EncounterResolver.pick(table, rng, false, 30) != &"",
			"picking without Repel returned nothing")
	_check(EncounterResolver.pick(table, rng, true, 1) != &"",
			"Repel at level 1 suppressed everything")


func _test_map_round_trip() -> void:
	var session := _new_session()
	var legs := [
		[&"town", Vector2i(16, 23), &"field", Vector2i(20, 23)],
		[&"field", Vector2i(36, 10), &"dungeon", Vector2i(5, 5)],
		[&"dungeon", Vector2i(4, 4), &"field", Vector2i(36, 11)],
		[&"field", Vector2i(20, 22), &"town", Vector2i(16, 22)],
	]

	for leg in legs:
		var from_map: StringName = leg[0]
		var goal: Vector2i = leg[1]
		var to_map: StringName = leg[2]
		var arrival: Vector2i = leg[3]

		_check(session.world.map.id == from_map,
				"expected to be on %s, was on %s" % [from_map, session.world.map.id])
		var path := _path_to(session.world.map, session.world.cell, goal)
		_check(not path.is_empty(), "no walkable path on %s to %v" % [from_map, goal])
		for cell in path:
			session.try_move(cell - session.world.cell)
		_check(session.world.map.id == to_map,
				"stepping on %v did not warp to %s (now on %s)"
				% [goal, to_map, session.world.map.id])
		_check(session.world.cell == arrival,
				"warp landed on %v, expected %v" % [session.world.cell, arrival])


## Breadth-first path, excluding the start and including the goal.
func _path_to(map: MapData, from: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var came_from := {from: from}
	var queue: Array[Vector2i] = [from]
	var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var found := false

	while not queue.is_empty() and not found:
		var cell: Vector2i = queue.pop_front()
		for direction in directions:
			var next: Vector2i = cell + direction
			if came_from.has(next):
				continue
			var terrain := map.tile_at(next)
			if terrain < 0 or not Terrain.is_passable(terrain):
				continue
			came_from[next] = cell
			if next == goal:
				found = true
				break
			queue.append(next)

	var path: Array[Vector2i] = []
	if not came_from.has(goal):
		return path
	var cursor := goal
	while cursor != from:
		path.push_front(cursor)
		cursor = came_from[cursor]
	return path


func _test_death() -> void:
	var session := _new_session()
	session.hero.gold = 500
	session.world.enter_map(&"field", Vector2i(20, 23))
	session.hero.hp = 0
	var lost := session.respawn()
	_check(lost == 250, "death took %d gold, expected half of 500" % lost)
	_check(session.hero.gold == 250, "gold after death is %d" % session.hero.gold)
	_check(session.hero.hp == session.hero.max_hp, "respawn did not restore HP")
	_check(session.world.map.id == _db.start_map, "respawn did not return to the save point")
