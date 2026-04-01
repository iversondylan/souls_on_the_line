# keep_stability_performable_model.gd
class_name KeepStabilityPerformableModel
extends PerformableModel

#func is_performable(ctx: NPCAIContext) -> bool:
	#if !ctx or !ctx.state:
		#return true
	#return !bool(ctx.state.get(NPCAIBehavior.STABILITY_BROKEN, false))

func is_performable_sim(ctx: NPCAIContext) -> bool:
	if !ctx or !ctx.combatant_state or !ctx.combatant_state.ai_state:
		return true
	var stability_broken := bool(ctx.combatant_state.ai_state.get(Keys.STABILITY_BROKEN, false))
	return !stability_broken
