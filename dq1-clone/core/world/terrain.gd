## Terrain types and their rules. Colours and tiles are the view's business —
## nothing here knows what a tile looks like.
class_name Terrain
extends RefCounted

enum Type {
	PLAIN,
	GRASS,
	FOREST,
	HILL,
	SWAMP,
	WATER,
	WALL,
	FLOOR,
	BRIDGE,
	TOWN,
	CAVE,
	STAIRS_DOWN,
	STAIRS_UP,
	DOOR,
}

## HP lost on stepping onto a swamp tile.
const SWAMP_DAMAGE := 2


static func is_passable(type: int) -> bool:
	match type:
		Type.WATER, Type.WALL:
			return false
		_:
			return true


## Scales the map's base encounter rate. Rough terrain hides more monsters.
static func encounter_multiplier(type: int) -> float:
	match type:
		Type.FOREST, Type.HILL:
			return 1.5
		Type.SWAMP:
			return 1.25
		Type.PLAIN, Type.GRASS, Type.FLOOR:
			return 1.0
		Type.BRIDGE:
			return 0.5
		_:
			return 0.0


static func damage_on_enter(type: int) -> int:
	return SWAMP_DAMAGE if type == Type.SWAMP else 0


static func type_name(type: int) -> String:
	if type < 0 or type >= Type.size():
		return "INVALID"
	return Type.keys()[type]
