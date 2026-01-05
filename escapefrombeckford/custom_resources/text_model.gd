# text_model.gd
class_name TextModel extends Resource

@export var text_template: String

func get_text(_ctx: NPCAIContext) -> String:
	return ""
