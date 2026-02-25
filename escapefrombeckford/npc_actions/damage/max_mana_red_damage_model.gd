# max_mana_red_damage_model.gd
class_name MaxManaRedDamageModel
extends ParamModel


# I need to change to tracking both melee and ranged damage (and remove variable scaling)
# something like:
# ctx.params[NPCKeys.DAMAGE_MELEE] = base_damage + ctx.combatant_state.apm (attack power melee)
# ctx.params[NPCKeys.DAMAGE_RANGED] = base_damage + ctx.combatant_state.apr (attack power ranged)

@export var base_damage: int = 0
@export var scaling: float = 1.0   # multiplied by max_mana_red

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	#print("max_mana_red_damage_model.gd change_params() ")
	var max_red: int = 0
	if ctx.combatant and ctx.combatant.combatant_data:
		max_red = ctx.combatant.combatant_data.max_mana_red
	elif ctx.combatant_data:
		max_red = ctx.combatant_data.max_mana_red

	var scaled := floori(scaling * max_red)
	var total := base_damage + scaled
	if total < 0:
		total = 0
	print("max_mana_red_damage_model.gd change_params() base dmg: %s, scaled dmg: %s, total: %s" % [base_damage, scaled, total])
	# IMPORTANT: base damage only (no DMG_DEALT here)
	ctx.params[NPCKeys.DAMAGE] = total
	#print("max_mana_red_damage_model.gd total: ", total)
	return ctx

func change_params_sim(ctx: NPCAIContext) -> NPCAIContext:
	
	var apr: int = 0
	if ctx.combatant_state:
		apr = ctx.combatant_state.apr
	elif ctx.combatant_data:
		apr = ctx.combatant_data.max_mana_red

	var scaled := floori(scaling * apr)
	var total := base_damage + scaled
	if total < 0:
		total = 0
	print("max_mana_red_damage_model.gd change_params_sim() base dmg: %s, scaled dmg: %s, total: %s" % [base_damage, scaled, total])
	# IMPORTANT: base damage only (no DMG_DEALT here)
	ctx.params[NPCKeys.DAMAGE] = total
	#print("max_mana_red_damage_model.gd total: ", total)
	return ctx
