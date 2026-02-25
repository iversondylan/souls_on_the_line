# before_me_insert_index_model.gd
class_name BeforeMeInsertIndexModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.api:
		return ctx

	var cid := 0
	if ctx.combatant and is_instance_valid(ctx.combatant):
		cid = ctx.combatant.combat_id
	elif ctx.combatant_data:
		cid = ctx.combatant_data.combat_id

	if cid <= 0:
		return ctx

	var my_rank := ctx.api.get_rank_in_group(cid)
	ctx.params[NPCKeys.INSERT_INDEX] = maxi(my_rank, 0)
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.api:
		return ctx
	var cid := ParamModel._actor_id(ctx)
	if cid <= 0:
		return ctx
	var my_rank := int(ctx.api.get_rank_in_group(cid))
	ctx.params[NPCKeys.INSERT_INDEX] = maxi(my_rank, 0)
	return ctx
