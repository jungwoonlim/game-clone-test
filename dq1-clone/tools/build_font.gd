## Builds the Theme every window and Label draws with.
##
## The .ttf files come from tools/build_font.py. This step reads one of them
## and bakes it **into** the Theme as a built-in resource.
##
## Baking rather than referencing matters more than it looks. A Theme that
## points at `res://assets/fonts/....ttf` does not point at the file — it
## points at what Godot's importer makes of it, under .godot/, which is not in
## the repository. A fresh clone therefore had to be imported twice before it
## would run: once to produce the font, once for the Theme to find it. Until
## then the project came up with no theme and a pile of parse errors. Baked in,
## the Theme is a plain resource that loads from the file itself.
extends SceneTree

## The canvas is 512x384 upscaled by an integer factor, so every glyph is
## rasterised once at this size and then blown up. 11px is the smallest size
## at which the jamo of a Hangul syllable stay apart; the Latin text grew
## with it rather than the game carrying two sets of metrics.
const FONT_SIZE := 11
const REGULAR := "res://assets/fonts/NotoSansKR-Regular-subset.ttf"
const THEME := "res://assets/theme/dq_theme.tres"


func _init() -> void:
	if not FileAccess.file_exists(REGULAR):
		printerr("[font] %s is missing. Run tools/build_font.py first." % REGULAR)
		quit(1)
		return

	var font := FontFile.new()
	font.load_dynamic_font(REGULAR)
	# Hinting and subpixel placement fight the integer upscale: they move
	# stems onto half-pixels that the 2x blit then smears. Off is crisper.
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.force_autohinter = false
	font.multichannel_signed_distance_field = false
	# Never reach past this font: a glyph we did not ship must look missing
	# here, not borrow a shape from whatever the player happens to have.
	font.fallbacks = []

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = FONT_SIZE
	if ResourceSaver.save(theme, THEME) != OK:
		printerr("[font] could not write %s" % THEME)
		quit(1)
		return
	print("[font] %s at %dpx, font baked in" % [THEME, FONT_SIZE])
	quit(0)
