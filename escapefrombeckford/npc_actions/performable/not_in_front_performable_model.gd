# not_in_front_performable_model.gd
class_name NotInFrontPerformableModel extends PerformableModel

func is_performable(ctx: NPCAIContext) -> bool:
	var in_front: bool = ctx.combatant.get_index() == 0
	#print("not_in_front_performable_model.gd performable: ", !in_front)
	return !in_front
