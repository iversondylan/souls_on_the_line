extends CardAction

class_name SacrificeAction

const Removal = preload("res://core/keys_values/removal_values.gd")
const RemovalContextScript = preload("res://battle/contexts/removal_context.gd")

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if ctx.target_ids.is_empty():
		return false

	var target_id := int(ctx.target_ids[0])
	if target_id <= 0 or !ctx.api.is_alive(target_id):
		return false

	ctx.affected_target_player_pos_delta = int(ctx.api.get_player_pos_delta(target_id))

	var removal_ctx = RemovalContextScript.new()
	removal_ctx.target_id = target_id
	removal_ctx.removal_type = Removal.Type.DEATH
	removal_ctx.killer_id = int(ctx.source_id)
	removal_ctx.reason = "card_sacrifice"
	removal_ctx.overload_mod = -1
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		removal_ctx.origin_card_uid = String(ctx.card_data.uid)

	ctx.api.resolve_removal(removal_ctx)
	if !removal_ctx.removed:
		return false

	if !ctx.affected_ids.has(target_id):
		ctx.affected_ids.append(target_id)

	return true
