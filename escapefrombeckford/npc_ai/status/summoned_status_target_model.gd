class_name SummonedStatusTargetModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func _write_target_ids(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx

	ctx.params[Keys.TARGET_IDS] = ctx.summoned_ids.duplicate()
	return ctx
