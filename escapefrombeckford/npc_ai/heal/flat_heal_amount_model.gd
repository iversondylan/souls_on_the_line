# flat_heal_amount_model.gd

class_name FlatHealAmountModel extends ParamModel

@export var flat_amount: int = 0

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.FLAT_AMOUNT] = maxi(int(flat_amount), 0)
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.FLAT_AMOUNT] = maxi(int(flat_amount), 0)
	return ctx
