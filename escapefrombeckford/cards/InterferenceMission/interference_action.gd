extends CardAction

const STACKS := 30

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var pos_delta := int(ctx.affected_target_player_pos_delta)
	if pos_delta == 0:
		return false

	var status_id := SunderedStatus.ID if pos_delta < 0 else SuppressedStatus.ID
	var enemy_ids := ctx.api.get_enemies_of(int(ctx.source_id))
	if enemy_ids.is_empty():
		return false

	var any := false
	for enemy_id in enemy_ids:
		var target_id := int(enemy_id)
		if target_id <= 0 or !ctx.api.is_alive(target_id):
			continue

		var status_ctx := StatusContext.new()
		status_ctx.source_id = int(ctx.source_id)
		status_ctx.target_id = target_id
		status_ctx.status_id = status_id
		status_ctx.intensity = STACKS
		ctx.api.apply_status(status_ctx)
		any = true

		if !ctx.affected_ids.has(target_id):
			ctx.affected_ids.append(target_id)

	return any

func description_arity() -> int:
	return 0
