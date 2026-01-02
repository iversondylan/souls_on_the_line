# not_used_yet_performable_model.gd
class_name NotUsedYetPerformableModel
extends PerformableModel

@export var key: String = NPCKeys.USED_1

func is_performable(ctx: NPCAIContext) -> bool:
	return !bool(ctx.state.get(key, false))
