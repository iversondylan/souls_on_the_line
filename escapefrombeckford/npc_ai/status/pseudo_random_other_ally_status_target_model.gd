# pseudo_random_other_ally_status_target_model.gd
class_name PseudoRandomOtherAllyStatusTargetModel extends ParamModel

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
	if !candidate_ids.is_empty():
		if ctx.rng != null:
			var pick_idx := int(floor(ctx.rng.randf() * float(candidate_ids.size())))
			chosen_id = int(candidate_ids[clampi(pick_idx, 0, candidate_ids.size() - 1)])
		else:
			chosen_id = int(candidate_ids[0])

	var target_ids := PackedInt32Array()
	if chosen_id > 0:
		target_ids.append(chosen_id)
		ctx.params[Keys.TARGET_ID] = chosen_id
	ctx.params[Keys.TARGET_IDS] = target_ids
	return ctx
