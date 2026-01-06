# text_model.gd
class_name TextModel extends Resource

@export_multiline var text_template: String

func get_text(_ctx: NPCAIContext) -> String:
	return ""
