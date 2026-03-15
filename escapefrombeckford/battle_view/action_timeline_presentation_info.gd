# action_timeline_presentation_info

class_name ActionTimelinePresentationInfo extends RefCounted

var actor_id: int = 0
var action_kind: int = DirectorAction.ActionKind.GENERIC
var steps: Array[ActionStepPresentationInfo] = []

func get_all_target_ids() -> Array[int]:
	var seen := {}
	var out: Array[int] = []

	for step in steps:
		if step == null:
			continue
		for tid in step.target_ids:
			var k := int(tid)
			if !seen.has(k):
				seen[k] = true
				out.append(k)

	return out
