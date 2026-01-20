# before_me_insert_index_model.gd
class_name BeforeMeInsertIndexModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.combatant:
		return ctx
	
	var fighter := ctx.combatant
	var group := fighter.get_parent()
	if !group or !group.has_method("get_combatants"):
		return ctx
	
	# Index of this combatant within its group
	var my_index := fighter.get_index()
	
	# Insert directly in front of me
	ctx.params[NPCKeys.INSERT_INDEX] = max(my_index, 0)
	
	return ctx
