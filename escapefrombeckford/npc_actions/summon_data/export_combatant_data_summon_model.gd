# export_combatant_data_summon_model.gd
class_name ExportCombatantDataSummonModel
extends ParamModel

@export var combatant_data: CombatantData

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	if combatant_data:
		ctx.params[NPCKeys.SUMMON_DATA] = combatant_data
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx
	if combatant_data:
		# IMPORTANT: in sim I want a duplicate so per-summon mutation doesn't leak
		ctx.params[NPCKeys.SUMMON_DATA] = combatant_data.duplicate()
	return ctx
