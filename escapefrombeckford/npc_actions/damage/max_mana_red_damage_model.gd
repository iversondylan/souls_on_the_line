# max_mana_red_damage_model.gd
class_name MaxManaRedDamageModel
extends ParamModel

@export var base_damage: int = 0
@export var mana_scaling: float = 1.0   # multiplied by max_mana_red

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	var max_red: int = 0
	if ctx.combatant and ctx.combatant.combatant_data:
		max_red = ctx.combatant.combatant_data.max_mana_red
	elif ctx.combatant_data:
		max_red = ctx.combatant_data.max_mana_red

	var scaled := floori(mana_scaling * max_red)
	var total := base_damage + scaled
	if total < 0:
		total = 0

	# IMPORTANT: base damage only (no DMG_DEALT here)
	ctx.params[NPCKeys.DAMAGE] = total
	return ctx
