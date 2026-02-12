# my_group_index_model.gd
class_name MyGroupIndexModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.combatant:
		return ctx
	
	var group := ctx.combatant.get_parent()
	if !group:
		return ctx
	
	# Determine group index from battle_scene
	var battle_scene := ctx.battle_scene
	if battle_scene and battle_scene.has_method("get_group_index_for"):
		ctx.params[NPCKeys.GROUP_INDEX] = battle_scene.get_group_index_for(group)
	else:
		# Fallback: assume parent order matches group index
		ctx.params[NPCKeys.GROUP_INDEX] = group.get_index()
	
	return ctx
