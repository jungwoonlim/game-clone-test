## Draws the art contract as a picture: every sheet, every cell, labelled.
##
##   xvfb-run -a godot --path . --rendering-driver opengl3 \
##       --script res://tools/build_art_guide.gd
##
## ArtSpec says a sheet is "fifteen 16px cells in Terrain.Type order". That is
## exact and unreadable. Whoever draws the replacement art wants to see which
## square is the swamp, so this renders the current sheets at 4x with the name
## of each cell under it, on a chequerboard that shows transparency as
## transparency.
##
## Regenerate after changing ArtSpec — it is a view of the contract, not a
## second copy of it.
extends SceneTree

const OUT_PATH := "res://docs/asset-layout.png"
const ZOOM := 4
const PAD := 10
const LABEL := 16
const HEADER := 24
const BACKGROUND := Color(0.07, 0.08, 0.12)


func _init() -> void:
	var page := ArtGuidePage.new()
	page.size = page.measure()

	var viewport := SubViewport.new()
	viewport.size = page.size
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.add_child(page)
	root.add_child(viewport)

	await process_frame
	await process_frame

	var image := viewport.get_texture().get_image()
	if image.save_png(OUT_PATH) != OK:
		printerr("[guide] could not write %s" % OUT_PATH)
		quit(1)
		return
	print("[guide] %s  %dx%d" % [OUT_PATH, image.get_width(), image.get_height()])
	quit(0)


## The page itself. A Control so the font draws the way it draws in the game.
class ArtGuidePage extends Control:
	const CHEQUER_A := Color(0.16, 0.17, 0.22)
	const CHEQUER_B := Color(0.21, 0.22, 0.28)

	var _images := {}

	func _init() -> void:
		for name in ArtSpec.SHEETS:
			var texture: Texture2D = load(ArtSpec.SHEETS[name]["path"])
			_images[name] = texture


	func measure() -> Vector2:
		var width := 0.0
		var height := float(PAD)
		for name in ArtSpec.SHEETS:
			var grid := ArtSpec.grid(name)
			var step := _step(name)
			width = maxf(width, PAD * 2 + grid.x * step)
			height += HEADER + grid.y * (_cell_pixels(name) + LABEL) + PAD
		return Vector2(maxf(width, 560.0), height)


	## Columns are as wide as their widest label, not as their picture. At 4x
	## a 16px cell is 64 wide and "11 STAIRS_DOWN" is not.
	func _step(name: StringName) -> float:
		var spec := ArtSpec.sheet(name)
		var font := get_theme_default_font()
		var widest := 0.0
		for index in spec["cells"].size():
			var label := "%d %s" % [index, spec["cells"][index]]
			widest = maxf(widest, font.get_string_size(
					label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x)
		return maxf(_cell_pixels(name), widest) + PAD


	func _cell_pixels(name: StringName) -> float:
		return float(int(ArtSpec.SHEETS[name]["cell"]) * ZOOM)


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND)
		var font := get_theme_default_font()
		var top := float(PAD)
		for name in ArtSpec.SHEETS:
			var spec := ArtSpec.sheet(name)
			var grid := ArtSpec.grid(name)
			var cell: int = spec["cell"]
			var step := _step(name)

			draw_string(font, Vector2(PAD, top + 14),
					"%s  (%dpx x %d)  —  %s" % [name, cell, spec["cells"].size(), spec["about"]],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.96, 0.9, 0.62))

			for index in spec["cells"].size():
				var at := Vector2i(index % grid.x, index / grid.x)
				var origin := Vector2(PAD + at.x * step,
						top + HEADER + at.y * (_cell_pixels(name) + LABEL))
				_chequer(origin, cell * ZOOM)
				var texture: Texture2D = _images[name]
				if texture != null:
					var source := ArtSpec.cell_rect(name, index)
					draw_texture_rect_region(texture,
							Rect2(origin, Vector2(cell * ZOOM, cell * ZOOM)),
							Rect2(source.position, source.size))
				draw_string(font, Vector2(origin.x, origin.y + cell * ZOOM + 12),
						"%d %s" % [index, spec["cells"][index]],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.78, 0.8, 0.86))

			top += HEADER + grid.y * (_cell_pixels(name) + LABEL) + PAD


	## Transparency has to look like something, or an empty cell and a black
	## cell are the same picture.
	func _chequer(origin: Vector2, side: int) -> void:
		var square := 8
		for y in range(0, side, square):
			for x in range(0, side, square):
				var dark := ((x / square) + (y / square)) % 2 == 0
				draw_rect(Rect2(origin + Vector2(x, y), Vector2(square, square)),
						CHEQUER_A if dark else CHEQUER_B)
