extends StatusApplyAction

class_name ApplyStatusToSummonedAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if ctx.summoned_ids.is_empty():
		return false

	var applied_any := false
	for summoned_id in ctx.summoned_ids:
		applied_any = _apply_status_to_target(ctx, int(summoned_id)) or applied_any

	_play_success_sound(ctx, applied_any)
	return applied_any
