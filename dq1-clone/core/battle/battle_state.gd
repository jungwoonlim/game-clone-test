## One 1-on-1 battle, resolved as pure logic.
##
## Knows nothing about scenes, animation or input. A turn is resolved
## immediately and returns the list of events that happened; the caller decides
## whether to draw them over two seconds or throw them away.
class_name BattleState
extends RefCounted

enum Command { ATTACK, SPELL, ITEM, FLEE }
enum Result { ONGOING, HERO_WON, HERO_DIED, HERO_FLED }

var hero: BattleActor
var monster: BattleActor
var result: Result = Result.ONGOING
var turn: int = 0

## Filled in when the hero wins. The caller applies them to the Hero.
var exp_reward: int = 0
var gold_reward: int = 0

var _rng: Rng
var _db: GameDatabase


func _init(p_hero: BattleActor, p_monster: BattleActor, p_rng: Rng, p_db: GameDatabase) -> void:
	hero = p_hero
	monster = p_monster
	_rng = p_rng
	_db = p_db


func is_over() -> bool:
	return result != Result.ONGOING


## Must be called once before the first resolve_turn(). The monster may get a
## free action here if it wins initiative.
func start() -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	events.append(BattleEvent.new(BattleEvent.Kind.BATTLE_START, false, 0, monster.display_name))
	if Formulas.monster_acts_first(hero.agility, monster.agility, _rng):
		events.append(BattleEvent.new(BattleEvent.Kind.MONSTER_FIRST, false))
		_take_monster_turn(events)
		_check_end(events)
	return events


## `argument` is a spell id for Command.SPELL and an item id for Command.ITEM.
func resolve_turn(command: Command, argument: StringName = &"") -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if is_over():
		return events
	turn += 1

	_take_hero_turn(command, argument, events)
	if result == Result.HERO_FLED:
		return events
	if _check_end(events):
		return events

	_take_monster_turn(events)
	_check_end(events)
	return events


# --- 턴 ------------------------------------------------------------------

func _take_hero_turn(command: Command, argument: StringName, events: Array[BattleEvent]) -> void:
	if _handle_sleep(hero, events):
		return

	match command:
		Command.ATTACK:
			_do_attack(hero, monster, events)
		Command.SPELL:
			_do_spell(hero, monster, argument, events)
		Command.ITEM:
			_do_item(argument, events)
		Command.FLEE:
			_do_flee(events)


func _take_monster_turn(events: Array[BattleEvent]) -> void:
	if not monster.is_alive() or is_over():
		return
	if _handle_sleep(monster, events):
		return

	var action := _choose_monster_action()
	if action == null or action.kind == "attack":
		_do_attack(monster, hero, events)
		return
	if action.kind == "spell":
		_do_spell(monster, hero, action.spell_id, events)
		return
	if action.kind == "flee":
		events.append(BattleEvent.new(BattleEvent.Kind.FLEE_SUCCESS, false))
		result = Result.HERO_WON
		exp_reward = 0
		gold_reward = 0


## Picks among the actions that are eligible right now. Spell actions drop out
## while the monster is silenced, which is the whole point of Stopspell.
func _choose_monster_action() -> MonsterAction:
	if monster.monster == null or monster.monster.actions.is_empty():
		return null

	var ratio := monster.hp_ratio()
	var candidates: Array[MonsterAction] = []
	var weights: Array[int] = []
	for action in monster.monster.actions:
		if ratio > action.hp_threshold:
			continue
		if action.kind == "spell":
			if monster.spell_sealed:
				continue
			var spell := _db.spell(action.spell_id)
			if spell == null or monster.mp < spell.mp_cost:
				continue
		candidates.append(action)
		weights.append(action.weight)

	var index := _rng.pick_weighted(weights)
	if index < 0:
		return null
	return candidates[index]


## Returns true when the actor loses its turn to sleep.
func _handle_sleep(actor: BattleActor, events: Array[BattleEvent]) -> bool:
	if not actor.asleep:
		return false
	if actor.sleep_guaranteed_left > 0:
		actor.sleep_guaranteed_left -= 1
		events.append(BattleEvent.new(BattleEvent.Kind.SLEEP_SKIP, actor.is_hero))
		return true
	if Formulas.wakes_from_sleep(_rng):
		actor.asleep = false
		events.append(BattleEvent.new(BattleEvent.Kind.SLEEP_WAKE, actor.is_hero))
		return true
	events.append(BattleEvent.new(BattleEvent.Kind.SLEEP_SKIP, actor.is_hero))
	return true


# --- 행동 ----------------------------------------------------------------

func _do_attack(attacker: BattleActor, defender: BattleActor, events: Array[BattleEvent]) -> void:
	# Only the hero lands critical hits, and never against a boss.
	var critical := attacker.is_hero and defender.can_be_critical \
			and Formulas.rolls_critical(_rng)

	var damage := 0
	if critical:
		damage = Formulas.critical_damage(attacker.attack_power, _rng)
		events.append(BattleEvent.new(BattleEvent.Kind.CRITICAL, attacker.is_hero))
	else:
		damage = Formulas.physical_damage(
				attacker.attack_power, defender.defense_power, _rng)
		events.append(BattleEvent.new(BattleEvent.Kind.ATTACK, attacker.is_hero))

	var dealt := defender.take_damage(damage)
	if dealt > 0:
		events.append(BattleEvent.new(BattleEvent.Kind.DAMAGE, attacker.is_hero, dealt))
	else:
		events.append(BattleEvent.new(BattleEvent.Kind.NO_DAMAGE, attacker.is_hero))


func _do_spell(caster: BattleActor, target: BattleActor, spell_id: StringName,
		events: Array[BattleEvent]) -> void:
	var spell := _db.spell(spell_id)
	if spell == null or not spell.usable_in_battle:
		events.append(BattleEvent.new(BattleEvent.Kind.SPELL_UNAVAILABLE, caster.is_hero))
		return
	if caster.is_hero and not caster.knows_spell(spell_id):
		events.append(BattleEvent.new(BattleEvent.Kind.SPELL_UNAVAILABLE, true, 0, spell.display_name))
		return
	if caster.spell_sealed:
		events.append(BattleEvent.new(BattleEvent.Kind.SPELL_SEALED, caster.is_hero, 0, spell.display_name))
		return
	if caster.mp < spell.mp_cost:
		events.append(BattleEvent.new(BattleEvent.Kind.NOT_ENOUGH_MP, caster.is_hero, 0, spell.display_name))
		return

	caster.mp -= spell.mp_cost
	events.append(BattleEvent.new(BattleEvent.Kind.SPELL_CAST, caster.is_hero, 0, spell.display_name))

	match spell.kind:
		"damage":
			var raw := Formulas.spell_power(spell, caster.is_hero, _rng)
			var reduced := Formulas.apply_hurt_reduction(raw, target.hurt_reduction)
			var dealt := target.take_damage(reduced)
			if dealt > 0:
				events.append(BattleEvent.new(BattleEvent.Kind.DAMAGE, caster.is_hero, dealt))
			else:
				events.append(BattleEvent.new(BattleEvent.Kind.NO_DAMAGE, caster.is_hero))
		"heal":
			var healed := caster.restore_hp(Formulas.spell_power(spell, caster.is_hero, _rng))
			events.append(BattleEvent.new(BattleEvent.Kind.HEAL, caster.is_hero, healed))
		"sleep":
			if target.asleep:
				events.append(BattleEvent.new(BattleEvent.Kind.SPELL_RESISTED, caster.is_hero))
			elif Formulas.status_lands(target.resist_sleep, _rng):
				target.apply_sleep()
				events.append(BattleEvent.new(BattleEvent.Kind.SLEEP_APPLIED, caster.is_hero))
			else:
				events.append(BattleEvent.new(BattleEvent.Kind.SPELL_RESISTED, caster.is_hero))
		"stopspell":
			if target.spell_sealed:
				events.append(BattleEvent.new(BattleEvent.Kind.SPELL_RESISTED, caster.is_hero))
			elif Formulas.status_lands(target.resist_stopspell, _rng):
				target.spell_sealed = true
				events.append(BattleEvent.new(BattleEvent.Kind.STOPSPELL_APPLIED, caster.is_hero))
			else:
				events.append(BattleEvent.new(BattleEvent.Kind.SPELL_RESISTED, caster.is_hero))
		_:
			events.append(BattleEvent.new(BattleEvent.Kind.SPELL_UNAVAILABLE, caster.is_hero))


func _do_item(item_id: StringName, events: Array[BattleEvent]) -> void:
	var item := _db.item(item_id)
	if item == null or item.kind != "consumable" or item.effect_id != &"heal_hp":
		events.append(BattleEvent.new(BattleEvent.Kind.ITEM_UNAVAILABLE, true))
		return
	var healed := hero.restore_hp(item.effect_power)
	events.append(BattleEvent.new(BattleEvent.Kind.ITEM_USED, true, healed, item.display_name))


func _do_flee(events: Array[BattleEvent]) -> void:
	if not monster.can_flee_from:
		events.append(BattleEvent.new(BattleEvent.Kind.FLEE_BLOCKED, true))
		return
	if Formulas.flee_succeeds(hero.agility, monster.agility, _rng):
		events.append(BattleEvent.new(BattleEvent.Kind.FLEE_SUCCESS, true))
		result = Result.HERO_FLED
		return
	events.append(BattleEvent.new(BattleEvent.Kind.FLEE_FAIL, true))


# --- 종료 판정 -----------------------------------------------------------

func _check_end(events: Array[BattleEvent]) -> bool:
	if not monster.is_alive():
		events.append(BattleEvent.new(BattleEvent.Kind.MONSTER_DEFEATED, true, 0, monster.display_name))
		result = Result.HERO_WON
		if monster.monster != null:
			exp_reward = monster.monster.exp_reward
			gold_reward = Formulas.gold_reward(monster.monster, _rng)
		events.append(BattleEvent.new(BattleEvent.Kind.EXP_GAINED, true, exp_reward))
		events.append(BattleEvent.new(BattleEvent.Kind.GOLD_GAINED, true, gold_reward))
		return true
	if not hero.is_alive():
		events.append(BattleEvent.new(BattleEvent.Kind.HERO_DEFEATED, false))
		result = Result.HERO_DIED
		return true
	return false
