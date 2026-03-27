# my_group_index_model.gd
class_name MyGroupIndexModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.api:
		return ctx

	var cid := ParamModel._actor_id(ctx)
	if cid <= 0:
		return ctx

	ctx.params[Keys.GROUP_INDEX] = ctx.api.get_group(cid)
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.api:
		return ctx
	var cid := ParamModel._actor_id(ctx)
	if cid <= 0:
		return ctx
	ctx.params[Keys.GROUP_INDEX] = int(ctx.api.get_group(cid))
	return ctx
