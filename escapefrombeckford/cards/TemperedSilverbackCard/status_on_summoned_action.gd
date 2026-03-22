# status_on_summoned_action.gd

class_name StatusOnSummonedAction extends CardAction

@export var status: Status

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	if status == null:
		push_warning("status_on_summoned_action.gd activate_sim(): missing status")
		return false

	if ctx.summoned_ids.is_empty():
		return false

	var applied_any := false

	for summoned_id in ctx.summoned_ids:
		var target_id := int(summoned_id)
		if target_id <= 0:
			continue

		var applied_status := status.duplicate(true)
		if applied_status == null:
			continue

		var sctx := StatusContext.new()
		sctx.source_id = int(ctx.source_id)
		sctx.target_id = target_id
		sctx.status_id = status.get_id()

		ctx.api.apply_status(sctx)
		applied_any = true

		if target_id not in ctx.affected_ids:
			ctx.affected_ids.append(target_id)

	return applied_any
