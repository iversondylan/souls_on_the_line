class_name SummonMortalityParamModel extends ParamModel

@export var mortality: CombatantState.Mortality = CombatantState.Mortality.HOLLOW

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.SUMMON_MORTALITY] = int(mortality)
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.SUMMON_MORTALITY] = int(mortality)
	return ctx
