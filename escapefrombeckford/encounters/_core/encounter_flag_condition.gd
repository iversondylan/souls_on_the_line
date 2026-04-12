extends "res://encounters/_core/encounter_condition.gd"
class_name EncounterFlagCondition

@export var flag_name: StringName = &""
@export var expected_value: Variant = true

func evaluate_match(ctx) -> bool:
	if ctx == null or flag_name == &"":
		return false
	return ctx.get_flag(flag_name) == expected_value
