extends "res://encounters/_core/encounter_condition.gd"
class_name EncounterEventCondition

@export var event_name: StringName = &""
@export var battle_event_type: int = -1
@export var gate_request_kind: int = -1

func evaluate_match(ctx) -> bool:
	if ctx == null:
		return false
	if event_name != &"" and ctx.get_event_name() != event_name:
		return false
	if battle_event_type >= 0 and ctx.get_battle_event_type() != battle_event_type:
		return false
	if gate_request_kind >= 0 and ctx.get_request_kind() != gate_request_kind:
		return false
	return true
