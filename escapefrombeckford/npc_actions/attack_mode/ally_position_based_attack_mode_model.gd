class_name AllyPositionBasedAttackMode extends NPCAttackModeModel

func resolve_mode(ctx: NPCAIContext) -> NPCAttackAction.AttackMode:
	var fighter := ctx.combatant
	if not fighter:
		return NPCAttackAction.AttackMode.MELEE
	
	# You define this however you want
	if fighter.battle_group.is_in_front_of_player(fighter):
		return NPCAttackAction.AttackMode.MELEE
	
	return NPCAttackAction.AttackMode.RANGED
