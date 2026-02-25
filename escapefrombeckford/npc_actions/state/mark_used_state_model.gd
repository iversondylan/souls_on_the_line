# mark_used_state_model.gd
class_name MarkUsedStateModel
extends StateModel

@export var key: String = NPCKeys.USED_1
@export var value: bool = true

func change_state(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	if !ctx.state:
		ctx.state = {}
	ctx.state[key] = value
	return ctx


func change_state_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	if !ctx.state:
		ctx.state = {}
	ctx.state[key] = bool(value)
	return ctx
