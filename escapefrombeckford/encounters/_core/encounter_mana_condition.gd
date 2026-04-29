class_name EncounterManaCondition extends EncounterCondition

@export var min_after_mana: int = -1
@export var max_after_mana: int = -1
@export var min_before_mana: int = -1
@export var max_before_mana: int = -1

func evaluate_match(ctx: EncounterRuleContext) -> bool:
	if ctx == null or ctx.observed_event == null:
		return false
	if ctx.get_event_name() != &"mana":
		return false

	var data := ctx.observed_event.data
	var before_mana := int(data.get(Keys.BEFORE_MANA, 0))
	var after_mana := int(data.get(Keys.AFTER_MANA, 0))
	if min_after_mana >= 0 and after_mana < min_after_mana:
		return false
	if max_after_mana >= 0 and after_mana > max_after_mana:
		return false
	if min_before_mana >= 0 and before_mana < min_before_mana:
		return false
	if max_before_mana >= 0 and before_mana > max_before_mana:
		return false
	return min_after_mana >= 0 \
		or max_after_mana >= 0 \
		or min_before_mana >= 0 \
		or max_before_mana >= 0
