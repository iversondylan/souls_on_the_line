class_name FlatArmorModel extends ParamModel

@export var armor: int = 5

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	ctx.params[NPCKeys.ARMOR_AMOUNT] = armor
	return ctx
