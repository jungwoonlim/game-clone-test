## Placeholder monster portrait, drawn from the monster's id so every species
## looks consistently different without any art. Replaced by sprites in M6.
extends Control

var _body: Color = Color.WHITE
var _accent: Color = Color.BLACK
var _horns: bool = false
var _ready_to_draw: bool = false


func set_monster(data: MonsterData) -> void:
	var hash_value: int = abs(int(data.id.hash()))
	_body = Color.from_hsv(float(hash_value % 360) / 360.0, 0.5, 0.82)
	_accent = _body.darkened(0.45)
	_horns = data.is_boss or (hash_value / 360) % 2 == 0
	_ready_to_draw = true
	queue_redraw()


func _draw() -> void:
	if not _ready_to_draw:
		return
	var center := size / 2.0
	var radius := minf(size.x, size.y) * 0.42

	if _horns:
		for direction in [-1.0, 1.0]:
			var base := center + Vector2(direction * radius * 0.62, -radius * 0.62)
			draw_colored_polygon(PackedVector2Array([
				base + Vector2(-4, 4), base + Vector2(4, 4),
				base + Vector2(direction * 5, -radius * 0.55),
			]), _accent)

	draw_colored_polygon(_ellipse(center, radius * 1.15, radius), _body)
	draw_colored_polygon(_ellipse(center, radius * 1.15, radius, 3.0), _accent)
	draw_colored_polygon(_ellipse(center, radius * 1.05, radius * 0.9), _body)

	var eye_dx := radius * 0.38
	for direction in [-1.0, 1.0]:
		var eye := center + Vector2(direction * eye_dx, -radius * 0.15)
		draw_circle(eye, radius * 0.17, Color(0.96, 0.96, 0.92))
		draw_circle(eye + Vector2(direction * radius * 0.04, 0), radius * 0.08, Color(0.1, 0.08, 0.12))
	draw_line(center + Vector2(-radius * 0.28, radius * 0.35),
			center + Vector2(radius * 0.28, radius * 0.35), _accent, 2.0)


func _ellipse(center: Vector2, rx: float, ry: float, grow: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 28:
		var angle := TAU * float(i) / 28.0
		points.append(center + Vector2(cos(angle) * (rx + grow), sin(angle) * (ry + grow)))
	return points
