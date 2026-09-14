## How each terrain type becomes geometry.
##
## The ground is UV-mapped into the same 16x16 atlas the 2D view uses, so the
## tiles keep their art and only gain height. That is the whole trick behind
## the HD-2D look: 2D art, 3D space.
class_name Terrain3D
extends RefCounted

## terrain -> [height, tint, prop height (0 = no billboard)]
const PROFILE := {
	Terrain.Type.PLAIN: [0.0, Color(1, 1, 1), 0.0],
	Terrain.Type.GRASS: [0.0, Color(1, 1, 1), 0.0],
	Terrain.Type.FOREST: [0.15, Color(0.85, 0.9, 0.85), 1.5],
	Terrain.Type.HILL: [0.5, Color(1, 1, 1), 0.0],
	Terrain.Type.SWAMP: [-0.12, Color(0.9, 0.95, 0.9), 0.0],
	Terrain.Type.WATER: [-0.3, Color(1, 1, 1), 0.0],
	Terrain.Type.WALL: [1.4, Color(1, 1, 1), 0.0],
	Terrain.Type.FLOOR: [0.0, Color(1, 1, 1), 0.0],
	Terrain.Type.BRIDGE: [0.06, Color(1, 1, 1), 0.0],
	Terrain.Type.TOWN: [0.0, Color(1, 1, 1), 1.6],
	Terrain.Type.CAVE: [0.0, Color(0.8, 0.8, 0.85), 1.4],
	Terrain.Type.STAIRS_DOWN: [-0.25, Color(1, 1, 1), 0.0],
	Terrain.Type.STAIRS_UP: [0.25, Color(1, 1, 1), 0.0],
	Terrain.Type.DOOR: [0.0, Color(1, 1, 1), 1.3],
	Terrain.Type.CHEST: [0.0, Color(1, 1, 1), 0.7],
}

## Elevation from MapData is layered on top of the terrain's own height. The
## 2D renderer ignores that field entirely; this is the first thing to use it.
const ELEVATION_STEP := 0.35


static func height(terrain: int, elevation: int) -> float:
	var profile: Array = PROFILE.get(terrain, [0.0, Color.WHITE, 0.0])
	return float(profile[0]) + elevation * ELEVATION_STEP


static func tint(terrain: int) -> Color:
	var profile: Array = PROFILE.get(terrain, [0.0, Color.WHITE, 0.0])
	return profile[1]


## Height of the upright billboard that stands on this tile, 0 for none.
static func prop_height(terrain: int) -> float:
	var profile: Array = PROFILE.get(terrain, [0.0, Color.WHITE, 0.0])
	return float(profile[2])
