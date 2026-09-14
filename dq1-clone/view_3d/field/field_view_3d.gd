## The 2.5D field: the same maps, built as geometry.
##
## Exposes exactly the method surface that view_2d/field/field_view.gd does —
## render_map, snap_hero, walk_hero, face_hero, is_walking, set_sight,
## set_cell_terrain — so scenes/main.gd drives either renderer without knowing
## which one it has. That substitutability is the whole point of M7.
extends Node3D

const TILE_PIXELS := 16
const WALK_SPEED := 5.6
## Sprites are centred on their origin, so standing one on the ground means
## lifting it by half its height. Forgetting this buries the party to the waist.
const SPRITE_LIFT := 0.5
const ATLAS := "res://view_2d/field/terrain_tiles.png"
const PROP_ATLAS := "res://view_2d/field/terrain_props.png"
## terrain -> column in the prop atlas
const PROP_COLUMNS := {
	Terrain.Type.FOREST: 0, Terrain.Type.TOWN: 1, Terrain.Type.CAVE: 2,
	Terrain.Type.DOOR: 3, Terrain.Type.CHEST: 4,
}
## What the ground under a prop is made of. A house should not be standing on
## a picture of a house.
const PROP_GROUND := {
	Terrain.Type.FOREST: Terrain.Type.GRASS,
	Terrain.Type.TOWN: Terrain.Type.GRASS,
	Terrain.Type.CAVE: Terrain.Type.HILL,
	Terrain.Type.DOOR: Terrain.Type.FLOOR,
	Terrain.Type.CHEST: Terrain.Type.FLOOR,
}
const HERO_SHEET := "res://assets/art/hero.png"
const NPC_SHEET := "res://assets/art/npcs.png"
const NPC_COLUMNS := {"villager": 0, "shop": 1, "inn": 2, "king": 3}
const HERO_ROWS := {
	Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3,
}

@onready var _ground: MeshInstance3D = $Ground
@onready var _props: Node3D = $Props
@onready var _actors: Node3D = $Actors
@onready var _hero: Sprite3D = $Actors/Hero
@onready var _lantern: OmniLight3D = $Actors/Hero/Lantern
@onready var _rig: Node3D = $CameraRig
@onready var _environment: WorldEnvironment = $World

var _map: MapData = null
var _tiles: PackedByteArray = PackedByteArray()
var _target: Vector3 = Vector3.ZERO
var _frame := 0
var _facing := Vector2i.DOWN
var _atlas: Texture2D = load(ATLAS)
var _prop_atlas: Texture2D = load(PROP_ATLAS)
var _hero_texture: Texture2D = load(HERO_SHEET)
var _npc_texture: Texture2D = load(NPC_SHEET)


func _ready() -> void:
	_hero.texture = _hero_texture
	_hero.region_enabled = true
	_hero.pixel_size = 1.0 / float(TILE_PIXELS)
	_hero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hero.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_hero.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_hero.shaded = true
	_hero.double_sided = true
	_apply_hero_region()
	_setup_world()
	_setup_camera()


## Built in code rather than authored in the scene: the enum names are
## readable here, and there is one fewer binary resource to keep in sync.
func _setup_world() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_texture = _atlas
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_ground.material_override = material

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0a0d1a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8f9fc4")
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.92
	env.fog_light_color = Color("0a0d1a")
	env.fog_enabled = false
	_environment.environment = env


func _setup_camera() -> void:
	var camera: Camera3D = _rig.get_node("Camera")
	# ~16 tiles across: close enough to feel like a diorama, wide enough to
	# navigate by. A narrow field of view compresses depth, which is what
	# sells the miniature.
	camera.position = Vector3(0.0, 13.5, 12.6)
	camera.rotation_degrees = Vector3(-47.0, 0.0, 0.0)
	camera.fov = 36.0
	camera.current = true


# --- main.gd가 부르는 메서드 (view_2d와 동일) -----------------------------

func render_map(map: MapData) -> void:
	_map = map
	_tiles = map.tiles.duplicate()
	_rebuild()


func snap_hero(cell: Vector2i) -> void:
	_target = _stand_on(cell)
	_hero.position = _target
	_rig.position = _target


func walk_hero(cell: Vector2i, facing: Vector2i) -> void:
	_target = _stand_on(cell)
	face_hero(facing)
	_frame = 1 - _frame
	_apply_hero_region()


func face_hero(facing: Vector2i) -> void:
	if facing != Vector2i.ZERO and facing != _facing:
		_facing = facing
		_apply_hero_region()


func is_walking() -> bool:
	return _hero.position.distance_to(_target) > 0.02


## In 3D the dark is a lantern and fog rather than a black overlay, which is
## the same information carried by the medium that suits it.
func set_sight(_center: Vector2i, radius: int) -> void:
	var lit := radius <= 0
	_lantern.visible = not lit
	_lantern.omni_range = maxf(1.0, radius * 2.2)
	var env := _environment.environment
	if env == null:
		return
	env.fog_enabled = not lit
	env.fog_density = 0.0 if lit else 0.19
	env.ambient_light_energy = 0.6 if lit else 0.16


func set_cell_terrain(cell: Vector2i, terrain: int) -> void:
	if _map == null or not _map.in_bounds(cell):
		return
	_tiles[cell.y * _map.width + cell.x] = terrain
	_rebuild()


# --- 내부 ----------------------------------------------------------------

func _process(delta: float) -> void:
	if is_walking():
		_hero.position = _hero.position.move_toward(_target, WALK_SPEED * delta)
	else:
		_hero.position = _target
	# The rig trails the party so the camera glides instead of snapping.
	_rig.position = _rig.position.lerp(_hero.position, clampf(delta * 7.0, 0.0, 1.0))


func _apply_hero_region() -> void:
	var row: int = HERO_ROWS.get(_facing, 0)
	_hero.region_rect = Rect2(_frame * TILE_PIXELS, row * TILE_PIXELS,
			TILE_PIXELS, TILE_PIXELS)


func _terrain_at(cell: Vector2i) -> int:
	if _map == null or not _map.in_bounds(cell):
		return -1
	return _tiles[cell.y * _map.width + cell.x]


func _height_at(cell: Vector2i) -> float:
	var terrain := _terrain_at(cell)
	if terrain < 0:
		return -1.5
	return Terrain3D.height(terrain, _map.elevation_at(cell))


func _cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x + 0.5, _height_at(cell), cell.y + 0.5)


func _stand_on(cell: Vector2i) -> Vector3:
	return _cell_to_world(cell) + Vector3(0.0, SPRITE_LIFT, 0.0)


# --- 지오메트리 ----------------------------------------------------------

func _rebuild() -> void:
	_ground.mesh = _build_ground()
	_rebuild_props()


## One surface for the whole map: a top quad per tile, plus side quads wherever
## a neighbour sits lower. UVs point into the same atlas the 2D view samples,
## so the tiles keep their pixels and only gain height.
func _build_ground() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := Terrain.Type.size()

	for y in _map.height:
		for x in _map.width:
			var cell := Vector2i(x, y)
			var terrain := _terrain_at(cell)
			var top := _height_at(cell)
			var uv := _atlas_uv(_ground_terrain(terrain), columns)
			var tint := Terrain3D.tint(terrain)

			_quad(tool,
					Vector3(x, top, y), Vector3(x + 1, top, y),
					Vector3(x + 1, top, y + 1), Vector3(x, top, y + 1),
					uv, tint, Vector3.UP)

			# Sides, only where they would actually be visible.
			for offset in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var neighbour: Vector2i = cell + offset
				var other := _height_at(neighbour)
				if other >= top - 0.001:
					continue
				_side(tool, cell, offset, top, other, uv, tint.darkened(0.28))

	tool.generate_normals()
	return tool.commit()


func _side(tool: SurfaceTool, cell: Vector2i, offset: Vector2i, top: float,
		bottom: float, uv: Rect2, color: Color) -> void:
	var x := float(cell.x)
	var y := float(cell.y)
	if offset == Vector2i(0, -1):
		_quad(tool, Vector3(x, top, y), Vector3(x, bottom, y),
				Vector3(x + 1, bottom, y), Vector3(x + 1, top, y),
				uv, color, Vector3.FORWARD)
	elif offset == Vector2i(0, 1):
		_quad(tool, Vector3(x + 1, top, y + 1), Vector3(x + 1, bottom, y + 1),
				Vector3(x, bottom, y + 1), Vector3(x, top, y + 1),
				uv, color, Vector3.BACK)
	elif offset == Vector2i(-1, 0):
		_quad(tool, Vector3(x, top, y + 1), Vector3(x, bottom, y + 1),
				Vector3(x, bottom, y), Vector3(x, top, y),
				uv, color, Vector3.LEFT)
	else:
		_quad(tool, Vector3(x + 1, top, y), Vector3(x + 1, bottom, y),
				Vector3(x + 1, bottom, y + 1), Vector3(x + 1, top, y + 1),
				uv, color, Vector3.RIGHT)


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		uv: Rect2, color: Color, normal: Vector3) -> void:
	var corners := [a, b, c, d]
	var coords := [
		uv.position,
		Vector2(uv.position.x + uv.size.x, uv.position.y),
		uv.end,
		Vector2(uv.position.x, uv.position.y + uv.size.y),
	]
	for triangle in [[0, 1, 2], [0, 2, 3]]:
		for index in triangle:
			tool.set_color(color)
			tool.set_normal(normal)
			tool.set_uv(coords[index])
			tool.add_vertex(corners[index])


## Half a texel of inset, or neighbouring tiles bleed into each other.
## Prop tiles draw their neutral ground; the motif stands on top as a sprite.
func _ground_terrain(terrain: int) -> int:
	return PROP_GROUND.get(terrain, terrain)


func _atlas_uv(terrain: int, columns: int) -> Rect2:
	var index := clampi(terrain, 0, columns - 1)
	var width := 1.0 / float(columns)
	var inset_u := 0.5 / float(columns * TILE_PIXELS)
	var inset_v := 0.5 / float(TILE_PIXELS)
	return Rect2(index * width + inset_u, inset_v,
			width - inset_u * 2.0, 1.0 - inset_v * 2.0)


# --- 프롭과 NPC ----------------------------------------------------------

func _rebuild_props() -> void:
	for child in _props.get_children():
		child.queue_free()
	if _map == null:
		return

	for y in _map.height:
		for x in _map.width:
			var cell := Vector2i(x, y)
			var terrain := _terrain_at(cell)
			var prop := Terrain3D.prop_height(terrain)
			if prop <= 0.0 or not PROP_COLUMNS.has(terrain):
				continue
			var column: int = PROP_COLUMNS[terrain]
			_props.add_child(_billboard(_prop_atlas,
					Rect2(column * TILE_PIXELS, 0, TILE_PIXELS, TILE_PIXELS),
					_cell_to_world(cell) + Vector3(0, prop * 0.5, 0), prop))

	for npc in _map.npcs:
		var column: int = NPC_COLUMNS.get(npc.role, 0)
		_props.add_child(_billboard(_npc_texture,
				Rect2(column * TILE_PIXELS, 0, TILE_PIXELS, TILE_PIXELS),
				_stand_on(npc.cell), 1.0, true))


func _billboard(texture: Texture2D, region: Rect2, at: Vector3, height: float,
		face_camera: bool = false) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.pixel_size = height / float(TILE_PIXELS)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED if face_camera \
			else BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.double_sided = true
	sprite.position = at
	return sprite
