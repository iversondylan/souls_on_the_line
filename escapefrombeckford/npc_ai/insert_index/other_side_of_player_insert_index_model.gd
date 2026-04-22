class_name OtherSideOfPlayerInsertIndexModel
extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _apply(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _apply(ctx)

func _apply(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.api:
		return ctx

	var actor_id := int(ctx.get_actor_id())
	if actor_id <= 0:
		return ctx

	var player_id := int(ctx.api.get_player_id())
	if player_id <= 0:
		ctx.params[Keys.SEQUENCE_EXECUTABLE] = false
		return ctx

	var my_rank := int(ctx.api.get_rank_in_group(actor_id))
	var player_rank := int(ctx.api.get_rank_in_group(player_id))
	if my_rank < 0 or player_rank < 0:
		ctx.params[Keys.SEQUENCE_EXECUTABLE] = false
		return ctx

	var to_index := -1
	if my_rank < player_rank:
		to_index = player_rank
	elif my_rank > player_rank:
		to_index = player_rank
	else:
		ctx.params[Keys.SEQUENCE_EXECUTABLE] = false
		return ctx

	ctx.params[Keys.SEQUENCE_EXECUTABLE] = true
	ctx.params[Keys.MOVE_TYPE] = int(MoveContext.MoveType.INSERT_AT_INDEX)
	ctx.params[Keys.MOVE_UNIT_ID] = actor_id
	ctx.params[Keys.TO_INDEX] = maxi(to_index, 0)
	ctx.params[Keys.CAN_RESTORE_TURN] = true
	ctx.params[Keys.REASON] = "other_side_of_player"
	return ctx
