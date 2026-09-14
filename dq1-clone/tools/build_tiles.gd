## Generates the terrain atlas.
##
##   godot --headless --path . --script res://tools/build_tiles.gd
##   godot --headless --path . --import          # import the new PNG
##
## One 16x16 tile per Terrain.Type, in a single row.
##
## The look is the NES original's, and the thing that makes it read that way is
## not the colours — it is that **the patterns repeat**. A field tile is drawn
## once and then stamped a thousand times across the map, so a motif at fixed
## positions reads as grass; the same motif scattered at random reads as dirt,
## or as static. The first pass here used a seeded RNG for texture and looked
## modern and noisy for exactly that reason. There is no randomness left in the
## terrain patterns: every tile is a deliberate arrangement that lines up with
## its own edges, so a field of them has no seams and no noise.
##
## The palette is NES-shaped too — few colours, high contrast, saturated. Each
## field tile uses three: a flat base, a dark and a light. Icons get a fourth.
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
	["e0a860", "a86820", "fcd8a8", "704214", "sand"],       # PLAIN
	["00a800", "007800", "58d854", "004400", "grass"],      # GRASS
	["006800", "003800", "00a800", "50300c", "forest"],     # FOREST
	["886800", "503000", "bc9038", "302000", "hill"],       # HILL
	["506800", "303800", "789838", "203000", "swamp"],      # SWAMP
	["0058f8", "0000bc", "3cbcfc", "a4e4fc", "water"],      # WATER
	["787878", "3c3c3c", "bcbcbc", "202020", "wall"],       # WALL
	["987858", "604830", "c0a080", "402810", "floor"],      # FLOOR
	["a05820", "683810", "c88040", "402000", "bridge"],     # BRIDGE
	["d82800", "881000", "fc7460", "f8f8f8", "town"],       # TOWN
	["303030", "101010", "585858", "000000", "cave"],       # CAVE
	["686868", "383838", "a0a0a0", "181818", "down"],       # STAIRS_DOWN
	["a8a8a8", "686868", "e0e0e0", "303030", "up"],         # STAIRS_UP
	["a85820", "683008", "d88840", "fcd800", "door"],       # DOOR
	["986018", "583000", "d8a040", "fcf0a0", "chest"],      # CHEST
]

## The overworld colours the icon tiles sit on, so a town or a cave mouth is a
## thing standing in a field rather than a square cut out of one.
const FIELD_BASE := "00a800"
const FIELD_DARK := "007800"
const FIELD_LIGHT := "58d854"

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
## The upright versions, for the 2.5D view. Same palette as the tiles they
## stand on — a billboard in the old colours next to a tile in the new ones is
## the one place the difference is impossible to miss.
func _draw_prop(ox: int, name: String) -> void:
	match name:
		"tree":
			_rect(ox, 7, 11, 8, 15, Color("50300c"))
			_disc(ox, 8.0, 6.5, 5.2, Color("003800"))
			_disc(ox, 8.0, 6.5, 4.2, Color("006800"))
			_disc(ox, 6.5, 5.0, 2.2, Color("00a800"))
			_disc(ox, 5.0, 9.5, 2.6, Color("006800"))
			_disc(ox, 11.0, 9.5, 2.6, Color("006800"))
			_px(ox, 4, 9, Color("003800"))
			_px(ox, 12, 9, Color("003800"))
		"house":
			_rect(ox, 2, 7, 13, 15, Color("e0a860"))
			_rect(ox, 2, 7, 2, 15, Color("a86820"))
			_rect(ox, 13, 7, 13, 15, Color("a86820"))
			for y in range(2, 8):
				_rect(ox, y - 2, y, 17 - y, y, Color("d82800"))
			_rect(ox, 0, 7, 15, 7, Color("881000"))
			_rect(ox, 6, 10, 9, 15, Color("704214"))
			_px(ox, 9, 13, Color("f8d878"))
			_rect(ox, 3, 9, 4, 10, Color("0058f8"))
			_rect(ox, 11, 9, 12, 10, Color("0058f8"))
		"cave":
			_disc(ox, 8.0, 10.0, 7.0, Color("585858"))
			_disc(ox, 8.0, 10.0, 6.0, Color("303030"))
			_rect(ox, 2, 10, 13, 15, Color("303030"))
			_disc(ox, 8.0, 11.0, 4.2, Color("000000"))
			_rect(ox, 4, 11, 11, 15, Color("000000"))
		"door":
			_rect(ox, 3, 2, 12, 15, Color("683008"))
			_rect(ox, 4, 3, 11, 15, Color("a85820"))
			for x in [6, 9]:
				_rect(ox, x, 4, x, 15, Color("d88840"))
			_disc(ox, 10.0, 9.0, 1.4, Color("fcd800"))
		"chest":
			_rect(ox, 2, 6, 13, 14, Color("986018"))
			_rect(ox, 2, 6, 13, 9, Color("d8a040"))
			_rect(ox, 2, 6, 13, 6, Color("583000"))
			_rect(ox, 2, 10, 13, 10, Color("583000"))
			_rect(ox, 2, 14, 13, 14, Color("583000"))
			_rect(ox, 2, 6, 2, 14, Color("583000"))
			_rect(ox, 13, 6, 13, 14, Color("583000"))
			_rect(ox, 7, 10, 8, 13, Color("583000"))
			_px(ox, 7, 11, Color("fcf0a0"))
			_px(ox, 8, 11, Color("fcf0a0"))


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


## The overworld under an icon tile, so a town is a thing in a field.
func _field(ox: int) -> void:
	_fill(ox, Color(FIELD_BASE))
	_tufts(ox, Color(FIELD_DARK), Color(FIELD_LIGHT))


## Two tufts of grass at fixed places. Fixed is the point — see the note at
## the top of this file.
func _tufts(ox: int, dark: Color, light: Color) -> void:
	for at in [Vector2i(3, 4), Vector2i(11, 11)]:
		_px(ox, at.x, at.y, light)
		_px(ox, at.x - 1, at.y + 1, light)
		_px(ox, at.x + 1, at.y + 1, light)
		_px(ox, at.x, at.y + 1, dark)
	for at in [Vector2i(12, 3), Vector2i(4, 12)]:
		_px(ox, at.x, at.y, dark)


## A handful of single pixels at named places, for the odd highlight that a
## pattern would make too regular.
func _scatter_free(ox: int, color: Color, at: Array) -> void:
	for point in at:
		_px(ox, point.x, point.y, color)


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
		"sand":
			# Four dashes, spread so no two land in the same row or column.
			for at in [Vector2i(2, 3), Vector2i(10, 2), Vector2i(6, 9), Vector2i(13, 12)]:
				_rect(ox, at.x, at.y, at.x + 1, at.y, dark)
				_px(ox, at.x, at.y + 1, light)
		"grass":
			_tufts(ox, dark, light)
		"forest":
			# Four canopies on a 8x8 lattice. Their centres are half a tile
			# apart, so the tile lines up with a copy of itself in both
			# directions and a wood reads as continuous canopy.
			for at in [Vector2i(4, 4), Vector2i(12, 4), Vector2i(4, 12), Vector2i(12, 12)]:
				_disc(ox, at.x, at.y, 3.6, dark)
				_disc(ox, at.x, at.y, 2.6, light)
				_px(ox, at.x - 1, at.y - 2, light)
				_px(ox, at.x, at.y + 3, accent)
		"hill":
			# Two rows of humps, offset by half so the rows interlock.
			for row in 2:
				var y := 5 + row * 7
				var offset := row * 4
				for hump in 2:
					var cx := offset + 3 + hump * 8
					for dx in range(-3, 4):
						var top := y - int(round(sqrt(maxf(0.0, 9.0 - dx * dx))))
						_px(ox, cx + dx, top, light)
						_px(ox, cx + dx, top + 1, dark)
		"swamp":
			# Bands of standing water, with a bubble caught in each.
			for row in 3:
				var y := 2 + row * 5
				for x in TILE:
					if (x + row * 3) % 4 < 3:
						_px(ox, x, y, dark)
				_px(ox, 3 + row * 5, y - 1, light)
			_scatter_free(ox, light, [Vector2i(1, 7), Vector2i(9, 12), Vector2i(13, 3)])
		"water":
			# Horizontal crests, every fourth row, alternating phase. Flat
			# water with a repeating wave is the whole NES ocean.
			for row in 4:
				var y := 1 + row * 4
				var phase := (row % 2) * 4
				for x in TILE:
					if (x + phase) % 8 < 4:
						_px(ox, x, y, light)
						_px(ox, x, y + 1, dark)
		"wall":
			# Running-bond brick: every other course offset by half a brick.
			for course in 4:
				var y := course * 4
				_rect(ox, 0, y, 15, y, accent)
				var offset := 0 if course % 2 == 0 else 4
				for x in range(offset, 16, 8):
					_rect(ox, x, y + 1, x, y + 3, accent)
				for x in range(offset + 1, 16, 8):
					_rect(ox, x, y + 1, x, y + 1, light)
		"floor":
			# Flagstones: a grid of four, grouted dark, lit from the top left.
			for at in [Vector2i(0, 0), Vector2i(8, 0), Vector2i(0, 8), Vector2i(8, 8)]:
				_rect(ox, at.x, at.y, at.x + 7, at.y, dark)
				_rect(ox, at.x, at.y, at.x, at.y + 7, dark)
				_rect(ox, at.x + 1, at.y + 1, at.x + 6, at.y + 1, light)
		"bridge":
			for x in [0, 5, 10, 15]:
				_rect(ox, x, 0, x, 15, accent)
			_rect(ox, 0, 1, 15, 1, dark)
			_rect(ox, 0, 14, 15, 14, dark)
			for x in range(2, 15, 5):
				_rect(ox, x, 3, x + 2, 3, light)
		"town":
			# A walled town seen from above, standing in the field.
			_field(ox)
			_rect(ox, 2, 6, 13, 14, base)
			_rect(ox, 2, 6, 13, 6, dark)
			_rect(ox, 2, 14, 13, 14, dark)
			_rect(ox, 2, 6, 2, 14, dark)
			_rect(ox, 13, 6, 13, 14, dark)
			for x in range(3, 13, 3):
				_rect(ox, x, 3, x + 1, 5, base)
				_rect(ox, x, 3, x + 1, 3, light)
			_rect(ox, 7, 10, 8, 14, accent)
		"cave":
			# A mouth in a hillside: rock, then a hole that goes nowhere.
			_field(ox)
			_disc(ox, 8.0, 10.0, 6.4, light)
			_rect(ox, 2, 10, 13, 15, light)
			_disc(ox, 8.0, 10.5, 5.2, base)
			_rect(ox, 3, 11, 12, 15, base)
			_disc(ox, 8.0, 12.0, 3.4, accent)
			_rect(ox, 5, 12, 10, 15, accent)
		"down", "up":
			# Four flights. Down steps away from the viewer and up towards,
			# which at this size is entirely a matter of which way the treads
			# narrow.
			var steps := 4
			for i in steps:
				var y := i * 4
				var inset: int = i if spec[4] == "down" else steps - 1 - i
				_rect(ox, inset, y, 15 - inset, y + 2, light)
				_rect(ox, inset, y + 3, 15 - inset, y + 3, dark)
				_rect(ox, inset, y, inset, y + 3, dark)
				_rect(ox, 15 - inset, y, 15 - inset, y + 3, dark)
		"door":
			_fill(ox, Color(FIELD_DARK))
			_rect(ox, 2, 1, 13, 15, base)
			_rect(ox, 2, 1, 2, 15, dark)
			_rect(ox, 13, 1, 13, 15, dark)
			_rect(ox, 2, 1, 13, 1, dark)
			for x in [5, 8, 11]:
				_rect(ox, x, 2, x, 15, light)
			_disc(ox, 11.0, 9.0, 1.4, accent)
		"chest":
			_fill(ox, Color(FIELD_DARK))
			_rect(ox, 2, 5, 13, 14, base)
			_rect(ox, 2, 5, 13, 8, light)
			_rect(ox, 2, 5, 13, 5, dark)
			_rect(ox, 2, 9, 13, 9, dark)
			_rect(ox, 2, 14, 13, 14, dark)
			_rect(ox, 2, 5, 2, 14, dark)
			_rect(ox, 13, 5, 13, 14, dark)
			_rect(ox, 7, 9, 8, 12, dark)
			_px(ox, 7, 10, accent)
			_px(ox, 8, 10, accent)
