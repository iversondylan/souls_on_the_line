class_name ProjectileUidModel extends ParamModel

@export var projectile_uid: String = ""

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.PROJECTILE_SCENE] = String(projectile_uid)
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	ctx.params[Keys.PROJECTILE_SCENE] = String(projectile_uid)
	return ctx
