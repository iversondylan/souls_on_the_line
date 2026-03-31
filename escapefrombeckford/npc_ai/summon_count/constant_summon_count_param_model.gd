class_name ConstantSummonCountParamModel extends ParamModel

@export var summon_count: int = 1

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.SUMMON_COUNT] = maxi(int(summon_count), 0)
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.SUMMON_COUNT] = maxi(int(summon_count), 0)
	return ctx
