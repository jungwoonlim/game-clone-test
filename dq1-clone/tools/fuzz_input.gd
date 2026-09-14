## 실제 키 입력을 무작위로 퍼부어 뷰를 흔든다.
##
##   godot --path . --script res://tools/fuzz_input.gd -- [frames] [seed]
##
## smoke_view.gd 는 메뉴를 `chosen.emit()` 으로 고릅니다. 플레이어가 하는 일과
## 결과는 같지만 경로가 다릅니다 — 입력 처리기를 통째로 건너뜁니다. 그래서
## _unhandled_input 안에서만 터지는 버그는 스모크 테스트를 전부 통과합니다.
## 이 도구는 진짜 키 이벤트를 흘려보냅니다.
##
## 판정은 이 스크립트가 하지 않습니다. 엔진이 stderr 에 찍는 SCRIPT ERROR 가
## 곧 실패이고, 호출한 쪽이 그걸 봅니다.
extends SceneTree

const KEYS := [
	KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
	KEY_SPACE, KEY_ENTER, KEY_Z,
	KEY_ESCAPE, KEY_X, KEY_BACKSPACE,
]
const SCENES := ["res://scenes/title.tscn", "res://scenes/main.tscn"]

var _frames := 0
var _budget := 1200
var _rng := RandomNumberGenerator.new()
var _pressed := 0


func _initialize() -> void:
	Engine.time_scale = 6.0
	SaveGame.erase()
	var seed_value := 1
	var args := OS.get_cmdline_user_args()
	var numbers: Array[int] = []
	for argument in args:
		if argument.is_valid_int():
			numbers.append(int(argument))
	if numbers.size() > 0:
		_budget = numbers[0]
	if numbers.size() > 1:
		seed_value = numbers[1]
	_rng.seed = seed_value
	var scene := SCENES[0]
	for argument in args:
		if argument.begins_with("res://"):
			scene = argument
	Boot.continue_from_save = false
	root.add_child(load(scene).instantiate())
	print("[fuzz-input] %s  %d frames, seed %d" % [scene, _budget, seed_value])


func _process(_delta: float) -> bool:
	_frames += 1
	# 한 프레임에 하나씩. 사람이 누르는 것보다 훨씬 빠르지만, 같은 경로입니다.
	if _frames % 2 == 0:
		var event := InputEventKey.new()
		event.keycode = KEYS[_rng.randi_range(0, KEYS.size() - 1)]
		event.pressed = true
		Input.parse_input_event(event)
		_pressed += 1
	if _frames < _budget:
		return false
	print("[fuzz-input] %d keys sent over %d frames" % [_pressed, _frames])
	return true
