extends StatusApplyAction

class_name ApplyStatusToSelfAction

func activate_sim(ctx: CardContext) -> bool:
	var applied_any := _apply_status_to_target(ctx, int(ctx.source_id))
	_play_success_sound(ctx, applied_any)
	return applied_any
