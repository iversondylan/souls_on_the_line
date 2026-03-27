# combat_forecast.gd
class_name CombatForecast

static func preview_action_params(combatant_data: CombatantData) -> Dictionary:
	var action: NPCAction = combatant_data.ai.actions[0]
	var ctx := NPCAIContext.new()
	ctx.combatant_data = combatant_data
	ctx.params = {}
	ctx.state = {}
	ctx.forecast = true
	ctx.battle_scene = null
	ctx.rng = null
	
	# run ONLY param models (same as intent path)
	for pkg in action.effect_packages:
		for m in pkg.param_models:
			if m:
				m.change_params(ctx)
	return ctx.params
