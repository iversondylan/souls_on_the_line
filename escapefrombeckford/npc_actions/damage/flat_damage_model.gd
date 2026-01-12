class_name FlatDamageModel extends ParamModel

@export var damage: int = 5

func change_params(ctx: NPCAIContext) -> NPCAIContext:
	print("flat_damage_model.gd base damage: ", damage)
	ctx.params[NPCKeys.DAMAGE] = ctx.combatant.modifier_system.get_modified_value(damage, Modifier.Type.DMG_DEALT)
	print("flat_damage_model.gd modified damage: ", ctx.params[NPCKeys.DAMAGE])
	return ctx
