extends StatusOnSummonedAction

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [(status as TemperedStatus).max_health_per_strike]
