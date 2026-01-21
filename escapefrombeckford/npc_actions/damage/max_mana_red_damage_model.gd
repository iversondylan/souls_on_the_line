# max_mana_red_damage_model.gd
class_name MaxManaRedDamageModel
extends ParamModel

@export var base_damage: int = 0
@export var mana_scaling: float = 1.0   # multiplied by max_mana_red

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	var fighter := ctx.combatant
	if not fighter:
		ctx.params[NPCKeys.DAMAGE] = 0
		return ctx

	var max_red := fighter.combatant_data.max_mana_red
	var scaled := floori(mana_scaling * max_red)
	var total := base_damage + scaled
	#print("max_mana_red_damage_model.gd total damage: ", total, " fighter: ", fighter.name)
	# Clamp negative results to zero
	if total < 0:
		total = 0

	ctx.params[NPCKeys.DAMAGE] = ctx.combatant.modifier_system.get_modified_value(total, Modifier.Type.DMG_DEALT)
	#print("max_mana_red_damage_model.gd total modified damage: ", ctx.params[NPCKeys.DAMAGE], " fighter: ", fighter.name)
	return ctx
