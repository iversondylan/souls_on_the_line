# max_ap_damage_model.gd
class_name MaxApDamageModel
extends ParamModel

@export var base_damage: int = 0
@export var scaling: float = 1.0

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	var ap: int = 0
	if ctx.combatant and ctx.combatant.combatant_data:
		ap = ctx.combatant.combatant_data.ap
	elif ctx.combatant_data:
		ap = ctx.combatant_data.ap

	var scaled := floori(scaling * ap)
	var total := base_damage + scaled
	if total < 0:
		total = 0
	ctx.params[Keys.DAMAGE] = total
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	var ap: int = 0
	if ctx.combatant_state:
		ap = ctx.combatant_state.ap
	elif ctx.combatant_data:
		ap = ctx.combatant_data.ap

	var scaled := floori(scaling * ap)
	var total := base_damage + scaled
	if total < 0:
		total = 0
	ctx.params[Keys.DAMAGE] = total
	ctx.params[Keys.DAMAGE_MELEE] = total
	ctx.params[Keys.DAMAGE_RANGED] = total
	return ctx
