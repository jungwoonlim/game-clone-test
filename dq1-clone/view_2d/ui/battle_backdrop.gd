## The ground you are fighting on.
##
## A flat dim panel made every fight look identical; this reads the terrain the
## party is standing on so a forest ambush and a cave ambush look different.
extends Control

const DEFAULT_SCENE := ["17203a", "34412a", "4a5c37"]
const DIM := Color(0.02, 0.02, 0.05, 0.55)

var _sky := Color(DEFAULT_SCENE[0])
var _ground := Color(DEFAULT_SCENE[1])
var _accent := Color(DEFAULT_SCENE[2])


func set_terrain(terrain: int) -> void:
	match terrain:
		Terrain.Type.GRASS, Terrain.Type.PLAIN, Terrain.Type.BRIDGE:
			_apply("172142", "3d6b32", "56904a")
		Terrain.Type.FOREST:
			_apply("101a30", "1f4523", "2f6b32")
		Terrain.Type.HILL:
			_apply("1d2138", "6a5230", "8a6c44")
		Terrain.Type.SWAMP:
			_apply("141a26", "3a4526", "515f35")
		Terrain.Type.FLOOR, Terrain.Type.CAVE, Terrain.Type.STAIRS_DOWN, \
		Terrain.Type.STAIRS_UP:
			_apply("0b0c12", "40372c", "574a3a")
		_:
			_apply(DEFAULT_SCENE[0], DEFAULT_SCENE[1], DEFAULT_SCENE[2])
	queue_redraw()


func _apply(sky: String, ground: String, accent: String) -> void:
	_sky = Color(sky)
	_ground = Color(ground)
	_accent = Color(accent)


func _draw() -> void:
	var horizon := size.y * 0.55
	# Sky, banded so it gradates without a gradient texture.
	var bands := 12
	var band_height := horizon / float(bands)
	for i in bands:
		# Step by the band height, not by t: stepping by horizon*t leaves a
		# hairline gap between bands. Invisible over the 2D field, and a row of
		# bright streaks over the 3D one.
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0, i * band_height, size.x, band_height + 1.0),
				_sky.lightened(0.08 * t))
	draw_rect(Rect2(0, horizon, size.x, size.y - horizon), _ground)
	draw_rect(Rect2(0, horizon - 2.0, size.x, 3.0), _accent)
	# Ground texture: a few darker bands so it is not a flat slab.
	for i in 6:
		var y := horizon + 6.0 + i * (size.y - horizon) / 7.0
		draw_rect(Rect2(0, y, size.x, 1.0), _ground.darkened(0.18))
	draw_rect(Rect2(Vector2.ZERO, size), DIM)
