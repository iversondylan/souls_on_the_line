class_name FlatDamageModel extends ParamModel

@export var damage: int = 5

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	ctx.params[NPCKeys.DAMAGE] = damage
	return ctx
