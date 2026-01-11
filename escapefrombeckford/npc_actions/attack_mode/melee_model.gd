class_name MeleeModel extends ParamModel

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	ctx.params[NPCKeys.ATTACK_MODE] = NPCAttackSequence.ATTACK_MODE_MELEE

	return ctx
