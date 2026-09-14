## Seeded random number generator.
##
## Every random decision in core/ goes through one of these. Never call the
## global randi()/randf() from core code — a battle must be perfectly
## reproducible from its seed, because that is what makes headless balance
## simulation, bug reproduction and regression tests possible.
class_name Rng
extends RefCounted

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


## Current generator state. Save this to resume an identical stream later.
func get_state() -> int:
	return _rng.state


func set_state(value: int) -> void:
	_rng.state = value


## Inclusive on both ends. Returns `from` when the range is inverted.
func range_i(from: int, to: int) -> int:
	if to <= from:
		return from
	return _rng.randi_range(from, to)


## 0..255, the granularity the original game's checks are written against.
func byte() -> int:
	return _rng.randi_range(0, 255)


func unit() -> float:
	return _rng.randf()


## True with probability numerator/denominator.
func chance(numerator: int, denominator: int) -> bool:
	if numerator <= 0:
		return false
	if numerator >= denominator:
		return true
	return _rng.randi_range(0, denominator - 1) < numerator


## Index into `weights`, picked proportionally. Returns -1 if nothing is eligible.
func pick_weighted(weights: Array[int]) -> int:
	var total := 0
	for w in weights:
		if w > 0:
			total += w
	if total <= 0:
		return -1
	var roll := _rng.randi_range(0, total - 1)
	for i in weights.size():
		if weights[i] <= 0:
			continue
		roll -= weights[i]
		if roll < 0:
			return i
	return weights.size() - 1
