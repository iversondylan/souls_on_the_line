# attack_intent_text_model.gd
class_name AttackIntentTextModel
extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if ctx == null:
		return "error"

	var damage := _param_i(ctx, Keys.DAMAGE, 0)
	var banish_damage := _param_i(ctx, Keys.BANISH_DAMAGE, 0)
	var strikes := _param_i(ctx, Keys.STRIKES, 1)

	var actor_id := ctx.get_actor_id()
	var components := PendingIntentModifierResolver.get_attack_display_components(
		ctx,
		damage,
		banish_damage,
		actor_id
	)
	damage = int(components.get("total", 0))

	if damage < 0 or strikes < 0:
		return "error"

	if strikes <= 1:
		return "%s" % damage

	return "%s×%s" % [strikes, damage]
