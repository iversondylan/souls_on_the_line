class_name ManaScaledDamageModel extends NPCDamageModel

@export var base_damage: int = 3
@export var scale: float = 1.0

func get_damage(ctx: NPCAIContext) -> int:
	var mana := ctx.combatant.combatant_data.max_mana_red
	var raw := base_damage + int(mana * scale)
	return ctx.combatant.modifier_system.get_modified_value(
		raw,
		Modifier.Type.DMG_DEALT
	)
