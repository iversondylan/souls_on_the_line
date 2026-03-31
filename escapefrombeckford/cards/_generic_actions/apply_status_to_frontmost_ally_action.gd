extends StatusApplyAction

class_name ApplyStatusToFrontmostAllyAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var player_id := int(ctx.api.get_player_id())
	var friendly_ids := ctx.api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false)
	var target_id := 0
	for cid in friendly_ids:
		var ally_id := int(cid)
		if ally_id <= 0 or ally_id == player_id:
			continue
		target_id = ally_id
		break

	var applied_any := _apply_status_to_target(ctx, target_id)
	_play_success_sound(ctx, applied_any)
	return applied_any
