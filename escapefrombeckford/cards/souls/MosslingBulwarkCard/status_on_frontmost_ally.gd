extends StatusApplyAction

class_name StatusOnFrontmostAllyAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if ctx.summoned_ids.is_empty():
		return false

	var player_id := int(ctx.api.get_player_id())
	var summoned_ids := {}
	for summoned_id in ctx.summoned_ids:
		summoned_ids[int(summoned_id)] = true

	var target_id := 0
	for cid in ctx.api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false):
		var ally_id := int(cid)
		if ally_id <= 0 or ally_id == player_id or summoned_ids.has(ally_id):
			continue
		target_id = ally_id
		break

	var applied_any := _apply_status_to_target(ctx, target_id)
	_play_success_sound(ctx, applied_any)
	return applied_any
