class_name NoDamageModifiersParamModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_params(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_params(ctx)

func _write_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.DEAL_MOD_TYPE] = int(Modifier.Type.NO_MODIFIER)
	ctx.params[Keys.TAKE_MOD_TYPE] = int(Modifier.Type.NO_MODIFIER)
	return ctx
