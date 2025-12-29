class_name NPCAttackModeModel extends Resource

func resolve_mode(_ctx: NPCAIContext) -> NPCAttackAction.AttackMode:
	return NPCAttackAction.AttackMode.MELEE
