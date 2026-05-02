class_name ActionFxProfile
extends Resource

@export var cues: Array[Resource] = []

func get_cues_for_type(type: int) -> Array[Resource]:
	var out: Array[Resource] = []
	for cue: Resource in cues:
		if cue != null and bool(cue.call("matches", type)):
			out.append(cue)
	return out

func has_cues_for_type(type: int) -> bool:
	for cue: Resource in cues:
		if cue != null and bool(cue.call("matches", type)):
			return true
	return false
