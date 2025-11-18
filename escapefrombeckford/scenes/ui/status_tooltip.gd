class_name StatusTooltip extends HBoxContainer

@export var status: Status : set = _set_status

@onready var status_display: StatusDisplay = $StatusDisplay

@onready var description: RichTextLabel = $Description

func _set_status(new_status: Status) -> void:
	if !is_node_ready():
		await ready
	status = new_status
	status_display.status = status
	description.text = status.get_tooltip()
