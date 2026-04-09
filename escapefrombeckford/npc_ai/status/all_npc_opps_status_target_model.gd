class_name AllNpcOppsStatusTargetModel extends ParamModel

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

	var opp_group_index := int(ctx.api.get_opposing_group(group_index))
	var player_id := int(ctx.api.get_player_id())
	var target_ids := PackedInt32Array()

	for cid in ctx.api.get_combatants_in_group(opp_group_index, false):
		var target_id := int(cid)
		if target_id <= 0 or target_id == player_id:
			continue
		target_ids.append(target_id)

	ctx.params[Keys.TARGET_IDS] = target_ids
	return ctx
