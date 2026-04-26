extends CardAction

class_name MoveTargetToFrontAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null:
		return false
	if ctx.target_ids == null or ctx.target_ids.is_empty():
		return false

	var target_id := int(ctx.target_ids[0])
	if target_id <= 0 or !ctx.api.is_alive(target_id):
		return false

	ctx.runtime.append_affected_id(ctx, target_id)

	var friendly_ids := ctx.api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false)
	if !friendly_ids.is_empty() and int(friendly_ids[0]) == target_id:
		return true

	var move := MoveContext.new()
	move.move_type = MoveContext.MoveType.MOVE_TO_FRONT
	move.actor_id = int(ctx.source_id)
	move.move_unit_id = target_id
	move.reason = "card_move_target_to_front"
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		move.origin_card_uid = String(ctx.card_data.uid)

	ctx.runtime.run_move(move)
	return true
