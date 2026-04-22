class_name MoveUnitFromTargetParamModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _apply(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _apply(ctx)

func _apply(ctx: NPCAIContext) -> NPCAIContext:
	if ctx == null:
		return ctx

	var params: Dictionary = ctx.params if ctx.params else {}
	var move_unit_id := int(params.get(Keys.MOVE_UNIT_ID, 0))
	if move_unit_id <= 0:
		move_unit_id = int(params.get(Keys.TARGET_ID, 0))
	if move_unit_id <= 0:
		var raw_target_ids = params.get(Keys.TARGET_IDS, PackedInt32Array())
		if raw_target_ids is PackedInt32Array and !raw_target_ids.is_empty():
			move_unit_id = int(raw_target_ids[0])
		elif raw_target_ids is Array and !raw_target_ids.is_empty():
			move_unit_id = int(raw_target_ids[0])

	if move_unit_id > 0:
		ctx.params[Keys.MOVE_UNIT_ID] = move_unit_id
	return ctx
