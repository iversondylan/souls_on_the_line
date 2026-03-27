class_name FlatArmorModel extends ParamModel

@export var armor: int = 5

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	ctx.params[Keys.ARMOR_AMOUNT] = armor
	return ctx
