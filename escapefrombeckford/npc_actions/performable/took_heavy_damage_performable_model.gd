class_name TookHeavyDamagePerformableModel extends PerformableModel

@export var threshold := 7

func is_performable(ctx: NPCAIContext) -> bool:
	var heavy_damage : bool = ctx.state.get("dmg_since_last_turn", 0) >= threshold
	print("%s" % ctx.state.get("dmg_since_last_turn"))
	print("TookHeavyDamagePerformableModel damage taken: %s" % ctx.state.get("dmg_since_last_turn", 0))
	print("TookHeavyDamagePerformableModel is_performable: %s" % heavy_damage)
	return heavy_damage
