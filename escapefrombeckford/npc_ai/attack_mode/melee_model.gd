# melee_model.gd

class_name MeleeModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	ctx.params[Keys.ATTACK_MODE] = Attack.Mode.MELEE
	return ctx
