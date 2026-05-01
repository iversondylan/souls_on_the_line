# after_me_insert_index_model.gd

class_name AfterMeInsertIndexModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_insert_index(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_insert_index(ctx)

func _write_insert_index(ctx: NPCAIContext) -> NPCAIContext:
	if ctx == null or ctx.api == null:
		return ctx

	var cid := ctx.get_actor_id()
	if cid <= 0:
		return ctx

	var my_rank := int(ctx.api.get_rank_in_group(cid))
	ctx.params[Keys.INSERT_INDEX] = maxi(my_rank + 1, 0)
	return ctx
