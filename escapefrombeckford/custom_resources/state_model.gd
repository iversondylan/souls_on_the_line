# state_model.gd

class_name StateModel extends Resource

## Same definition as ParamModel but this should only act on ctx.state
func change_state(ctx: NPCAIContext) -> NPCAIContext:
	return ctx
func change_state_sim(ctx: NPCAIContext) -> NPCAIContext:
	return ctx
