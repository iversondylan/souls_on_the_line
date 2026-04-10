# target_ids_stored_in_state_param_model.gd

class_name TargetIdsStoredInStateParamModel extends ParamModel

@export var state_key: StringName = &"stored_target_ids"
@export var require_alive: bool = true

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func _write_target_ids(ctx: NPCAIContext) -> NPCAIContext:
	if ctx == null or ctx.state == null or state_key == &"":
		return ctx

	var stored = ctx.state.get(state_key, PackedInt32Array())
	var target_ids := PackedInt32Array()
	if stored is PackedInt32Array:
		target_ids = stored
	elif stored is Array:
		target_ids = PackedInt32Array(stored)
	elif int(stored) > 0:
		target_ids.append(int(stored))

	var filtered := PackedInt32Array()
	for tid in target_ids:
		var target_id := int(tid)
		if target_id <= 0:
			continue
		if require_alive and ctx.api != null and !ctx.api.is_alive(target_id):
			continue
		filtered.append(target_id)

	ctx.params[Keys.TARGET_IDS] = filtered
	if filtered.is_empty():
		ctx.params.erase(Keys.TARGET_ID)
	else:
		ctx.params[Keys.TARGET_ID] = int(filtered[0])
	return ctx
