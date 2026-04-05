# attack_intent_tooltip_text_model.gd

class_name AttackIntentTooltipTextModel extends TextModel

@export_multiline var text_template: String = "[b]{action_name}[/b]: {strikes}{damage} damage."

func get_text(ctx: NPCAIContext) -> String:
	if ctx == null or ctx.params == null:
		return text_template

	var result := text_template

	result = result.replace("{action_name}", String(ctx.action_name))

	# ---- Strikes ----
	var strikes := _param_i(ctx, Keys.STRIKES, 1)
	var strikes_text := ""
	if strikes >= 2:
		strikes_text = "%d strikes of " % strikes
	result = result.replace("{strikes}", strikes_text)

	# ---- Damage ----
	var damage := _param_i(ctx, Keys.DAMAGE, 0)
	var banish_damage := _param_i(ctx, Keys.BANISH_DAMAGE, 0)
	var components := PendingIntentModifierResolver.get_attack_display_components(
		ctx,
		damage,
		banish_damage,
		ctx.get_actor_id()
	)
	result = result.replace("{damage}", "%d" % int(components.get("total", 0)))

	return result
