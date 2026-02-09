# state_model.gd

class_name StateModel extends Resource

## Same definition as ParamModel but this should only act on ctx.state
func change_state(ctx: NPCAIContext) -> NPCAIContext:
	return ctx
