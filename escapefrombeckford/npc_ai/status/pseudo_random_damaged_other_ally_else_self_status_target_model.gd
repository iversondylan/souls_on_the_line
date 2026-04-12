class_name PseudoRandomDamagedOtherAllyElseSelfStatusTargetModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_target_ids(ctx)

static func find_target_id(ctx: NPCAIContext) -> int:
	if ctx == null or ctx.api == null or ctx.api.state == null:
		return 0

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		return 0

	var group_index := int(ctx.api.get_group(actor_id))
	if group_index < 0:
		return 0

	var damaged_other_ids := PackedInt32Array()
	for cid in ctx.api.get_combatants_in_group(group_index, false):
		var ally_id := int(cid)
		if ally_id <= 0 or ally_id == actor_id:
			continue

		var ally: CombatantState = ctx.api.state.get_unit(ally_id)
		if ally == null or !ally.is_alive():
			continue
		if int(ally.health) >= int(ally.max_health):
			continue

		damaged_other_ids.append(ally_id)

	if !damaged_other_ids.is_empty():
		return _pick_random_candidate(ctx, damaged_other_ids)

	var actor: CombatantState = ctx.api.state.get_unit(actor_id)
	if actor != null and actor.is_alive() and int(actor.health) < int(actor.max_health):
		return actor_id

	return 0

static func _pick_random_candidate(ctx: NPCAIContext, candidate_ids: PackedInt32Array) -> int:
	if candidate_ids.is_empty():
		return 0
	if ctx != null and ctx.rng != null:
		var pick_idx := int(floor(ctx.rng.randf() * float(candidate_ids.size())))
		return int(candidate_ids[clampi(pick_idx, 0, candidate_ids.size() - 1)])
	return int(candidate_ids[0])

func _write_target_ids(ctx: NPCAIContext) -> NPCAIContext:
	if ctx == null:
		return ctx

	var target_id := find_target_id(ctx)
	var target_ids := PackedInt32Array()
	if target_id > 0:
		target_ids.append(target_id)
		ctx.params[Keys.TARGET_ID] = target_id
	else:
		ctx.params.erase(Keys.TARGET_ID)

	ctx.params[Keys.TARGET_IDS] = target_ids
	return ctx
