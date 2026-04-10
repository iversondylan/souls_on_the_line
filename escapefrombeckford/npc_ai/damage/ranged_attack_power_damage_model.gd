# ranged_attack_power_damage_model.gd

class_name RangedAttackPowerDamageModel extends ParamModel

@export var base_damage: int = 0

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	return _write_damage(ctx)

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	return _write_damage(ctx)

func _write_damage(ctx: NPCAIContext) -> NPCAIContext:
	if !ctx:
		return ctx

	var total := maxi(base_damage + _get_apr(ctx), 0)
	ctx.params[Keys.DAMAGE] = total
	ctx.params[Keys.DAMAGE_RANGED] = total
	return ctx

func _get_apr(ctx: NPCAIContext) -> int:
	if ctx.combatant_state != null:
		return int(ctx.combatant_state.apr)
	if ctx.combatant_data != null:
		return int(ctx.combatant_data.apr)
	return 0
