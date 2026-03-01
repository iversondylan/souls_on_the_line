# block_intent_text_model.gd
class_name BlockIntentTextModel
extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if !ctx:
		return "error"

	var armor := int(ctx.params.get(Keys.ARMOR_AMOUNT, 0))

	if armor < 0:
		return "error"

	return "%s" % armor
