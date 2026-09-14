## Deciding whether a step starts a fight, and with what.
class_name EncounterResolver
extends RefCounted

## Repel keeps out monsters at or below hero_level / this.
const REPEL_TIER_DIVISOR := 5


static func triggers(map: MapData, terrain_type: int, rng: Rng) -> bool:
	if map.encounter_rate <= 0:
		return false
	var rate := int(map.encounter_rate * Terrain.encounter_multiplier(terrain_type))
	if rate <= 0:
		return false
	return rng.byte() < rate


static func repel_tier_ceiling(hero_level: int) -> int:
	return hero_level / REPEL_TIER_DIVISOR


## Returns &"" when nothing is eligible (which is how Repel suppresses a fight).
static func pick(table: EncounterTable, rng: Rng, repel_active: bool,
		hero_level: int) -> StringName:
	if table == null or table.entries.is_empty():
		return &""

	var ceiling := repel_tier_ceiling(hero_level) if repel_active else -1
	var ids: Array[StringName] = []
	var weights: Array[int] = []
	for entry in table.entries:
		if entry.tier <= ceiling:
			continue
		ids.append(entry.monster_id)
		weights.append(entry.weight)

	var index := rng.pick_weighted(weights)
	if index < 0:
		return &""
	return ids[index]
