class_name StatusFxProfile
extends Resource

@export var cues: Array[Resource] = []


func get_cues_for_phase(phase: int) -> Array[Resource]:
	var out: Array[Resource] = []
	for cue: Resource in cues:
		if cue != null and bool(cue.call("matches", phase)):
			out.append(cue)
	return out


func has_cues_for_phase(phase: int) -> bool:
	for cue: Resource in cues:
		if cue != null and bool(cue.call("matches", phase)):
			return true
	return false
