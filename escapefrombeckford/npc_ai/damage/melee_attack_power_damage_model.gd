# melee_attack_power_damage_model.gd
class_name MeleeAttackPowerDamageModel extends ParamModel

@export var base_damage: int = 0


func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx

	var total := maxi(base_damage + _get_apm(ctx), 0)
	ctx.params[Keys.DAMAGE] = total
	ctx.params[Keys.DAMAGE_MELEE] = total
	return ctx


func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx

	var total := maxi(base_damage + _get_apm(ctx), 0)
	ctx.params[Keys.DAMAGE] = total
	ctx.params[Keys.DAMAGE_MELEE] = total
	return ctx


func _get_apm(ctx: NPCAIContext) -> int:
	if ctx.combatant_state:
		return int(ctx.combatant_state.apm)
	if ctx.combatant and ctx.combatant.combatant_data:
		return int(ctx.combatant.combatant_data.apm)
	if ctx.combatant_data:
		return int(ctx.combatant_data.apm)
	return 0
