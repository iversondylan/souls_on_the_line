class_name IntentData extends Resource

@export var icon: Texture
@export var text: String  : set = _set_text
@export_multiline var tooltip_text: String

var current_text: String

func _set_text(string: String) -> void:
	text = string
