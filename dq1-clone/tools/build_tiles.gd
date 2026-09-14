## Generates the placeholder terrain atlas.
##
##   godot --headless --path . --script res://tools/build_tiles.gd
##   godot --headless --path . --import          # import the new PNG
##
## One 16x16 tile per Terrain.Type, laid out in a single row. Replacing this
## with a real CC0 tileset later means swapping the PNG and keeping the order.
extends SceneTree

const TILE := 16
const OUT_PATH := "res://view_2d/field/terrain_tiles.png"

# base colour, accent colour, pattern name
const TILES := [
	[Color("c9b98c"), Color("b4a274"), "dots"],      # PLAIN
	[Color("6aa84f"), Color("548a3c"), "tufts"],     # GRASS
	[Color("2f6b32"), Color("1d4a20"), "trees"],     # FOREST
	[Color("9c7a4a"), Color("7d5f36"), "bumps"],     # HILL
	[Color("5a6b3a"), Color("3d4a26"), "blotches"],  # SWAMP
	[Color("2a5fa8"), Color("3f78c4"), "waves"],     # WATER
	[Color("4a4a55"), Color("33333c"), "bricks"],    # WALL
	[Color("7a6a55"), Color("665742"), "dots"],      # FLOOR
	[Color("8a6a3a"), Color("6b5029"), "planks"],    # BRIDGE
	[Color("b04a3a"), Color("e8e2cf"), "house"],     # TOWN
	[Color("3a3a44"), Color("15151a"), "arch"],      # CAVE
	[Color("6a6a75"), Color("50505a"), "steps"],     # STAIRS_DOWN
	[Color("9a9aa5"), Color("70707a"), "steps"],     # STAIRS_UP
	[Color("8a5a2a"), Color("5e3c18"), "door"],      # DOOR
]


func _initialize() -> void:
	var image := Image.create(TILE * TILES.size(), TILE, false, Image.FORMAT_RGBA8)
	for index in TILES.size():
		_draw_tile(image, index * TILE, TILES[index][0], TILES[index][1], TILES[index][2])

	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var err := image.save_png(OUT_PATH)
	print("[tiles] %d tiles -> %s (err=%d)" % [TILES.size(), OUT_PATH, err])
	quit(0 if err == OK else 1)


func _draw_tile(image: Image, ox: int, base: Color, accent: Color, pattern: String) -> void:
	for y in TILE:
		for x in TILE:
			image.set_pixel(ox + x, y, base)

	match pattern:
		"dots":
			for p in [Vector2i(3, 4), Vector2i(11, 6), Vector2i(6, 12), Vector2i(13, 12)]:
				_px(image, ox, p, accent)
		"tufts":
			for cx in [2, 7, 12]:
				for cy in [3, 9, 14]:
					_px(image, ox, Vector2i(cx, cy), accent)
					_px(image, ox, Vector2i(cx + 1, cy - 1), accent)
		"trees":
			for c in [Vector2i(4, 5), Vector2i(11, 4), Vector2i(8, 11)]:
				_disc(image, ox, c, 3, accent)
		"bumps":
			for c in [Vector2i(4, 10), Vector2i(11, 9)]:
				_arc(image, ox, c, 4, accent)
		"blotches":
			for c in [Vector2i(5, 6), Vector2i(11, 11)]:
				_disc(image, ox, c, 3, accent)
		"waves":
			for y in [3, 8, 13]:
				for x in range(1, 15):
					if (x + y) % 4 < 2:
						_px(image, ox, Vector2i(x, y), accent)
		"bricks":
			for y in [0, 5, 10, 15]:
				for x in TILE:
					_px(image, ox, Vector2i(x, y), accent)
			for y in range(TILE):
				var offset := 0 if (y / 5) % 2 == 0 else 8
				_px(image, ox, Vector2i((offset + 3) % TILE, y), accent)
		"planks":
			for x in [0, 5, 10, 15]:
				for y in TILE:
					_px(image, ox, Vector2i(x, y), accent)
		"house":
			for y in range(4, 14):
				for x in range(3, 13):
					_px(image, ox, Vector2i(x, y), accent)
			for y in range(2, 5):
				for x in range(2 + (4 - y), 14 - (4 - y)):
					_px(image, ox, Vector2i(x, y), Color("6b2f24"))
			for y in range(9, 14):
				for x in range(7, 10):
					_px(image, ox, Vector2i(x, y), Color("6b2f24"))
		"arch":
			_disc(image, ox, Vector2i(8, 9), 5, accent)
			for y in range(9, 15):
				for x in range(4, 13):
					_px(image, ox, Vector2i(x, y), accent)
		"steps":
			for i in 4:
				for x in range(2 + i, 14):
					_px(image, ox, Vector2i(x, 3 + i * 3), accent)
		"door":
			for y in range(3, 15):
				for x in range(4, 12):
					_px(image, ox, Vector2i(x, y), accent)
			_px(image, ox, Vector2i(10, 9), Color("e8c84a"))


func _px(image: Image, ox: int, p: Vector2i, color: Color) -> void:
	if p.x < 0 or p.y < 0 or p.x >= TILE or p.y >= TILE:
		return
	image.set_pixel(ox + p.x, p.y, color)


func _disc(image: Image, ox: int, center: Vector2i, radius: int, color: Color) -> void:
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if Vector2(x - center.x, y - center.y).length() <= float(radius):
				_px(image, ox, Vector2i(x, y), color)


func _arc(image: Image, ox: int, center: Vector2i, radius: int, color: Color) -> void:
	for x in range(center.x - radius, center.x + radius + 1):
		var dx := float(x - center.x) / float(radius)
		var y := center.y - int(round(sqrt(maxf(0.0, 1.0 - dx * dx)) * radius))
		_px(image, ox, Vector2i(x, y), color)
		_px(image, ox, Vector2i(x, y + 1), color)
