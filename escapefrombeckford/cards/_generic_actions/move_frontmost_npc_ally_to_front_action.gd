extends CardAction

class_name MoveFrontmostNpcAllyToFrontAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null:
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

	if target_id <= 0:
		return false

	ctx.runtime.append_affected_id(ctx, target_id)

	if !friendly_ids.is_empty() and int(friendly_ids[0]) == target_id:
		return true

	var move := MoveContext.new()
	move.move_type = MoveContext.MoveType.MOVE_TO_FRONT
	move.actor_id = int(ctx.source_id)
	move.move_unit_id = target_id
	move.reason = "card_move_frontmost_npc_ally_to_front"
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		move.origin_card_uid = String(ctx.card_data.uid)

	ctx.runtime.run_move(move)
	return true
