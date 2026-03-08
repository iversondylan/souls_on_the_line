# intent_tooltip_text_model.gd
class_name IntentTooltipTextModel
extends TextModel

@export_multiline var text_template: String

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


func get_text_sim(ctx: NPCAIContext) -> String:
	if ctx == null or ctx.params == null:
		return text_template

	var result := text_template
	var regex := RegEx.new()
	regex.compile("\\{([^}]+)\\}")

	var matches := regex.search_all(result)
	for m in matches:
		var key_str := m.get_string(1)
		var replacement := "[key not found]"

		# Try string key
		if ctx.params.has(key_str):
			replacement = str(ctx.params.get(key_str))
		else:
			# Try StringName key
			var key_sn := StringName(key_str)
			if ctx.params.has(key_sn):
				replacement = str(ctx.params.get(key_sn))

		result = result.replace("{" + key_str + "}", replacement)

	return result
