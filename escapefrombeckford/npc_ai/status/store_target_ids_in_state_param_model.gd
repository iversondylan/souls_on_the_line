# store_target_ids_in_state_param_model.gd

class_name StoreTargetIdsInStateParamModel extends ParamModel

@export var state_key: StringName = &"stored_target_ids"
@export var clear_when_empty: bool = true

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _store_target_ids(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _store_target_ids(ctx)

func _store_target_ids(ctx: NPCAIContext) -> NPCAIContext:
	if ctx == null or ctx.state == null or state_key == &"":
		return ctx

	var target_ids := _read_target_ids_from_params(ctx)
	if target_ids.is_empty():
		if clear_when_empty:
			ctx.state.erase(state_key)
		return ctx

	ctx.state[state_key] = target_ids
	return ctx

func _read_target_ids_from_params(ctx: NPCAIContext) -> PackedInt32Array:
	var out := PackedInt32Array()
	if ctx == null or ctx.params == null:
		return out

	var raw_value = ctx.params.get(Keys.TARGET_IDS, PackedInt32Array())
	if raw_value is PackedInt32Array:
		out = raw_value
	elif raw_value is Array:
		out = PackedInt32Array(raw_value)

	if out.is_empty():
		var single_id := int(ctx.params.get(Keys.TARGET_ID, 0))
		if single_id > 0:
			out.append(single_id)

	return out
