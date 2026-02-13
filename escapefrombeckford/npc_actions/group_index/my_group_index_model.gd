# my_group_index_model.gd
class_name MyGroupIndexModel
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

	ctx.params[NPCKeys.GROUP_INDEX] = ctx.api.get_group(cid)
	return ctx
