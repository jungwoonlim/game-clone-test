## Turns core's BattleEvent stream into player-facing lines.
##
## All wording lives here; core only emits enum kinds and numbers. Localisation
## later means touching this file and nothing in core/.
class_name BattleText
extends RefCounted


static func describe(event: BattleEvent, hero_name: String, monster_name: String) -> String:
	# `by_hero` says who acted; the target is whoever did not.
	var actor_is_hero := event.by_hero
	var target_is_hero := not event.by_hero
	var actor := _subject(actor_is_hero, hero_name, monster_name)
	var target := _subject(target_is_hero, hero_name, monster_name)

	match event.kind:
		BattleEvent.Kind.BATTLE_START:
			return "A %s draws near!" % event.label
		BattleEvent.Kind.MONSTER_FIRST:
			return "%s strikes first!" % monster_name
		BattleEvent.Kind.ATTACK:
			return "%s %s!" % [actor, _verb(actor_is_hero, "attack", "attacks")]
		BattleEvent.Kind.CRITICAL:
			return "%s %s an excellent blow!" % [actor, _verb(actor_is_hero, "land", "lands")]
		BattleEvent.Kind.DAMAGE:
			return "%s %s %d damage." % [target, _verb(target_is_hero, "take", "takes"), event.amount]
		BattleEvent.Kind.NO_DAMAGE:
			return "%s %s unharmed." % [target, _verb(target_is_hero, "are", "is")]
		BattleEvent.Kind.SPELL_CAST:
			return "%s %s %s!" % [actor, _verb(actor_is_hero, "cast", "casts"), event.label]
		BattleEvent.Kind.SPELL_SEALED:
			return "%s magic is sealed." % _possessive(actor_is_hero, monster_name)
		BattleEvent.Kind.SPELL_RESISTED:
			return "%s %s." % [target, _verb(target_is_hero, "resist", "resists")]
		BattleEvent.Kind.SPELL_UNAVAILABLE:
			return "Nothing happens."
		BattleEvent.Kind.NOT_ENOUGH_MP:
			return "Not enough MP."
		BattleEvent.Kind.HEAL:
			return "%s %s %d HP." % [actor, _verb(actor_is_hero, "recover", "recovers"), event.amount]
		BattleEvent.Kind.SLEEP_APPLIED:
			return "%s %s asleep." % [target, _verb(target_is_hero, "fall", "falls")]
		BattleEvent.Kind.SLEEP_SKIP:
			return "%s %s asleep." % [actor, _verb(actor_is_hero, "are", "is")]
		BattleEvent.Kind.SLEEP_WAKE:
			return "%s %s up." % [actor, _verb(actor_is_hero, "wake", "wakes")]
		BattleEvent.Kind.STOPSPELL_APPLIED:
			return "%s magic is blocked!" % _possessive(target_is_hero, monster_name)
		BattleEvent.Kind.ITEM_USED:
			return "%s %s %s. +%d HP." % [
				actor, _verb(actor_is_hero, "use", "uses"), event.label, event.amount]
		BattleEvent.Kind.ITEM_UNAVAILABLE:
			return "Nothing to use."
		BattleEvent.Kind.FLEE_SUCCESS:
			return "%s %s!" % [actor, _verb(actor_is_hero, "flee", "flees")]
		BattleEvent.Kind.FLEE_BLOCKED:
			return "There is no escape!"
		BattleEvent.Kind.FLEE_FAIL:
			return "%s cannot escape!" % actor
		BattleEvent.Kind.MONSTER_DEFEATED:
			return "%s is defeated!" % event.label
		BattleEvent.Kind.HERO_DEFEATED:
			return "%s have fallen..." % hero_name
		BattleEvent.Kind.EXP_GAINED:
			return "%d experience gained." % event.amount
		BattleEvent.Kind.GOLD_GAINED:
			return "%d gold gained." % event.amount
		BattleEvent.Kind.LEVEL_UP:
			return "Level %d!" % event.amount
		BattleEvent.Kind.SPELL_LEARNED:
			return "Learned %s!" % event.label
		_:
			return ""


static func _subject(is_hero: bool, hero_name: String, monster_name: String) -> String:
	return hero_name if is_hero else monster_name


static func _possessive(is_hero: bool, monster_name: String) -> String:
	return "Your" if is_hero else "%s's" % monster_name


## "You attack" but "the Slime attacks".
static func _verb(is_hero: bool, second_person: String, third_person: String) -> String:
	return second_person if is_hero else third_person
