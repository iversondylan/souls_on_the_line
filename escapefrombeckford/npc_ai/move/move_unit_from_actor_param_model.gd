class_name MoveUnitFromActorParamModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _apply(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _apply(ctx)

func _apply(ctx: NPCAIContext) -> NPCAIContext:
	if ctx == null:
		return ctx

	var actor_id := int(ctx.get_actor_id())
	if actor_id > 0:
		ctx.params[Keys.MOVE_UNIT_ID] = actor_id
	return ctx
