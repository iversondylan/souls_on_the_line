# attack_intent_text_model.gd
class_name AttackIntentTextModel
extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if ctx == null:
		return "error"

	var damage := _param_i(ctx, Keys.DAMAGE, 0)
	var strikes := _param_i(ctx, Keys.STRIKES, 1)

	var actor_id := int(ctx.cid)
	damage = _modified_intent_sim(ctx, damage, Modifier.Type.DMG_DEALT, actor_id)

	if damage < 0 or strikes < 0:
		return "error"

	if strikes <= 1:
		return "%s" % damage

	return "%s×%s" % [strikes, damage]
