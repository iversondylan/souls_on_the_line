# took_heavy_damage_performable_model.gd
class_name TookHeavyDamagePerformableModel
extends PerformableModel

@export var threshold := 7

func is_performable(ctx: NPCAIContext) -> bool:
	if !ctx or !ctx.state:
		return false
	return int(ctx.state.get("dmg_since_last_turn", 0)) >= threshold
