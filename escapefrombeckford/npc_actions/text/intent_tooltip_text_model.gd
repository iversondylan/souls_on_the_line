# intent_tooltip_text_model.gd
class_name IntentTooltipTextModel
extends TextModel

func get_text(ctx: NPCAIContext) -> String:
	if !ctx or !ctx.params:
		return text_template
	
	var result := text_template
	var regex := RegEx.new()
	regex.compile("\\{([^}]+)\\}")
	
	var matches := regex.search_all(result)
	for m in matches:
		var key := m.get_string(1)
		var replacement: String
	
		if ctx.params.has(key):
			replacement = str(ctx.params[key])
		else:
			replacement = "[key not found]"
	
		result = result.replace("{" + key + "}", replacement)
	
	return result
