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

func get_text_sim(ctx: NPCAIContext) -> String:
	if ctx == null:
		return "error"

	var damage := _param_i(ctx, Keys.DAMAGE, 0)
	var strikes := _param_i(ctx, Keys.STRIKES, 1)

	# modifier: damage dealt by the actor
	var actor_id := int(ctx.cid)
	damage = _modified_sim(ctx, damage, Modifier.Type.DMG_DEALT, actor_id)

	if damage < 0 or strikes < 0:
		return "error"

	if strikes <= 1:
		return "%s" % damage

	return "%s×%s" % [strikes, damage]
