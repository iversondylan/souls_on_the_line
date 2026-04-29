class_name ClearEncounterArrowsAction extends EncounterAction

func execute(ctx: EncounterRuleContext) -> void:
	if ctx == null or ctx.battle == null:
		return
	ctx.battle.clear_encounter_arrows()
