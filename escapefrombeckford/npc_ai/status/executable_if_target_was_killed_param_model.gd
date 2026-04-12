class_name ExecutableIfTargetWasKilledParamModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _apply(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _apply(ctx)

func _apply(ctx: NPCAIContext) -> NPCAIContext:
	if ctx == null:
		return ctx

	var killed_ids := PackedInt32Array()
	if ctx.state != null:
		var stored = ctx.state.get(Keys.KILLED_TARGET_IDS, PackedInt32Array())
		if stored is PackedInt32Array:
			killed_ids = stored
		elif stored is Array:
			killed_ids = PackedInt32Array(stored)
		elif int(stored) > 0:
			killed_ids.append(int(stored))

	ctx.params[Keys.SEQUENCE_EXECUTABLE] = !killed_ids.is_empty()
	return ctx
