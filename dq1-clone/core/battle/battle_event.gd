## One thing that happened during a battle turn.
##
## core/ resolves a whole turn synchronously and returns a list of these. The
## view replays them at its own pace. That is what lets the same battle run a
## thousand times in a headless simulation with no animation in the way.
class_name BattleEvent
extends RefCounted

enum Kind {
	BATTLE_START,
	MONSTER_FIRST,
	ATTACK,
	CRITICAL,
	DAMAGE,
	NO_DAMAGE,
	SPELL_CAST,
	SPELL_SEALED,
	SPELL_RESISTED,
	SPELL_UNAVAILABLE,
	NOT_ENOUGH_MP,
	HEAL,
	SLEEP_APPLIED,
	SLEEP_SKIP,
	SLEEP_WAKE,
	STOPSPELL_APPLIED,
	ITEM_USED,
	ITEM_UNAVAILABLE,
	FLEE_SUCCESS,
	FLEE_BLOCKED,
	FLEE_FAIL,
	MONSTER_TRANSFORMED,
	MONSTER_DEFEATED,
	HERO_DEFEATED,
	EXP_GAINED,
	GOLD_GAINED,
	LEVEL_UP,
	SPELL_LEARNED,
}

var kind: Kind
## True when the hero caused this event, false when the monster did.
var by_hero: bool
var amount: int
var label: String


func _init(p_kind: Kind, p_by_hero: bool = true, p_amount: int = 0, p_label: String = "") -> void:
	kind = p_kind
	by_hero = p_by_hero
	amount = p_amount
	label = p_label


func _to_string() -> String:
	var who := "hero" if by_hero else "monster"
	var out := "%s[%s]" % [Kind.keys()[kind], who]
	if amount != 0:
		out += " %d" % amount
	if label != "":
		out += " %s" % label
	return out
