class_name RangedModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	ctx.params[NPCKeys.ATTACK_MODE] = NPCAttackSequence.ATTACK_MODE_RANGED

	return ctx
