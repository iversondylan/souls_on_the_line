class_name EncounterCondition extends Resource

@export var invert: bool = false

func evaluate(ctx) -> bool:
	var matched := evaluate_match(ctx)
	return !matched if invert else matched

func evaluate_match(_ctx) -> bool:
	return true
