extends RefCounted
class_name SimRng

## Deterministic 31-bit LCG. Same seed and call order always yield the same stream.

var state: int = 1


func _init(seed_value: int = 1) -> void:
	state = int(seed_value) & 0x7fffffff
	if state == 0:
		state = 1


func next_u32() -> int:
	state = int((1103515245 * int(state) + 12345) & 0x7fffffff)
	return state


func unit() -> float:
	return float(next_u32()) / 2147483647.0


func chance(probability: float) -> bool:
	return unit() < probability


func pick_index(count: int) -> int:
	if count <= 1:
		return 0
	return next_u32() % count
