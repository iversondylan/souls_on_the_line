# not_in_front_performable_model.gd

class_name NotInFrontPerformableModel extends PerformableModel

func is_performable_sim(ctx: NPCAIContext) -> bool:
	if !ctx or !ctx.api:
		return false
	var id := ctx.get_actor_id()
	if id <= 0:
		return false
	return int(ctx.api.get_rank_in_group(id)) != 0
