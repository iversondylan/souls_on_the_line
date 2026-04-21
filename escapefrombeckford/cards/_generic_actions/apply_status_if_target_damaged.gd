extends StatusApplyAction

class_name ApplyStatusIfTargetDamagedAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var target_id := int(ctx.target_ids[0]) if ctx.target_ids != null and ctx.target_ids.size() > 0 else 0
	var target_state := ctx.api.state.get_unit(target_id) if ctx.api.state != null else null
	var is_damaged := target_state != null and int(target_state.health) < int(target_state.max_health)
	ctx.params[Keys.TARGET_IS_DAMAGED] = is_damaged
	if !is_damaged:
		return target_state != null

	var applied_any := _apply_status_to_target(ctx, target_id)
	_play_success_sound(ctx, applied_any)
	return applied_any or target_state != null
