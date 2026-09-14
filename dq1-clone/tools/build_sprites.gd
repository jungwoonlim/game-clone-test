## Generates the character and monster sprite sheets.
##
##   godot --headless --path . --script res://tools/build_sprites.gd
##   godot --headless --path . --import
##
## Sprites are composed from primitives on an index grid, then run through a
## shading and outline pass. That last pass is what makes them read as sprite
## art rather than coloured blobs, and it costs nothing per species.
extends SceneTree

const MONSTER := ArtSpec.MONSTER
const CHAR := ArtSpec.TILE
const ART_DIR := ArtSpec.DIR

# Index grid values.
const EMPTY := 0
const BASE := 1
const SHADE := 2
const LIGHT := 3
const ACCENT := 4
const WHITE := 5
const BLACK := 6
const OUTLINE := 7

## Monster order must match the sheet columns read by the battle view.
const MONSTER_ORDER := [
	"m_slime", "m_slime_red", "m_drakee", "m_ghost", "m_magician",
	"m_scorpion", "m_wraith", "m_dragonlord", "m_dragonlord_true",
]

## species -> [shape, base, shade, light, accent]
const MONSTER_STYLE := {
	"m_slime": ["slime", "4aa3e0", "2b6ba0", "9ad4ff", "ffffff"],
	"m_slime_red": ["slime", "d9484d", "9a2b30", "ff9a9a", "ffffff"],
	"m_drakee": ["bat", "8a5ec0", "5a3888", "c0a0e8", "f0d070"],
	"m_ghost": ["ghost", "d8e0e8", "97a4b4", "ffffff", "6a7a8a"],
	"m_magician": ["mage", "3f6fd0", "24417e", "7aa0e8", "e8c84a"],
	"m_scorpion": ["scorpion", "c8862a", "8a5716", "efc06a", "2b2b33"],
	"m_wraith": ["mage", "3a7a52", "1f4a30", "76bb8e", "d8e0e8"],
	"m_dragonlord": ["knight", "6a4aa0", "3d2a66", "a184d8", "e8c84a"],
	"m_dragonlord_true": ["dragon", "2f9e44", "1a6129", "72d089", "e8c84a"],
}

const HERO_STYLE := ["3f6fd0", "24417e", "7aa0e8", "e8c84a"]
## NPC roles reuse the hero silhouette in their own colours.
const NPC_ORDER := ["villager", "shop", "inn", "king"]
const NPC_STYLE := {
	"villager": ["3f9f5a", "215f36", "86d3a0", "c8b88a"],
	"shop": ["b0762a", "744a15", "dcb066", "e8e2cf"],
	"inn": ["9b5ec0", "633a80", "c79ae0", "e8e2cf"],
	"king": ["c8a04a", "8a6a24", "efd48a", "e8c84a"],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ART_DIR)
	_write_monsters()
	_write_hero()
	_write_npcs()
	print("[sprites] wrote %d monsters, hero (4 dirs x 2 frames), %d npcs"
			% [MONSTER_ORDER.size(), NPC_ORDER.size()])
	quit(0)


# --- 그리드 유틸 ----------------------------------------------------------

func _grid(size: int) -> PackedByteArray:
	var grid := PackedByteArray()
	grid.resize(size * size)
	return grid


func _px(grid: PackedByteArray, size: int, x: int, y: int, value: int) -> void:
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	grid[y * size + x] = value


func _at(grid: PackedByteArray, size: int, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= size or y >= size:
		return EMPTY
	return grid[y * size + x]


func _ellipse(grid: PackedByteArray, size: int, cx: float, cy: float,
		rx: float, ry: float, value: int) -> void:
	for y in size:
		for x in size:
			var dx := (x + 0.5 - cx) / maxf(rx, 0.001)
			var dy := (y + 0.5 - cy) / maxf(ry, 0.001)
			if dx * dx + dy * dy <= 1.0:
				_px(grid, size, x, y, value)


func _box(grid: PackedByteArray, size: int, x0: int, y0: int, x1: int, y1: int,
		value: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(grid, size, x, y, value)


## Filled triangle, used for wings, horns and robes.
func _triangle(grid: PackedByteArray, size: int, a: Vector2, b: Vector2, c: Vector2,
		value: int) -> void:
	var min_x := int(floor(minf(a.x, minf(b.x, c.x))))
	var max_x := int(ceil(maxf(a.x, maxf(b.x, c.x))))
	var min_y := int(floor(minf(a.y, minf(b.y, c.y))))
	var max_y := int(ceil(maxf(a.y, maxf(b.y, c.y))))
	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			if _inside(p, a, b, c):
				_px(grid, size, x, y, value)


func _inside(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := _sign_of(p, a, b)
	var d2 := _sign_of(p, b, c)
	var d3 := _sign_of(p, c, a)
	var has_negative: bool = d1 < 0.0 or d2 < 0.0 or d3 < 0.0
	var has_positive: bool = d1 > 0.0 or d2 > 0.0 or d3 > 0.0
	return not (has_negative and has_positive)


func _sign_of(p: Vector2, a: Vector2, b: Vector2) -> float:
	return (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)


## Shades the lower half, lights the upper-left, then traces an outline around
## everything. Doing this after composition means each species only has to
## describe its silhouette.
func _finish(grid: PackedByteArray, size: int, light_center: Vector2) -> void:
	var lowest := 0
	for y in size:
		for x in size:
			if _at(grid, size, x, y) == BASE:
				lowest = maxi(lowest, y)

	for y in size:
		for x in size:
			if _at(grid, size, x, y) != BASE:
				continue
			if y >= lowest - maxi(2, size / 6):
				_px(grid, size, x, y, SHADE)
			elif Vector2(x + 0.5, y + 0.5).distance_to(light_center) < size * 0.13:
				_px(grid, size, x, y, LIGHT)

	var outlined := grid.duplicate()
	for y in size:
		for x in size:
			if _at(grid, size, x, y) != EMPTY:
				continue
			var touches := false
			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var neighbour := _at(grid, size, x + offset.x, y + offset.y)
				if neighbour != EMPTY and neighbour != OUTLINE:
					touches = true
					break
			if touches:
				outlined[y * size + x] = OUTLINE
	for i in grid.size():
		grid[i] = outlined[i]


func _eyes(grid: PackedByteArray, size: int, left: Vector2i, right: Vector2i,
		radius: int = 2) -> void:
	for eye in [left, right]:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if dx * dx + dy * dy <= radius * radius:
					_px(grid, size, eye.x + dx, eye.y + dy, WHITE)
		_px(grid, size, eye.x, eye.y, BLACK)
		_px(grid, size, eye.x, eye.y + 1, BLACK)


# --- 몬스터 실루엣 --------------------------------------------------------

func _build_monster(shape: String) -> PackedByteArray:
	var g := _grid(MONSTER)
	match shape:
		"slime":
			_ellipse(g, MONSTER, 12.0, 10.0, 5.5, 6.0, BASE)
			_ellipse(g, MONSTER, 12.0, 16.0, 10.0, 7.0, BASE)
			_triangle(g, MONSTER, Vector2(12, 2), Vector2(9, 9), Vector2(15, 9), BASE)
			_box(g, MONSTER, 3, 21, 20, 22, BASE)
			_finish(g, MONSTER, Vector2(8, 11))
			_eyes(g, MONSTER, Vector2i(9, 13), Vector2i(15, 13))
			_box(g, MONSTER, 10, 18, 13, 18, BLACK)
		"bat":
			_ellipse(g, MONSTER, 12.0, 13.0, 5.0, 6.0, BASE)
			_triangle(g, MONSTER, Vector2(7, 11), Vector2(0, 6), Vector2(2, 18), BASE)
			_triangle(g, MONSTER, Vector2(17, 11), Vector2(24, 6), Vector2(22, 18), BASE)
			_triangle(g, MONSTER, Vector2(9, 8), Vector2(7, 1), Vector2(12, 6), BASE)
			_triangle(g, MONSTER, Vector2(15, 8), Vector2(17, 1), Vector2(12, 6), BASE)
			_finish(g, MONSTER, Vector2(10, 10))
			_eyes(g, MONSTER, Vector2i(10, 12), Vector2i(14, 12), 1)
			_px(g, MONSTER, 11, 16, BLACK)
			_px(g, MONSTER, 12, 16, BLACK)
		"ghost":
			_ellipse(g, MONSTER, 12.0, 11.0, 8.0, 8.0, BASE)
			_box(g, MONSTER, 4, 11, 19, 19, BASE)
			for i in 4:
				_triangle(g, MONSTER, Vector2(4 + i * 4, 19), Vector2(8 + i * 4, 19),
						Vector2(6 + i * 4, 23), BASE)
			_finish(g, MONSTER, Vector2(9, 8))
			_eyes(g, MONSTER, Vector2i(9, 10), Vector2i(15, 10))
			_box(g, MONSTER, 10, 15, 13, 16, BLACK)
		"mage":
			_triangle(g, MONSTER, Vector2(12, 5), Vector2(2, 22), Vector2(22, 22), BASE)
			_box(g, MONSTER, 3, 20, 20, 22, BASE)
			_ellipse(g, MONSTER, 12.0, 7.0, 5.0, 5.5, BASE)
			_triangle(g, MONSTER, Vector2(12, 0), Vector2(7, 8), Vector2(17, 8), BASE)
			_finish(g, MONSTER, Vector2(9, 6))
			_box(g, MONSTER, 8, 6, 15, 10, BLACK)
			_px(g, MONSTER, 10, 8, ACCENT)
			_px(g, MONSTER, 11, 8, ACCENT)
			_px(g, MONSTER, 13, 8, ACCENT)
			_px(g, MONSTER, 14, 8, ACCENT)
			_box(g, MONSTER, 9, 16, 14, 17, ACCENT)
		"scorpion":
			# Body low and wide, tail arcing up the right, claws reaching left.
			_ellipse(g, MONSTER, 10.0, 17.0, 6.5, 4.0, BASE)
			_ellipse(g, MONSTER, 10.0, 12.0, 4.0, 3.2, BASE)
			for i in 6:
				var t := float(i) / 5.0
				var angle: float = lerpf(PI * 0.55, -PI * 0.12, t)
				_ellipse(g, MONSTER,
						14.5 + cos(angle) * 6.5, 15.0 - sin(angle) * 10.0,
						2.2 - t * 0.7, 2.2 - t * 0.7, BASE)
			_triangle(g, MONSTER, Vector2(19, 6), Vector2(23, 2), Vector2(21, 8), ACCENT)
			# Pincers: a blob with a notch bitten out of it.
			for claw in [Vector2(4, 12), Vector2(4, 18)]:
				_ellipse(g, MONSTER, claw.x, claw.y, 3.2, 2.4, BASE)
				_triangle(g, MONSTER, Vector2(claw.x - 3, claw.y),
						Vector2(claw.x + 1, claw.y - 1), Vector2(claw.x + 1, claw.y + 1),
						EMPTY)
			# Legs.
			for x in [7, 10, 13]:
				_box(g, MONSTER, x, 20, x, 21, SHADE)
			_finish(g, MONSTER, Vector2(8, 14))
			_eyes(g, MONSTER, Vector2i(8, 12), Vector2i(12, 12), 1)
		"knight":
			# Caped figure: the cape is the silhouette, the arms stay short so
			# they read as arms rather than columns.
			_triangle(g, MONSTER, Vector2(12, 8), Vector2(1, 22), Vector2(23, 22), BASE)
			_box(g, MONSTER, 8, 8, 15, 21, BASE)
			_box(g, MONSTER, 5, 11, 7, 17, BASE)
			_box(g, MONSTER, 16, 11, 18, 17, BASE)
			_ellipse(g, MONSTER, 12.0, 6.0, 4.2, 4.5, BASE)
			_triangle(g, MONSTER, Vector2(8, 4), Vector2(4, 0), Vector2(10, 2), BASE)
			_triangle(g, MONSTER, Vector2(16, 4), Vector2(20, 0), Vector2(14, 2), BASE)
			_finish(g, MONSTER, Vector2(9, 5))
			_box(g, MONSTER, 9, 5, 14, 8, BLACK)
			_px(g, MONSTER, 10, 6, ACCENT)
			_px(g, MONSTER, 13, 6, ACCENT)
			_box(g, MONSTER, 9, 12, 14, 13, ACCENT)
		"dragon":
			_ellipse(g, MONSTER, 12.0, 14.0, 7.5, 7.0, BASE)
			_ellipse(g, MONSTER, 12.0, 8.0, 6.0, 5.0, BASE)
			# Snout.
			_box(g, MONSTER, 9, 9, 14, 12, BASE)
			# Horns and wings.
			_triangle(g, MONSTER, Vector2(7, 5), Vector2(3, 0), Vector2(10, 3), BASE)
			_triangle(g, MONSTER, Vector2(17, 5), Vector2(21, 0), Vector2(14, 3), BASE)
			_triangle(g, MONSTER, Vector2(5, 12), Vector2(0, 8), Vector2(1, 20), BASE)
			_triangle(g, MONSTER, Vector2(19, 12), Vector2(24, 8), Vector2(23, 20), BASE)
			_box(g, MONSTER, 5, 20, 18, 22, BASE)
			_finish(g, MONSTER, Vector2(9, 8))
			_eyes(g, MONSTER, Vector2i(9, 8), Vector2i(15, 8), 2)
			_px(g, MONSTER, 9, 8, ACCENT)
			_px(g, MONSTER, 15, 8, ACCENT)
			# Teeth.
			for x in [10, 12, 14]:
				_px(g, MONSTER, x, 13, WHITE)
	return g


# --- 캐릭터 실루엣 --------------------------------------------------------

## `facing` is one of down/up/left/right; `step` alternates the legs.
func _build_character(facing: String, step: int, hat: bool) -> PackedByteArray:
	var g := _grid(CHAR)
	# Cloak, head, and legs that swap which one is forward.
	_box(g, CHAR, 4, 7, 11, 12, BASE)
	_box(g, CHAR, 3, 8, 12, 11, BASE)
	_ellipse(g, CHAR, 8.0, 4.5, 3.8, 3.8, BASE)
	var lift := 1 if step == 0 else 0
	_box(g, CHAR, 5, 13, 6, 15 - lift, SHADE)
	_box(g, CHAR, 9, 13, 10, 14 + lift, SHADE)
	_finish(g, CHAR, Vector2(6, 3))

	# Face goes on after the outline pass so it stays crisp. Facing up shows
	# the back of the head, which is how you read direction at 16 pixels.
	match facing:
		"down":
			_box(g, CHAR, 6, 4, 9, 6, ACCENT)
			_px(g, CHAR, 6, 5, BLACK)
			_px(g, CHAR, 9, 5, BLACK)
		"up":
			pass
		"left":
			_box(g, CHAR, 5, 4, 7, 6, ACCENT)
			_px(g, CHAR, 5, 5, BLACK)
		"right":
			_box(g, CHAR, 8, 4, 10, 6, ACCENT)
			_px(g, CHAR, 10, 5, BLACK)
	if hat:
		# A three-point crown, so the save point is obvious across a room.
		_box(g, CHAR, 4, 1, 11, 2, ACCENT)
		for x in [4, 7, 11]:
			_px(g, CHAR, x, 0, ACCENT)
	_box(g, CHAR, 5, 10, 10, 10, ACCENT)
	return g


# --- 이미지 출력 ----------------------------------------------------------

func _palette(style: Array) -> Dictionary:
	return {
		EMPTY: Color(0, 0, 0, 0),
		BASE: Color(style[0]),
		SHADE: Color(style[1]),
		LIGHT: Color(style[2]),
		ACCENT: Color(style[3]),
		WHITE: Color(0.96, 0.96, 0.92),
		BLACK: Color(0.09, 0.08, 0.12),
		OUTLINE: Color(0.07, 0.06, 0.10),
	}


func _blit(image: Image, grid: PackedByteArray, size: int, ox: int, oy: int,
		palette: Dictionary) -> void:
	for y in size:
		for x in size:
			image.set_pixel(ox + x, oy + y, palette[grid[y * size + x]])


func _write_monsters() -> void:
	var image := Image.create(MONSTER * MONSTER_ORDER.size(), MONSTER, false,
			Image.FORMAT_RGBA8)
	for index in MONSTER_ORDER.size():
		var style: Array = MONSTER_STYLE[MONSTER_ORDER[index]]
		var grid := _build_monster(style[0])
		_blit(image, grid, MONSTER, index * MONSTER, 0, _palette(style.slice(1)))
	image.save_png("%s/monsters.png" % ART_DIR)


func _write_hero() -> void:
	var facings := ["down", "up", "left", "right"]
	var image := Image.create(CHAR * 2, CHAR * facings.size(), false, Image.FORMAT_RGBA8)
	for row in facings.size():
		for step in 2:
			var grid := _build_character(facings[row], step, false)
			_blit(image, grid, CHAR, step * CHAR, row * CHAR, _palette(HERO_STYLE))
	image.save_png("%s/hero.png" % ART_DIR)


func _write_npcs() -> void:
	var image := Image.create(CHAR * NPC_ORDER.size(), CHAR, false, Image.FORMAT_RGBA8)
	for index in NPC_ORDER.size():
		var role: String = NPC_ORDER[index]
		var grid := _build_character("down", 0, role == "king")
		_blit(image, grid, CHAR, index * CHAR, 0, _palette(NPC_STYLE[role]))
	image.save_png("%s/npcs.png" % ART_DIR)
