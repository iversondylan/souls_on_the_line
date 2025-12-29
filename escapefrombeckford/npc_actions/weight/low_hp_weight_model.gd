class_name LowHPWeightModel extends NPCWeightModel

@export var threshold: float = 0.5
@export var bonus: float = 2.0

func get_weight(ctx: NPCAIContext) -> float:
	var data := ctx.combatant.combatant_data
	if data.health / float(data.max_health) <= threshold:
		return bonus
	return 1.0
