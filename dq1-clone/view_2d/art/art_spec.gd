## What every art sheet in this game looks like: where it is, how big one cell
## is, and what has to be in each cell, in order.
##
## This is the contract for putting real art in. Before it existed the layout
## of a sheet was implicit — 240x16 meant "fifteen terrain tiles in the order
## of an enum in core/", and nothing said so anywhere. Dropping in somebody
## else's tileset meant reading the drawing code to find out what it expected.
##
## Now the generators write to this, the views read from it, and
## tools/test_presentation.gd checks the files on disk against it. A sheet one
## cell short fails headlessly instead of drawing the wrong tile for the rest
## of the game.
class_name ArtSpec
extends RefCounted

## One map cell, in pixels. The 2D field, the darkness overlay, the NPC layer
## and the 2.5D mesh all measure the world with this one number.
const TILE := 16
## Monsters are drawn larger than the world grid; they are never on it.
const MONSTER := 24

const DIR := "res://assets/art"

## `cells` names every cell in the order it must appear, left to right and
## then down. `columns` is how many fit in a row before wrapping; 0 means one
## single row. `opaque` sheets fill every pixel, the rest need transparency
## around the subject or it carries a square of background around with it.
const SHEETS := {
	&"tiles": {
		"path": DIR + "/terrain_tiles.png",
		"cell": TILE,
		"columns": 0,
		"opaque": true,
		"about": "지형 아틀라스. 순서는 core/world/terrain.gd 의 Terrain.Type.",
		"cells": [
			"PLAIN", "GRASS", "FOREST", "HILL", "SWAMP", "WATER", "WALL",
			"FLOOR", "BRIDGE", "TOWN", "CAVE", "STAIRS_DOWN", "STAIRS_UP",
			"DOOR", "CHEST",
		],
	},
	&"props": {
		"path": DIR + "/terrain_props.png",
		"cell": TILE,
		"columns": 0,
		"opaque": false,
		"about": "2.5D 에서 세워 놓는 입체물. 바닥 없이, 배경 투명.",
		"cells": ["tree", "house", "cave", "door", "chest"],
	},
	&"hero": {
		"path": DIR + "/hero.png",
		"cell": TILE,
		"columns": 2,
		"opaque": false,
		"about": "주인공. 한 줄이 한 방향, 두 칸이 걸음 두 프레임.",
		"cells": [
			"down 1", "down 2", "up 1", "up 2",
			"left 1", "left 2", "right 1", "right 2",
		],
	},
	&"npcs": {
		"path": DIR + "/npcs.png",
		"cell": TILE,
		"columns": 0,
		"opaque": false,
		"about": "마을 사람들. 순서는 npc_layer.gd 의 COLUMNS.",
		"cells": ["villager", "shop", "inn", "king"],
	},
	&"monsters": {
		"path": DIR + "/monsters.png",
		"cell": MONSTER,
		"columns": 0,
		"opaque": false,
		"about": "전투 초상. 순서는 monster_sprite.gd 의 COLUMNS.",
		"cells": [
			"m_slime", "m_slime_red", "m_drakee", "m_ghost", "m_magician",
			"m_scorpion", "m_wraith", "m_dragonlord", "m_dragonlord_true",
		],
	},
}


static func sheet(name: StringName) -> Dictionary:
	return SHEETS.get(name, {})


## How many cells across and down a sheet is laid out.
static func grid(name: StringName) -> Vector2i:
	var spec := sheet(name)
	if spec.is_empty():
		return Vector2i.ZERO
	var count: int = spec["cells"].size()
	var columns: int = spec["columns"]
	if columns <= 0:
		return Vector2i(count, 1)
	return Vector2i(columns, int(ceil(float(count) / float(columns))))


## The size the file on disk has to be, in pixels.
static func pixel_size(name: StringName) -> Vector2i:
	var spec := sheet(name)
	if spec.is_empty():
		return Vector2i.ZERO
	return grid(name) * int(spec["cell"])


## Where cell `index` sits in the sheet, in pixels.
static func cell_rect(name: StringName, index: int) -> Rect2i:
	var spec := sheet(name)
	if spec.is_empty():
		return Rect2i()
	var size: int = spec["cell"]
	var columns: int = maxi(1, grid(name).x)
	return Rect2i(Vector2i(index % columns, index / columns) * size,
			Vector2i(size, size))
