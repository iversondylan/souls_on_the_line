class_name SmolderingMascotTextModel extends TextModel

@export_multiline var text_template: String = ""

func get_text(ctx: NPCAIContext) -> String:
	if ctx == null:
		return text_template
	return text_template.replace("{action_name}", String(ctx.action_name))
