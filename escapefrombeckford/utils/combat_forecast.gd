# combat_forecast.gd
class_name CombatForecast

static func preview_action_params(combatant_data: CombatantData) -> Dictionary:
	var action: NPCAction = combatant_data.ai.actions[0]
	var ctx := NPCAIContext.new()
	#ctx.combatant = _make_preview_fighter(combatant_data, modifier_system) # see note below
	ctx.combatant_data = combatant_data
	ctx.params = {}
	ctx.state = {}      # optional
	ctx.forecast = true # you already have this concept
	ctx.battle_scene = null
	ctx.rng = null
	
	# run ONLY param models (same as your intent path)
	for pkg in action.effect_packages:
		for m in pkg.param_models:
			if m:
				m.change_params(ctx)
	#ctx.combatant.queue_free()
	return ctx.params

#static func _make_preview_fighter(combatant_data: CombatantData, modifier_system: ModifierSystem) -> Fighter:
	#var fighter := Fighter.new()
	#fighter.combatant_data = combatant_data
	#fighter.modifier_system = modifier_system
	#return fighter
