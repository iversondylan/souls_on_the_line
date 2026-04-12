# heal_intent_text_model.gd

class_name HealIntentTextModel extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if ctx == null:
		return "error"
	return "+%s" % get_display_heal_amount(ctx)

func get_display_heal_amount(ctx: NPCAIContext) -> int:
	return maxi(_param_i(ctx, Keys.FLAT_AMOUNT, 0), 0)
