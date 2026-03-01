# attack_intent_text_model.gd
class_name AttackIntentTextModel
extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if !ctx:
		return "error"

	var damage := int(ctx.params.get(Keys.DAMAGE, 0))
	damage = ctx.combatant.modifier_system.get_modified_value(damage, Modifier.Type.DMG_DEALT)
	var strikes := int(ctx.params.get(Keys.STRIKES, 1))

	if damage < 0 or strikes < 0:
		return "error"

	if strikes <= 1:
		return "%s" % damage

	return "%s×%s" % [strikes, damage]
