extends StatusApplyAction

class_name ApplyStatusToTargetsAction

@export var fallback_to_source_if_no_targets: bool = false

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var target_ids: Array[int] = []
	for target_id in ctx.target_ids:
		target_ids.append(int(target_id))

	if target_ids.is_empty() and bool(fallback_to_source_if_no_targets):
		target_ids.append(int(ctx.source_id))

	var applied_any := false
	for target_id in target_ids:
		applied_any = _apply_status_to_target(ctx, int(target_id)) or applied_any

	_play_success_sound(ctx, applied_any)
	return applied_any
