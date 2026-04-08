extends CardAction

class_name SacrificeAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if ctx.target_ids.is_empty():
		return false

	var target_id := int(ctx.target_ids[0])
	if target_id <= 0 or !ctx.api.is_alive(target_id):
		return false

	ctx.affected_target_player_pos_delta = int(ctx.api.get_player_pos_delta(target_id))

	var death_ctx := DeathContext.new()
	death_ctx.dead_id = target_id
	death_ctx.killer_id = int(ctx.source_id)
	death_ctx.reason = "card_sacrifice"
	death_ctx.overload_mod = -2
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		death_ctx.origin_card_uid = String(ctx.card_data.uid)

	ctx.api.resolve_death(death_ctx)
	if !death_ctx.died:
		return false

	if !ctx.affected_ids.has(target_id):
		ctx.affected_ids.append(target_id)

	return true
