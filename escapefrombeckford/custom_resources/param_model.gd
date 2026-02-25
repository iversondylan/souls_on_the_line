# param_model.gd
class_name ParamModel extends Resource



## Same definition as StateModel but this should only act on ctx.params
func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return ctx
func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return ctx

static func _actor_id(ctx: NPCAIContext) -> int:
	if !ctx:
		return 0
	if ctx.combatant and is_instance_valid(ctx.combatant):
		return ctx.combatant.combat_id
	if ctx.combatant_data:
		return ctx.combatant_data.combat_id
	return 0
