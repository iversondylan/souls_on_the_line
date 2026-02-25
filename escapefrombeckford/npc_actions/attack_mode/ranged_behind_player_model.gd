# ranged_behind_player_model.gd

class_name RangedBehindPlayerModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.api:
		return ctx
	var id := ctx.combatant.combat_id if ctx.combatant else (ctx.combatant_data.combat_id if ctx.combatant_data else 0)
	if id <= 0:
		return ctx
	
	var delta := ctx.api.get_player_pos_delta(id)
	if delta > 0:
		ctx.params[NPCKeys.ATTACK_MODE] = NPCAttackSequence.ATTACK_MODE_RANGED
	elif delta < 0:
		ctx.params[NPCKeys.ATTACK_MODE] = NPCAttackSequence.ATTACK_MODE_MELEE
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx or !ctx.api:
		return ctx

	var id := ParamModel._actor_id(ctx)
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
		ctx.params[NPCKeys.ATTACK_MODE] = Attack.Mode.RANGED
	elif delta < 0:
		ctx.params[NPCKeys.ATTACK_MODE] = Attack.Mode.MELEE

	return ctx
