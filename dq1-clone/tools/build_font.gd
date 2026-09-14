## Builds the Theme every window and Label draws with.
##
## The .ttf files come from tools/build_font.py; their rasterisation settings
## live in the .import files next to them, which is where Godot keeps them.
## All that is left for this step is the Theme — the one place that decides
## the game's default font and size.
extends SceneTree

## The canvas is 512x384 upscaled by an integer factor, so every glyph is
## rasterised once at this size and then blown up. 11px is the smallest size
## at which the jamo of a Hangul syllable stay apart; the Latin text grew
## with it rather than the game carrying two sets of metrics.
const FONT_SIZE := 11
const REGULAR := "res://assets/fonts/NotoSansKR-Regular-subset.ttf"


func _init() -> void:
	var font: Font = load(REGULAR)
	if font == null:
		printerr("[font] %s is missing. Run tools/build_font.py, then --import." % REGULAR)
		quit(1)
		return

	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = FONT_SIZE
	var path := "res://assets/theme/dq_theme.tres"
	if ResourceSaver.save(theme, path) != OK:
		printerr("[font] could not write %s" % path)
		quit(1)
		return
	print("[font] %s at %dpx" % [path, FONT_SIZE])
	quit(0)
