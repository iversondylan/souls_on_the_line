# strike_followthrough_slice.gd

class_name StrikeFollowthroughSlice extends RefCounted

var attack: AttackPresentationInfo = null
var strike: StrikePresentationInfo = null
var strike_index: int = 0

func get_target_ids() -> Array[int]:
	if strike != null and !strike.target_ids.is_empty():
		return strike.target_ids
	if attack != null:
		return attack.get_all_target_ids()
	return []
