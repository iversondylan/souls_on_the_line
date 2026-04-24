extends StatusApplyAction

class_name ToggleStatusAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if status == null:
		push_warning("toggle_status_action.gd activate_sim(): missing status")
		return false

	var applied_any := false
	for raw_target_id in ctx.target_ids:
		var target_id := int(raw_target_id)
		if target_id <= 0 or !ctx.api.is_alive(target_id):
			continue

		if ctx.api.has_status(target_id, status.get_id()):
			var remove_ctx := StatusContext.new()
			remove_ctx.source_id = int(ctx.source_id)
			remove_ctx.target_id = target_id
			remove_ctx.status_id = status.get_id()
			if ctx.card_data != null:
				ctx.card_data.ensure_uid()
				remove_ctx.origin_card_uid = String(ctx.card_data.uid)
			ctx.api.remove_status(remove_ctx)
			if !ctx.affected_ids.has(target_id):
				ctx.affected_ids.append(target_id)
			applied_any = true
			continue

		applied_any = _apply_status_to_target(ctx, target_id) or applied_any

	_play_success_sound(ctx, applied_any)
	return applied_any
