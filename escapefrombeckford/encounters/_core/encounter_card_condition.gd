extends "res://encounters/_core/encounter_condition.gd"
class_name EncounterCardCondition

@export var card_uid: StringName = &""

func evaluate_match(ctx) -> bool:
	if ctx == null or card_uid == &"":
		return false
	return ctx.get_card_uid() == card_uid
