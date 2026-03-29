# state_model.gd

class_name StateModel extends Resource

## Same definition as ParamModel but this should only act on ctx.state
func change_state(ctx: NPCAIContext) -> NPCAIContext:
	return ctx
func change_state_sim(ctx: NPCAIContext) -> NPCAIContext:
	return ctx

func change_chance_weight_state_sim(_ctx: NPCAIContext, _action_state: Dictionary) -> void:
	pass
