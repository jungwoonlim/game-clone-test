## Turning battle rewards into levels and spells.
class_name Progression
extends RefCounted


## Applies EXP and gold, levelling the hero up as many times as the total
## allows. Returns { levels: Array[int], spells: Array[SpellData] } describing
## what changed, so the caller can turn it into events or messages.
static func award(hero: Hero, db: GameDatabase, exp_gain: int, gold_gain: int) -> Dictionary:
	hero.gold += maxi(0, gold_gain)
	hero.total_exp = mini(hero.total_exp + maxi(0, exp_gain), max_exp(db))

	var levels_gained: Array[int] = []
	var spells_learned: Array[SpellData] = []

	var target := db.level_curve.level_for_exp(hero.total_exp)
	while hero.level < target:
		hero.apply_level(db.level_curve, hero.level + 1)
		levels_gained.append(hero.level)
		for spell in db.spells_learned_at(hero.level):
			spells_learned.append(spell)

	return {"levels": levels_gained, "spells": spells_learned}


## The EXP value the last level requires — the original caps at 65535.
static func max_exp(db: GameDatabase) -> int:
	var table := db.level_curve.required_exp
	return table[table.size() - 1] if not table.is_empty() else 0


## Death: lose half your gold and wake up at the save point.
static func apply_death(hero: Hero) -> int:
	var lost := hero.gold / 2
	hero.gold -= lost
	hero.restore_fully()
	return lost
