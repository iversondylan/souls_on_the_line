class_name EncounterCondition extends Resource

@export var invert: bool = false

func evaluate(ctx: EncounterRuleContext) -> bool:
	var matched := evaluate_match(ctx)
	return !matched if invert else matched

func evaluate_match(_ctx: EncounterRuleContext) -> bool:
	return true
