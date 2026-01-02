# health_below_threshold_performable_model.gd
class_name HealthBelowThresholdPerformableModel
extends PerformableModel

@export var hp_threshold: int = 5

func is_performable(ctx: NPCAIContext) -> bool:
	if not ctx.combatant:
		return false
	return ctx.combatant.combatant_data.health <= hp_threshold
