class_name IntentData extends Resource

@export var icon: Texture
@export var base_text: String  : set = _set_text
@export_multiline var tooltip_text: String

var current_text: String
var current_tooltip_text: String

func _set_text(string: String) -> void:
	base_text = string
