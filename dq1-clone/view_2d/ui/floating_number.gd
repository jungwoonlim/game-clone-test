## A damage or heal number that rises and fades over the battle window.
##
## Numbers in the message log tell you what happened; a number over the target
## tells you who it happened to, which is the part the log cannot show.
class_name FloatingNumber
extends Label


static func spawn(parent: Node, text: String, at: Vector2, color: Color) -> void:
	var label := FloatingNumber.new()
	label.text = text
	label.position = at - Vector2(24, 8)
	label.size = Vector2(48, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.07))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 22.0, 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.55).set_delay(0.18)
	tween.tween_callback(label.queue_free)
