# health_below_threshold_performable_model.gd
class_name HealthBelowThresholdPerformableModel
extends PerformableModel

@export var hp_threshold: int = 5

func is_performable(ctx: NPCAIContext) -> bool:
	if !ctx:
		return false

	if ctx.combatant_state:
		return int(ctx.combatant_state.health) <= int(hp_threshold)

	return false

func is_performable_sim(ctx: NPCAIContext) -> bool:
	if !ctx:
		return false
	if ctx.combatant_state:
		return int(ctx.combatant_state.health) <= int(hp_threshold)
	return false
