## Turns core's BattleEvent stream into player-facing lines.
##
## All wording lives here; core only emits enum kinds, numbers and ids. That is
## what makes the game translatable without touching a line of core/ — the
## event says SPELL_CAST with the id `heal`, and this decides whether the
## player reads "You cast Heal!" or "그대는 호이미를 외웠다!".
class_name BattleText
extends RefCounted


## `monster_name` is already translated by the caller, which knows which of a
## boss's forms is on screen right now.
static func describe(event: BattleEvent, monster_name: String,
		db: GameDatabase = null) -> String:
	var actor_is_hero := event.by_hero
	var target_is_hero := not event.by_hero

	match event.kind:
		BattleEvent.Kind.BATTLE_START:
			return Loc.t("BT_BATTLE_START", {"monster": monster_name})
		BattleEvent.Kind.MONSTER_FIRST:
			return Loc.t("BT_MONSTER_FIRST", {"monster": monster_name})
		BattleEvent.Kind.ATTACK:
			return _side("BT_ATTACK", actor_is_hero, {"actor": monster_name})
		BattleEvent.Kind.CRITICAL:
			return _side("BT_CRITICAL", actor_is_hero, {"actor": monster_name})
		BattleEvent.Kind.DAMAGE:
			return _side("BT_DAMAGE", target_is_hero,
					{"target": monster_name, "amount": event.amount})
		BattleEvent.Kind.NO_DAMAGE:
			return _side("BT_NO_DAMAGE", target_is_hero, {"target": monster_name})
		BattleEvent.Kind.SPELL_CAST:
			return _side("BT_SPELL", actor_is_hero,
					{"actor": monster_name, "spell": _spell(db, event.subject)})
		BattleEvent.Kind.SPELL_SEALED:
			return _side("BT_SPELL_SEALED", actor_is_hero, {"actor": monster_name})
		BattleEvent.Kind.SPELL_RESISTED:
			return _side("BT_RESISTED", target_is_hero, {"target": monster_name})
		BattleEvent.Kind.SPELL_UNAVAILABLE:
			return Loc.t("BT_SPELL_UNAVAILABLE")
		BattleEvent.Kind.NOT_ENOUGH_MP:
			return Loc.t("BT_NOT_ENOUGH_MP")
		BattleEvent.Kind.HEAL:
			return _side("BT_HEAL", actor_is_hero,
					{"actor": monster_name, "amount": event.amount})
		BattleEvent.Kind.SLEEP_APPLIED:
			return _side("BT_SLEEP_APPLIED", target_is_hero, {"target": monster_name})
		BattleEvent.Kind.SLEEP_SKIP:
			return _side("BT_SLEEP_SKIP", actor_is_hero, {"actor": monster_name})
		BattleEvent.Kind.SLEEP_WAKE:
			return _side("BT_SLEEP_WAKE", actor_is_hero, {"actor": monster_name})
		BattleEvent.Kind.STOPSPELL_APPLIED:
			return _side("BT_STOPSPELL", target_is_hero, {"target": monster_name})
		BattleEvent.Kind.ITEM_USED:
			return _side("BT_ITEM_USED", actor_is_hero, {
				"actor": monster_name,
				"item": _item(db, event.subject),
				"amount": event.amount,
			})
		BattleEvent.Kind.ITEM_UNAVAILABLE:
			return Loc.t("BT_ITEM_UNAVAILABLE")
		BattleEvent.Kind.ITEM_NO_EFFECT:
			return _side("BT_ITEM_NO_EFFECT", actor_is_hero,
					{"actor": monster_name, "item": _item(db, event.subject)})
		BattleEvent.Kind.FLEE_SUCCESS:
			return _side("BT_FLEE_SUCCESS", actor_is_hero, {"actor": monster_name})
		BattleEvent.Kind.FLEE_BLOCKED:
			return Loc.t("BT_FLEE_BLOCKED")
		BattleEvent.Kind.FLEE_FAIL:
			return _side("BT_FLEE_FAIL", actor_is_hero, {"actor": monster_name})
		BattleEvent.Kind.MONSTER_TRANSFORMED:
			return Loc.t("BT_TRANSFORMED", {"monster": _monster(db, event.subject)})
		BattleEvent.Kind.MONSTER_DEFEATED:
			return _side("BT_DEFEATED", false, {"target": _monster(db, event.subject)})
		BattleEvent.Kind.HERO_DEFEATED:
			return _side("BT_DEFEATED", true, {})
		BattleEvent.Kind.EXP_GAINED:
			return Loc.t("BT_EXP", {"amount": event.amount})
		BattleEvent.Kind.GOLD_GAINED:
			return Loc.t("BT_GOLD", {"amount": event.amount})
		BattleEvent.Kind.LEVEL_UP:
			return Loc.t("BT_LEVEL_UP", {"amount": event.amount})
		BattleEvent.Kind.SPELL_LEARNED:
			return Loc.t("BT_SPELL_LEARNED", {"spell": _spell(db, event.subject)})
		_:
			return ""


## English conjugates for the hero ("You attack") and against the monster
## ("the Slime attacks"); Korean puts the difference in the subject instead.
## Either way the two readings are two keys, so a translator never has to
## reproduce another language's grammar.
static func _side(base: String, is_hero: bool, args: Dictionary) -> String:
	return Loc.t(base + ("_YOU" if is_hero else "_IT"), args)


static func _spell(db: GameDatabase, id: StringName) -> String:
	return Loc.spell_name(db.spell(id)) if db != null else String(id)


static func _item(db: GameDatabase, id: StringName) -> String:
	return Loc.item_name(db.item(id)) if db != null else String(id)


static func _monster(db: GameDatabase, id: StringName) -> String:
	return Loc.monster_name(db.monster(id)) if db != null else String(id)
