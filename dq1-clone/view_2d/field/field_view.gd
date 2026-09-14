## Draws whatever map the world is currently on and walks the hero across it.
##
## Pure presentation: it is handed a MapData and a cell, and knows nothing about
## encounters, battles or stats.
extends Node2D

const TILE := 16
const WALK_SPEED := 90.0

@onready var _terrain: TileMapLayer = $Terrain
@onready var _hero: Node2D = $Hero
@onready var _camera: Camera2D = $Hero/Camera2D

var _target_position: Vector2 = Vector2.ZERO


func render_map(map: MapData) -> void:
	_terrain.clear()
	for y in map.height:
		for x in map.width:
			var terrain: int = map.tiles[y * map.width + x]
			_terrain.set_cell(Vector2i(x, y), 0, Vector2i(terrain, 0))

	# Keep the camera inside the map instead of showing the void past its edge.
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = map.width * TILE
	_camera.limit_bottom = map.height * TILE


func snap_hero(cell: Vector2i) -> void:
	_target_position = _cell_to_position(cell)
	_hero.position = _target_position
	_camera.reset_smoothing()


func walk_hero(cell: Vector2i, facing: Vector2i) -> void:
	_target_position = _cell_to_position(cell)
	_hero.set_facing(facing)


func face_hero(facing: Vector2i) -> void:
	_hero.set_facing(facing)


## True while the sprite is still catching up with its logical cell.
func is_walking() -> bool:
	return _hero.position.distance_to(_target_position) > 0.5


func _process(delta: float) -> void:
	if is_walking():
		_hero.position = _hero.position.move_toward(_target_position, WALK_SPEED * delta)
	else:
		_hero.position = _target_position


func _cell_to_position(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE / 2.0)
