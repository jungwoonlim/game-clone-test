## Main game loop: dropper, merging, scoring and game-over handling.
extends Node2D

## How long a fruit may sit above the dead line before the run ends.
const DEAD_LINE_GRACE: float = 2.0
## Minimum gap between two drops.
const DROP_COOLDOWN: float = 0.4
const KEYBOARD_SPEED: float = 460.0
const SAVE_PATH: String = "user://suika_save.cfg"

const FRUIT_SCENE: PackedScene = preload("res://scenes/fruit.tscn")

@onready var _fruits: Node2D = $Fruits
@onready var _dropper: Node2D = $Dropper
@onready var _score_value: Label = $UI/ScoreValue
@onready var _best_value: Label = $UI/BestValue
@onready var _game_over_panel: Control = $UI/GameOver
@onready var _final_score: Label = $UI/GameOver/FinalScore

var _score: int = 0
var _best: int = 0
var _current_level: int = 0
var _next_level: int = 0
var _preview: Fruit = null
var _drop_timer: float = 0.0
## Worst per-fruit danger timer this frame; drives the blinking dead line.
var _danger_timer: float = 0.0
var _game_over: bool = false


func _ready() -> void:
	_best = _load_best()
	_best_value.text = str(_best)
	_game_over_panel.visible = false
	_current_level = FruitData.random_droppable_level()
	_next_level = FruitData.random_droppable_level()
	_spawn_preview()
	_move_dropper((Playfield.LEFT + Playfield.RIGHT) * 0.5)


func _process(delta: float) -> void:
	if _game_over:
		return

	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0 and _preview == null:
			_spawn_preview()

	var axis := Input.get_axis("ui_left", "ui_right")
	if not is_zero_approx(axis):
		_move_dropper(_dropper.position.x + axis * KEYBOARD_SPEED * delta)

	_update_danger(delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _game_over:
		if _is_confirm(event):
			_restart()
		return

	if event is InputEventMouseMotion or event is InputEventScreenDrag:
		_move_dropper(get_global_mouse_position().x)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_move_dropper(get_global_mouse_position().x)
		_drop()
	elif event is InputEventScreenTouch and event.pressed:
		_move_dropper(get_global_mouse_position().x)
		_drop()
	elif event.is_action_pressed("ui_accept"):
		_drop()


func _is_confirm(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventScreenTouch and event.pressed:
		return true
	return false


# --- Dropper ------------------------------------------------------------

func _spawn_preview() -> void:
	_preview = _make_fruit(_current_level)
	_preview.set_active(false)
	_dropper.add_child(_preview)
	_preview.position = Vector2.ZERO
	# Clamp again: the new fruit may be wider than the previous one.
	_move_dropper(_dropper.position.x)


func _move_dropper(x: float) -> void:
	var r: float = FruitData.RADII[_current_level]
	_dropper.position.x = clampf(x, Playfield.LEFT + r, Playfield.RIGHT - r)
	_dropper.position.y = Playfield.DROP_Y


func _drop() -> void:
	if _game_over or _preview == null or _drop_timer > 0.0:
		return

	var fruit := _preview
	_preview = null
	var spawn_pos := fruit.global_position
	_dropper.remove_child(fruit)
	_fruits.add_child(fruit)
	fruit.global_position = spawn_pos
	fruit.dropped = true
	fruit.set_active(true)

	_current_level = _next_level
	_next_level = FruitData.random_droppable_level()
	_drop_timer = DROP_COOLDOWN


# --- Fruit lifecycle ----------------------------------------------------

func _make_fruit(level: int) -> Fruit:
	var fruit: Fruit = FRUIT_SCENE.instantiate()
	fruit.setup(level)
	fruit.request_merge.connect(_on_request_merge)
	return fruit


func _spawn_fruit(level: int, pos: Vector2) -> Fruit:
	var fruit := _make_fruit(level)
	_fruits.add_child(fruit)
	fruit.global_position = pos
	fruit.dropped = true
	fruit.set_active(true)
	return fruit


func _on_request_merge(a: Fruit, b: Fruit) -> void:
	# body_entered fires inside the physics step; adding and removing bodies
	# has to wait until the step is over.
	_merge.call_deferred(a, b)


func _merge(a: Fruit, b: Fruit) -> void:
	if _game_over:
		return
	if not is_instance_valid(a) or not is_instance_valid(b):
		return
	var level: int = a.level
	var pos: Vector2 = (a.global_position + b.global_position) * 0.5
	a.queue_free()
	b.queue_free()

	if level >= FruitData.MAX_LEVEL:
		# Two watermelons cancel out and pay double.
		_add_score(FruitData.SCORES[FruitData.MAX_LEVEL] * 2)
		return

	var next := level + 1
	_add_score(FruitData.SCORES[next])
	_spawn_fruit(next, pos)


func _add_score(points: int) -> void:
	_score += points
	_score_value.text = str(_score)
	if _score > _best:
		_best = _score
		_best_value.text = str(_best)


# --- Game over ----------------------------------------------------------

func _update_danger(delta: float) -> void:
	var worst := 0.0
	for child in _fruits.get_children():
		var fruit := child as Fruit
		if fruit == null or fruit.is_merging or not fruit.dropped:
			continue
		fruit.update_danger(delta)
		worst = maxf(worst, fruit.danger_time)

	_danger_timer = worst
	if worst >= DEAD_LINE_GRACE:
		_end_game()


func _end_game() -> void:
	_game_over = true
	_final_score.text = "SCORE  %d\nBEST  %d" % [_score, _best]
	_game_over_panel.visible = true
	_save_best()
	if _preview != null:
		_preview.queue_free()
		_preview = null
	# Stop the jar so the final board stays readable (and stops scoring).
	for child in _fruits.get_children():
		var fruit := child as Fruit
		if fruit != null:
			fruit.set_deferred("freeze", true)


func _restart() -> void:
	for child in _fruits.get_children():
		child.queue_free()
	_score = 0
	_score_value.text = "0"
	_danger_timer = 0.0
	_drop_timer = 0.0
	_game_over = false
	_game_over_panel.visible = false
	_current_level = FruitData.random_droppable_level()
	_next_level = FruitData.random_droppable_level()
	_spawn_preview()
	_move_dropper((Playfield.LEFT + Playfield.RIGHT) * 0.5)


# --- Persistence --------------------------------------------------------

func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value("progress", "best", 0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best", _best)
	cfg.save(SAVE_PATH)


# --- Presentation -------------------------------------------------------

func _draw() -> void:
	const WALL := 20.0
	var jar := Color(0.86, 0.78, 0.64)
	var left: float = Playfield.LEFT
	var right: float = Playfield.RIGHT
	var top: float = Playfield.TOP_Y
	var bottom: float = Playfield.FLOOR_Y

	# Page background (drawn first: children of Main render on top of this).
	draw_rect(Rect2(0.0, 0.0, 540.0, 960.0), Color(0.98, 0.95, 0.89))
	# Jar interior.
	draw_rect(Rect2(left, top, right - left, bottom - top), Color(1.0, 0.99, 0.95))
	# Walls and floor. Only the lower part of the walls is drawn: they extend
	# invisibly above the rim so fruit cannot be squeezed out of the jar.
	draw_rect(Rect2(left - WALL, top, WALL, bottom - top + WALL), jar)
	draw_rect(Rect2(right, top, WALL, bottom - top + WALL), jar)
	draw_rect(Rect2(left - WALL, bottom, right - left + WALL * 2.0, WALL), jar)

	_draw_dead_line()
	_draw_next_preview()
	# Guide line showing where the current fruit will land.
	if not _game_over and _preview != null:
		var x := _dropper.position.x
		draw_line(Vector2(x, Playfield.DROP_Y + FruitData.RADII[_current_level]),
				Vector2(x, bottom), Color(0.2, 0.2, 0.2, 0.15), 2.0)


func _draw_dead_line() -> void:
	var col := Color(0.82, 0.25, 0.25)
	col.a = 0.5
	if _danger_timer > 0.0:
		# Blink harder the longer a fruit has been sitting over the line.
		var beat := absf(sin(Time.get_ticks_msec() / 1000.0 * TAU * 2.0))
		col.a = 0.5 + 0.5 * beat * (_danger_timer / DEAD_LINE_GRACE)
	var x: float = Playfield.LEFT
	while x < Playfield.RIGHT:
		draw_line(Vector2(x, Playfield.DEAD_LINE_Y),
				Vector2(minf(x + 13.0, Playfield.RIGHT), Playfield.DEAD_LINE_Y), col, 4.0)
		x += 22.0


func _draw_next_preview() -> void:
	var center := Vector2(470.0, 78.0)
	var r: float = minf(FruitData.RADII[_next_level], 24.0)
	draw_circle(center, r, FruitData.COLORS[_next_level])
	draw_arc(center, r - 1.0, 0.0, TAU, 32,
			FruitData.COLORS[_next_level].darkened(0.3), 2.0, true)
