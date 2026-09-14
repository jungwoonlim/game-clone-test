## Generates the terrain atlas.
##
##   godot --headless --path . --script res://tools/build_tiles.gd
##   godot --headless --path . --import          # import the new PNG
##
## One 16x16 tile per Terrain.Type, in a single row. Everything is drawn from a
## seeded RNG so the atlas is byte-identical every run — a noisy texture that
## changed on every build would make every commit look like an art change.
extends SceneTree

const TILE := ArtSpec.TILE
const OUT_PATH: String = ArtSpec.SHEETS[&"tiles"]["path"]
## Upright versions of the tiles that become billboards in the 2.5D view.
## Same motifs, transparent background — a standing billboard must not carry
## its own patch of ground with it.
const PROPS_PATH: String = ArtSpec.SHEETS[&"props"]["path"]
const PROPS := ["tree", "house", "cave", "door", "chest"]
const SEED := 611

## base, dark, light, accent — order matches Terrain.Type.
const TILES := [
	["c3b184", "ab9868", "d8c9a4", "8d7a4e", "speckle"],    # PLAIN
	["5f9f47", "4a8036", "79bb5c", "3a6a28", "grass"],      # GRASS
	["2f6b32", "1c4a20", "418f44", "5a3a1e", "forest"],     # FOREST
	["9a7b4c", "7c6038", "b99a68", "6a5028", "hill"],       # HILL
	["566b39", "3c4c25", "6d8449", "2d3a1b", "swamp"],      # SWAMP
	["2a5fa8", "1d4a8c", "4a86d0", "8fc0f0", "water"],      # WATER
	["4b4b58", "32323d", "656573", "23232c", "wall"],       # WALL
	["7b6b56", "615340", "958471", "4a3e2f", "floor"],      # FLOOR
	["8a6a3a", "6b5029", "a8875a", "4a3418", "bridge"],     # BRIDGE
	["b04a3a", "7e2f24", "d4705c", "e8e2cf", "town"],       # TOWN
	["3a3a44", "16161c", "55555f", "0b0b10", "cave"],       # CAVE
	["6a6a75", "43434d", "8c8c98", "24242c", "down"],       # STAIRS_DOWN
	["9a9aa5", "6e6e79", "bcbcc6", "34343c", "up"],         # STAIRS_UP
	["8a5a2a", "5e3c18", "ab7640", "e8c84a", "door"],       # DOOR
	["7b6b56", "5e3c18", "a8761f", "f0e08a", "chest"],      # CHEST
]

var _rng := RandomNumberGenerator.new()
var _image: Image


func _initialize() -> void:
	_rng.seed = SEED
	_image = Image.create(TILE * TILES.size(), TILE, false, Image.FORMAT_RGBA8)
	for index in TILES.size():
		_draw_tile(index * TILE, TILES[index])

	DirAccess.make_dir_recursive_absolute(OUT_PATH.get_base_dir())
	var err := _image.save_png(OUT_PATH)

	_image = Image.create(TILE * PROPS.size(), TILE, false, Image.FORMAT_RGBA8)
	for index in PROPS.size():
		_draw_prop(index * TILE, PROPS[index])
	var prop_err := _image.save_png(PROPS_PATH)

	print("[tiles] %d tiles, %d props (err=%d/%d)" % [
		TILES.size(), PROPS.size(), err, prop_err])
	quit(0 if err == OK and prop_err == OK else 1)


## Drawn standing up, so these read from the side rather than from above.
func _draw_prop(ox: int, name: String) -> void:
	match name:
		"tree":
			_rect(ox, 7, 10, 8, 15, Color("5a3a1e"))
			_disc(ox, 8.0, 6.0, 5.0, Color("1c4a20"))
			_disc(ox, 8.0, 6.0, 4.0, Color("2f6b32"))
			_disc(ox, 6.0, 4.5, 2.0, Color("418f44"))
			_disc(ox, 5.0, 9.0, 2.6, Color("2f6b32"))
			_disc(ox, 11.0, 9.0, 2.6, Color("2f6b32"))
		"house":
			_rect(ox, 2, 7, 13, 15, Color("d8c9a4"))
			_rect(ox, 2, 7, 2, 15, Color("ab9868"))
			_rect(ox, 13, 7, 13, 15, Color("ab9868"))
			for y in range(2, 8):
				_rect(ox, y - 2, y, 17 - y, y, Color("b04a3a"))
			_rect(ox, 0, 7, 15, 7, Color("7e2f24"))
			_rect(ox, 6, 10, 9, 15, Color("5e3c18"))
			_px(ox, 9, 13, Color("e8c84a"))
			_rect(ox, 3, 9, 4, 10, Color("2a5fa8"))
			_rect(ox, 11, 9, 12, 10, Color("2a5fa8"))
		"cave":
			_disc(ox, 8.0, 10.0, 7.0, Color("55555f"))
			_disc(ox, 8.0, 10.0, 6.0, Color("3a3a44"))
			_rect(ox, 2, 10, 13, 15, Color("3a3a44"))
			_disc(ox, 8.0, 11.0, 4.2, Color("0b0b10"))
			_rect(ox, 4, 11, 11, 15, Color("0b0b10"))
		"door":
			_rect(ox, 3, 2, 12, 15, Color("5e3c18"))
			_rect(ox, 4, 3, 11, 15, Color("8a5a2a"))
			for x in [6, 9]:
				_rect(ox, x, 4, x, 15, Color("ab7640"))
			_disc(ox, 10.0, 9.0, 1.4, Color("e8c84a"))
		"chest":
			_rect(ox, 2, 6, 13, 14, Color("a8761f"))
			_rect(ox, 2, 6, 13, 9, Color("c9913a"))
			_rect(ox, 2, 6, 13, 6, Color("5e3c18"))
			_rect(ox, 2, 10, 13, 10, Color("5e3c18"))
			_rect(ox, 2, 14, 13, 14, Color("5e3c18"))
			_rect(ox, 2, 6, 2, 14, Color("5e3c18"))
			_rect(ox, 13, 6, 13, 14, Color("5e3c18"))
			_rect(ox, 7, 10, 8, 13, Color("5e3c18"))
			_px(ox, 7, 11, Color("f0e08a"))
			_px(ox, 8, 11, Color("f0e08a"))


# --- 유틸 -----------------------------------------------------------------

func _px(ox: int, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= TILE or y >= TILE:
		return
	_image.set_pixel(ox + x, y, color)


func _fill(ox: int, color: Color) -> void:
	for y in TILE:
		for x in TILE:
			_px(ox, x, y, color)


func _rect(ox: int, x0: int, y0: int, x1: int, y1: int, color: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_px(ox, x, y, color)


## Scatters `color` over the tile. The checker offset keeps it looking like
## texture rather than random dots.
func _scatter(ox: int, color: Color, density: float) -> void:
	for y in TILE:
		for x in TILE:
			if _rng.randf() < density:
				_px(ox, x, y, color)


func _disc(ox: int, cx: float, cy: float, radius: float, color: Color) -> void:
	for y in TILE:
		for x in TILE:
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= radius:
				_px(ox, x, y, color)


func _draw_tile(ox: int, spec: Array) -> void:
	var base := Color(spec[0])
	var dark := Color(spec[1])
	var light := Color(spec[2])
	var accent := Color(spec[3])
	_fill(ox, base)

	match spec[4]:
		"speckle":
			_scatter(ox, dark, 0.10)
			_scatter(ox, light, 0.06)
		"grass":
			_scatter(ox, dark, 0.10)
			for tuft in 7:
				var x := _rng.randi_range(1, 14)
				var y := _rng.randi_range(1, 14)
				_px(ox, x, y, light)
				_px(ox, x, y - 1, light)
				_px(ox, x + 1, y, dark)
		"forest":
			_scatter(ox, dark, 0.2)
			for canopy in [Vector2(4.5, 5.0), Vector2(11.5, 4.0), Vector2(8.0, 11.5)]:
				_disc(ox, canopy.x, canopy.y, 3.4, dark)
				_disc(ox, canopy.x, canopy.y, 2.6, base)
				_disc(ox, canopy.x - 0.8, canopy.y - 0.8, 1.3, light)
				_px(ox, int(canopy.x), int(canopy.y) + 4, accent)
		"hill":
			_scatter(ox, dark, 0.08)
			for ridge in [Vector2(4.0, 9.0), Vector2(11.0, 12.0)]:
				for x in range(int(ridge.x) - 4, int(ridge.x) + 5):
					var dx: float = (x + 0.5 - ridge.x) / 4.0
					var y: int = int(ridge.y - sqrt(maxf(0.0, 1.0 - dx * dx)) * 3.5)
					_px(ox, x, y, light)
					_px(ox, x, y + 1, dark)
		"swamp":
			_scatter(ox, dark, 0.22)
			for bubble in [Vector2(4.5, 6.0), Vector2(11.0, 10.0), Vector2(7.5, 13.0)]:
				_disc(ox, bubble.x, bubble.y, 1.8, dark)
				_px(ox, int(bubble.x), int(bubble.y) - 1, light)
		"water":
			for y in TILE:
				for x in TILE:
					if (x + y * 3) % 16 < 2:
						_px(ox, x, y, dark)
			for y in [2, 7, 12]:
				for x in range(1, 15):
					if (x + y) % 5 < 2:
						_px(ox, x, y, light)
						_px(ox, x + 1, y + 1, accent)
		"wall":
			# Running-bond brick: every other course is offset by half a brick.
			for course in 4:
				var y := course * 4
				_rect(ox, 0, y, 15, y, accent)
				var offset := 0 if course % 2 == 0 else 4
				for x in range(offset, 16, 8):
					_rect(ox, x, y + 1, x, y + 3, accent)
				for x in range(offset + 1, 16, 8):
					_px(ox, x, y + 1, light)
			_scatter(ox, dark, 0.07)
		"floor":
			_scatter(ox, dark, 0.12)
			_scatter(ox, light, 0.05)
			for crack in 2:
				var x := _rng.randi_range(2, 12)
				var y := _rng.randi_range(2, 12)
				for step in 4:
					_px(ox, x + step, y + (step % 2), accent)
		"bridge":
			for x in [0, 5, 10, 15]:
				_rect(ox, x, 0, x, 15, accent)
			_rect(ox, 0, 1, 15, 1, dark)
			_rect(ox, 0, 14, 15, 14, dark)
			_scatter(ox, light, 0.05)
		"town":
			_fill(ox, Color(spec[1]).lerp(Color("5f9f47"), 0.55))
			_rect(ox, 2, 6, 13, 14, accent)
			for y in range(2, 7):
				_rect(ox, 1 + (y - 2), 8 - (y - 2), 14 - (y - 2), 8 - (y - 2), base)
			_rect(ox, 6, 10, 9, 14, dark)
			_px(ox, 9, 12, Color("e8c84a"))
			_rect(ox, 3, 8, 4, 9, base)
			_rect(ox, 11, 8, 12, 9, base)
		"cave":
			_scatter(ox, light, 0.10)
			_disc(ox, 8.0, 9.0, 5.2, dark)
			_rect(ox, 3, 9, 12, 15, dark)
			_disc(ox, 8.0, 9.5, 3.6, accent)
			_rect(ox, 5, 10, 10, 15, accent)
		"down", "up":
			var steps := 4
			for i in steps:
				var y := 1 + i * 4
				var inset: int = i if spec[4] == "down" else steps - 1 - i
				_rect(ox, inset, y, 15 - inset, y + 2, light if i % 2 == 0 else base)
				_rect(ox, inset, y + 3, 15 - inset, y + 3, dark)
			_scatter(ox, accent, 0.05)
		"door":
			_fill(ox, Color(spec[1]))
			_rect(ox, 2, 1, 13, 15, base)
			_rect(ox, 2, 1, 2, 15, dark)
			_rect(ox, 13, 1, 13, 15, dark)
			_rect(ox, 2, 1, 13, 1, dark)
			for x in [5, 8, 11]:
				_rect(ox, x, 2, x, 15, light)
			_disc(ox, 11.0, 9.0, 1.4, accent)
		"chest":
			_fill(ox, Color(spec[0]))
			_scatter(ox, Color(spec[0]).darkened(0.15), 0.1)
			_rect(ox, 2, 5, 13, 14, Color("a8761f"))
			_rect(ox, 2, 5, 13, 8, Color("c9913a"))
			_rect(ox, 2, 5, 13, 5, dark)
			_rect(ox, 2, 9, 13, 9, dark)
			_rect(ox, 2, 14, 13, 14, dark)
			_rect(ox, 2, 5, 2, 14, dark)
			_rect(ox, 13, 5, 13, 14, dark)
			_rect(ox, 7, 9, 8, 12, dark)
			_px(ox, 7, 10, accent)
			_px(ox, 8, 10, accent)
