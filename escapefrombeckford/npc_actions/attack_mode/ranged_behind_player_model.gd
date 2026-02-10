# ranged_behind_player_model.gd

class_name RangedBehindPlayerModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	var player_pos_delta: int = 0
	if ctx.combatant:
		player_pos_delta = ctx.battle_scene.get_player_pos_delta(ctx.combatant)
	if player_pos_delta > 0:
		ctx.params[NPCKeys.ATTACK_MODE] = NPCAttackSequence.ATTACK_MODE_RANGED
	elif player_pos_delta < 0:
		ctx.params[NPCKeys.ATTACK_MODE] = NPCAttackSequence.ATTACK_MODE_MELEE

	return ctx
