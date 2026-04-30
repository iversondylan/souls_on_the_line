extends CardAction

class_name SeanceAction

const ENERGY_SURGE := preload("res://statuses/energy_surge.tres")

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.target_ids.is_empty():
		return false

	var target_id := int(ctx.target_ids[0])
	if target_id <= 0 or !ctx.api.is_alive(target_id):
		return false

	var bonus := _get_bonus(ctx.api)
	if bonus > 0:
		var status_ctx := StatusContext.new()
		status_ctx.source_id = int(ctx.source_id)
		status_ctx.target_id = target_id
		status_ctx.status_id = ENERGY_SURGE.get_id()
		status_ctx.stacks = bonus
		status_ctx.reason = "seance"
		if ctx.card_data != null:
			ctx.card_data.ensure_uid()
			status_ctx.origin_card_uid = String(ctx.card_data.uid)
		ctx.api.apply_status(status_ctx)

	if ctx.runtime != null:
		ctx.runtime.append_affected_id(ctx, target_id)
		var draw_ctx := DrawContext.new()
		draw_ctx.amount = 1
		draw_ctx.source_id = int(ctx.api.get_player_id())
		draw_ctx.reason = "seance"
		ctx.runtime.run_draw_action(draw_ctx)

	return true

func get_description_value(ctx: CardActionContext) -> String:
	var api := ctx.api if ctx != null else null
	return str(_get_bonus(api))

func _get_bonus(api: SimBattleAPI) -> int:
	if api == null:
		return 0
	return int(api.count_previous_round_deaths()) * 2
