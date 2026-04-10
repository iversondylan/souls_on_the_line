# pseudo_random_other_ally_status_target_model.gd
class_name PseudoRandomOtherAllyStatusTargetModel extends ParamModel

@export var cache_state_key: StringName = &""
@export var read_cached_only: bool = false

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func _write_target_ids(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or ctx.api == null:
		return ctx

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return ctx

	var group_index := int(ctx.api.get_group(actor_id))
	if group_index < 0:
		return ctx

	var candidate_ids := PackedInt32Array()
	for cid in ctx.api.get_combatants_in_group(group_index, false):
		var ally_id := int(cid)
		if ally_id <= 0 or ally_id == actor_id:
			continue
		candidate_ids.append(ally_id)

	var chosen_id := 0
	var allow_cached := bool(ctx.state != null and bool(ctx.state.get(Keys.IS_ACTING, false)) and cache_state_key != &"")
	if allow_cached and read_cached_only:
		var cached_id := int(ctx.state.get(cache_state_key, 0))
		if cached_id > 0 and ctx.api.is_alive(cached_id):
			chosen_id = cached_id
	elif !candidate_ids.is_empty():
		if ctx.rng != null:
			var pick_idx := int(floor(ctx.rng.randf() * float(candidate_ids.size())))
			chosen_id = int(candidate_ids[clampi(pick_idx, 0, candidate_ids.size() - 1)])
		else:
			chosen_id = int(candidate_ids[0])
		if allow_cached:
			ctx.state[cache_state_key] = chosen_id

	var target_ids := PackedInt32Array()
	if chosen_id > 0:
		target_ids.append(chosen_id)
		ctx.params[Keys.TARGET_ID] = chosen_id
	ctx.params[Keys.TARGET_IDS] = target_ids
	return ctx
