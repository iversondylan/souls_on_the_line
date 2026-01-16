class_name ConstantStrikesModel extends ParamModel

@export var strikes: int = 2

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	ctx.params[NPCKeys.STRIKES] = strikes
	return ctx
