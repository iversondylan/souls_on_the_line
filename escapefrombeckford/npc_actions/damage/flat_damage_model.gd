class_name FlatDamageModel extends NPCDamageModel

@export var base_damage: int = 5

func get_damage(ctx: NPCAIContext) -> int:
	return ctx.combatant.modifier_system.get_modified_value(
		base_damage,
		Modifier.Type.DMG_DEALT
	)
