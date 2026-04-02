# reverse_targeting_model.gd

class_name ReverseTargetingModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.TARGET_TYPE] = Attack.Targeting.REVERSE
	return ctx


func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.TARGET_TYPE] = Attack.Targeting.REVERSE
	return ctx
