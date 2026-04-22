class_name RearmostInsertIndexModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_insert_index(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_insert_index(ctx)

func _write_insert_index(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or ctx.api == null:
		return ctx

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return ctx

	var group_index := int(ctx.api.get_group(actor_id))
	if group_index < 0:
		return ctx

	ctx.params[Keys.INSERT_INDEX] = ctx.api.get_combatants_in_group(group_index, false).size()
	return ctx
