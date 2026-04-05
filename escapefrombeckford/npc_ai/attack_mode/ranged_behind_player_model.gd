# ranged_behind_player_model.gd

class_name RangedBehindPlayerModel extends ParamModel

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.api:
		return ctx

	var id := ctx.get_actor_id()
	if id <= 0:
		return ctx

	var my_group := int(ctx.api.get_group(id))
	if my_group != 0:
		# If used on enemies, do nothing.
		return ctx
	
	var my_rank := int(ctx.api.get_rank_in_group(id))
	
	var player_id := (ctx.api as SimBattleAPI).get_player_id()
	
	var player_rank := int(ctx.api.get_rank_in_group(player_id)) if player_id > 0 else 0
	var delta := my_rank - player_rank
	
	# Behind player => ranged
	if delta > 0:
		ctx.params[Keys.ATTACK_MODE] = Attack.Mode.RANGED
	elif delta < 0:
		ctx.params[Keys.ATTACK_MODE] = Attack.Mode.MELEE

	return ctx
