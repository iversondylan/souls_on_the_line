# block_intent_text_model.gd
class_name BlockIntentTextModel
extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if ctx == null:
		return "error"

	var armor := _param_i(ctx, Keys.ARMOR_AMOUNT, 0)
	if armor < 0:
		return "error"
	return "%s" % armor
