# focused_collaboration_action.gd
extends CardAction

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null:
		return false

	var draw_ctx := DrawContext.new()
	draw_ctx.amount = 1
	draw_ctx.source_id = int(ctx.api.get_player_id())
	draw_ctx.reason = "focused_collaboration"
	ctx.runtime.run_draw_action(draw_ctx)

	var soulbound_played := ctx.api.has_played_card_type_this_turn(CardData.CardType.SOULBOUND)
	var soulwild_played := ctx.api.has_played_card_type_this_turn(CardData.CardType.SOULWILD)
	if soulbound_played or soulwild_played:
		print("focused_collaboration_action.gd soul was played, cancelling")
		return true

	var bound_ids := ctx.api.get_bound_ids_for_owner(int(ctx.source_id))
	print("focused_collaboration_action.gd bound_ids: ", bound_ids)
	if bound_ids.is_empty():
		return true

	for id in bound_ids:
		var tid := int(id)
		if tid <= 0 or !ctx.api.is_alive(tid):
			continue

		var might_ctx := StatusContext.new()
		might_ctx.source_id = int(ctx.source_id)
		might_ctx.target_id = tid
		might_ctx.status_id = Might.ID
		might_ctx.stacks = 1
		might_ctx.reason = "focused_collaboration"
		ctx.api.apply_status(might_ctx)
		
		var fort_ctx := StatusContext.new()
		fort_ctx.source_id = int(ctx.source_id)
		fort_ctx.target_id = tid
		fort_ctx.status_id = FullFortitudeStatus.ID
		fort_ctx.stacks = 1
		fort_ctx.reason = "focused_collaboration"
		ctx.api.apply_status(fort_ctx)

		var hctx := HealContext.new(int(ctx.source_id), tid, 2, 0.0, 0.0)
		ctx.api.heal(hctx)

		ctx.runtime.append_affected_id(ctx, tid)

	return true
