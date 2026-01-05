# param_model.gd
class_name ParamModel extends Resource
## Same definition as StateModel but this should only act on ctx.params
func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return ctx
