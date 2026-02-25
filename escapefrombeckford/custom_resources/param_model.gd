# param_model.gd

class_name ParamModel extends Resource

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return ctx

static func _actor_id(ctx: NPCAIContext) -> int:
	if !ctx:
		return 0
	if ctx.combatant_state:
		return int(ctx.combatant_state.id)
	if ctx.combatant and is_instance_valid(ctx.combatant):
		return int(ctx.combatant.combat_id)
	if ctx.combatant_data:
		return int(ctx.combatant_data.combat_id)
	if "cid" in ctx:
		return int(ctx.cid)
	return 0
