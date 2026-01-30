# flat_damage_model.gd
class_name FlatDamageModel extends ParamModel

@export var damage: int = 5

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	if ctx.combatant:
		ctx.params[NPCKeys.DAMAGE] = ctx.combatant.modifier_system.get_modified_value(damage, Modifier.Type.DMG_DEALT)
	elif ctx.combatant_data:
		ctx.params[NPCKeys.DAMAGE] = damage
	return ctx
