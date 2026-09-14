## Every combat formula and constant in the game lives here.
##
## The original's numbers disagree between sources (see docs/06-VERIFICATION.md).
## Keeping them in one file with no logic anywhere else means correcting a
## value later is a one-line edit, not a refactor.
##
## Label legend — OK: sources agree. PICKED: sources conflicted, choice recorded
## in docs/06. GUESS: unverified placeholder.
class_name Formulas
extends RefCounted

# --- 통상 공격 ---
## Damage spread is (atk-def)/4 .. (atk-def)/2.                          [OK]
const DAMAGE_DIVISOR_MIN := 4
const DAMAGE_DIVISOR_MAX := 2
## When attack power does not exceed defence, damage is 0..(atk+1)/6.  [PICKED]
const WEAK_HIT_DIVISOR := 6

# --- 회심의 일격 ---
## Flat 1/32, ignores defence, deals 50%..100% of attack power.        [PICKED]
const CRIT_NUMERATOR := 1
const CRIT_DENOMINATOR := 32

# --- 선공 판정 ---
const INITIATIVE_HERO_DIVISOR := 2                                   # [PICKED]

# --- 도망 ---
const FLEE_BASE := 192                                                # [GUESS]
const FLEE_AGILITY_DIVISOR := 4                                       # [GUESS]
const FLEE_MIN := 64
const FLEE_MAX := 224

# --- 수면 ---
## Turns lost before wake rolls start. The first one is the monster's half of
## the very turn Sleep landed on, so a successful Sleep costs the target that
## turn and then rolls to wake from the next one.                      [PICKED]
const SLEEP_GUARANTEED_TURNS := 1
## Chance to wake, checked once per turn after the guaranteed turns.   [PICKED]
const SLEEP_WAKE_NUMERATOR := 1
const SLEEP_WAKE_DENOMINATOR := 3


# --- 파생 스탯 -------------------------------------------------------------

static func attack_power(strength: int, weapon_bonus: int) -> int:
	return strength + weapon_bonus


static func defense_power(agility: int, armor_bonus: int, shield_bonus: int) -> int:
	return int(agility / 2.0) + armor_bonus + shield_bonus


## Monsters have no separate defence stat; half their agility is used.   [OK]
static func monster_defense(agility: int) -> int:
	return int(agility / 2.0)


# --- 데미지 ---------------------------------------------------------------

static func physical_damage(atk: int, def: int, rng: Rng) -> int:
	if atk > def:
		var spread := atk - def
		return rng.range_i(spread / DAMAGE_DIVISOR_MIN, spread / DAMAGE_DIVISOR_MAX)
	# Grazing hit: a well-armoured target still takes the occasional scratch.
	return rng.range_i(0, (atk + 1) / WEAK_HIT_DIVISOR)


static func rolls_critical(rng: Rng) -> bool:
	return rng.chance(CRIT_NUMERATOR, CRIT_DENOMINATOR)


static func critical_damage(atk: int, rng: Rng) -> int:
	return maxi(1, rng.range_i(atk / 2, atk))


# --- 전투 흐름 ------------------------------------------------------------

static func monster_acts_first(hero_agility: int, monster_agility: int, rng: Rng) -> bool:
	var monster_roll := monster_agility * rng.byte() / 256
	return monster_roll > hero_agility / INITIATIVE_HERO_DIVISOR


static func flee_succeeds(hero_agility: int, monster_agility: int, rng: Rng) -> bool:
	var threshold := FLEE_BASE + (hero_agility - monster_agility) / FLEE_AGILITY_DIVISOR
	return rng.byte() < clampi(threshold, FLEE_MIN, FLEE_MAX)


# --- 주문 -----------------------------------------------------------------

static func spell_power(spell: SpellData, cast_by_hero: bool, rng: Rng) -> int:
	if cast_by_hero:
		return rng.range_i(spell.hero_power_min, spell.hero_power_max)
	return rng.range_i(spell.monster_power_min, spell.monster_power_max)


## Hurt-family damage after the target's armour and innate resistance.
static func apply_hurt_reduction(raw: int, reduction: float) -> int:
	return maxi(0, int(round(raw * (1.0 - clampf(reduction, 0.0, 1.0)))))


## Sleep / Stopspell. `resist` is 0 (never resists) to 255 (immune).
static func status_lands(resist: int, rng: Rng) -> bool:
	if resist >= 255:
		return false
	return rng.byte() >= resist


static func wakes_from_sleep(rng: Rng) -> bool:
	return rng.chance(SLEEP_WAKE_NUMERATOR, SLEEP_WAKE_DENOMINATOR)


# --- 보상 -----------------------------------------------------------------

static func gold_reward(monster: MonsterData, rng: Rng) -> int:
	return rng.range_i(monster.gold_reward_min, monster.gold_reward_max)
