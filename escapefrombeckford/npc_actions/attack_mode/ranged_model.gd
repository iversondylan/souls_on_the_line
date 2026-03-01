# ranged_model.gd

class_name RangedModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	ctx.params[Keys.ATTACK_MODE] = Attack.Mode.RANGED

	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.ATTACK_MODE] = Attack.Mode.RANGED
	return ctx
