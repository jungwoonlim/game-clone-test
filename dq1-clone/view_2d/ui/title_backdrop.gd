## Title screen background: a night sky with a horizon, drawn in code.
extends Control

const TOP := Color("0a0c1e")
const BOTTOM := Color("1d2440")
const HORIZON := Color("0c1020")
const STAR_SEED := 7731


func _draw() -> void:
	var bands := 24
	var band_height := size.y / float(bands)
	for i in bands:
		var t := float(i) / float(bands - 1)
		draw_rect(Rect2(0, i * band_height, size.x, band_height + 1.0),
				TOP.lerp(BOTTOM, t))

	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	for i in 90:
		var star := Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.62)
		var bright: float = rng.randf_range(0.35, 1.0)
		draw_rect(Rect2(star.floor(), Vector2.ONE), Color(1, 1, 0.94, bright))

	# A low ridge so the title has ground under it.
	var horizon := size.y * 0.72
	var points := PackedVector2Array()
	points.append(Vector2(0, size.y))
	for x in range(0, int(size.x) + 8, 8):
		points.append(Vector2(x, horizon + sin(x * 0.045) * 9.0 + cos(x * 0.11) * 4.0))
	points.append(Vector2(size.x, size.y))
	draw_colored_polygon(points, HORIZON)
