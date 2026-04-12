extends "res://encounters/_core/encounter_condition.gd"
class_name EncounterCurrentStepCondition

@export var step_id: StringName = &""

func evaluate_match(ctx) -> bool:
	if ctx == null:
		return false
	return ctx.get_current_step_id() == step_id
