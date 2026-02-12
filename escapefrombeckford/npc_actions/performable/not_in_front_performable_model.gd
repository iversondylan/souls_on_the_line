# not_in_front_performable_model.gd

class_name NotInFrontPerformableModel extends PerformableModel

func is_performable(ctx: NPCAIContext) -> bool:
	if !ctx or !ctx.api:
		return false
	var id := ctx.combatant.combat_id if ctx.combatant else (ctx.combatant_data.combat_id if ctx.combatant_data else 0)
	if id <= 0:
		return false
	return ctx.api.get_rank_in_group(id) != 0

#func is_performable(ctx: NPCAIContext) -> bool:
	#var in_front: bool = ctx.combatant.get_index() == 0
	##print("not_in_front_performable_model.gd performable: ", !in_front)
	#return !in_front
