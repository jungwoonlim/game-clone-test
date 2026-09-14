## Top-left stats box. Deliberately dumb: it is handed numbers, not a Hero.
class_name StatusWindow
extends DQWindow

var _level := 1
var _hp := 0
var _max_hp := 1
var _mp := 0
var _max_mp := 0
var _gold := 0


func set_values(level: int, hp: int, max_hp: int, mp: int, max_mp: int, gold: int) -> void:
	_level = level
	_hp = hp
	_max_hp = max_hp
	_mp = mp
	_max_mp = max_mp
	_gold = gold
	queue_redraw()


func _draw() -> void:
	super()
	draw_text(0, "LV")
	draw_text_right(0, str(_level))
	draw_text(1, "HP")
	draw_text_right(1, "%d/%d" % [_hp, _max_hp], _hp_color())
	draw_text(2, "MP")
	draw_text_right(2, "%d/%d" % [_mp, _max_mp])
	draw_text(3, "G")
	draw_text_right(3, str(_gold))


## Turns red when a single average hit could finish you.
func _hp_color() -> Color:
	if _max_hp > 0 and float(_hp) / float(_max_hp) <= 0.25:
		return Color(0.95, 0.35, 0.35)
	return BORDER
